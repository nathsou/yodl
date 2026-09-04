import type { CompileRequest, CompileResult, SimulationStreamEvent } from './playground-compiler.ts';

// Replaced by the site build with the content-hashed worker filename.
declare const __YODL_COMPILER_WORKER__: string;
export const compilerWorkerFile = typeof __YODL_COMPILER_WORKER__ === 'undefined' ? './playground-worker.js' : __YODL_COMPILER_WORKER__;

type Job = { owner: string; request: CompileRequest; resolve: (result: CompileResult | null) => void };

// A page has at most one compiler worker. Each example owns its queued request;
// superseding an example never discards work belonging to another example.
export class CompilerClient {
    private worker?: Worker;
    private active?: Job;
    private queue: Job[] = [];
    private timer?: ReturnType<typeof setTimeout>;
    private nextId = 0;
    constructor(private timeoutMs = 15_000) {}

    compile(owner: string, request: Omit<CompileRequest, 'id'>): Promise<CompileResult | null> {
        this.cancel(owner);
        return new Promise(resolve => {
            this.queue.push({ owner, request: { ...request, id: ++this.nextId }, resolve });
            this.pump();
        });
    }
    cancel(owner: string) {
        this.queue = this.queue.filter(job => {
            if (job.owner !== owner) return true;
            job.resolve(null);
            return false;
        });
        if (this.active?.owner === owner) {
            this.worker?.terminate();
            this.worker = undefined;
            this.finish(null);
        }
    }
    dispose() {
        for (const job of this.queue) job.resolve(null);
        this.queue = [];
        if (this.active) this.cancel(this.active.owner);
        this.worker?.terminate();
        this.worker = undefined;
    }
    private finish(result: CompileResult | null) {
        clearTimeout(this.timer);
        const job = this.active;
        this.active = undefined;
        job?.resolve(result);
        this.pump();
    }
    private pump() {
        if (this.active || !this.queue.length) return;
        const job = this.active = this.queue.shift()!;
        const fail = (error: string) => {
            if (this.active !== job) return;
            this.worker?.terminate();
            this.worker = undefined;
            this.finish({ id: job.request.id, error, duration: 0 });
        };
        try {
            this.worker ??= new Worker(new URL(compilerWorkerFile, import.meta.url), { type: 'module' });
            this.worker.onmessage = (event: MessageEvent<CompileResult>) => {
                if (this.active === job && event.data.id === job.request.id) this.finish(event.data);
            };
            this.worker.onerror = () => fail('The compiler worker could not run. Try Compile again.');
            this.timer = setTimeout(() => fail('Compilation exceeded 15 seconds. Try a smaller design or reduce compile-time loop bounds.'), this.timeoutMs);
            this.worker.postMessage(job.request);
        } catch (error) {
            fail(`Could not start the compiler: ${(error as Error).message}`);
        }
    }
}

type StreamRequest = Omit<CompileRequest, 'id'>;

// Visual simulation has a separate worker so that a persistent real-time run
// never blocks ordinary compilation or documentation examples. The worker
// owns the simulator session and emits one framebuffer at a time.
export class RealtimeSimulationClient {
    private worker?: Worker;
    private requestId = 0;
    private activeId?: number;
    private request?: StreamRequest;
    private startupTimer?: ReturnType<typeof setTimeout>;
    constructor(private startupTimeoutMs = 30_000) {}

    start(request: StreamRequest, onEvent: (event: SimulationStreamEvent) => void) {
        this.stop();
        const id = ++this.requestId;
        this.activeId = id;
        this.request = request;
        const worker = this.worker = new Worker(new URL(compilerWorkerFile, import.meta.url), { type: 'module' });
        worker.onmessage = (message: MessageEvent<SimulationStreamEvent>) => {
            if (this.worker !== worker || message.data.id !== id) return;
            clearTimeout(this.startupTimer);
            onEvent(message.data);
        };
        worker.onerror = () => {
            if (this.worker !== worker) return;
            this.stop();
            onEvent({ id, type: 'error', error: 'The simulation worker could not run. Try Run again.' });
        };
        this.startupTimer = setTimeout(() => {
            if (this.worker !== worker) return;
            this.stop();
            onEvent({ id, type: 'error', error: 'Simulation compilation timed out. Try a smaller design.' });
        }, this.startupTimeoutMs);
        worker.postMessage({ ...request, id, simulate: { ...request.simulate, mode: 'realtime', action: request.simulate?.action ?? 'run' } });
    }

    pause() { this.postControl('pause'); }
    resume(options?: Pick<NonNullable<StreamRequest['simulate']>, 'clockHz' | 'refreshFps' | 'cyclesPerFrame'>) { this.postControl('resume', options); }
    command(action: 'reset' | 'step_cycle' | 'step_frame', options?: Pick<NonNullable<StreamRequest['simulate']>, 'clockHz' | 'refreshFps' | 'cyclesPerFrame'>) { this.postControl(action, options); }
    setInputs(inputs: NonNullable<StreamRequest['simulate']>['inputs']) {
        if (!this.request?.simulate) return;
        this.request = { ...this.request, simulate: { ...this.request.simulate, inputs } };
        this.postControl('settle');
    }

    stop() {
        clearTimeout(this.startupTimer);
        this.worker?.terminate();
        this.worker = undefined;
        this.activeId = undefined;
        this.request = undefined;
    }

    private postControl(action: 'pause' | 'resume' | 'reset' | 'step_cycle' | 'step_frame' | 'settle', options?: Pick<NonNullable<StreamRequest['simulate']>, 'clockHz' | 'refreshFps' | 'cyclesPerFrame'>) {
        if (!this.worker || this.activeId === undefined || !this.request) return;
        this.worker.postMessage({ id: this.activeId, control: { action, options, ...(action === 'settle' ? { inputs: this.request.simulate?.inputs } : {}) } });
    }
}

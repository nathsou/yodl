import type { CompileRequest, CompileResult } from './playground-compiler.ts';

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
            this.worker ??= new Worker(new URL('./playground-worker.js', import.meta.url), { type: 'module' });
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

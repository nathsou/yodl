import { compile, SimulationSession, simulationError } from './playground-compiler.ts';
import type { CompileRequest, SimulationRequest, SimulationStreamEvent, SimulationFramebuffer } from './playground-compiler.ts';

export type SimulationControl = { id: number; control: { action: NonNullable<SimulationRequest['action']>; inputs?: SimulationRequest['inputs']; options?: Pick<SimulationRequest, 'cyclesPerFrame' | 'clockHz' | 'refreshFps'> } };
type State = {
    id: number;
    session: SimulationSession;
    running: boolean;
    remaining: number;
    targetFrame?: number;
    totalCycles: number;
    refreshFps: number;
    clockHz?: number;
    cyclesPerFrame: number;
    lastTick: number;
    lastPaint: number;
    credit: number;
    measuredAt: number;
    measuredCycles: number;
};
let state: State | undefined;
let timer: ReturnType<typeof setTimeout> | undefined;

function buffers(frame?: SimulationFramebuffer): ArrayBuffer[] {
    return [frame?.packed, frame?.rgb, frame?.valid].flatMap(value => value ? [value.buffer as ArrayBuffer] : []);
}
function send(type: SimulationStreamEvent['type']) {
    if (!state) return;
    const now = performance.now();
    const result = state.session.snapshot();
    const event: SimulationStreamEvent = {
        id: state.id, type: result.halted ? 'halted' : type,
        frame: result.framebuffers?.at(-1), outputs: result.outputs, inputs: result.inputs,
        messages: result.messages, events: result.events, status: result.status, totalCycles: state.totalCycles, clock: result.clock,
        sources: type === 'started' ? state.session.sources : undefined,
        metadata: result.metadata,
        playback: { refreshFps: state.refreshFps, clockHz: state.clockHz, cyclesPerFrame: state.cyclesPerFrame },
        simulatedSeconds: state.clockHz ? state.totalCycles / state.clockHz : undefined,
        cyclesPerSecond: (state.totalCycles - state.measuredCycles) * 1000 / Math.max(1, now - state.measuredAt),
    };
    self.postMessage(event, buffers(event.frame));
    state.lastPaint = now;
    if (now - state.measuredAt >= 1000) { state.measuredAt = now; state.measuredCycles = state.totalCycles; }
}
function cancelTick() { clearTimeout(timer); timer = undefined; }
function schedule(delay = 0) { cancelTick(); timer = setTimeout(tick, delay); }
function fail(error: unknown) {
    cancelTick();
    if (state) { state.running = false; self.postMessage({ id: state.id, type: 'error', error: simulationError(error) }); }
}
function tick() {
    const current = state;
    if (!current) return;
    try {
        const start = performance.now();
        const manual = current.remaining > 0 || current.targetFrame !== undefined;
        const hz = current.clockHz;
        if (current.running && hz) current.credit = Math.min(Math.max(1, hz / 4), current.credit + (start - current.lastTick) * hz / 1000);
        current.lastTick = start;
        let budget = manual ? current.remaining : hz ? Math.floor(current.credit) : 4096;
        while ((current.running || manual) && budget > 0 && performance.now() - start < 8) {
            const chunk = Math.min(current.session.stream ? 128 : 1, budget);
            const outcome = current.targetFrame !== undefined
                ? current.session.advanceTowardFrame(chunk)
                : current.session.advanceCycles(chunk);
            const count = outcome.cycles;
            current.totalCycles += count;
            budget -= count;
            if (manual) current.remaining -= count;
            else if (hz) current.credit -= count;
            if (current.session.halted || count === 0) break;
            if (current.targetFrame !== undefined && current.session.frames >= current.targetFrame) { current.remaining = 0; break; }
        }
        if (current.session.halted) { current.running = false; current.remaining = 0; current.targetFrame = undefined; send('halted'); return; }
        if (manual && current.remaining <= 0) {
            if (current.targetFrame !== undefined && current.session.frames < current.targetFrame) throw new Error('No frame boundary after 10,000,000 cycles. Check the stream coordinates and valid signal.');
            current.targetFrame = undefined;
            send('snapshot');
            return;
        }
        if (performance.now() - current.lastPaint >= 1000 / current.refreshFps) send(manual ? 'stepping' : 'frame');
        if (current.running || manual) schedule(budget <= 0 && hz && !manual ? Math.min(16, 1000 / hz) : 0);
    } catch (error) { fail(error); }
}
function configure(options: SimulationControl['control']['options']) {
    if (!state || !options) return;
    if (options.refreshFps !== undefined) state.refreshFps = Math.max(1, Math.min(240, options.refreshFps));
    if (options.clockHz !== undefined) state.clockHz = Math.max(1, options.clockHz);
    if (options.cyclesPerFrame !== undefined) {
        if (!Number.isSafeInteger(options.cyclesPerFrame) || options.cyclesPerFrame < 1 || options.cyclesPerFrame > 100000) throw new Error('cyclesPerFrame must be an integer between 1 and 100000.');
        state.cyclesPerFrame = options.cyclesPerFrame;
    }
}
function control(command: SimulationControl) {
    if (!state || command.id !== state.id) return;
    const { action, inputs, options } = command.control;
    configure(options);
    cancelTick();
    state.running = false;
    state.remaining = 0;
    state.targetFrame = undefined;
    if (inputs) state.session.setInputs(inputs);
    switch (action) {
        case 'run':
        case 'resume':
            if (!state.session.clock || state.session.halted) { send('snapshot'); break; }
            state.running = true;
            state.credit = 0;
            state.lastTick = performance.now();
            send('resumed');
            schedule();
            break;
        case 'pause': send('paused'); break;
        case 'stop': send('stopped'); state = undefined; break;
        case 'reset':
            state.session.reset(); state.totalCycles = 0;
            state.measuredAt = performance.now(); state.measuredCycles = 0;
            send('snapshot'); break;
        case 'step_cycle': state.remaining = 1; send('stepping'); schedule(); break;
        case 'step_frame':
            state.remaining = state.session.stream ? 10_000_000 : state.cyclesPerFrame;
            state.targetFrame = state.session.stream ? state.session.frames + 1 : undefined;
            send('stepping'); schedule(); break;
        default: send('snapshot'); break;
    }
}
self.onmessage = (event: MessageEvent<CompileRequest | SimulationControl>) => {
    const request = event.data;
    try {
        if ('control' in request) { control(request); return; }
        if (request.simulate?.mode !== 'realtime') {
            const result = compile(request);
            self.postMessage(result, result.simulation?.framebuffers?.flatMap(buffers) ?? []);
            return;
        }
        cancelTick();
        const session = new SimulationSession(request);
        const metadata = session.metadata;
        state = { id: request.id, session, running: false, remaining: 0, totalCycles: 0, refreshFps: 30, clockHz: session.clock ? metadata.clockHz ?? (session.stream ? undefined : 30) : undefined, cyclesPerFrame: metadata.cyclesPerFrame ?? 1, lastTick: performance.now(), lastPaint: 0, credit: 0, measuredAt: performance.now(), measuredCycles: 0 };
        configure(request.simulate);
        send('started');
        if (session.clock || (request.simulate.action && request.simulate.action !== 'run')) control({ id: request.id, control: { action: request.simulate.action ?? 'run' } });
    } catch (error) {
        cancelTick();
        self.postMessage({ id: request.id, type: 'error', error: simulationError(error) });
    }
};

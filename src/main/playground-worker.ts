import { compile } from './playground-compiler.ts';
import type { CompileRequest, SimulationStreamEvent } from './playground-compiler.ts';

type RealtimeState = {
    id: number;
    request: CompileRequest;
    frameRate: number;
    frameCycles: number;
    totalCycles: number;
    nextDeadline: number;
    running: boolean;
};

let realtime: RealtimeState | undefined;
let realtimeTimer: ReturnType<typeof setTimeout> | undefined;

function post(event: SimulationStreamEvent) {
    self.postMessage(event);
}

function stopRealtime() {
    if (realtimeTimer !== undefined) clearTimeout(realtimeTimer);
    realtimeTimer = undefined;
    realtime = undefined;
}

function eventFromResult(id: number, type: SimulationStreamEvent['type'], result: ReturnType<typeof compile>, totalCycles: number): SimulationStreamEvent {
    const simulation = result.simulation;
    if (result.error !== undefined) return { id, type: 'error', error: result.error };
    return {
        id,
        type,
        frame: simulation?.framebuffers?.at(-1),
        outputs: simulation?.outputs,
        messages: simulation?.messages,
        cycles: simulation?.cycles ?? 0,
        totalCycles,
    };
}

function scheduleRealtime(state: RealtimeState) {
    if (realtime !== state || !state.running) return;
    const delay = Math.max(0, state.nextDeadline - performance.now());
    realtimeTimer = setTimeout(() => realtimeTick(state), delay);
}

function realtimeTick(state: RealtimeState) {
    if (realtime !== state || !state.running) return;
    const simulate = state.request.simulate!;
    const result = compile({
        ...state.request,
        simulate: { ...simulate, mode: 'batch', action: 'step_frame', frames: 1, frameCycles: state.frameCycles },
    });
    if (result.error !== undefined) {
        post(eventFromResult(state.id, 'error', result, state.totalCycles));
        stopRealtime();
        return;
    }
    state.totalCycles += result.simulation?.cycles ?? 0;
    post(eventFromResult(state.id, 'frame', result, state.totalCycles));
    state.nextDeadline += 1000 / state.frameRate;
    // If a frame takes substantially longer than its deadline, slow simulated
    // time down rather than spinning in an unbounded catch-up loop.
    if (state.nextDeadline < performance.now() - 4 * (1000 / state.frameRate)) state.nextDeadline = performance.now() + 1000 / state.frameRate;
    scheduleRealtime(state);
}

function startRealtime(request: CompileRequest) {
    stopRealtime();
    const simulate = request.simulate!;
    const frameRate = Math.max(1, Math.min(240, simulate.frameRate ?? 60));
    const frameCycles = Math.max(1, Math.min(100000, simulate.frameCycles ?? 1));
    const initial = compile({ ...request, simulate: { ...simulate, mode: 'batch', action: 'run', frames: 1 } });
    if (initial.error !== undefined) {
        post(eventFromResult(request.id, 'error', initial, 0));
        return;
    }
    const state: RealtimeState = {
        id: request.id,
        request,
        frameRate,
        frameCycles,
        totalCycles: initial.simulation?.cycles ?? 0,
        nextDeadline: performance.now() + 1000 / frameRate,
        running: true,
    };
    realtime = state;
    post(eventFromResult(state.id, 'started', initial, state.totalCycles));
    scheduleRealtime(state);
}

self.onmessage = (event: MessageEvent<CompileRequest>) => {
    const request = event.data;
    const simulate = request.simulate;
    if (simulate?.mode !== 'realtime') {
        self.postMessage(compile(request));
        return;
    }
    switch (simulate.action) {
        case 'run':
            startRealtime(request);
            break;
        case 'pause':
            if (realtime) {
                realtime.running = false;
                if (realtimeTimer !== undefined) clearTimeout(realtimeTimer);
                realtimeTimer = undefined;
                post({ id: request.id, type: 'paused', totalCycles: realtime.totalCycles });
            }
            break;
        case 'resume':
            if (realtime) {
                realtime.running = true;
                realtime.nextDeadline = performance.now();
                post({ id: request.id, type: 'resumed', totalCycles: realtime.totalCycles });
                scheduleRealtime(realtime);
            }
            break;
        case 'stop':
            stopRealtime();
            post({ id: request.id, type: 'stopped' });
            break;
        default:
            self.postMessage(compile({ ...request, simulate: { ...simulate, mode: 'batch' } }));
            break;
    }
};

import { afterAll, beforeAll, expect, test } from 'bun:test';
import type { SimulationStreamEvent } from '../main/playground-compiler.ts';

const originalSelf = globalThis.self;
const events: SimulationStreamEvent[] = [];
const host = { onmessage: undefined as any, postMessage(event: SimulationStreamEvent, transfer: ArrayBuffer[] = []) { events.push(structuredClone(event, { transfer })); } };
beforeAll(async () => { globalThis.self = host as any; await import('../main/playground-worker.ts'); });
afterAll(() => { host.onmessage({ data: { id: 101, control: { action: 'stop' } } }); globalThis.self = originalSelf; });
function send(data: any) { host.onmessage({ data }); }
async function waitFor(type: string, from = 0) {
    const deadline = performance.now() + 2500;
    while (performance.now() < deadline) {
        const result = events.slice(from).find(e => e.type === type || e.type === 'error');
        if (result) { expect(result.error).toBeUndefined(); return result; }
        await new Promise(resolve => setTimeout(resolve, 5));
    }
    throw new Error(`Missing ${type} event`);
}

test('manual stepping, low-frequency resume and input snapshots share one worker machine', async () => {
    send({ id: 100, path: 'test.yodl', stage: 'write_low_firrtl', source: `@simulation({display: { signal: "pixel" }, reset: "rst"})
module Top(clk: clock, rst: bool, a: bool) -> (pixel: [1][2]bool, count: u8) {
    let counter = Reg[u8](clk, rst)
    counter.d = counter.q + 1
    count = counter.q
    pixel = [[a, a]]
}`, simulate: { mode: 'realtime', action: 'step_cycle', clockHz: 1 } });
    const started = await waitFor('started');
    expect(started.sources?.['test.yodl']).toContain('module Top');
    let snapshot = await waitFor('snapshot');
    expect(snapshot.sources).toBeUndefined();
    expect(snapshot.totalCycles).toBe(1);
    expect(snapshot.outputs!.find(s => s.name === 'count')!.value).toBe('1');
    let offset = events.length;
    send({ id: 100, control: { action: 'resume' } });
    const deadline = performance.now() + 2000;
    while (!events.slice(offset).some(e => (e.totalCycles ?? 0) >= 2) && performance.now() < deadline) await new Promise(resolve => setTimeout(resolve, 10));
    send({ id: 100, control: { action: 'pause' } });
    const paused = await waitFor('paused', offset);
    expect(paused.totalCycles).toBeGreaterThanOrEqual(2);
    offset = events.length;
    send({ id: 100, control: { action: 'settle', inputs: { a: { width: 1, value: 1 } } } });
    snapshot = await waitFor('snapshot', offset);
    expect(snapshot.totalCycles).toBe(paused.totalCycles);
    expect(snapshot.frame!.packed![0]).toBe(3);
    expect(snapshot.frame!.valid![0]).toBe(0xffffffff);
    offset = events.length;
    send({ id: 100, control: { action: 'reset' } });
    snapshot = await waitFor('snapshot', offset);
    expect(snapshot.totalCycles).toBe(0);
    expect(snapshot.outputs!.find(s => s.name === 'count')!.value).toBe('0');
    send({ id: 100, control: { action: 'stop' } });
});

test('a long pixel-stream frame step can be paused between execution chunks', async () => {
    const offset = events.length;
    send({ id: 101, path: 'test.yodl', stage: 'write_low_firrtl', source: `@simulation({display: {stream: "video", width: 2, height: 1}, reset: "rst"})
module Top(clk: clock, rst: bool) -> (video: (x: u24, y: u1, valid: bool, r: u1, g: u1, b: u1)) {
    let x = Reg[u24](clk, rst)
    x.d = x.q + 1
    video = (x: x.q, y: 0, valid: true, r: true, g: false, b: false)
}`, simulate: { mode: 'realtime', action: 'step_frame' } });
    await waitFor('stepping', offset);
    await new Promise(resolve => setTimeout(resolve, 20));
    send({ id: 101, control: { action: 'pause' } });
    const paused = await waitFor('paused', offset);
    expect(paused.totalCycles).toBeGreaterThan(0);
    expect(paused.totalCycles).toBeLessThan(10_000_000);
});

test('refresh FPS and frame step size do not control playback clock speed', async () => {
    const source = `@simulation({reset: "rst", cycles_per_frame: 7})
module Top(clk: clock, rst: bool) -> (count: u16) {
    let count_reg = Reg[u16](clk, rst)
    count_reg.d = count_reg.q + 1
    count = count_reg.q
}`;
    const measure = async (refreshFps: number) => {
        const offset = events.length;
        send({ id: 102, path: 'timing.yodl', stage: 'write_low_firrtl', source, simulate: { mode: 'realtime', action: 'run', refreshFps } });
        const started = await waitFor('started', offset);
        expect(started.playback).toEqual({ refreshFps, clockHz: 30, cyclesPerFrame: 7 });
        expect(started.metadata).not.toHaveProperty('refreshFps');
        await new Promise(resolve => setTimeout(resolve, 500));
        send({ id: 102, control: { action: 'pause' } });
        const paused = await waitFor('paused', offset);
        expect(paused.totalCycles).toBeGreaterThanOrEqual(12);
        expect(paused.totalCycles).toBeLessThanOrEqual(18);
        const stepOffset = events.length;
        send({ id: 102, control: { action: 'step_frame', options: { refreshFps: 240 } } });
        const stepped = await waitFor('snapshot', stepOffset);
        expect(stepped.totalCycles! - paused.totalCycles!).toBe(7);
        expect(stepped.playback!.clockHz).toBe(30);
        send({ id: 102, control: { action: 'stop' } });
        return paused.totalCycles!;
    };
    const slowRefresh = await measure(1);
    const fastRefresh = await measure(120);
    expect(Math.abs(slowRefresh - fastRefresh)).toBeLessThanOrEqual(3);
});

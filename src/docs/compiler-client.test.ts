import { afterEach, expect, test } from 'bun:test';
import { CompilerClient } from '../main/compiler-client.ts';
import { compile } from '../main/playground-compiler.ts';
import { files } from '../main/playground-model.ts';

const originalWorker = globalThis.Worker;
class FakeWorker {
    static instances: FakeWorker[] = [];
    onmessage?: (event: any) => void;
    onerror?: () => void;
    messages: any[] = [];
    terminated = false;
    constructor() { FakeWorker.instances.push(this); }
    postMessage(request: any) { this.messages.push(request); }
    terminate() { this.terminated = true; }
    reply() { this.onmessage?.({ data: { id: this.messages.at(-1).id, output: 'compiled', duration: 1 } }); }
}
afterEach(() => { globalThis.Worker = originalWorker; FakeWorker.instances = []; });
const request = { source: 'module Top() -> () {}', path: 'examples/Top.yodl', stage: 'write_firrtl' as const };

test('queue isolates examples and superseded jobs never update another owner', async () => {
    globalThis.Worker = FakeWorker as any;
    const client = new CompilerClient();
    const first = client.compile('a', request);
    const second = client.compile('b', request);
    const staleWorker = FakeWorker.instances[0];
    expect(staleWorker.messages).toHaveLength(1);
    const replacement = client.compile('a', request);
    expect(await first).toBeNull();
    expect(staleWorker.terminated).toBe(true);
    staleWorker.reply();
    const worker = FakeWorker.instances[1];
    worker.reply();
    expect((await second)?.output).toBe('compiled');
    expect(worker.messages).toHaveLength(2);
    worker.reply();
    expect((await replacement)?.output).toBe('compiled');
    client.dispose();
});

test('worker errors allow queued and future requests to continue', async () => {
    globalThis.Worker = FakeWorker as any;
    const client = new CompilerClient();
    const failed = client.compile('a', request);
    const next = client.compile('b', request);
    FakeWorker.instances[0].onerror!();
    expect((await failed)?.error).toContain('could not run');
    FakeWorker.instances[1].reply();
    expect((await next)?.output).toBe('compiled');
    client.dispose();
});

test('dispose resolves outstanding requests and terminates the worker', async () => {
    globalThis.Worker = FakeWorker as any;
    const client = new CompilerClient();
    const a = client.compile('a', request), b = client.compile('b', request);
    client.dispose();
    expect(await a).toBeNull(); expect(await b).toBeNull();
    expect(FakeWorker.instances[0].terminated).toBe(true);
});

test('compilation uses fresh explicit files for each request, including nested entry paths', () => {
    const valid = compile({ id: 1, source: 'module Top(a: bool) -> (q: bool) { q = a; }', path: 'book/src/width/ex-test.yodl', stage: 'write_firrtl' });
    expect(valid.error).toBeUndefined();
    expect(valid.output).toContain('module Top');
    const invalid = compile({ id: 2, source: 'module Broken(', path: 'book/src/width/ex-test.yodl', stage: 'write_typed' });
    expect(invalid.error).toContain('book/src/width/ex-test.yodl');
    expect(compile({ id: 3, ...request }).error).toBeUndefined();
});

test('timeout terminates stuck work and releases the next example', async () => {
    globalThis.Worker = FakeWorker as any;
    const client = new CompilerClient(10);
    const stuck = client.compile('a', request);
    const next = client.compile('b', request);
    expect((await stuck)?.error).toContain('exceeded 15 seconds');
    expect(FakeWorker.instances[0].terminated).toBe(true);
    FakeWorker.instances[1].reply();
    expect((await next)?.output).toBe('compiled');
    client.dispose();
});

test('each compile has an isolated dependency filesystem', () => {
    const source = 'import Logic\nmodule Top(a: bool) -> (q: bool) {\n    let gate = Logic::Gate(a)\n    q = gate.q\n}\n';
    const files = { 'examples/lib/Logic.yodl': 'module Gate(a: bool) -> (q: bool) {\n    q = not a\n}\n' };
    const first = compile({ ...request, id: 1, source, files });
    expect(first.error).toBeUndefined();
    expect(first.output).toContain('not(');
    const second = compile({ ...request, id: 2, source });
    expect(second.error).toBeDefined();
    expect(files['examples/lib/Logic.yodl']).toContain('q = not a');
});

test('Game of Life simulation returns playable framebuffer frames', () => {
    const source = files['examples/Sim.yodl'];
    const result = compile({
        id: 4,
        source,
        path: 'examples/Sim.yodl',
        stage: 'write_low_firrtl',
        files,
        simulate: {
            top: 'LifeSim',
            clock: 'clk',
            frames: 4,
            frameCycles: 1,
            framebuffer: { width: 40, height: 30, statePrefix: 'state', initSignal: 'init', initCycles: 1 },
        },
    });
    expect(result.error).toBeUndefined();
    expect(result.simulation?.cycles).toBe(3);
    expect(result.simulation?.framebuffers).toHaveLength(4);
    expect(result.simulation?.framebuffers?.[0].pixels.some(pixel => pixel !== 0)).toBe(true);
});

test('visual examples expose simulation-friendly pixel outputs', () => {
    const image = compile({
        id: 5,
        source: files['examples/Image.yodl'],
        path: 'examples/Image.yodl',
        stage: 'write_low_firrtl',
        files,
        simulate: {
            top: 'ImageSim',
            frames: 1,
            frameCycles: 0,
            framebuffer: { width: 40, height: 30, statePrefix: 'pixel', valueMode: 'rgb' },
        },
    });
    expect(image.error).toBeUndefined();
    expect(image.simulation?.framebuffers).toHaveLength(1);
    expect(image.simulation?.framebuffers?.[0]).toMatchObject({ width: 40, height: 30 });
    expect(image.simulation?.framebuffers?.[0].pixels[0]).toBe(0x6db6ff);
    expect(new Set(image.simulation?.framebuffers?.[0].pixels).size).toBeGreaterThan(4);

    const noise = compile({
        id: 6,
        source: files['examples/Noise.yodl'],
        path: 'examples/Noise.yodl',
        stage: 'write_low_firrtl',
        files,
        simulate: {
            top: 'NoiseSim',
            clock: 'clk',
            frames: 2,
            frameCycles: 1,
            framebuffer: { width: 40, height: 30, statePrefix: 'pixel', valueMode: 'binary', initSignal: 'rst', initCycles: 1 },
        },
    });
    expect(noise.error).toBeUndefined();
    expect(noise.simulation?.framebuffers).toHaveLength(2);
    expect(noise.simulation?.framebuffers?.[0]).toMatchObject({ width: 40, height: 30 });
    expect(noise.simulation?.framebuffers?.[0].pixels.some(pixel => pixel !== 528408)).toBe(true);
    expect(noise.simulation?.framebuffers?.[0].pixels).not.toEqual(noise.simulation?.framebuffers?.[1].pixels);

    for (const [id, file, top] of [
        [9, 'examples/Hello.yodl', 'HelloSim'],
        [10, 'examples/Euler1.yodl', 'Euler1Sim'],
        [11, 'examples/Clock.yodl', 'ClockSim'],
    ] as const) {
        const visual = compile({
            id,
            source: files[file],
            path: file,
            stage: 'write_low_firrtl',
            files,
            simulate: {
                top,
                clock: 'clk',
                frames: 2,
                frameCycles: 1,
                framebuffer: { width: 40, height: 30, statePrefix: 'pixel', valueMode: 'binary', initSignal: 'rst', initCycles: 1 },
            },
        });
        expect(visual.error).toBeUndefined();
        expect(visual.simulation?.framebuffers).toHaveLength(2);
        expect(visual.simulation?.framebuffers?.[0].pixels.some(pixel => pixel !== 0)).toBe(true);
    }
});

test('pixel matrices from user circuits are rendered automatically', () => {
    const source = 'module Top() -> (pixel: [2][3]u8) { pixel = [[1, 2, 3], [4, 5, 6]]; }';
    const result = compile({ id: 7, source, path: 'examples/Pixel.yodl', stage: 'write_low_firrtl', simulate: { action: 'run' } });
    expect(result.error).toBeUndefined();
    expect(result.simulation?.framebuffers).toHaveLength(1);
    expect(result.simulation?.framebuffers?.[0]).toMatchObject({ width: 3, height: 2 });
    expect(result.simulation?.framebuffers?.[0].pixels).toEqual([1, 2, 3, 4, 5, 6]);
});

test('simulation step actions continue the worker session', () => {
    const source = files['examples/Sim.yodl'];
    const request = (action: 'reset' | 'step_frame' | 'step_cycle') => compile({
        id: 8,
        source,
        path: 'examples/Sim.yodl',
        stage: 'write_low_firrtl',
        files,
        simulate: {
            action,
            top: 'LifeSim',
            clock: 'clk',
            frameCycles: 1,
            framebuffer: { width: 40, height: 30, statePrefix: 'state', initSignal: 'init', initCycles: 1 },
        },
    });
    const reset = request('reset');
    const first = request('step_frame');
    const second = request('step_cycle');
    expect(reset.simulation?.framebuffers?.[0].pixels.filter(pixel => pixel !== 0)).toHaveLength(43);
    expect(first.simulation?.cycles).toBe(1);
    expect(first.simulation?.framebuffers?.[0].pixels).not.toEqual(reset.simulation?.framebuffers?.[0].pixels);
    expect(second.simulation?.cycles).toBe(1);
});

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
    expect(result.simulation?.cycles).toBe(4);
    expect(result.simulation?.framebuffers).toHaveLength(4);
    expect(result.simulation?.framebuffers?.[0].pixels.some(pixel => pixel !== 0)).toBe(true);
});

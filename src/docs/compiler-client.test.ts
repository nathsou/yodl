import { afterEach, expect, test } from 'bun:test';
import { CompilerClient, RealtimeSimulationClient } from '../main/compiler-client.ts';
import { compile, readSimulationMetadata, SimulationSession } from '../main/playground-compiler.ts';
import { files } from '../main/playground-model.ts';

function pixels(frame: any): number[] {
    if (frame.pixels) return frame.pixels;
    if (frame.rgb) return Array.from(frame.rgb);
    return Array.from({ length: frame.width * frame.height }, (_, i) => {
        const row = Math.floor(i / frame.width), col = i % frame.width;
        return (frame.packed[row * Math.ceil(frame.width / 32) + Math.floor(col / 32)] & (1 << (col % 32))) !== 0 ? frame.onColor ?? 0xffffff : frame.offColor ?? 0;
    });
}

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

test('real-time simulation uses a persistent worker control stream', () => {
    globalThis.Worker = FakeWorker as any;
    const client = new RealtimeSimulationClient();
    const events: string[] = [];
    client.start({ ...request, simulate: { action: 'run', display: { width: 2, height: 2, buffer: 'pixel' }, refreshFps: 60, cyclesPerFrame: 1 } }, event => events.push(event.type));
    const worker = FakeWorker.instances[0];
    expect(worker.messages[0].simulate).toMatchObject({ mode: 'realtime', action: 'run' });
    client.pause();
    expect(worker.messages[1].control).toMatchObject({ action: 'pause' });
    client.resume();
    expect(worker.messages[2].control).toMatchObject({ action: 'resume' });
    client.command('step_cycle');
    expect(worker.messages[3]).toMatchObject({ control: { action: 'step_cycle' } });
    expect(worker.messages[3].source).toBeUndefined();
    worker.onmessage?.({ data: { id: worker.messages[0].id, type: 'started' } });
    expect(events).toEqual(['started']);
    client.stop();
    expect(worker.terminated).toBe(true);
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

test('simulation metadata comes from parsed compiler attributes', () => {
    const metadata = readSimulationMetadata({ source: files['examples/GameOfLife.yodl'], path: 'examples/GameOfLife.yodl', files });
    expect(metadata).toMatchObject({
        top: 'GameOfLifeSim',
        reset: { signal: 'init' },
        display: { buffer: 'state' },
    });
    expect(readSimulationMetadata({ source: files['examples/Image.yodl'], path: 'examples/Image.yodl', files })?.cyclesPerFrame).toBeUndefined();
});

test('simulation signals retain their width, exact value and unknown state', () => {
    const wide = compile({
        id: 4,
        source: "module Top() -> (q: u64) {\n  q = 64'h100000000\n}\n",
        path: 'examples/Wide.yodl',
        stage: 'write_low_firrtl',
        simulate: { action: 'reset' },
    });
    expect(wide.error).toBeUndefined();
    expect(wide.simulation?.outputs).toContainEqual({ name: 'q', width: 64, value: '4294967296', known: true });
    const unknown = compile({
        id: 5,
        source: 'module Top(clk: clock) -> (q: u8) {\n  let state = Reg[u8](clk)\n  state.d = state.q\n  q = state.q\n}\n',
        path: 'examples/Unknown.yodl',
        stage: 'write_low_firrtl',
        simulate: { action: 'reset' },
    });
    expect(unknown.simulation?.outputs).toContainEqual({ name: 'q', width: 8, value: '0', known: false });
});

test('an explicit simulation top bypasses ambiguous top inference', () => {
    const source = "module A() -> (q: bool) {\n  q = true\n}\nmodule B() -> (q: bool) {\n  q = false\n}\n";
    const result = compile({ id: 5, source, path: 'examples/Ambiguous.yodl', stage: 'write_low_firrtl', simulate: { action: 'reset', top: 'A' } });
    expect(result.error).toBeUndefined();
    expect(result.simulation?.outputs).toContainEqual({ name: 'q', width: 1, value: '1', known: true });
});

test('simulation preserves unknown muxes and signed dynamic shifts', () => {
    const mux = compile({
        id: 6,
        source: "module Top(clk: clock) -> (q: u8) {\n  let select = Reg[bool](clk)\n  select.d = select.q\n  q = select.q ? 8'd1 : 8'd2\n}\n",
        path: 'examples/UnknownMux.yodl',
        stage: 'write_low_firrtl',
        simulate: { action: 'reset' },
    });
    expect(mux.simulation?.outputs).toContainEqual({ name: 'q', width: 8, value: '0', known: false });
    const shift = compile({
        id: 7,
        source: "module Top(a: s8, n: u3) -> (q: s8) {\n  q = a shr n\n}\n",
        path: 'examples/SignedShift.yodl',
        stage: 'write_low_firrtl',
        simulate: { action: 'reset', inputs: { a: { width: 8, value: -4 }, n: { width: 3, value: 1 } } },
    });
    expect(shift.simulation?.outputs).toContainEqual({ name: 'q', width: 8, value: '254', known: true });
});

test('logical display bindings infer matrix dimensions and pack rows internally', () => {
    const result = compile({
        id: 8,
        source: files['examples/GameOfLife.yodl'],
        path: 'examples/GameOfLife.yodl',
        stage: 'write_low_firrtl',
        files,
        simulate: { action: 'reset', top: 'GameOfLifeSim' },
    });
    expect(result.error).toBeUndefined();
    expect(result.simulation?.metadata?.display?.buffer).toBe('state');
    expect(result.simulation?.framebuffers?.[0]).toMatchObject({ width: 40, height: 30 });
    expect(result.simulation?.framebuffers?.[0].packed).toBeInstanceOf(Uint32Array);
    expect(result.simulation?.framebuffers?.[0].packed).toHaveLength(60);
    expect(pixels(result.simulation?.framebuffers?.[0]).filter(pixel => pixel !== 0)).toHaveLength(43);
});

test('Game of Life simulation returns playable framebuffer frames', () => {
    const source = files['examples/GameOfLife.yodl'];
    const result = compile({
        id: 4,
        source,
        path: 'examples/GameOfLife.yodl',
        stage: 'write_low_firrtl',
        files,
        simulate: {
            top: 'GameOfLifeSim',
            clock: 'clk',
            captureFrames: 4,
            cyclesPerFrame: 1,
            display: { buffer: 'state' },
            reset: { signal: 'init' },
        },
    });
    expect(result.error).toBeUndefined();
    expect(result.simulation?.cycles).toBe(3);
    expect(result.simulation?.framebuffers).toHaveLength(4);
    expect(pixels(result.simulation?.framebuffers?.[0]).some(pixel => pixel !== 0)).toBe(true);
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
            captureFrames: 1,
        },
    });
    expect(image.error).toBeUndefined();
    expect(image.simulation?.framebuffers).toHaveLength(1);
    expect(image.simulation?.framebuffers?.[0]).toMatchObject({ width: 40, height: 30 });
    expect(pixels(image.simulation?.framebuffers?.[0])[0]).toBe(0x6db6ff);
    expect(new Set(pixels(image.simulation?.framebuffers?.[0])).size).toBeGreaterThan(4);

    // ImageSim is a static framebuffer and intentionally has no clock. It
    // remains valid on the one-shot path instead of attempting frame stepping.
    expect(image.simulation?.clock).toBeUndefined();

    for (const [id, file, top, width] of [
        [9, 'examples/Hello.yodl', 'HelloSim', 400],
        [10, 'examples/Euler1.yodl', 'Euler1Sim', 400],
        [11, 'examples/Clock.yodl', 'ClockSim', 400],
    ] as const) {
        const visual = compile({
            id,
            source: files[file],
            path: file,
            stage: 'write_low_firrtl',
            files,
            simulate: {
                top,
                captureFrames: 2,
                cyclesPerFrame: 1,
            },
        });
        expect(visual.error).toBeUndefined();
        expect(visual.simulation?.clock).toBe(top === 'HelloSim' ? undefined : 'clk');
        expect(visual.simulation?.framebuffers).toHaveLength(2);
        expect(visual.simulation?.framebuffers?.[0]).toMatchObject({ width, height: 300 });
        expect(pixels(visual.simulation?.framebuffers?.[0]).some(pixel => pixel !== 0)).toBe(true);
    }
}, 60_000);

test('pixel matrices from user circuits are rendered automatically', () => {
    const source = 'module Top() -> (pixel: [2][3]u8) { pixel = [[1, 2, 3], [4, 5, 6]]; }';
    const result = compile({ id: 7, source, path: 'examples/Pixel.yodl', stage: 'write_low_firrtl', simulate: { action: 'run' } });
    expect(result.error).toBeUndefined();
    expect(result.simulation?.framebuffers).toHaveLength(1);
    expect(result.simulation?.framebuffers?.[0]).toMatchObject({ width: 3, height: 2 });
    expect(pixels(result.simulation?.framebuffers?.[0])).toEqual([1, 2, 3, 4, 5, 6]);
});

test('packed framebuffers reconstruct their declared display size', () => {
    const result = compile({
        id: 12,
        source: '@simulation({ display: { buffer: "pixel", width: 4, height: 2, mode: "binary", packing: "bits32", pixel_scale: 2, on_color: 1193046 } })\nmodule Top() -> (pixel: [1][1]u32) { pixel = [[32\'d3]]; }',
        path: 'examples/Packed.yodl',
        stage: 'write_low_firrtl',
        simulate: {
            top: 'Top',
            captureFrames: 1,
        },
    });
    expect(result.error).toBeUndefined();
    expect(result.simulation?.framebuffers?.[0]).toMatchObject({ width: 4, height: 2 });
    expect(pixels(result.simulation?.framebuffers?.[0])).toEqual(new Array(8).fill(0x123456));
});

test('simulation step actions continue the worker session', () => {
    const source = files['examples/GameOfLife.yodl'];
    const request = (action: 'reset' | 'step_frame' | 'step_cycle') => compile({
        id: 8,
        source,
        path: 'examples/GameOfLife.yodl',
        stage: 'write_low_firrtl',
        files,
        simulate: {
            action,
            top: 'GameOfLifeSim',
            clock: 'clk',
            cyclesPerFrame: 1,
            display: { buffer: 'state' },
            reset: { signal: 'init' },
        },
    });
    const reset = request('reset');
    const first = request('step_frame');
    const second = request('step_cycle');
    expect(pixels(reset.simulation?.framebuffers?.[0]).filter(pixel => pixel !== 0)).toHaveLength(43);
    expect(first.simulation?.cycles).toBe(1);
    expect(pixels(first.simulation?.framebuffers?.[0])).not.toEqual(pixels(reset.simulation?.framebuffers?.[0]));
    expect(second.simulation?.cycles).toBe(1);
});


test('Noise exposes complete framebuffer frames with successive LFSR samples', () => {
    const path = 'examples/Noise.yodl';
    const session = new SimulationSession({ id: 90, source: files[path], files, path, stage: 'write_low_firrtl', simulate: {} });
    expect(session.stream).toBe(false);
    const first = session.snapshot().framebuffers![0];
    expect(first).toMatchObject({ signal: 'pixel', width: 80, height: 60 });
    let random = 0;
    const expectedFrame = () => Array.from({ length: first.width * first.height }, () => {
        const channel = (bits: number) => (bits << 5) | (bits << 2) | (bits >>> 1);
        const color = (channel(random & 7) << 16) | (channel((random >>> 3) & 7) << 8) | channel((random >>> 6) & 7);
        const feedback = 1 ^ ((random >>> 31) & 1) ^ ((random >>> 21) & 1) ^ ((random >>> 1) & 1) ^ (random & 1);
        random = ((random << 1) | feedback) >>> 0;
        return color;
    });
    const expectedFirst = expectedFrame();
    expect(Array.from(first.rgb!)).toEqual(expectedFirst);
    expect(first.valid!.every(value => value === 0xffffffff)).toBe(true);
    expect(session.advance(1)).toBe(1);
    const second = session.snapshot().framebuffers![0];
    expect(Array.from(second.rgb!)).toEqual(expectedFrame());
    expect(second.rgb).not.toEqual(first.rgb);
    expect(second.valid!.every(value => value === 0xffffffff)).toBe(true);
    session.reset();
    expect(Array.from(session.snapshot().framebuffers![0].rgb!)).toEqual(expectedFirst);
}, 30_000);

test('typed displays select the requested shape, preserve black RGB and reject name heuristics', () => {
    const source = `@simulation({display: { buffer: "image" }})
module Top() -> (pixel: [1][1]bool, image: [2][3]u24, state_count: u8) {
    pixel = [[true]]
    image = [[0, 0, 0], [0, 0, 0]]
    state_count = 7
}`;
    const result = compile({ ...request, id: 91, source, simulate: {} });
    expect(result.error).toBeUndefined();
    expect(result.simulation!.framebuffers![0]).toMatchObject({ width: 3, height: 2 });
    expect(result.simulation!.framebuffers![0].rgb).toEqual(new Uint32Array(6));
    expect(result.simulation!.outputs.some(s => s.name === 'state_count')).toBe(true);
    const fake = compile({ ...request, id: 92, source: 'module Top() -> (pixel_0_0: bool) { pixel_0_0 = true; }', simulate: {} });
    expect(fake.simulation!.framebuffers).toEqual([]);
});

test('binary rendering packs integer pixels by value rather than storage layout', () => {
    const source = `@simulation({display: { buffer: "pixel" }})
module Top() -> (pixel: [1][2]u8) { pixel = [[1, 1]]; }`;
    const result = compile({ ...request, id: 921, source, simulate: { display: { buffer: 'pixel', valueMode: 'binary' } } });
    expect(result.error).toBeUndefined();
    const frame = result.simulation!.framebuffers![0];
    expect(frame.packed).toEqual(new Uint32Array([3]));
    expect(frame.valid).toEqual(new Uint32Array([3]));
});

test('settling inputs refreshes packed displays and retains unknown validity', () => {
    const source = `@simulation({display: { buffer: "pixel" }})
module Top(clk: clock, a: bool) -> (pixel: [1][33]bool) {
    let uninitialized = Reg[bool](clk)
    uninitialized.d = uninitialized.q
    for x in 0..<33 { pixel[0][x] = a; }
}`;
    const session = new SimulationSession({ ...request, id: 93, source, simulate: {} });
    session.setInputs({ a: { width: 1, value: 1 } });
    const frame = session.snapshot().framebuffers![0];
    expect(frame.packed).toEqual(new Uint32Array([0xffffffff, 1]));
    expect(frame.pixels).toBeUndefined();
    expect(session.snapshot().outputs).toEqual([]);
    const unknown = compile({ ...request, id: 94, source: source.replace('pixel[0][x] = a', 'pixel[0][x] = uninitialized.q'), simulate: {} });
    expect(unknown.simulation!.framebuffers![0].valid).toEqual(new Uint32Array(2));
    expect(unknown.simulation!.messages.join(' ')).toContain('unknown');
});

test('metadata diagnostics include the attribute location', () => {
    const result = compile({ ...request, id: 95, source: '@simulation({frame_cylces: 1})\nmodule Top() -> () {}', simulate: {} });
    expect(result.error).toContain('frame_cylces');
    expect(result.error).toContain('examples/Top.yodl');
});

test('pixel stream frame boundaries preserve the completed image and exact cycle count', () => {
    const source = `@simulation({display: {stream: "video", width: 4, height: 1}, reset: "rst"})
module Top(clk: clock, rst: bool) -> (video: (x: u2, y: u1, valid: bool, r: u1, g: u1, b: u1)) {
    let count = Reg[u8](clk, rst)
    count.d = count.q + 1
    video = (x: count.q[1:0], y: 0, valid: true, r: count.q[0], g: count.q[2], b: false)
}`;
    const session = new SimulationSession({ ...request, id: 97, source, simulate: {} });
    expect(session.advance(100, true)).toBe(4);
    expect(session.frames).toBe(1);
    expect(session.snapshot().framebuffers![0].rgb).toEqual(new Uint32Array([0, 0xff0000, 0, 0xff0000]));
    expect(session.advance(100, true)).toBe(4);
    expect(session.frames).toBe(2);
    expect(session.snapshot().framebuffers![0].rgb).toEqual(new Uint32Array([0x00ff00, 0xffff00, 0x00ff00, 0xffff00]));
});

test('display descriptors survive flattened-name collisions', () => {
    const result = compile({ ...request, id: 98, source: `@simulation({display: { buffer: "pixel" }})
module Top() -> (pixel_0: bool, pixel: [1][2]bool) {
    pixel_0 = false
    pixel = [[true, false]]
}`, simulate: {} });
    expect(result.error).toBeUndefined();
    expect(result.simulation!.framebuffers![0].packed).toEqual(new Uint32Array([1]));
    expect(result.simulation!.outputs).toContainEqual({ name: 'pixel_0', width: 1, value: '0', known: true });
});


test('all graphical examples use the same display annotation object', () => {
    for (const name of ['Noise', 'GameOfLife', 'Image', 'Hello', 'Clock', 'Euler1']) {
        const path = `examples/${name}.yodl`;
        const metadata = readSimulationMetadata({ path, source: files[path], files });
        expect(metadata?.display?.buffer).toBe(name === 'GameOfLife' ? 'state' : 'pixel');
        expect(metadata).not.toHaveProperty('framebuffer');
    }
});

test('simulation accepts only the display object syntax', () => {
    for (const options of [
        'display: "pixel"',
        'framebuffer: { buffer: "pixel", width: 1, height: 1 }',
        'display: { state_prefix: "pixel" }',
        'display: {}',
        'display: { signal: "pixel" }',
        'display: { buffer: "pixel", packing: "bits32" }',
    ]) {
        const source = `@simulation({ ${options} })\nmodule Top() -> (pixel: [1][1]bool) { pixel = [[true]]; }`;
        const result = compile({ ...request, id: 99, source, simulate: {} });
        expect(result.error).toBeDefined();
        expect(result.error).toContain('examples/Top.yodl');
    }
});

test('capture count is a run option and cycles_per_frame is a positive design interval', () => {
    const source = `@simulation({display: {buffer: "pixel"}, reset: "rst", cycles_per_frame: 3})
module Top(clk: clock, rst: bool) -> (pixel: [1][1]u24) {
    let count = Reg[u24](clk, rst)
    count.d = count.q + 1
    pixel = [[count.q]]
}`;
    const result = compile({ ...request, id: 200, source, simulate: { captureFrames: 4 } });
    expect(result.error).toBeUndefined();
    expect(result.simulation!.cycles).toBe(9);
    expect(result.simulation!.framebuffers!.map(frame => frame.rgb![0])).toEqual([0, 3, 6, 9]);
    expect(result.simulation!.metadata).not.toHaveProperty('captureFrames');
    expect(result.simulation!.metadata).not.toHaveProperty('refreshFps');
    const staticCapture = compile({ ...request, id: 201, source: 'module Top() -> (pixel: [1][1]u24) { pixel = [[7]]; }', simulate: { captureFrames: 2 } });
    expect(staticCapture.error).toBeUndefined();
    expect(staticCapture.simulation!.cycles).toBe(0);
    expect(staticCapture.simulation!.framebuffers!.map(frame => frame.rgb![0])).toEqual([7, 7]);
});

test('obsolete timing annotations and zero frame intervals are rejected', () => {
    for (const setting of ['frames: 1', 'frame_cycles: 0', 'frame_rate: 1', 'refresh_fps: 30', 'cycles_per_frame: 0']) {
        const result = compile({ ...request, id: 202, source: `@simulation({${setting}})\nmodule Top() -> () {}`, simulate: {} });
        expect(result.error).toBeDefined();
        expect(result.error).toContain('examples/Top.yodl');
    }
});


test('source tabs receive only files actually read, including transitive imports and shared overrides', () => {
    const source = 'import A\nmodule Top() -> () {}';
    const dependency = 'import B\nmodule A() -> () {}';
    const leaf = 'module B() -> () {}';
    const request = { id: 500, path: 'examples/Main.yodl', source, stage: 'write_source' as const, files: {
        'examples/Main.yodl': 'stale entry',
        'examples/lib/A.yodl': dependency,
        'examples/lib/B.yodl': leaf,
        'examples/lib/Unused.yodl': 'invalid unused file',
    } };
    const result = compile(request);
    expect(result.error).toBeUndefined();
    expect(result.sources).toEqual({ 'examples/Main.yodl': source, 'examples/lib/A.yodl': dependency, 'examples/lib/B.yodl': leaf });
    const invalid = 'module B() -> (q: bool) { q = missing }';
    const failed = compile({ ...request, stage: 'write_firrtl', files: { ...request.files, 'examples/lib/B.yodl': invalid } });
    expect(failed.error).toBeDefined();
    expect(failed.sources?.['examples/lib/B.yodl']).toBe(invalid);
    const fresh = compile({ ...request, source: 'module Top() -> () {}' });
    expect(Object.keys(fresh.sources!)).toEqual(['examples/Main.yodl']);
});

test('GameOfLife is the sole Game of Life example and simulation exposes its loaded source', () => {
    expect(files['examples/Sim.yodl']).toBeUndefined();
    const path = 'examples/GameOfLife.yodl';
    const session = new SimulationSession({ id: 501, path, source: files[path], files, stage: 'write_low_firrtl' });
    expect(session.sources[path]).toBe(files[path]);
    expect(session.metadata.top).toBe('GameOfLifeSim');
});

test('batch capture retains final scalar state and messages from every frame', () => {
    const result = compile({
        id: 901, path: 'Capture.yodl', stage: 'write_firrtl',
        source: `module Top(clk: clock, rst: bool) -> (q: u8, pixel: [1][1]u24) {
            let r = RegAsyncReset[u8](clk, rst: rst)
            r.d = r.q + 1'b1
            q = r.q
            pixel[0][0] = r.q
            printf!("counter %d", r.q)
        }`,
        simulate: { reset: { signal: 'rst' }, captureFrames: 3 },
    });
    expect(result.error).toBeUndefined();
    const simulation = result.simulation!;
    expect(simulation.cycles).toBe(2);
    expect(simulation.outputs.find(signal => signal.name === 'q')?.value).toBe('2');
    expect(simulation.framebuffers!.map(frame => Array.from(frame.rgb!))).toEqual([[0], [1], [2]]);
    expect(simulation.messages).toEqual(['counter 0', 'counter 0', 'counter 1']);
});

import { SimulationSession } from '../src/main/playground-compiler.ts';
import type { CompileRequest } from '../src/main/playground-compiler.ts';

const request = (path: string, source: string, files: Record<string, string> = {}, simulate: CompileRequest['simulate'] = {}): CompileRequest =>
    ({ id: 1, path, source, files, stage: 'write_firrtl', simulate });

function measure(name: string, cycles: number, create: () => SimulationSession) {
    const compileStarted = performance.now();
    const session = create();
    const compileMs = performance.now() - compileStarted;
    const executeStarted = performance.now();
    const advanced = session.advanceCycles(cycles).cycles;
    const executeMs = performance.now() - executeStarted;
    const frameStarted = performance.now();
    session.snapshot();
    const framebufferMs = performance.now() - frameStarted;
    console.log(JSON.stringify({ name, compileMs, cycles: advanced, executeMs, cyclesPerSecond: advanced * 1000 / executeMs, framebufferMs }));
}

measure('scalar-counter', 10_000, () => new SimulationSession(request('Counter.yodl', `module Top(clk: clock, rst: bool) -> (q: u32) {
    let state = Reg[u32](clk, rst)
    state.d = state.q + 1
    q = state.q
}`, {}, { reset: { signal: 'rst' } })));

measure('repeated-hierarchy', 2_000, () => new SimulationSession(request('Hierarchy.yodl', `module Counter(clk: clock, rst: bool) -> (q: u16) {
    let state = Reg[u16](clk, rst)
    state.d = state.q + 1
    q = state.q
}
module Top(clk: clock, rst: bool) -> (q: u16) {
    let a = Counter(clk, rst)
    let b = Counter(clk, rst)
    let c = Counter(clk, rst)
    let d = Counter(clk, rst)
    q = a.q + b.q + c.q + d.q
}`, {}, { reset: { signal: 'rst' } })));

for (const depth of [16, 256, 4096]) {
    const width = depth === 16 ? 4 : depth === 256 ? 8 : 12;
    measure(`memory-${depth}`, 2_000, () => new SimulationSession(request(`Memory${depth}.yodl`, `module Top(clk: clock, addr: u${width}, data: u32) -> (q: u32) {
    let mem = Memory[T: u32, Depth: ${depth}, ReadPorts: 1, WritePorts: 1, ReadLatency: 0, WriteLatency: 1](
        read: [(clk: clk, en: true, addr: addr)],
        write: [(clk: clk, en: true, addr: addr, data: data, mask: true)])
    q = mem.q[0]
}`, {}, { inputs: { addr: { width, value: depth - 1 }, data: { width: 32, value: 42 } } })));
}

measure('memory-4096-two-port', 2_000, () => new SimulationSession(request('MemoryTwoPort.yodl', `module Top(clk: clock, addr: u12, data: u32) -> (q: u32) {
    let mem = Memory[T: u32, Depth: 4096, ReadPorts: 2, WritePorts: 2, ReadLatency: 0, WriteLatency: 1](
        read: [(clk: clk, en: true, addr: addr), (clk: clk, en: true, addr: addr)],
        write: [(clk: clk, en: true, addr: addr, data: data, mask: true), (clk: clk, en: false, addr: addr, data: data, mask: true)])
    q = mem.q[0] + mem.q[1]
}`, {}, { inputs: { addr: { width: 12, value: 4095 }, data: { width: 32, value: 42 } } })));

measure('pixel-stream', 2_000, () => new SimulationSession(request('Stream.yodl', `@simulation({display: {stream: "video", width: 4, height: 1}, reset: "rst"})
module Top(clk: clock, rst: bool) -> (video: (x: u2, y: u1, valid: bool, r: u1, g: u1, b: u1)) {
    let count = Reg[u8](clk, rst)
    count.d = count.q + 1
    video = (x: count.q[1:0], y: 0, valid: true, r: count.q[0], g: false, b: false)
}`)));

const gameOfLife = await Bun.file(new URL('../examples/GameOfLife.yodl', import.meta.url)).text();
measure('game-of-life', 10, () => new SimulationSession(request('examples/GameOfLife.yodl', gameOfLife, {}, {
    top: 'GameOfLifeSim', reset: { signal: 'init' }, display: { buffer: 'state' }, cyclesPerFrame: 1,
})));

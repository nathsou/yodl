import { unwrap, yodl, ext, createInMemoryFileSystem } from './yodl.ts';
import {
    simulator_new,
    simulator_poke_int,
    simulator_step,
    simulator_clocks,
    simulator_settle,
    simulator_messages,
    simulator_outputs,
} from '../../_build/js/release/build/lib/simulator/simulator.js';
import type { Stage } from './compiler-stages.ts';

export type SimulationRequest = {
    action?: 'run' | 'reset' | 'step_cycle' | 'step_frame';
    top?: string;
    clock?: string;
    cycles?: number;
    inputs?: Record<string, { width: number; value: number }>;
    frames?: number;
    frameCycles?: number;
    framebuffer?: {
        width: number;
        height: number;
        statePrefix: string;
        initSignal?: string;
        initCycles?: number;
        valueMode?: 'binary' | 'gray' | 'rgb';
        onColor?: number;
        offColor?: number;
    };
};
export type CompileRequest = { id: number; source: string; path: string; stage: Stage; files?: Record<string, string>; simulate?: SimulationRequest };
export type SimulationFramebuffer = { width: number; height: number; pixels: number[] };
export type SimulationResult = { outputs: Record<string, number>; messages: string[]; cycles: number; clock?: string; framebuffers?: SimulationFramebuffer[] };
export type CompileResult = { id: number; output?: string; error?: string; duration: number; simulation?: SimulationResult };

type SimulationSession = {
    key: string;
    machine: any;
    clock?: string;
    framebuffer?: SimulationRequest['framebuffer'];
};
let simulationSession: SimulationSession | undefined;

function readSimulationOutputs(machine: any): Record<string, number> {
    const values: Record<string, number> = {};
    for (const pair of (simulator_outputs(machine) as Array<{ _0: string; _1: number }>)) values[pair._0] = pair._1;
    return values;
}

function inferFramebuffer(values: Record<string, number>): SimulationRequest['framebuffer'] | undefined {
    const candidates = new Map<string, { width: number; height: number; max: number }>();
    for (const [name, value] of Object.entries(values)) {
        const match = /^(.*)_([0-9]+)_([0-9]+)$/.exec(name);
        if (!match) continue;
        const prefix = match[1];
        const row = Number(match[2]);
        const col = Number(match[3]);
        const current = candidates.get(prefix) ?? { width: 0, height: 0, max: 0 };
        current.width = Math.max(current.width, col + 1);
        current.height = Math.max(current.height, row + 1);
        current.max = Math.max(current.max, value >>> 0);
        candidates.set(prefix, current);
    }
    const preferred = ['pixel', 'pixels', 'framebuffer', 'state'];
    const prefix = preferred.find(name => candidates.has(name)) ?? [...candidates.keys()].find(name => candidates.get(name)!.width * candidates.get(name)!.height > 1);
    if (!prefix) return undefined;
    const shape = candidates.get(prefix)!;
    return {
        width: shape.width,
        height: shape.height,
        statePrefix: prefix,
        valueMode: shape.max <= 1 ? 'binary' : 'rgb',
    };
}

function simulationFramebuffer(values: Record<string, number>, framebuffer: SimulationRequest['framebuffer']): SimulationFramebuffer | undefined {
    if (!framebuffer) return undefined;
    const pixels = new Array(framebuffer.width * framebuffer.height).fill(framebuffer.offColor ?? 0);
    const prefix = `${framebuffer.statePrefix}_`;
    for (const [name, value] of Object.entries(values)) {
        if (!name.startsWith(prefix) || value === 0) continue;
        const parts = name.slice(prefix.length).split('_');
        if (parts.length !== 2) continue;
        const row = Number(parts[0]);
        const col = Number(parts[1]);
        if (Number.isInteger(row) && Number.isInteger(col) && row >= 0 && row < framebuffer.height && col >= 0 && col < framebuffer.width) {
            const color = framebuffer.valueMode === 'rgb'
                ? value & 0xffffff
                : framebuffer.valueMode === 'gray'
                    ? ((value & 0xff) * 0x010101) & 0xffffff
                    : framebuffer.onColor ?? 0xffffff;
            pixels[row * framebuffer.width + col] = color;
        }
    }
    return { width: framebuffer.width, height: framebuffer.height, pixels };
}

export function compile(request: CompileRequest): CompileResult {
    const started = performance.now();
    let output = '';
    try {
        // Each request starts with pristine dependencies. Editing an example
        // must not change imports in a different example compiled afterwards.
        const fs = createInMemoryFileSystem({ ...request.files, [request.path]: request.source });
        unwrap(fs.write_string_to_file(request.path, request.source));
        if (request.simulate) {
            const simulate = request.simulate;
            const action = simulate.action ?? 'run';
            const top = simulate.top;
            const topOption = top === undefined ? { $tag: 0 } : { $tag: 1, _0: top };
            const key = JSON.stringify({
                path: request.path,
                source: request.source,
                files: request.files ?? {},
                top: simulate.top ?? null,
                clock: simulate.clock ?? null,
                inputs: simulate.inputs ?? {},
                framebuffer: simulate.framebuffer ?? null,
            });
            const reuse = action !== 'run' && action !== 'reset' && simulationSession?.key === key;
            if (!reuse) {
                const circuit = unwrap(yodl.compile_simulation(request.path, { ...ext, fs, println: () => {} }, topOption));
                const machine = unwrap(simulator_new(circuit, simulate.top ?? ''));
                for (const [name, input] of Object.entries(simulate.inputs ?? {})) {
                    unwrap(simulator_poke_int(machine, name, input.width, input.value));
                }
                unwrap(simulator_settle(machine));
                const clocks = simulator_clocks(machine) as string[];
                const clock = simulate.clock || clocks[0];
                if (simulate.framebuffer?.initSignal) {
                    if (!clock) throw new Error('framebuffer simulation requires a clock');
                    unwrap(simulator_poke_int(machine, simulate.framebuffer.initSignal, 1, 1));
                    for (let i = 0; i < Math.max(0, simulate.framebuffer.initCycles ?? 1); i++) unwrap(simulator_step(machine, clock));
                    unwrap(simulator_poke_int(machine, simulate.framebuffer.initSignal, 1, 0));
                    unwrap(simulator_settle(machine));
                }
                const framebuffer = simulate.framebuffer ?? inferFramebuffer(readSimulationOutputs(machine));
                simulationSession = { key, machine, clock, framebuffer };
            }
            const session = simulationSession!;
            const machine = session.machine;
            const clock = session.clock;
            const framebuffer = session.framebuffer;
            const cycles = Math.max(0, Math.min(100000, simulate.cycles ?? 1));
            const frameCount = Math.max(1, Math.min(600, simulate.frames ?? 1));
            const frameCycles = Math.max(0, Math.min(100000, simulate.frameCycles ?? cycles));
            const framebuffers: SimulationFramebuffer[] = [];
            let simulatedCycles = 0;
            if (action === 'step_cycle') {
                if (!clock) throw new Error('framebuffer simulation requires a clock');
                unwrap(simulator_step(machine, clock));
                simulatedCycles = 1;
            } else if (action === 'step_frame') {
                if (!clock) throw new Error('frame stepping requires a clock');
                for (let cycle = 0; cycle < Math.max(1, frameCycles); cycle++) unwrap(simulator_step(machine, clock));
                simulatedCycles = Math.max(1, frameCycles);
            } else if (action === 'run' && framebuffer) {
                for (let frame = 0; frame < frameCount; frame++) {
                    if (frame > 0 && frameCycles > 0) {
                        if (!clock) throw new Error('framebuffer simulation requires a clock for multiple frames');
                        for (let cycle = 0; cycle < frameCycles; cycle++) unwrap(simulator_step(machine, clock));
                        simulatedCycles += frameCycles;
                    }
                    const image = simulationFramebuffer(readSimulationOutputs(machine), framebuffer);
                    if (image) framebuffers.push(image);
                }
            } else if (action === 'run' && clock) {
                for (let cycle = 0; cycle < cycles; cycle++) unwrap(simulator_step(machine, clock));
                simulatedCycles = cycles;
            }
            const outputs = readSimulationOutputs(machine);
            const detectedFramebuffer = framebuffer ?? inferFramebuffer(outputs);
            if (action === 'reset' && detectedFramebuffer) {
                const frame = simulationFramebuffer(outputs, detectedFramebuffer);
                if (frame) framebuffers.push(frame);
            } else if ((action === 'step_cycle' || action === 'step_frame') && detectedFramebuffer) {
                const frame = simulationFramebuffer(outputs, detectedFramebuffer);
                if (frame) framebuffers.push(frame);
            } else if (action === 'run' && !framebuffer && detectedFramebuffer) {
                const frame = simulationFramebuffer(outputs, detectedFramebuffer);
                if (frame) framebuffers.push(frame);
            }
            return {
                id: request.id,
                duration: performance.now() - started,
                simulation: { outputs, messages: simulator_messages(machine) as string[], cycles: simulatedCycles, ...(clock ? { clock } : {}), ...((framebuffer || detectedFramebuffer) ? { framebuffers } : {}) },
            };
        }
        const commands = unwrap(yodl.parse_commands(request.stage));
        unwrap(yodl.run(request.path, commands, { ...ext, fs, println: (text: string) => { output += text; } }));
        return { id: request.id, output, duration: performance.now() - started };
    } catch (error) {
        // unwrap serialises the MoonBit error. Retain the rendered message,
        // including the source span and excerpt, without escaped JSON newlines.
        let value: any = error instanceof Error ? error.message : error;
        if (typeof value === 'string') {
            try { value = JSON.parse(value); } catch { /* Already plain text. */ }
        }
        const message = typeof value === 'string' ? value : value?._0 ?? value?.message ?? String(value);
        return { id: request.id, error: String(message), duration: performance.now() - started };
    }
}

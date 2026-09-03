import { unwrap, yodl, ext, createInMemoryFileSystem } from './yodl.ts';
import {
    simulator_new,
    simulator_poke_int,
    simulator_peek_int,
    simulator_step,
    simulator_clocks,
    simulator_settle,
    simulator_messages,
    simulator_outputs,
} from '../../_build/js/release/build/lib/simulator/simulator.js';
import type { Stage } from './compiler-stages.ts';

export type SimulationRequest = {
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
        onColor?: number;
        offColor?: number;
    };
};
export type CompileRequest = { id: number; source: string; path: string; stage: Stage; files?: Record<string, string>; simulate?: SimulationRequest };
export type SimulationFramebuffer = { width: number; height: number; pixels: number[] };
export type SimulationResult = { outputs: Record<string, number>; messages: string[]; cycles: number; framebuffers?: SimulationFramebuffer[] };
export type CompileResult = { id: number; output?: string; error?: string; duration: number; simulation?: SimulationResult };

export function compile(request: CompileRequest): CompileResult {
    const started = performance.now();
    let output = '';
    try {
        // Each request starts with pristine dependencies. Editing an example
        // must not change imports in a different example compiled afterwards.
        const fs = createInMemoryFileSystem({ ...request.files, [request.path]: request.source });
        unwrap(fs.write_string_to_file(request.path, request.source));
        if (request.simulate) {
            const top = request.simulate.top;
            const topOption = top === undefined ? { $tag: 0 } : { $tag: 1, _0: top };
            const circuit = unwrap(yodl.compile_simulation(request.path, { ...ext, fs, println: () => {} }, topOption));
            const machine = unwrap(simulator_new(circuit, request.simulate.top ?? ''));
            for (const [name, input] of Object.entries(request.simulate.inputs ?? {})) {
                unwrap(simulator_poke_int(machine, name, input.width, input.value));
            }
            unwrap(simulator_settle(machine));
            const cycles = request.simulate.cycles ?? 1;
            const clocks = simulator_clocks(machine) as string[];
            const clock = request.simulate.clock || clocks[0];
            const framebuffer = request.simulate.framebuffer;
            if (!framebuffer && clock) {
                for (let cycle = 0; cycle < cycles; cycle++) unwrap(simulator_step(machine, clock));
            }
            const outputs: Record<string, number> = {};
            const readOutputs = () => {
                const values: Record<string, number> = {};
                for (const pair of (simulator_outputs(machine) as Array<{ _0: string; _1: number }>)) values[pair._0] = pair._1;
                return values;
            };
            const frameCount = Math.max(1, Math.min(600, request.simulate.frames ?? 1));
            const frameCycles = Math.max(0, Math.min(100000, request.simulate.frameCycles ?? cycles));
            const framebuffers: SimulationFramebuffer[] = [];
            if (framebuffer?.initSignal) {
                if (!clock) throw new Error('framebuffer simulation requires a clock');
                unwrap(simulator_poke_int(machine, framebuffer.initSignal, 1, 1));
                for (let i = 0; i < (framebuffer.initCycles ?? 1); i++) unwrap(simulator_step(machine, clock));
                unwrap(simulator_poke_int(machine, framebuffer.initSignal, 1, 0));
            }
            const framebufferFromOutputs = (values: Record<string, number>): SimulationFramebuffer => {
                const pixels = new Array(framebuffer!.width * framebuffer!.height).fill(framebuffer!.offColor ?? 0);
                const prefix = `${framebuffer!.statePrefix}_`;
                for (const [name, value] of Object.entries(values)) {
                    if (!name.startsWith(prefix) || value === 0) continue;
                    const parts = name.slice(prefix.length).split('_');
                    if (parts.length !== 2) continue;
                    const row = Number(parts[0]);
                    const col = Number(parts[1]);
                    if (Number.isInteger(row) && Number.isInteger(col) && row >= 0 && row < framebuffer!.height && col >= 0 && col < framebuffer!.width) {
                        pixels[row * framebuffer!.width + col] = framebuffer!.onColor ?? 0xffffff;
                    }
                }
                return { width: framebuffer!.width, height: framebuffer!.height, pixels };
            };
            if (framebuffer) {
                if (!clock) throw new Error('framebuffer simulation requires a clock');
                for (let frame = 0; frame < frameCount; frame++) {
                    for (let cycle = 0; cycle < frameCycles; cycle++) unwrap(simulator_step(machine, clock));
                    framebuffers.push(framebufferFromOutputs(readOutputs()));
                }
            }
            Object.assign(outputs, readOutputs());
            return {
                id: request.id,
                duration: performance.now() - started,
                simulation: { outputs, messages: simulator_messages(machine) as string[], cycles: clock ? (framebuffer ? frameCount * frameCycles : cycles) : 0, ...(framebuffer ? { framebuffers } : {}) },
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

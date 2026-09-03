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
};
export type CompileRequest = { id: number; source: string; path: string; stage: Stage; files?: Record<string, string>; simulate?: SimulationRequest };
export type SimulationResult = { outputs: Record<string, number>; messages: string[]; cycles: number };
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
            const circuit = unwrap(yodl.compile_simulation(request.path, { ...ext, fs, println: () => {} }));
            const machine = unwrap(simulator_new(circuit, request.simulate.top ?? 'Top'));
            for (const [name, input] of Object.entries(request.simulate.inputs ?? {})) {
                unwrap(simulator_poke_int(machine, name, input.width, input.value));
            }
            unwrap(simulator_settle(machine));
            const cycles = request.simulate.cycles ?? 1;
            const clocks = simulator_clocks(machine) as string[];
            const clock = request.simulate.clock || clocks[0];
            if (clock) {
                for (let cycle = 0; cycle < cycles; cycle++) unwrap(simulator_step(machine, clock));
            }
            const outputs: Record<string, number> = {};
            for (const pair of (simulator_outputs(machine) as Array<{ _0: string; _1: number }>)) outputs[pair._0] = pair._1;
            return {
                id: request.id,
                duration: performance.now() - started,
                simulation: { outputs, messages: simulator_messages(machine) as string[], cycles: clock ? cycles : 0 },
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

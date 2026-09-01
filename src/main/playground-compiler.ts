import { unwrap, yodl, ext, createInMemoryFileSystem } from './yodl.ts';
import { files } from './playground-model.ts';
import type { Stage } from './playground-model.ts';

export type CompileRequest = { id: number; source: string; path: string; stage: Stage };
export type CompileResult = { id: number; output?: string; error?: string; duration: number };

export function compile(request: CompileRequest): CompileResult {
    const started = performance.now();
    let output = '';
    try {
        // Each request starts with pristine dependencies. Editing an example
        // must not change imports in a different example compiled afterwards.
        const fs = createInMemoryFileSystem(files);
        unwrap(fs.write_string_to_file(request.path, request.source));
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

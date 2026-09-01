import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { loadChapters } from './content.ts';
import { compile } from '../main/playground-compiler.ts';
import { stages } from '../main/compiler-stages.ts';
import type { Stage } from '../main/compiler-stages.ts';

const backend = process.argv.includes('--backend');
const directory = await mkdtemp(join(tmpdir(), 'yodl-docs-'));
let count = 0;
try {
    for (const chapter of loadChapters()) for (const example of chapter.examples) {
        if (example.expect === 'skip') continue;
        const label = `${chapter.slug}.md:${example.line} (${example.id})`;
        // Expected errors are checked at the authored stage; valid examples
        // must also work at every stage available in the editor.
        const checkedStages = example.expect === 'error' ? [example.stage] : Object.keys(stages) as Stage[];
        let low = '';
        for (const stage of checkedStages) {
            const result = compile({ id: ++count, source: example.source, path: example.path, files: example.files, stage });
            if (example.expect === 'error') {
                if (!result.error || (example.diagnostic && !result.error.includes(example.diagnostic))) throw new Error(`${label}: expected diagnostic ${example.diagnostic ?? '(any)'}, got ${result.error ?? 'success'}`);
            } else if (example.unsupported.includes(stage)) {
                if (!result.error) throw new Error(`${label}: ${stage} now succeeds; remove its unsupported annotation`);
            } else if (result.error !== undefined) throw new Error(`${label} at ${stage}:\n${result.error}`);
            if (stage === 'write_low_firrtl') low = result.output ?? '';
        }
        if (backend && example.expect === 'success') {
            const input = join(directory, 'example.fir');
            await writeFile(input, low);
            const result = Bun.spawnSync(['firtool', '--format=fir', '-O=debug', '--verilog', input, '-o', join(directory, 'example.sv')]);
            if (result.exitCode !== 0) throw new Error(`${label}: firtool failed\n${result.stderr.toString()}`);
        }
    }
    console.log(`Validated ${count} documentation compiler cases${backend ? ' and FIRRTL backend output' : ''}.`);
} finally {
    await rm(directory, { recursive: true, force: true });
}

import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { compile } from '../src/main/playground-compiler.ts';
import { files, tour, examples, stages, encodeShare, decodeShare, diagnosticLocation, validSelection } from '../src/main/playground-model.ts';
import type { Stage } from '../src/main/playground-model.ts';

assert.equal(new Set(tour.map(lesson => lesson.id)).size, tour.length, 'Lesson IDs must be unique');
assert.deepEqual(tour.map(lesson => lesson.file).sort(), readdirSync('tour').filter(name => name.endsWith('.yodl')).sort(), 'Every tour source must have a lesson');
assert.ok(examples.every(path => path.startsWith('examples/')));
const ids = new Set([...readFileSync('src/main/playground.html', 'utf8').matchAll(/id="([^"]+)"/g)].map(match => match[1]));
const app = readFileSync('src/main/playground.ts', 'utf8');
for (const match of app.matchAll(/(?:element(?:<[^>]+>)?|button|select)\('([^']+)'\)/g)) {
    assert.ok(ids.has(match[1]), `Missing UI element: ${match[1]}`);
}
for (const lesson of tour) {
    const path = `tour/${lesson.file}`;
    assert.ok(validSelection({ mode: 'tour', path, stage: lesson.stage }));
    assert.ok(lesson.intro && lesson.observe && lesson.challenge && lesson.concepts.length);
    for (const stage of Object.keys(stages) as Stage[]) {
        const result = compile({ id: 1, path, source: files[path], stage });
        assert.equal(result.error, undefined, `${lesson.id}/${stage}: ${result.error}`);
        assert.ok(result.output?.trim(), `Empty output for ${lesson.id}/${stage}`);
    }
}

// Check that each suggested experiment remains a valid, editable circuit.
const challenges: Record<string, (source: string) => string> = {
    gates: source => source.replace('a and b', 'a xor b'),
    widths: source => source.replace('sum: u9', 'sum: u8'),
    selection: source => source.replace('        _ => 0', '        2 => a xor b\n        _ => 0'),
    bits: source => source.replace('cat!(low, high)', 'cat!(low, low)'),
    vectors: source => source.replace('Lanes = 4', 'Lanes = 8'),
    records: source => source.replace('(..color, g: 0)', '(..color, g: 0, b: 0)'),
    modules: source => source.replace('Adder(a: b, b: c)', 'Adder(a: a, b: c)'),
    generics: source => source.replaceAll('u16', 'u12').replace('Mask[16]', 'Mask[12]'),
    registers: source => source.replace('en: enable', 'en: true'),
    counter: source => source.replace('Limit = 10', 'Limit = 16'),
    packages: source => source.replace('q = inverter.q', 'let second = Logic::Invert(value: inverter.q)\n    q = second.q'),
    memory: source => source.replace('Depth: 16', 'Depth: 32').replace('addr: u4', 'addr: u5'),
};
for (const lesson of tour) {
    const path = `tour/${lesson.file}`;
    const result = compile({ id: 2, path, source: challenges[lesson.id](files[path]), stage: 'write_low_firrtl' });
    assert.equal(result.error, undefined, `Challenge ${lesson.id}: ${result.error}`);
}

// Unicode source survives a link round-trip; malformed links and unknown files do not.
const shared = { mode: 'tour' as const, path: `tour/${tour[0].file}`, stage: 'write_firrtl' as const, source: files[`tour/${tour[0].file}`] + '// café → circuit ⚡\n' };
assert.deepEqual(decodeShare(`#code=${encodeShare(shared)}`), { ...shared, version: 1 });
assert.equal(decodeShare(''), null);
assert.throws(() => decodeShare('#code=malformed'));
assert.throws(() => decodeShare(`#code=${encodeShare({ ...shared, path: '../../outside.yodl' })}`));
assert.ok(!validSelection({ ...shared, stage: 'toString' }));
assert.ok(!validSelection({ ...shared, mode: 'examples' }));

const bad = compile({ id: 3, path: shared.path, source: 'module Top(a: bool) -> (q: bool) {\n    q = missing\n}\n', stage: 'write_firrtl' });
assert.ok(bad.error?.includes('missing'));
assert.ok(!bad.error!.startsWith('{'), 'Diagnostics must be unwrapped readable text');
assert.ok(diagnosticLocation(bad.error!, shared.path), 'Explicit source spans become editor markers');
assert.equal(diagnosticLocation(bad.error!, 'examples/Elsewhere.yodl'), null);
assert.equal(diagnosticLocation('No top-level module found', shared.path), null);

// Editing a bundled dependency must not poison the next compilation's imports.
const library = 'examples/lib/Timing.yodl';
const edited = compile({ id: 4, path: library, source: files[shared.path], stage: 'write_firrtl' });
assert.equal(edited.error, undefined);
const imported = compile({ id: 5, path: 'examples/Playground.yodl', source: 'import Timing\nmodule Top(clk: clock) -> (q: bool) {\n    q = Timing::Timer[8](clk).q\n}\n', stage: 'write_firrtl' });
assert.equal(imported.error, undefined, imported.error);

// Exercise the same worker protocol used by the browser, including recovery after an error.
const worker = new Worker(new URL('./playground-worker.js', import.meta.url).href);
async function inWorker(id: number, source: string) {
    return await new Promise<any>((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error('Compiler worker timed out')), 10_000);
        worker.onmessage = event => { clearTimeout(timeout); resolve(event.data); };
        worker.onerror = event => { clearTimeout(timeout); reject(new Error(event.message)); };
        worker.postMessage({ id, source, path: shared.path, stage: shared.stage });
    });
}
try {
    const failure = await inWorker(6, 'invalid');
    assert.equal(failure.id, 6);
    assert.ok(failure.error);
    const success = await inWorker(7, shared.source);
    assert.equal(success.id, 7);
    assert.equal(success.error, undefined);
    assert.match(success.output, /circuit Top/);
} finally { worker.terminate(); }
console.log(`Playground checks passed: ${tour.length} lessons × ${Object.keys(stages).length} stages, ${tour.length} challenges, sharing, diagnostics, isolated imports, and compiler worker.`);

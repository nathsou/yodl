import { expect, test } from 'bun:test';
import { mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { buildBrowserAssets } from './bundle.ts';
import type { CompileResult } from '../main/playground-compiler.ts';

test('browser bundles pin their compiler and compile nested documentation paths', async () => {
    const directory = await mkdtemp(join(tmpdir(), 'yodl-browser-test-'));
    let worker: Worker | undefined;
    try {
        const assets = await buildBrowserAssets(resolve(import.meta.dir, '../..'), directory);
        expect(assets.worker).toMatch(/^playground-worker-[^.]+\.js$/);
        expect(assets.docs).toMatch(/^docs-[^.]+\.js$/);
        expect(assets.playground).toMatch(/^playground-[^.]+\.js$/);
        const bundles = await Promise.all((await readdir(directory)).map(name => readFile(join(directory, name), 'utf8')));
        expect(bundles.join('\n')).toContain(`./${assets.worker}`);
        expect(bundles.join('\n')).not.toContain('./playground-worker.js');
        worker = new Worker(pathToFileURL(join(directory, assets.worker)), { type: 'module' });
        const result = await new Promise<CompileResult>((resolve, reject) => {
            worker!.onmessage = event => resolve(event.data);
            worker!.onerror = reject;
            worker!.postMessage({
                id: 1, path: 'book/src/02_getting_started/ex-your-first-yodl-design.yodl',
                source: 'module Top(clk: clock, rst: bool) -> (leds: u8) {\nlet counter = Reg[u24](clk, rst)\ncounter.d = counter.q + 1\nleds = counter.q[23:16]\n}',
                stage: 'write_firrtl', files: {},
            });
        });
        expect(result.error).toBeUndefined();
        expect(result.output).toContain('public module Top:');
        expect(result.output).toContain('regreset');
    } finally {
        worker?.terminate();
        await rm(directory, { recursive: true, force: true });
    }
}, 15_000);

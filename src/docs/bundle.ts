import { basename } from 'node:path';

const entryName = (result: Awaited<ReturnType<typeof Bun.build>>, prefix: string, kind: 'entry-point' | 'asset' = 'entry-point', extension = '.js') =>
    basename(result.outputs.find(output => output.kind === kind && basename(output.path).startsWith(`${prefix}-`) && output.path.endsWith(extension))!.path);

export async function buildBrowserAssets(root: string, outdir: string) {
    // Build the workers first so clients refer to this exact version, even when
    // a browser or CDN still has assets from a previous deployment.
    const worker = await Bun.build({ entrypoints: [`${root}/src/main/playground-worker.ts`], outdir, naming: '[name]-[hash].[ext]', minify: true, target: 'browser' });
    if (!worker.success) throw new AggregateError(worker.logs, 'Compiler worker build failed');
    const workerName = basename(worker.outputs.find(output => output.kind === 'entry-point')!.path);
    const lspWorker = await Bun.build({ entrypoints: [`${root}/src/main/lsp-worker.ts`], outdir, naming: '[name]-[hash].[ext]', minify: true, target: 'browser' });
    if (!lspWorker.success) throw new AggregateError(lspWorker.logs, 'Language worker build failed');
    const lspWorkerName = basename(lspWorker.outputs.find(output => output.kind === 'entry-point')!.path);
    // Monaco is bundled with the site: its core, the features the editor uses,
    // its stylesheet and icon font, and its background worker.
    const monacoWorker = await Bun.build({ entrypoints: [`${root}/node_modules/monaco-editor/esm/vs/editor/editor.worker.js`], outdir, naming: 'monaco-worker-[hash].[ext]', minify: true, target: 'browser' });
    if (!monacoWorker.success) throw new AggregateError(monacoWorker.logs, 'Editor worker build failed');
    const monacoWorkerName = basename(monacoWorker.outputs.find(output => output.kind === 'entry-point')!.path);
    const editor = await Bun.build({
        entrypoints: [`${root}/src/main/monaco.ts`], outdir, naming: '[name]-[hash].[ext]', minify: true, target: 'browser',
        define: { __MONACO_WORKER__: JSON.stringify(`./${monacoWorkerName}`) },
    });
    if (!editor.success) throw new AggregateError(editor.logs, 'Editor build failed');
    const editorName = entryName(editor, 'monaco');
    const editorCss = entryName(editor, 'monaco', 'asset', '.css');
    const clients = await Bun.build({
        entrypoints: [`${root}/src/main/playground.ts`],
        outdir, naming: '[name]-[hash].[ext]', splitting: true, minify: true, target: 'browser',
        define: { __YODL_COMPILER_WORKER__: JSON.stringify(`./${workerName}`), __YODL_LSP_WORKER__: JSON.stringify(`./${lspWorkerName}`), __MONACO_BUNDLE__: JSON.stringify(`./${editorName}`), __MONACO_CSS__: JSON.stringify(`./${editorCss}`) },
    });
    if (!clients.success) throw new AggregateError(clients.logs, 'Browser build failed');
    return { worker: workerName, lspWorker: lspWorkerName, editor: editorName, editorCss, editorWorker: monacoWorkerName, playground: entryName(clients, 'playground') };
}

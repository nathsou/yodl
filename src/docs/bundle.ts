import { basename } from 'node:path';

export async function buildBrowserAssets(root: string, outdir: string) {
    // Build the worker first so clients refer to this exact compiler version,
    // even when a browser or CDN still has assets from a previous deployment.
    const worker = await Bun.build({ entrypoints: [`${root}/src/main/playground-worker.ts`], outdir, naming: '[name]-[hash].[ext]', minify: true, target: 'browser' });
    if (!worker.success) throw new AggregateError(worker.logs, 'Compiler worker build failed');
    const workerName = basename(worker.outputs.find(output => output.kind === 'entry-point')!.path);
    const clients = await Bun.build({
        entrypoints: [`${root}/src/main/playground.ts`, `${root}/src/docs/docs.ts`],
        outdir, naming: '[name]-[hash].[ext]', splitting: true, minify: true, target: 'browser',
        define: { __YODL_COMPILER_WORKER__: JSON.stringify(`./${workerName}`) },
    });
    if (!clients.success) throw new AggregateError(clients.logs, 'Browser build failed');
    const entry = (name: string) => basename(clients.outputs.find(output => output.kind === 'entry-point' && basename(output.path).startsWith(`${name}-`))!.path);
    return { worker: workerName, docs: entry('docs'), playground: entry('playground') };
}

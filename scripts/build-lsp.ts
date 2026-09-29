import { mkdir, chmod } from 'node:fs/promises';
await mkdir('dist/lsp', { recursive: true });
const result = await Bun.build({ entrypoints: ['src/lsp/node.ts'], outdir: 'dist/lsp', target: 'node', format: 'cjs', naming: 'yodl-lsp.cjs', minify: true });
if (!result.success) throw new AggregateError(result.logs, 'Language server build failed');
await chmod('dist/lsp/yodl-lsp.cjs', 0o755);

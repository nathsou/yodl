#!/usr/bin/env node
import { readdir, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { new_server, handle_message, flush_diagnostics } from '../../_build/js/release/build/lib/lsp/lsp.js';
import { frame, MessageReader } from './transport.ts';

const server = new_server();
const roots = new Set<string>();
let files: Record<string, string> = {};
let timer: ReturnType<typeof setTimeout> | undefined;
let shutdown = false;
const ignored = new Set(['.git', 'node_modules', '_build', 'target', 'dist', '.mooncakes']);
const output = (messages: string) => { for (const message of JSON.parse(messages)) process.stdout.write(frame(message)); };
const dispatch = (message: any) => output(handle_message(server, JSON.stringify(message)));
const publish = () => { clearTimeout(timer); timer = setTimeout(() => output(flush_diagnostics(server)), 120); };
function path(uri: string): string | undefined {
    try { if (new URL(uri).protocol === 'file:') return fileURLToPath(uri); } catch { /* Non-file documents use their open text. */ }
}
async function scan(root: string, result: Record<string, string>) {
    let entries;
    try { entries = await readdir(root, { withFileTypes: true }); } catch { return; }
    await Promise.all(entries.map(async entry => {
        if (ignored.has(entry.name) || entry.isSymbolicLink()) return;
        const target = join(root, entry.name);
        if (entry.isDirectory()) await scan(target, result);
        else if (entry.isFile() && entry.name.endsWith('.yodl')) {
            try { result[pathToFileURL(target).href] = await readFile(target, 'utf8'); } catch { /* Deleted while scanning. */ }
        }
    }));
}
async function refresh() {
    const next: Record<string, string> = {};
    for (const root of roots) await scan(root, next);
    files = next;
    dispatch({ jsonrpc: '2.0', method: 'yodl/setFiles', params: { files } });
}
async function receive(json: string) {
    let message: any;
    try { message = JSON.parse(json); } catch { output(handle_message(server, json)); return; }
    if (message.method === 'initialize') {
        const params = message.params ?? {};
        for (const folder of params.workspaceFolders ?? []) { const p = path(folder.uri); if (p) roots.add(p); }
        const root = path(params.rootUri ?? '');
        if (root) roots.add(root);
        if (!roots.size && params.rootPath) roots.add(params.rootPath);
        const scanned: Record<string, string> = {};
        for (const root of roots) await scan(root, scanned);
        files = { ...scanned, ...params.initializationOptions?.files };
        message.params = { ...params, initializationOptions: { ...params.initializationOptions, files } };
    } else if (message.method === 'workspace/didChangeWorkspaceFolders') {
        for (const folder of message.params?.event?.removed ?? []) { const p = path(folder.uri); if (p) roots.delete(p); }
        for (const folder of message.params?.event?.added ?? []) { const p = path(folder.uri); if (p) roots.add(p); }
        await refresh(); publish(); return;
    } else if (message.method === 'textDocument/didOpen') {
        const p = path(message.params?.textDocument?.uri ?? '');
        if (p && ![...roots].some(root => p.startsWith(root + '/') || p.startsWith(root + '\\'))) { roots.add(dirname(p)); await refresh(); }
    } else if (['textDocument/didSave', 'textDocument/didClose', 'workspace/didChangeWatchedFiles'].includes(message.method)) {
        await refresh();
    }
    if (message.method === 'exit') { clearTimeout(timer); dispatch(message); process.exit(shutdown ? 0 : 1); }
    dispatch(message);
    if (message.method === 'shutdown') { shutdown = true; clearTimeout(timer); }
    else if (/^textDocument\/did|^workspace\/didChangeWatchedFiles$|^yodl\/setFiles$/.test(message.method ?? '')) publish();
}
// Serialise disk reads and messages so an edit cannot overtake its didOpen.
let queue = Promise.resolve();
const reader = new MessageReader(json => {
    queue = queue.then(() => receive(json)).catch(error => { console.error('Yodl LSP:', error); });
});
process.stdin.on('data', chunk => { try { reader.feed(chunk); } catch (error) { console.error('Yodl LSP transport:', error); process.exitCode = 1; process.stdin.destroy(); } });
process.stdin.on('end', () => { clearTimeout(timer); });

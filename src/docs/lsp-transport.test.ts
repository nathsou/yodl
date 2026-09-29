import { expect, test } from 'bun:test';
import { spawn } from 'node:child_process';
import { frame, MessageReader } from '../lsp/transport.ts';

test('stdio framing uses UTF8 bytes across split and coalesced messages', () => {
    const values: string[] = []; const reader = new MessageReader(json => values.push(json));
    const first = { text: '😀\r\n世界' }, second = { id: 2 };
    const bytes = Buffer.concat([frame(first), frame(second)]);
    for (const byte of bytes) reader.feed(Buffer.from([byte]));
    expect(values.map(v => JSON.parse(v))).toEqual([first, second]);
    expect(() => new MessageReader(() => {}).feed(Buffer.from('Content-Length: -1\r\n\r\n'))).toThrow();
});

test('packaged stdio server answers real requests and publishes diagnostics', async () => {
    const child = spawn(process.execPath, ['dist/lsp/yodl-lsp.cjs'], { stdio: ['pipe', 'pipe', 'pipe'] });
    let stderr = ''; child.stderr.on('data', d => stderr += d);
    const messages: any[] = [];
    const reader = new MessageReader(json => messages.push(JSON.parse(json)));
    child.stdout.on('data', d => reader.feed(d));
    const send = (message: any) => child.stdin.write(frame({ jsonrpc: '2.0', ...message }));
    const wait = async (predicate: (m: any) => boolean) => {
        for (let i = 0; i < 100; i++) { const message = messages.find(predicate); if (message) return message; await Bun.sleep(20); }
        throw new Error(`Server timeout: ${stderr} ${JSON.stringify(messages)}`);
    };
    try {
        send({ id: 1, method: 'initialize', params: {} });
        expect((await wait(m => m.id === 1)).result.capabilities.positionEncoding).toBe('utf-16');
        const uri = 'untitled:///Top.yodl';
        send({ method: 'textDocument/didOpen', params: { textDocument: { uri, version: 1, text: 'module Top() -> () {\n let value: u8 = 256\n}' } } });
        expect((await wait(m => m.method === 'textDocument/publishDiagnostics')).params.diagnostics[0].code).toBe('Y0501');
        send({ id: 2, method: 'textDocument/hover', params: { textDocument: { uri }, position: { line: 1, character: 6 } } });
        expect((await wait(m => m.id === 2)).result.contents.value).toContain('value');
        send({ id: 3, method: 'shutdown' }); await wait(m => m.id === 3);
        const exited = new Promise<number | null>(resolve => child.on('exit', resolve));
        send({ method: 'exit' }); expect(await exited).toBe(0);
        expect(stderr).toBe('');
    } finally { child.kill(); }
}, 10000);

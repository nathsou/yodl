/** The host only frames UTF-8 JSON; MoonBit owns JSON-RPC and LSP. */
export class MessageReader {
    private buffer = Buffer.alloc(0);
    private length: number | undefined;
    constructor(private receive: (json: string) => void) {}
    feed(chunk: Uint8Array) {
        this.buffer = Buffer.concat([this.buffer, chunk]);
        while (true) {
            if (this.length === undefined) {
                const end = this.buffer.indexOf('\r\n\r\n');
                if (end < 0) { if (this.buffer.length > 8192) throw new Error('LSP header exceeds 8 KiB'); return; }
                const headers = this.buffer.subarray(0, end).toString('ascii').split('\r\n');
                const lengths = headers.filter(h => /^content-length:/i.test(h));
                if (lengths.length !== 1 || !/^content-length:\s*\d+\s*$/i.test(lengths[0])) throw new Error('Invalid Content-Length');
                this.length = Number(lengths[0].split(':')[1]);
                if (this.length > 16 * 1024 * 1024) throw new Error('LSP message exceeds 16 MiB');
                this.buffer = this.buffer.subarray(end + 4);
            }
            if (this.buffer.length < this.length) return;
            const json = this.buffer.subarray(0, this.length).toString('utf8');
            this.buffer = this.buffer.subarray(this.length); this.length = undefined;
            this.receive(json);
        }
    }
}
export function frame(message: unknown): Buffer {
    const body = Buffer.from(JSON.stringify(message), 'utf8');
    return Buffer.concat([Buffer.from(`Content-Length: ${body.length}\r\n\r\n`), body]);
}

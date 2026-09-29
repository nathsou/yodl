export type Position = { line: number; character: number };
export type Range = { start: Position; end: Position };
export type LspDiagnostic = { range: Range; message: string; code?: string; severity?: number; relatedInformation?: any[]; rendered?: string };
declare const __YODL_LSP_WORKER__: string;

export class LanguageClient {
    private id = 0;
    private pending = new Map<number, { resolve: (value: any) => void; reject: (error: Error) => void; timer: ReturnType<typeof setTimeout> }>();
    private worker: Worker;
    onDiagnostics: (uri: string, diagnostics: LspDiagnostic[], version?: number) => void = () => {};
    onError: (message: string) => void = () => {};
    constructor(worker?: Worker) {
        this.worker = worker ?? new Worker(new URL(typeof __YODL_LSP_WORKER__ === 'undefined' ? './lsp-worker.js' : __YODL_LSP_WORKER__, import.meta.url), { type: 'module' });
        this.worker.onmessage = event => {
            const message = event.data;
            if (message.id !== undefined) {
                const pending = this.pending.get(message.id);
                if (!pending) return;
                this.pending.delete(message.id); clearTimeout(pending.timer);
                if (message.error) pending.reject(new Error(message.error.message)); else pending.resolve(message.result);
            } else if (message.method === 'textDocument/publishDiagnostics') {
                this.onDiagnostics(message.params.uri, message.params.diagnostics, message.params.version);
            } else if (message.method === 'window/logMessage' && message.params.type === 1) this.onError(message.params.message);
        };
        this.worker.onerror = event => {
            this.fail(new Error(event.message || 'Language worker failed'));
            this.onError(event.message || 'Language worker failed');
        };
    }
    request(method: string, params: any = {}, cancellation?: { isCancellationRequested: boolean; onCancellationRequested: (f: () => void) => { dispose(): void } }): Promise<any> {
        const id = ++this.id;
        let subscription: { dispose(): void } | undefined;
        const promise = new Promise((resolve, reject) => {
            if (cancellation?.isCancellationRequested) { resolve(null); return; }
            const timer = setTimeout(() => { this.pending.delete(id); reject(new Error(`Language service timed out: ${method}`)); }, 30000);
            this.pending.set(id, { resolve, reject, timer });
            subscription = cancellation?.onCancellationRequested(() => {
                const pending = this.pending.get(id);
                if (pending) { this.pending.delete(id); clearTimeout(pending.timer); pending.resolve(null); this.notify('$/cancelRequest', { id }); }
            });
            this.worker.postMessage({ jsonrpc: '2.0', id, method, params });
        });
        return promise.finally(() => subscription?.dispose());
    }
    notify(method: string, params: any) { this.worker.postMessage({ jsonrpc: '2.0', method, params }); }
    private fail(error: Error) { for (const pending of this.pending.values()) { clearTimeout(pending.timer); pending.reject(error); } this.pending.clear(); }
    dispose() { this.fail(new Error('Language client disposed')); this.worker.terminate(); }
}

export const sourceUri = (path: string) => `yodl:///workspace/${path.split('/').map(encodeURIComponent).join('/')}`;
export const sourcePath = (uri: string) => uri.startsWith('yodl:///workspace/') ? uri.slice('yodl:///workspace/'.length).split('/').map(decodeURIComponent).join('/') : uri;
export const toPosition = (position: any): Position => ({ line: position.lineNumber - 1, character: position.column - 1 });
export const toRange = (range: any): Range => ({ start: toPosition({ lineNumber: range.startLineNumber, column: range.startColumn }), end: toPosition({ lineNumber: range.endLineNumber, column: range.endColumn }) });
export const editorRange = (range: Range) => ({ startLineNumber: range.start.line + 1, startColumn: range.start.character + 1, endLineNumber: range.end.line + 1, endColumn: range.end.character + 1 });

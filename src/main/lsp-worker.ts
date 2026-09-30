import { new_server, handle_message, flush_diagnostics } from '../../_build/js/release/build/lib/lsp/lsp.js';
const server = new_server();
let timer: ReturnType<typeof setTimeout> | undefined;
const send = (messages: string) => { for (const message of JSON.parse(messages)) self.postMessage(message); };
self.onmessage = (event: MessageEvent) => {
    const message = event.data;
    try {
        send(handle_message(server, JSON.stringify(message)));
        if (/^textDocument\/did|^yodl\/setFiles$/.test(message.method ?? '')) {
            clearTimeout(timer);
            timer = setTimeout(() => {
                try { send(flush_diagnostics(server)); }
                catch (error) { self.postMessage({ jsonrpc: '2.0', method: 'window/logMessage', params: { type: 1, message: String(error) } }); }
            }, 120);
        }
    } catch (error) {
        if (message.id !== undefined) self.postMessage({ jsonrpc: '2.0', id: message.id, error: { code: -32603, message: String(error) } });
    }
};

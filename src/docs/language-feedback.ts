import { new_server, handle_message } from '../../_build/js/release/build/lib/lsp/lsp.js';
import { sourceUri, sourcePath } from '../main/lsp-client.ts';
import type { Example } from './content.ts';
import type { ExampleFeedback } from './feedback.ts';

/** Each example owns a fresh workspace, including its hidden code and imports. */
export function captureFeedback(example: Example): ExampleFeedback | undefined {
    if (example.expect === 'skip') return undefined;
    const server = new_server();
    let id = 0;
    const request = (method: string, params: unknown) => {
        const messages = JSON.parse(handle_message(server, JSON.stringify({ jsonrpc: '2.0', id: ++id, method, params })));
        const response = messages.find((message: any) => message.id === id);
        if (!response || response.error) throw new Error(`${example.path}: ${response?.error?.message ?? 'Missing language-service response'}`);
        return response.result;
    };
    const uri = sourceUri(example.path);
    const files = Object.fromEntries(Object.entries({ ...example.files, [example.path]: example.source }).map(([path, source]) => [sourceUri(path), source]));
    request('initialize', { initializationOptions: { files } });
    request('textDocument/didOpen', { textDocument: { uri, languageId: 'yodl', version: 1, text: example.source } });
    const feedback: ExampleFeedback = request('yodl/snapshot', { uri });
    for (const diagnostic of feedback.diagnostics) {
        if (diagnostic.uri) diagnostic.uri = sourcePath(diagnostic.uri);
        for (const related of diagnostic.relatedInformation) related.location.uri = sourcePath(related.location.uri);
    }
    return feedback;
}

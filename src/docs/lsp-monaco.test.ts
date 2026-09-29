import { expect, test } from 'bun:test';
import { LanguageService } from '../main/lsp-monaco.ts';
import { LanguageClient, sourceUri } from '../main/lsp-client.ts';
import { new_server, handle_message } from '../../_build/js/release/build/lib/lsp/lsp.js';

function setup() {
    const server = new_server();
    const worker: any = { postMessage(message: any) { queueMicrotask(() => { for (const data of JSON.parse(handle_message(server, JSON.stringify(message)))) worker.onmessage({ data }); }); }, terminate() {} };
    const client = new LanguageClient(worker);
    const providers: Record<string, any> = {}, models: any[] = [], markers: any[] = [];
    const disposable = { dispose() {} };
    const monaco: any = {
        Uri: { parse: (value: string) => ({ toString: () => value }) }, MarkerSeverity: { Error: 8, Warning: 4 },
        languages: new Proxy({}, { get: (_, name: string) => (_: string, provider: any) => { providers[name] = provider; return disposable; } }),
        editor: { registerEditorOpener: () => disposable, setModelMarkers: (...args: any[]) => markers.push(args), getModel: (uri: any) => models.find(m => m.uri.toString() === uri.toString()), createModel(source: string, _: string, uri = monaco.Uri.parse(`memory:///${models.length}`)) {
            const model = { uri, getValue: () => source, getVersionId: () => 1, onDidChangeContent: () => disposable, onWillDispose: () => disposable };
            models.push(model); return model;
        } },
    };
    const service = new LanguageService(monaco, () => {}, () => {}, () => {}, client);
    const model = monaco.editor.createModel('module Top(a: u8) -> (b: u8) {\n let value: u8 = a\n b = value\n}', 'yodl');
    return { service, model, providers, markers };
}

test('Monaco providers translate ranges, symbols, completions and rename edits', async () => {
    const { service, model, providers } = setup();
    try {
        await service.workspace({}, model, 'Top.yodl');
        const position = { lineNumber: 3, column: 7 };
        const hover = await providers.registerHoverProvider.provideHover(model, position);
        expect(hover.range).toEqual({ startLineNumber: 3, startColumn: 6, endLineNumber: 3, endColumn: 11 });
        const definition = await providers.registerDefinitionProvider.provideDefinition(model, position);
        expect(definition[0].uri).toBe(model.uri);
        expect(definition[0].range.startLineNumber).toBe(2);
        const completion = await providers.registerCompletionItemProvider.provideCompletionItems(model, position, {});
        expect(completion.suggestions[0].kind).toBe(4); // Monaco Variable, LSP Variable = 6.
        expect(completion.suggestions[0].insertText).toBe('value');
        const rename = await providers.registerRenameProvider.provideRenameEdits(model, position, 'renamed');
        expect(rename.edits).toHaveLength(2);
        expect(rename.edits[0].resource).toBe(model.uri);
        expect(rename.edits[0].textEdit.text).toBe('renamed');
        const symbols = await providers.registerDocumentSymbolProvider.provideDocumentSymbols(model);
        expect(symbols[0].kind).toBe(1); // LSP Module = 2.
        const tokens = await providers.registerDocumentSemanticTokensProvider.provideDocumentSemanticTokens(model);
        expect(tokens.data).toBeInstanceOf(Uint32Array);
        expect(providers.registerSelectionRangeProvider).toBeDefined();
    } finally { service.dispose(); }
});

test('browser client cancellation cleans pending requests and source URIs encode paths', async () => {
    const worker: any = { postMessage() {}, terminate() {} };
    const client = new LanguageClient(worker);
    let cancel: (() => void) | undefined;
    const result = client.request('textDocument/hover', {}, { isCancellationRequested: false, onCancellationRequested(f) { cancel = f; return { dispose() {} }; } });
    cancel!(); expect(await result).toBeNull(); client.dispose();
    expect(sourceUri('book/with space.yodl')).toBe('yodl:///workspace/book/with%20space.yodl');
});

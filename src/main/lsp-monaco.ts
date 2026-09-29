import { LanguageClient, sourceUri, sourcePath, toPosition, toRange, editorRange, type LspDiagnostic } from './lsp-client.ts';

/** Only model ownership and protocol/Monaco conversion live in the browser host. */
export class LanguageService {
    readonly client: LanguageClient;
    private models = new Map<string, any>();
    private uris = new Map<any, string>();
    private listeners = new Map<any, { dispose(): void }[]>();
    private registrations: { dispose(): void }[] = [];
    private ready: Promise<any>;
    private epoch = 0;
    private errors = new Map<string, LspDiagnostic[]>();
    model(path: string) { return this.models.get(path.startsWith('yodl-builtin:') ? path : sourceUri(path)); }
    constructor(private monaco: any, private open: (path: string, range: any) => void, private problems: (diagnostics: any[]) => void, onError: (message: string) => void, client = new LanguageClient()) {
        this.client = client;
        this.client.onError = onError;
        this.ready = client.request('initialize', { capabilities: { general: { positionEncodings: ['utf-16'] } } }).then(result => { client.notify('initialized', {}); return result; });
        client.onDiagnostics = (uri, diagnostics, version) => {
            const model = this.models.get(uri);
            if (version !== undefined && model && version !== model.getVersionId()) return;
            this.errors.set(uri, diagnostics);
            if (model) this.markers(model, diagnostics);
            this.problems([...this.errors].flatMap(([uri, diagnostics]) => diagnostics.map(d => ({ ...d, uri: sourcePath(uri) }))));
        };
        this.register();
        this.registrations.push(monaco.editor.registerEditorOpener({ openCodeEditor: (_editor: any, uri: any, selection: any) => {
            const model = monaco.editor.getModel(uri);
            const lspUri = this.uris.get(model);
            if (!lspUri) return false;
            this.open(sourcePath(lspUri), selection); return true;
        } }));
    }
    private markers(model: any, diagnostics: LspDiagnostic[]) {
        this.monaco.editor.setModelMarkers(model, 'yodl', diagnostics.map(d => ({ ...editorRange(d.range), message: d.message, code: d.code, source: 'yodl', severity: d.severity === 2 ? this.monaco.MarkerSeverity.Warning : this.monaco.MarkerSeverity.Error, relatedInformation: d.relatedInformation?.map(r => ({ resource: this.monaco.Uri.parse(r.location.uri), ...editorRange(r.location.range), message: r.message })) })));
    }
    attach(model: any, path: string) {
        const uri = path.startsWith('yodl-builtin:') ? path : sourceUri(path);
        if (this.uris.get(model) === uri) return;
        if (this.uris.has(model)) this.detach(model);
        this.uris.set(model, uri); this.models.set(uri, model);
        this.ready.then(() => { if (this.uris.get(model) === uri) this.client.notify('textDocument/didOpen', { textDocument: { uri, languageId: 'yodl', version: model.getVersionId(), text: model.getValue() } }); });
        this.listeners.set(model, [model.onDidChangeContent(() => {
            this.ready.then(() => { if (this.uris.get(model) === uri) this.client.notify('textDocument/didChange', { textDocument: { uri, version: model.getVersionId() }, contentChanges: [{ text: model.getValue() }] }); });
        }), model.onWillDispose(() => this.detach(model))]);
        this.markers(model, this.errors.get(uri) ?? []);
    }
    private detach(model: any) {
        const uri = this.uris.get(model);
        for (const listener of this.listeners.get(model) ?? []) listener.dispose();
        this.listeners.delete(model); this.uris.delete(model);
        if (uri) { this.models.delete(uri); this.errors.delete(uri); this.ready.then(() => this.client.notify('textDocument/didClose', { textDocument: { uri } })); }
        this.monaco.editor.setModelMarkers(model, 'yodl', []);
    }
    async workspace(files: Record<string, string>, entry: any, path: string): Promise<Record<string, string> | undefined> {
        const epoch = ++this.epoch;
        this.attach(entry, path);
        await this.ready;
        const sourceFiles = Object.fromEntries(Object.entries(files).map(([path, source]) => [sourceUri(path), source]));
        await this.client.request('yodl/setFiles', { files: sourceFiles });
        const dependencies = await this.client.request('yodl/dependencies', { uri: sourceUri(path) });
        if (epoch !== this.epoch) return;
        return Object.fromEntries(Object.entries(dependencies).map(([uri, source]) => [sourcePath(uri), source as string]));
    }
    private async query(model: any, method: string, params: any, token?: any) {
        const uri = this.uris.get(model), version = model.getVersionId();
        if (!uri) return null;
        await this.ready;
        const result = await this.client.request(`textDocument/${method}`, { textDocument: { uri }, ...params }, token);
        return this.uris.get(model) === uri && model.getVersionId() === version ? result : null;
    }
    private async ensure(uri: string) {
        if (this.models.has(uri)) return this.models.get(uri);
        const source = await this.client.request('yodl/source', { uri });
        if (source === null) return;
        if (this.models.has(uri)) return this.models.get(uri);
        const model = this.monaco.editor.createModel(source, 'yodl', this.monaco.Uri.parse(uri));
        this.attach(model, sourcePath(uri));
        this.open(sourcePath(uri), undefined);
        return model;
    }
    private async locations(result: any) {
        if (!result) return [];
        return (await Promise.all((Array.isArray(result) ? result : [result]).map(async (location: any) => {
            const model = await this.ensure(location.uri);
            return model ? { uri: model.uri, range: editorRange(location.range) } : null;
        }))).filter(Boolean);
    }
    private async edits(edit: any) {
        if (!edit?.changes) return undefined;
        const edits = [];
        for (const [uri, changes] of Object.entries(edit.changes)) {
            const model = await this.ensure(uri);
            if (!model) return undefined;
            for (const change of changes as any[]) edits.push({ resource: model.uri, versionId: model.getVersionId(), textEdit: { range: editorRange(change.range), text: change.newText } });
        }
        return { edits };
    }
    private register() {
        const languages = this.monaco.languages;
        const register = (name: string, provider: any) => this.registrations.push(languages[name]('yodl', provider));
        register('registerHoverProvider', { provideHover: async (model: any, position: any, token: any) => {
            const value = await this.query(model, 'hover', { position: toPosition(position) }, token);
            return value ? { range: value.range && editorRange(value.range), contents: [{ value: value.contents.value }] } : null;
        } });
        for (const [provider, method] of [['Definition', 'definition'], ['Declaration', 'declaration'], ['TypeDefinition', 'typeDefinition']]) {
            register(`register${provider}Provider`, { [`provide${provider}`]: async (model: any, position: any, token: any) => this.locations(await this.query(model, method, { position: toPosition(position) }, token)) });
        }
        register('registerReferenceProvider', { provideReferences: async (model: any, position: any, context: any, token: any) => this.locations(await this.query(model, 'references', { position: toPosition(position), context }, token)) });
        register('registerDocumentHighlightProvider', { provideDocumentHighlights: async (model: any, position: any, token: any) => (await this.query(model, 'documentHighlight', { position: toPosition(position) }, token) ?? []).map((r: any) => ({ ...r, range: editorRange(r.range) })) });
        const symbol = (value: any): any => ({ ...value, kind: value.kind - 1, range: editorRange(value.range), selectionRange: editorRange(value.selectionRange), children: value.children?.map(symbol) });
        register('registerDocumentSymbolProvider', { provideDocumentSymbols: async (model: any, token: any) => (await this.query(model, 'documentSymbol', {}, token) ?? []).map(symbol) });
        register('registerCompletionItemProvider', { triggerCharacters: ['.', ':', '['], provideCompletionItems: async (model: any, position: any, _context: any, token: any) => {
            const result = await this.query(model, 'completion', { position: toPosition(position) }, token);
            // Monaco's completion enum differs from LSP after the first values.
            const kinds = [0,18,0,1,2,3,4,7,5,8,9,12,13,15,17,28,19,20,21,23,16,14,6,10,11,24];
            return { incomplete: result?.isIncomplete ?? false, suggestions: (result?.items ?? []).map((i: any) => ({ label: i.label, detail: i.detail, kind: kinds[i.kind ?? 1], insertText: i.textEdit?.newText ?? i.label, range: i.textEdit ? editorRange(i.textEdit.range) : undefined })) };
        } });
        register('registerSignatureHelpProvider', { signatureHelpTriggerCharacters: ['(', '[', ',', ':'], signatureHelpRetriggerCharacters: [','], provideSignatureHelp: async (model: any, position: any, token: any) => {
            const value = await this.query(model, 'signatureHelp', { position: toPosition(position) }, token);
            return value ? { value, dispose() {} } : null;
        } });
        register('registerRenameProvider', {
            resolveRenameLocation: async (model: any, position: any, token: any) => {
                try { const result = await this.query(model, 'prepareRename', { position: toPosition(position) }, token); return result ? { range: editorRange(result.range), text: result.placeholder } : { rejectReason: 'No renameable symbol here' }; }
                catch (error) { return { rejectReason: (error as Error).message }; }
            },
            provideRenameEdits: async (model: any, position: any, newName: string, token: any) => {
                try { return await this.edits(await this.query(model, 'rename', { position: toPosition(position), newName }, token)); }
                catch (error) { return { edits: [], rejectReason: (error as Error).message }; }
            },
        });
        register('registerCodeActionProvider', { providedCodeActionKinds: ['quickfix'], provideCodeActions: async (model: any, range: any, context: any, token: any) => {
            const result = await this.query(model, 'codeAction', { range: toRange(range), context: { diagnostics: [], only: context.only ? [context.only] : undefined } }, token);
            return { actions: await Promise.all((result ?? []).map(async (action: any) => ({ title: action.title, kind: action.kind, isPreferred: action.isPreferred, edit: await this.edits(action.edit) }))), dispose() {} };
        } });
        register('registerFoldingRangeProvider', { provideFoldingRanges: async (model: any, _context: any, token: any) => (await this.query(model, 'foldingRange', {}, token) ?? []).map((r: any) => ({ start: r.startLine + 1, end: r.endLine + 1 })) });
        register('registerSelectionRangeProvider', { provideSelectionRanges: async (model: any, positions: any[], token: any) => {
            const result = await this.query(model, 'selectionRange', { positions: positions.map(toPosition) }, token);
            return (result ?? []).map((value: any) => { const ranges = []; while (value) { ranges.push({ range: editorRange(value.range) }); value = value.parent; } return ranges; });
        } });
        register('registerDocumentSemanticTokensProvider', {
            getLegend: () => ({ tokenTypes: ['namespace','type','class','parameter','variable','property','function','keyword','number','string','operator'], tokenModifiers: ['declaration','readonly'] }),
            provideDocumentSemanticTokens: async (model: any, _last: any, token: any) => { const result = await this.query(model, 'semanticTokens/full', {}, token); return result ? { data: Uint32Array.from(result.data) } : null; },
            releaseDocumentSemanticTokens() {},
        });
    }
    dispose() {
        for (const model of [...this.uris.keys()]) this.detach(model);
        for (const registration of this.registrations) registration.dispose();
        this.client.dispose();
    }
}

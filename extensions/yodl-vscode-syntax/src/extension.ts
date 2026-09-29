import * as vscode from 'vscode';
import { LanguageClient, TransportKind } from 'vscode-languageclient/node';
let client: LanguageClient | undefined;
export async function activate(context: vscode.ExtensionContext) {
    const watcher = vscode.workspace.createFileSystemWatcher('**/*.yodl');
    context.subscriptions.push(watcher);
    client = new LanguageClient('yodl', 'Yodl', {
        run: { module: context.asAbsolutePath('dist/yodl-lsp.cjs'), transport: TransportKind.stdio },
        debug: { module: context.asAbsolutePath('dist/yodl-lsp.cjs'), transport: TransportKind.stdio },
    }, {
        documentSelector: [{ language: 'yodl', scheme: 'file' }, { language: 'yodl', scheme: 'untitled' }],
        synchronize: { fileEvents: watcher },
    });
    context.subscriptions.push(vscode.workspace.registerTextDocumentContentProvider('yodl-builtin', {
        provideTextDocumentContent: uri => client!.sendRequest<string>('yodl/source', { uri: uri.toString() }),
    }));
    await client.start();
    context.subscriptions.push(client);
}
export async function deactivate() { await client?.stop(); client = undefined; }

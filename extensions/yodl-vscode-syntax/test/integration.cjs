const vscode = require('vscode');
const assert = require('node:assert/strict');
const { mkdtemp, writeFile, rm } = require('node:fs/promises');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
exports.run = async function () {
    const directory = await mkdtemp(join(tmpdir(), 'yodl-vscode-'));
    const uri = vscode.Uri.file(join(directory, 'Top.yodl'));
    const lib = vscode.Uri.file(join(directory, 'Lib.yodl'));
    const source = 'import Lib\nmodule Top(a: u8) -> (b: u8) {\n let value: u8 = a\n let inst = Lib::Identity(value: value)\n b = inst.out\n}';
    await writeFile(uri.fsPath, source);
    await writeFile(lib.fsPath, 'module Identity(value: u8) -> (out: u8) {\n out = value\n}');
    const poll = async (f, predicate = value => value?.length > 0) => {
        for (let i = 0; i < 150; i++) { const value = await f(); if (predicate(value)) return value; await new Promise(r => setTimeout(r, 100)); }
        throw new Error('Timed out waiting for VS Code language provider');
    };
    try {
        await vscode.extensions.getExtension('nathsou.yodl-syntax-highlighting').activate();
        const document = await vscode.workspace.openTextDocument(uri);
        const editor = await vscode.window.showTextDocument(document);
        const hover = await poll(() => vscode.commands.executeCommand('vscode.executeHoverProvider', uri, new vscode.Position(2, 6)));
        assert.ok(hover[0].contents[0].value.includes('value: u8'));
        const definitions = await poll(() => vscode.commands.executeCommand('vscode.executeDefinitionProvider', uri, new vscode.Position(3, 18)));
        assert.equal(definitions[0].uri.toString(), lib.toString());
        const references = await vscode.commands.executeCommand('vscode.executeReferenceProvider', uri, new vscode.Position(2, 6));
        assert.equal(references.length, 3);
        const rename = await vscode.commands.executeCommand('vscode.executeDocumentRenameProvider', uri, new vscode.Position(2, 6), 'renamed');
        assert.equal(rename.get(uri).length, 3);
        await vscode.workspace.applyEdit(rename);
        assert.ok(document.getText().includes('value: renamed'));
        const completion = await vscode.commands.executeCommand('vscode.executeCompletionItemProvider', uri, new vscode.Position(4, 10));
        assert.ok(completion.items.some(i => i.label === 'out'));
        const symbols = await vscode.commands.executeCommand('vscode.executeDocumentSymbolProvider', uri);
        assert.ok(symbols.some(s => s.name === 'Top'));
        await editor.edit(edit => edit.replace(new vscode.Range(0, 0, document.lineCount, 0), 'module Top() -> () {\n let value: u8 = 256\n}'));
        const diagnostics = await poll(() => vscode.languages.getDiagnostics(uri));
        assert.equal(diagnostics[0].code, 'Y0501');
        assert.equal(diagnostics[0].range.start.line, 1);
        await editor.edit(edit => edit.replace(new vscode.Range(1, 17, 1, 20), '1'));
        await poll(() => vscode.languages.getDiagnostics(uri), diagnostics => diagnostics.length === 0);
        console.log('Yodl VS Code integration: hover, imports, references, rename, completion, symbols, live diagnostics passed');
    } finally { await vscode.commands.executeCommand('workbench.action.closeAllEditors'); await rm(directory, { recursive: true, force: true }); }
};

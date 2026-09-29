import { describe, expect, test } from 'bun:test';
import { new_server, handle_message, flush_diagnostics } from '../../_build/js/release/build/lib/lsp/lsp.js';
const uri = 'file:///workspace/Top.yodl';
function service(source: string, files: Record<string, string> = {}) {
    const server = new_server(); let id = 0;
    const raw = (method: string, params: any = {}, request = true) => JSON.parse(handle_message(server, JSON.stringify({ jsonrpc: '2.0', ...(request ? { id: ++id } : {}), method, params })));
    const request = (method: string, params: any = {}) => {
        const response = raw(method, params).find((r: any) => 'id' in r);
        if (response.error) throw new Error(response.error.message);
        return response.result;
    };
    request('initialize', { initializationOptions: { files: { ...files, [uri]: source } } });
    raw('initialized', {}, false);
    raw('textDocument/didOpen', { textDocument: { uri, text: source, version: 1, languageId: 'yodl' } }, false);
    const at = (needle: string, occurrence = 0) => {
        let index = -1;
        for (let i = 0; i <= occurrence; i++) index = source.indexOf(needle, index + 1);
        if (index < 0) throw new Error(`Missing ${needle}`);
        const lines = source.slice(0, index).split(/\r\n|\r|\n/);
        return { line: lines.length - 1, character: lines.at(-1)!.length };
    };
    return { server, request, raw, at, query: (method: string, position: any, extra = {}) => request(`textDocument/${method}`, { textDocument: { uri }, position, ...extra }), diagnostics: () => JSON.parse(flush_diagnostics(server)).flatMap((r: any) => r.params.diagnostics) };
}
describe('MoonBit LSP', () => {
    test('lifecycle, parse errors, unsupported requests and shutdown', () => {
        const s = new_server();
        expect(JSON.parse(handle_message(s, '{'))[0].error.code).toBe(-32700);
        expect(JSON.parse(handle_message(s, JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'textDocument/hover' })))[0].error.code).toBe(-32002);
        const c = service('');
        expect(c.raw('unknown')[0].error.code).toBe(-32601);
        c.request('shutdown');
        expect(c.raw('workspace/symbol', { query: '' })[0].error.code).toBe(-32600);
    });
    test('types, precise definitions, references and rename', () => {
        const c = service('module Top(a: u8) -> (b: u8) {\n let value: u8 = a\n b = value\n}');
        expect(c.diagnostics()).toEqual([]);
        expect(c.query('hover', c.at('value', 1)).contents.value).toContain('let value: u8');
        expect(c.query('definition', c.at('value', 1))[0].range.start).toEqual(c.at('value'));
        expect(c.query('references', c.at('value'), { context: { includeDeclaration: true } })).toHaveLength(2);
        expect(c.query('rename', c.at('value'), { newName: 'renamed' }).changes[uri]).toHaveLength(2);
        expect(c.raw('textDocument/rename', { textDocument: { uri }, position: c.at('value'), newName: 'module' })[0].error.code).toBe(-32602);
    });
    test('nested scopes shadow names without duplicate indexing', () => {
        const c = service('module Top() -> () {\n let x: u8 = 1\n let y = if true {\n  let x: u8 = 2\n  x\n } else { x }\n}');
        const refs = c.query('references', c.at('x', 1), { context: { includeDeclaration: true } });
        expect(refs).toHaveLength(2);
        expect(refs.every((r: any) => r.range.start.line === 3 || r.range.start.line === 4)).toBe(true);
        expect(c.query('references', c.at('x'), { context: { includeDeclaration: true } })).toHaveLength(2);
    });
    test('unsaved imports, named arguments, members and generic signatures', () => {
        const lib = 'file:///workspace/lib/Lib.yodl';
        const c = service('import Lib\nmodule Top(a: u8) -> (b: u8) {\n let inst = Lib::Identity[W: 8](value: a)\n b = inst.out\n}', { [lib]: 'module Identity[W: Nat](value: uint[W]) -> (out: uint[W]) { out = value; }' });
        expect(c.diagnostics()).toEqual([]);
        expect(c.query('definition', c.at('Identity'))[0].uri).toBe(lib);
        expect(c.query('definition', c.at('value'))[0].uri).toBe(lib);
        expect(c.query('definition', c.at('out'))[0].uri).toBe(lib);
        expect(c.query('signatureHelp', c.at('8]')).signatures[0].label).toContain('W: Nat');
        expect(c.query('signatureHelp', c.at('a)')).signatures[0].parameters[0].label).toContain('value');
        expect(c.query('completion', c.at('out')).items.map((i: any) => i.label)).toEqual(['value', 'out']);
        c.raw('textDocument/didOpen', { textDocument: { uri: lib, text: 'module Identity[W: Nat](value: uint[W]) -> (out: uint[W]) { out = missing; }', version: 2 } }, false);
        expect(c.diagnostics().some((d: any) => d.uri === lib && d.code === 'Y0510')).toBe(true);
    });
    test('incremental edits use UTF16/CRLF, reject stale versions and clear errors', () => {
        const src = '// 😀\r\nmodule Top() -> () { let value: u8 = 256; }';
        const c = service(src);
        expect(c.diagnostics()[0].range.start).toEqual(c.at('256'));
        const change = { range: { start: c.at('256'), end: { ...c.at('256'), character: c.at('256').character + 3 } }, text: '1' };
        c.raw('textDocument/didChange', { textDocument: { uri, version: 2 }, contentChanges: [change] }, false);
        expect(c.diagnostics()).toEqual([]);
        c.raw('textDocument/didChange', { textDocument: { uri, version: 1 }, contentChanges: [{ text: src }] }, false);
        expect(c.diagnostics()).toEqual([]);
        expect(c.request('yodl/source', { uri })).toContain('= 1');
    });
    test('recovering syntax, unknown names and quick fixes', () => {
        const c = service('module Top() -> () {\n let value: u8 = 1\n let copy = valeu\n}');
        const diag = c.diagnostics()[0];
        expect(diag.code).toBe('Y0510'); expect(diag.notes[0]).toContain('value');
        const actions = c.request('textDocument/codeAction', { textDocument: { uri }, range: diag.range, context: { diagnostics: [diag] } });
        expect(actions[0].edit.changes[uri][0].newText).toBe('value');
        const incomplete = service('module Top() -> () {\n let value = 1\n');
        const errors = incomplete.diagnostics();
        expect(errors[0].message).toContain('end of file');
        expect(incomplete.request('textDocument/documentSymbol', { textDocument: { uri } })[0].name).toBe('Top');
        expect(incomplete.request('textDocument/codeAction', { textDocument: { uri }, range: errors[0].range, context: { diagnostics: errors } })[0].edit.changes[uri][0].newText).toBe('}');
    });
    test('semantic tokens, symbols, folds, selections and builtin navigation', () => {
        const c = service('module Top() -> () {\n let r = Reg[Width: 8]()\n}');
        expect(c.query('definition', c.at('Reg'))[0].uri).toBe('yodl-builtin:///builtin.yodl');
        expect(c.request('yodl/source', { uri: 'yodl-builtin:///builtin.yodl' })).toContain('Reg');
        const tokens = c.request('textDocument/semanticTokens/full', { textDocument: { uri } }).data;
        expect(tokens.length % 5).toBe(0); expect(tokens.every((n: number) => n >= 0)).toBe(true);
        expect(c.request('workspace/symbol', { query: 'top' })[0].name).toBe('Top');
        expect(c.request('textDocument/foldingRange', { textDocument: { uri } })).toHaveLength(1);
        expect(c.request('textDocument/selectionRange', { textDocument: { uri }, positions: [c.at('r =')] })[0].parent).toBeDefined();
    });
});

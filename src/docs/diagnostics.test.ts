import { expect, test } from 'bun:test';
import { compile } from '../main/playground-compiler.ts';
import { diagnosticLocation } from '../main/diagnostics.ts';

test('compiler errors cross the browser boundary as structured diagnostics', () => {
    const result = compile({ id: 1, path: 'examples/Top.yodl', source: 'module Top() -> () {\n  let value: u8 = 256\n}', stage: 'write_firrtl', files: {} });
    expect(result.error).toContain('error[Y0501]');
    expect(result.diagnostics).toHaveLength(1);
    const diagnostic = result.diagnostics![0];
    expect(diagnostic.uri).toBe('examples/Top.yodl');
    expect(diagnostic.range).toEqual({ start: { line: 1, character: 18 }, end: { line: 1, character: 21 } });
    expect(diagnostic.message).not.toContain('-->');
    expect(diagnosticLocation(diagnostic, 'examples/Top.yodl')).toEqual({ startLineNumber: 2, startColumn: 19, endLineNumber: 2, endColumn: 22 });
});

test('an imported error points into the imported file and retains its import site', () => {
    const result = compile({ id: 2, path: 'examples/Top.yodl', source: 'import Child\nmodule Top() -> () {}', stage: 'write_firrtl', files: { 'examples/Child.yodl': 'module Child() -> () {\n let value = )\n}' } });
    const diagnostic = result.diagnostics![0];
    expect(diagnostic.uri).toBe('examples/Child.yodl');
    expect(diagnostic.relatedInformation[0].location.uri).toBe('examples/Top.yodl');
    expect(diagnostic.relatedInformation[0].message).toBe('Imported here');
});

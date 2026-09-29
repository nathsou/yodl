import type { CompilerDiagnostic } from './yodl.ts';

export function diagnosticLocation(diagnostic: Pick<CompilerDiagnostic, 'uri' | 'range'>, path: string) {
    if (diagnostic.uri !== path || !diagnostic.range) return null;
    const { start, end } = diagnostic.range;
    return { startLineNumber: start.line + 1, startColumn: start.character + 1, endLineNumber: end.line + 1, endColumn: end.character + 1 };
}

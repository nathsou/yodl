import { describe, expect, test } from 'bun:test';
import { dedentDisplay, extractExamples, exampleHTML, highlight, loadChapters } from './content.ts';
import { encodeProgram, decodeProgram, validFiles, validSourcePath } from '../main/share-codec.ts';
import { diagnosticLocation } from '../main/diagnostics.ts';
import { chapterLessons } from './links.ts';
import lessons from '../../tour/lessons.json';

const fence = (source: string, meta = '') => `\`\`\`yodl ${meta}\n${source}\n\`\`\``;
describe('documentation content contract', () => {
    test('hidden supporting lines preserve compiler indentation and line locations', () => {
        const { examples } = extractExamples(fence('# module Top() -> () {\n#     let support = true\n    let q = support\n# }', 'live id=ex-test'), 'test');
        expect(examples[0].source).toBe('module Top() -> () {\n    let support = true\n    let q = support\n}\n');
        expect(examples[0].display).toBe('let q = support');
        expect(examples[0].line).toBe(1);
        expect(examples[0].source.split('\n')).toHaveLength(5);
    });
    test('display dedenting preserves nested blocks, tabs and complete modules', () => {
        expect(dedentDisplay('    if ready {\n        q = true\n    }\n')).toBe('if ready {\n    q = true\n}');
        expect(dedentDisplay('\n\tlet a = true\n\n\tif a {\n\t\tq = a\n\t}\n')).toBe('let a = true\n\nif a {\n\tq = a\n}');
        const whole = 'module Top() -> () {\n    let a = true\n}';
        expect(dedentDisplay(whole)).toBe(whole);
        expect(dedentDisplay('\n  \n')).toBe('');
    });
    test('named regions dedent every line evenly while retaining full source', () => {
        const source = 'module Top() -> () {\n// region body\n    if true {\n        let a = true\n    }\n// endregion body\n}';
        const example = extractExamples(fence(source, 'region=body'), 'test').examples[0];
        expect(example.display).toBe('if true {\n    let a = true\n}');
        expect(example.source).toBe(source + '\n');
    });
    test('tilde fences, CRLF, indented fences and longer fence delimiters', () => {
        const result = extractExamples('  ~~~~yodl live id=ex-tilde\r\n  module Top() -> () {}\r\n  ~~~~', 'test');
        expect(result.examples[0].source).toBe('module Top() -> () {}\n');
        expect(extractExamples('````text\n```yodl\nnot an example\n```\n````', 'test').examples).toHaveLength(0);
    });
    test('static fragments and expected errors are explicit', () => {
        const result = extractExamples(fence('let x', 'static expect=skip') + '\n' + fence('module Invalid', 'live expect=error diagnostic=Expected id=ex-bad stage=write_typed'), 'test');
        expect(result.examples[0].live).toBe(false);
        expect(result.examples[1].expect).toBe('error');
        expect(result.examples[1].diagnostic).toBe('Expected');
        expect(result.examples[1].stage).toBe('write_typed');
    });
    test('invalid metadata fails at build time', () => {
        for (const meta of ['stage=garbage', 'id=x id=y', 'id=../x', 'expect=maybe', 'live static', 'surprise=yes', 'unsupported=unknown', 'stage=write_rtlil unsupported=write_rtlil']) {
            expect(() => extractExamples(fence('module Top() -> () {}', meta), 'test')).toThrow();
        }
        expect(() => extractExamples(fence('', 'id=x') + '\n' + fence('', 'id=x'), 'test')).toThrow('duplicate');
        expect(() => extractExamples('```yodl\nmodule Top', 'test')).toThrow('unclosed');
    });
    test('referenced files retain their import base and affect draft hashes', () => {
        const example = extractExamples(fence('', 'id=ex-file src=tour/05-vectors.yodl'), 'test').examples[0];
        expect(example.path).toBe('tour/05-vectors.yodl');
        expect(example.source).toContain('Lanes');
        expect(() => extractExamples(fence('', 'src=../../private.yodl'), 'test')).toThrow('Invalid');
        expect(() => extractExamples(fence('inline source', 'src=tour/05-vectors.yodl'), 'test')).toThrow('empty fence');
        expect(extractExamples(fence('a'), 'test').examples[0].hash).not.toBe(extractExamples(fence('b'), 'test').examples[0].hash);
    });
    test('source text cannot inject HTML or executable script', () => {
        const example = extractExamples(fence('// </script><img src=x onerror=alert(1)>\nlet x = "<tag>"', 'id=ex-safe'), 'test').examples[0];
        expect(exampleHTML(example)).not.toContain('<img');
        expect(highlight(example.source)).toContain('&lt;/script&gt;');
        expect(highlight('a < b and c > d')).toContain('&lt;');
    });
    test('every chapter, example ID, lesson link, and legacy anchor remains valid', () => {
        const chapters = loadChapters();
        expect(chapters).toHaveLength(10);
        for (const chapter of chapters) {
            expect(chapter.html).not.toContain('data-yodl-example');
            expect(chapter.html).not.toMatch(/href="[^"#]+\.md/);
            for (const ex of chapter.examples) expect(ex.id).toStartWith('ex-');
            for (const lesson of chapterLessons[chapter.slug] ?? []) expect(lessons.some(l => l.id === lesson.id)).toBe(true);
        }
        expect(chapters[2].html).toContain('id="tuples"');
        expect(chapters[6].headings.some(h => h.id === 'printfformat_string-args')).toBe(true);
        expect(chapters[8].headings.some(h => h.id === 'parameters---optional')).toBe(true);
    });
});

describe('sharing and diagnostics', () => {
    test('Unicode source and selected compiler stage round-trip', () => {
        const payload = { version: 2, source: '// λ 🔌\nmodule Top() -> () {}', stage: 'write_typed', files: { 'examples/lib/X.yodl': '// shared dependency' } };
        expect(decodeProgram(encodeProgram(payload))).toEqual(payload);
        expect(() => decodeProgram('x'.repeat(200_001))).toThrow('too large');
    });
    test('shared dependencies must be named source files within the virtual roots', () => {
        expect(validSourcePath('book/src/example/ex-width.yodl')).toBe(true);
        expect(validFiles({ 'examples/lib/Timing.yodl': 'module Timing() -> () {}' })).toBe(true);
        for (const path of ['/etc/passwd', 'examples/../secret.yodl', 'https://host/a.yodl', 'examples/./x.yodl']) expect(validSourcePath(path)).toBe(false);
        expect(validFiles({ 'examples/x.yodl': 123 })).toBe(false);
        expect(validFiles([])).toBe(false);
    });
    test('diagnostic locations match only the explicit source path', () => {
        expect(diagnosticLocation('book/src/ex.yodl:3.4-3.8\nError', 'book/src/ex.yodl')).toEqual({ startLineNumber: 3, startColumn: 4, endLineNumber: 3, endColumn: 8 });
        expect(diagnosticLocation('other.yodl:3.4-3.8', 'book/src/ex.yodl')).toBeNull();
    });
});

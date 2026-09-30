import { expect, test } from 'bun:test';
import { extractExamples, exampleHTML, loadChapters } from './content.ts';
import { captureFeedback } from './language-feedback.ts';
const example = (source: string, meta = '') => extractExamples(`\`\`\`yodl id=ex-feedback ${meta}\n${source}\n\`\`\``, 'test').examples[0];

// These exercise the real MoonBit service and the static renderer together.
test('documentation hovers retain inferred types, signatures and source text after hiding and dedenting', () => {
    const ex = example('# module Top(a: u8) -> () {\n    let value = a\n    let size = clog2!(8)\n# }');
    const feedback = captureFeedback(ex)!;
    expect(feedback.diagnostics).toEqual([]);
    expect(ex.displayMap).toEqual([{ line: 1, character: 4 }, { line: 2, character: 4 }]);
    const html = exampleHTML(ex, feedback);
    expect(html).toContain('data-code-info="let value: u8"');
    expect(html).toContain('data-code-info="clog2!(value: Nat) -&gt; Nat"');
    expect(html).toContain('class="token-ident"');
    const text = html.split('<span class="lt">').slice(1).map(row => row.slice(0, row.indexOf('</div>')).replace(/<[^>]*>/g, '')).join('\n');
    expect(text).toBe(ex.display);
    expect(html).not.toContain('Monaco');
});

test('static errors underline exact displayed columns and expose diagnostics before compilation', () => {
    const ex = example('# module Top() -> () {\n    let value: u8 = 256\n# }', 'expect=error');
    const feedback = captureFeedback(ex)!;
    expect(feedback.diagnostics[0].range!.start).toEqual({ line: 1, character: 20 });
    const html = exampleHTML(ex, feedback);
    expect(html).toContain('class="token-number code-error"');
    expect(html).toContain('>256</span>');
    expect(html).toContain('aria-label="Source diagnostics"');
    expect(html).toContain('href="#ex-feedback-problem-0"');
    expect(html).toContain('Literal requires 9 bits but context provides u8');
    expect(html).toContain('ex-feedback.yodl:2:21');
});

test('named regions, blank lines, tabs and repeated lines keep their original positions', () => {
    const ex = example('module Top() -> () {\n// region body\n\tlet ok: u8 = 1\n\n\tlet bad: u8 = 256\n// endregion body\n}', 'region=body');
    expect(ex.displayMap).toEqual([{ line: 2, character: 1 }, { line: 3, character: 0 }, { line: 4, character: 1 }]);
    const html = exampleHTML(ex, captureFeedback(ex));
    expect(html).toContain('>256</span>');
    expect(html).toContain('ex-feedback.yodl:5:16');
    const repeated = example('# module A() -> () {\n    let value: u8 = 1\n# }\n# module B() -> () {\n    let value: u16 = 1\n# }');
    const repeatedHtml = exampleHTML(repeated, captureFeedback(repeated));
    expect(repeatedHtml).toContain('data-code-info="let value: u8"');
    expect(repeatedHtml).toContain('data-code-info="let value: u16"');
});

test('UTF16 offsets after astral text and escaped tooltip content preserve valid HTML', () => {
    const ex = example('# module Top() -> () {\n    let text = "🙂"; let value: u8 = 256\n    // <img src=x onerror=alert(1)>\n# }', 'expect=error');
    const html = exampleHTML(ex, captureFeedback(ex));
    expect(html).toContain('>256</span>');
    expect(html).not.toContain('<img');
    expect(html).toContain('&lt;img');
    expect(html).toContain('data-code-info="let text: string[2]"');
    expect(html).toContain('ex-feedback.yodl:2:38');
});

test('imports and hidden diagnostics keep complete source locations and isolated workspaces', () => {
    const ex = example('import Child\nmodule Top() -> () {}');
    const path = 'book/src/test/Child.yodl';
    ex.files[path] = 'module Child() -> () {\n let bad: u8 = 256\n}';
    const feedback = captureFeedback(ex)!;
    expect(feedback.diagnostics[0].uri).toBe(path);
    const html = exampleHTML(ex, feedback);
    expect(html).toContain(`${path}:2:16`);
    expect(html).not.toContain('code-error');
    ex.files[path] = 'module Child() -> () {\n let bad = )\n}';
    expect(exampleHTML(ex, captureFeedback(ex))).toContain(`${path}:2:12`);
    const valid = example('module Top() -> () {}');
    expect(captureFeedback(valid)!.diagnostics).toEqual([]);
    const hidden = example('# module Top() -> () {\n# let bad: u8 = 256\n    let ok: u8 = 1\n# }');
    const hiddenHtml = exampleHTML(hidden, captureFeedback(hidden));
    expect(hiddenHtml).toContain('Literal requires');
    expect(hiddenHtml).not.toContain('code-error');
});

test('static diagnostics include spelling suggestions and related declaration locations', () => {
    const ex = example('module Top() -> () {\n let value: u8 = 1\n let copy = valeu\n}');
    const html = exampleHTML(ex, captureFeedback(ex));
    expect(html).toContain('Did you mean &#39;value&#39;?');
    expect(html).toContain('&#39;value&#39; is declared here');
    expect(html).toContain('ex-feedback.yodl:2:6');
});

test('static complete programs receive feedback, while illustrative skipped fragments remain unchanged', () => {
    const ex = example('module Top() -> () {\n let a: u8 = 256\n}', 'static expect=error');
    const html = exampleHTML(ex, captureFeedback(ex));
    expect(html).not.toContain('data-action');
    expect(html).toContain('code-error');
    const skipped = example('let incomplete', 'static expect=skip');
    expect(captureFeedback(skipped)).toBeUndefined();
    expect(exampleHTML(skipped, captureFeedback(skipped))).not.toContain('Source diagnostics');
});

test('the guide captures constant Nat hovers and its intentional overflow diagnostic', () => {
    const chapters = loadChapters(process.cwd(), ex => {
        const feedback = captureFeedback(ex);
        if (ex.expect === 'success') expect(feedback!.diagnostics).toEqual([]);
        return exampleHTML(ex, feedback);
    });
    const control = chapters.find(c => c.slug === '06_control_flow')!;
    expect(control.html).toContain('data-code-info="const Len: Nat"');
    const types = chapters.find(c => c.slug === '03_data_types')!;
    expect(types.html).toContain('code-error');
    expect(types.html).toContain('Literal requires 9 bits but context provides u8');
});

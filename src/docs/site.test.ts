import { describe, expect, test } from 'bun:test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { buildSearchIndex, extractExamples, loadChapters, exampleHTML } from './content.ts';
import { highlight, highlightLines } from '../main/highlight.ts';
import { siteHeader, modes } from '../main/site-navigation.ts';
import { accents } from '../main/theme.ts';
import { stages } from '../main/compiler-stages.ts';
import lessons from '../../tour/lessons.json';

const root = resolve(import.meta.dir, '../..');
const read = (path: string) => readFileSync(resolve(root, path), 'utf8');
const page = read('src/main/playground.html').replace('<!-- site-header -->', siteHeader());
const pageIds = new Set([...page.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]));

describe('single-page shell', () => {
    test('the header offers the three modes and every accent', () => {
        const header = siteHeader();
        expect(modes.map(mode => mode.id)).toEqual(['tour', 'playground', 'docs']);
        for (const mode of modes) expect(header).toContain(`data-mode="${mode.id}"`);
        expect(accents).toHaveLength(7);
        for (const accent of accents) expect(header).toContain(`data-accent="${accent.id}"`);
        for (const preference of ['system', 'light', 'dark']) expect(header).toContain(`data-theme-preference="${preference}"`);
    });
    test('every accent has a light and a dark palette in theme.css', () => {
        const css = read('src/main/theme.css');
        for (const { id } of accents) {
            expect(css).toContain(`[data-accent="${id}"] {`);
            expect(css).toContain(`[data-theme="dark"][data-accent="${id}"]`);
        }
        const [light, dark] = css.split(':root[data-theme="dark"]');
        for (const token of ['--bg', '--panel', '--sunk', '--ink', '--mute', '--line', '--acc', '--acc-soft', '--acc-ink', '--k-kw', '--k-ty', '--k-fn', '--k-nm', '--k-id']) {
            expect(light).toContain(`${token}:`);
            expect(dark).toContain(`${token}:`);
        }
    });
    test('scripts only look up elements that exist in the page', () => {
        const missing: string[] = [];
        for (const file of ['playground.ts', 'simulation-view.ts', 'docs-view.ts', 'search.ts', 'theme.ts']) {
            const source = read(`src/main/${file}`);
            for (const [, id] of source.matchAll(/\b(?:element|button|input|getElementById)(?:<[^>]*>)?\('([a-z][\w-]*)'\)/g)) if (!pageIds.has(id)) missing.push(`${file}: #${id}`);
            for (const [, id] of source.matchAll(/querySelector(?:<[^>]*>)?\('#([\w-]+)'\)/g)) if (!pageIds.has(id)) missing.push(`${file}: #${id}`);
        }
        expect(missing).toEqual([]);
    });
    test('chapter and example IDs cannot shadow page elements', () => {
        const clashes: string[] = [];
        for (const chapter of loadChapters(root)) for (const [, id] of chapter.html.matchAll(/\bid="([^"]+)"/g)) if (pageIds.has(id)) clashes.push(`${chapter.slug}#${id}`);
        expect(clashes).toEqual([]);
    });
    test('every stage has a short tab label and every lesson names a valid stage', () => {
        for (const stage of Object.values(stages)) expect(stage.short.length).toBeGreaterThan(0);
        for (const lesson of lessons) expect(Object.hasOwn(stages, lesson.stage)).toBe(true);
    });
});

describe('static highlighting', () => {
    test('Yodl tokens map to the design palette classes', () => {
        const html = highlight("test \"x\" for Xor { drive!(a, 8'hFF) } // note\nlet y: u8 = a and b");
        for (const kind of ['keyword', 'string', 'ident', 'function', 'number', 'comment', 'type']) expect(html).toContain(`token-${kind}`);
        expect(highlight('a-1')).toContain('<span class="token-number">1</span>');
    });
    test('FIRRTL and RTLIL use their own comment syntax', () => {
        expect(highlight('node x = add(a, b) ; note', 'firrtl')).toContain('<span class="token-comment">; note</span>');
        expect(highlight('cell $and # note', 'rtlil')).toContain('<span class="token-comment"># note</span>');
        expect(highlight('<b>', 'plaintext')).toBe('&lt;b&gt;');
    });
    test('code blocks render a numbered gutter, one row per line', () => {
        const html = highlightLines('let a = 1\n\nlet b = 2\n');
        expect(html.match(/class="code-line"/g)).toHaveLength(3);
        expect(html).toContain('<span class="ln">3</span>');
    });
});

describe('documentation blocks and search', () => {
    const fenced = '```yodl live id=ex-one\nmodule Top() -> () {}\n```\n\n## Heading\n\nSome prose about registers.\n';
    test('live examples expose compile and playground actions; static ones are read-only', () => {
        const [live, fixed] = [extractExamples(fenced, 'test').examples[0], extractExamples('```yodl static id=ex-two\nlet x\n```', 'test').examples[0]];
        expect(exampleHTML(live)).toContain('data-action="compile"');
        expect(exampleHTML(live)).toContain('data-action="playground"');
        expect(exampleHTML(live)).toContain('ex-one.yodl');
        expect(exampleHTML(fixed)).not.toContain('data-action');
        expect(exampleHTML(fixed)).toContain('Read-only');
    });
    test('the search index keeps prose and code but not example chrome or line numbers', () => {
        const chapters = loadChapters(root);
        const index = buildSearchIndex(chapters);
        expect(index.length).toBeGreaterThan(chapters.length);
        const withCode = index.find(entry => entry.text.includes('Reg[u24]'));
        expect(withCode).toBeDefined();
        for (const entry of index) {
            expect(entry.text).not.toContain('Compile ▸');
            expect(entry.text).not.toContain('Open in Playground');
            expect(chapters.some(chapter => chapter.slug === entry.slug && chapter.headings.some(heading => heading.id === entry.id))).toBe(true);
        }
    });
});

describe('self-contained site', () => {
    test('nothing is loaded from a CDN or font service', () => {
        const cdn = /cdnjs|cloudflare|googleapis|gstatic|unpkg|jsdelivr|cdn\./;
        for (const path of ['src/main/playground.html', 'src/main/playground.css', 'src/main/theme.css', 'src/main/site-navigation.css', ...['playground', 'playground-editor', 'monaco', 'docs-view', 'search', 'simulation-view', 'theme'].map(name => `src/main/${name}.ts`)]) {
            expect({ path, cdn: cdn.test(read(path)) }).toEqual({ path, cdn: false });
        }
    });
    test('the vendored fonts named by the stylesheet exist with their licences', () => {
        const css = read('src/main/playground.css');
        const files = [...css.matchAll(/url\('\.\/fonts\/([^']+)'\)/g)].map(match => match[1]);
        expect(files).toHaveLength(3);
        for (const file of files) expect(readFileSync(resolve(root, 'src/main/fonts', file)).byteLength).toBeGreaterThan(1000);
        expect(read('src/main/fonts/LICENSE-HankenGrotesk.txt')).toContain('SIL Open Font License');
        expect(read('src/main/fonts/LICENSE-IBMPlexMono.txt')).toContain('SIL Open Font License');
    });
});

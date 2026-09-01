import { readFileSync } from 'node:fs';
import { resolve, relative, extname } from 'node:path';
import { createHash } from 'node:crypto';
import { stages } from '../main/compiler-stages.ts';
import type { Stage } from '../main/compiler-stages.ts';

export type Example = {
    id: string; title: string; source: string; display: string; hash: string;
    path: string; files: Record<string, string>; stage: Stage; live: boolean;
    unsupported: Stage[]; expect: 'success' | 'error' | 'skip'; diagnostic?: string; line: number;
};
export type Heading = { id: string; title: string; level: number };
export type Chapter = { slug: string; title: string; markdown: string; html: string; examples: Example[]; headings: Heading[] };
export const escapeHTML = (value: string) => value.replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]!);
export const plainText = (html: string) => html.replace(/<[^>]*>/g, ' ').replace(/&(?:amp|lt|gt|quot|#39);/g, value => ({ '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'" })[value]!).replace(/\s+/g, ' ').trim();

function sourceFile(root: string, path: string) {
    const full = resolve(root, path);
    const name = relative(resolve(root), full).replaceAll('\\', '/');
    if (!/^(examples|tour|book\/src)\//.test(name) || name.includes('..') || extname(name) !== '.yodl') throw new Error(`Invalid example source path: ${path}`);
    return { name, source: readFileSync(full, 'utf8') };
}

// The pinned Bun parser exposes only the first word of a fence in code.language.
// Extract top-level fences here, then let Bun handle all Markdown rendering.
// Keeping this function shared by the build and validation avoids two different
// interpretations of hidden lines or example metadata.
export function extractExamples(markdown: string, slug: string, root = process.cwd()) {
    const lines = markdown.replaceAll('\r\n', '\n').split('\n');
    const output: string[] = [];
    const examples: Example[] = [];
    const ids = new Set<string>();
    for (let i = 0; i < lines.length; i++) {
        const start = /^( {0,3})(`{3,}|~{3,})(.*)$/.exec(lines[i]);
        if (!start) { output.push(lines[i]); continue; }
        const begin = i;
        const fence = start[2];
        const body: string[] = [];
        for (i++; i < lines.length; i++) {
            const end = /^ {0,3}(`+|~+)\s*$/.exec(lines[i]);
            if (end && end[1][0] === fence[0] && end[1].length >= fence.length) break;
            body.push(lines[i].replace(new RegExp(`^ {0,${start[1].length}}`), ''));
        }
        const [language, ...options] = start[3].trim().split(/\s+/);
        if (language !== 'yodl') { output.push(...lines.slice(begin, Math.min(i + 1, lines.length))); continue; }
        if (i === lines.length) throw new Error(`${slug}:${begin + 1}: unclosed Yodl fence`);
        const config: Record<string, string> = {};
        for (const option of options) {
            const equal = option.indexOf('=');
            const key = equal < 0 ? option : option.slice(0, equal);
            const value = equal < 0 ? 'true' : option.slice(equal + 1);
            if (!['live', 'static', 'id', 'stage', 'src', 'files', 'expect', 'diagnostic', 'region', 'unsupported'].includes(key) || key in config) throw new Error(`${slug}:${begin + 1}: invalid or duplicate option ${key}`);
            config[key] = value;
        }
        const id = config.id ?? `example-${examples.length + 1}`;
        if (!/^[a-z][a-z0-9-]*$/.test(id) || ids.has(id)) throw new Error(`${slug}: invalid or duplicate example id ${id}`);
        ids.add(id);
        const stage = config.stage ?? (slug.startsWith('03_') || slug.startsWith('05_') ? 'write_typed' : slug.startsWith('06_') ? 'write_simplified' : 'write_firrtl');
        if (!Object.hasOwn(stages, stage)) throw new Error(`${slug}:${begin + 1}: unknown compiler stage ${stage}`);
        const unsupported = (config.unsupported?.split(',') ?? []) as Stage[];
        if (unsupported.some(value => !Object.hasOwn(stages, value)) || unsupported.includes(stage as Stage)) throw new Error(`${slug}: invalid unsupported stage`);
        const expect = config.expect ?? 'success';
        if (!['success', 'error', 'skip'].includes(expect)) throw new Error(`${slug}: invalid expectation ${expect}`);
        if (config.live && config.static) throw new Error(`${slug}: choose live or static`);
        let raw = body.join('\n') + '\n';
        let path = `book/src/${slug}/${id}.yodl`;
        if (config.src) {
            if (body.some(line => line.trim())) throw new Error(`${slug}: src examples must have an empty fence`);
            const file = sourceFile(root, config.src);
            raw = file.source; path = file.name;
        }
        const files: Record<string, string> = {};
        for (const name of config.files?.split(',') ?? []) {
            const file = sourceFile(root, name); files[file.name] = file.source;
        }
        // Remove just the mdBook marker and one optional separating space.
        // Preserve indentation and line count for precise compiler diagnostics.
        const source = raw.replace(/^# ?/gm, '');
        let display = raw.split('\n').filter(line => !line.startsWith('#')).join('\n');
        if (config.region) {
            const begin = `// region ${config.region}`;
            const end = `// endregion ${config.region}`;
            if (!raw.includes(begin) || !raw.includes(end) || raw.indexOf(end) < raw.indexOf(begin)) throw new Error(`${slug}: missing region ${config.region}`);
            display = raw.slice(raw.indexOf(begin) + begin.length, raw.indexOf(end)).trim();
        }
        examples.push({ id, title: id.replace(/^ex-/, '').replaceAll('-', ' '), source, display: display.trimEnd(), path, files, stage: stage as Stage,
            unsupported, hash: createHash('sha256').update(JSON.stringify({ source, files })).digest('hex').slice(0, 16),
            live: !config.static && expect !== 'skip', expect: expect as Example['expect'], diagnostic: config.diagnostic, line: begin + 1 });
        output.push('', `<div data-yodl-example="${examples.length - 1}"></div>`, '');
    }
    return { markdown: output.join('\n'), examples };
}

export function highlight(source: string) {
    // Static highlighting does not load Monaco or any browser JavaScript.
    return source.split(/(\/\/[^\n]*|"(?:[^"\\]|\\.)*"|\b\w+!|\b\d+(?:'[bhod]?[\da-fA-F_]+)?\b|\b[a-zA-Z_]\w*\b)/g).map(token => {
        let kind = '';
        if (token.startsWith('//')) kind = 'comment';
        else if (token.startsWith('"')) kind = 'string';
        else if (/^(module|declare|let|const|type|package|import|for|in|if|else|match|true|false)$/.test(token)) kind = 'keyword';
        else if (/^(u\d+|s\d+|uint|sint|bool|clock|Nat|Type)$/.test(token)) kind = 'type';
        else if (/^\w+!$/.test(token)) kind = 'function';
        else if (/^\d/.test(token)) kind = 'number';
        return kind ? `<span class="token-${kind}">${escapeHTML(token)}</span>` : escapeHTML(token);
    }).join('');
}

export function exampleHTML(example: Example) {
    const e = escapeHTML;
    return `<section class="code-example" id="${example.id}" aria-label="Example: ${e(example.title)}">
    <div class="example-header"><a class="example-title" href="#${example.id}"><span class="file-dot"></span>Yodl <span class="example-number">/ ${e(example.title)}</span></a><div class="example-actions">${example.live ? '<button data-action="edit" class="js-only">Edit & compile</button>' : '<span class="muted">Read-only</span>'}<button data-action="copy" class="js-only">Copy</button>${example.live ? '<button data-action="playground" class="js-only">Playground ↗</button>' : ''}</div></div>
    <pre class="example-static"><code>${highlight(example.display)}</code></pre>
    ${example.expect === 'error' ? '<p class="example-note">This example intentionally produces a compiler error. Edit it to explore the diagnostic.</p>' : ''}
    <div class="example-interactive" hidden></div><p class="example-status" role="status" hidden></p></section>`;
}

export function loadChapters(root = process.cwd()): Chapter[] {
    const summary = readFileSync(resolve(root, 'book/src/SUMMARY.md'), 'utf8');
    const entries = [...summary.matchAll(/^- \[([^\]]+)\]\(\.\/([\w-]+)\.md\)/gm)];
    if (!entries.length) throw new Error('SUMMARY.md contains no chapters');
    return entries.map(([, title, slug]) => {
        const markdown = readFileSync(resolve(root, `book/src/${slug}.md`), 'utf8');
        const extracted = extractExamples(markdown, slug, root);
        let html = Bun.markdown.html(extracted.markdown, { headings: { ids: true }, noHtmlSpans: true });
        html = html.replace(/<div data-yodl-example="(\d+)"><\/div>/g, (_, index) => exampleHTML(extracted.examples[Number(index)]));
        html = html.replace(/href="([^"#]+)\.md(#[^"]*)?"/g, 'href="$1.html$2"');
        // Preserve published mdBook anchors whose punctuation differs from Bun.
        const legacy: Record<string, string> = {
            'printfformatstring-args': 'printfformat_string-args',
            'assertpredicate-formatstring-args': 'assertpredicate-format_string-args',
            'stopexitcode': 'stopexit_code',
            'externalmodulename-filepath': 'externalmodule_name-file_path',
            'parameters-optional': 'parameters---optional',
        };
        for (const [current, old] of Object.entries(legacy)) html = html.replace(`id="${current}"`, `id="${old}"`);
        html = html.replace('<h3 id="positional-records-tuples">', '<span id="tuples"></span><h3 id="positional-records-tuples">').replace('<h3 id="named-records-structs-bundles">', '<span id="structs"></span><h3 id="named-records-structs-bundles">');
        const headings = [...html.matchAll(/<h([1-6]) id="([^"]+)">([\s\S]*?)<\/h\1>/g)].map(([, level, id, text]) => ({ level: +level, id, title: plainText(text) }));
        const documentIds = [...html.matchAll(/ id="([^"]+)"/g)].map(match => match[1]);
        if (new Set(documentIds).size !== documentIds.length) throw new Error(`${slug}: example IDs must not collide with heading IDs`);
        html = html.replace(/<h([1-6]) id="([^"]+)">([\s\S]*?)<\/h\1>/g, '<h$1 id="$2"><a class="heading-anchor" href="#$2">$3</a></h$1>');
        return { slug, title, markdown, html, examples: extracted.examples, headings };
    });
}

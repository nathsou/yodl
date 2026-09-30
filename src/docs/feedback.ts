import { highlightSegments } from '../main/highlight.ts';
import type { Range } from '../main/lsp-client.ts';
import type { Example } from './content.ts';

export type ExampleFeedback = {
    hovers: { range: Range; contents: { value: string } }[];
    diagnostics: { uri?: string; range?: Range; code: string; message: string; severity: number; notes: string[]; relatedInformation: { location: { uri: string; range: Range }; message: string }[] }[];
    semanticTokens: { data: number[] };
};
const e = (value: string) => value.replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]!);
const plainHover = (value: string) => value.replace(/^```yodl\n/, '').replace(/\n```$/, '');
const location = (uri: string, range?: Range) => `${uri}${range ? `:${range.start.line + 1}:${range.start.character + 1}` : ''}`;

/** Static HTML only: all language analysis happened in the MoonBit service. */
export function feedbackHTML(example: Example, feedback: ExampleFeedback): string {
    const semantic: { range: Range; kind: string }[] = [];
    const kinds = ['ident', 'type', 'ident', 'ident', 'ident', 'ident', 'function', 'keyword', 'number', 'string', 'punct'];
    let line = 0, character = 0;
    for (let i = 0; i < feedback.semanticTokens.data.length; i += 5) {
        const [delta, column, length, kind] = feedback.semanticTokens.data.slice(i, i + 5);
        character = delta ? column : character + column;
        line += delta;
        semantic.push({ range: { start: { line, character }, end: { line, character: character + length } }, kind: kinds[kind] });
    }
    const anchors = new Map<number, string>();
    const diagnostics = feedback.diagnostics.map((diagnostic, index) => ({ diagnostic, index }));
    const rows = example.display.split('\n').map((text, row) => {
        const origin = example.displayMap[row];
        if (!origin) return '';
        const clip = (range: Range) => {
            if (origin.line < range.start.line || origin.line > range.end.line) return null;
            const start = Math.max(0, (range.start.line === origin.line ? range.start.character : origin.character) - origin.character);
            const end = Math.min(text.length, (range.end.line === origin.line ? range.end.character : origin.character + text.length) - origin.character);
            // A zero-width diagnostic still marks the following character.
            if (start === end && start < text.length && range.start.line === range.end.line && range.start.character === range.end.character) return { start, end: start + 1 };
            return end > start ? { start, end } : null;
        };
        const hovers = feedback.hovers.flatMap(hover => { const range = clip(hover.range); return range ? [{ ...range, info: plainHover(hover.contents.value) }] : []; });
        const tokens = semantic.flatMap(token => { const range = clip(token.range); return range ? [{ ...range, kind: token.kind }] : []; });
        const errors = diagnostics.flatMap(({ diagnostic, index }) => {
            if ((diagnostic.uri ?? example.path) !== example.path || !diagnostic.range) return [];
            const range = clip(diagnostic.range);
            return range ? [{ ...range, diagnostic, index }] : [];
        });
        const syntax = highlightSegments(text);
        const boundaries = [...new Set([0, text.length, ...[...hovers, ...tokens, ...errors, ...syntax].flatMap(range => [range.start, range.end])])].sort((a, b) => a - b);
        const html = boundaries.slice(0, -1).map((start, i) => {
            const end = boundaries[i + 1];
            const covering = <T extends { start: number; end: number }>(ranges: T[]) => ranges.filter(range => range.start <= start && range.end >= end);
            const info = [...covering(hovers).map(hover => hover.info), ...covering(errors).map(({ diagnostic }) => `${diagnostic.code}: ${diagnostic.message}${diagnostic.notes.length ? `\n${diagnostic.notes.join('\n')}` : ''}`)].join('\n\n');
            const error = covering(errors)[0];
            const kind = covering(tokens)[0]?.kind ?? covering(syntax)[0]?.kind;
            const classes = [kind && `token-${kind}`, error && (error.diagnostic.severity === 2 ? 'code-warning' : 'code-error')].filter(Boolean).join(' ');
            let anchor = '';
            if (error && !anchors.has(error.index)) {
                const id = `${example.id}-problem-${error.index}`;
                anchors.set(error.index, id);
                anchor = ` id="${id}"`;
            }
            const content = e(text.slice(start, end));
            return classes || info ? `<span${anchor}${classes ? ` class="${classes}"` : ''}${info ? ` tabindex="0" data-code-info="${e(info)}" aria-label="${e(text.slice(start, end) + ': ' + info)}"` : ''}>${content}</span>` : content;
        }).join('');
        return `<div class="code-line"><span class="ln">${row + 1}</span><span class="lt">${html || ' '}</span></div>`;
    }).join('');
    const problems = feedback.diagnostics.length ? `<ul class="example-problems" aria-label="Source diagnostics">${feedback.diagnostics.map((diagnostic, index) => {
        const message = e(`${diagnostic.code}: ${diagnostic.message}`);
        const related = diagnostic.relatedInformation.map(item => `${location(item.location.uri, item.location.range)} — ${item.message}`);
        const notes = [...diagnostic.notes, ...related];
        return `<li class="${diagnostic.severity === 2 ? 'problem-warning' : 'problem-error'}">${anchors.has(index) ? `<a href="#${anchors.get(index)}">${message}</a>` : message}<small>${e(location(diagnostic.uri ?? example.path, diagnostic.range))}</small>${notes.length ? `<span>${e(notes.join('\n'))}</span>` : ''}</li>`;
    }).join('')}</ul>` : '';
    return `<div class="code-lines" tabindex="0" role="region" aria-label="Source: ${e(example.title)}">${rows}</div>${problems}`;
}

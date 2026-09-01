import { diagnosticLocation } from '../main/diagnostics.ts';
import { setupTheme } from '../main/theme.ts';
import { CompilerClient } from '../main/compiler-client.ts';
import { stages } from '../main/compiler-stages.ts';
import type { Stage } from '../main/compiler-stages.ts';
import { encodeProgram, decodeProgram } from '../main/share-codec.ts';
import type { Example } from './content.ts';

const data: { slug: string; version: string; revision: string; examples: Example[] } = JSON.parse(document.getElementById('chapter-data')!.textContent!);
const compiler = new CompilerClient();
let editorModule: typeof import('../main/playground-editor.ts') | undefined;
setupTheme(document.getElementById('theme-select') as HTMLSelectElement, dark => editorModule?.monaco?.editor.setTheme(dark ? 'yodl-dark' : 'yodl-light'));
const q = <T extends HTMLElement = HTMLElement>(root: ParentNode, selector: string) => root.querySelector<T>(selector)!;
const confirmDialog = document.getElementById('confirm-dialog') as HTMLDialogElement;
const shareDialog = document.getElementById('share-dialog') as HTMLDialogElement;
const shareInput = document.getElementById('share-url') as HTMLInputElement;
const states = new Map<string, { source: () => string; stage: () => Stage; close: () => void }>();
const draftKey = (id: string) => `yodl-docs-v1:${data.slug}:${id}`;
let shared: { id: string; source: string; stage: Stage } | undefined;
try {
    if (location.hash.startsWith('#example=')) {
        const payload = decodeProgram(location.hash.slice(9)) as any;
        if (payload.version !== 1 || !data.examples.some(e => e.id === payload.id) || typeof payload.source !== 'string' || !Object.hasOwn(stages, payload.stage)) throw new Error('Invalid shared example.');
        shared = payload;
    }
} catch {
    const warning = document.createElement('p'); warning.className = 'warning'; warning.textContent = 'This shared example could not be opened. The original examples are shown below.';
    document.getElementById('content')!.prepend(warning);
}
function key(example: Example) { return shared?.id === example.id ? `${draftKey(example.id)}:shared:${location.hash.slice(9)}` : draftKey(example.id); }
function readDraft(example: Example): { source: string; hash: string; stage?: Stage } | undefined {
    try {
        const value = JSON.parse(localStorage.getItem(key(example)) ?? 'null');
        if (typeof value?.source === 'string' && typeof value.hash === 'string') return value;
    } catch { /* Malformed or unavailable storage does not prevent editing. */ }
}
async function copy(text: string, control: HTMLElement, fallback?: HTMLInputElement) {
    const previous = control.textContent;
    try {
        await navigator.clipboard.writeText(text);
        control.textContent = 'Copied';
    } catch {
        if (fallback) { fallback.focus(); fallback.select(); }
        control.textContent = 'Select text to copy';
    }
    setTimeout(() => { control.textContent = previous; }, 1800);
}
q<HTMLButtonElement>(shareDialog, '#share-copy').onclick = event => void copy(shareInput.value, event.currentTarget as HTMLElement, shareInput);
function share(example: Example, source: string, stage: Stage) {
    const url = new URL(`${data.slug}.html`, location.href);
    url.hash = `example=${encodeProgram({ version: 1, id: example.id, source, stage })}`;
    if (url.href.length > 32_000) { status(example, 'This example is too large for a reliable share link. Copy the source instead.'); return; }
    shareInput.value = url.href;
    shareDialog.showModal(); shareInput.focus(); shareInput.select();
}
function playground(example: Example, source: string, stage: Stage) {
    const url = new URL('../playground.html', location.href);
    url.hash = `code=${encodeProgram({ version: 2, mode: 'examples', path: 'examples/Playground.yodl', source, stage, entryPath: example.path, files: example.files, origin: `${data.slug}.html#${example.id}` })}`;
    if (url.href.length > 32_000) { status(example, 'This example is too large for a reliable playground link. Copy the source instead.'); return; }
    location.href = url.href;
}
function status(example: Example, message: string, state = '') {
    const element = q(document.getElementById(example.id)!, '.example-status');
    element.hidden = !message; element.textContent = message; element.dataset.state = state;
}
for (const example of data.examples) {
    const card = document.getElementById(example.id)!;
    const draft = readDraft(example);
    if (draft && draft.source !== example.source) status(example, draft.hash === example.hash ? 'Your edited draft is saved in this browser.' : 'This example has been updated. Edit to review your saved draft alongside the new original.');
    q<HTMLButtonElement>(card, '[data-action="copy"]').onclick = event => void copy(states.get(example.id)?.source() ?? example.display, event.currentTarget as HTMLElement);
    if (!example.live) continue;
    q<HTMLButtonElement>(card, '[data-action="playground"]').onclick = () => playground(example, states.get(example.id)?.source() ?? readDraft(example)?.source ?? sharedSource(example) ?? example.source, states.get(example.id)?.stage() ?? readDraft(example)?.stage ?? example.stage);
    q<HTMLButtonElement>(card, '[data-action="edit"]').onclick = () => void openExample(example);
}
function sharedSource(example: Example) { return shared?.id === example.id ? shared.source : undefined; }

async function openExample(example: Example) {
    if (states.has(example.id)) return;
    const card = document.getElementById(example.id)!;
    const edit = q<HTMLButtonElement>(card, '[data-action="edit"]');
    edit.disabled = true; status(example, 'Loading editor…');
    const container = q(card, '.example-interactive');
    let input: any, output: any;
    try {
        editorModule ??= await import('../main/playground-editor.ts');
        await editorModule.loadMonaco();
        container.innerHTML = `<div class="editing-note">You are editing the complete program, including any supporting lines hidden in the article. <button data-control="original">Show original</button></div>
<div class="original-source" hidden><p>Current documentation source</p><pre></pre></div>
<div class="example-toolbar"><button data-control="compile" class="primary">Compile <kbd>⌘ / Ctrl ↵</kbd></button><label>Output <select data-control="stage" aria-label="Compiler output stage"></select></label><label class="auto-control"><input type="checkbox" data-control="auto"> Auto</label><button data-control="layout" aria-pressed="false">Side by side</button></div>
<nav class="example-tabs" aria-label="Example view"><button data-control="source-tab" aria-pressed="true">Source</button><button data-control="output-tab" aria-pressed="false">Output</button></nav><div class="example-panes" data-view="source"><div class="source-editor" aria-label="Source editor"></div><div class="output-pane"><div class="output-label">Compiler output <span data-control="output-state">Not compiled yet</span></div><div class="output-editor"></div></div></div>
<p class="stage-hint"></p><pre class="diagnostic" tabindex="0" hidden></pre><button data-control="jump" hidden>Go to error ↑</button>
<div class="example-bottom"><button data-control="reset">Reset</button><button data-control="share">Share</button><button data-control="compare">Compare output with original</button><button data-control="copy-output" disabled>Copy output</button><button data-control="close">Close editor</button></div><div class="output-comparison" hidden><p>Original output</p><pre data-comparison="original"></pre><p>Your output</p><pre data-comparison="edited"></pre></div>`;
        const control = <T extends HTMLElement = HTMLButtonElement>(name: string) => q<T>(container, `[data-control="${name}"]`);
        const original = q(container, '.original-source');
        q(original, 'pre').textContent = example.source;
        control('original').onclick = () => { original.hidden = !original.hidden; };
        const draft = readDraft(example);
        let draftHash = draft?.hash ?? example.hash;
        const source = draft?.source ?? sharedSource(example) ?? example.source;
        const picker = control<HTMLSelectElement>('stage');
        for (const [value, stage] of Object.entries(stages)) {
            const option = new Option(stage.label, value);
            option.disabled = example.unsupported.includes(value as Stage);
            if (option.disabled) option.text += ' (unavailable)';
            picker.add(option);
        }
        picker.value = draft?.stage && Object.hasOwn(stages, draft.stage) ? draft.stage : shared?.id === example.id ? shared.stage : example.stage;
        const mobileView = (view: 'source' | 'output') => {
            q(container, '.example-panes').dataset.view = view;
            control('source-tab').setAttribute('aria-pressed', String(view === 'source'));
            control('output-tab').setAttribute('aria-pressed', String(view === 'output'));
            input?.layout(); output?.layout();
        };
        control('source-tab').onclick = () => mobileView('source');
        control('output-tab').onclick = () => mobileView('output');
        const selectedStage = () => picker.value as Stage;
        container.hidden = false;
        q(card, '.example-static').hidden = true;
        const sourcePanel = q(container, '.source-editor');
        sourcePanel.style.height = `${Math.min(480, Math.max(200, source.split('\n').length * 23 + 40))}px`;
        input = await editorModule.createEditor(sourcePanel, { value: source, ariaLabel: `Source: ${example.title}` });
        output = await editorModule.createEditor(q(container, '.output-editor'), { readOnly: true, ariaLabel: `Compiler output: ${example.title}` });
        let revision = 0, outputRevision = -1, closed = false, lastOutput = '';
        let timer: ReturnType<typeof setTimeout> | undefined;
        const auto = control<HTMLInputElement>('auto');
        const diagnostic = q(container, '.diagnostic');
        const comparison = q(container, '.output-comparison');
        const outputState = control('output-state');
        const monaco = editorModule.monaco;
        const clearError = () => { diagnostic.hidden = true; control('jump').hidden = true; monaco.editor.setModelMarkers(input.getModel(), 'yodl', []); };
        const save = () => {
            try { localStorage.setItem(key(example), JSON.stringify({ source: input.getValue(), hash: draftHash, stage: selectedStage() })); return true; }
            catch { return false; }
        };
        const changed = () => {
            revision++; compiler.cancel(example.id); compiler.cancel(`${example.id}:original`); clearTimeout(timer);
            clearError(); comparison.hidden = true; control<HTMLButtonElement>('copy-output').disabled = true;
            outputState.textContent = lastOutput ? 'Out of date' : 'Not compiled yet';
            const saved = save();
            status(example, saved ? 'Draft saved locally. Compile to see the result.' : 'Draft could not be saved in this browser. Copy it to keep your edits.');
            if (auto.checked) timer = setTimeout(run, 500);
        };
        const hint = () => {
            q(container, '.stage-hint').textContent = stages[selectedStage()].description + (example.unsupported.length ? ` ${example.unsupported.map(value => stages[value].label).join(', ')} is not supported for this original example yet.` : '');
            monaco.editor.setModelLanguage(output.getModel(), stages[selectedStage()].language);
        };
        const run = async () => {
            clearTimeout(timer); clearError(); comparison.hidden = true; outputRevision = -1;
            const atRevision = revision;
            const source = input.getValue();
            control<HTMLButtonElement>('copy-output').disabled = true;
            if (matchMedia('(max-width: 540px)').matches) mobileView('output');
            outputState.textContent = 'Compiling…'; status(example, 'Compiling…');
            const result = await compiler.compile(example.id, { source, path: example.path, files: example.files, stage: selectedStage() });
            if (!result || closed || revision !== atRevision) return;
            if (result.error !== undefined) {
                diagnostic.hidden = false; diagnostic.textContent = result.error;
                outputState.textContent = lastOutput ? 'Previous output · out of date' : 'Compilation failed';
                const expected = example.expect === 'error' && source === example.source;
                status(example, expected ? 'Expected compiler error. Try editing the source to fix it.' : 'Compilation failed. See the diagnostic below.', expected ? '' : 'error');
                const location = diagnosticLocation(result.error, example.path);
                if (location) {
                    const range = input.getModel().validateRange(location);
                    monaco.editor.setModelMarkers(input.getModel(), 'yodl', [{ ...range, message: result.error, severity: monaco.MarkerSeverity.Error }]);
                    control('jump').hidden = false;
                    control('jump').onclick = () => { mobileView('source'); input.setSelection(range); input.revealRangeInCenter(range); input.focus(); };
                }
            } else {
                lastOutput = result.output ?? ''; outputRevision = revision;
                output.setValue(lastOutput); outputState.textContent = 'Up to date';
                control<HTMLButtonElement>('copy-output').disabled = false;
                status(example, `✓ Compiled in ${Math.round(result.duration)} ms · Yodl ${data.version} · ${data.revision}`, 'success');
            }
        };
        input.onDidChangeModelContent(changed);
        input.addAction({ id: 'compile-example', label: 'Compile example', keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter], run });
        control('compile').onclick = run;
        picker.onchange = () => { hint(); changed(); };
        auto.onchange = () => { clearTimeout(timer); if (auto.checked) void run(); };
        control('layout').onclick = () => {
            const split = card.classList.toggle('split'); control('layout').setAttribute('aria-pressed', String(split)); input.layout(); output.layout();
        };
        control('share').onclick = () => share(example, input.getValue(), selectedStage());
        control('reset').onclick = () => {
            confirmDialog.showModal();
            confirmDialog.addEventListener('close', () => {
                if (confirmDialog.returnValue === 'reset') { draftHash = example.hash; input.setValue(example.source); save(); }
            }, { once: true });
        };
        control('copy-output').onclick = event => { if (outputRevision === revision) void copy(lastOutput, event.currentTarget as HTMLElement); };
        control('compare').onclick = async () => {
            await run();
            if (outputRevision !== revision || closed || !diagnostic.hidden) return;
            const atRevision = revision;
            status(example, 'Compiling the original for comparison…');
            const result = await compiler.compile(`${example.id}:original`, { source: example.source, path: example.path, files: example.files, stage: selectedStage() });
            if (!result || closed || revision !== atRevision) return;
            comparison.hidden = false;
            q(comparison, '[data-comparison="original"]').textContent = result.error ?? result.output ?? '';
            q(comparison, '[data-comparison="edited"]').textContent = lastOutput;
            status(example, result.output === lastOutput ? 'Your edits produce the same output as the original at this stage.' : 'Original and edited output are shown below.');
        };
        const close = () => {
            closed = true; clearTimeout(timer); compiler.cancel(example.id); compiler.cancel(`${example.id}:original`); save();
            input.getModel()?.dispose(); output.getModel()?.dispose(); input.dispose(); output.dispose();
            states.delete(example.id); container.replaceChildren(); container.hidden = true; q(card, '.example-static').hidden = false;
            edit.disabled = false; edit.hidden = false; edit.textContent = 'Resume editing';
            status(example, 'Editor closed. Your draft stays in this browser.'); edit.focus();
        };
        control('close').onclick = close;
        states.set(example.id, { source: () => input.getValue(), stage: selectedStage, close });
        hint(); edit.hidden = true;
        if (draft && draft.hash !== example.hash) { original.hidden = false; status(example, 'The documentation changed since your draft was saved. Compare with the current original above, or Reset to adopt it.'); }
        else status(example, shared?.id === example.id ? 'Shared example opened in a separate draft. Your ordinary draft is unchanged.' : 'Ready to compile. Edits stay in this browser.');
        input.focus();
    } catch (error) {
        input?.dispose(); output?.dispose(); container.hidden = true; q(card, '.example-static').hidden = false;
        edit.disabled = false; status(example, `${(error as Error).message}`, 'error');
    }
}
if (shared) {
    const example = data.examples.find(e => e.id === shared!.id)!;
    if (example.live) { document.getElementById(example.id)!.scrollIntoView(); void openExample(example); }
}
window.addEventListener('pagehide', () => compiler.dispose());

const searchDialog = document.getElementById('search-dialog') as HTMLDialogElement;
const searchInput = document.getElementById('search-input') as HTMLInputElement;
const results = document.getElementById('search-results')!;
const searchStatus = document.getElementById('search-status')!;
type SearchEntry = { title: string; chapter: string; url: string; text: string };
let searchData: SearchEntry[] | undefined;
let searchLoading: Promise<void> | undefined;
async function search() {
    const query = searchInput.value.toLowerCase().trim();
    if (!searchData) {
        searchStatus.textContent = 'Loading search…';
        try {
            await (searchLoading ??= fetch('./search.json').then(response => {
                if (!response.ok) throw new Error('Search unavailable'); return response.json();
            }).then(value => { searchData = value; }).finally(() => { searchLoading = undefined; }));
        } catch { searchStatus.textContent = 'Search could not load. Try typing again, or browse the chapters.'; return; }
        if (searchInput.value.toLowerCase().trim() !== query) return;
    }
    results.replaceChildren();
    if (!query) { searchStatus.textContent = 'Search all chapters, including operators and example code.'; return; }
    const words = query.split(/\s+/);
    const matches = searchData!.filter(entry => words.every(word => `${entry.title} ${entry.text}`.toLowerCase().includes(word))).sort((a, b) => Number(b.title.toLowerCase().includes(query)) - Number(a.title.toLowerCase().includes(query))).slice(0, 30);
    searchStatus.textContent = matches.length ? `${matches.length} result${matches.length === 1 ? '' : 's'}` : 'No results. Try a concept, operator, or built-in name.';
    for (const entry of matches) {
        const link = document.createElement('a'); link.href = entry.url;
        link.addEventListener('click', () => searchDialog.close());
        const heading = document.createElement('strong'); heading.textContent = `${entry.chapter} / ${entry.title}`;
        const excerpt = document.createElement('span');
        const start = Math.max(0, entry.text.toLowerCase().indexOf(words[0]) - 50);
        excerpt.textContent = `${start ? '…' : ''}${entry.text.slice(start, start + 180)}…`;
        link.append(heading, excerpt); results.append(link);
    }
}
const openSearch = () => { searchDialog.showModal(); searchInput.focus(); void search(); };
document.getElementById('search-open')!.onclick = openSearch;
document.getElementById('search-close')!.onclick = () => searchDialog.close();
searchInput.oninput = () => void search();
searchDialog.addEventListener('keydown', event => {
    const links = Array.from(results.querySelectorAll('a'));
    if (event.key === 'ArrowDown') { event.preventDefault(); links[Math.min(links.length - 1, links.indexOf(document.activeElement as HTMLAnchorElement) + 1)]?.focus(); }
    if (event.key === 'ArrowUp') { event.preventDefault(); const index = links.indexOf(document.activeElement as HTMLAnchorElement); if (index <= 0) searchInput.focus(); else links[index - 1].focus(); }
    if (event.key === 'Enter' && document.activeElement === searchInput) links[0]?.click();
});
document.addEventListener('keydown', event => {
    const target = event.target as HTMLElement;
    if (event.key === '/' && !target.closest('input, textarea, [contenteditable="true"], .monaco-editor') && !document.querySelector('dialog[open]')) { event.preventDefault(); openSearch(); }
});
if (matchMedia('(max-width: 820px)').matches) (document.querySelector('.chapter-menu') as HTMLDetailsElement).open = false;
const tocLinks = Array.from(document.querySelectorAll<HTMLAnchorElement>('.page-toc nav a'));
const observer = new IntersectionObserver(entries => {
    for (const entry of entries) if (entry.isIntersecting) for (const link of tocLinks) {
        if (link.hash === `#${entry.target.id}`) link.setAttribute('aria-current', 'location'); else link.removeAttribute('aria-current');
    }
}, { rootMargin: '-80px 0px -65% 0px' });
for (const heading of Array.from(document.querySelectorAll('article h2, article h3'))) observer.observe(heading);

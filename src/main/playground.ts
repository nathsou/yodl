import { chapterLessons } from '../docs/links.ts';
import { examples, files, tour, stages, blankPath, initialSelection, validSelection, encodeShare, decodeShare, diagnosticLocation } from './playground-model.ts';
import type { Selection, Stage, Mode, SharedProgram } from './playground-model.ts';
import { CompilerClient } from './compiler-client.ts';
import { decodeProgram } from './share-codec.ts';
import { setupTheme, setupAccent } from './theme.ts';
import { loadEditors, monaco, applyEditorTheme } from './playground-editor.ts';
import { createSimulationView } from './simulation-view.ts';
import { createDocs, docsUrl } from './docs-view.ts';
import type { ChapterData } from './docs-view.ts';
import { createSearch } from './search.ts';

const element = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const button = (id: string) => element<HTMLButtonElement>(id);
const prefix = 'yodl-playground-v2:';
let storageAvailable = true;
function readStorage(key: string) {
    try { return localStorage.getItem(prefix + key); } catch { storageAvailable = false; return null; }
}
function writeStorage(key: string, value: string) {
    try { localStorage.setItem(prefix + key, value); } catch { storageAvailable = false; }
}
function notice(message: string) {
    const container = element('notice');
    container.textContent = message;
    const close = document.createElement('button');
    close.textContent = 'Dismiss';
    close.addEventListener('click', () => { container.hidden = true; });
    container.append(close);
    container.hidden = false;
}
function setStatus(message: string, state = 'idle') {
    element('compile-status').textContent = message;
    element('compile-status').dataset.state = state;
}
const mac = /Mac|iPhone|iPad/.test(navigator.platform);
setupTheme(element('theme-switch'), () => applyEditorTheme());
setupAccent(document.querySelector<HTMLElement>('.accent-picker')!, () => applyEditorTheme());

// ---------------------------------------------------------------------------
// Sections. Tour, Playground and Docs are modes of this one page. The editor
// modes share a workspace; the URL records which lesson, chapter or shared
// circuit is open, so links and the back button behave like separate pages.
// ---------------------------------------------------------------------------
type Section = 'tour' | 'playground' | 'docs';
type SharedState = { code: string; mode: Mode; path: string; stage: Stage; source: string; files: Record<string, string>; entryPath?: string; origin?: string };
type Target =
    | { section: 'tour'; lesson?: string }
    | { section: 'playground'; path?: string }
    | { section: 'docs'; chapter?: string; anchor?: string }
    | { section: 'shared'; shared: SharedState };
const sectionOf = (mode: Mode): Section => mode === 'tour' ? 'tour' : 'playground';
const lessonPath = (lesson: { file: string }) => `tour/${lesson.file}`;
const baseName = (path: string) => path.split('/').at(-1)!;

let section: Section = 'tour';
let docsSlug: string | undefined;
let docsAnchor: string | undefined;
let selection: Selection = { ...initialSelection };
try {
    const saved = JSON.parse(readStorage('selection') ?? 'null');
    if (validSelection(saved)) selection = saved;
} catch { /* Ignore incompatible saved preferences. */ }
// Sharing never overwrites the recipient's ordinary lesson/example draft.
let shared: SharedState | undefined;
const sharedKey = () => shared ? `shared:${shared.code}` : '';
const entryPath = () => shared?.entryPath ?? selection.path;

let editors: Awaited<ReturnType<typeof loadEditors>> | undefined;
let editorReady: Promise<void> | undefined;
let loadingSource = false;
let entryModel: any;
let activeSourcePath = '';
let errorPath = '';
const importedModels = new Map<string, any>();
const sourceViews = new Map<string, any>();
const entrySource = () => entryModel.getValue() as string;

function openSource(path: string) {
    const model = path === entryPath() ? entryModel : importedModels.get(path);
    if (!model) return;
    if (activeSourcePath) sourceViews.set(activeSourcePath, editors!.input.saveViewState());
    activeSourcePath = path;
    editors!.input.setModel(model);
    editors!.input.updateOptions({ readOnly: path !== entryPath(), ariaLabel: `${path}${path === entryPath() ? ', main source' : ', imported, read only'}` });
    const view = sourceViews.get(path);
    if (view) editors!.input.restoreViewState(view);
    renderSourceTabs();
    editors!.input.layout();
}
function renderSourceTabs() {
    const imported = activeSourcePath !== entryPath();
    const hasImports = importedModels.size > 0;
    element('source-files').hidden = !hasImports;
    element('editors').dataset.imports = String(hasImports);
    element('input-filename').textContent = baseName(activeSourcePath || entryPath());
    element('input-filename').title = activeSourcePath;
    element('source-kind').textContent = imported ? 'Imported · read only' : '';
    element('source-kind').hidden = !imported;
    element('draft-badge').hidden = imported || !entryModel || entrySource() === originalSource();
    button('reset-button').disabled = imported;
    element('source-files').replaceChildren(...[entryPath(), ...importedModels.keys()].map(path => {
        const tab = document.createElement('button');
        tab.textContent = baseName(path);
        tab.title = path === entryPath() ? `${path} · compile and simulation target` : `${path} · imported, read only`;
        tab.setAttribute('aria-pressed', String(path === activeSourcePath));
        tab.onclick = () => openSource(path);
        return tab;
    }));
}
function updateImportedSources(sources: Record<string, string>) {
    // Models come from actual compiler reads, so resolution and transitive
    // imports cannot drift from the compiler's rules.
    const imports = Object.entries(sources).filter(([path]) => path !== entryPath() && path.endsWith('.yodl'));
    const wanted = new Set(imports.map(([path]) => path));
    if (activeSourcePath !== entryPath() && !wanted.has(activeSourcePath)) openSource(entryPath());
    for (const [path, model] of importedModels) {
        if (!wanted.has(path)) { model.dispose(); importedModels.delete(path); sourceViews.delete(path); }
    }
    for (const [path, source] of imports) {
        const existing = importedModels.get(path);
        if (!existing) importedModels.set(path, monaco.editor.createModel(source, 'yodl'));
        else if (existing.getValue() !== source) existing.setValue(source);
    }
    renderSourceTabs();
}
function resetSourceWorkspace() {
    activeSourcePath = '';
    sourceViews.clear();
    editors!.input.setModel(entryModel);
    for (const model of importedModels.values()) model.dispose();
    importedModels.clear();
    openSource(entryPath());
}

let revision = 0;
let lastOutput = '';
let outputRevision = -1;
const compiler = new CompilerClient();
const importResolver = new CompilerClient();
let importRevision = 0;
let importTimer: ReturnType<typeof setTimeout> | undefined;
const allFiles = () => ({ ...files, ...shared?.files });
async function loadImports() {
    const current = ++importRevision;
    const result = await importResolver.compile('imports', { source: entrySource(), path: entryPath(), stage: 'write_source', files: allFiles() });
    if (current === importRevision && result?.sources) updateImportedSources(result.sources);
}
function scheduleImports() {
    ++importRevision;
    importResolver.cancel('imports');
    clearTimeout(importTimer);
    importTimer = setTimeout(loadImports, 150);
}
const sourceHasTests = (source: string) => /\btest\s+(?:"|for\b)/.test(source);

const simulation = createSimulationView({
    request: () => ({ source: entrySource(), path: entryPath(), files: allFiles() }),
    setStatus,
});
let requestId = 0;
let latestRequest = 0;
let errorRange: ReturnType<typeof diagnosticLocation> = null;
const defaultBlank = '// Start a new circuit here.\nmodule Top(a: bool) -> (q: bool) {\n    q = a\n}\n';
const originals = (path: string) => files[path] ?? defaultBlank;
const originalSource = () => shared ? shared.source : originals(selection.path);
function sourceRevision(source: string): string {
    // A compact, deterministic revision keeps built-in example drafts from
    // masking updated simulator adapters after a site deployment. User edits
    // remain sticky until the example source itself changes again.
    let hash = 2166136261;
    for (let i = 0; i < source.length; i++) {
        hash ^= source.charCodeAt(i);
        hash = Math.imul(hash, 16777619);
    }
    return (hash >>> 0).toString(36);
}
const draftKeyFor = (path: string) => `draft:${path}:${sourceRevision(originals(path))}`;
const draftKey = () => sharedKey() || draftKeyFor(selection.path);

// ---------------------------------------------------------------------------
// Drafts. The index lets the Playground list what the reader has edited, with
// a relative time. The source itself stays under its existing storage key.
// ---------------------------------------------------------------------------
type DraftEntry = { key: string; path: string; label: string; updated: number; shared?: boolean };
const maxDrafts = 12;
function readDrafts(): DraftEntry[] {
    try {
        const list = JSON.parse(readStorage('drafts') ?? '[]');
        return Array.isArray(list) ? list.filter((entry): entry is DraftEntry => typeof entry?.key === 'string' && typeof entry.label === 'string' && typeof entry.updated === 'number') : [];
    } catch { return []; }
}
function noteDraft() {
    if (selection.mode !== 'examples' && !shared) return;
    const key = draftKey();
    const list = readDrafts();
    const existing = list.findIndex(entry => entry.key === key);
    const edited = entrySource() !== originalSource();
    if (!edited) {
        if (existing < 0) return;
        list.splice(existing, 1);
    } else {
        // Typing calls this constantly; refresh the timestamp at most every 30 s.
        if (existing === 0 && Date.now() - list[0].updated < 30_000) return;
        if (existing >= 0) list.splice(existing, 1);
        const label = shared ? `Shared · ${baseName(shared.entryPath ?? shared.path)}` : selection.path === blankPath ? 'scratch.yodl' : baseName(selection.path);
        list.unshift({ key, path: selection.path, label, updated: Date.now(), ...(shared ? { shared: true } : {}) });
    }
    writeStorage('drafts', JSON.stringify(list.slice(0, maxDrafts)));
    renderDrafts();
}
function relativeTime(time: number) {
    const minutes = Math.floor((Date.now() - time) / 60_000);
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes} min ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours} h ago`;
    const days = Math.floor(hours / 24);
    return days === 1 ? 'Yesterday' : days < 14 ? `${days} days ago` : new Date(time).toLocaleDateString();
}

function saveDraft() {
    if (!entryModel) return;
    writeStorage(draftKey(), entrySource());
    if (!shared) writeStorage('selection', JSON.stringify(selection));
    element('save-status').textContent = storageAvailable ? 'Draft saved locally' : 'Draft not saved · storage unavailable';
    element('draft-badge').hidden = activeSourcePath !== entryPath() || entrySource() === originalSource();
    noteDraft();
}

// ---------------------------------------------------------------------------
// Sidebar: the lesson guide (Tour) and the example library (Playground)
// ---------------------------------------------------------------------------
const lessonIndex = () => tour.findIndex(lesson => lessonPath(lesson) === selection.path);
const chapterFor = (lessonId: string) => Object.entries(chapterLessons).find(([, lessons]) => lessons.some(lesson => lesson.id === lessonId))?.[0];
const chapterTitles = new Map<string, string>();
const fallbackTitle = (slug: string) => { const words = slug.replace(/^\d+_/, '').replaceAll('_', ' '); return words[0].toUpperCase() + words.slice(1); };
const pad = (value: number) => String(value).padStart(2, '0');

function renderGuide() {
    const index = lessonIndex();
    const lesson = tour[index];
    if (!lesson) return;
    element('lesson-position').textContent = `Tour · Lesson ${pad(index + 1)} of ${tour.length}`;
    element('lesson-topic').textContent = lesson.topic;
    element('lesson-title').textContent = lesson.title;
    element('lesson-intro').textContent = lesson.intro;
    element('lesson-observe').textContent = lesson.observe;
    element('lesson-challenge').textContent = lesson.challenge;
    element('lesson-concepts').replaceChildren(...lesson.concepts.map((text, i) => {
        const item = document.createElement('li');
        const number = document.createElement('span'); number.className = 'n'; number.textContent = pad(i + 1);
        const body = document.createElement('span'); body.textContent = text;
        item.append(number, body);
        return item;
    }));
    button('suggested-stage').textContent = `Open ${stages[lesson.stage as Stage].label} →`;
    const slug = chapterFor(lesson.id);
    element('lesson-reference').hidden = !slug;
    if (slug) {
        const anchor = element<HTMLAnchorElement>('related-docs');
        anchor.textContent = chapterTitles.get(slug) ?? fallbackTitle(slug);
        anchor.href = docsUrl(slug);
        anchor.onclick = event => { event.preventDefault(); void go({ section: 'docs', chapter: slug }); };
    }
    const previous = tour[index - 1], next = tour[index + 1];
    button('previous-lesson').disabled = !previous;
    element('previous-title').textContent = previous?.title ?? '';
    button('next-lesson').disabled = false;
    element('next-title').textContent = next?.title ?? 'Explore the Playground';
    for (const [i, item] of Array.from(element('lesson-progress').children).entries()) {
        if (i === index) item.setAttribute('aria-current', 'step'); else item.removeAttribute('aria-current');
    }
    for (const [i, item] of Array.from(element('lesson-list').children).entries()) {
        if (i === index) item.setAttribute('aria-current', 'step'); else item.removeAttribute('aria-current');
    }
}
function buildLessonNavigation() {
    element('lesson-progress').style.setProperty('--lessons', String(tour.length));
    element('lesson-progress').replaceChildren(...tour.map((lesson, i) => {
        const segment = document.createElement('button');
        segment.type = 'button';
        segment.title = `${pad(i + 1)} · ${lesson.title}`;
        segment.setAttribute('aria-label', `Lesson ${i + 1}: ${lesson.title}`);
        segment.onclick = () => void go({ section: 'tour', lesson: lesson.id });
        return segment;
    }));
    element('lesson-list').replaceChildren(...tour.map((lesson, i) => {
        const row = document.createElement('button');
        row.type = 'button';
        row.innerHTML = '<span class="n"></span><span><strong></strong><small></small></span>';
        row.querySelector('.n')!.textContent = pad(i + 1);
        row.querySelector('strong')!.textContent = lesson.title;
        row.querySelector('small')!.textContent = lesson.topic;
        row.onclick = () => { setLessonList(false); void go({ section: 'tour', lesson: lesson.id }); };
        return row;
    }));
}
function setLessonList(open: boolean) {
    element('lesson-list-scrim').hidden = !open;
    button('lesson-list-button').setAttribute('aria-expanded', String(open));
    if (open) element('lesson-list').querySelector<HTMLElement>('[aria-current]')?.scrollIntoView({ block: 'nearest' });
}

function exampleNote(path: string) {
    const source = files[path] ?? '';
    const lines = source.split('\n').length;
    return `${lines} lines${source.includes('@simulation') ? ' · simulation' : ''}`;
}
function renderLibrary() {
    element('example-list').replaceChildren(...examples.map(path => {
        const entry = document.createElement('button');
        entry.type = 'button';
        entry.className = 'entry';
        const current = !shared && selection.path === path;
        if (current) entry.setAttribute('aria-current', 'true');
        const name = document.createElement('span'); name.className = 'entry-name'; name.textContent = baseName(path).replace(/\.yodl$/, '');
        const note = document.createElement('span'); note.className = 'entry-note'; note.textContent = current ? baseName(path) : exampleNote(path);
        entry.append(name, note);
        entry.onclick = () => { writeStorage('last:examples', path); void go({ section: 'playground', path }); };
        return entry;
    }));
    renderDrafts();
}
function renderDrafts() {
    // Drafts of an example whose source changed since are no longer applicable.
    const drafts = readDrafts().filter(entry => entry.shared || (entry.path === blankPath || examples.includes(entry.path)) && entry.key === draftKeyFor(entry.path));
    element('drafts-empty').hidden = drafts.length > 0;
    element('draft-list').replaceChildren(...drafts.map(draft => {
        const entry = document.createElement('button');
        entry.type = 'button';
        entry.className = 'entry draft';
        if (draft.key === draftKey() && (selection.mode === 'examples' || shared)) entry.setAttribute('aria-current', 'true');
        const name = document.createElement('span'); name.className = 'entry-name'; name.textContent = draft.label;
        const time = document.createElement('span'); time.className = 'entry-note'; time.textContent = relativeTime(draft.updated);
        entry.append(name, time);
        entry.onclick = () => {
            if (draft.shared) {
                const code = draft.key.slice('shared:'.length);
                try { void go({ section: 'shared', shared: toSharedState(decodeShare(`#code=${code}`)!, code) }); } catch (error) { notice((error as Error).message); }
            } else void go({ section: 'playground', path: draft.path });
        };
        return entry;
    }));
}

// ---------------------------------------------------------------------------
// Output stages
// ---------------------------------------------------------------------------
const suggestedStage = () => selection.mode === 'tour' ? tour[lessonIndex()]?.stage as Stage | undefined : undefined;
function renderStageTabs() {
    const showTests = selection.stage === 'test' || (entryModel !== undefined && sourceHasTests(entrySource()));
    const suggested = suggestedStage();
    element('stage-tabs').replaceChildren(...(Object.keys(stages) as Stage[]).filter(stage => stage !== 'test' || showTests).map(stage => {
        const tab = document.createElement('button');
        tab.type = 'button';
        tab.className = 'stage-tab';
        tab.dataset.stage = stage;
        tab.title = stages[stage].description;
        tab.setAttribute('aria-pressed', String(stage === selection.stage));
        tab.append(stages[stage].short);
        if (stage === suggested && stage !== selection.stage) {
            const dot = document.createElement('span'); dot.className = 'suggested'; dot.title = 'Suggested for this lesson';
            tab.append(dot);
        }
        tab.onclick = () => changeStage(stage);
        return tab;
    }));
}
function setOutputView(view: 'output' | 'simulation') {
    element('output-pane').dataset.view = view;
    button('view-output').setAttribute('aria-pressed', String(view === 'output'));
    button('view-simulate').setAttribute('aria-pressed', String(view === 'simulation'));
    editors?.output.layout();
}
function renderStage() {
    const stage = stages[selection.stage];
    element('stage-description').textContent = stage.description;
    element('stage-description').title = stage.description;
    if (editors) monaco.editor.setModelLanguage(editors.output.getModel(), stage.language);
    renderStageTabs();
}

function renderSelection() {
    setOutputView('output');
    renderSourceTabs();
    renderGuide();
    renderLibrary();
    element('related-docs-menu').hidden = !shared?.origin;
    renderStage();
}
function syncChrome() {
    for (const item of Array.from(document.querySelectorAll<HTMLButtonElement>('.mode-switch button'))) item.setAttribute('aria-pressed', String(item.dataset.mode === section));
    const editor = section !== 'docs';
    element('editor-view').hidden = !editor;
    element('docs-view').hidden = editor;
    element('editor-view').dataset.section = section;
    element('guide').hidden = section !== 'tour';
    element('library').hidden = section !== 'playground';
    if (editor) {
        document.title = section === 'tour' ? 'Tour · Yodl' : 'Playground · Yodl';
        editors?.input.layout(); editors?.output.layout();
    } else simulation.stop();
}

function clearDiagnostics() {
    element('problems').hidden = true;
    errorRange = null;
    if (!entryModel) return;
    for (const model of [entryModel, ...importedModels.values()]) monaco.editor.setModelMarkers(model, 'yodl', []);
}
function markChanged() {
    compiler.cancel('playground');
    simulation.stop();
    revision++;
    scheduleImports();
    latestRequest = ++requestId;
    clearDiagnostics();
    button('copy-output').disabled = true;
    button('output-download').disabled = true;
    button('download-output').disabled = true;
    setStatus(lastOutput ? 'Source changed · output is out of date' : 'Ready to compile');
    const hadTests = element('stage-tabs').querySelector('[data-stage="test"]') !== null;
    if (hadTests !== (selection.stage === 'test' || sourceHasTests(entrySource()))) renderStageTabs();
}

/** Loads a selection into the editor. With no editor yet, it only records what
 * the editor should open with once Monaco has loaded. */
function choose(next: Selection, nextShared?: SharedState) {
    if (editors) saveDraft();
    shared = nextShared;
    selection = next;
    renderGuide();
    renderLibrary();
    if (!editors) return;
    resetSourceWorkspace();
    // Simulation fields describe the selected design. Do not carry a top or
    // clock from a previous example into the next one.
    simulation.clear();
    loadingSource = true;
    editors.input.setValue(readStorage(draftKey()) ?? shared?.source ?? originals(selection.path));
    loadingSource = false;
    editors.input.setScrollTop(0);
    editors.output.setValue('');
    lastOutput = '';
    outputRevision = -1;
    renderSelection();
    saveDraft();
    markChanged();
    void runCompile();
}
function changeStage(stage: Stage) {
    selection.stage = stage;
    if (!editors) { renderStage(); return; }
    simulation.clearFrame();
    editors.output.setValue('');
    lastOutput = '';
    renderStage();
    setOutputView('output');
    saveDraft();
    markChanged();
    void runCompile();
}
function setMobileView(view: string) {
    element('editors').dataset.view = view;
    button('source-tab').setAttribute('aria-pressed', String(view === 'source'));
    button('output-tab').setAttribute('aria-pressed', String(view === 'output'));
    editors?.input.layout(); editors?.output.layout();
}
function showError(message: string) {
    setOutputView('output');
    element('problems').hidden = false;
    element('error-message').textContent = message;
    errorPath = [entryPath(), ...importedModels.keys()].find(path => diagnosticLocation(message, path)) ?? entryPath();
    errorRange = diagnosticLocation(message, errorPath);
    button('jump-error').hidden = errorRange === null;
    if (errorRange) {
        const model = errorPath === entryPath() ? entryModel : importedModels.get(errorPath);
        const range = model.validateRange(errorRange);
        errorRange = range;
        monaco.editor.setModelMarkers(model, 'yodl', [{ ...range, message, severity: monaco.MarkerSeverity.Error }]);
    }
    setStatus(lastOutput ? 'Compilation failed · showing previous output' : 'Compilation failed · check diagnostics', 'error');
}
async function runCompile() {
    if (!editors) return;
    simulation.stop();
    simulation.clearFrame();
    const id = ++requestId;
    latestRequest = id;
    const compiledRevision = revision;
    clearDiagnostics();
    setStatus('Compiling…', 'loading');
    const result = await compiler.compile('playground', { source: entrySource(), path: entryPath(), stage: selection.stage, files: allFiles() });
    if (!result || id !== latestRequest) return;
    if (result.error !== undefined) { showError(result.error); return; }
    lastOutput = result.output ?? '';
    outputRevision = compiledRevision;
    editors.output.setValue(lastOutput);
    renderStage();
    setOutputView('output');
    button('copy-output').disabled = !lastOutput;
    button('output-download').disabled = !lastOutput;
    button('download-output').disabled = !lastOutput;
    setStatus(`Compiled · ${Math.round(result.duration)} ms`, 'success');
}

function download(name: string, content: string) {
    const url = URL.createObjectURL(new Blob([content], { type: 'text/plain;charset=utf-8' }));
    const link = document.createElement('a'); link.href = url; link.download = name; link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
}
async function copy(text: string, control: HTMLButtonElement) {
    try {
        await navigator.clipboard.writeText(text);
        const previous = control.textContent;
        control.textContent = 'Copied';
        setTimeout(() => { control.textContent = previous; }, 1800);
    } catch {
        notice('Clipboard access is unavailable. Select the text and use your browser’s Copy command.');
        if (control.id === 'copy-share') element<HTMLInputElement>('share-url').select();
        else { editors!.output.focus(); editors!.output.setSelection(editors!.output.getModel().getFullModelRange()); }
    }
}
function downloadOutput() {
    if (outputRevision === revision) download(`${baseName(selection.path).replace(/\.yodl$/, '')}.${stages[selection.stage].extension}`, lastOutput);
}
function setMenu(open: boolean) {
    element('file-menu').hidden = !open;
    button('menu-button').setAttribute('aria-expanded', String(open));
}
function openShare() {
    if (!editors) return;
    const url = new URL(location.href);
    url.search = '';
    url.hash = `code=${encodeShare({ ...selection, source: entrySource(), files: shared?.files, entryPath: shared?.entryPath, origin: shared?.origin })}`;
    if (url.href.length > 32_000) { notice('This circuit is too large for a reliable share link. Use Download source instead.'); return; }
    element<HTMLInputElement>('share-url').value = url.href;
    element<HTMLDialogElement>('share-dialog').showModal();
    element<HTMLInputElement>('share-url').select();
}
function requestReset() {
    if (editors && activeSourcePath === entryPath()) element<HTMLDialogElement>('reset-dialog').showModal();
}

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------
function toSharedState(program: SharedProgram, code: string): SharedState {
    return { code, mode: program.mode, path: program.path, stage: program.stage, source: program.source, files: program.files ?? {}, entryPath: program.entryPath, origin: program.origin };
}
function resumePath(mode: Mode) {
    if (selection.mode === mode && !shared) return selection.path;
    const previous = readStorage(`last:${mode}`);
    if (validSelection({ mode, path: previous, stage: 'write_firrtl' })) return previous!;
    return mode === 'tour' ? initialSelection.path : blankPath;
}
function currentUrl() {
    const url = new URL(location.href);
    url.search = ''; url.hash = '';
    if (section === 'docs') {
        url.searchParams.set('mode', 'docs');
        if (docsSlug) url.searchParams.set('chapter', docsSlug);
        if (docsAnchor) url.hash = docsAnchor;
    } else if (shared) url.hash = `code=${shared.code}`;
    else if (section === 'tour') url.searchParams.set('lesson', tour[lessonIndex()]?.id ?? tour[0].id);
    else {
        url.searchParams.set('mode', 'examples');
        if (selection.path !== blankPath) url.searchParams.set('example', baseName(selection.path).replace(/\.yodl$/, ''));
    }
    return url.href;
}
function updateUrl(how: 'push' | 'replace' | 'none') {
    const next = currentUrl();
    if (how === 'none' || next === location.href) return;
    if (how === 'push') history.pushState(null, '', next); else history.replaceState(null, '', next);
}

let navigation = 0;
async function go(target: Target, how: 'push' | 'replace' | 'none' = 'push') {
    const token = ++navigation;
    setLessonList(false);
    if (target.section === 'docs') {
        section = 'docs';
        syncChrome();
        docsSlug = target.chapter; docsAnchor = target.anchor;
        const chapter = await docs.show(target.chapter, target.anchor);
        if (token !== navigation) return;
        docsSlug = chapter?.slug ?? target.chapter;
        if (chapter) document.title = `${chapter.title} · Yodl`;
        updateUrl(how);
        return;
    }
    if (target.section === 'shared') {
        section = sectionOf(target.shared.mode);
        syncChrome();
        choose({ mode: target.shared.mode, path: target.shared.path, stage: target.shared.stage }, target.shared);
        notice('Shared circuit opened. Your existing lesson and example drafts are kept separately.');
    } else {
        section = target.section;
        syncChrome();
        const mode: Mode = section === 'tour' ? 'tour' : 'examples';
        const lesson = target.section === 'tour' ? tour.find(item => item.id === target.lesson) : undefined;
        const path = target.section === 'playground' && target.path && validSelection({ mode, path: target.path, stage: 'write_firrtl' }) ? target.path : lesson ? lessonPath(lesson) : resumePath(mode);
        const same = !shared && selection.mode === mode && selection.path === path;
        if (!same) {
            writeStorage(`last:${mode}`, path);
            const stage = mode === 'tour' ? tour.find(item => lessonPath(item) === path)!.stage as Stage : 'write_firrtl';
            choose({ mode, path, stage });
        } else if (!editors) { renderGuide(); renderLibrary(); }
        if (target.section === 'tour') element('guide-body').scrollTop = 0;
    }
    void ensureEditor();
    updateUrl(how);
}
function fromLocation(): Target {
    const params = new URLSearchParams(location.search);
    if (location.hash.startsWith('#code=')) {
        try {
            const code = location.hash.slice(6);
            return { section: 'shared', shared: toSharedState(decodeShare(location.hash)!, code) };
        } catch (error) { notice((error as Error).message); }
    }
    if (params.get('mode') === 'docs') return { section: 'docs', chapter: params.get('chapter') ?? undefined, anchor: location.hash.slice(1) || undefined };
    const lesson = tour.find(item => item.id === params.get('lesson'));
    if (lesson) return { section: 'tour', lesson: lesson.id };
    if (params.get('mode') === 'examples') {
        const example = examples.find(path => baseName(path) === `${params.get('example')}.yodl`);
        return { section: 'playground', path: example ?? blankPath };
    }
    return { section: sectionOf(selection.mode) };
}

const docs = createDocs({
    navigate: (slug, anchor) => void go({ section: 'docs', chapter: slug, anchor }),
    openLesson: id => void go({ section: 'tour', lesson: id }),
    openExample(chapter: ChapterData, example, source, stage) {
        const program = { mode: 'examples' as Mode, path: blankPath, stage, source, files: example.files, entryPath: example.path, origin: `${chapter.slug}.html#${example.id}` };
        const code = encodeShare(program);
        if (code.length > 30_000) { notice('This example is too large for a reliable handoff. Copy the source instead.'); return; }
        void go({ section: 'shared', shared: { ...program, code } });
    },
});
const search = createSearch({
    lessons: tour,
    openLesson: id => void go({ section: 'tour', lesson: id }),
    openDoc: (slug, anchor) => void go({ section: 'docs', chapter: slug, anchor }),
});

// ---------------------------------------------------------------------------
// Editor start-up (Monaco is a large bundle, so it loads on first need and the
// guide stays usable if it cannot load).
// ---------------------------------------------------------------------------
function ensureEditor() {
    return editorReady ??= startEditor().catch(error => {
        editorReady = undefined;
        setStatus('Could not load the editor', 'error');
        element('input-panel').textContent = 'The editor could not load. Check your connection and reload the page.';
        notice(`Playground startup failed: ${(error as Error).message ?? String(error)}`);
    });
}
async function startEditor() {
    editors = await loadEditors();
    entryModel = editors.input.getModel();
    activeSourcePath = entryPath();
    loadingSource = true;
    editors.input.setValue(readStorage(draftKey()) ?? shared?.source ?? originals(selection.path));
    loadingSource = false;
    renderSelection();
    saveDraft();
    for (const control of [button('compile-button'), button('menu-button'), button('view-simulate')]) control.disabled = false;
    simulation.enable();
    button('compile-shortcut').textContent = mac ? '⌘↵' : 'Ctrl ↵';
    element('share-shortcut').textContent = mac ? '⌘S' : 'Ctrl S';
    element('new-shortcut').textContent = mac ? '⌘N' : 'Ctrl N';
    editors.input.addAction({ id: 'compile-yodl', label: 'Compile Yodl', keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter], run: runCompile });
    editors.output.addAction({ id: 'compile-yodl-output', label: 'Compile Yodl', keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter], run: runCompile });
    // Monaco reserves Ctrl/⌘+K as a chord prefix; the site-wide search shortcut wins.
    for (const editor of [editors.input, editors.output]) editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyK, () => search.open());
    editors.input.onDidChangeModelContent(() => {
        if (loadingSource || editors!.input.getModel() !== entryModel) return;
        saveDraft();
        markChanged();
    });
    editors.input.onDidChangeCursorPosition((event: any) => { element('cursor-position').textContent = `Ln ${event.position.lineNumber}, Col ${event.position.column}`; });
    installResizer();
    setStatus('Ready to compile');
    void loadImports();
    void runCompile();
}

function newFile() {
    if (section !== 'playground') { void go({ section: 'playground', path: blankPath }); return; }
    if (editors && selection.path === blankPath && !shared && entrySource() !== originalSource()) requestReset();
    else void go({ section: 'playground', path: blankPath });
}
function setSidebarCollapsed(collapsed: boolean) {
    const sidebar = element('sidebar');
    if (collapsed) sidebar.dataset.collapsed = ''; else delete sidebar.dataset.collapsed;
    for (const control of [button('guide-collapse'), button('library-collapse')]) {
        control.textContent = collapsed ? 'Show ▾' : 'Hide ▴';
        control.setAttribute('aria-expanded', String(!collapsed));
    }
}
function installResizer() {
    const handle = element('resize-handle');
    let ratio = Number(readStorage('split') ?? 50);
    function apply(value: number) {
        ratio = Math.max(25, Math.min(75, Number.isFinite(value) ? value : 50));
        element('editors').style.setProperty('--source-width', `${ratio}%`);
        handle.setAttribute('aria-valuenow', String(Math.round(ratio)));
        editors!.input.layout(); editors!.output.layout();
    }
    apply(ratio);
    handle.onpointerdown = event => {
        handle.setPointerCapture(event.pointerId);
        handle.classList.add('dragging');
        event.preventDefault();
    };
    handle.onpointermove = event => {
        if (!handle.hasPointerCapture(event.pointerId)) return;
        const bounds = element('editors').getBoundingClientRect();
        apply((event.clientX - bounds.left) / bounds.width * 100);
    };
    const finish = () => { handle.classList.remove('dragging'); writeStorage('split', String(ratio)); };
    handle.onlostpointercapture = finish;
    handle.onpointerup = event => { if (handle.hasPointerCapture(event.pointerId)) handle.releasePointerCapture(event.pointerId); };
    handle.onkeydown = event => {
        if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
        event.preventDefault();
        apply(event.key === 'Home' ? 25 : event.key === 'End' ? 75 : ratio + (event.key === 'ArrowLeft' ? -5 : 5));
        finish();
    };
}

// ---------------------------------------------------------------------------
// Wiring that does not depend on the editor
// ---------------------------------------------------------------------------
for (const item of Array.from(document.querySelectorAll<HTMLButtonElement>('.mode-switch button'))) {
    item.onclick = () => void go(item.dataset.mode === 'docs' ? { section: 'docs', chapter: docsSlug } : item.dataset.mode === 'tour' ? { section: 'tour' } : { section: 'playground' });
}
document.querySelector<HTMLAnchorElement>('.site-brand')!.onclick = event => { event.preventDefault(); void go({ section: 'tour', lesson: tour[0].id }); };
button('lesson-list-button').onclick = () => setLessonList(element('lesson-list-scrim').hidden === true);
element('lesson-list-scrim').onclick = event => { if (event.target === event.currentTarget) setLessonList(false); };
button('previous-lesson').onclick = () => { const previous = tour[lessonIndex() - 1]; if (previous) void go({ section: 'tour', lesson: previous.id }); };
button('next-lesson').onclick = () => { const next = tour[lessonIndex() + 1]; void go(next ? { section: 'tour', lesson: next.id } : { section: 'playground' }); };
button('suggested-stage').onclick = () => { if (editors) changeStage(tour[lessonIndex()].stage as Stage); };
button('new-file').onclick = newFile;
button('guide-collapse').onclick = button('library-collapse').onclick = () => setSidebarCollapsed(element('sidebar').dataset.collapsed === undefined);
button('compile-button').onclick = () => void runCompile();
button('view-output').onclick = () => setOutputView('output');
button('view-simulate').onclick = () => setOutputView('simulation');
button('source-tab').onclick = () => setMobileView('source');
button('output-tab').onclick = () => setMobileView('output');
button('menu-button').onclick = () => setMenu(element('file-menu').hidden === true);
element('file-menu').onclick = () => setMenu(false);
document.addEventListener('pointerdown', event => {
    if (!element('file-menu').hidden && !element('file-menu').parentElement!.contains(event.target as Node)) setMenu(false);
});
button('share-button').onclick = openShare;
button('download-source').onclick = () => { if (editors) download(baseName(activeSourcePath), editors.input.getValue()); };
button('download-output').onclick = downloadOutput;
button('output-download').onclick = downloadOutput;
button('copy-output').onclick = () => { if (outputRevision === revision) void copy(lastOutput, button('copy-output')); };
button('reset-button').onclick = requestReset;
button('related-docs-menu').onclick = () => {
    const [slug, anchor] = shared?.origin?.replace(/\.html$/, '').split('#') ?? [];
    if (slug) void go({ section: 'docs', chapter: slug, anchor: anchor });
};
button('jump-error').onclick = () => {
    if (!errorRange || !editors) return;
    setMobileView('source');
    openSource(errorPath);
    editors.input.setSelection(errorRange); editors.input.revealRangeInCenter(errorRange); editors.input.focus();
};
element<HTMLDialogElement>('reset-dialog').addEventListener('close', () => {
    if (element<HTMLDialogElement>('reset-dialog').returnValue === 'reset') entryModel.setValue(originalSource());
});
button('copy-share').onclick = () => void copy(element<HTMLInputElement>('share-url').value, button('copy-share'));
document.addEventListener('keydown', event => {
    const command = event.metaKey || event.ctrlKey;
    if (event.key === 'Escape') { setLessonList(false); setMenu(false); }
    if (section === 'docs' || !command) return;
    if (event.key === 'Enter' && !event.defaultPrevented) { event.preventDefault(); void runCompile(); }
    else if (event.key.toLowerCase() === 's' && !event.altKey) { event.preventDefault(); openShare(); }
    else if (event.key.toLowerCase() === 'n' && !event.altKey && section === 'playground') { event.preventDefault(); newFile(); }
});
window.addEventListener('popstate', () => void go(fromLocation(), 'none'));
window.addEventListener('pagehide', () => docs.dispose());
if (matchMedia('(max-width: 820px)').matches) setSidebarCollapsed(true);
buildLessonNavigation();
setStatus('Starting editor…', 'loading');

// Old share links for documentation examples: book/<chapter>.html#example=<code>
// now arrive here. Open the example in the Playground with the shared source.
async function openLegacyExample() {
    if (!location.hash.startsWith('#example=')) return false;
    const chapter = await docs.show(new URLSearchParams(location.search).get('chapter') ?? undefined);
    try {
        const payload = decodeProgram(location.hash.slice(9)) as { version: number; id: string; source: string; stage: Stage };
        const example = chapter?.examples.find(item => item.id === payload.id);
        if (payload.version !== 1 || !example || typeof payload.source !== 'string' || !Object.hasOwn(stages, payload.stage)) throw new Error();
        const program = { mode: 'examples' as Mode, path: blankPath, stage: payload.stage, source: payload.source, files: example.files, entryPath: example.path, origin: `${chapter!.slug}.html#${example.id}` };
        await go({ section: 'shared', shared: { ...program, code: encodeShare(program) } }, 'replace');
    } catch {
        notice('This shared example could not be opened. The original examples are shown in the guide.');
        return false;
    }
    return true;
}
const initial = fromLocation();
if (initial.section === 'docs' && location.hash.startsWith('#example=')) void openLegacyExample().then(opened => { if (!opened) void go({ ...initial, anchor: undefined }, 'replace'); });
else void go(initial, 'replace');
// Chapter titles feed the tour's "Reference" link; fetch them once the page is idle.
setTimeout(() => void docs.load().then(data => {
    for (const chapter of data.chapters) chapterTitles.set(chapter.slug, chapter.title);
    if (section === 'tour') renderGuide();
}).catch(() => { /* The link keeps its readable fallback title. */ }), 1500);

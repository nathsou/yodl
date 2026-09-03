import { chapterLessons } from '../docs/links.ts';
import { examples, files, tour, stages, blankPath, initialSelection, validSelection, encodeShare, decodeShare, diagnosticLocation } from './playground-model.ts';
import type { Selection, Stage, Mode } from './playground-model.ts';
import { CompilerClient } from './compiler-client.ts';
import { setupTheme } from './theme.ts';
import { loadEditors, monaco } from './playground-editor.ts';

const element = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const button = (id: string) => element<HTMLButtonElement>(id);
const select = (id: string) => element<HTMLSelectElement>(id);
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
const updateTheme = setupTheme(select('theme-select'), dark => {
    if (monaco) monaco.editor.setTheme(dark ? 'yodl-dark' : 'yodl-light');
});

let selection: Selection = { ...initialSelection };
try {
    const saved = JSON.parse(readStorage('selection') ?? 'null');
    if (validSelection(saved)) selection = saved;
} catch { /* Ignore incompatible saved preferences. */ }
const params = new URLSearchParams(location.search);
const requestedLesson = tour.find(lesson => lesson.id === params.get('lesson'));
if (requestedLesson) selection = { mode: 'tour', path: `tour/${requestedLesson.file}`, stage: requestedLesson.stage as Stage };
else if (params.get('mode') === 'examples') selection = { mode: 'examples', path: blankPath, stage: 'write_firrtl' };
let sharedFiles: Record<string, string> = {};
let sharedEntryPath: string | undefined;
let sharedOrigin: string | undefined;
let sharedSource: string | null = null;
let sharedDraftKey = '';
try {
    const shared = decodeShare(location.hash);
    if (shared) {
        selection = { mode: shared.mode, path: shared.path, stage: shared.stage };
        sharedSource = shared.source;
        sharedFiles = shared.files ?? {};
        sharedEntryPath = shared.entryPath;
        sharedOrigin = shared.origin;
        // Sharing never overwrites the recipient's ordinary lesson/example draft.
        sharedDraftKey = `shared:${location.hash.slice(6)}`;
        notice('Shared circuit opened. Your existing lesson and example drafts are kept separately.');
    }
} catch (error) { notice((error as Error).message); }
let editors: Awaited<ReturnType<typeof loadEditors>>;
let loadingSource = false;
let revision = 0;
let lastOutput = '';
let outputRevision = -1;
let timer: ReturnType<typeof setTimeout> | undefined;
const compiler = new CompilerClient();
let requestId = 0;
let latestRequest = 0;
let errorRange: ReturnType<typeof diagnosticLocation> = null;
const auto = element<HTMLInputElement>('auto-compile');
auto.checked = readStorage('auto') !== 'false';
const defaultBlank = '// Start a new circuit here.\nmodule Top(a: bool) -> (q: bool) {\n    q = a\n}\n';
const originals = (path: string) => files[path] ?? defaultBlank;
const originalSource = () => sharedEntryPath && sharedSource !== null ? sharedSource : originals(selection.path);
const draftKey = () => sharedDraftKey || `draft:${selection.path}`;

function lessonIndex() { return tour.findIndex(lesson => `tour/${lesson.file}` === selection.path); }
function saveDraft() {
    writeStorage(draftKey(), editors.input.getValue());
    if (!sharedDraftKey) writeStorage('selection', JSON.stringify(selection));
    element('save-status').textContent = storageAvailable ? 'Draft saved locally' : 'Draft not saved · storage unavailable';
    element('draft-badge').hidden = editors.input.getValue() === originalSource();
}
function renderSelection() {
    const isTour = selection.mode === 'tour';
    element('site-section').textContent = isTour ? 'tour' : 'playground';
    button('tour-mode').setAttribute('aria-pressed', String(isTour));
    button('examples-mode').setAttribute('aria-pressed', String(!isTour));
    element('guide').hidden = !isTour;
    element('source-label').textContent = isTour ? 'Lesson' : 'Example';
    const picker = select('source-selector');
    picker.replaceChildren();
    const choices = isTour ? tour.map((lesson, index) => ({ value: `tour/${lesson.file}`, label: `${String(index + 1).padStart(2, '0')} · ${lesson.title}` })) : [
        { value: blankPath, label: 'New circuit' }, ...examples.map(path => ({ value: path, label: path.split('/').at(-1)! })),
    ];
    for (const choice of choices) picker.add(new Option(choice.label, choice.value));
    picker.value = selection.path;
    element('input-filename').textContent = (sharedEntryPath ?? selection.path).split('/').at(-1)!;
    element('input-filename').title = sharedEntryPath ?? selection.path;
    const docLink = element<HTMLAnchorElement>('related-docs');
    const doc = Object.entries(chapterLessons).find(([, lessons]) => lessons.some(l => l.id === tour[lessonIndex()]?.id));
    docLink.hidden = !doc && !sharedOrigin;
    docLink.href = `./book/${sharedOrigin ?? (doc ? doc[0] + '.html' : '')}`;
    if (isTour) {
        const index = lessonIndex();
        const lesson = tour[index];
        element('lesson-position').textContent = `${String(index + 1).padStart(2, '0')} / ${tour.length}`;
        element('lesson-topic').textContent = lesson.topic;
        element('lesson-title').textContent = lesson.title;
        element('lesson-intro').textContent = lesson.intro;
        element('lesson-observe').textContent = lesson.observe;
        element('lesson-challenge').textContent = lesson.challenge;
        element('lesson-concepts').replaceChildren(...lesson.concepts.map(text => {
            const li = document.createElement('li'); li.textContent = text; return li;
        }));
        button('suggested-stage').textContent = `Show ${stages[lesson.stage as Stage].label} →`;
        button('previous-lesson').disabled = index === 0;
        button('next-lesson').disabled = false;
        button('next-lesson').textContent = index === tour.length - 1 ? 'Explore examples →' : 'Next lesson →';
    }
    select('pass-selector').value = selection.stage;
    renderStage();
}
function renderStage() {
    const stage = stages[selection.stage];
    element('stage-description').textContent = stage.description;
    element('stage-command').textContent = selection.stage;
    monaco.editor.setModelLanguage(editors.output.getModel(), stage.language);
}
function clearDiagnostics() {
    element('problems').hidden = true;
    errorRange = null;
    monaco.editor.setModelMarkers(editors.input.getModel(), 'yodl', []);
}
function markChanged() {
    compiler.cancel('playground');
    revision++;
    latestRequest = ++requestId;
    clearTimeout(timer);
    clearDiagnostics();
    button('copy-output').disabled = true;
    button('download-output').disabled = true;
    setStatus(lastOutput ? 'Source changed · output is out of date' : 'Ready to compile');
    if (auto.checked) timer = setTimeout(runCompile, 500);
}
function choose(next: Selection) {
    saveDraft();
    sharedDraftKey = '';
    sharedSource = null;
    sharedFiles = {}; sharedEntryPath = undefined; sharedOrigin = undefined;
    if (location.hash.startsWith('#code=')) history.replaceState(null, '', location.pathname + location.search);
    selection = next;
    loadingSource = true;
    editors.input.setValue(readStorage(draftKey()) ?? originals(selection.path));
    loadingSource = false;
    editors.input.setScrollTop(0);
    editors.output.setValue('');
    lastOutput = '';
    outputRevision = -1;
    renderSelection();
    const url = new URL(location.href);
    url.searchParams.delete('lesson'); url.searchParams.delete('mode');
    history.replaceState(null, '', url);
    saveDraft();
    markChanged();
}
function changeMode(mode: Mode) {
    if (mode === selection.mode && !sharedDraftKey) return;
    let path = mode === 'tour' ? initialSelection.path : blankPath;
    const previous = readStorage(`last:${mode}`);
    if (validSelection({ mode, path: previous, stage: 'write_firrtl' })) path = previous!;
    choose({ mode, path, stage: mode === 'tour' ? tour.find(l => `tour/${l.file}` === path)!.stage as Stage : 'write_firrtl' });
}
function changeStage(stage: Stage) {
    selection.stage = stage;
    select('pass-selector').value = stage;
    editors.output.setValue('');
    lastOutput = '';
    renderStage();
    saveDraft();
    markChanged();
}
function setMobileView(view: string) {
    element('editors').dataset.view = view;
    button('source-tab').setAttribute('aria-pressed', String(view === 'source'));
    button('output-tab').setAttribute('aria-pressed', String(view === 'output'));
    editors.input.layout(); editors.output.layout();
}
function showError(message: string) {
    element('problems').hidden = false;
    element('error-message').textContent = message;
    errorRange = diagnosticLocation(message, sharedEntryPath ?? selection.path);
    button('jump-error').hidden = errorRange === null;
    if (errorRange) {
        const range = editors.input.getModel().validateRange(errorRange);
        errorRange = range;
        monaco.editor.setModelMarkers(editors.input.getModel(), 'yodl', [{ ...range, message, severity: monaco.MarkerSeverity.Error }]);
    }
    setStatus(lastOutput ? 'Compilation failed · showing previous output' : 'Compilation failed · check diagnostics', 'error');
}
async function runCompile() {
    clearTimeout(timer);
    const id = ++requestId;
    latestRequest = id;
    const compiledRevision = revision;
    clearDiagnostics();
    setStatus('Compiling…', 'loading');
    const result = await compiler.compile('playground', { source: editors.input.getValue(), path: sharedEntryPath ?? selection.path, stage: selection.stage, files: { ...files, ...sharedFiles } });
    if (!result || id !== latestRequest) return;
    if (result.error !== undefined) { showError(result.error); return; }
    lastOutput = result.output ?? '';
    outputRevision = compiledRevision;
    editors.output.setValue(lastOutput);
    renderStage();
    button('copy-output').disabled = !lastOutput;
    button('download-output').disabled = !lastOutput;
    setStatus(`✓ Compiled · ${Math.round(result.duration)} ms`, 'success');
}
function parseSimulationInputs(source: string): Record<string, { width: number; value: number }> {
    const inputs: Record<string, { width: number; value: number }> = {};
    for (const token of source.split(',')) {
        const match = /^\s*([A-Za-z_$][\w$]*)(?::(\d+))?\s*=\s*(-?\d+)\s*$/.exec(token);
        if (!match) continue;
        inputs[match[1]] = { width: Number(match[2] ?? 32), value: Number(match[3]) };
    }
    return inputs;
}
function renderSimulationFrames(frames: Array<{ width: number; height: number; pixels: number[] }>) {
    const canvas = element<HTMLCanvasElement>('simulation-framebuffer');
    if (framebufferAnimation !== undefined) cancelAnimationFrame(framebufferAnimation);
    framebufferAnimation = undefined;
    if (frames.length === 0) { canvas.hidden = true; return; }
    canvas.hidden = false;
    canvas.width = frames[0].width;
    canvas.height = frames[0].height;
    const context = canvas.getContext('2d');
    if (!context) return;
    const image = context.createImageData(canvas.width, canvas.height);
    let frame = 0;
    const draw = () => {
        for (let i = 0; i < frames[frame].pixels.length; i++) {
            const color = frames[frame].pixels[i] >>> 0;
            image.data[i * 4] = (color >>> 16) & 255;
            image.data[i * 4 + 1] = (color >>> 8) & 255;
            image.data[i * 4 + 2] = color & 255;
            image.data[i * 4 + 3] = 255;
        }
        context.putImageData(image, 0, 0);
        if (frames.length > 1) {
            frame = (frame + 1) % frames.length;
            framebufferAnimation = requestAnimationFrame(draw);
        }
    };
    draw();
}
let framebufferAnimation: number | undefined;
async function runSimulation() {
    const id = ++requestId;
    latestRequest = id;
    const cycles = Math.max(0, Math.min(100000, Number(element<HTMLInputElement>('simulation-cycles').value) || 0));
    const requestedTop = element<HTMLInputElement>('simulation-top').value.trim();
    const clock = element<HTMLInputElement>('simulation-clock').value.trim() || undefined;
    const inputs = parseSimulationInputs(element<HTMLInputElement>('simulation-inputs').value);
    const isLife = (requestedTop || '').toLowerCase() === 'lifesim' || (selection.path.endsWith('/Sim.yodl') || selection.path === 'examples/Sim.yodl') && requestedTop === '';
    const top = requestedTop || (isLife ? 'LifeSim' : undefined);
    const framebuffer = isLife ? {
        width: 40,
        height: 30,
        statePrefix: 'state',
        initSignal: 'init',
        initCycles: 1,
        onColor: 0x1f6a4,
        offColor: 0x000000,
    } : undefined;
    const frameCount = isLife ? Math.max(1, Math.min(600, cycles || 60)) : undefined;
    setStatus('Simulating…', 'loading');
    const result = await compiler.compile('simulation', {
        source: editors.input.getValue(),
        path: sharedEntryPath ?? selection.path,
        stage: 'write_low_firrtl',
        files: { ...files, ...sharedFiles },
        simulate: { top, clock, cycles, inputs, frames: frameCount, frameCycles: isLife ? 1 : undefined, framebuffer },
    });
    if (!result || id !== latestRequest) return;
    if (result.error !== undefined) { showError(result.error); return; }
    const simulation = result.simulation;
    if (!simulation) return;
    const lines = [`cycles: ${simulation.cycles}`];
    const outputEntries = Object.entries(simulation.outputs).filter(([name]) => !simulation.framebuffers || !name.startsWith('state_'));
    for (const [name, value] of outputEntries.slice(0, 100)) lines.push(`${name} = ${value}`);
    if (outputEntries.length > 100) lines.push(`… ${outputEntries.length - 100} more outputs`);
    if (simulation.messages.length) { lines.push('', ...simulation.messages); }
    element('simulation-output').textContent = lines.join('\n');
    renderSimulationFrames(simulation.framebuffers ?? []);
    setStatus(`✓ Simulated · ${Math.round(result.duration)} ms`, 'success');
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
        else { editors.output.focus(); editors.output.setSelection(editors.output.getModel().getFullModelRange()); }
    }
}
async function start() {
    editors = await loadEditors();
    updateTheme();
    for (const [value, stage] of Object.entries(stages)) select('pass-selector').add(new Option(stage.label, value));
    loadingSource = true;
    editors.input.setValue(readStorage(draftKey()) ?? sharedSource ?? originals(selection.path));
    loadingSource = false;
    renderSelection();
    if (matchMedia('(max-width: 820px)').matches) element<HTMLDetailsElement>('guide-details').open = false;
    saveDraft();
    for (const id of ['share-button', 'source-selector', 'compile-button', 'simulate-button', 'pass-selector', 'reset-button', 'download-source']) (element(id) as HTMLButtonElement).disabled = false;
    const mac = /Mac|iPhone|iPad/.test(navigator.platform);
    element('compile-shortcut').textContent = mac ? '⌘ ↵' : 'Ctrl ↵';
    editors.input.addAction({ id: 'compile-yodl', label: 'Compile Yodl', keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter], run: runCompile });
    editors.output.addAction({ id: 'compile-yodl-output', label: 'Compile Yodl', keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter], run: runCompile });
    document.addEventListener('keydown', event => {
        if (!event.defaultPrevented && (event.metaKey || event.ctrlKey) && event.key === 'Enter') { event.preventDefault(); runCompile(); }
    });
    editors.input.onDidChangeModelContent(() => {
        if (loadingSource) return;
        saveDraft();
        markChanged();
    });
    editors.input.onDidChangeCursorPosition((event: any) => { element('cursor-position').textContent = `Ln ${event.position.lineNumber}, Col ${event.position.column}`; });
    button('tour-mode').onclick = () => changeMode('tour');
    button('examples-mode').onclick = () => changeMode('examples');
    select('source-selector').onchange = () => {
        const path = select('source-selector').value;
        writeStorage(`last:${selection.mode}`, path);
        choose({ mode: selection.mode, path, stage: selection.mode === 'tour' ? tour.find(l => `tour/${l.file}` === path)!.stage as Stage : selection.stage });
    };
    button('previous-lesson').onclick = () => navigateLesson(-1);
    button('next-lesson').onclick = () => navigateLesson(1);
    button('suggested-stage').onclick = () => changeStage(tour[lessonIndex()].stage as Stage);
    select('pass-selector').onchange = () => changeStage(select('pass-selector').value as Stage);
    button('compile-button').onclick = runCompile;
    button('simulate-button').onclick = runSimulation;
    auto.onchange = () => {
        writeStorage('auto', String(auto.checked));
        clearTimeout(timer);
        if (auto.checked) runCompile();
    };
    button('source-tab').onclick = () => setMobileView('source');
    button('output-tab').onclick = () => setMobileView('output');
    button('jump-error').onclick = () => {
        if (!errorRange) return;
        setMobileView('source');
        editors.input.setSelection(errorRange); editors.input.revealRangeInCenter(errorRange); editors.input.focus();
    };
    button('reset-button').onclick = () => element<HTMLDialogElement>('reset-dialog').showModal();
    element<HTMLDialogElement>('reset-dialog').addEventListener('close', () => {
        if (element<HTMLDialogElement>('reset-dialog').returnValue === 'reset') editors.input.setValue(originalSource());
    });
    button('download-source').onclick = () => download(selection.path.split('/').at(-1)!, editors.input.getValue());
    button('download-output').onclick = () => {
        if (outputRevision === revision) download(`${selection.path.split('/').at(-1)!.replace(/\.yodl$/, '')}.${stages[selection.stage].extension}`, lastOutput);
    };
    button('copy-output').onclick = () => { if (outputRevision === revision) void copy(lastOutput, button('copy-output')); };
    button('share-button').onclick = () => {
        const url = new URL(location.href);
        url.hash = `code=${encodeShare({ ...selection, source: editors.input.getValue(), files: sharedFiles, entryPath: sharedEntryPath, origin: sharedOrigin })}`;
        if (url.href.length > 32_000) { notice('This circuit is too large for a reliable share link. Use Save to download the source instead.'); return; }
        element<HTMLInputElement>('share-url').value = url.href;
        element<HTMLDialogElement>('share-dialog').showModal();
        element<HTMLInputElement>('share-url').select();
    };
    button('copy-share').onclick = () => void copy(element<HTMLInputElement>('share-url').value, button('copy-share'));
    installResizer();
    setStatus('Ready to compile');
    if (auto.checked) runCompile();
}
function navigateLesson(delta: number) {
    const index = lessonIndex() + delta;
    if (index >= tour.length) { changeMode('examples'); return; }
    const lesson = tour[index];
    if (lesson) {
        writeStorage('last:tour', `tour/${lesson.file}`);
        choose({ mode: 'tour', path: `tour/${lesson.file}`, stage: lesson.stage as Stage });
        element('guide').scrollTop = 0;
    }
}
function installResizer() {
    const handle = element('resize-handle');
    let ratio = Number(readStorage('split') ?? 50);
    function apply(value: number) {
        ratio = Math.max(25, Math.min(75, Number.isFinite(value) ? value : 50));
        element('editors').style.setProperty('--source-width', `${ratio}%`);
        handle.setAttribute('aria-valuenow', String(Math.round(ratio)));
        editors.input.layout(); editors.output.layout();
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
start().catch(error => {
    setStatus('Could not load the editor', 'error');
    element('input-panel').textContent = 'The editor could not load. Check your connection and reload the page.';
    notice(`Playground startup failed: ${(error as Error).message ?? String(error)}`);
});

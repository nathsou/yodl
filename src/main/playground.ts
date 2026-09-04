import { chapterLessons } from '../docs/links.ts';
import { examples, files, tour, stages, blankPath, initialSelection, validSelection, encodeShare, decodeShare, diagnosticLocation } from './playground-model.ts';
import type { Selection, Stage, Mode } from './playground-model.ts';
import { CompilerClient, RealtimeSimulationClient } from './compiler-client.ts';
import type { SimulationStreamEvent } from './playground-compiler.ts';
import { setupTheme } from './theme.ts';
import { loadEditors, monaco } from './playground-editor.ts';
import type { SimulationFramebuffer, SimulationRequest, SimulationSignal } from './playground-compiler.ts';

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
let entryModel: any;
let activeSourcePath = '';
let errorPath = '';
const importedModels = new Map<string, any>();
const sourceViews = new Map<string, any>();
const entryPath = () => sharedEntryPath ?? selection.path;
const entrySource = () => entryModel.getValue() as string;
function openSource(path: string) {
    const model = path === entryPath() ? entryModel : importedModels.get(path);
    if (!model) return;
    if (activeSourcePath) sourceViews.set(activeSourcePath, editors.input.saveViewState());
    activeSourcePath = path;
    editors.input.setModel(model);
    editors.input.updateOptions({ readOnly: path !== entryPath(), ariaLabel: `${path}${path === entryPath() ? ', main source' : ', imported, read only'}` });
    const view = sourceViews.get(path);
    if (view) editors.input.restoreViewState(view);
    renderSourceTabs();
    editors.input.layout();
}
function renderSourceTabs() {
    const imported = activeSourcePath !== entryPath();
    const hasImports = importedModels.size > 0;
    element('source-files').hidden = !hasImports;
    element('editors').dataset.imports = String(hasImports);
    element('input-filename').textContent = activeSourcePath;
    element('input-filename').title = activeSourcePath;
    element('source-kind').textContent = imported ? 'Imported · read only' : '';
    element('source-kind').hidden = !imported;
    element('draft-badge').hidden = imported || entrySource() === originalSource();
    button('reset-button').disabled = imported;
    element('source-files').replaceChildren(...[entryPath(), ...importedModels.keys()].map(path => {
        const tab = document.createElement('button');
        tab.textContent = path.split('/').at(-1)!;
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
    editors.input.setModel(entryModel);
    for (const model of importedModels.values()) model.dispose();
    importedModels.clear();
    openSource(entryPath());
}

let revision = 0;
let lastOutput = '';
let outputRevision = -1;
let timer: ReturnType<typeof setTimeout> | undefined;
const compiler = new CompilerClient();
const importResolver = new CompilerClient();
let importRevision = 0;
let importTimer: ReturnType<typeof setTimeout> | undefined;
async function loadImports() {
    const current = ++importRevision;
    const result = await importResolver.compile('imports', { source: entrySource(), path: entryPath(), stage: 'write_source', files: { ...files, ...sharedFiles } });
    if (current === importRevision && result?.sources) updateImportedSources(result.sources);
}
function scheduleImports() {
    ++importRevision;
    importResolver.cancel('imports');
    clearTimeout(importTimer);
    importTimer = setTimeout(loadImports, 150);
}
const realtimeSimulation = new RealtimeSimulationClient();
let simulationState: 'ready' | 'starting' | 'running' | 'paused' | 'stepping' | 'halted' | 'error' = 'ready';
let requestId = 0;
let latestRequest = 0;
let errorRange: ReturnType<typeof diagnosticLocation> = null;
const auto = element<HTMLInputElement>('auto-compile');
auto.checked = readStorage('auto') !== 'false';
const defaultBlank = '// Start a new circuit here.\nmodule Top(a: bool) -> (q: bool) {\n    q = a\n}\n';
const originals = (path: string) => files[path] ?? defaultBlank;
const originalSource = () => sharedEntryPath && sharedSource !== null ? sharedSource : originals(selection.path);
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
const draftKey = () => sharedDraftKey || `draft:${selection.path}:${sourceRevision(originals(selection.path))}`;

function lessonIndex() { return tour.findIndex(lesson => `tour/${lesson.file}` === selection.path); }
function saveDraft() {
    writeStorage(draftKey(), entrySource());
    if (!sharedDraftKey) writeStorage('selection', JSON.stringify(selection));
    element('save-status').textContent = storageAvailable ? 'Draft saved locally' : 'Draft not saved · storage unavailable';
    element('draft-badge').hidden = activeSourcePath !== entryPath() || entrySource() === originalSource();
}
function renderSelection() {
    element('output-pane').dataset.view = 'output';
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
    renderSourceTabs();
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
    element('stage-description').title = stage.description;
    select('pass-selector').title = stage.description;
    element('stage-command').textContent = selection.stage;
    monaco.editor.setModelLanguage(editors.output.getModel(), stage.language);
}
function clearDiagnostics() {
    element('problems').hidden = true;
    errorRange = null;
    for (const model of [entryModel, ...importedModels.values()]) monaco.editor.setModelMarkers(model, 'yodl', []);
}
function markChanged() {
    compiler.cancel('playground');
    realtimeSimulation.stop();
    simulationState = 'ready';
    updateSimulationControls();
    revision++;
    scheduleImports();
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
    renderSimulationFrames([]);
    sharedDraftKey = '';
    sharedSource = null;
    sharedFiles = {}; sharedEntryPath = undefined; sharedOrigin = undefined;
    if (location.hash.startsWith('#code=')) history.replaceState(null, '', location.pathname + location.search);
    selection = next;
    resetSourceWorkspace();
    // Simulation fields describe the selected design. Do not carry a top or
    // clock from a previous example into the next one (that made Image/Noise
    // appear broken after running GameOfLifeSim).
    for (const id of ['simulation-top', 'simulation-clock', 'simulation-inputs']) {
        element<HTMLInputElement>(id).value = '';
    }
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
    renderSimulationFrames([]);
    selection.stage = stage;
    select('pass-selector').value = stage;
    editors.output.setValue('');
    lastOutput = '';
    renderStage();
    element('output-pane').dataset.view = 'output';
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
    element('output-pane').dataset.view = 'output';
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
    clearTimeout(timer);
    realtimeSimulation.stop();
    simulationState = 'ready';
    updateSimulationControls();
    renderSimulationFrames([]);
    const id = ++requestId;
    latestRequest = id;
    const compiledRevision = revision;
    clearDiagnostics();
    setStatus('Compiling…', 'loading');
    const result = await compiler.compile('playground', { source: entrySource(), path: sharedEntryPath ?? selection.path, stage: selection.stage, files: { ...files, ...sharedFiles } });
    if (!result || id !== latestRequest) return;
    if (result.error !== undefined) { showError(result.error); return; }
    lastOutput = result.output ?? '';
    outputRevision = compiledRevision;
    editors.output.setValue(lastOutput);
    renderStage();
    element('output-pane').dataset.view = 'output';
    button('copy-output').disabled = !lastOutput;
    button('download-output').disabled = !lastOutput;
    setStatus(`✓ Compiled · ${Math.round(result.duration)} ms`, 'success');
}
function parseSimulationInputs(source: string): Record<string, { width: number; value: number }> {
    const inputs: Record<string, { width: number; value: number }> = {};
    for (const token of source.split(',')) {
        const match = /^\s*([A-Za-z_$][\w$]*)(?::(\d+))?\s*=\s*(-?\d+)\s*$/.exec(token);
        if (!token.trim()) continue;
        if (!match) throw new Error(`Invalid input assignment: ${token}`);
        if (!Number.isSafeInteger(Number(match[3]))) throw new Error("Input exceeds the safe integer range.");
        inputs[match[1]] = { width: Number(match[2] ?? 32), value: Number(match[3]) };
    }
    return inputs;
}
function updateSimulationControls() {
    const run = button('simulation-run');
    const stop = button('simulation-stop');
    run.textContent = simulationState === 'running' || simulationState === 'stepping' ? 'Pause' : simulationState === 'paused' ? 'Resume' : 'Run';
    run.disabled = simulationState === 'starting' || simulationState === 'halted';
    stop.disabled = simulationState === 'ready';
}

let canvasImage: ImageData | undefined;
let lastFrame: SimulationFramebuffer | undefined;
function renderSimulationFrames(frames: SimulationFramebuffer[]) {
    const canvas = element<HTMLCanvasElement>('simulation-framebuffer');
    const frame = frames.at(-1);
    lastFrame = frame;
    element('simulation-zoom-control').hidden = !frame;
    if (!frame) { canvas.hidden = true; return; }
    canvas.hidden = false;
    if (canvas.width !== frame.width || canvas.height !== frame.height) {
        canvas.width = frame.width;
        canvas.height = frame.height;
        canvasImage = undefined;
    }
    const availableWidth = canvas.parentElement?.clientWidth || 640;
    const zoom = select('simulation-zoom').value;
    const scale = zoom === 'fit' ? Math.min(availableWidth / frame.width, 480 / frame.height) : Number(zoom);
    canvas.style.width = `${frame.width * scale}px`;
    canvas.style.height = `${frame.height * scale}px`;
    const context = canvas.getContext('2d');
    if (!context) return;
    const image = canvasImage ??= context.createImageData(frame.width, frame.height);
    const stride = Math.ceil(frame.width / 32);
    for (let i = 0; i < frame.width * frame.height; i++) {
        const row = Math.floor(i / frame.width), col = i % frame.width;
        const word = row * stride + Math.floor(col / 32);
        const known = !frame.valid || (frame.packed ? (frame.valid[word] & (1 << (col % 32))) !== 0 : frame.valid[i] !== 0);
        const color = !known ? 0xff00ff : frame.packed
            ? (frame.packed[word] & (1 << (col % 32))) !== 0 ? frame.onColor ?? 0xffffff : frame.offColor ?? 0
            : frame.rgb?.[i] ?? frame.pixels?.[i] ?? 0;
        image.data[i * 4] = color >>> 16 & 255;
        image.data[i * 4 + 1] = color >>> 8 & 255;
        image.data[i * 4 + 2] = color & 255;
        image.data[i * 4 + 3] = 255;
    }
    context.putImageData(image, 0, 0);
}

function renderSimulationOutput(outputs: SimulationSignal[], messages: string[], cycles: number, framebufferSignal?: string) {
    const lines = [`cycles: ${cycles}`];
    const outputEntries = outputs;
    for (const signal of outputEntries.slice(0, 100)) lines.push(`${signal.name}: u${signal.width} = ${signal.known ? signal.value : 'X'}`);
    if (outputEntries.length > 100) lines.push(`… ${outputEntries.length - 100} more outputs`);
    if (messages.length) lines.push('', ...messages);
    element('simulation-output').textContent = lines.join('\n');
}

function renderSimulationInputs(inputs: SimulationSignal[]) {
    const container = element('simulation-inputs-controls');
    const signature = inputs.map(signal => `${signal.name}:${signal.width}:${signal.value}:${signal.known}`).join('|');
    if (container.dataset.signature === signature) return;
    container.dataset.signature = signature;
    container.replaceChildren();
    for (const signal of inputs) {
        const label = document.createElement('label');
        label.textContent = signal.name;
        const input = document.createElement('input');
        input.dataset.signal = signal.name;
        input.dataset.width = String(signal.width);
        if (signal.width === 1) {
            input.type = 'checkbox';
            input.checked = signal.value !== '0';
        } else {
            input.type = 'text';
            input.value = signal.value;
            input.inputMode = 'numeric';
            input.title = `u${signal.width}`;
        }
        input.addEventListener('change', () => {
            const assignments = [...container.querySelectorAll<HTMLInputElement>('input')].map(control => {
                const value = control.type === 'checkbox' ? Number(control.checked) : control.value;
                return `${control.dataset.signal}:${control.dataset.width}=${value}`;
            });
            element<HTMLInputElement>('simulation-inputs').value = assignments.join(', ');
            try {
                const inputs = parseSimulationInputs(assignments.join(', '));
                input.setCustomValidity('');
                if (simulationState !== 'ready') realtimeSimulation.setInputs(inputs);
            } catch (error) { input.setCustomValidity(String(error)); input.reportValidity(); }
        });
        label.append(input);
        container.append(label);
    }
    container.hidden = inputs.length === 0;
}

function handleRealtimeEvent(event: SimulationStreamEvent) {
    if (event.type === 'error') {
        simulationState = 'error';
        element('simulation-output').textContent = event.error ?? 'Simulation failed.';
        element('simulation-state').textContent = 'Error';
        updateSimulationControls();
        setStatus('Simulation failed', 'error');
        return;
    }
    simulationState = event.type === 'halted' ? 'halted'
        : event.type === 'stopped' ? 'ready'
        : event.type === 'stepping' ? 'stepping'
        : event.type === 'frame' || event.type === 'resumed' ? 'running' : 'paused';
    if (event.frame) renderSimulationFrames([event.frame]);
    else if (event.metadata && !event.metadata.display) renderSimulationFrames([]);
    if (event.outputs) renderSimulationOutput(event.outputs, event.messages ?? [], event.totalCycles ?? 0, event.frame?.signal);
    if (event.inputs) renderSimulationInputs(event.inputs);
    button('simulation-step-cycle').disabled = !event.clock || simulationState === 'halted';
    button('simulation-step-frame').hidden = !(event.frame && event.clock);
    if (event.metadata) {
        const values = { 'simulation-top': event.metadata.top, 'simulation-clock': event.clock, 'simulation-cycles-per-frame': event.playback?.cyclesPerFrame, 'simulation-clock-hz': event.playback?.clockHz ?? 'maximum', 'simulation-refresh-fps': event.playback?.refreshFps };
        for (const [id, value] of Object.entries(values)) element<HTMLInputElement>(id).placeholder = String(value ?? 'automatic');
        element<HTMLInputElement>('simulation-cycles-per-frame').disabled = !event.clock || Boolean(event.metadata.display?.stream);
        element<HTMLInputElement>('simulation-clock-hz').disabled = !event.clock;
        element<HTMLInputElement>('simulation-refresh-fps').disabled = !event.clock;
    }
    const time = event.simulatedSeconds === undefined ? '' : ` · ${event.simulatedSeconds.toFixed(3)} simulated s`;
    const throughput = event.cyclesPerSecond === undefined ? '' : ` · ${Math.round(event.cyclesPerSecond).toLocaleString()} cycles/s achieved`;
    const label = simulationState[0].toUpperCase() + simulationState.slice(1);
    element('simulation-state').textContent = `${label} · ${(event.totalCycles ?? 0).toLocaleString()} cycles${time}${throughput}`;
    updateSimulationControls();
    setStatus(simulationState === 'running' || simulationState === 'stepping' ? 'Simulating…' : `Simulation ${simulationState}`);
}

async function runSimulation(action: SimulationRequest['action'] = 'run') {
    setMobileView('output');
    const readPositive = (id: string) => {
        const value = Number(element<HTMLInputElement>(id).value);
        return Number.isFinite(value) && value > 0 ? value : undefined;
    };
    const options = { clockHz: readPositive('simulation-clock-hz'), refreshFps: readPositive('simulation-refresh-fps'), cyclesPerFrame: readPositive('simulation-cycles-per-frame') };
    if (simulationState !== 'ready' && simulationState !== 'error') {
        if (action === 'run') {
            if (simulationState === 'running' || simulationState === 'stepping') realtimeSimulation.pause();
            else realtimeSimulation.resume(options);
        } else realtimeSimulation.command(action as 'reset' | 'step_cycle' | 'step_frame', options);
        return;
    }
    const top = element<HTMLInputElement>('simulation-top').value.trim();
    const clock = element<HTMLInputElement>('simulation-clock').value.trim();
    element('output-pane').dataset.view = 'simulation';
    element('simulation-state').textContent = 'Compiling simulation…';
    simulationState = 'starting';
    updateSimulationControls();
    try {
        realtimeSimulation.start({
            source: entrySource(), path: sharedEntryPath ?? selection.path,
            stage: 'write_low_firrtl', files: { ...files, ...sharedFiles },
            simulate: { action, ...(top ? { top } : {}), ...(clock ? { clock } : {}), ...Object.fromEntries(Object.entries(options).filter(([, value]) => value !== undefined)), inputs: parseSimulationInputs(element<HTMLInputElement>('simulation-inputs').value) },
        }, handleRealtimeEvent);
    } catch (error) { handleRealtimeEvent({ id: 0, type: 'error', error: String(error) }); }
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
    entryModel = editors.input.getModel();
    activeSourcePath = entryPath();
    updateTheme();
    for (const [value, stage] of Object.entries(stages)) select('pass-selector').add(new Option(stage.label, value));
    loadingSource = true;
    editors.input.setValue(readStorage(draftKey()) ?? sharedSource ?? originals(selection.path));
    loadingSource = false;
    renderSelection();
    if (matchMedia('(max-width: 820px)').matches) element<HTMLDetailsElement>('guide-details').open = false;
    saveDraft();
    for (const id of ['share-button', 'source-selector', 'compile-button', 'simulate-button', 'simulation-reset', 'simulation-step-cycle', 'simulation-step-frame', 'simulation-stop', 'simulation-run', 'simulation-top', 'simulation-clock', 'simulation-cycles-per-frame', 'simulation-clock-hz', 'simulation-refresh-fps', 'simulation-inputs', 'pass-selector', 'reset-button', 'download-source']) (element(id) as HTMLButtonElement).disabled = false;
    const mac = /Mac|iPhone|iPad/.test(navigator.platform);
    element('compile-shortcut').textContent = mac ? '⌘ ↵' : 'Ctrl ↵';
    editors.input.addAction({ id: 'compile-yodl', label: 'Compile Yodl', keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter], run: runCompile });
    editors.output.addAction({ id: 'compile-yodl-output', label: 'Compile Yodl', keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter], run: runCompile });
    document.addEventListener('keydown', event => {
        if (!event.defaultPrevented && (event.metaKey || event.ctrlKey) && event.key === 'Enter') { event.preventDefault(); runCompile(); }
    });
    editors.input.onDidChangeModelContent(() => {
        if (loadingSource || editors.input.getModel() !== entryModel) return;
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
    button('simulate-button').onclick = () => runSimulation('run');
    button('simulation-run').onclick = () => runSimulation('run');
    button('simulation-reset').onclick = () => runSimulation('reset');
    button('simulation-step-cycle').onclick = () => runSimulation('step_cycle');
    button('simulation-step-frame').onclick = () => runSimulation('step_frame');
    select('simulation-zoom').onchange = () => { if (lastFrame) renderSimulationFrames([lastFrame]); };
    button('simulation-stop').onclick = () => {
        realtimeSimulation.stop();
        simulationState = 'ready';
        updateSimulationControls();
        element('simulation-state').textContent = 'Stopped';
        setStatus('Simulation stopped');
    };
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
        openSource(errorPath);
        editors.input.setSelection(errorRange); editors.input.revealRangeInCenter(errorRange); editors.input.focus();
    };
    button('reset-button').onclick = () => element<HTMLDialogElement>('reset-dialog').showModal();
    element<HTMLDialogElement>('reset-dialog').addEventListener('close', () => {
        if (element<HTMLDialogElement>('reset-dialog').returnValue === 'reset') entryModel.setValue(originalSource());
    });
    button('download-source').onclick = () => download(activeSourcePath.split('/').at(-1)!, editors.input.getValue());
    button('download-output').onclick = () => {
        if (outputRevision === revision) download(`${selection.path.split('/').at(-1)!.replace(/\.yodl$/, '')}.${stages[selection.stage].extension}`, lastOutput);
    };
    button('copy-output').onclick = () => { if (outputRevision === revision) void copy(lastOutput, button('copy-output')); };
    button('share-button').onclick = () => {
        const url = new URL(location.href);
        url.hash = `code=${encodeShare({ ...selection, source: entrySource(), files: sharedFiles, entryPath: sharedEntryPath, origin: sharedOrigin })}`;
        if (url.href.length > 32_000) { notice('This circuit is too large for a reliable share link. Use Save to download the source instead.'); return; }
        element<HTMLInputElement>('share-url').value = url.href;
        element<HTMLDialogElement>('share-dialog').showModal();
        element<HTMLInputElement>('share-url').select();
    };
    button('copy-share').onclick = () => void copy(element<HTMLInputElement>('share-url').value, button('copy-share'));
    installResizer();
    setStatus('Ready to compile');
    void loadImports();
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

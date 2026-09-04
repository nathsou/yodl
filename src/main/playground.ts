import { chapterLessons } from '../docs/links.ts';
import { examples, files, tour, stages, blankPath, initialSelection, validSelection, encodeShare, decodeShare, diagnosticLocation } from './playground-model.ts';
import type { Selection, Stage, Mode } from './playground-model.ts';
import { CompilerClient, RealtimeSimulationClient } from './compiler-client.ts';
import type { SimulationStreamEvent } from './playground-compiler.ts';
import { setupTheme } from './theme.ts';
import { loadEditors, monaco } from './playground-editor.ts';
import type { SimulationRequest } from './playground-compiler.ts';

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
const realtimeSimulation = new RealtimeSimulationClient();
let realtimeRunning = false;
let realtimePaused = false;
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
    writeStorage(draftKey(), editors.input.getValue());
    if (!sharedDraftKey) writeStorage('selection', JSON.stringify(selection));
    element('save-status').textContent = storageAvailable ? 'Draft saved locally' : 'Draft not saved · storage unavailable';
    element('draft-badge').hidden = editors.input.getValue() === originalSource();
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
    realtimeSimulation.stop();
    realtimeRunning = false;
    realtimePaused = false;
    updateSimulationControls();
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
    renderSimulationFrames([]);
    sharedDraftKey = '';
    sharedSource = null;
    sharedFiles = {}; sharedEntryPath = undefined; sharedOrigin = undefined;
    if (location.hash.startsWith('#code=')) history.replaceState(null, '', location.pathname + location.search);
    selection = next;
    // Simulation fields describe the selected design. Do not carry a top or
    // clock from a previous example into the next one (that made Image/Noise
    // appear broken after running LifeSim).
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
    realtimeSimulation.stop();
    realtimeRunning = false;
    realtimePaused = false;
    updateSimulationControls();
    renderSimulationFrames([]);
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
    element('output-pane').dataset.view = 'output';
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
type VisualSimulation = {
    top?: string;
    clock?: string;
    framebuffer?: NonNullable<SimulationRequest['framebuffer']>;
    frames?: number;
    frameCycles?: number;
    clockHz?: number;
    frameRate?: number;
    clocked: boolean;
};
type SimulationAnnotation = Record<string, unknown> & { module?: string };

function parseSimulationAnnotations(source: string): SimulationAnnotation[] {
    const annotations: SimulationAnnotation[] = [];
    let search = 0;
    while (true) {
        const marker = source.indexOf('@simulation', search);
        if (marker < 0) break;
        const brace = source.indexOf('{', marker);
        if (brace < 0) break;
        let depth = 0;
        let end = -1;
        let quote = false;
        let escaped = false;
        for (let index = brace; index < source.length; index++) {
            const char = source[index];
            if (quote) {
                if (escaped) escaped = false;
                else if (char === '\\') escaped = true;
                else if (char === '"') quote = false;
                continue;
            }
            if (char === '"') { quote = true; continue; }
            if (char === '{') depth++;
            else if (char === '}' && --depth === 0) { end = index; break; }
        }
        if (end < 0) break;
        const jsonLike = simulationMetadataJson(source.slice(brace, end + 1));
        try {
            const value = JSON.parse(jsonLike) as Record<string, unknown>;
            const module = /\bmodule\s+([A-Za-z_$][\w$]*)/.exec(source.slice(end + 1, end + 300))?.[1];
            annotations.push({ ...value, module });
        } catch { /* Invalid metadata is ignored; normal simulation still works. */ }
        search = end + 1;
    }
    return annotations;
}

function simulationMetadataJson(source: string): string {
    let result = '';
    let quote = false;
    let escaped = false;
    for (let index = 0; index < source.length;) {
        const char = source[index];
        if (quote) {
            result += char;
            if (escaped) escaped = false;
            else if (char === '\\') escaped = true;
            else if (char === '"') quote = false;
            index++;
            continue;
        }
        if (char === '"') { quote = true; result += char; index++; continue; }
        if (/[A-Za-z_$]/.test(char)) {
            let end = index + 1;
            while (end < source.length && /[\w$]/.test(source[end])) end++;
            let next = end;
            while (next < source.length && /\s/.test(source[next])) next++;
            if (source[next] === ':') {
                result += `"${source.slice(index, end)}"`;
                index = end;
                continue;
            }
        }
        result += char;
        index++;
    }
    return result.replace(/,\s*([}])/g, '$1');
}

function numberOption(value: unknown): number | undefined {
    return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

function stringOption(value: unknown): string | undefined {
    return typeof value === 'string' && value.length > 0 ? value : undefined;
}

function hasModule(source: string, name: string): boolean {
    return new RegExp(`\\bmodule\\s+${name.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\$&')}\\b`).test(source);
}

function hasModuleInSources(sources: Iterable<string>, name: string): boolean {
    for (const source of sources) if (hasModule(source, name)) return true;
    return false;
}

function annotatedSimulation(source: string, requestedTop: string, dependencies: Iterable<string> = []): VisualSimulation | undefined {
    const annotations = parseSimulationAnnotations(source);
    const requested = requestedTop.toLowerCase();
    const annotation = annotations.find(value => {
        const target = stringOption(value.top) ?? value.module;
        return !requested || target?.toLowerCase() === requested || value.module?.toLowerCase() === requested;
    });
    if (!annotation) return undefined;
    const annotatedTop = stringOption(annotation.top) ?? annotation.module;
    if (annotatedTop && !hasModuleInSources([source, ...dependencies], annotatedTop)) return undefined;
    const rawFramebuffer = annotation.framebuffer && typeof annotation.framebuffer === 'object'
        ? annotation.framebuffer as Record<string, unknown>
        : undefined;
    const width = numberOption(rawFramebuffer?.width);
    const height = numberOption(rawFramebuffer?.height);
    const statePrefix = stringOption(rawFramebuffer?.state_prefix) ?? stringOption(rawFramebuffer?.statePrefix);
    const framebuffer = width && height && statePrefix ? {
        width,
        height,
        statePrefix,
        valueMode: (stringOption(rawFramebuffer?.mode) ?? stringOption(rawFramebuffer?.value_mode) ?? 'binary') as 'binary' | 'gray' | 'rgb',
        packing: (stringOption(rawFramebuffer?.packing) ?? undefined) as 'bits' | 'bits32' | 'rgb332x4' | undefined,
        pixelScale: numberOption(rawFramebuffer?.pixel_scale) ?? numberOption(rawFramebuffer?.pixelScale),
        onColor: numberOption(rawFramebuffer?.on_color) ?? numberOption(rawFramebuffer?.onColor),
        offColor: numberOption(rawFramebuffer?.off_color) ?? numberOption(rawFramebuffer?.offColor),
        initSignal: stringOption(annotation.init_signal) ?? stringOption(annotation.initSignal),
        initCycles: numberOption(annotation.init_cycles) ?? numberOption(annotation.initCycles),
    } satisfies NonNullable<SimulationRequest['framebuffer']> : undefined;
    const clock = stringOption(annotation.clock);
    return {
        top: annotatedTop,
        clock,
        framebuffer,
        frames: numberOption(annotation.frames),
        frameCycles: numberOption(annotation.frame_cycles) ?? numberOption(annotation.frameCycles),
        clockHz: numberOption(annotation.clock_hz) ?? numberOption(annotation.clockHz),
        frameRate: numberOption(annotation.frame_rate) ?? numberOption(annotation.frameRate),
        // A framebuffer alone does not make a design clocked. Static images
        // should use one-shot capture; only a declared clock can be streamed
        // or manually stepped.
        clocked: Boolean(clock),
    };
}

function visualSimulation(requestedTop: string, source = '', dependencies: Iterable<string> = []): VisualSimulation {
    const annotated = annotatedSimulation(source, requestedTop, dependencies);
    if (annotated && (!requestedTop || annotated.top?.toLowerCase() === requestedTop.toLowerCase())) return annotated;
    // Simulator behavior is explicit: without a valid @simulation annotation
    // the compiler may still run a scalar design, but the playground does not
    // infer visual tops or framebuffer formats from filenames.
    return { clocked: false };
}
let framebufferAnimation: number | undefined;
function updateSimulationControls() {
    const run = button('simulation-run');
    const stop = button('simulation-stop');
    run.textContent = realtimeRunning && !realtimePaused ? 'Pause' : 'Run';
    stop.disabled = !realtimeRunning;
}

function renderSimulationFrames(frames: Array<{ width: number; height: number; pixels: number[] }>, frameRate = 60) {
    const canvas = element<HTMLCanvasElement>('simulation-framebuffer');
    if (framebufferAnimation !== undefined) clearTimeout(framebufferAnimation);
    framebufferAnimation = undefined;
    if (frames.length === 0) { canvas.hidden = true; return; }
    canvas.hidden = false;
    canvas.width = frames[0].width;
    canvas.height = frames[0].height;
    // A canvas defaults to its backing-store dimensions. Small semantic
    // framebuffers (for example ImageSim's 40×30 output) would otherwise be
    // rendered as a postage stamp even though the pixels are correct. Pick an
    // integer pixel scale that fits the panel and keep image-rendering crisp.
    const availableWidth = canvas.parentElement?.clientWidth || 640;
    const scale = Math.max(1, Math.floor(Math.min(Math.min(640, availableWidth) / frames[0].width, 360 / frames[0].height)));
    canvas.style.width = `${frames[0].width * scale}px`;
    canvas.style.height = `${frames[0].height * scale}px`;
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
            const delay = 1000 / Math.max(1, Math.min(240, frameRate));
            framebufferAnimation = window.setTimeout(draw, delay);
        }
    };
    draw();
}

function renderSimulationOutput(outputs: Record<string, number>, messages: string[], cycles: number, hasFramebuffer: boolean) {
    const lines = [`cycles: ${cycles}`];
    const outputEntries = Object.entries(outputs).filter(([name]) => !hasFramebuffer || !/^(state|pixel|pixels|framebuffer)_/.test(name));
    for (const [name, value] of outputEntries.slice(0, 100)) lines.push(`${name} = ${value}`);
    if (outputEntries.length > 100) lines.push(`… ${outputEntries.length - 100} more outputs`);
    if (messages.length) lines.push('', ...messages);
    element('simulation-output').textContent = lines.join('\n');
}

function handleRealtimeEvent(event: SimulationStreamEvent) {
    if (event.type === 'error') {
        realtimeRunning = false;
        realtimePaused = false;
        updateSimulationControls();
        element('simulation-state').textContent = 'Error';
        element('simulation-output').textContent = event.error ?? 'The simulation worker stopped unexpectedly.';
        setStatus('Simulation failed · check the simulation output', 'error');
        return;
    }
    if (event.type === 'stopped') {
        realtimeRunning = false;
        realtimePaused = false;
        updateSimulationControls();
        return;
    }
    if (event.type === 'paused') {
        realtimePaused = true;
        updateSimulationControls();
        element('simulation-state').textContent = `${event.totalCycles ?? 0} cycles · Paused`;
        setStatus('Simulation paused');
        return;
    }
    if (event.type === 'resumed') {
        realtimePaused = false;
        updateSimulationControls();
        element('simulation-state').textContent = `${event.totalCycles ?? 0} cycles · Running`;
        setStatus('Simulating…', 'loading');
        return;
    }
    realtimeRunning = true;
    realtimePaused = false;
    updateSimulationControls();
    if (event.frame) renderSimulationFrames([event.frame]);
    renderSimulationOutput(event.outputs ?? {}, event.messages ?? [], event.totalCycles ?? 0, Boolean(event.frame));
    element('simulation-state').textContent = `${event.totalCycles ?? 0} cycles · Running`;
    setStatus(event.type === 'started' ? '✓ Simulation started' : 'Simulating…', event.type === 'started' ? 'success' : 'loading');
}

async function runSimulation(action: SimulationRequest['action'] = 'run') {
    setMobileView('output');
    if (action === 'run' && realtimeRunning) {
        if (realtimePaused) realtimeSimulation.resume();
        else realtimeSimulation.pause();
        return;
    }
    if (action !== 'run') {
        realtimeSimulation.stop();
        realtimeRunning = false;
        realtimePaused = false;
        updateSimulationControls();
    }
    const id = ++requestId;
    latestRequest = id;
    const readPositive = (id: string) => {
        const value = Number(element<HTMLInputElement>(id).value);
        return Number.isFinite(value) && value > 0 ? value : undefined;
    };
    const cycles = Math.max(0, Math.min(100000, Number(element<HTMLInputElement>('simulation-cycles').value) || 0));
    const requestedTop = element<HTMLInputElement>('simulation-top').value.trim();
    const clock = element<HTMLInputElement>('simulation-clock').value.trim() || undefined;
    const inputs = parseSimulationInputs(element<HTMLInputElement>('simulation-inputs').value);
    const entryPath = sharedEntryPath ?? selection.path;
    const source = editors.input.getValue();
    // Exclude the entry path itself: files contains the repository original,
    // which must not make a stale annotation look valid after an edit. Other
    // files are available to resolve annotations such as Sim.yodl's imported
    // LifeSim module.
    const dependencies = Object.entries({ ...files, ...sharedFiles })
        .filter(([path]) => path !== entryPath)
        .map(([, content]) => content);
    const visual = visualSimulation(requestedTop, source, dependencies);
    // A source edit can remove an annotated/fallback simulator top while the
    // text field still contains its old value. Let the simulator infer the
    // actual top in that case instead of issuing a guaranteed missing-module
    // error (for example, an edited Noise.yodl without NoiseSim).
    const top = requestedTop && hasModuleInSources([source, ...dependencies], requestedTop) ? requestedTop : visual.top;
    const width = readPositive('simulation-width');
    const height = readPositive('simulation-height');
    const framebuffer = visual.framebuffer && (width || height) ? {
        ...visual.framebuffer,
        width: width ?? visual.framebuffer.width,
        height: height ?? visual.framebuffer.height,
    } : visual.framebuffer;
    const clockHz = readPositive('simulation-clock-hz') ?? visual.clockHz;
    const frameRate = readPositive('simulation-frame-rate') ?? visual.frameRate ?? 60;
    const frameCount = framebuffer ? Math.max(1, Math.min(600, readPositive('simulation-frames') ?? visual.frames ?? 60)) : undefined;
    const requestedFrameCycles = readPositive('simulation-frame-cycles');
    const cadenceOverride = readPositive('simulation-clock-hz') !== undefined || readPositive('simulation-frame-rate') !== undefined;
    const frameCycles = framebuffer
        ? requestedFrameCycles !== undefined
            ? Math.max(0, Math.min(100000, requestedFrameCycles))
            : cadenceOverride
                ? Math.max(1, Math.min(100000, clockHz ? Math.round(clockHz / frameRate) : 1))
                : visual.frameCycles ?? Math.max(1, Math.min(100000, clockHz ? Math.round(clockHz / frameRate) : 1))
        : undefined;
    element('output-pane').dataset.view = 'simulation';
    element('simulation-state').textContent = action === 'run' ? 'Running…' : action === 'reset' ? 'Resetting…' : action === 'step_frame' ? 'Stepping frame…' : 'Stepping cycle…';
    button('simulation-step-cycle').disabled = !visual.clocked;
    button('simulation-step-frame').hidden = !(framebuffer && visual.clocked);
    renderSimulationFrames([]);
    setStatus('Simulating…', 'loading');
    const simulationRequest = {
        source: editors.input.getValue(),
        path: entryPath,
        stage: 'write_low_firrtl',
        files: { ...files, ...sharedFiles },
        simulate: { action, top, clock: clock ?? visual.clock, cycles, inputs, frames: frameCount, frameCycles, framebuffer },
    } as const;
    if (action === 'run' && framebuffer && visual.clocked) {
        // Visual runs are streamed by a persistent worker. It captures the
        // initial frame once, then advances one frame per wall-clock deadline.
        realtimeSimulation.start({ ...simulationRequest, simulate: { ...simulationRequest.simulate, mode: 'realtime' } }, handleRealtimeEvent);
        return;
    }
    const result = await compiler.compile('simulation', simulationRequest);
    if (!result || id !== latestRequest) return;
    if (result.error !== undefined) {
        element('simulation-state').textContent = 'Error';
        element('simulation-output').textContent = result.error;
        setStatus('Simulation failed · check the simulation output', 'error');
        return;
    }
    const simulation = result.simulation;
    if (!simulation) return;
    renderSimulationOutput(simulation.outputs, simulation.messages, simulation.cycles, Boolean(simulation.framebuffers));
    renderSimulationFrames(simulation.framebuffers ?? [], frameRate);
    button('simulation-step-cycle').disabled = !simulation.clock;
    button('simulation-step-frame').hidden = !(simulation.framebuffers?.length && simulation.clock);
    element('simulation-state').textContent = simulation.framebuffers?.length ? `${simulation.framebuffers.length} frame${simulation.framebuffers.length === 1 ? '' : 's'} · ${simulation.cycles} cycles` : `${simulation.cycles} cycles`;
    updateSimulationControls();
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
    for (const id of ['share-button', 'source-selector', 'compile-button', 'simulate-button', 'simulation-reset', 'simulation-step-cycle', 'simulation-step-frame', 'simulation-stop', 'simulation-run', 'simulation-top', 'simulation-clock', 'simulation-cycles', 'simulation-frames', 'simulation-frame-cycles', 'simulation-width', 'simulation-height', 'simulation-clock-hz', 'simulation-frame-rate', 'simulation-inputs', 'pass-selector', 'reset-button', 'download-source']) (element(id) as HTMLButtonElement).disabled = false;
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
    button('simulate-button').onclick = () => runSimulation('run');
    button('simulation-run').onclick = () => runSimulation('run');
    button('simulation-reset').onclick = () => runSimulation('reset');
    button('simulation-step-cycle').onclick = () => runSimulation('step_cycle');
    button('simulation-step-frame').onclick = () => runSimulation('step_frame');
    button('simulation-stop').onclick = () => {
        realtimeSimulation.stop();
        realtimeRunning = false;
        realtimePaused = false;
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

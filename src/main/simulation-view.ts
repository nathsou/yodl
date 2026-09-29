import { RealtimeSimulationClient } from './compiler-client.ts';
import type { SimulationFramebuffer, SimulationRequest, SimulationSignal, SimulationStreamEvent } from './playground-compiler.ts';

export type SimulationHost = {
    /** The design to simulate: the current entry source and its virtual files. */
    request(): { source: string; path: string; files: Record<string, string> };
    setStatus(message: string, state?: string): void;
};
type State = 'ready' | 'starting' | 'running' | 'paused' | 'stepping' | 'halted' | 'error';
type Sample = { cycle: number; values: Map<string, SimulationSignal> };

const element = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const traceWindow = 16;
const maxTraceRows = 10;
const maxSamples = 512;

export function parseSimulationInputs(source: string): Record<string, { width: number; value: number }> {
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

/** `8'h2a` for buses, `0`/`1` for single bits, `x` for unknown values. */
export function formatSignal(signal: SimulationSignal): string {
    if (!signal.known) return 'x';
    if (signal.width === 1) return signal.value === '0' ? '0' : '1';
    try { return `${signal.width}'h${BigInt(signal.value).toString(16)}`; } catch { return signal.value; }
}
const shortHex = (signal: SimulationSignal) => {
    if (!signal.known) return 'x';
    try { return BigInt(signal.value).toString(16); } catch { return signal.value; }
};
export function formatRate(hertz: number): string {
    if (hertz >= 1e6) return `${(hertz / 1e6).toFixed(1)} MHz`;
    if (hertz >= 1e4) return `${Math.round(hertz / 1e3)} kHz`;
    if (hertz >= 1e3) return `${(hertz / 1e3).toFixed(1)} kHz`;
    return `${hertz < 10 ? hertz.toFixed(1) : Math.round(hertz)} Hz`;
}

export function createSimulationView(host: SimulationHost) {
    const realtime = new RealtimeSimulationClient();
    let state: State = 'ready';
    let clock: string | undefined;
    let history: Sample[] = [];
    let lastFrame: SimulationFramebuffer | undefined;
    let canvasImage: ImageData | undefined;
    const button = (id: string) => element<HTMLButtonElement>(id);
    const input = (id: string) => element<HTMLInputElement>(id);
    const inputFields = ['simulation-top', 'simulation-clock', 'simulation-cycles-per-frame', 'simulation-clock-hz', 'simulation-refresh-fps'];

    function updateControls() {
        const running = state === 'running' || state === 'stepping';
        button('simulation-run').textContent = running ? 'Pause' : state === 'paused' ? 'Resume' : 'Run';
        button('simulation-run').disabled = state === 'starting' || state === 'halted';
        button('simulation-reset').disabled = state === 'ready' || state === 'starting';
        button('simulation-stop').disabled = state === 'ready';
    }

    function renderFrame(frame: SimulationFramebuffer | undefined) {
        const canvas = element<HTMLCanvasElement>('simulation-framebuffer');
        lastFrame = frame;
        element('simulation-zoom-control').hidden = !frame;
        if (!frame) { canvas.hidden = true; return; }
        canvas.hidden = false;
        if (canvas.width !== frame.width || canvas.height !== frame.height) {
            canvas.width = frame.width;
            canvas.height = frame.height;
            canvasImage = undefined;
        }
        const availableWidth = (canvas.parentElement?.clientWidth || 640) - 32;
        const zoom = element<HTMLSelectElement>('simulation-zoom').value;
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

    function signalRow(signal: SimulationSignal, control: HTMLElement) {
        const row = document.createElement('div');
        row.className = 'signal';
        const name = document.createElement('span');
        name.className = 'signal-name';
        name.append(signal.name + ' ');
        const type = document.createElement('small');
        type.textContent = signal.width === 1 ? 'bool' : `u${signal.width}`;
        name.append(type);
        row.append(name, control);
        return row;
    }

    function renderInputs(inputs: SimulationSignal[]) {
        const container = element('simulation-inputs-controls');
        const signature = inputs.map(signal => `${signal.name}:${signal.width}:${signal.value}:${signal.known}`).join('|');
        if (container.dataset.signature === signature) return;
        container.dataset.signature = signature;
        container.replaceChildren();
        const publish = (changed: HTMLElement) => {
            const assignments = [...container.querySelectorAll<HTMLElement>('[data-signal]')].map(control => {
                const value = control instanceof HTMLInputElement ? control.value : control.getAttribute('aria-checked') === 'true' ? 1 : 0;
                return `${control.dataset.signal}:${control.dataset.width}=${value}`;
            });
            input('simulation-inputs').value = assignments.join(', ');
            try {
                const parsed = parseSimulationInputs(assignments.join(', '));
                if (changed instanceof HTMLInputElement) changed.setCustomValidity('');
                if (state !== 'ready') realtime.setInputs(parsed);
            } catch (error) {
                if (changed instanceof HTMLInputElement) { changed.setCustomValidity(String(error)); changed.reportValidity(); }
            }
        };
        for (const signal of inputs) {
            let control: HTMLElement;
            if (signal.width === 1) {
                const toggle = document.createElement('button');
                toggle.type = 'button';
                toggle.setAttribute('role', 'switch');
                toggle.setAttribute('aria-checked', String(signal.value !== '0'));
                toggle.setAttribute('aria-label', signal.name);
                toggle.textContent = signal.value !== '0' ? '1' : '0';
                toggle.addEventListener('click', () => {
                    const on = toggle.getAttribute('aria-checked') !== 'true';
                    toggle.setAttribute('aria-checked', String(on));
                    toggle.textContent = on ? '1' : '0';
                    publish(toggle);
                });
                control = toggle;
            } else {
                const field = document.createElement('input');
                field.type = 'text';
                field.value = signal.value;
                field.inputMode = 'numeric';
                field.title = `u${signal.width}`;
                field.setAttribute('aria-label', signal.name);
                field.addEventListener('change', () => publish(field));
                control = field;
            }
            control.className = 'signal-value';
            control.dataset.signal = signal.name;
            control.dataset.width = String(signal.width);
            container.append(signalRow(signal, control));
        }
        if (!inputs.length) container.append(emptyNote('No inputs'));
    }
    function emptyNote(text: string) {
        const note = document.createElement('p');
        note.className = 'signal-empty';
        note.textContent = text;
        return note;
    }
    function renderOutputs(outputs: SimulationSignal[]) {
        const container = element('simulation-outputs');
        const rows = outputs.slice(0, 100).map(signal => {
            const value = document.createElement('span');
            value.className = 'signal-value signal-output';
            value.textContent = formatSignal(signal);
            return signalRow(signal, value);
        });
        if (outputs.length > 100) rows.push(signalRow({ name: `… ${outputs.length - 100} more`, width: 0, value: '', known: false }, document.createElement('span')));
        container.replaceChildren(...(rows.length ? rows : [emptyNote('No outputs')]));
    }

    // The trace samples the signals each time the worker reports. At slow clock
    // rates that is every cycle; when running fast it is a sampled view.
    function recordSample(event: SimulationStreamEvent) {
        if (event.totalCycles === undefined || (!event.outputs && !event.inputs)) return;
        const values = new Map<string, SimulationSignal>();
        for (const signal of [...(event.inputs ?? []), ...(event.outputs ?? [])]) values.set(signal.name, signal);
        const last = history.at(-1);
        if (last && last.cycle === event.totalCycles) { last.values = values; return; }
        if (last && event.totalCycles < last.cycle) history = [];
        history.push({ cycle: event.totalCycles, values });
        if (history.length > maxSamples) history.shift();
    }
    function renderTrace() {
        const container = element('simulation-trace');
        if (!history.length) {
            container.replaceChildren(emptyNote('Run or step the simulation to record signals.'));
            element('trace-range').textContent = '';
            return;
        }
        const latest = history.at(-1)!;
        const names = [...latest.values.keys()].filter(name => name !== clock).slice(0, maxTraceRows - (clock ? 1 : 0));
        const start = Math.max(0, history.length - traceWindow);
        const shown = history.slice(start);
        const rows: HTMLElement[] = [];
        const row = (name: string, cells: HTMLElement[]) => {
            const line = document.createElement('div');
            line.className = 'trace-row';
            const label = document.createElement('span');
            label.className = 'trace-name'; label.textContent = name; label.title = name;
            const lane = document.createElement('div');
            lane.className = 'trace-lane';
            lane.append(...cells);
            line.append(label, lane);
            return line;
        };
        const cell = (kind: string, future: boolean, edge: boolean) => {
            const item = document.createElement('div');
            item.className = 'trace-cell';
            item.dataset.kind = kind;
            if (future) item.dataset.future = '';
            if (edge) item.dataset.edge = '';
            return item;
        };
        if (clock) {
            const cells: HTMLElement[] = [];
            for (let i = 0; i < traceWindow; i++) {
                const item = cell('clock', i >= shown.length, i === 0);
                item.append(document.createElement('span'), document.createElement('span'));
                cells.push(item);
            }
            rows.push(row(clock, cells));
        }
        for (const name of names) {
            const cells: HTMLElement[] = [];
            let previous: string | undefined;
            for (let i = 0; i < traceWindow; i++) {
                const sample = shown[Math.min(i, shown.length - 1)].values.get(name);
                const future = i >= shown.length;
                if (!sample) { cells.push(cell('bus', future, false)); continue; }
                const bit = sample.width === 1 && sample.known;
                const value = `${sample.known}:${sample.value}`;
                const changed = !future && (previous === undefined || previous !== value);
                const item = cell(bit ? 'bit' : 'bus', future, changed);
                if (bit && sample.value !== '0') item.dataset.high = '';
                if (!bit && changed) {
                    const text = document.createElement('span');
                    text.className = 'bus-value';
                    text.textContent = shortHex(sample);
                    item.append(text);
                }
                if (!future) previous = value;
                cells.push(item);
            }
            rows.push(row(name, cells));
        }
        container.replaceChildren(...rows);
        element('trace-range').textContent = shown.length > 1 ? `cycles ${shown[0].cycle}–${latest.cycle}` : `cycle ${latest.cycle}`;
    }

    function handleEvent(event: SimulationStreamEvent) {
        const output = element('simulation-output');
        if (event.type === 'error') {
            state = 'error';
            output.hidden = false;
            output.textContent = event.error ?? 'Simulation failed.';
            element('simulation-state').textContent = 'Error';
            updateControls();
            host.setStatus('Simulation failed', 'error');
            return;
        }
        state = event.type === 'halted' ? 'halted'
            : event.type === 'stopped' ? 'ready'
            : event.type === 'stepping' ? 'stepping'
            : event.type === 'frame' || event.type === 'resumed' ? 'running' : 'paused';
        if (event.frame) renderFrame(event.frame);
        else if (event.metadata && !event.metadata.display) renderFrame(undefined);
        if (event.clock !== undefined) clock = event.clock;
        if (event.inputs) event = { ...event, inputs: event.inputs.filter(signal => signal.name !== clock) };
        if (event.outputs) renderOutputs(event.outputs);
        if (event.inputs) renderInputs(event.inputs);
        recordSample(event);
        renderTrace();
        const messages = event.messages ?? [];
        output.hidden = messages.length === 0;
        output.textContent = messages.join('\n');
        button('simulation-step-cycle').disabled = !event.clock || state === 'halted';
        button('simulation-step-frame').hidden = !(event.frame && event.clock);
        button('simulation-step-frame').disabled = state === 'halted';
        if (event.metadata) {
            const values = { 'simulation-top': event.metadata.top, 'simulation-clock': event.clock, 'simulation-cycles-per-frame': event.playback?.cyclesPerFrame, 'simulation-clock-hz': event.playback?.clockHz ?? 'maximum', 'simulation-refresh-fps': event.playback?.refreshFps };
            for (const [id, value] of Object.entries(values)) input(id).placeholder = String(value ?? 'automatic');
            input('simulation-cycles-per-frame').disabled = !event.clock || Boolean(event.metadata.display?.stream);
            input('simulation-clock-hz').disabled = !event.clock;
            input('simulation-refresh-fps').disabled = !event.clock;
        }
        const total = event.totalCycles ?? 0;
        const rate = event.cyclesPerSecond === undefined || (state !== 'running' && state !== 'stepping') ? '' : ` · ${formatRate(event.cyclesPerSecond)}`;
        element('simulation-cycle').textContent = `cycle ${total.toLocaleString()}${rate}`;
        const time = event.simulatedSeconds === undefined ? '' : ` · ${event.simulatedSeconds.toFixed(3)} simulated s`;
        const failed = event.status?.failed ?? false;
        const label = failed ? 'Failed' : state[0].toUpperCase() + state.slice(1);
        const exit = event.status?.exit_code === undefined ? '' : ` · exit ${event.status.exit_code}`;
        element('simulation-state').textContent = `${label}${exit}${time}`;
        updateControls();
        host.setStatus(failed ? `Simulation failed${event.status?.first_failure ? `: ${event.status.first_failure.message}` : ''}` : state === 'running' || state === 'stepping' ? 'Simulating…' : `Simulation ${state}`, failed ? 'error' : undefined);
    }

    function run(action: SimulationRequest['action'] = 'run') {
        const readPositive = (id: string) => {
            const value = Number(input(id).value);
            return Number.isFinite(value) && value > 0 ? value : undefined;
        };
        const options = { clockHz: readPositive('simulation-clock-hz'), refreshFps: readPositive('simulation-refresh-fps'), cyclesPerFrame: readPositive('simulation-cycles-per-frame') };
        if (state !== 'ready' && state !== 'error') {
            if (action === 'run') {
                if (state === 'running' || state === 'stepping') realtime.pause();
                else realtime.resume(options);
            } else realtime.command(action as 'reset' | 'step_cycle' | 'step_frame', options);
            return;
        }
        const top = input('simulation-top').value.trim();
        const requestedClock = input('simulation-clock').value.trim();
        history = [];
        renderTrace();
        element('simulation-state').textContent = 'Compiling simulation…';
        state = 'starting';
        updateControls();
        try {
            const { source, path, files } = host.request();
            realtime.start({
                source, path, stage: 'write_low_firrtl', files,
                simulate: { action, ...(top ? { top } : {}), ...(requestedClock ? { clock: requestedClock } : {}), ...Object.fromEntries(Object.entries(options).filter(([, value]) => value !== undefined)), inputs: parseSimulationInputs(input('simulation-inputs').value) },
            }, handleEvent);
        } catch (error) { handleEvent({ id: 0, type: 'error', error: String(error) }); }
    }

    function stop() {
        realtime.stop();
        state = 'ready';
        element('simulation-state').textContent = 'Ready';
        element('simulation-cycle').textContent = 'cycle 0';
        updateControls();
    }

    button('simulation-run').onclick = () => run('run');
    button('simulation-reset').onclick = () => { history = []; renderTrace(); run('reset'); };
    button('simulation-step-cycle').onclick = () => run('step_cycle');
    button('simulation-step-frame').onclick = () => run('step_frame');
    element<HTMLSelectElement>('simulation-zoom').onchange = () => { if (lastFrame) renderFrame(lastFrame); };
    button('simulation-stop').onclick = () => { stop(); host.setStatus('Simulation stopped'); };
    button('simulation-settings').onclick = () => {
        const options = element('simulation-options');
        options.hidden = !options.hidden;
        button('simulation-settings').setAttribute('aria-expanded', String(!options.hidden));
    };
    renderTrace();
    renderOutputs([]);
    renderInputs([]);
    updateControls();

    return {
        /** Enable the controls once the editor (and so a design) exists. */
        enable() { for (const id of ['simulation-run', 'simulation-step-cycle', ...inputFields]) (element(id) as HTMLButtonElement).disabled = false; updateControls(); },
        /** Stop the worker and return to the ready state (the source changed or was recompiled). */
        stop,
        /** Forget everything about the previous design's run. */
        clear() {
            stop();
            history = []; clock = undefined;
            renderFrame(undefined); renderTrace(); renderOutputs([]);
            element('simulation-inputs-controls').dataset.signature = '';
            renderInputs([]);
            element('simulation-output').hidden = true;
            for (const id of ['simulation-top', 'simulation-clock', 'simulation-inputs']) input(id).value = '';
        },
        clearFrame() { renderFrame(undefined); },
        get active() { return state !== 'ready' && state !== 'error'; },
        run,
    };
}
export type SimulationView = ReturnType<typeof createSimulationView>;

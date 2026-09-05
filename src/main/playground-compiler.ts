import { unwrap, yodl, ext, createInMemoryFileSystem } from './yodl.ts';
import type { Stage } from './compiler-stages.ts';

const {
    host_simulator_poke: simulator_poke_int,
    host_simulator_step: simulator_step,
    host_simulator_clocks: simulator_clocks,
    host_simulator_settle: simulator_settle,
    host_simulator_drain_events: simulator_drain_events,
    host_simulator_status: simulator_status,
    host_simulator_exit_codes: simulator_exit_codes,
    host_simulator_set_history_retention: simulator_set_history_retention,
    host_simulator_output_signals: simulator_output_signals,
    host_simulator_inputs: simulator_inputs,
    host_simulator_frame: simulator_frame_with_layout,
    host_simulator_halted: simulator_halted,
    host_simulator_visible_outputs: simulator_visible_outputs,
    host_simulator_raster_new: simulator_raster_new_with_ports,
    host_simulator_raster_step: simulator_raster_step,
} = yodl as any;

export type SimulationRequest = {
    action?: 'run' | 'reset' | 'step_cycle' | 'step_frame' | 'settle' | 'pause' | 'resume' | 'stop';
    mode?: 'batch' | 'realtime';
    top?: string;
    clock?: string;
    cycles?: number;
    inputs?: Record<string, { width: number; value: number }>;
    reset?: { signal: string; cycles?: number };
    /** Batch capture length; not a circuit annotation. */
    captureFrames?: number;
    cyclesPerFrame?: number;
    clockHz?: number;
    /** Realtime canvas refresh limit; independent of simulated clock speed. */
    refreshFps?: number;
    /** Logical display-buffer binding. Dimensions and binary mode are inferred from
     * the typed aggregate output when they are omitted. */
    display?: { buffer?: string; stream?: string; width?: number; height?: number; valueMode?: 'binary' | 'gray' | 'rgb'; packing?: 'bits' | 'bits32' | 'rgb332x4'; pixelScale?: number; onColor?: number; offColor?: number };
};
type ResolvedFramebuffer = NonNullable<SimulationRequest['display']> & { signal: string; width: number; height: number };
export type CompileRequest = { id: number; source: string; path: string; stage: Stage; files?: Record<string, string>; simulate?: SimulationRequest };
/** A display frame. `packed` is present for logical binary matrices and is
 * transferred as row-major u32 words by the realtime worker. `rgb` contains
 * color pixels; `pixels` is retained only for explicitly packed inputs. */
export type SimulationFramebuffer = { width: number; height: number; signal?: string; pixels?: number[]; packed?: Uint32Array; rgb?: Uint32Array; valid?: Uint32Array; onColor?: number; offColor?: number };
export type SimulationSignal = { name: string; width: number; value: string; known: boolean };
export type SimulationMetadata = { top?: string; clock?: string; reset?: NonNullable<SimulationRequest['reset']>; display?: NonNullable<SimulationRequest['display']>; cyclesPerFrame?: number; clockHz?: number };
export type SimulationEvent = { kind: 'printf' | 'assert_failure' | 'assert_unknown'; message: string; text: string; cycle: number; instancePath: string; source?: string };
export type SimulationStatus = { halted: boolean; exit_code?: number; failed: boolean; first_failure?: SimulationEvent };
export type SimulationAdvance = { cycles: number; boundaryComplete: boolean; halted: boolean };
export type SimulationResult = { outputs: SimulationSignal[]; inputs: SimulationSignal[]; messages: string[]; events: SimulationEvent[]; status: SimulationStatus; cycles: number; halted?: boolean; clock?: string; metadata?: SimulationMetadata; framebuffers?: SimulationFramebuffer[] };
export type CompileResult = { id: number; output?: string; error?: string; duration: number; sources?: Record<string, string>; simulation?: SimulationResult };
export type SimulationStreamEvent = {
    id: number;
    type: 'started' | 'frame' | 'snapshot' | 'paused' | 'resumed' | 'stopped' | 'halted' | 'stepping' | 'error';
    sources?: Record<string, string>;
    frame?: SimulationFramebuffer;
    outputs?: SimulationSignal[];
    inputs?: SimulationSignal[];
    messages?: string[];
    events?: SimulationEvent[];
    status?: SimulationStatus;
    cycles?: number;
    totalCycles?: number;
    error?: string;
    metadata?: SimulationMetadata;
    playback?: { refreshFps: number; clockHz?: number; cyclesPerFrame: number };
    clock?: string;
    simulatedSeconds?: number;
    cyclesPerSecond?: number;
};

type DisplayDescriptor = { buffer: string; stream: boolean; width: number; height: number; bits: number; ports: string[] };

function inferFramebuffer(displays: DisplayDescriptor[], selected?: string): ResolvedFramebuffer | undefined {
    const display = selected ? displays.find(d => d.buffer === selected)
        : displays.length === 1 ? displays[0] : undefined;
    if (selected && !display) throw new Error(`Display buffer '${selected}' must name a two-dimensional unsigned output array.`);
    if (!display) return undefined;
    return { signal: display.buffer, width: display.width, height: display.height, valueMode: display.bits === 1 ? 'binary' : 'rgb' };
}

function outputValues(signals: SimulationSignal[]): Record<string, number> {
    return Object.fromEntries(signals.map(signal => [signal.name, signal.known ? Number(signal.value) : NaN]));
}

function positive(value: string | undefined): number | undefined {
    const number = Number(value);
    return Number.isFinite(number) && number > 0 ? number : undefined;
}

function nonNegative(value: string | undefined): number | undefined {
    const number = Number(value);
    return Number.isFinite(number) && number >= 0 ? number : undefined;
}

function metadataFromPairs(pairs: Array<{ _0: string; _1: string }>): SimulationMetadata | undefined {
    if (!pairs.length) return undefined;
    const values = Object.fromEntries(pairs.map(pair => [pair._0, pair._1]));
    const allowed = new Set(['location', 'module', 'top', 'clock', 'reset', 'reset.signal', 'reset.cycles', 'display.buffer', 'display.stream', 'display.width', 'display.height', 'display.mode', 'display.packing', 'display.pixel_scale', 'display.on_color', 'display.off_color', 'cycles_per_frame', 'clock_hz']);
    for (const [key, value] of Object.entries(values)) {
        if (!allowed.has(key)) throw new Error(`Unknown @simulation option '${key}'.`);
        if (/(width|height|cycles|frames|hz|rate|scale)$/.test(key) && (!Number.isSafeInteger(Number(value)) || Number(value) < 0)) throw new Error(`@simulation '${key}' must be a nonnegative integer.`);
        if (key.endsWith('.mode') && !['binary', 'gray', 'rgb'].includes(value)) throw new Error(`Unknown display mode '${value}'.`);
        if (key.endsWith('.packing') && !['bits', 'bits32', 'rgb332x4'].includes(value)) throw new Error(`Unknown display packing '${value}'.`);
    }
    if (values.cycles_per_frame !== undefined && (!Number.isSafeInteger(Number(values.cycles_per_frame)) || Number(values.cycles_per_frame) < 1 || Number(values.cycles_per_frame) > 100000)) throw new Error('cycles_per_frame must be an integer between 1 and 100000.');
    const hasDisplay = Object.keys(values).some(key => key.startsWith('display.'));
    if (hasDisplay && !values['display.buffer'] && !values['display.stream']) throw new Error('The display object requires buffer (array output) or stream (pixel stream).');
    if (values['display.buffer'] && values['display.stream']) throw new Error('Choose either display.buffer or display.stream.');
    if (values['display.packing'] && (!positive(values['display.width']) || !positive(values['display.height']))) throw new Error('Explicitly packed displays require positive width and height.');
    const resetSignal = values['reset.signal'] ?? values.reset;
    const logicalDisplayBuffer = values['display.buffer'];
    const display = logicalDisplayBuffer || values['display.stream'] ? {
        buffer: logicalDisplayBuffer,
        stream: values['display.stream'],
        width: positive(values['display.width']),
        height: positive(values['display.height']),
        valueMode: values['display.mode'] as 'binary' | 'gray' | 'rgb' | undefined,
        packing: values['display.packing'] as 'bits' | 'bits32' | 'rgb332x4' | undefined,
        pixelScale: positive(values['display.pixel_scale']),
        onColor: values['display.on_color'] === undefined ? undefined : Number(values['display.on_color']),
        offColor: values['display.off_color'] === undefined ? undefined : Number(values['display.off_color']),
    } satisfies SimulationRequest['display'] : undefined;
    return {
        top: values.top ?? values.module,
        clock: values.clock,
        reset: resetSignal ? { signal: resetSignal, cycles: nonNegative(values['reset.cycles']) } : undefined,
        display,
        cyclesPerFrame: positive(values.cycles_per_frame),
        clockHz: positive(values.clock_hz),
    };
}

/** Parsed compiler-owned simulation metadata. This is deliberately separate
 * from `compile` so the UI can choose appropriate controls before a run. */
export function readSimulationMetadata(request: Pick<CompileRequest, 'source' | 'path' | 'files'>, top?: string): SimulationMetadata | undefined {
    const fs = createInMemoryFileSystem({ ...request.files, [request.path]: request.source });
    unwrap(fs.write_string_to_file(request.path, request.source));
    const topOption = top === undefined ? { $tag: 0 } : { $tag: 1, _0: top };
    const pairs = unwrap(yodl.simulation_metadata(request.path, { ...ext, fs }, topOption)) as Array<{ _0: string; _1: string }>;
    try { return metadataFromPairs(pairs); }
    catch (error) { throw new Error(`${simulationError(error)} at ${pairs.find(pair => pair._0 === 'location')?._1 ?? request.path}`); }
}

function simulationFramebuffer(values: Record<string, number>, framebuffer: ResolvedFramebuffer): SimulationFramebuffer | undefined {
    if (!framebuffer) return undefined;
    const pixels = new Array(framebuffer.width * framebuffer.height).fill(framebuffer.offColor ?? 0);
    const signal = framebuffer.signal;
    if (!signal) return undefined;
    const prefix = `${signal}_`;
    const pixelScale = Number.isInteger(framebuffer.pixelScale) && framebuffer.pixelScale! > 0 ? framebuffer.pixelScale! : 1;
    const putPixel = (row: number, col: number, color: number) => {
        for (let dy = 0; dy < pixelScale; dy++) {
            for (let dx = 0; dx < pixelScale; dx++) {
                const y = row * pixelScale + dy;
                const x = col * pixelScale + dx;
                if (y < framebuffer.height && x < framebuffer.width) pixels[y * framebuffer.width + x] = color;
            }
        }
    };
    for (const [name, value] of Object.entries(values)) {
        if (!name.startsWith(prefix)) continue;
        if (framebuffer.packing !== 'rgb332x4' && value === 0) continue;
        const parts = name.slice(prefix.length).split('_');
        if (parts.length !== 2) continue;
        const row = Number(parts[0]);
        const col = Number(parts[1]);
        if (Number.isInteger(row) && Number.isInteger(col) && row >= 0 && row < framebuffer.height && col >= 0 && col < framebuffer.width) {
            if (!Number.isFinite(value)) { putPixel(row, col, 0xff00ff); continue; }
            if (framebuffer.packing === 'bits') {
                if (value === 0) continue;
                for (let bit = 0; bit < 8; bit++) {
                    const x = col * 8 + bit;
                    if (((value >>> bit) & 1) !== 0) putPixel(row, x, framebuffer.onColor ?? 0xffffff);
                }
                continue;
            }
            if (framebuffer.packing === 'bits32') {
                if (value === 0) continue;
                for (let bit = 0; bit < 32; bit++) {
                    const x = col * 32 + bit;
                    if (((value >>> bit) & 1) !== 0) putPixel(row, x, framebuffer.onColor ?? 0xffffff);
                }
                continue;
            }
            if (framebuffer.packing === 'rgb332x4') {
                for (let lane = 0; lane < 4; lane++) {
                    const x = col * 4 + lane;
                    if (x >= framebuffer.width) continue;
                    const packed = (value >>> (lane * 8)) & 0xff;
                    const red = Math.round(((packed >>> 5) & 0x7) * 255 / 7);
                    const green = Math.round(((packed >>> 2) & 0x7) * 255 / 7);
                    const blue = Math.round((packed & 0x3) * 255 / 3);
                    putPixel(row, x, (red << 16) | (green << 8) | blue);
                }
                continue;
            }
            const color = framebuffer.valueMode === 'rgb'
                ? value & 0xffffff
                : framebuffer.valueMode === 'gray'
                    ? ((value & 0xff) * 0x010101) & 0xffffff
                    : framebuffer.onColor ?? 0xffffff;
            putPixel(row, col, color);
        }
    }
    return { width: framebuffer.width, height: framebuffer.height, signal, pixels };
}

/** A compiled machine owned by one worker. Commands never parse source. */
export class SimulationSession {
    readonly metadata: SimulationMetadata;
    readonly clock?: string;
    readonly sources: Record<string, string> = {};
    readonly framebuffer?: ResolvedFramebuffer;
    readonly stream: boolean;
    private machine: any;
    private raster: any;
    private design: any;
    private hidden: string[] = [];
    private nativeDisplay = false;
    private packedDisplayRows = false;
    private streamPorts: string[] = [];
    private firstFailure?: SimulationEvent;
    private inputs: NonNullable<SimulationRequest['inputs']>;
    private options: SimulationRequest;
    constructor(request: CompileRequest) {
        const requested = request.simulate ?? {};
        const fs = createInMemoryFileSystem({ ...request.files, [request.path]: request.source }, (path, source) => { this.sources[path] = source; });
        const compiled: any = unwrap(yodl.compile_simulation_design(request.path, { ...ext, fs, println: () => {} }, requested.top === undefined ? { $tag: 0 } : { $tag: 1, _0: requested.top }));
        const configuration = compiled.configuration;
        const metadata: SimulationMetadata = {
            top: configuration.top,
            clock: configuration.clock,
            reset: configuration.reset ? { signal: configuration.reset.signal, cycles: configuration.reset.cycles } : undefined,
            display: configuration.display ? {
                buffer: configuration.display.buffer,
                stream: configuration.display.stream,
                width: configuration.display.width,
                height: configuration.display.height,
                valueMode: configuration.display.mode,
                packing: configuration.display.packing,
                pixelScale: configuration.display.pixel_scale,
                onColor: configuration.display.on_color,
                offColor: configuration.display.off_color,
            } : undefined,
            cyclesPerFrame: configuration.cycles_per_frame,
            clockHz: configuration.clock_hz,
        };
        this.options = { ...metadata, ...requested, reset: requested.reset ?? metadata?.reset, display: requested.display ?? metadata?.display };
        const options = this.options;
        this.design = compiled;
        this.inputs = options.inputs ?? {};
        this.machine = unwrap(yodl.new_compiled_simulation(this.design));
        simulator_set_history_retention(this.machine, false);
        const clocks = simulator_clocks(this.machine) as string[];
        if (!options.clock && clocks.length > 1) throw new Error('Select a simulation clock: ' + clocks.join(', '));
        this.clock = options.clock ?? clocks[0];
        if (this.clock && !clocks.includes(this.clock)) throw new Error(`Unknown clock '${this.clock}'.`);
        this.stream = Boolean(options.display?.stream);
        if (this.stream) {
            if (options.display?.buffer) throw new Error("Choose either an array buffer or a pixel stream.");
            this.framebuffer = { signal: options.display!.stream!, width: options.display!.width!, height: options.display!.height!, valueMode: 'rgb' };
            const descriptor = compiled.displays.find((display: DisplayDescriptor) => display.stream && display.buffer === this.framebuffer!.signal);
            if (!descriptor) throw new Error(`Display stream '${this.framebuffer.signal}' must name an output record with x, y, valid, r, g, and b fields.`);
            this.hidden = descriptor.ports;
            this.streamPorts = descriptor.ports;
        } else {
            const selected = options.display?.buffer;
            const inferred = inferFramebuffer(compiled.displays, selected);
            this.framebuffer = inferred ? { ...inferred, ...Object.fromEntries(Object.entries(options.display ?? {}).filter(([, v]) => v !== undefined)) } : undefined;
            const descriptor = compiled.displays.find((d: DisplayDescriptor) => d.buffer === this.framebuffer?.signal);
            this.nativeDisplay = Boolean(descriptor && !this.framebuffer?.packing);
            if (descriptor) {
                this.packedDisplayRows = descriptor.bits === 1;
                if (descriptor.bits === 1 && this.framebuffer?.valueMode !== 'binary') throw new Error("Boolean displays use binary mode; set on_color and off_color to change their colors.");
                if (this.nativeDisplay && (this.framebuffer!.width !== descriptor.width || this.framebuffer!.height !== descriptor.height)) throw new Error('Display dimensions come from the output type; use UI zoom to resize it.');
                this.hidden = descriptor.ports;
            }
        }
        if (this.framebuffer && (!Number.isSafeInteger(this.framebuffer.width) || !Number.isSafeInteger(this.framebuffer.height) || this.framebuffer.width < 1 || this.framebuffer.height < 1 || this.framebuffer.width * this.framebuffer.height > 4_194_304)) throw new Error('Display dimensions must be positive integers with at most 4,194,304 pixels.');
        this.metadata = { top: options.top, clock: this.clock, reset: options.reset, clockHz: options.clockHz, cyclesPerFrame: options.cyclesPerFrame, display: options.display ?? (this.framebuffer ? { buffer: this.framebuffer.signal } : undefined) };
        this.initialize();
    }
    private initialize() {
        this.setInputs(this.inputs);
        if (this.options.reset) {
            if (!this.clock) throw new Error('Reset requires a clock.');
            const { signal, cycles = 1 } = this.options.reset;
            if (!Number.isSafeInteger(cycles) || cycles < 0 || cycles > 100000) throw new Error('Reset cycles must be between 0 and 100000.');
            const input = (simulator_inputs(this.machine) as SimulationSignal[]).find(input => input.name === signal);
            if (!input || input.width !== 1) throw new Error(`Reset '${signal}' must name a one-bit input.`);
            unwrap(simulator_poke_int(this.machine, signal, 1, 1));
            for (let i = 0; i < cycles; i++) unwrap(simulator_step(this.machine, this.clock));
            unwrap(simulator_poke_int(this.machine, signal, 1, 0));
            unwrap(simulator_settle(this.machine));
        }
        if (this.stream) this.raster = unwrap(simulator_raster_new_with_ports(this.machine, this.framebuffer!.signal!, this.streamPorts, this.framebuffer!.width, this.framebuffer!.height));
    }
    reset() {
        this.machine = unwrap(yodl.new_compiled_simulation(this.design));
        simulator_set_history_retention(this.machine, false);
        this.firstFailure = undefined;
        this.initialize();
    }
    setInputs(inputs: NonNullable<SimulationRequest['inputs']>) {
        this.inputs = inputs;
        for (const [name, input] of Object.entries(inputs)) unwrap(simulator_poke_int(this.machine, name, input.width, input.value));
        unwrap(simulator_settle(this.machine));
    }
    get halted(): boolean { return simulator_halted(this.machine); }
    get frames(): number { return this.raster?.frames ?? 0; }
    advance(cycles: number, untilFrame = false): number {
        if (!this.clock) throw new Error('Stepping requires a clock.');
        if (this.stream) return unwrap(simulator_raster_step(this.machine, this.raster, this.clock, cycles, untilFrame));
        let advanced = 0;
        for (; advanced < cycles && !this.halted; advanced++) unwrap(simulator_step(this.machine, this.clock));
        return advanced;
    }
    advanceCycles(cycles: number): SimulationAdvance {
        const advanced = this.advance(cycles, false);
        return { cycles: advanced, boundaryComplete: false, halted: this.halted };
    }
    advanceTowardFrame(cycleBudget: number): SimulationAdvance {
        const startFrame = this.frames;
        const advanced = this.advance(cycleBudget, true);
        return { cycles: advanced, boundaryComplete: this.frames > startFrame, halted: this.halted };
    }
    advanceFrame(cycleBudget = 10_000_000): SimulationAdvance {
        if (!this.stream) return this.advanceCycles(this.options.cyclesPerFrame ?? 1);
        const { cycles: advanced, boundaryComplete } = this.advanceTowardFrame(cycleBudget);
        if (!boundaryComplete && !this.halted) throw new Error(`No frame boundary after ${cycleBudget} cycles. Check the stream coordinates and valid signal.`);
        return { cycles: advanced, boundaryComplete, halted: this.halted };
    }
    snapshot(cycles = 0): SimulationResult {
        const frames: SimulationFramebuffer[] = [];
        const fb = this.framebuffer;
        if (fb) {
            if (this.stream) frames.push({ width: fb.width, height: fb.height, signal: fb.signal, rgb: Uint32Array.from(this.raster.pixels), valid: Uint32Array.from(this.raster.valid) });
            else if (this.nativeDisplay) {
                const binary = fb.valueMode === 'binary';
                const frame: any = unwrap(simulator_frame_with_layout(this.machine, this.hidden, fb.width, fb.height, this.packedDisplayRows, binary));
                const words = Uint32Array.from(frame.words);
                if (fb.valueMode === 'gray') for (let i = 0; i < words.length; i++) words[i] = (words[i] & 255) * 0x010101;
                frames.push({ width: fb.width, height: fb.height, signal: fb.signal, ...(binary ? { packed: words } : { rgb: words }), valid: Uint32Array.from(frame.valid), onColor: fb.onColor, offColor: fb.offColor });
            } else {
                const frame = simulationFramebuffer(outputValues(simulator_output_signals(this.machine) as SimulationSignal[]), fb);
                if (frame) frames.push(frame);
            }
        }
        const normalizeEvent = (event: any): SimulationEvent => ({
            kind: event.kind,
            message: event.text,
            text: event.text,
            cycle: event.cycle,
            instancePath: event.instance_path,
            ...(event.source?.$tag === 1 ? { source: event.source._0 } : {}),
        });
        const events = (simulator_drain_events(this.machine) as any[]).map(normalizeEvent);
        const messages = events.map(event => event.text);
        const rawStatus: any = simulator_status(this.machine);
        const exitCodes = simulator_exit_codes(this.machine) as number[];
        if (!this.firstFailure) this.firstFailure = events.find(event => event.kind === 'assert_failure' || event.kind === 'assert_unknown');
        const firstFailure = this.firstFailure;
        const status: SimulationStatus = {
            halted: rawStatus.halted,
            failed: rawStatus.failed,
            ...(exitCodes.length ? { exit_code: exitCodes[0] } : {}),
            ...(firstFailure ? { first_failure: firstFailure } : {}),
        };
        const unknown = frames.reduce((n, frame) => n + (frame.valid?.filter(word => word === 0).length ?? 0), 0);
        if (unknown) messages.push(this.stream ? 'Uncaptured or unknown pixels are shown in magenta.' : 'Display contains unknown values (magenta). Check reset and initialization.');
        return { outputs: simulator_visible_outputs(this.machine, this.hidden) as SimulationSignal[], inputs: simulator_inputs(this.machine) as SimulationSignal[], messages, events, status, cycles, halted: status.halted, clock: this.clock, metadata: this.metadata, framebuffers: frames };
    }
}

let batchSession: { key: string; session: SimulationSession } | undefined;
export function compile(request: CompileRequest): CompileResult {
    const started = performance.now();
    const sources: Record<string, string> = {};
    try {
        if (request.simulate) {
            const action = request.simulate.action ?? 'run';
            const { action: _action, inputs: _inputs, cycles: _cycles, captureFrames: _captureFrames, cyclesPerFrame: _cyclesPerFrame, ...identity } = request.simulate;
            const key = JSON.stringify([request.path, request.source, request.files, identity]);
            if (action === 'run' || batchSession?.key !== key) batchSession = { key, session: new SimulationSession(request) };
            const session = batchSession!.session;
            if (action === 'reset') session.reset();
            if (request.simulate.inputs) session.setInputs(request.simulate.inputs);
            const cyclesPerFrame = request.simulate.cyclesPerFrame ?? session.metadata.cyclesPerFrame ?? 1;
            if (!Number.isSafeInteger(cyclesPerFrame) || cyclesPerFrame < 1 || cyclesPerFrame > 100000) throw new Error('cyclesPerFrame must be an integer between 1 and 100000.');
            let cycles = 0;
            if (action === 'step_cycle') cycles = session.advanceCycles(1).cycles;
            if (action === 'step_frame') cycles = (session.stream ? session.advanceFrame() : session.advanceCycles(cyclesPerFrame)).cycles;
            if (action === 'run' && session.stream) cycles = session.advanceFrame().cycles;
            const simulation = session.snapshot(cycles);
            if (action === 'run') {
                if (session.framebuffer) {
                    const frames = request.simulate.captureFrames ?? 1;
                    if (!Number.isSafeInteger(frames) || frames < 1 || frames > 600) throw new Error("captureFrames must be an integer between 1 and 600.");
                    for (let i = 1; i < frames; i++) {
                        if (session.clock) cycles += (session.stream ? session.advanceFrame() : session.advanceCycles(cyclesPerFrame)).cycles;
                        const snapshot = session.snapshot();
                        simulation.framebuffers!.push(...snapshot.framebuffers!);
                        simulation.outputs = snapshot.outputs;
                        simulation.inputs = snapshot.inputs;
                        simulation.messages.push(...snapshot.messages);
                        simulation.events.push(...snapshot.events);
                        simulation.status = snapshot.status;
                    }
                } else if (session.clock) {
                    cycles += session.advanceCycles(Math.max(0, Math.min(100000, request.simulate.cycles ?? 1))).cycles;
                    return { id: request.id, duration: performance.now() - started, sources: session.sources, simulation: session.snapshot(cycles) };
                }
            }
            simulation.cycles = cycles;
            simulation.halted = session.halted;
            simulation.status.halted = session.halted;
            return { id: request.id, duration: performance.now() - started, sources: session.sources, simulation };
        }
        const fs = createInMemoryFileSystem({ ...request.files, [request.path]: request.source }, (path, source) => { sources[path] = source; });
        let output = '';
        unwrap(yodl.run(request.path, unwrap(yodl.parse_commands(request.stage)), { ...ext, fs, println: (text: string) => { output += text; } }));
        return { id: request.id, output, sources, duration: performance.now() - started };
    } catch (error) {
        return { id: request.id, sources, error: simulationError(error), duration: performance.now() - started };
    }
}

export function simulationError(error: unknown): string {
    let value: any = error instanceof Error ? error.message : error;
    if (typeof value === 'string') { try { value = JSON.parse(value); } catch { /* Plain text. */ } }
    return String(typeof value === 'string' ? value : value?._0 ?? value?.message ?? value);
}

# Simulation

Yodl's simulator executes the normalized, typed FIRRTL produced by the
compiler. It is intended for deterministic testbenches and for interactive
playground tools; it does not model gate delays or analogue timing.

The low-level API accepts a compiled FIRRTL module:

```moonbit
let sim = @simulator.Simulator::from_circuit(circuit, "Top")
sim.poke("rst", @simulator.SimValue::from_int(1, 1))
sim.step_clock("clk")
let value = sim.peek("counter")
```

For procedural tests, wrap it in a testbench. `step` performs a rising and
falling edge, while `run` repeats that operation and tracks the cycle count.

```moonbit
let tb = sim.testbench()
tb.poke("rst", @simulator.SimValue::from_int(1, 1))
tb.run("clk", 2)
tb.expect("done", @simulator.SimValue::from_int(1, 1))
```

Values are arbitrary-width packed integers. A value can be marked unknown with
`SimValue::new(..., known=false)`; unreset registers and uninitialised memory
locations start unknown. This prevents a test from accidentally relying on an
implicit zero initialisation.

The simulator settles combinational connections between clock events, commits
registers and synchronous memories together on a rising edge, and executes
clocked `printf!`, `assert!`, and `stop!` commands. A combinational loop or an
external module without a registered simulation model is reported as an error.

For long-running tests, the evaluator compiles typed FIRRTL into a small
SimIR worklist. Only statements affected by a changed input, register, memory,
or child output are revisited, and machine-word primitive operations avoid
allocating arbitrary-precision temporaries for the common narrow-control paths.
The resulting cycle/settle API is deterministic while remaining suitable for a
future bytecode backend.

Transition tracing is opt-in, so normal simulation remains fast:

```moonbit
sim.enable_waveform(signals=["valid", "ready"])
sim.step_clock("clk")
for sample in sim.waveform() {
  println("{sample.cycle()}: {sample.signal()} = {sample.value()}")
}
```

External FIRRTL modules can be supplied by a host model. The model receives its
input values and returns output values in declared port order:

```moonbit
let models : Map[String, @simulator.PrimitiveModel] = Map([])
models["TimerIP"] = {
  evaluate: (_) => [@simulator.SimValue::from_int(1, 1)],
}
let sim = @simulator.Simulator::from_circuit_with_models(circuit, "Top", models)
```

Graphical and text-producing designs can expose semantic output protocols to a
simulation host. `Framebuffer` stores RGB pixels for a browser canvas, and
`TextSink` collects byte-oriented output. A hardware wrapper can connect those
same logical signals to a physical display or serial link when targeting an
FPGA, but the simulation top does not need those timing signals.

The playground uses this separation for the Game of Life example: `GameOfLifeSim`
loads its 30×40 vector register in one cycle, advances one generation per
clock, and returns the aggregate state as a framebuffer.

A simulation display can be a logical array or a pixel stream. The compiler
binds displays to typed outputs; signal names do not need a special prefix.
A sole two-dimensional unsigned output is detected automatically. Use
`display: { buffer: "name" }` to choose between multiple arrays.

```yodl id=ex-simulation-annotation
@simulation({ display: { buffer: "pixel" }, reset: "rst" })
module VisualSim(clk: clock, rst: bool) -> (pixel: [30][40]bool) {
    for row in 0..<30 {
        for col in 0..<40 {
            pixel[row][col] = rst
        }
    }
}
```

The attribute selects the module it is attached to. A sole clock is inferred;
multiple clocks require an explicit `"clock": "name"`. `reset: "rst"` asserts
that one-bit input for one cycle, then deasserts it. Use
`reset: { signal: "rst", cycles: 2 }` when more reset cycles are needed.
Reset signals must actually initialize the design's registers: declaring a
reset sequence alone does not initialize unconnected registers.

For `[height][width]bool`, dimensions and monochrome mode come from the type.
The simulation lowering keeps each boolean row as a packed value, combines
its bit writes, and uses bit slices for reads. Registers and connections
execute on those packed rows. The host reads them directly as `Uint32Array`
words with `ceil(width / 32)` words per row; trailing bits are padding.
The worker transfers those buffers with validity information instead of
exporting one decimal string per pixel. Validity is conservative at the row
level: if any bit is unknown, the row can be shown as unknown.

Other unsigned element types default to RGB integers (`0xRRGGBB`). Use
`display: { buffer: "image", mode: "gray" }` for grayscale or set `on_color`
and `off_color` for monochrome colors. Mode never depends on the current
pixel values, so an initially black RGB image remains an RGB image.
The panel shows unknown values in magenta and reports an initialization hint.
Zoom is a canvas setting and does not change the circuit or framebuffer shape.

`Noise.yodl` exposes an 80×60 logical RGB framebuffer with
`@simulation({ display: { buffer: "pixel" }, reset: "rst" })`. Each pixel consumes a
successive LFSR state in row-major order. One clock edge advances the seed by
one complete frame, so adjacent frames continue the sequence without
reusing overlapping samples. The example has no scan counters or VGA signals;
canvas zoom controls its displayed size.

Designs that already produce timed pixels can instead use a pixel stream:


```text
@simulation({
    display: { stream: "video", width: 640, height: 480 },
    reset: "rst",
})
```

The `video` output is a named tuple with unsigned `x` and `y` coordinates,
a boolean `valid`, and unsigned `r`, `g`, and `b` channels of one to eight
bits. The host samples a valid pixel before each rising edge. A return to
valid coordinate `(0, 0)` marks the next frame; blanking cycles still execute
but do not paint pixels. Dimensions describe the active image, so blanking
and counter widths need not match them. Pixels not yet captured are shown in
magenta.

The panel uses one persistent worker session for Run, Pause, Resume, input
edits, and manual steps. Changing an input settles the circuit and refreshes
the canvas. Reset creates a fresh machine from the already compiled design.
Stop releases the session; the next Run compiles a new one. Source edits also
stop the session. Scalar signals and messages appear below the display.

Source tabs load imported files and their dependencies automatically when you
open or edit a design, independently of automatic compilation. Imports open read-only, with their full path in
the editor header. The Main file remains the target for compilation, simulation,
drafts, and sharing while you browse. Save downloads the file you are viewing.

Step cycle advances one clock. For arrays, Step frame advances
`cycles_per_frame` (default one). Declare it only when a complete frame needs
multiple cycles; it must be a positive integer. For streams, Step frame runs
until the next frame boundary. Execution is divided into bounded chunks so
Pause can interrupt a long frame step.

`clock_hz` sets the target simulation speed. Without it, clocked array and
scalar designs default to 30 cycles per second; pixel streams run as fast as
possible. The UI's **Refresh FPS** setting independently limits canvas updates
(default 30). It never sets the clock speed or the number of cycles advanced
by Step frame. The UI reports achieved cycles per second and simulated time
when a target frequency is configured. Resolved defaults appear in Advanced
settings. Timing changes apply on Resume or the next manual step; top/clock
changes require Stop.

Capture length and canvas refresh are run options, not circuit annotations.
The batch API accepts `captureFrames` (default one) and optional
`cyclesPerFrame`; realtime playback accepts `refreshFps`. A clockless design
settles and displays its image without any timing configuration. For example,
ImageSim needs only `@simulation({ display: { buffer: "pixel" } })`.

Every framebuffer annotation uses the same `display` object. Logical arrays
need only `buffer`; colors and grayscale mode are optional fields in that
object. Designs that expose explicitly packed words use that same object with
`width`, `height`, and `packing`, for example:

```text
display: {
    buffer: "pixel",
    width: 400,
    height: 300,
    mode: "binary",
    packing: "bits32",
    on_color: 8116210,
    off_color: 1056800,
}
```

`bits` and `bits32` store 8 and 32 horizontal monochrome pixels per word;
`rgb332x4` stores four RGB332 pixels per word. `pixel_scale` expands each
packed pixel into a square block when decoding. Prefer logical arrays for
new hardware: execution and transfer packing then remain internal.
Batch capture is available through the compiler API for deterministic tests
and snapshot generation.

## JavaScript and WebAssembly hosts

The browser playground currently uses MoonBit's JavaScript target. This keeps
the compiler and simulator directly importable as ES modules and makes the
existing object/array API inexpensive to call from a worker. MoonBit also
produces both classic WASM and `wasm-gc` artifacts, but a library package's
`.wasm` file is not by itself a browser API: the host still needs an exported
entry point, memory/string marshalling, and a stable ABI for compile, poke,
step, and framebuffer reads.

WASM is attractive for long, arithmetic-heavy runs because the hot loop avoids
JavaScript's dynamic dispatch and garbage collector. In this simulator the
compiler/elaboration pass and display rendering are also
significant costs, so repeatedly crossing a JS/WASM boundary for individual
signals can erase that gain. A practical WASM backend should therefore batch
work (`compile` or load a serialized SimIR once, `step N`, then copy one packed
framebuffer) and keep the worker session in WASM. That can improve sustained
playback and leave short interactive steps roughly unchanged; startup,
serialization, and browser support for `wasm-gc` still make JavaScript the
better default today. The recommended path is to keep the current JS backend,
add a batched WASM worker behind the same `SimulationRequest` protocol, and
choose it only after measuring representative designs such as GameOfLife, Image,
and Noise.

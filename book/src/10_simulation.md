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

External FIRRTL modules can be supplied by a host model. The model is called
after input propagation and can use `peek`/`poke` on the primitive's ports:

```moonbit
let models : Map[String, @simulator.PrimitiveModel] = Map([])
models["TimerIP"] = {
  eval: fn(ip) { ip.poke("done", @simulator.SimValue::from_int(1, 1)) },
}
let sim = @simulator.Simulator::from_circuit_with_models(circuit, "Top", models)
```

Graphical and text-producing designs can expose semantic output protocols to a
simulation host. `Framebuffer` stores RGB pixels for a browser canvas, and
`TextSink` collects byte-oriented output. Hardware wrappers can connect those
same logical signals to VGA or UART timing when targeting an FPGA.

The playground uses this separation for the Game of Life example: `LifeSim`
loads its 30×40 vector register in one cycle, advances one generation per
clock, and returns the aggregate state as a framebuffer. The FPGA-oriented
`TopSim` remains available when VGA timing itself is what you want to inspect.

Framebuffer output is a host protocol, not a VGA requirement. Any simulation
top can expose a two-dimensional output such as `pixel: [height][width]bool`
or `pixel: [height][width]u8`; the playground detects flattened
`pixel_row_col` ports and renders them automatically (binary pixels, grayscale
values, and RGB values are supported). Scalar ports and `printf!` messages are
shown as text below the canvas, so small circuits can be explored without a
display adapter. The visual examples include compact `*Sim` tops for this
protocol while keeping their VGA-oriented FPGA tops unchanged.

Simulation tops may declare their host-facing defaults with the `simulation`
module attribute. The compiler accepts the dictionary and leaves it out of
hardware output; playgrounds and testbenches can interpret it as follows:

```yodl id=ex-simulation-annotation
@simulation({
    "clock": "clk",
    framebuffer: {
        width: 40,
        height: 30,
        state_prefix: "pixel",
        mode: "binary",
        on_color: 16777215,
        off_color: 0,
    },
    init_signal: "rst",
    init_cycles: 1,
    frame_cycles: 1,
    clock_hz: 60,
    frame_rate: 30,
})
module VisualSim(clk: clock, rst: bool) -> (pixel: [30][40]bool) {
    for row in 0..<30 {
        for col in 0..<40 {
            pixel[row][col] = rst
        }
    }
}
```

`width`, `height`, and `state_prefix` describe the flattened output names;
`mode` can be `binary`, `gray`, or `rgb`. `clock_hz` is the simulated design
clock and `frame_rate` is the preferred display cadence, so a host can derive
`frame_cycles` when it is omitted. The playground exposes these values as
defaults in its Options panel. Width, height, frame count, clock frequency,
display rate, top, clock, and input values can be overridden per run. A design
that has no framebuffer metadata still works with scalar outputs and textual
messages, and a matrix output can be inferred from its `prefix_row_col` port
names.

The simulation panel keeps one worker-side machine alive for manual
interaction. `Reset` creates a fresh machine, `Step cycle` advances one clock,
and `Step frame` advances the configured number of cycles per frame. `Run`
captures the initial state before advancing, which makes reset-time patterns
visible and avoids dropping the first frame.

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
compiler/elaboration pass and the large flattened framebuffer are also
significant costs, so repeatedly crossing a JS/WASM boundary for individual
signals can erase that gain. A practical WASM backend should therefore batch
work (`compile` or load a serialized SimIR once, `step N`, then copy one packed
framebuffer) and keep the worker session in WASM. That can improve sustained
playback and leave short interactive steps roughly unchanged; startup,
serialization, and browser support for `wasm-gc` still make JavaScript the
better default today. The recommended path is to keep the current JS backend,
add a batched WASM worker behind the same `SimulationRequest` protocol, and
choose it only after measuring representative designs such as Life, Image,
and Noise.

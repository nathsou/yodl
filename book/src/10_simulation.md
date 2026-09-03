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

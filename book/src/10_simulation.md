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

Graphical and text-producing designs can expose semantic output protocols to a
simulation host. `Framebuffer` stores RGB pixels for a browser canvas, and
`TextSink` collects byte-oriented output. Hardware wrappers can connect those
same logical signals to VGA or UART timing when targeting an FPGA.

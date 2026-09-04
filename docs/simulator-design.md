# Simulator execution contract

This document records the compiler/runtime contract of the Yodl simulator.
It is an implementation design note; user-facing simulation instructions live
in `book/src/10_simulation.md`.

## Values and initialization

- Inputs default to known zero.
- Registers and memory words begin unknown unless reset or written.
- Knownness is tracked per bit. Bits whose validity is clear have canonical
  zero backing data, so unknown backing data cannot create transitions or make
  semantically equivalent values compare differently.
- Packed and unpacked representations have the same observable values and
  knownness. A packed two-bit shift register therefore becomes partly known
  after its first initialized sample and fully known after its second.

## Combinational and sequential execution

- `poke` changes an input value.
- `settle` evaluates combinational logic to a stable result and applies
  asynchronous resets. It does not advance a cycle.
- A rising edge samples register inputs, memory-port controls, and clocked
  commands from one settled pre-edge state.
- Sampled state updates become visible atomically, after which combinational
  logic settles again. One requested rising edge advances exactly one cycle.
- A `stop!` completes the edge that triggered it. Its committed state and
  post-edge combinational outputs remain observable.
- Derived clocks are not executable simulation clocks and are rejected during
  simulation-design preparation. Runtime `printf!`, `assert!`, and `stop!`
  require an actual module clock. Unsupported memory latency combinations are
  rejected during preparation rather than approximated at runtime.

## Outcomes and frames

- Assertion failure is persistent and separate from halting. Hosts can observe
  failure kind, first failure, cycle, hierarchy, and source location without
  parsing printed text.
- Stop status preserves its exit code; successful stop, nonzero stop, and
  assertion failure are distinct outcomes.
- Array frame stepping advances the configured cycle interval. Stream frame
  stepping advances through a completed stream boundary within a bounded
  budget and reports the actual number of cycles advanced.
- Batch stream capture completes the first frame before exposing its first
  image. Batch and realtime paths use the same advancement operations.
- Packed framebuffer validity is exported per pixel bit, so unknown data only
  affects the corresponding pixels.

The regression suite covers packed shift-register initialization, first stream
frame capture, clockless runtime commands, assertion/stop outcomes, stream
signal-name collisions, and decimal clock rendering. Each fixture asserts both
value/knownness and the number of cycles advanced where cycles are involved.

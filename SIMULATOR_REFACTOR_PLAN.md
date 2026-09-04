# Simulator architecture refactor plan

This plan replaces the simulator's permissive FIRRTL interpreter with a small
runtime for a validated simulation program. It covers the findings from the
three review rounds, preserves the playground and native testbench use cases,
and defines checkpoints where each migration step can be reviewed or reverted.

The central invariant is:

> Construction either produces a complete, immutable `SimulationProgram`, or
> returns a diagnostic. The runtime never repairs, discovers, or guesses the
> meaning of that program.

The target data flow is:

```text
Typed FIRRTL circuit
    -> normalize ordered FIRRTL semantics
    -> validate the supported simulation subset
    -> flatten names, hierarchy, types, and clock domains
    -> compile expressions and state components
    -> immutable SimulationProgram
    -> mutable SimulationState
```

The refactor deliberately keeps whole-value known/unknown tracking. Per-bit
four-state arithmetic is outside this work. Memory masks still operate by lane,
but an uncertain value can conservatively make the affected word unknown.

## 1. Freeze semantics and establish a baseline

Before replacing runtime code, make the intended behavior executable as tests.
Keep the existing review reproductions and add focused cases for every semantic
boundary below.

| Area | Required cases |
| --- | --- |
| Arithmetic | signed unequal-width equality and bitwise operations; signed dynamic left shift; fast and arbitrary-width paths; divide/remainder by zero |
| Assignment | ordered default plus conditional assignment; nested aggregate widening; missing driver diagnostic |
| Registers | normal sampling; simultaneous tied clocks; synchronous and asynchronous known reset; unknown reset with agreeing and disagreeing alternatives |
| Memories | aggregate data; known/unknown address and enable; zero mask; disjoint masks; colliding masks; every read-under-write mode; read/write ports |
| Hierarchy | nested module data flow; parent and child registers on one edge; direct clock aliases; rejected derived clocks |
| External models | zero-input model; initial evaluation with zero-valued inputs; width/output contract failures |
| Commands | printf and assert formats `%b`, `%c`, `%d`, `%x`, `%%`; unknown values; stop completing its triggering edge |
| Observation | wide values; Boolean rows across 32-bit boundaries; integer pixels in binary and RGB modes; validity; waveform ordering |
| Unsupported input | memory file annotation; unsupported memory latency; combinational cycle; unknown external module |

Add differential arithmetic tests that compare simulator results with the
ordinary FIRRTL/firtool path. The permanent test can use a compact fixed vector
set; retain the exhaustive local harness as a review aid. Add at least one
heterogeneous bundle memory case because equal-width array elements do not catch
offset errors.

Record performance before changing scheduling. Use `GameOfLife.yodl`, `Image.yodl`,
and `Noise.yodl` with fixed compile, settle, and cycle counts. Record elapsed
time, allocations when available, and frame correctness. Performance results
are evidence for later optimization; they do not override semantics.

Do not update expected outputs to match current simulator defects. Where FIRRTL
behavior is unclear, compare against the pinned firtool version and document the
chosen conservative unknown behavior.

Checkpoint: all current tests pass, each known defect has a failing regression
test or an explicit unsupported-behavior test, and baseline timings are saved in
the PR description or a small checked-in benchmark note.

## 2. Introduce the immutable program and mutable state

Split the current `Simulator` data into an immutable description and mutable
execution data. Keep these types private until their shape stabilizes.

```moonbit
priv struct SimulationProgram {
  signals: Array[SignalSpec]
  names: Map[String, SignalId]
  inputs: Array[SignalId]
  outputs: Array[SignalId]
  clocks: Array[ClockSpec]
  combinational: Array[EvalNode]
  registers: Array[RegisterSpec]
  memories: Array[MemorySpec]
  commands: Array[CommandSpec]
  models: Array[ModelSpec]
  displays: Array[DisplaySpec]
}

priv struct SimulationState {
  inputs: Array[SimValue]
  values: Array[SimValue]
  register_storage: Array[SimValue]
  memory_storage: Array[Array[SimValue]]
  clock_levels: Array[Bool]
  messages: Array[SimMessage]
  cycle: Int
  halted: Bool
  failure: String?
}
```

Keep externally driven input storage separate from the last successfully
settled values. A settle builds a working value array from inputs and persistent
state, evaluates it, and publishes it only on success. An edge similarly builds
candidate register and memory state, evaluates the candidate post-edge graph,
then swaps the complete candidate into the simulator. This copy-first design is
the initial correctness implementation. Copy-on-write memory pages can replace
whole-memory copies later if profiling shows a cost, without changing the
transaction protocol.

Use small integer IDs (`SignalId`, `MemoryId`, `ClockDomainId`) everywhere in
the engine. Names remain in metadata for `poke`, `peek`, diagnostics, waveform
selection, and host output. Runtime evaluation must not parse dotted names or
look up signal meaning in a `Map`.

Define signal initialization explicitly:

- Data inputs start at known zero to preserve the current host behavior.
- Clock inputs start low.
- Nodes, wires, and outputs begin unknown until the initial settle evaluates
  their driver.
- Register storage and memory cells begin unknown unless supported explicit
  initialization says otherwise.
- Constants live in expression bytecode and need no signal slot.

Make the public `Simulator` hold a program and state. Remove `pub(all)` from
engine internals. Public mutation remains available only through documented
methods. This prevents external code from depending on temporary maps,
hierarchical child simulators, or register caches.

Checkpoint: the new types exist behind the old API, basic combinational and
register tests run using array-backed state, and no browser API changes are
required yet.

Use a file split that follows responsibilities rather than FIRRTL statement
classes:

| File | Responsibility |
| --- | --- |
| `program.mbt` | private IDs, immutable specs, signal/name/layout metadata |
| `compile.mbt` | top selection, preparation orchestration, hierarchy flattening, validation |
| `expression.mbt` | explicit expression construction and the operation table |
| `graph.mbt` | dependencies, cycle diagnostics, topological order, graph evaluation |
| `engine.mbt` | public simulator methods, state publication, settle and edge transactions |
| `memory.mbt` | request sampling and memory conflict/read-under-write resolution |
| `model.mbt` | external model registry, binding, validation, graph execution |
| `command.mbt` | sampled events and shared format rendering |
| `observe.mbt` | names, signals, waveforms, displays, raster capture |

MoonBit package files share package-private definitions, so this split need not
make implementation types public. Keep `simulator.mbt` temporarily as the API
facade, then shrink or remove it as code moves.

## 3. Create one preparation entry point

Create a single compiler in the simulator package:

```moonbit
pub fn compile_program(
  circuit: @firrtl.TypedCircuit,
  top: String,
  displays: Array[DisplayRequest],
) -> SimulationProgram raise SimulationCompileError
```

The program records the signatures and graph positions of required external
models, but it contains no host callbacks. `Simulator::from_program` receives a
`ModelRegistry`, validates it against those signatures, and stores the callbacks
as runtime bindings. This lets the driver compile and cache one program while
different native hosts provide models without rerunning FIRRTL preparation.

The FIRRTL package should continue to own general FIRRTL transformations.
Simulator-specific validation, layout metadata, clock resolution, and program
construction belong in the simulator package. Avoid adding a general FIRRTL
pass whose output can still be mistaken for arbitrary typed FIRRTL.

The preparation sequence is fixed:

1. Select the top module unambiguously.
2. Expand aggregate connects.
3. Expand whens and last-connect semantics.
4. Flatten aggregate memories while preserving an explicit leaf-to-bit layout.
5. Lower aggregate values to ground or deliberately packed values.
6. Flatten the selected hierarchy into program-level signal identities.
7. Normalize widths and signed conversions.
8. Resolve clock domains, state components, commands, models, and displays.
9. Build and validate the combinational graph.
10. Emit the immutable program.

The sequence is invoked exactly once on each construction path. The Yodl
driver should return a prepared simulation program consumed by
`Simulator::from_program(program, models)`. The native convenience constructors
can accept raw typed FIRRTL, call `compile_program` once, and then bind models.

Prefer a deliberate API change over a hidden “already normalized” heuristic.
Change `compile_simulation` and `SimulationDesign.circuit` to expose a
`PreparedSimulation` value, then migrate their callers together on this branch.
If callers still need the lowered FIRRTL for debugging, expose it through a
read-only `lowered_circuit()` method; do not feed that method back into normal
simulator construction.

Delete the partially introduced `prepare_simulation` FIRRTL helper after this
entry point owns the pipeline. Fix the general `FlattenMemoriesPass` bundle
offset and mask-width bugs independently, with FIRRTL pass tests, because other
backends also use that pass.

Checkpoint: driver and native construction share one entry point; preparation
is never repeated in the production path; a malformed program cannot reach the
engine.

## 4. Define and enforce the supported subset

Validation should return precise construction diagnostics. It must run before
allocating mutable state or invoking an external model.

Accept:

- Ground unsigned, signed, clock, reset, and async-reset values after lowering.
- Deliberately packed Boolean rows represented as unsigned values with layout
  metadata.
- The primitive operations already emitted by Yodl after explicit width
  normalization.
- Registers with supported synchronous or asynchronous reset expressions.
- Memories with read latency zero or one and write latency one.
- Direct top-level input clocks and aliases made only of reference nodes or
  connects.
- Hierarchical modules that can be flattened and declared external models with
  matching signatures.

Reject:

- Remaining aggregate references, `When` statements, dynamic references, or
  multiple combinational drivers.
- Unresolved references and incomplete output/wire initialization.
- Combinational cycles, with a diagnostic showing at least one cycle path.
- Derived or gated clocks, including a register output cast to clock.
- Unsupported memory latency and malformed mask granularity.
- Memory file annotations until an explicit host filesystem contract exists.
- External modules without models and models whose port contract cannot be
  bound.
- Display requests whose logical layout cannot be resolved.

Do not keep `SimStmt::Other`. Every statement must compile to a supported
program component or produce a diagnostic. Do not turn a missing signal into an
unknown value. Unknown is valid runtime data; a missing signal is invalid input.

Give compile errors structured variants with context such as module path,
statement/reference, and reason. Convert them to the existing host error string
at the JS boundary.

Validate deterministic ordering as well as structural correctness. Preserve
module-body order for commands and ports, assign IDs in a declared traversal
order, and never use `Map` iteration order to decide evaluation, collision,
message, or waveform order.

Checkpoint: all rejection tests fail during construction, before the first
`poke`, `settle`, or `step_clock`.

## 5. Flatten hierarchy and resolve clock domains

Flatten module instances while compiling the program. Allocate each instance a
path such as `top.child.grandchild` for metadata, then allocate globally unique
signal IDs. Instance input and output connections become ordinary expression
dependencies; there is no child `Simulator`.

Flatten in declaration-independent order by first building a module table and
then recursively instantiating the selected top. Detect recursive instantiation
with the active instance stack and report its path. Bind external modules at the
same point, using a model node instead of recursively entering a body.

Resolve every clock-valued state component to a `ClockDomainId` during this
walk. Follow only reference aliases. Two register clocks connected to the same
top input receive the same ID, including registers in different instances.
Commands and memory ports use the same IDs.

Add an atomic clock-driving primitive internally:

```moonbit
fn drive_clocks(levels: Array[(ClockDomainId, Bool)]) -> Unit raise
```

It settles the driven levels and performs one transaction for all low-to-high
domains. `set_clock(name, high)` and `step_clock(name)` are wrappers. This
ensures tied or intentionally simultaneous domains sample one pre-edge state.
Reject duplicate contradictory levels in one call.

Restrict public `poke` to data input ports. Clock inputs use clock methods.
Driving outputs, internal state, or model outputs through `poke` should fail.
Tests that need internal construction details should test the compiler or engine
inside the package rather than use public mutation as a back door.

Checkpoint: delete `children`, `child_message_offsets`, `primitive_model` on a
child simulator, `clock_source`, `find_signal_source` from the runtime, and all
recursive settle/commit methods.

## 6. Normalize expressions and keep one evaluator

Compile every data expression, reset/init expression, memory control, command
predicate, and command argument into one `EvalExpr` representation. A compact
tree is sufficient first; bytecode can be added later if profiling supports it.

Use explicit operations whose operands already have normalized widths:

```text
Signal(id)
Literal(value)
Slice(source, lo, width)
Concat(parts)
ZeroExtend(source, width)
SignExtend(source, width)
Unary(op, source, result_width)
Binary(op, lhs, rhs, result_width)
Mux(condition, yes, no, result_width)
AsyncMemoryRead(memory, address, enable)
ExternalModelOutput(model, output_index)
```

An external model is a single multi-output graph node. References to its
outputs depend on that node's cached result; they do not invoke the callback.
Likewise, a memory component can publish several read outputs from one sampled
transaction.

Lower FIRRTL `Pad`, result-based implicit widening, aggregate coercion, and
mixed-width signed operands to explicit extension nodes. Bitwise operations and
equality compare equally sized bit patterns after the correct extension. Signed
dynamic left shift extends the left operand to the result width before shifting.

Keep one `eval_expr` implementation. It may choose a fast machine-integer
helper when every input and output fits its proven safe range, but both paths
must implement one semantic operation table and share conformance tests. Use
the arbitrary-width implementation as the oracle.

Unknown behavior is centralized:

- Most operations return unknown if any required operand is unknown.
- A mux with unknown condition returns its common known arm if both arms agree;
  otherwise it returns unknown.
- Division and remainder by a known zero return unknown.
- Shifts use the unsigned raw shift amount; signedness affects the extended
  value and right-shift fill.
- Compare an arbitrary-width shift amount with the result width before
  converting it to `Int`. An oversized left shift is zero after normalization;
  an oversized arithmetic right shift is all sign bits. This avoids allocating
  an enormous intermediate or overflowing a host integer.
- Results are normalized to their declared width exactly once.

Remove the typed-FIRRTL `eval_expr`, compiled `eval_compiled_expr`, runtime
signedness inference, and connection-specific widening.

Checkpoint: the permanent differential arithmetic suite passes at narrow and
arbitrary widths, and all expression consumers use this evaluator.

## 7. Build a deterministic combinational graph

Give each driven combinational signal exactly one `EvalNode`. Derive graph edges
from compiled expression signal IDs, external model inputs, and asynchronous
memory-read controls. Topologically sort once during program construction.

Treat synchronous register storage and memory contents as graph roots. Treat
asynchronous register output as an evaluation node that selects between its
stored value and reset value. Include reset and init dependencies in the graph.
This catches asynchronous-reset feedback rather than incorrectly hiding it
behind a state boundary.

The first implementation should evaluate the complete topological order on
`settle`. This is easy to reason about and makes initialization identical to
later evaluation. It also ensures zero-input external models execute on the
first settle.

Asynchronous register outputs are staged during evaluation and committed after
the graph sweep. Require their combined dependency graph to be acyclic. With
that restriction, the topological sweep determines a stable reset result
without an ad hoc fixed-point loop. An unknown reset selects between reset and
stored values using the same mux rule.

Graph nodes may have one output (ordinary expression) or several outputs
(external model). Topological sorting operates on nodes, while signal IDs map
each dependency to its producing node. Reject two nodes that publish the same
signal. A node may read only inputs, state roots, constants, or outputs from
lower-ranked nodes.

After correctness is established, optionally add dirty evaluation:

- Generate reverse dependencies from the same immutable graph.
- Mark input, register, memory-read, and model-output changes dirty.
- Execute dirty nodes in topological rank order.
- Retain a debug/test mode that performs a full evaluation and compares the
  resulting observable values.

Do not introduce special dependency rules outside graph construction. If the
optimized evaluator cannot express a dependency, the program representation is
incomplete.

Checkpoint: delete `pending`, `queued`, the million-evaluation loop heuristic,
`order_simulation_body`, and runtime `When` evaluation. If dirty evaluation is
not yet justified by measurements, keep only the full graph sweep.

## 8. Make clock edges transactional

Implement each rising-edge set as one transaction:

1. Settle the pre-edge combinational graph.
2. Sample register next values and synchronous reset choices for all active
   clock domains.
3. Sample every active memory port into immutable requests.
4. Sample active command predicates and arguments into immutable command
   events.
5. Resolve memory read-under-write results and write collisions.
6. Commit registers, memory contents, synchronous read outputs, and status.
7. Publish command events in deterministic program order.
8. Settle the post-edge graph, even if a sampled stop event halted future
   stepping.

Never mutate state while sampling another component. If sampling or a model
evaluation raises an error, do not partially commit the edge. Evaluate the
post-edge combinational graph against candidate register and memory state and
publish the candidate only after it succeeds. This makes model errors and
formatting errors transactional as well as register and memory updates.

Synchronous reset uses the common selector semantics. A known asserted reset
selects init; a known deasserted reset selects next state; an unknown reset
returns a known value only if both alternatives are known and equal.

Commands sharing an edge are all sampled from the pre-edge state. A stop event
prevents later edges, while the current transaction and output settle complete.
Define assertion failure and stop precedence explicitly in tests rather than
depending on traversal side effects.

For side-effect controls, require a definite decision. A command whose enable
is unknown, or an enabled assertion whose predicate is unknown, returns a
runtime uncertainty error instead of silently firing or suppressing an event.
Unknown printf arguments remain printable as `x`. This policy confines
conservative four-state merging to data and reports uncertainty when no honest
event value exists.

Checkpoint: register, memory, hierarchy, reset, printf/assert, and stop tests all
exercise this one transaction implementation.

## 9. Isolate memory semantics

Represent memory ports structurally:

```moonbit
priv struct ReadPortSpec {
  clock: ClockDomainId?
  address: EvalExpr
  enable: EvalExpr
  output: SignalId
  latency: Int
}

priv struct WritePortSpec {
  clock: ClockDomainId
  address: EvalExpr
  enable: EvalExpr
  data: EvalExpr
  mask: EvalExpr
  lane_width: Int
}
```

Normalize read/write ports into equivalent read and write requests gated by
`wmode`. The memory engine should never inspect `.addr`, `.data`, `.wmode`, or
other names.

Sample all active requests first. Drop a write only when enable is known false
or mask is known zero. A known enabled write to a known in-range address
participates normally. An unknown enable, mask, mode, or address conservatively
affects every location and lane it could select. Out-of-range known addresses
follow the chosen FIRRTL behavior consistently and receive a test.

Resolve writes per location and mask lane. Disjoint known lanes combine.
Overlapping active writes make the overlapping result unknown; with whole-value
validity this conservatively makes the word unknown. A possible unknown-address
write can invalidate candidate cells but must not index storage using its raw
backing bits.

Compute synchronous read results from the pre-edge memory and the complete set
of sampled writes according to `Old`, `New`, or `Undefined`. A zero-mask write
does not count as a collision. Apply writes only after every read result has
been computed. Asynchronous reads are ordinary graph nodes and observe the
post-commit contents after the final settle.

Avoid scanning the full memory on every edge when all addresses are known.
Build a set of affected addresses from requests. Scan all cells only for an
unknown-address request; that cost directly represents the conservative effect
of the uncertain write.

Checkpoint: all memory behavior lives in a small memory module with table-driven
tests. The general engine knows only how to sample and commit its results.

## 10. Replace external model mutation with an explicit contract

Replace `PrimitiveModel.eval: (Simulator) -> Unit` with a callback that receives
only declared input values and returns declared output values. Bind ports to IDs
during compilation.

```moonbit
pub(all) struct PrimitiveModel {
  evaluate: (Array[SimValue]) -> Array[SimValue] raise SimulatorError
}
```

Order inputs and outputs by the extmodule declaration and expose their names in
the model registration metadata. Validate returned count and widths before
publishing any output. A failed model evaluation leaves previous stable state
unchanged and reports the model and port involved.

Model nodes belong in the combinational graph. A zero-input model therefore
runs during initial settle. A model whose output feeds its own input contributes
a graph cycle and is rejected. Document that combinational callbacks should be
deterministic and free of hidden state; stateful devices need an explicit
clocked-model interface in a later design rather than relying on call count.

Evaluate a model once per graph sweep and stage all of its outputs together.
Reject an output array with the wrong length, width, or an invalid value before
publishing any output. Since callbacks may still perform host side effects that
the engine cannot roll back, document the callback as pure and invoke it only
during graph evaluation, never during dependency discovery or validation.

Migrate the current tests and book example in the same change. Do not maintain a
long-lived compatibility adapter that grants a model arbitrary simulator access,
because that would preserve the scheduling ambiguity the refactor removes.

Checkpoint: external model scheduling needs no dirty flag, child simulator, or
special initial-call branch.

## 11. Compile commands and separate observation

Reuse `@firrtl.FormatString::parse` instead of implementing another parser.
During program construction, validate placeholder count against argument count
and compile parts into `FormatSpec`. Store whether decimal arguments are signed.

Use one formatter for printf and assert. Implement `%b`, `%c`, `%d`, `%x`, and
`%%`, including unknown values and width-derived padding consistent with the
existing FIRRTL/RTLIL formatter. Preserve literal whitespace exactly; do not
append extra arguments to a format string without placeholders. If legacy
Yodl examples use a bare string plus arguments, either update them to valid
placeholders or define that syntax in elaboration before format parsing.

Move waveforms and framebuffer conversion behind read-only observation APIs.
They consume stable state after settle and cannot enqueue work or change signal
values.

Each display has immutable storage metadata:

- logical element signal IDs in row-major order, or deliberately packed row IDs;
- logical width and height;
- element bit width;
- packed-row bit orientation;
- validity granularity.

Rendering mode is a host option applied after values are read. Binary mode maps
every integer element to off/on by testing the complete arbitrary-width value
for zero. It must not reinterpret an integer image as packed Boolean storage.
Only a layout marked `packed Boolean row` is decoded by bits. RGB and grayscale
also use the same logical element layout.

Checkpoint: display mode changes representation only at the rendering step, all
formatting tests pass, and the simulator core has no framebuffer-specific code.

## 12. Migrate public APIs and browser integration

Make API changes in one migration commit after the internal engine is usable.
The intended public surface is small:

```text
compile_program / Simulator::from_program
Simulator::from_circuit              convenience for native callers
poke / peek / settle
set_clock / step_clock / drive_clocks
messages / failure / halted / cycle
enable_waveform / waveform
read_display / output_signals / input_signals / clocks
```

Keep the JS export names used by `playground-compiler.ts` when their semantics
remain sound. Change framebuffer export arguments to accept a display binding or
layout ID rather than `ports + width + height + binary`. This removes the
storage/render ambiguity at the ABI boundary.

`compile_simulation_design` should return the prepared program artifact plus
display descriptors. The browser session constructs a machine directly from
that artifact. Reset constructs fresh mutable state from the same immutable
program; it does not rerun FIRRTL passes.

Update callers and tests in these locations as part of the API migration:

- `src/lib/driver/driver.mbt` for the prepared artifact and display metadata;
- `src/lib/tests/simulator_compile.mbt` for Yodl-to-runtime integration;
- `src/lib/simulator/*_test.mbt` for program, graph, engine, and memory units;
- `src/main/playground-compiler.ts` for construction and display reads;
- `src/docs/compiler-client.test.ts` and `simulation-worker.test.ts` for JS and
  worker protocol behavior;
- `book/src/10_simulation.md` for the supported contract and model API.

Update `pkg.generated.mbti` by running `moon info`; never hand-edit it. Update
the simulation book section to describe the execution phases, supported subset,
unknown-value precision, memory restrictions, model contract, and derived-clock
diagnostic.

Checkpoint: native testbenches, batch simulation, realtime worker, array
displays, pixel streams, pause/resume, step cycle, and reset all use the new API.

## 13. Remove the old architecture

Remove old code as soon as each replacement passes its checkpoint. The final
simulator must not retain dormant fallback paths.

Delete:

- `SimStmt::When` and `SimStmt::Other`;
- both old expression evaluators and runtime typed FIRRTL traversal;
- `signals: Map[String, SimValue]` from the hot path;
- `registers`, `next_registers`, and `memory_clocks` keyed by names;
- recursive child simulators and child message offsets;
- primitive dirty flags and simulator-mutating primitive callbacks;
- runtime clock alias searches;
- worklist ordering and its fixed evaluation limit;
- duplicated printf/assert formatting;
- framebuffer decoding based on render mode.

Run `rg` checks for these names during review. Reducing code is part of the
acceptance criteria: replacement code should not merely wrap the old engine.

Checkpoint: the simulator package has one construction path, one evaluator, one
settle path, one edge transaction, and one memory resolver.

## 14. Validation and acceptance gates

Run focused tests after each phase, followed by the full repository gates at
the integration checkpoints:

```sh
moon check
moon test src/lib/simulator
moon test src/lib/tests
moon test
moon info
bun test src/docs
bash scripts/test.sh
```

Review all generated interface changes. Review snapshots only when behavior is
intentionally changed. Because memory flattening and aggregate lowering feed
RTLIL too, inspect representative `write_low_firrtl`, `write_firrtl`, and
`write_rtlil` output and run backend examples.

Run the arithmetic differential harness against pinned firtool. Add a second
differential sequence for registers and memories where practical. Run the
browser worker tests through actual JS release builds, because native-only tests
do not verify the exported ABI or typed-array transfer behavior.

Compare final performance with the baseline. A simple full-graph implementation
is acceptable initially if interactive examples remain responsive. If a
representative sustained workload regresses by more than roughly 20%, profile
before optimizing. Add dirty evaluation only when evaluation work is the
measured bottleneck, and verify it against full evaluation.

The refactor is complete when:

- Every review finding has a passing regression or intentional construction
  error.
- The supported subset is documented and enforced before execution.
- No runtime operation discovers semantics from FIRRTL types or signal names.
- A rising edge samples one stable pre-edge state and commits atomically.
- Hierarchical modules and external models are nodes in one graph.
- Display and formatting code cannot affect execution.
- All repository gates pass under the pinned toolchain, or unavailable external
  validation is reported explicitly.

Review the final architecture against these proof obligations:

| Invariant | Evidence |
| --- | --- |
| Every read has one source | compiler rejects missing/multiple producers; graph test enumerates all operands |
| Settle is deterministic | immutable topological order; no semantic `Map` iteration; repeated-settle idempotence tests |
| An edge is atomic | candidate-state tests inject model failure and verify no register, memory, message, cycle, or waveform partial commit |
| All active domains see one snapshot | tied-clock parent/child and multi-domain cross-sampling tests |
| Width semantics are explicit | prepared-program inspection tests and firtool differential vectors |
| Memory mutation follows sampled requests | table-driven collision/mask/read-under-write tests |
| Unknown never substitutes for invalid structure | missing references fail construction; actual uninitialized state remains unknown |
| Presentation cannot alter execution | render one settled state in each mode and compare observables |
| Optimization preserves meaning | optional dirty evaluator compared with full evaluator after random input/edge traces |

## 15. Commit and review sequence

Keep the branch reviewable with dependency-ordered commits:

1. Add regression tests and baseline measurements without behavior changes.
2. Fix reusable FIRRTL aggregate-memory lowering defects with pass tests.
3. Add private program/state types and array-backed basic execution.
4. Add the single preparation/validation compiler and migrate construction.
5. Flatten hierarchy and resolve clock domains.
6. Add explicit expressions and the shared evaluator.
7. Add the graph evaluator and asynchronous reset nodes.
8. Add transactional clock edges and the isolated memory resolver.
9. Replace the external model API.
10. Compile command formats and split observation/display layout.
11. Migrate browser/native APIs and documentation; regenerate interfaces.
12. Delete old runtime paths, run all gates, and report benchmark results.

Do not mix broad mechanical deletion with a semantic change in the same commit.
Each commit should identify the old path it makes removable, and the next commit
should remove that path once its replacement is covered. If bisectability would
otherwise require two production engines, keep the new engine private until it
handles one complete vertical slice, then switch the public constructor in one
commit.

The current uncommitted fixes should be sorted before starting this sequence.
Retain tests and independent FIRRTL lowering corrections. Rework arithmetic,
memory, reset, model, and preparation fixes into their corresponding phases so
they do not become a second layer of patches around code scheduled for removal.

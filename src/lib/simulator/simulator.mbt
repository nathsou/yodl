/// A compact, deterministic simulator for a typed FIRRTL module.
///
/// This is intentionally a module-level runner.  The compiler-facing lowering
/// step can flatten a hierarchy into this form later; keeping the execution
/// semantics here independent from the compiler makes it useful for native
/// testbenches as well as the JavaScript playground.

using @firrtl {
  type TypedModule,
  type TypedCircuit,
  type TypedExpr,
  type TypedRef,
  type Type,
  type PrimOp,
}

pub(all) struct SimValue {
  width: Int
  raw: BigInt
  known_mask: BigInt
}

pub fn SimValue::new(width: Int, raw: BigInt, known~: Bool = true) -> SimValue {
  let known_mask = if known { mask(width) } else { 0 }
  SimValue::with_mask(width, raw, known_mask)
}

pub fn SimValue::with_mask(width: Int, raw: BigInt, known_mask: BigInt) -> SimValue {
  let known_mask = normalize(known_mask, width)
  { width, raw: normalize(raw, width) & known_mask, known_mask }
}

pub fn SimValue::zero(width: Int) -> SimValue {
  SimValue::new(width, 0)
}

pub fn SimValue::from_int(width: Int, value: Int) -> SimValue {
  SimValue::new(width, BigInt::from_int(value))
}

pub fn SimValue::as_bigint(self: SimValue) -> BigInt {
  self.raw
}

pub fn SimValue::is_known(self: SimValue) -> Bool {
  self.known_mask == mask(self.width)
}

pub fn SimValue::known_mask(self: SimValue) -> BigInt {
  self.known_mask
}

pub fn SimValue::bit(self: SimValue, index: Int) -> SimValue {
  if index < 0 || index >= self.width {
    SimValue::new(1, 0, known=false)
  } else {
    SimValue::with_mask(1, (self.raw >> index) & 1, (self.known_mask >> index) & 1)
  }
}

pub impl Show for SimValue with output(self, logger) {
  if self.is_known() {
    logger.write_string(self.raw.to_string())
  } else {
    logger.write_string("x")
  }
}

/// The execution form used by the simulator.  It is deliberately small and
/// backend-neutral: typed FIRRTL is compiled to this representation once when
/// a simulator is constructed, so the hot loop does not repeatedly inspect
/// type metadata or rebuild reference paths.
pub(all) enum SimExpr {
  Signal(name~: String, width~: Int)
  MemoryData(memory~: String, reader~: String, width~: Int)
  Slice(source~: SimExpr, index~: Int, width~: Int)
  Literal(value~: SimValue)
  Mux(cond~: SimExpr, tval~: SimExpr, fval~: SimExpr)
  Prim(op~: PrimOp, args~: Array[SimExpr], width~: Int, signed~: Bool)
}

pub(all) enum SimStmt {
  Node(name~: String, expr~: SimExpr)
  Connect(name~: String, expr~: SimExpr)
  Other
}

pub enum SimFormatPart {
  Text(String)
  Binary
  Character
  Decimal
  Hexadecimal
}

pub enum SimCommandAction {
  Printf(parts~: Array[SimFormatPart], args~: Array[(SimExpr, Bool)])
  Assert(pred~: SimExpr, parts~: Array[SimFormatPart], args~: Array[(SimExpr, Bool)])
  Stop(code~: Int)
}

pub struct SimCommand {
  clock: String
  enable: SimExpr
  action: SimCommandAction
}

/// A host-provided implementation for an external FIRRTL module. Inputs and
/// outputs follow the ExtModule port declaration order, filtered by direction.
/// Models are combinational: they must return one value for every output.
pub(all) struct PrimitiveModel {
  evaluate: (Array[SimValue]) -> Array[SimValue] raise SimulatorError
}

suberror SimulatorError {
  InvalidWidth(width~: Int)
  MissingSignal(name~: String)
  Unsupported(message~: String)
  CombinationalLoop(message~: String)
  ExpectationFailed(name~: String, expected~: String, actual~: String)
} derive(Debug)

pub(all) struct SimMessage {
  kind: String
  text: String
  cycle: Int
  instance_path: String
  source: String?
}

pub fn SimMessage::kind(self: SimMessage) -> String { self.kind }

pub fn SimMessage::text(self: SimMessage) -> String { self.text }

pub fn SimMessage::cycle(self: SimMessage) -> Int { self.cycle }

pub fn SimMessage::instance_path(self: SimMessage) -> String { self.instance_path }

pub fn SimMessage::source(self: SimMessage) -> String? { self.source }

pub(all) struct SimulationStatus {
  halted: Bool
  exit_code: Int?
  failed: Bool
  first_failure: SimMessage?
}

pub(all) struct WaveSample {
  cycle: Int
  signal: String
  value: SimValue
}

pub fn WaveSample::cycle(self: WaveSample) -> Int { self.cycle }

pub fn WaveSample::signal(self: WaveSample) -> String { self.signal }

pub fn WaveSample::value(self: WaveSample) -> SimValue { self.value }

pub(all) struct Waveform {
  samples: Array[WaveSample]
}

pub(all) struct RegisterState {
  name: String
  width: Int
  clock: String
  reset: SimExpr?
  init: SimExpr?
  async_reset: Bool
  previous_clock: Bool
}

struct MemoryState {
  width: Int
  depth: Int
  read_latency: Int
  read_under_write: @firrtl.ReadUnderWrite
  readers: Array[String]
  writers: Array[String]
  readwriters: Array[String]
  data: Array[SimValue]
  read_data: Map[String, SimValue]
}

priv struct MemoryWrite {
  address: Int?
  data: SimValue
  mask: SimValue
}

pub struct Simulator {
  design: TypedModule
  program: Array[SimStmt]
  signals: Map[String, SimValue]
  registers: Map[String, RegisterState]
  next_registers: Map[String, SimValue]
  memories: Map[String, MemoryState]
  clocks: Map[String, Bool]
  messages: Array[SimMessage]
  mut message_cursor: Int
  mut retain_history: Bool
  mut halted: Bool
  mut exit_code: Int?
  mut failure: String?
  mut first_failure: SimMessage?
  modules: Map[String, TypedModule]
  children: Map[String, Simulator]
  child_message_offsets: Map[String, Int]
  memory_clocks: Map[String, String]
  mut cycle: Int
  mut waveform: Waveform?
  mut waveform_filter: Array[String]
  // A reverse dependency index lets settle() revisit only statements affected
  // by a poke, clock edge, register update, or child output change.
  dependents: Map[String, Array[Int]]
  pending: Array[Int]
  queued: Array[Bool]
  primitive_model: PrimitiveModel?
  commands: Array[SimCommand]
}

pub fn Simulator::new(design: TypedModule) -> Simulator raise SimulatorError {
  let circuit: TypedCircuit = { version: @firrtl.min_version(), id: design.id, annotations: [], decls: [@firrtl.Decl::Module(design)] }
  let circuit = prepare_simulation_circuit(circuit)
  Simulator::from_circuit(circuit, design.id.inner())
}

/// Build a hierarchical simulator for one module in a typed FIRRTL circuit.
pub fn Simulator::from_circuit(circuit: TypedCircuit, top: String) -> Simulator raise SimulatorError {
  Simulator::from_circuit_with_models(circuit, top, Map([]))
}

/// Build a hierarchical simulator and provide host models for ExtModule
/// declarations.  Primitive models keep board- or device-specific behaviour
/// out of the FIRRTL evaluator while remaining usable from native testbenches.
pub fn Simulator::from_circuit_with_models(
  circuit: TypedCircuit,
  top: String,
  primitive_models: Map[String, PrimitiveModel],
) -> Simulator raise SimulatorError {
  let top = if top.is_empty() { circuit.id.inner() } else { top }
  let modules: Map[String, TypedModule] = Map([])
  for decl in circuit.decls {
    match decl {
      @firrtl.Decl::Module(design) => modules[design.id.inner()] = design
      @firrtl.Decl::ExtModule(ext) => modules[ext.id.inner()] = {
        public: false,
        id: ext.id,
        ports: ext.ports,
        body: [],
      }
    }
  }
  let design = match modules.get(top) {
    Some(design) => design
    None => {
      // Imported modules are namespace-qualified by elaboration (for example
      // `GameOfLifeSim` becomes `GameOfLife_GameOfLifeSim`). Accept the source-level leaf name
      // when it resolves unambiguously so playground users do not need to
      // know the compiler's internal prefix.
      let suffix = "_" + top
      let matches = modules.values().filter(mod => mod.id.inner().has_suffix(suffix)).collect()
      match matches {
        [design] => design
        _ => raise MissingSignal(name="top module " + top)
      }
    }
  }
  Simulator::new_with_modules(design, modules~, primitive_model=primitive_models.get(design.id.inner()), primitive_models~)
}

/// Normalize raw typed FIRRTL once before constructing a simulator. Driver
/// output already satisfies this contract; `Simulator::new` uses it for
/// hand-built modules.
pub fn prepare_simulation_circuit(circuit: TypedCircuit) -> TypedCircuit raise SimulatorError {
  try {
    @firrtl.LowerAggregateTypesPass::new(split_memories=false, packed_bool_rows=true).prepare_simulation(circuit)
  } catch {
    err => raise Unsupported(message=err.to_string())
  }
}

fn Simulator::new_with_modules(
  design: TypedModule,
  modules~: Map[String, TypedModule],
  primitive_models~: Map[String, PrimitiveModel],
  primitive_model~: PrimitiveModel?,
) -> Simulator raise SimulatorError {
  let design = { ..design, body: order_simulation_body(design.body) }
  for stmt in design.body {
    if stmt is @firrtl.Stmt::When(_) {
      raise Unsupported(message="simulation requires normalized FIRRTL; remaining conditional statements are not supported")
    }
  }
  let signals: Map[String, SimValue] = Map([])
  let registers: Map[String, RegisterState] = Map([])
  let next_registers: Map[String, SimValue] = Map([])
  let memories: Map[String, MemoryState] = Map([])
  let clocks: Map[String, Bool] = Map([])
  let children: Map[String, Simulator] = Map([])
  let child_message_offsets: Map[String, Int] = Map([])
  let memory_clocks: Map[String, String] = Map([])
  let program = design.body.map(compile_stmt)
  let commands = compile_commands(design)
  let dependents: Map[String, Array[Int]] = Map([])
  let pending = Array::new(capacity=design.body.length())
  let queued = Array::new(capacity=design.body.length())
  for _ in 0..<design.body.length() { queued.push(false) }

  for port in design.ports {
    let width = type_width(port.ty)
    if width < 0 { raise InvalidWidth(width~) }
    let name = port.id.inner()
    signals[name] = SimValue::zero(width)
    if port.ty is @firrtl.Type::Clock {
      clocks[name] = false
    }
  }

  for stmt in design.body {
    match stmt {
      @firrtl.Stmt::Wire(id~, ty~) => {
        signals[id.inner()] = SimValue::zero(type_width(ty))
      }
      @firrtl.Stmt::Node(id~, expr~) => {
        signals[id.inner()] = SimValue::zero(type_width(expr.ty()))
      }
      @firrtl.Stmt::Reg(id~, ty~, clock~) => {
        let name = id.inner()
        let clock = clock_name(clock)
        let clock = require_clock_source(design, clock)
        let width = type_width(ty)
        signals[name] = SimValue::new(width, 0, known=false)
        registers[name] = {
          name, width, clock, reset: None, init: None, async_reset: false, previous_clock: false,
        }
        next_registers[name] = signals[name]
      }
      @firrtl.Stmt::RegReset(id~, ty~, clock~, reset~, init~) => {
        let name = id.inner()
        let clock = clock_name(clock)
        let clock = require_clock_source(design, clock)
        let width = type_width(ty)
        signals[name] = SimValue::new(width, 0, known=false)
        registers[name] = {
          name,
          width,
          clock,
          reset: Some(compile_expr(reset)),
          init: Some(compile_expr(init)),
          async_reset: reset.ty() is @firrtl.Type::AsyncReset,
          previous_clock: false,
        }
        next_registers[name] = signals[name]
      }
      @firrtl.Stmt::Mem(mem) => {
        let id = mem.id.inner()
        if mem.read_latency < 0 || mem.read_latency > 1 || mem.write_latency != 1 {
          raise Unsupported(message="memory '{id}' requires read latency 0 or 1 and write latency 1")
        }
        let width = type_width(mem.data_type)
        let data = Array::new(capacity=mem.depth)
        for _ in 0..<mem.depth { data.push(SimValue::new(width, 0, known=false)) }
        memories[id] = {
          width,
          depth: mem.depth,
          read_latency: mem.read_latency,
          read_under_write: mem.read_under_write,
          readers: mem.readers.map(id => id.inner()),
          writers: mem.writers.map(id => id.inner()),
          readwriters: mem.readwriters.map(id => id.inner()),
          data,
          read_data: Map([]),
        }
        for reader in mem.readers + mem.readwriters {
          let name = id + "." + reader.inner()
          memory_clocks[name] = require_clock_source(design, name + ".clk")
        }
        for writer in mem.writers {
          let name = id + "." + writer.inner()
          memory_clocks[name] = require_clock_source(design, name + ".clk")
        }
      }
      @firrtl.Stmt::Inst(id~, of~, sig~) => {
        let instance = id.inner()
        let child_design = match modules.get(of.inner()) {
          Some(child) => child
          None => match primitive_models.get(of.inner()) {
            Some(_) => {
              // Some frontends omit ExtModule declarations from the circuit
              // and leave only the instance signature. Build a synthetic leaf
              // module so the registered primitive model can still service it.
              let ports: Array[@firrtl.Port] = []
              for name, port in sig.ports.iter2() {
                ports.push({
                  dir: port.dir,
                  id: @firrtl.Id::from(name),
                  ty: port.ty,
                })
              }
              let synthetic: @firrtl.TypedModule = {
                public: false,
                id: @firrtl.Id::from(of.inner()),
                ports,
                body: [],
              }
              modules[of.inner()] = synthetic
              synthetic
            }
            None => raise Unsupported(message="external or unknown module '{of.inner()}' has no simulation model")
          }
        }
        let model = primitive_models.get(of.inner())
        if child_design.body.is_empty() && model is None {
          raise Unsupported(message="external module '{of.inner()}' has no simulation model")
        }
        children[instance] = Simulator::new_with_modules(
          child_design,
          modules~,
          primitive_models~,
          primitive_model=model,
        )
        for port_name, port in sig.ports {
          if port.dir is @parse.PortDir::Input && port.ty is @firrtl.Type::Clock {
            let _ = require_clock_source(design, instance + "." + port_name)
          }
          signals[instance + "." + port_name] = SimValue::new(type_width(port.ty), 0, known=false)
        }
      }
      _ => ()
    }
  }

  for i, stmt in design.body {
    let refs = []
    collect_stmt_refs(stmt, refs)
    for name in refs {
      add_dependent(dependents, name, i)
      // Asynchronous read data also depends on the read-port controls.
      for memory_id, memory in memories {
        if memory.read_latency != 0 { continue }
        for reader in memory.readers + memory.readwriters {
          let port = memory_id + "." + reader
          if name == port + ".data" || name == port + ".rdata" {
            for control in ["addr", "en", "wmode"] {
              add_dependent(dependents, port + "." + control, i)
            }
          }
        }
      }
    }
    // All combinational statements are evaluated once on the first settle.
    pending.push(i)
    queued[i] = true
  }

  {
    design,
    program,
    signals,
    registers,
    next_registers,
    memories,
    clocks,
    messages: [],
    message_cursor: 0,
    retain_history: true,
    halted: false,
    exit_code: None,
    failure: None,
    first_failure: None,
    modules,
    children,
    child_message_offsets,
    memory_clocks,
    cycle: 0,
    waveform: None,
    waveform_filter: [],
    dependents,
    pending,
    queued,
    primitive_model,
    commands,
  }
}

fn add_dependent(dependents: Map[String, Array[Int]], name: String, index: Int) -> Unit {
  match dependents.get(name) {
    Some(indices) => if !indices.contains(index) { indices.push(index) }
    None => dependents[name] = [index]
  }
}

fn collect_stmt_refs(stmt: @firrtl.TypedStmt, refs: Array[String]) -> Unit {
  match stmt {
    @firrtl.Stmt::Node(expr~, ..) => collect_expr_refs(expr, refs)
    @firrtl.Stmt::Connect(_, expr) => collect_expr_refs(expr, refs)
    @firrtl.Stmt::When(when) => {
      collect_expr_refs(when.cond, refs)
      for nested in when.body { collect_stmt_refs(nested, refs) }
      for nested in when.otherwise.unwrap_or([]) { collect_stmt_refs(nested, refs) }
    }
    @firrtl.Stmt::Command(command) => match command {
      @firrtl.Command::Printf(clk~, en~, fmt=_, args~) => {
        collect_expr_refs(clk, refs)
        collect_expr_refs(en, refs)
        for arg in args { collect_expr_refs(arg, refs) }
      }
      @firrtl.Command::Assert(clk~, pred~, en~, fmt=_, args~) => {
        collect_expr_refs(clk, refs)
        collect_expr_refs(pred, refs)
        collect_expr_refs(en, refs)
        for arg in args { collect_expr_refs(arg, refs) }
      }
      @firrtl.Command::Stop(clk~, en~, code=_) => {
        collect_expr_refs(clk, refs)
        collect_expr_refs(en, refs)
      }
    }
    _ => ()
  }
}

fn collect_expr_refs(expr: @firrtl.TypedExpr, refs: Array[String]) -> Unit {
  match expr {
    @firrtl.Expr::Reference(reference, ..) => collect_ref_refs(reference, refs)
    @firrtl.Expr::Mux(cond~, tval~, fval~, ..) => {
      collect_expr_refs(cond, refs)
      collect_expr_refs(tval, refs)
      collect_expr_refs(fval, refs)
    }
    @firrtl.Expr::PrimOp(args~, ..) => {
      for arg in args { collect_expr_refs(arg, refs) }
    }
    @firrtl.Expr::Literal(_, ..) => ()
  }
}

// Static and dynamic indexing is evaluated from the underlying signal, not
// from a standalone `signal[index]` entry.  Record every enclosing reference
// so that a later assignment to the source re-enqueues the slice expression.
// This matters for aggregate literals, whose bit-slice statements can be
// visited before the literal node during the initial dirty-worklist pass.
fn collect_ref_refs(reference: @firrtl.TypedRef, refs: Array[String]) -> Unit {
  refs.push(ref_name(reference))
  match reference {
    @firrtl.Reference::StaticIndexing(lhs~, ..) | @firrtl.Reference::DynamicIndexing(lhs~, ..) => {
      collect_ref_refs(lhs, refs)
    }
    @firrtl.Reference::FieldAccess(lhs~, ..) => collect_ref_refs(lhs, refs)
    @firrtl.Reference::Id(_, ..) => ()
  }
}

fn compile_stmt(stmt: @firrtl.TypedStmt) -> SimStmt {
  match stmt {
    @firrtl.Stmt::Node(id~, expr~) => SimStmt::Node(name=id.inner(), expr=compile_expr(expr))
    @firrtl.Stmt::Connect(lhs, rhs) => {
      let expr = compile_expr(rhs)
      let width = type_width(lhs.ty())
      // Hand-built typed FIRRTL may widen a connection without an explicit pad.
      let expr = if type_signed(rhs.ty()) && width > type_width(rhs.ty()) {
        SimExpr::Prim(op=@firrtl.PrimOp::Pad, args=[expr], width~, signed=true)
      } else { expr }
      SimStmt::Connect(name=ref_name(lhs), expr~)
    }
    _ => SimStmt::Other
  }
}

fn compile_commands(design: TypedModule) -> Array[SimCommand] raise SimulatorError {
  let commands = []
  for stmt in design.body {
    guard stmt is @firrtl.Stmt::Command(command) else { continue }
    match command {
      @firrtl.Command::Printf(clk~, en~, fmt~, args~) => {
        let clock = require_clock_source(design, clock_name(clk))
        commands.push({
          clock,
          enable: compile_expr(en),
          action: SimCommandAction::Printf(
            parts=compile_format(fmt, args),
            args=args.map(arg => (compile_expr(arg), type_signed(arg.ty()))),
          ),
        })
      }
      @firrtl.Command::Assert(clk~, en~, pred~, fmt~, args~) => {
        let clock = require_clock_source(design, clock_name(clk))
        commands.push({
          clock,
          enable: compile_expr(en),
          action: SimCommandAction::Assert(
            pred=compile_expr(pred),
            parts=compile_format(fmt, args),
            args=args.map(arg => (compile_expr(arg), type_signed(arg.ty()))),
          ),
        })
      }
      @firrtl.Command::Stop(clk~, en~, code~) => {
        let clock = require_clock_source(design, clock_name(clk))
        commands.push({ clock, enable: compile_expr(en), action: SimCommandAction::Stop(code~) })
      }
    }
  }
  commands
}

fn compile_format(fmt: String, args: Array[TypedExpr]) -> Array[SimFormatPart] raise SimulatorError {
  let parsed = try @firrtl.FormatString::parse(fmt) catch {
    err => raise Unsupported(message=err.to_string())
  }
  let parts = []
  let mut placeholders = 0
  for part in parsed.parts {
    match part {
      @firrtl.FormatStringPart::StringPart(text) => parts.push(SimFormatPart::Text(text))
      @firrtl.FormatStringPart::EscapedChar(char) => parts.push(SimFormatPart::Text(char.to_string()))
      @firrtl.FormatStringPart::BinaryPlaceholder => { placeholders += 1; parts.push(SimFormatPart::Binary) }
      @firrtl.FormatStringPart::AsciiPlaceholder => { placeholders += 1; parts.push(SimFormatPart::Character) }
      @firrtl.FormatStringPart::DecimalPlaceholder => { placeholders += 1; parts.push(SimFormatPart::Decimal) }
      @firrtl.FormatStringPart::HexadecimalPlaceholder => { placeholders += 1; parts.push(SimFormatPart::Hexadecimal) }
    }
  }
  if placeholders != args.length() {
    raise Unsupported(message="format string has \{placeholders} placeholders for \{args.length()} arguments")
  }
  parts
}

// Operand interpretation is shared by compiled data paths and command/reset evaluation.
fn primitive_signed(op: PrimOp, args: Array[TypedExpr], ty: Type) -> Bool {
  match op {
    @firrtl.PrimOp::Lt | @firrtl.PrimOp::Leq | @firrtl.PrimOp::Gt | @firrtl.PrimOp::Geq |
    @firrtl.PrimOp::Eq | @firrtl.PrimOp::Neq | @firrtl.PrimOp::And | @firrtl.PrimOp::Or |
    @firrtl.PrimOp::Xor | @firrtl.PrimOp::Neg | @firrtl.PrimOp::Dshl =>
      args.get(0).map(expr => type_signed(expr.ty())).unwrap_or(false)
    _ => type_signed(ty)
  }
}

fn compile_expr(expr: @firrtl.TypedExpr) -> SimExpr {
  match expr {
    @firrtl.Expr::Reference(reference, ty~) => compile_ref(reference, type_width(ty))
    @firrtl.Expr::Literal(lit, ty~) => SimExpr::Literal(value=SimValue::new(type_width(ty), lit.as_bigint()))
    @firrtl.Expr::Mux(cond~, tval~, fval~, ..) => SimExpr::Mux(
      cond=compile_expr(cond),
      tval=compile_expr(tval),
      fval=compile_expr(fval),
    )
    @firrtl.Expr::PrimOp(op~, args~, ty~) => {
      let signed = primitive_signed(op, args, ty)
      SimExpr::Prim(
        op~,
        args=args.map(compile_expr),
        width=type_width(ty),
        signed~,
      )
    }
  }
}

fn compile_ref(reference: @firrtl.TypedRef, width: Int) -> SimExpr {
  match reference {
    @firrtl.Reference::FieldAccess(
      lhs=@firrtl.Reference::FieldAccess(
        lhs=@firrtl.Reference::Id(memory_id, ..),
        field=reader,
        ..
      ),
      field=data,
      ..
    ) if data.inner() == "data" || data.inner() == "rdata" => SimExpr::MemoryData(
      memory=memory_id.inner(),
      reader=reader.inner(),
      width~,
    )
    @firrtl.Reference::StaticIndexing(lhs~, index~, ty~) => SimExpr::Slice(
      source=compile_ref(lhs, type_width(lhs.ty())),
      index~,
      width=type_width(ty),
    )
    _ => SimExpr::Signal(name=ref_name(reference), width~)
  }
}

fn Simulator::enqueue_signal(self: Simulator, name: String) -> Unit {
  match self.dependents.get(name) {
    Some(indices) => for index in indices { self.enqueue_statement(index) }
    None => ()
  }
}

fn Simulator::enqueue_statement(self: Simulator, index: Int) -> Unit {
  if index < 0 || index >= self.queued.length() || self.queued[index] { return }
  self.queued[index] = true
  self.pending.push(index)
}

pub fn Simulator::messages(self: Simulator) -> Array[SimMessage] {
  self.messages
}

pub fn Simulator::set_history_retention(self: Simulator, retain: Bool) -> Unit {
  self.retain_history = retain
}

pub fn Simulator::drain_events(self: Simulator) -> Array[SimMessage] {
  let events = self.messages[self.message_cursor:].iter().collect()
  if self.retain_history {
    self.message_cursor = self.messages.length()
  } else {
    self.messages.clear()
    self.message_cursor = 0
  }
  events
}

pub fn Simulator::is_halted(self: Simulator) -> Bool { self.halted }

pub fn Simulator::exit_code(self: Simulator) -> Int? { self.exit_code }

pub fn Simulator::failure(self: Simulator) -> String? { self.failure }

pub fn Simulator::status(self: Simulator) -> SimulationStatus {
  {
    halted: self.halted,
    exit_code: self.exit_code,
    failed: self.failure is Some(_),
    first_failure: self.first_failure,
  }
}

/// Enable transition tracing.  An empty filter records every changed signal;
/// otherwise only the named signals are retained.  Tracing is opt-in so it
/// does not affect the hot path used by the playground.
pub fn Simulator::enable_waveform(self: Simulator, signals~: Array[String] = []) -> Unit {
  self.waveform_filter = signals
  self.waveform = Some({ samples: [] })
}

pub fn Simulator::disable_waveform(self: Simulator) -> Unit {
  self.waveform = None
}

pub fn Simulator::waveform(self: Simulator) -> Array[WaveSample] {
  self.waveform.map(w => w.samples).unwrap_or([])
}

pub fn Simulator::cycle(self: Simulator) -> Int { self.cycle }

pub fn Simulator::poke(self: Simulator, name: String, value: SimValue) -> Unit raise SimulatorError {
  if !self.signals.contains(name) {
    raise MissingSignal(name~)
  }
  let _ = self.assign_signal(name, SimValue::with_mask(type_width_for_name(self, name), value.raw, value.known_mask))
  self.apply_async_resets()
}

pub fn Simulator::peek(self: Simulator, name: String) -> SimValue raise SimulatorError {
  match self.signals.get(name) {
    Some(value) => value
    None => raise MissingSignal(name~)
  }
}

/// Evaluate the dirty combinational worklist and propagate changed child ports.
/// Low FIRRTL is normally acyclic, so the queue visits each affected statement
/// once.  A generous bound still catches hand-built combinational loops without
/// allowing a malformed design to hang a testbench or browser worker.
pub fn Simulator::settle(self: Simulator) -> Unit raise SimulatorError {
  if self.halted { return }
  self.settle_pending()
}

fn Simulator::settle_pending(self: Simulator) -> Unit raise SimulatorError {
  // The normalized program has a deterministic producer order. Evaluate every
  // combinational node at the start of a public settle rather than depending
  // on ad-hoc dependency exceptions for memory controls or model inputs.
  // The reverse index remains useful for follow-up propagation within this
  // sweep, after a register, asynchronous reset, or child output changes.
  for index in 0..<self.program.length() {
    self.enqueue_statement(index)
  }
  let mut evaluated = 0
  while true {
    // Process in source/enqueue order. A stack repeatedly propagates partially
    // evaluated values through long feed-forward chains (such as a framebuffer
    // of successive LFSR samples), making acyclic circuits look like loops.
    let mut cursor = 0
    while cursor < self.pending.length() {
      let index = self.pending[cursor]
      cursor += 1
      self.queued[index] = false
      evaluated += 1
      if evaluated > 1_000_000 {
        raise CombinationalLoop(message="dirty worklist exceeded 1,000,000 evaluations")
      }
      self.eval_combinational_stmt(self.program[index])
    }
    self.pending.clear()
    self.apply_async_resets()
    let child_changed = self.settle_children()
    if self.pending.length() == 0 && !child_changed { break }
  }
}

fn Simulator::eval_combinational_stmt(self: Simulator, stmt: SimStmt) -> Unit raise SimulatorError {
  match stmt {
    SimStmt::Node(name~, expr~) => {
      let _ = self.assign_signal(name, self.eval_compiled_expr(expr))
    }
    SimStmt::Connect(name~, expr~) => {
      let value = self.eval_compiled_expr(expr)
      if self.registers.contains(name) {
        self.next_registers[name] = value
      } else {
        let _ = self.assign_signal(name, value)
      }
    }
    SimStmt::Other => ()
  }
}

fn Simulator::eval_compiled_expr(self: Simulator, expr: SimExpr) -> SimValue raise SimulatorError {
  match expr {
    SimExpr::Signal(name~, width~) => self.signals.get(name).unwrap_or(SimValue::new(width, 0, known=false))
    SimExpr::MemoryData(memory~, reader~, width~) => self.eval_memory_data(memory, reader, width)
    SimExpr::Slice(source~, index~, width~) => {
      let value = self.eval_compiled_expr(source)
      SimValue::with_mask(width, value.raw >> (index * width), value.known_mask >> (index * width))
    }
    SimExpr::Literal(value~) => value
    SimExpr::Mux(cond~, tval~, fval~) => {
      let condition = self.eval_compiled_expr(cond)
      if condition.is_known() {
        return self.eval_compiled_expr(if condition.raw != 0 { tval } else { fval })
      }
      let when_true = self.eval_compiled_expr(tval)
      let when_false = self.eval_compiled_expr(fval)
      merge_unknown_mux(when_true, when_false, when_true.width)
    }
    SimExpr::Prim(op~, args~, width~, signed~) => {
      let values = args.map((arg: SimExpr) => self.eval_compiled_expr(arg))
      eval_prim(op, values, width, signed)
    }
  }
}

fn Simulator::eval_memory_data(self: Simulator, memory_id: String, reader: String, width: Int) -> SimValue raise SimulatorError {
  match self.memories.get(memory_id) {
    Some(memory) if memory.read_latency > 0 => memory.read_data.get(reader).unwrap_or(SimValue::new(width, 0, known=false))
    Some(memory) => self.live_memory_read(memory_id, memory, reader, width)
    None => raise MissingSignal(name=memory_id + "." + reader + ".data")
  }
}

fn Simulator::settle_children(self: Simulator) -> Bool raise SimulatorError {
  let mut changed = false
  for instance, child in self.children {
    let mut input_changed = false
    for port in child.design.ports {
      if port.dir is @parse.PortDir::Input {
        let parent_name = instance + "." + port.id.inner()
        let value = self.signals.get(parent_name).unwrap_or(SimValue::zero(type_width(port.ty)))
        input_changed = child.assign_signal(port.id.inner(), value) || input_changed
        if port.ty is @firrtl.Type::Clock {
          child.clocks[port.id.inner()] = value.raw != 0
        }
      }
    }
    match child.primitive_model {
      Some(model) => {
        let inputs = []
        for port in child.design.ports {
          if port.dir is @parse.PortDir::Input {
            inputs.push(self.signals.get(instance + "." + port.id.inner()).unwrap_or(SimValue::zero(type_width(port.ty))))
          }
        }
        let outputs = (model.evaluate)(inputs)
        let output_ports = child.design.ports.filter(port => port.dir is @parse.PortDir::Output)
        if outputs.length() != output_ports.length() {
          raise Unsupported(message="primitive model for '\{child.design.id.inner()}' returned \{outputs.length()} outputs for \{output_ports.length()} ports")
        }
        for pair in @utils.zip2(output_ports, outputs) {
          let (port, value) = pair
          if value.width != type_width(port.ty) {
            raise Unsupported(message="primitive model for '\{child.design.id.inner()}' returned width \{value.width} for output '\{port.id.inner()}', expected \{type_width(port.ty)}")
          }
          let _ = child.assign_signal(port.id.inner(), value)
        }
      }
      None => if input_changed || child.pending.length() > 0 {
        child.settle()
      }
    }
    for port in child.design.ports {
      if port.dir is @parse.PortDir::Output {
        let child_value = child.signals.get(port.id.inner()).unwrap_or(SimValue::new(type_width(port.ty), 0, known=false))
        changed = self.assign_signal(instance + "." + port.id.inner(), child_value) || changed
      }
    }
  }
  changed
}

/// Drive a clock and commit the registers on a rising edge.
pub fn Simulator::set_clock(self: Simulator, name: String, high: Bool) -> Unit raise SimulatorError {
  if !self.clocks.contains(name) {
    raise MissingSignal(name~)
  }
  let old = self.clocks.get(name).unwrap()
  self.clocks[name] = high
  let _ = self.assign_signal(name, SimValue::from_int(1, high.to_int()))
  self.settle()
  self.apply_async_resets()
  if !old && high {
    self.commit_clock(name)
  }
}

fn Simulator::apply_async_resets(self: Simulator) -> Unit raise SimulatorError {
  for name, reg in self.registers {
    if !reg.async_reset { continue }
    let reset = self.eval_compiled_expr(reg.reset.unwrap())
    let init = match reg.init {
      Some(expr) => self.eval_compiled_expr(expr)
      None => SimValue::zero(reg.width)
    }
    let value = select_value(reset, init, self.signals[name], reg.width)
    // Reset changes Q, not the cached combinational D input.
    let _ = self.assign_signal(name, value)
  }
}

pub fn Simulator::step_clock(self: Simulator, name: String) -> Unit raise SimulatorError {
  if self.halted { return }
  self.set_clock(name, true)
  self.set_clock(name, false)
  self.cycle += 1
}

fn Simulator::commit_clock(self: Simulator, clock: String) -> Unit raise SimulatorError {
  self.commit_clocks([clock])
}

// All clock ports driven by the same parent edge sample one pre-edge state.
fn Simulator::commit_clocks(self: Simulator, clocks: Array[String]) -> Unit raise SimulatorError {
  let updates: Array[(String, SimValue)] = []
  for name, reg in self.registers {
    if !clocks.contains(reg.clock) { continue }
    let next = self.next_registers.get(name).unwrap_or(self.signals[name])
    let value = match reg.reset {
      Some(expr) => {
        let init = match reg.init {
          Some(expr) => self.eval_compiled_expr(expr)
          None => SimValue::zero(reg.width)
        }
        select_value(self.eval_compiled_expr(expr), init, next, reg.width)
      }
      None => next
    }
    updates.push((name, value))
  }
  for clock in clocks { self.run_commands(clock) }
  self.commit_children(clocks)
  self.commit_memories(clocks)
  for update in updates {
    let (name, value) = update
    let _ = self.assign_signal(name, value)
  }
  // A stop command still completes its triggering edge and output propagation.
  self.settle_pending()
}

fn Simulator::commit_children(self: Simulator, clocks: Array[String]) -> Unit raise SimulatorError {
  for instance, child in self.children {
    let child_clocks: Array[String] = []
    for port in child.design.ports {
      if port.dir is @parse.PortDir::Input && port.ty is @firrtl.Type::Clock {
        let source = clock_source(self.design, instance, port.id.inner())
        if source.map(clock => clocks.contains(clock)).unwrap_or(false) && child.clocks.get(port.id.inner()).unwrap_or(false) {
          child_clocks.push(port.id.inner())
        }
      }
    }
    if !child_clocks.is_empty() { child.commit_clocks(child_clocks) }
    let offset = self.child_message_offsets.get(instance).unwrap_or(0)
    let child_messages = child.messages()
    for i in offset..<child_messages.length() {
      let event = child_messages[i]
      self.messages.push({ ..event, instance_path: if event.instance_path.is_empty() { instance } else { instance + "." + event.instance_path } })
    }
    self.child_message_offsets[instance] = child_messages.length()
    if self.failure is None && child.failure is Some(failure) {
      self.failure = Some(failure)
      self.first_failure = child.first_failure.map(event => { ..event, instance_path: if event.instance_path.is_empty() { instance } else { instance + "." + event.instance_path } })
    }
    if child.halted {
      self.halted = true
      self.exit_code = child.exit_code
    }
  }
}

fn clock_source(design: TypedModule, instance: String, port: String) -> String? {
  for stmt in design.body {
    match stmt {
      @firrtl.Stmt::Connect(
        @firrtl.Reference::FieldAccess(
          lhs=@firrtl.Reference::Id(id, ..),
          field~,
          ..
        ),
        @firrtl.Expr::Reference(@firrtl.Reference::Id(clock, ..), ..),
      ) if id.inner() == instance && field.inner() == port => return find_signal_source(design, clock.inner())
      _ => ()
    }
  }
  None
}

// Follow direct clock aliases to their input port. Cyclic or computed
// sources are left unresolved rather than recursing indefinitely.
fn require_clock_source(design: TypedModule, target: String) -> String raise SimulatorError {
  match find_signal_source(design, target) {
    Some(clock) => clock
    None => raise Unsupported(message="clock '{target}' must be driven by a direct input clock or alias; derived clocks are not supported")
  }
}

fn find_signal_source(design: TypedModule, target: String) -> String? {
  let visited: Set[String] = Set([])
  let mut current = target
  while !visited.contains(current) {
    visited.add(current)
    for port in design.ports {
      if port.id.inner() == current && port.dir is @parse.PortDir::Input && port.ty is @firrtl.Type::Clock {
        return Some(current)
      }
    }
    let mut source: String? = None
    for stmt in design.body {
      match stmt {
        @firrtl.Stmt::Connect(lhs, @firrtl.Expr::Reference(@firrtl.Reference::Id(id, ..), ..)) if ref_name(lhs) == current => source = Some(id.inner())
        @firrtl.Stmt::Node(id~, expr=@firrtl.Expr::Reference(@firrtl.Reference::Id(ref_id, ..), ..)) if id.inner() == current => source = Some(ref_id.inner())
        _ => ()
      }
    }
    match source {
      Some(name) => current = name
      None => return None
    }
  }
  None
}

// Sample every active port before mutating memory or synchronous read outputs.
fn Simulator::commit_memories(self: Simulator, clocks: Array[String]) -> Unit {
  for id, memory in self.memories {
    let prefix = id + "."
    let writes: Array[MemoryWrite] = []
    for writer in memory.writers + memory.readwriters {
      let port = prefix + writer
      if !clocks.contains(self.memory_clocks[port]) { continue }
      let enabled = self.signal_or_zero(port + ".en")
      if enabled.is_known() && enabled.raw == 0 { continue }
      let rw = memory.readwriters.contains(writer)
      let mode = if rw { self.signal_or_zero(port + ".wmode") } else { SimValue::from_int(1, 1) }
      if mode.is_known() && mode.raw == 0 { continue }
      let mask_name = if rw { port + ".wmask" } else { port + ".mask" }
      let mask_value = self.signal_or_zero(mask_name)
      if mask_value.is_known() && mask_value.raw == 0 { continue }
      let address_value = self.signal_or_zero(port + ".addr")
      if address_value.is_known() && address_value.raw >= BigInt::from_int(memory.depth) { continue }
      let address = if address_value.is_known() { Some(address_value.raw.to_int()) } else { None }
      let data_name = if rw { port + ".wdata" } else { port + ".data" }
      let data = self.signal_or_zero(data_name)
      let controls_known = enabled.is_known() && mode.is_known() && address_value.is_known()
      let data = if controls_known { data } else { SimValue::new(data.width, 0, known=false) }
      writes.push({ address, data, mask: mask_value })
    }

    if memory.read_latency == 1 {
      for reader in memory.readers + memory.readwriters {
        let port = prefix + reader
        if !clocks.contains(self.memory_clocks[port]) { continue }
        let enabled = self.signal_or_zero(port + ".en")
        let address = self.signal_or_zero(port + ".addr")
        let rw = memory.readwriters.contains(reader)
        let mode = if rw { self.signal_or_zero(port + ".wmode") } else { SimValue::zero(1) }
        let value = if enabled.is_known() && enabled.raw != 0 && address.is_known() &&
            address.raw < BigInt::from_int(memory.depth) && mode.is_known() && mode.raw == 0 {
          memory.read_value(address.raw.to_int(), writes)
        } else {
          SimValue::new(memory.width, 0, known=false)
        }
        memory.read_data[reader] = value
      }
    }

    for address in 0..<memory.depth {
      let matching = writes.filter(w => w.address is None || w.address == Some(address))
      if !matching.is_empty() {
        memory.data[address] = resolve_writes(memory.data[address], matching, memory.width)
      }
    }
    for reader in memory.readers { self.enqueue_signal(prefix + reader + ".data") }
    for reader in memory.readwriters { self.enqueue_signal(prefix + reader + ".rdata") }
  }
}

fn resolve_writes(old: SimValue, writes: Array[MemoryWrite], width: Int) -> SimValue {
  let mut result = old
  let mut written: BigInt = 0
  for write in writes {
    let granularity = if write.mask.width == 0 { width } else { width / write.mask.width }
    let mut bits: BigInt = 0
    for lane in 0..<write.mask.width {
      if ((write.mask.known_mask >> lane) & 1) == 0 || ((write.mask.raw >> lane) & 1) != 0 {
        bits = bits | (mask(granularity) << (lane * granularity))
      }
    }
    let overlap = written & bits
    written = written | bits
    result = masked_write(result, write.data, write.mask, width)
    if overlap != 0 {
      result = SimValue::with_mask(width, result.raw, result.known_mask & (mask(width) ^ overlap))
    }
  }
  result
}

fn MemoryState::read_value(self: MemoryState, address: Int, writes: Array[MemoryWrite]) -> SimValue {
  let old = self.data[address]
  let matching = writes.filter(write => write.address is None || write.address == Some(address))
  if matching.is_empty() { return old }
  match self.read_under_write {
    @firrtl.ReadUnderWrite::Old => old
    @firrtl.ReadUnderWrite::New => resolve_writes(old, matching, self.width)
    @firrtl.ReadUnderWrite::Undefined => SimValue::new(self.width, 0, known=false)
  }
}

fn Simulator::live_memory_read(self: Simulator, memory_id: String, memory: MemoryState, reader: String, width: Int) -> SimValue {
  let port = memory_id + "." + reader
  let enabled = self.signal_or_zero(port + ".en")
  let address_value = self.signal_or_zero(port + ".addr")
  let address = address_value.raw.to_int()
  let mode = if memory.readwriters.contains(reader) { self.signal_or_zero(port + ".wmode") } else { SimValue::zero(1) }
  if !mode.is_known() || mode.raw != 0 || !enabled.is_known() || !address_value.is_known() || enabled.raw == 0 || address_value.raw >= BigInt::from_int(memory.depth) || address < 0 || address >= memory.depth {
    SimValue::new(width, 0, known=false)
  } else {
    memory.data[address]
  }
}

fn Simulator::signal_or_zero(self: Simulator, name: String) -> SimValue {
  self.signals.get(name).unwrap_or(SimValue::zero(1))
}

fn select_value(condition: SimValue, yes: SimValue, no: SimValue, width: Int) -> SimValue {
  if condition.is_known() {
    let value = if condition.raw != 0 { yes } else { no }
    SimValue::with_mask(width, value.raw, value.known_mask)
  } else {
    merge_unknown_mux(yes, no, width)
  }
}

fn merge_unknown_mux(yes: SimValue, no: SimValue, width: Int) -> SimValue {
  let both_known = yes.known_mask & no.known_mask
  let equal = mask(width) ^ normalize(yes.raw ^ no.raw, width)
  let known_mask = both_known & equal
  SimValue::with_mask(width, yes.raw, known_mask)
}

fn masked_write(old: SimValue, value: SimValue, mask_value: SimValue, width: Int) -> SimValue {
  let granularity = if mask_value.width == 0 { width } else { width / mask_value.width }
  let mut raw = old.raw
  let mut known_mask = old.known_mask
  for i in 0..<mask_value.width {
    let chunk_mask = mask(granularity) << (i * granularity)
    if ((mask_value.known_mask >> i) & 1) == 0 {
      raw = raw & (mask(width) ^ chunk_mask)
      known_mask = known_mask & (mask(width) ^ chunk_mask)
    } else if ((mask_value.raw >> i) & 1) != 0 {
      raw = (raw & (mask(width) ^ chunk_mask)) | (value.raw & chunk_mask)
      known_mask = (known_mask & (mask(width) ^ chunk_mask)) | (value.known_mask & chunk_mask)
    }
  }
  SimValue::with_mask(width, raw, known_mask)
}

fn Simulator::run_commands(self: Simulator, clock: String) -> Unit raise SimulatorError {
  for command in self.commands {
    if command.clock != clock { continue }
    let enabled = self.eval_compiled_expr(command.enable)
    if !enabled.is_known() {
      raise Unsupported(message="command enable is unknown on clock '\{clock}'")
    }
    if enabled.raw == 0 { continue }
    match command.action {
      SimCommandAction::Printf(parts~, args~) => {
        self.messages.push({ kind: "printf", text: self.format_command(parts, args), cycle: self.cycle + 1, instance_path: "", source: None })
      }
      SimCommandAction::Assert(pred~, parts~, args~) => {
        let predicate = self.eval_compiled_expr(pred)
        if !predicate.is_known() {
          let text = "assertion predicate is unknown on clock '\{clock}'"
          if self.failure is None { self.failure = Some(text) }
          let event = { kind: "assert_unknown", text, cycle: self.cycle + 1, instance_path: "", source: None }
          if self.first_failure is None { self.first_failure = Some(event) }
          self.messages.push(event)
          continue
        }
        if predicate.raw == 0 {
          let text = self.format_command(parts, args)
          if self.failure is None { self.failure = Some(text) }
          let event = { kind: "assert_failure", text, cycle: self.cycle + 1, instance_path: "", source: None }
          if self.first_failure is None { self.first_failure = Some(event) }
          self.messages.push(event)
        }
      }
      SimCommandAction::Stop(code~) => {
        self.halted = true
        self.exit_code = Some(code)
      }
    }
  }
}

fn Simulator::format_command(
  self: Simulator,
  parts: Array[SimFormatPart],
  args: Array[(SimExpr, Bool)],
) -> String raise SimulatorError {
  let text = StringBuilder()
  let mut next = 0
  for part in parts {
    match part {
      SimFormatPart::Text(value) => text.write_string(value)
      SimFormatPart::Binary | SimFormatPart::Character | SimFormatPart::Decimal | SimFormatPart::Hexadecimal => {
        let (expr, signed) = args[next]
        next += 1
        let value = self.eval_compiled_expr(expr)
        match part {
          SimFormatPart::Binary => text.write_string(format_binary(value))
          SimFormatPart::Character => text.write_char(Int::unsafe_to_char((value.raw & 255).to_int()))
          SimFormatPart::Decimal => text.write_string(if value.is_known() { (if signed { signed_value(value) } else { value.raw }).to_string() } else { "x" })
          SimFormatPart::Hexadecimal => text.write_string(format_hex(value))
          SimFormatPart::Text(_) => ()
        }
      }
    }
  }
  text.to_string()
}

fn format_binary(value: SimValue) -> String {
  if !value.is_known() { return "x" }
  let text = StringBuilder()
  for i in 0..<value.width {
    let bit = value.width - i - 1
    text.write_char(if ((value.raw >> bit) & 1) == 0 { '0' } else { '1' })
  }
  text.to_string()
}

fn format_hex(value: SimValue) -> String {
  if !value.is_known() { return "x" }
  let text = StringBuilder()
  let digits = (value.width + 3) / 4
  for i in 0..<digits {
    let shift = (digits - i - 1) * 4
    let nibble = ((value.raw >> shift) & 15).to_int()
    text.write_char(if nibble < 10 { Int::unsafe_to_char('0'.to_int() + nibble) } else { Int::unsafe_to_char('a'.to_int() + nibble - 10) })
  }
  text.to_string()
}

fn Simulator::assign_signal(self: Simulator, name: String, value: SimValue) -> Bool {
  let old = self.signals.get(name).unwrap_or(SimValue::zero(value.width))
  let value = SimValue::with_mask(old.width, value.raw, value.known_mask)
  if old.raw != value.raw || old.known_mask != value.known_mask {
    self.signals[name] = value
    self.enqueue_signal(name)
    if self.waveform is Some(trace) && (self.waveform_filter.is_empty() || self.waveform_filter.contains(name)) {
      trace.samples.push({ cycle: self.cycle, signal: name, value })
    }
    true
  } else {
    false
  }
}

fn eval_prim(
  op: PrimOp,
  values: Array[SimValue],
  width: Int,
  signed: Bool,
) -> SimValue {
  match eval_validity_prim(op, values, width, signed) {
    Some(value) => return value
    None => ()
  }
  if (op is @firrtl.PrimOp::Div || op is @firrtl.PrimOp::Rem) &&
      values.get(1).map(v => !v.is_known() || v.raw == 0).unwrap_or(true) {
    return SimValue::new(width, 0, known=false)
  }
  // Most generated control/data paths (including the playground's VGA and
  // Game of Life examples) are comfortably within a machine word.  Avoiding
  // BigInt arithmetic for those paths is the largest single speedup available
  // to the interpreter while retaining arbitrary-width semantics as a
  // fallback for software-style designs.
  if width <= 20 && values.iter().all(v => v.width <= 20) {
    return eval_prim_fast(op, values, width, signed)
  }
  eval_prim_big(op, values, width, signed)
}

/// Structural and bitwise primitives propagate validity bit-for-bit. More
/// complex arithmetic and comparisons deliberately remain conservative: their
/// result is unknown unless every operand is known.
fn eval_validity_prim(
  op: PrimOp,
  values: Array[SimValue],
  width: Int,
  signed: Bool,
) -> SimValue? {
  let a = values.get(0).unwrap_or(SimValue::zero(width))
  let b = values.get(1).unwrap_or(SimValue::zero(width))
  match op {
    @firrtl.PrimOp::Not => Some(SimValue::with_mask(width, mask(width) ^ a.raw, a.known_mask))
    @firrtl.PrimOp::And => {
      let known_zero_a = a.known_mask & (mask(width) ^ a.raw)
      let known_zero_b = b.known_mask & (mask(width) ^ b.raw)
      Some(SimValue::with_mask(width, a.raw & b.raw, (a.known_mask & b.known_mask) | known_zero_a | known_zero_b))
    }
    @firrtl.PrimOp::Or => {
      let known_one_a = a.known_mask & a.raw
      let known_one_b = b.known_mask & b.raw
      Some(SimValue::with_mask(width, a.raw | b.raw, (a.known_mask & b.known_mask) | known_one_a | known_one_b))
    }
    @firrtl.PrimOp::Xor => Some(SimValue::with_mask(width, a.raw ^ b.raw, a.known_mask & b.known_mask))
    @firrtl.PrimOp::Cat => {
      let mut raw: BigInt = 0
      let mut known_mask: BigInt = 0
      for value in values {
        raw = (raw << value.width) | value.raw
        known_mask = (known_mask << value.width) | value.known_mask
      }
      Some(SimValue::with_mask(width, raw, known_mask))
    }
    @firrtl.PrimOp::Bits => {
      let lo = values.get(2).unwrap_or(SimValue::zero(1)).raw.to_int()
      Some(SimValue::with_mask(width, a.raw >> lo, a.known_mask >> lo))
    }
    @firrtl.PrimOp::Head => {
      let shift = if a.width > width { a.width - width } else { 0 }
      Some(SimValue::with_mask(width, a.raw >> shift, a.known_mask >> shift))
    }
    @firrtl.PrimOp::Tail => Some(SimValue::with_mask(width, a.raw, a.known_mask))
    @firrtl.PrimOp::Shl | @firrtl.PrimOp::Dshl => {
      if !b.is_known() { Some(SimValue::new(width, 0, known=false)) } else {
        let shift = b.raw.to_int()
        let fill = if shift >= width { mask(width) } else { mask(shift) }
        Some(SimValue::with_mask(width, a.raw << shift, (a.known_mask << shift) | fill))
      }
    }
    @firrtl.PrimOp::Shr | @firrtl.PrimOp::Dshr => {
      if !b.is_known() { Some(SimValue::new(width, 0, known=false)) } else {
        let shift = b.raw.to_int()
        let kept_mask: BigInt = if shift >= a.width { BigInt::from_int(0) } else { a.known_mask >> shift }
        let extension_width = if shift > width { width } else { shift }
        let extension: BigInt = if extension_width == 0 { BigInt::from_int(0) } else { mask(extension_width) << (width - extension_width) }
        if signed && a.width > 0 {
          let sign_known = ((a.known_mask >> (a.width - 1)) & 1) != 0
          let sign_set = ((a.raw >> (a.width - 1)) & 1) != 0
          let raw = (a.raw >> shift) | (if sign_set { extension } else { 0 })
          Some(SimValue::with_mask(width, raw, kept_mask | (if sign_known { extension } else { 0 })))
        } else {
          Some(SimValue::with_mask(width, a.raw >> shift, kept_mask | extension))
        }
      }
    }
    @firrtl.PrimOp::Pad | @firrtl.PrimOp::AsUInt | @firrtl.PrimOp::AsSInt |
    @firrtl.PrimOp::AsClock | @firrtl.PrimOp::AsAsyncReset | @firrtl.PrimOp::Cvt => {
      if width <= a.width {
        Some(SimValue::with_mask(width, a.raw, a.known_mask))
      } else {
        let extension = mask(width) ^ mask(a.width)
        if signed && a.width > 0 {
          let sign_known = ((a.known_mask >> (a.width - 1)) & 1) != 0
          let sign_set = ((a.raw >> (a.width - 1)) & 1) != 0
          Some(SimValue::with_mask(width, a.raw | (if sign_set { extension } else { 0 }), a.known_mask | (if sign_known { extension } else { 0 })))
        } else {
          Some(SimValue::with_mask(width, a.raw, a.known_mask | extension))
        }
      }
    }
    @firrtl.PrimOp::Andr => {
      let known_zero = (a.known_mask & (mask(a.width) ^ a.raw)) != 0
      Some(if known_zero { SimValue::zero(1) } else if a.is_known() { SimValue::from_int(1, 1) } else { SimValue::new(1, 0, known=false) })
    }
    @firrtl.PrimOp::Orr => {
      let known_one = (a.known_mask & a.raw) != 0
      Some(if known_one { SimValue::from_int(1, 1) } else if a.is_known() { SimValue::zero(1) } else { SimValue::new(1, 0, known=false) })
    }
    @firrtl.PrimOp::Xorr => if a.is_known() { None } else { Some(SimValue::new(1, 0, known=false)) }
    _ => None
  }
}

fn eval_prim_fast(
  op: PrimOp,
  values: Array[SimValue],
  width: Int,
  signed: Bool,
) -> SimValue {
  let a = values.get(0).unwrap_or(SimValue::zero(width))
  let b = values.get(1).unwrap_or(SimValue::zero(width))
  let ar = a.raw.to_int()
  let br = b.raw.to_int()
  let av = if signed { signed_int(a) } else { ar }
  let bv = if signed { signed_int(b) } else { br }
  let shift = if br < 0 { 0 } else { br }
  let result: Int = match op {
    @firrtl.PrimOp::AsUInt | @firrtl.PrimOp::AsSInt | @firrtl.PrimOp::AsClock | @firrtl.PrimOp::AsAsyncReset | @firrtl.PrimOp::Cvt => ar
    @firrtl.PrimOp::Neg => -av
    @firrtl.PrimOp::Not => normalize_int((1 << a.width) - 1 - ar, width)
    @firrtl.PrimOp::And => av & bv
    @firrtl.PrimOp::Or => av | bv
    @firrtl.PrimOp::Xor => av ^ bv
    @firrtl.PrimOp::Add => av + bv
    @firrtl.PrimOp::Sub => av - bv
    @firrtl.PrimOp::Mul => av * bv
    @firrtl.PrimOp::Div => if bv == 0 { 0 } else { av / bv }
    @firrtl.PrimOp::Rem => if bv == 0 { 0 } else { av % bv }
    @firrtl.PrimOp::Lt => (av < bv).to_int()
    @firrtl.PrimOp::Leq => (av <= bv).to_int()
    @firrtl.PrimOp::Gt => (av > bv).to_int()
    @firrtl.PrimOp::Geq => (av >= bv).to_int()
    @firrtl.PrimOp::Eq => (av == bv).to_int()
    @firrtl.PrimOp::Neq => (av != bv).to_int()
    @firrtl.PrimOp::Dshl => if shift >= 31 { 0 } else { av << shift }
    @firrtl.PrimOp::Dshr => if shift >= 31 { if signed && av < 0 { -1 } else { 0 } } else if signed { av >> shift } else { ar >> shift }
    @firrtl.PrimOp::Cat => {
      let mut result = 0
      for value in values {
        let amount = value.width
        result = (result << amount) | value.raw.to_int()
      }
      result
    }
    @firrtl.PrimOp::Pad => av
    @firrtl.PrimOp::Shl => if shift >= 31 { 0 } else { ar << shift }
    @firrtl.PrimOp::Shr => if shift >= 31 {
      if signed && av < 0 { -1 } else { 0 }
    } else if signed { av >> shift } else { ar >> shift }
    @firrtl.PrimOp::Head => if a.width <= width { ar } else { ar >> (a.width - width) }
    @firrtl.PrimOp::Tail => ar & mask_int(width)
    @firrtl.PrimOp::Bits => {
      let lo = values.get(2).map(v => v.raw.to_int()).unwrap_or(0)
      if lo >= a.width { 0 } else { (ar >> lo) & mask_int(width) }
    }
    @firrtl.PrimOp::Andr => all_bits_fast(a).to_int()
    @firrtl.PrimOp::Orr => (ar != 0).to_int()
    @firrtl.PrimOp::Xorr => parity_fast(a)
  }
  with_known(SimValue::from_int(width, normalize_int(result, width)), values.iter().all(v => v.is_known()))
}

fn eval_prim_big(
  op: PrimOp,
  values: Array[SimValue],
  width: Int,
  signed: Bool,
) -> SimValue {
  let a = values.get(0).unwrap_or(SimValue::zero(width))
  let b = values.get(1).unwrap_or(SimValue::zero(width))
  let av = if signed { signed_value(a) } else { a.raw }
  let bv = if signed { signed_value(b) } else { b.raw }
  let result: BigInt = match op {
    @firrtl.PrimOp::AsUInt | @firrtl.PrimOp::AsSInt | @firrtl.PrimOp::AsClock | @firrtl.PrimOp::AsAsyncReset | @firrtl.PrimOp::Cvt => a.raw
    @firrtl.PrimOp::Neg => -av
    @firrtl.PrimOp::Not => normalize((1 << a.width) - 1 - a.raw, width)
    @firrtl.PrimOp::And => av & bv
    @firrtl.PrimOp::Or => av | bv
    @firrtl.PrimOp::Xor => av ^ bv
    @firrtl.PrimOp::Add => av + bv
    @firrtl.PrimOp::Sub => av - bv
    @firrtl.PrimOp::Mul => av * bv
    @firrtl.PrimOp::Div => if bv == 0 { 0 } else { av / bv }
    @firrtl.PrimOp::Rem => if bv == 0 { 0 } else { av % bv }
    @firrtl.PrimOp::Lt => BigInt::from_int((av < bv).to_int())
    @firrtl.PrimOp::Leq => BigInt::from_int((av <= bv).to_int())
    @firrtl.PrimOp::Gt => BigInt::from_int((av > bv).to_int())
    @firrtl.PrimOp::Geq => BigInt::from_int((av >= bv).to_int())
    @firrtl.PrimOp::Eq => BigInt::from_int((av == bv).to_int())
    @firrtl.PrimOp::Neq => BigInt::from_int((av != bv).to_int())
    @firrtl.PrimOp::Dshl => if b.raw >= BigInt::from_int(width) { 0 } else { av << b.raw.to_int() }
    @firrtl.PrimOp::Dshr => if b.raw >= BigInt::from_int(a.width) {
      if signed && av < 0 { -1 } else { 0 }
    } else if signed { av >> b.raw.to_int() } else { a.raw >> b.raw.to_int() }
    @firrtl.PrimOp::Cat => {
      let mut result = BigInt::from_int(0)
      for value in values { result = (result << value.width) | value.raw }
      result
    }
    @firrtl.PrimOp::Pad => av
    @firrtl.PrimOp::Shl => if b.raw >= BigInt::from_int(width) { 0 } else { a.raw << b.raw.to_int() }
    @firrtl.PrimOp::Shr => if b.raw >= BigInt::from_int(a.width) {
      if signed && av < 0 { -1 } else { 0 }
    } else if signed { av >> b.raw.to_int() } else { a.raw >> b.raw.to_int() }
    @firrtl.PrimOp::Head => a.raw >> (a.width - width)
    @firrtl.PrimOp::Tail => a.raw & mask(width)
    @firrtl.PrimOp::Bits => {
      let lo = values.get(2).unwrap_or(SimValue::zero(1)).raw
      if lo >= BigInt::from_int(a.width) { 0 } else { (a.raw >> lo.to_int()) & mask(width) }
    }
    @firrtl.PrimOp::Andr => BigInt::from_int(all_bits(a).to_int())
    @firrtl.PrimOp::Orr => BigInt::from_int(any_bits(a).to_int())
    @firrtl.PrimOp::Xorr => BigInt::from_int(parity(a).to_int())
  }
  SimValue::new(width, result, known=values.iter().all(v => v.is_known()))
}

fn type_width(ty: Type) -> Int {
  match ty {
    @firrtl.Type::UInt(width) | @firrtl.Type::SInt(width) => width
    @firrtl.Type::Clock | @firrtl.Type::Reset | @firrtl.Type::AsyncReset => 1
    @firrtl.Type::Const(inner) => type_width(inner)
    @firrtl.Type::Bundle(fields) => fields.iter().fold(init=0, (n, f) => n + type_width(f.ty))
    @firrtl.Type::Vec(inner, size) => type_width(inner) * size
  }
}

fn type_signed(ty: Type) -> Bool {
  match ty {
    @firrtl.Type::SInt(_) => true
    @firrtl.Type::Const(inner) => type_signed(inner)
    _ => false
  }
}

fn clock_name(expr: TypedExpr) -> String raise SimulatorError {
  match expr {
    @firrtl.Expr::Reference(@firrtl.Reference::Id(id, ..), ..) => id.inner()
    _ => raise Unsupported(message="clock expressions must be direct references")
  }
}

fn ref_name(reference: TypedRef) -> String {
  match reference {
    @firrtl.Reference::Id(id, ..) => id.inner()
    @firrtl.Reference::StaticIndexing(lhs~, index~, ..) => ref_name(lhs) + "[" + index.to_string() + "]"
    @firrtl.Reference::DynamicIndexing(lhs~, ..) => ref_name(lhs)
    @firrtl.Reference::FieldAccess(lhs~, field~, ..) => ref_name(lhs) + "." + field.inner()
  }
}

fn normalize(value: BigInt, width: Int) -> BigInt {
  if width <= 0 { 0 } else { value & mask(width) }
}

fn normalize_int(value: Int, width: Int) -> Int {
  if width <= 0 { 0 } else { value & mask_int(width) }
}

fn mask_int(width: Int) -> Int {
  if width <= 0 { 0 } else { (1 << width) - 1 }
}

fn signed_int(value: SimValue) -> Int {
  let raw = value.raw.to_int()
  if value.width > 0 && ((raw >> (value.width - 1)) & 1) != 0 {
    raw - (1 << value.width)
  } else {
    raw
  }
}

fn all_bits_fast(value: SimValue) -> Bool {
  value.raw.to_int() == mask_int(value.width)
}

fn parity_fast(value: SimValue) -> Int {
  let mut x = value.raw.to_int()
  let mut result = false
  for _ in 0..<value.width {
    result = if (x & 1) != 0 { !result } else { result }
    x = x >> 1
  }
  result.to_int()
}

fn with_known(value: SimValue, known: Bool) -> SimValue {
  SimValue::new(value.width, value.raw, known~)
}

fn mask(width: Int) -> BigInt {
  if width <= 0 { 0 } else { (BigInt::from_int(1) << width) - 1 }
}

fn signed_value(value: SimValue) -> BigInt {
  if value.width > 0 && ((value.raw >> (value.width - 1)) & 1) != 0 {
    value.raw - (BigInt::from_int(1) << value.width)
  } else {
    value.raw
  }
}

fn any_bits(value: SimValue) -> Bool {
  value.raw != 0
}

fn all_bits(value: SimValue) -> Bool {
  value.raw == mask(value.width)
}

fn parity(value: SimValue) -> Bool {
  let mut x = value.raw
  let mut result = false
  for _ in 0..<value.width {
    result = if (x & 1) != 0 { !result } else { result }
    x = x >> 1
  }
  result
}

fn type_width_for_name(sim: Simulator, name: String) -> Int {
  for port in sim.design.ports {
    if port.id.inner() == name { return type_width(port.ty) }
  }
  sim.signals.get(name).map(v => v.width).unwrap_or(0)
}

/// A small procedural facade intended for native testbenches and the
/// playground host API.
pub(all) struct Testbench {
  simulator: Simulator
  mut cycles: Int
}

pub fn Simulator::testbench(self: Simulator) -> Testbench {
  { simulator: self, cycles: 0 }
}

pub fn Testbench::poke(self: Testbench, name: String, value: SimValue) -> Unit raise SimulatorError {
  self.simulator.poke(name, value)
}

pub fn Testbench::peek(self: Testbench, name: String) -> SimValue raise SimulatorError {
  self.simulator.peek(name)
}

pub fn Testbench::settle(self: Testbench) -> Unit raise SimulatorError {
  self.simulator.settle()
}

pub fn Testbench::step(self: Testbench, clock: String) -> Unit raise SimulatorError {
  self.simulator.step_clock(clock)
  self.cycles += 1
}

pub fn Testbench::expect(self: Testbench, name: String, expected: SimValue) -> Unit raise SimulatorError {
  let actual = self.simulator.peek(name)
  if actual.raw != expected.raw || actual.known_mask != expected.known_mask {
    raise ExpectationFailed(name~, expected=Show::to_string(expected), actual=Show::to_string(actual))
  }
}

pub fn Testbench::run(self: Testbench, clock: String, cycles: Int) -> Unit raise SimulatorError {
  if cycles < 0 { raise Unsupported(message="testbench cycle count must be non-negative") }
  for _ in 0..<cycles { self.step(clock) }
}

pub fn Testbench::cycle(self: Testbench) -> Int { self.cycles }

pub fn Testbench::simulator(self: Testbench) -> Simulator { self.simulator }

/// A semantic video sink for simulation-only adapters. Hardware wrappers can
/// turn the same logical pixels into VGA timing; the playground can render the
/// completed buffer directly.
pub(all) struct Framebuffer {
  width: Int
  height: Int
  pixels: Array[Int]
}

pub fn Framebuffer::new(width: Int, height: Int) -> Framebuffer {
  let pixels = Array::new(capacity=width * height)
  for _ in 0..<(width * height) { pixels.push(0) }
  { width, height, pixels }
}

pub fn Framebuffer::width(self: Framebuffer) -> Int { self.width }

pub fn Framebuffer::height(self: Framebuffer) -> Int { self.height }

pub fn Framebuffer::clear(self: Framebuffer, color~: Int = 0) -> Unit {
  for i in 0..<self.pixels.length() { self.pixels[i] = color }
}

pub fn Framebuffer::write(self: Framebuffer, x: Int, y: Int, red: Int, green: Int, blue: Int) -> Unit {
  if x < 0 || x >= self.width || y < 0 || y >= self.height { return }
  let color = ((red & 255) << 16) | ((green & 255) << 8) | (blue & 255)
  self.pixels[y * self.width + x] = color
}

pub fn Framebuffer::pixel(self: Framebuffer, x: Int, y: Int) -> Int {
  if x < 0 || x >= self.width || y < 0 || y >= self.height { return 0 }
  self.pixels[y * self.width + x]
}

pub fn Framebuffer::pixels(self: Framebuffer) -> Array[Int] { self.pixels }

pub(all) struct TextSink {
  mut bytes: Array[Int]
}

pub fn TextSink::new() -> TextSink { { bytes: [] } }

pub fn TextSink::write(self: TextSink, byte: Int) -> Unit {
  self.bytes.push(byte & 255)
}

pub fn TextSink::bytes(self: TextSink) -> Array[Int] { self.bytes }

pub fn TextSink::text(self: TextSink) -> String {
  let builder = StringBuilder()
  for byte in self.bytes {
    builder.write_char(byte.to_char().unwrap_or('\u{0}'))
  }
  builder.to_string()
}

// JavaScript-facing helpers expose a legacy integer view plus a lossless
// signal view. Native callers can use SimValue::new directly.
pub(all) struct SimulatorSignal {
  name: String
  width: Int
  value: String
  known: Bool
}
pub fn simulator_new(circuit: TypedCircuit, top: String) -> Simulator raise SimulatorError {
  Simulator::from_circuit(circuit, top)
}

pub fn simulator_poke_int(simulator: Simulator, name: String, width: Int, value: Int) -> Unit raise SimulatorError {
  simulator.poke(name, SimValue::from_int(width, value))
}

pub fn simulator_peek_int(simulator: Simulator, name: String) -> Int raise SimulatorError {
  simulator.peek(name).raw.to_int()
}

pub fn simulator_step(simulator: Simulator, clock: String) -> Unit raise SimulatorError {
  simulator.step_clock(clock)
}

pub fn simulator_settle(simulator: Simulator) -> Unit raise SimulatorError {
  simulator.settle()
}

pub fn simulator_messages(simulator: Simulator) -> Array[String] {
  simulator.messages().map(message => message.text())
}

pub fn simulator_drain_events(simulator: Simulator) -> Array[SimMessage] {
  simulator.drain_events()
}

pub fn simulator_status(simulator: Simulator) -> SimulationStatus {
  simulator.status()
}

/// JavaScript hosts use -1 for the absence of a stop code because nullable
/// MoonBit options are represented differently across JS toolchain releases.
pub fn simulator_exit_code(simulator: Simulator) -> Int {
  simulator.exit_code().unwrap_or(-1)
}

pub fn simulator_set_history_retention(simulator: Simulator, retain: Bool) -> Unit {
  simulator.set_history_retention(retain)
}

/// Legacy integer output view retained for native callers. New hosts should
/// use `simulator_output_signals` so wide values and unknown state survive the
/// boundary.
pub fn simulator_outputs(simulator: Simulator) -> Array[(String, Int)] {
  let outputs = []
  for port in simulator.design.ports {
    if port.dir is @parse.PortDir::Output {
      let name = port.id.inner()
      let value = simulator.signals.get(name).unwrap_or(SimValue::zero(type_width(port.ty)))
      outputs.push((name, value.raw.to_int()))
    }
  }
  outputs
}

pub fn simulator_output_signals(simulator: Simulator) -> Array[SimulatorSignal] {
  let outputs = []
  for port in simulator.design.ports {
    if port.dir is @parse.PortDir::Output {
      let name = port.id.inner()
      let value = simulator.signals.get(name).unwrap_or(SimValue::zero(type_width(port.ty)))
      outputs.push({ name, width: type_width(port.ty), value: value.raw.to_string(), known: value.is_known() })
    }
  }
  outputs
}

pub fn simulator_inputs(simulator: Simulator) -> Array[SimulatorSignal] {
  let inputs = []
  for port in simulator.design.ports {
    if port.dir is @parse.PortDir::Input && !(port.ty is @firrtl.Type::Clock) {
      let name = port.id.inner()
      let value = simulator.signals.get(name).unwrap_or(SimValue::zero(type_width(port.ty)))
      inputs.push({ name, width: type_width(port.ty), value: value.raw.to_string(), known: value.is_known() })
    }
  }
  inputs
}

pub fn simulator_clocks(simulator: Simulator) -> Array[String] {
  let clocks = []
  for port in simulator.design.ports {
    if port.ty is @firrtl.Type::Clock {
      clocks.push(port.id.inner())
    }
  }
  clocks
}

/// Read display storage directly, without decimal strings or scalar host maps.
/// Boolean rows are packed execution values; color elements are RGB integers.
pub(all) struct SimulatorFrame {
  words: Array[UInt]
  valid: Array[UInt]
}

pub fn simulator_frame(simulator: Simulator, ports: Array[String], width: Int, height: Int, binary: Bool) -> SimulatorFrame raise SimulatorError {
  simulator_frame_with_layout(simulator, ports, width, height, packed_rows=binary, binary~)
}

/// Read display values using storage metadata that is independent from the
/// requested rendering mode. `packed_rows` is true only for lowered Boolean
/// rows; integer pixels are never reinterpreted as packed storage.
pub fn simulator_frame_with_layout(
  simulator: Simulator,
  ports: Array[String],
  width: Int,
  height: Int,
  packed_rows~: Bool,
  binary~: Bool,
) -> SimulatorFrame raise SimulatorError {
  let words: Array[UInt] = []
  let valid: Array[UInt] = []
  for row in 0..<height {
    if packed_rows {
      let value = simulator.peek(ports[row])
      for word in 0..<((width + 31) / 32) {
        words.push(((value.raw >> (word * 32)) & mask(32)).to_uint())
        valid.push(((value.known_mask >> (word * 32)) & mask(32)).to_uint())
      }
    } else if binary {
      for word in 0..<((width + 31) / 32) {
        let mut packed = 0U
        let mut packed_valid = 0U
        for bit in 0..<32 {
          let col = word * 32 + bit
          if col >= width { continue }
          let value = simulator.peek(ports[row * width + col])
          if value.raw != 0 { packed = packed | (1U << bit) }
          if value.is_known() { packed_valid = packed_valid | (1U << bit) }
        }
        words.push(packed)
        valid.push(packed_valid)
      }
    } else {
      for col in 0..<width {
        let value = simulator.peek(ports[row * width + col])
        words.push((value.raw & mask(32)).to_uint())
        valid.push(if value.is_known() { 0xffffffffU } else { 0U })
      }
    }
  }
  { words, valid }
}

pub fn simulator_halted(simulator: Simulator) -> Bool { simulator.halted }

pub fn simulator_visible_outputs(simulator: Simulator, hidden: Array[String]) -> Array[SimulatorSignal] {
  let hidden = Set::from_array(hidden)
  let outputs = []
  for port in simulator.design.ports {
    let name = port.id.inner()
    if port.dir is @parse.PortDir::Output && !hidden.contains(name) {
      let value = simulator.peek(name) catch { _ => SimValue::new(type_width(port.ty), 0, known=false) }
      outputs.push({ name, width: value.width, value: value.raw.to_string(), known: value.is_known() })
    }
  }
  outputs
}

pub(all) struct SimulatorRaster {
  signal: String
  ports: Array[String]
  width: Int
  height: Int
  pixels: Array[UInt]
  valid: Array[UInt]
  mut frames: Int
  mut started: Bool
  mut at_origin: Bool
}

pub fn simulator_raster_new(simulator: Simulator, signal: String, width: Int, height: Int) -> SimulatorRaster raise SimulatorError {
  simulator_raster_new_with_ports(simulator, signal, ["x", "y", "valid", "r", "g", "b"].map(suffix => signal + "_" + suffix), width, height)
}

pub fn simulator_raster_new_with_ports(simulator: Simulator, signal: String, ports: Array[String], width: Int, height: Int) -> SimulatorRaster raise SimulatorError {
  if ports.length() != 6 { raise Unsupported(message="pixel stream requires six resolved fields") }
  for index, name in ports {
    if !simulator.design.ports.iter().any(p => p.id.inner() == name && p.dir is @parse.PortDir::Output) {
      raise Unsupported(message="pixel stream requires output '\{name}'")
    }
    let value = simulator.peek(name)
    if index >= 3 && (value.width < 1 || value.width > 8) {
      raise Unsupported(message="pixel stream color channels must have 1 to 8 bits")
    }
  }
  { signal, ports, width, height, pixels: Array::make(width * height, 0U), valid: Array::make(width * height, 0U), frames: 0, started: false, at_origin: false }
}

/// Sample the pre-edge pixel, then advance the hardware. The worker calls this
/// in bounded chunks so playback and frame stepping remain interruptible.
pub fn simulator_raster_step(simulator: Simulator, raster: SimulatorRaster, clock: String, cycles: Int, until_frame: Bool) -> Int raise SimulatorError {
  let target = raster.frames + 1
  let mut advanced = 0
  for _ in 0..<cycles {
    if simulator.halted { break }
    let x = simulator.peek(raster.ports[0])
    let y = simulator.peek(raster.ports[1])
    let valid = simulator.peek(raster.ports[2])
    if (x.is_known() && x.raw != 0) || (y.is_known() && y.raw != 0) || (valid.is_known() && valid.raw == 0) {
      raster.at_origin = false
    }
    if x.is_known() && y.is_known() && valid.is_known() && valid.raw != 0 {
      let col = x.raw.to_int()
      let row = y.raw.to_int()
      if col == 0 && row == 0 {
        if !raster.at_origin && raster.started { raster.frames += 1 }
        raster.at_origin = true
        raster.started = true
        if until_frame && raster.frames >= target { break }
      } else {
        raster.at_origin = false
      }
      if col >= 0 && col < raster.width && row >= 0 && row < raster.height {
        let r = simulator.peek(raster.ports[3])
        let g = simulator.peek(raster.ports[4])
        let b = simulator.peek(raster.ports[5])
        let red = (r.raw.to_int() * 255 / ((1 << r.width) - 1)).reinterpret_as_uint()
        let green = (g.raw.to_int() * 255 / ((1 << g.width) - 1)).reinterpret_as_uint()
        let blue = (b.raw.to_int() * 255 / ((1 << b.width) - 1)).reinterpret_as_uint()
        raster.pixels[row * raster.width + col] = (red << 16) | (green << 8) | blue
        raster.valid[row * raster.width + col] = if r.is_known() && g.is_known() && b.is_known() { 0xffffffffU } else { 0U }
      }
    }
    simulator.step_clock(clock)
    advanced += 1
    if until_frame && raster.frames >= target { break }
  }
  advanced
}


// Lowering may place temporary nodes before their source connections. Order
// combinational producers before consumers once, rather than propagating a
// partially settled value down a long feed-forward chain on every iteration.
fn order_simulation_body(body: Array[@firrtl.TypedStmt]) -> Array[@firrtl.TypedStmt] {
  // Hand-built FIRRTL can contain ordered conditional/multiple assignments.
  // Preserve that order; the compiler normalizes them before this optimization.
  let assigned: Set[String] = Set([])
  for stmt in body {
    match stmt {
      @firrtl.Stmt::When(_) => return body
      @firrtl.Stmt::Connect(lhs, _) => {
        let name = ref_name(lhs)
        if assigned.contains(name) { return body }
        assigned.add(name)
      }
      _ => ()
    }
  }
  let registers: Set[String] = Set([])
  for stmt in body {
    match stmt {
      @firrtl.Stmt::Reg(id~, ..) | @firrtl.Stmt::RegReset(id~, ..) => { registers.add(id.inner()) }
      _ => ()
    }
  }
  let producers: Map[String, Array[Int]] = Map([])
  for i, stmt in body {
    match stmt {
      @firrtl.Stmt::Node(id~, ..) => add_dependent(producers, id.inner(), i)
      @firrtl.Stmt::Connect(lhs, _) => {
        let name = ref_name(lhs)
        if !registers.contains(name) { add_dependent(producers, name, i) }
      }
      _ => ()
    }
  }
  let successors: Array[Array[Int]] = Array::makei(body.length(), _ => [])
  let indegree = Array::make(body.length(), 0)
  for i, stmt in body {
    let refs = []
    collect_stmt_refs(stmt, refs)
    let dependencies: Array[Int] = []
    for reference in refs {
      for producer in producers.get(reference).unwrap_or([]) {
        if !dependencies.contains(producer) { dependencies.push(producer) }
      }
    }
    indegree[i] = dependencies.length()
    for producer in dependencies { successors[producer].push(i) }
  }
  let queue: Array[Int] = []
  for i, count in indegree { if count == 0 { queue.push(i) } }
  let ordered = []
  let mut cursor = 0
  while cursor < queue.length() {
    let index = queue[cursor]
    cursor += 1
    ordered.push(body[index])
    for successor in successors[index] {
      indegree[successor] -= 1
      if indegree[successor] == 0 { queue.push(successor) }
    }
  }
  // Cyclic graphs still go through the ordinary convergence diagnostic.
  if ordered.length() == body.length() { ordered } else { body }
}

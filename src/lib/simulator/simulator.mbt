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
  type Command,
}

pub(all) struct SimValue {
  width: Int
  raw: BigInt
  known: Bool
}

pub fn SimValue::new(width: Int, raw: BigInt, known~: Bool = true) -> SimValue {
  { width, raw: normalize(raw, width), known }
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
  self.known
}

pub fn SimValue::bit(self: SimValue, index: Int) -> SimValue {
  if index < 0 || index >= self.width {
    SimValue::new(1, 0, known=false)
  } else {
    SimValue::new(1, (self.raw >> index) & 1, known=self.known)
  }
}

pub impl Show for SimValue with output(self, logger) {
  if self.known {
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
  When(cond~: SimExpr, body~: Array[SimStmt], otherwise~: Array[SimStmt])
  Other
}

/// A host-provided implementation for an external FIRRTL module.  Models are
/// invoked after their input ports are propagated; they can read inputs with
/// peek() and drive outputs with poke().
pub(all) struct PrimitiveModel {
  eval: (Simulator) -> Unit raise SimulatorError
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
}

pub fn SimMessage::kind(self: SimMessage) -> String { self.kind }

pub fn SimMessage::text(self: SimMessage) -> String { self.text }

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
  reset: TypedExpr?
  init: TypedExpr?
  previous_clock: Bool
}

struct MemoryState {
  width: Int
  depth: Int
  read_latency: Int
  write_latency: Int
  read_under_write: @firrtl.ReadUnderWrite
  readers: Array[String]
  writers: Array[String]
  readwriters: Array[String]
  data: Array[SimValue]
  read_data: Map[String, SimValue]
}

priv struct MemoryWrite {
  address: Int
  data: SimValue
  mask: SimValue
}

pub(all) struct Simulator {
  design: TypedModule
  program: Array[SimStmt]
  signals: Map[String, SimValue]
  registers: Map[String, RegisterState]
  next_registers: Map[String, SimValue]
  memories: Map[String, MemoryState]
  clocks: Map[String, Bool]
  messages: Array[SimMessage]
  mut halted: Bool
  mut exit_code: Int?
  mut failure: String?
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
  mut pending: Array[Int]
  mut queued: Array[Bool]
  primitive_models: Map[String, PrimitiveModel]
  primitive_model: PrimitiveModel?
}

pub fn Simulator::new(design: TypedModule) -> Simulator raise SimulatorError {
  Simulator::new_with_modules(design, modules=Map([]), primitive_models=Map([]), primitive_model=None)
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
      // `LifeSim` becomes `Life_LifeSim`).  Accept the source-level leaf name
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
  Simulator::new_with_modules(design, modules~, primitive_models~, primitive_model=None)
}

fn Simulator::new_with_modules(
  design: TypedModule,
  modules~: Map[String, TypedModule],
  primitive_models~: Map[String, PrimitiveModel],
  primitive_model~: PrimitiveModel?,
) -> Simulator raise SimulatorError {
  let design = { ..design, body: order_simulation_body(design.body) }
  let signals: Map[String, SimValue] = Map([])
  let registers: Map[String, RegisterState] = Map([])
  let next_registers: Map[String, SimValue] = Map([])
  let memories: Map[String, MemoryState] = Map([])
  let clocks: Map[String, Bool] = Map([])
  let children: Map[String, Simulator] = Map([])
  let child_message_offsets: Map[String, Int] = Map([])
  let memory_clocks: Map[String, String] = Map([])
  let program = design.body.map(compile_stmt)
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
        let width = type_width(ty)
        signals[name] = SimValue::new(width, 0, known=false)
        registers[name] = {
          name, width, clock, reset: None, init: None, previous_clock: false,
        }
        next_registers[name] = signals[name]
      }
      @firrtl.Stmt::RegReset(id~, ty~, clock~, reset~, init~) => {
        let name = id.inner()
        let clock = clock_name(clock)
        let width = type_width(ty)
        signals[name] = SimValue::new(width, 0, known=false)
        registers[name] = {
          name, width, clock, reset: Some(reset), init: Some(init), previous_clock: false,
        }
        next_registers[name] = signals[name]
      }
      @firrtl.Stmt::Mem(mem) => {
        let id = mem.id.inner()
        let width = type_width(mem.data_type)
        let data = Array::new(capacity=mem.depth)
        for _ in 0..<mem.depth { data.push(SimValue::new(width, 0, known=false)) }
        memories[id] = {
          width,
          depth: mem.depth,
          read_latency: mem.read_latency,
          write_latency: mem.write_latency,
          read_under_write: mem.read_under_write,
          readers: mem.readers.map(id => id.inner()),
          writers: mem.writers.map(id => id.inner()),
          readwriters: mem.readwriters.map(id => id.inner()),
          data,
          read_data: Map([]),
        }
        for reader in mem.readers {
          let name = id + "." + reader.inner()
          if find_signal_source(design, name + ".clk") is Some(clock) {
            memory_clocks[name] = clock
          }
        }
        for writer in mem.writers {
          let name = id + "." + writer.inner()
          if find_signal_source(design, name + ".clk") is Some(clock) {
            memory_clocks[name] = clock
          }
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
    halted: false,
    exit_code: None,
    failure: None,
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
    primitive_models,
    primitive_model,
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
    @firrtl.Stmt::Connect(lhs, rhs) => SimStmt::Connect(name=ref_name(lhs), expr=compile_expr(rhs))
    @firrtl.Stmt::When(when) => SimStmt::When(
      cond=compile_expr(when.cond),
      body=when.body.map(compile_stmt),
      otherwise=when.otherwise.unwrap_or([]).map(compile_stmt),
    )
    _ => SimStmt::Other
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
      let signed = match op {
        @firrtl.PrimOp::Lt | @firrtl.PrimOp::Leq | @firrtl.PrimOp::Gt | @firrtl.PrimOp::Geq =>
          args.get(0).map(expr => type_signed(expr.ty())).unwrap_or(false)
        _ => type_signed(ty)
      }
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

pub fn Simulator::is_halted(self: Simulator) -> Bool { self.halted }

pub fn Simulator::exit_code(self: Simulator) -> Int? { self.exit_code }

pub fn Simulator::failure(self: Simulator) -> String? { self.failure }

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
  let _ = self.assign_signal(name, SimValue::new(type_width_for_name(self, name), value.raw, known=value.known))
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
    SimStmt::When(cond~, body~, otherwise~) => {
      let condition = self.eval_compiled_expr(cond)
      if !condition.known {
        // A conditional assignment with an unknown predicate cannot safely
        // choose one branch. Mark the values written by either branch as
        // unknown instead of silently taking the false branch.
        let names = []
        for nested in body { collect_sim_stmt_assignments(nested, names) }
        for nested in otherwise { collect_sim_stmt_assignments(nested, names) }
        for name in names {
          match self.signals.get(name) {
            Some(value) => {
              let unknown = SimValue::new(value.width, 0, known=false)
              if self.registers.contains(name) {
                self.next_registers[name] = unknown
              } else {
                let _ = self.assign_signal(name, unknown)
              }
            }
            None => ()
          }
        }
      } else {
        let selected = if condition.raw != 0 { body } else { otherwise }
        for nested in selected {
          self.eval_combinational_stmt(nested)
        }
      }
    }
    SimStmt::Other => ()
  }
}

fn collect_sim_stmt_assignments(stmt: SimStmt, names: Array[String]) -> Unit {
  match stmt {
    SimStmt::Connect(name~, ..) => if !names.contains(name) { names.push(name) }
    SimStmt::When(body~, otherwise~, ..) => {
      for nested in body { collect_sim_stmt_assignments(nested, names) }
      for nested in otherwise { collect_sim_stmt_assignments(nested, names) }
    }
    _ => ()
  }
}

fn Simulator::eval_compiled_expr(self: Simulator, expr: SimExpr) -> SimValue raise SimulatorError {
  match expr {
    SimExpr::Signal(name~, width~) => self.signals.get(name).unwrap_or(SimValue::new(width, 0, known=false))
    SimExpr::MemoryData(memory~, reader~, width~) => self.eval_memory_data(memory, reader, width)
    SimExpr::Slice(source~, index~, width~) => {
      let value = self.eval_compiled_expr(source)
      SimValue::new(width, value.raw >> (index * width), known=value.known)
    }
    SimExpr::Literal(value~) => value
    SimExpr::Mux(cond~, tval~, fval~) => {
      let condition = self.eval_compiled_expr(cond)
      if condition.known {
        return self.eval_compiled_expr(if condition.raw != 0 { tval } else { fval })
      }
      let when_true = self.eval_compiled_expr(tval)
      let when_false = self.eval_compiled_expr(fval)
      if !condition.known {
        // Four-state mux semantics: an unknown selector can still produce a
        // known result when both arms agree. Otherwise preserve X instead of
        // silently choosing the false arm from the raw backing bit.
        if when_true.known && when_false.known && when_true.raw == when_false.raw {
          when_true
        } else {
          SimValue::new(when_true.width, 0, known=false)
        }
      } else if condition.raw != 0 {
        when_true
      } else {
        when_false
      }
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
    if input_changed || child.pending.length() > 0 {
      match child.primitive_model {
        Some(model) => (model.eval)(child)
        None => child.settle()
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
    let is_async = match reg.reset {
      Some(expr) => expr.ty() is @firrtl.Type::AsyncReset
      None => false
    }
    if !is_async { continue }
    let asserted = match reg.reset {
      Some(expr) => self.eval_expr(expr).raw != 0
      None => false
    }
    if !asserted { continue }
    let value = match reg.init {
      Some(expr) => self.eval_expr(expr)
      None => SimValue::zero(reg.width)
    }
    let _ = self.assign_signal(name, value)
    self.next_registers[name] = value
  }
}

pub fn Simulator::step_clock(self: Simulator, name: String) -> Unit raise SimulatorError {
  if self.halted { return }
  self.set_clock(name, true)
  self.set_clock(name, false)
  self.cycle += 1
}

fn Simulator::commit_clock(self: Simulator, clock: String) -> Unit raise SimulatorError {
  self.commit_children(clock)
  for name, reg in self.registers {
    if reg.clock != clock { continue }
    let reset = match reg.reset {
      Some(expr) => self.eval_expr(expr).raw != 0
      None => false
    }
    let value = if reset {
      match reg.init {
        Some(expr) => self.eval_expr(expr)
        None => SimValue::zero(reg.width)
      }
    } else {
      self.next_registers.get(name).unwrap_or(self.signals[name])
    }
    let _ = self.assign_signal(name, value)
    self.next_registers[name] = value
  }
  self.commit_memories(clock)
  self.run_commands(clock)
  self.settle()
}

fn Simulator::commit_children(self: Simulator, clock: String) -> Unit raise SimulatorError {
  for instance, child in self.children {
    for port in child.design.ports {
      if port.dir is @parse.PortDir::Input && port.ty is @firrtl.Type::Clock {
        let source = clock_source(self.design, instance, port.id.inner())
        if source == Some(clock) && child.clocks.get(port.id.inner()).unwrap_or(false) {
          child.commit_clock(port.id.inner())
        }
      }
    }
    let offset = self.child_message_offsets.get(instance).unwrap_or(0)
    let child_messages = child.messages()
    for i in offset..<child_messages.length() {
      self.messages.push(child_messages[i])
    }
    self.child_message_offsets[instance] = child_messages.length()
    if child.failure is Some(failure) {
      self.failure = Some(failure)
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
      ) if id.inner() == instance && field.inner() == port => return Some(clock.inner())
      _ => ()
    }
  }
  None
}

fn find_signal_source(design: TypedModule, target: String) -> String? {
  for stmt in design.body {
    match stmt {
      @firrtl.Stmt::Connect(lhs, @firrtl.Expr::Reference(@firrtl.Reference::Id(source, ..), ..)) if ref_name(lhs) == target => {
          for port in design.ports {
            if port.id.inner() == source.inner() && port.ty is @firrtl.Type::Clock {
              return Some(source.inner())
            }
          }
          return find_signal_source(design, source.inner())
        }
      _ => ()
    }
  }
  None
}

fn Simulator::commit_memories(self: Simulator, clock: String) -> Unit raise SimulatorError {
  for id, memory in self.memories {
    if memory.read_latency < 0 || memory.read_latency > 1 || memory.write_latency < 0 || memory.write_latency > 1 {
      raise Unsupported(message="memory '{id}' latencies above one cycle are not supported")
    }
    let prefix = id + "."
    let writes : Array[MemoryWrite] = []
    for writer in memory.writers {
      let port = prefix + writer
      let port_clock = self.signal_or_zero(port + ".clk")
      if self.memory_clocks.get(port) is Some(source) && source != clock { continue }
      if port_clock.raw == 0 || self.signal_or_zero(port + ".en").raw == 0 { continue }
      let address = self.signal_or_zero(port + ".addr").raw.to_int()
      if address < 0 || address >= memory.depth { continue }
      let data = self.signal_or_zero(port + ".data")
      let mask_value = self.signal_or_zero(port + ".mask")
      if memory.width > 0 { writes.push({ address, data, mask: mask_value }) }
    }

    for readwriter in memory.readwriters {
      let port = prefix + readwriter
      let port_clock = self.signal_or_zero(port + ".clk")
      if self.memory_clocks.get(port) is Some(source) && source != clock { continue }
      if port_clock.raw == 0 || self.signal_or_zero(port + ".en").raw == 0 { continue }
      let address = self.signal_or_zero(port + ".addr").raw.to_int()
      if address < 0 || address >= memory.depth { continue }
      if self.signal_or_zero(port + ".wmode").raw != 0 {
        let data = self.signal_or_zero(port + ".wdata")
        let mask_value = self.signal_or_zero(port + ".wmask")
        if memory.width > 0 { writes.push({ address, data, mask: mask_value }) }
      } else if memory.read_latency > 0 {
        memory.read_data[readwriter] = memory.read_value(address, writes)
        self.enqueue_signal(port + ".rdata")
      }
    }

    for reader in memory.readers {
      let port = prefix + reader
      let port_clock = self.signal_or_zero(port + ".clk")
      if self.memory_clocks.get(port) is Some(source) && source != clock { continue }
      if port_clock.raw == 0 || self.signal_or_zero(port + ".en").raw == 0 { continue }
      let address = self.signal_or_zero(port + ".addr").raw.to_int()
      if address < 0 || address >= memory.depth { continue }
      if memory.read_latency > 0 {
        memory.read_data[reader] = memory.read_value(address, writes)
        self.enqueue_signal(port + ".data")
      }
    }

    for write in writes {
      memory.data[write.address] = masked_write(memory.data[write.address], write.data, write.mask, memory.width)
    }
    // Zero-latency readers observe writes after the edge.  Queue their users
    // even when no read-data register was updated.
    for reader in memory.readers {
      self.enqueue_signal(prefix + reader + ".data")
    }
    for readwriter in memory.readwriters {
      self.enqueue_signal(prefix + readwriter + ".rdata")
    }
  }
}

fn MemoryState::read_value(self: MemoryState, address: Int, writes: Array[MemoryWrite]) -> SimValue {
  let old = self.data[address]
  let matching = writes.filter(write => write.address == address)
  if matching.is_empty() { return old }
  if matching.length() > 1 {
    return SimValue::new(self.width, 0, known=false)
  }
  let write = matching[0]
  match self.read_under_write {
    @firrtl.ReadUnderWrite::Old => old
    @firrtl.ReadUnderWrite::New => masked_write(old, write.data, write.mask, self.width)
    @firrtl.ReadUnderWrite::Undefined => SimValue::new(self.width, 0, known=false)
  }
}

fn Simulator::live_memory_read(self: Simulator, memory_id: String, memory: MemoryState, reader: String, width: Int) -> SimValue {
  let port = memory_id + "." + reader
  let enabled = self.signal_or_zero(port + ".en")
  let address = self.signal_or_zero(port + ".addr").raw.to_int()
  if enabled.raw == 0 || address < 0 || address >= memory.depth {
    SimValue::new(width, 0, known=false)
  } else {
    memory.data[address]
  }
}

fn Simulator::signal_or_zero(self: Simulator, name: String) -> SimValue {
  self.signals.get(name).unwrap_or(SimValue::zero(1))
}

fn masked_write(old: SimValue, value: SimValue, mask_value: SimValue, width: Int) -> SimValue {
  let granularity = if mask_value.width == 0 { width } else { width / mask_value.width }
  let mut raw = old.raw
  for i in 0..<mask_value.width {
    if ((mask_value.raw >> i) & 1) != 0 {
      let chunk_mask = mask(granularity) << (i * granularity)
      raw = (raw & (mask(width) ^ chunk_mask)) | (value.raw & chunk_mask)
    }
  }
  SimValue::new(width, raw, known=mask_value.known && (mask_value.raw == 0 || value.known) && (mask_value.raw == mask(mask_value.width) || old.known))
}

fn Simulator::run_commands(self: Simulator, clock: String) -> Unit raise SimulatorError {
  for stmt in self.design.body {
    match stmt {
      @firrtl.Stmt::Command(command) => {
        let (clk, en) = command_clock_enable(command, self)
        if clk != clock || en.raw == 0 { continue }
        match command {
          @firrtl.Command::Printf(fmt~, args~, ..) => {
            let mut text = fmt
            for arg in args {
              text = text + " " + Show::to_string(self.eval_expr(arg))
            }
            self.messages.push({ kind: "printf", text })
          }
          @firrtl.Command::Assert(pred~, fmt~, args~, ..) => {
            if self.eval_expr(pred).raw == 0 {
              let mut text = fmt
              for arg in args {
                text = text + " " + Show::to_string(self.eval_expr(arg))
              }
              self.failure = Some(text)
              self.messages.push({ kind: "assert", text })
            }
          }
          @firrtl.Command::Stop(code~, ..) => {
            self.halted = true
            self.exit_code = Some(code)
          }
        }
      }
      _ => ()
    }
  }
}

fn command_clock_enable(command: Command[Type], sim: Simulator) -> (String, SimValue) raise SimulatorError {
  match command {
    @firrtl.Command::Printf(clk~, en~, ..) | @firrtl.Command::Assert(clk~, en~, ..) | @firrtl.Command::Stop(clk~, en~, ..) => {
      (clock_name(clk), sim.eval_expr(en))
    }
  }
}

fn Simulator::assign_signal(self: Simulator, name: String, value: SimValue) -> Bool {
  let old = self.signals.get(name).unwrap_or(SimValue::zero(value.width))
  let value = SimValue::new(old.width, value.raw, known=value.known)
  if old.raw != value.raw || old.known != value.known {
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

fn Simulator::eval_expr(self: Simulator, expr: TypedExpr) -> SimValue raise SimulatorError {
  match expr {
    @firrtl.Expr::Reference(reference, ty~) => self.eval_ref(reference, type_width(ty))
    @firrtl.Expr::Literal(lit, ty~) => SimValue::new(type_width(ty), lit.as_bigint())
    @firrtl.Expr::Mux(cond~, tval~, fval~, ..) => {
      let condition = self.eval_expr(cond)
      if condition.known {
        return self.eval_expr(if condition.raw != 0 { tval } else { fval })
      }
      let when_true = self.eval_expr(tval)
      let when_false = self.eval_expr(fval)
      if !condition.known {
        if when_true.known && when_false.known && when_true.raw == when_false.raw {
          when_true
        } else {
          SimValue::new(when_true.width, 0, known=false)
        }
      } else if condition.raw != 0 {
        when_true
      } else {
        when_false
      }
    }
    @firrtl.Expr::PrimOp(op~, args~, ty~) => {
      let values = args.map((expr: TypedExpr) => self.eval_expr(expr))
      let signed = match op {
        @firrtl.PrimOp::Lt | @firrtl.PrimOp::Leq | @firrtl.PrimOp::Gt | @firrtl.PrimOp::Geq =>
          args.get(0).map(expr => type_signed(expr.ty())).unwrap_or(false)
        _ => type_signed(ty)
      }
      eval_prim(op, values, type_width(ty), signed)
    }
  }
}

fn Simulator::eval_ref(self: Simulator, reference: TypedRef, width: Int) -> SimValue raise SimulatorError {
  match reference {
    @firrtl.Reference::Id(id, ..) => {
      match self.signals.get(id.inner()) {
        Some(value) => value
        None => raise MissingSignal(name=id.inner())
      }
    }
    @firrtl.Reference::StaticIndexing(lhs~, index~, ty~) => {
      let element_width = type_width(ty)
      let source = self.eval_ref(lhs, type_width(lhs.ty()))
      SimValue::new(element_width, source.raw >> (index * element_width), known=source.known)
    }
    @firrtl.Reference::FieldAccess(
      lhs=@firrtl.Reference::FieldAccess(
        lhs=@firrtl.Reference::Id(memory_id, ..),
        field=reader,
        ..
      ),
      field=data_field,
      ..
    ) if data_field.inner() == "data" => {
      match self.memories.get(memory_id.inner()) {
              Some(memory) if memory.read_latency > 0 => memory.read_data.get(reader.inner()).unwrap_or(SimValue::new(width, 0, known=false))
              Some(memory) => self.live_memory_read(memory_id.inner(), memory, reader.inner(), width)
        None => raise MissingSignal(name=memory_id.inner())
      }
    }
    @firrtl.Reference::FieldAccess(lhs~, field~, ..) => {
      let name = ref_name(reference)
      match self.signals.get(name) {
        Some(value) => value
        None => {
          let parts: Array[String] = name.split(".").map(part => part.to_owned()).collect()
          if parts.length() >= 3 && parts[parts.length() - 1] == "data" {
            let memory_id = parts[0]
            let reader = parts[1]
            match self.memories.get(memory_id) {
              Some(memory) if memory.read_latency > 0 => memory.read_data.get(reader).unwrap_or(SimValue::new(width, 0, known=false))
              Some(memory) => self.live_memory_read(memory_id, memory, reader, width)
              None => self.eval_ref(lhs, width)
            }
          } else {
            self.eval_ref(lhs, width)
          }
        }
      }
    }
    @firrtl.Reference::DynamicIndexing(..) => raise Unsupported(message="dynamic references must be expanded before simulation")
  }
}

fn eval_prim(
  op: PrimOp,
  values: Array[SimValue],
  width: Int,
  signed: Bool,
) -> SimValue raise SimulatorError {
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
    @firrtl.PrimOp::And => ar & br
    @firrtl.PrimOp::Or => ar | br
    @firrtl.PrimOp::Xor => ar ^ br
    @firrtl.PrimOp::Add => av + bv
    @firrtl.PrimOp::Sub => av - bv
    @firrtl.PrimOp::Mul => av * bv
    @firrtl.PrimOp::Div => if bv == 0 { 0 } else { av / bv }
    @firrtl.PrimOp::Rem => if bv == 0 { 0 } else { av % bv }
    @firrtl.PrimOp::Lt => (av < bv).to_int()
    @firrtl.PrimOp::Leq => (av <= bv).to_int()
    @firrtl.PrimOp::Gt => (av > bv).to_int()
    @firrtl.PrimOp::Geq => (av >= bv).to_int()
    @firrtl.PrimOp::Eq => (ar == br).to_int()
    @firrtl.PrimOp::Neq => (ar != br).to_int()
    @firrtl.PrimOp::Dshl => if shift >= 31 { 0 } else { ar << shift }
    @firrtl.PrimOp::Dshr => if shift >= 31 { if signed && av < 0 { -1 } else { 0 } } else if signed { av >> shift } else { ar >> shift }
    @firrtl.PrimOp::Cat => {
      let mut result = 0
      for value in values {
        let amount = value.width
        result = (result << amount) | value.raw.to_int()
      }
      result
    }
    @firrtl.PrimOp::Pad => ar
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
  with_known(SimValue::from_int(width, normalize_int(result, width)), values.iter().all(v => v.known))
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
    @firrtl.PrimOp::And => a.raw & b.raw
    @firrtl.PrimOp::Or => a.raw | b.raw
    @firrtl.PrimOp::Xor => a.raw ^ b.raw
    @firrtl.PrimOp::Add => av + bv
    @firrtl.PrimOp::Sub => av - bv
    @firrtl.PrimOp::Mul => av * bv
    @firrtl.PrimOp::Div => if bv == 0 { 0 } else { av / bv }
    @firrtl.PrimOp::Rem => if bv == 0 { 0 } else { av % bv }
    @firrtl.PrimOp::Lt => BigInt::from_int((av < bv).to_int())
    @firrtl.PrimOp::Leq => BigInt::from_int((av <= bv).to_int())
    @firrtl.PrimOp::Gt => BigInt::from_int((av > bv).to_int())
    @firrtl.PrimOp::Geq => BigInt::from_int((av >= bv).to_int())
    @firrtl.PrimOp::Eq => BigInt::from_int((a.raw == b.raw).to_int())
    @firrtl.PrimOp::Neq => BigInt::from_int((a.raw != b.raw).to_int())
    @firrtl.PrimOp::Dshl => a.raw << b.raw.to_int()
    @firrtl.PrimOp::Dshr => if signed { av >> b.raw.to_int() } else { a.raw >> b.raw.to_int() }
    @firrtl.PrimOp::Cat => {
      let mut result = BigInt::from_int(0)
      for value in values { result = (result << value.width) | value.raw }
      result
    }
    @firrtl.PrimOp::Pad => a.raw
    @firrtl.PrimOp::Shl => a.raw << b.raw.to_int()
    @firrtl.PrimOp::Shr => if signed { av >> b.raw.to_int() } else { a.raw >> b.raw.to_int() }
    @firrtl.PrimOp::Head => a.raw >> (a.width - width)
    @firrtl.PrimOp::Tail => a.raw & mask(width)
    @firrtl.PrimOp::Bits => {
      let lo = values.get(2).unwrap_or(SimValue::zero(1)).raw.to_int()
      (a.raw >> lo) & mask(width)
    }
    @firrtl.PrimOp::Andr => BigInt::from_int(all_bits(a).to_int())
    @firrtl.PrimOp::Orr => BigInt::from_int(any_bits(a).to_int())
    @firrtl.PrimOp::Xorr => BigInt::from_int(parity(a).to_int())
  }
  SimValue::new(width, result, known=values.iter().all(v => v.known))
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
  { width: value.width, raw: value.raw, known }
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
  if actual.raw != expected.raw || actual.known != expected.known {
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
      outputs.push({ name, width: type_width(port.ty), value: value.raw.to_string(), known: value.known })
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
      inputs.push({ name, width: type_width(port.ty), value: value.raw.to_string(), known: value.known })
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
  let words: Array[UInt] = []
  let valid: Array[UInt] = []
  for row in 0..<height {
    if binary {
      let value = simulator.peek(ports[row])
      for word in 0..<((width + 31) / 32) {
        words.push(((value.raw >> (word * 32)) & mask(32)).to_uint())
        valid.push(if value.known { 0xffffffffU } else { 0U })
      }
    } else {
      for col in 0..<width {
        let value = simulator.peek(ports[row * width + col])
        words.push((value.raw & mask(32)).to_uint())
        valid.push(if value.known { 0xffffffffU } else { 0U })
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
      outputs.push({ name, width: value.width, value: value.raw.to_string(), known: value.known })
    }
  }
  outputs
}

pub(all) struct SimulatorRaster {
  signal: String
  width: Int
  height: Int
  pixels: Array[UInt]
  valid: Array[UInt]
  mut frames: Int
  mut started: Bool
  mut at_origin: Bool
}

pub fn simulator_raster_new(simulator: Simulator, signal: String, width: Int, height: Int) -> SimulatorRaster raise SimulatorError {
  for suffix in ["x", "y", "valid", "r", "g", "b"] {
    let name = signal + "_" + suffix
    if !simulator.design.ports.iter().any(p => p.id.inner() == name && p.dir is @parse.PortDir::Output) {
      raise Unsupported(message="pixel stream requires output '\{name}'")
    }
    let value = simulator.peek(name)
    if (suffix == "r" || suffix == "g" || suffix == "b") && (value.width < 1 || value.width > 8) {
      raise Unsupported(message="pixel stream color channels must have 1 to 8 bits")
    }
  }
  { signal, width, height, pixels: Array::make(width * height, 0U), valid: Array::make(width * height, 0U), frames: 0, started: false, at_origin: false }
}

/// Sample the pre-edge pixel, then advance the hardware. The worker calls this
/// in bounded chunks so playback and frame stepping remain interruptible.
pub fn simulator_raster_step(simulator: Simulator, raster: SimulatorRaster, clock: String, cycles: Int, until_frame: Bool) -> Int raise SimulatorError {
  let target = raster.frames + 1
  let mut advanced = 0
  for _ in 0..<cycles {
    if simulator.halted { break }
    let x = simulator.peek(raster.signal + "_x")
    let y = simulator.peek(raster.signal + "_y")
    let valid = simulator.peek(raster.signal + "_valid")
    if (x.known && x.raw != 0) || (y.known && y.raw != 0) || (valid.known && valid.raw == 0) {
      raster.at_origin = false
    }
    if x.known && y.known && valid.known && valid.raw != 0 {
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
        let r = simulator.peek(raster.signal + "_r")
        let g = simulator.peek(raster.signal + "_g")
        let b = simulator.peek(raster.signal + "_b")
        let red = (r.raw.to_int() * 255 / ((1 << r.width) - 1)).reinterpret_as_uint()
        let green = (g.raw.to_int() * 255 / ((1 << g.width) - 1)).reinterpret_as_uint()
        let blue = (b.raw.to_int() * 255 / ((1 << b.width) - 1)).reinterpret_as_uint()
        raster.pixels[row * raster.width + col] = (red << 16) | (green << 8) | blue
        raster.valid[row * raster.width + col] = if r.known && g.known && b.known { 0xffffffffU } else { 0U }
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

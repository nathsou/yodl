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
  data: Array[SimValue]
  read_data: Map[String, SimValue]
}

pub(all) struct Simulator {
  design: TypedModule
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
}

pub fn Simulator::new(design: TypedModule) -> Simulator raise SimulatorError {
  Simulator::new_with_modules(design, modules=Map([]))
}

/// Build a hierarchical simulator for one module in a typed FIRRTL circuit.
pub fn Simulator::from_circuit(circuit: TypedCircuit, top: String) -> Simulator raise SimulatorError {
  let modules: Map[String, TypedModule] = Map([])
  for decl in circuit.decls {
    match decl {
      @firrtl.Decl::Module(design) => modules[design.id.inner()] = design
      @firrtl.Decl::ExtModule(_) => ()
    }
  }
  let design = match modules.get(top) {
    Some(design) => design
    None => raise MissingSignal(name="top module " + top)
  }
  Simulator::new_with_modules(design, modules~)
}

fn Simulator::new_with_modules(design: TypedModule, modules~: Map[String, TypedModule]) -> Simulator raise SimulatorError {
  let signals: Map[String, SimValue] = Map([])
  let registers: Map[String, RegisterState] = Map([])
  let next_registers: Map[String, SimValue] = Map([])
  let memories: Map[String, MemoryState] = Map([])
  let clocks: Map[String, Bool] = Map([])
  let children: Map[String, Simulator] = Map([])
  let child_message_offsets: Map[String, Int] = Map([])

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
          data,
          read_data: Map([]),
        }
      }
      @firrtl.Stmt::Inst(id~, of~, sig~) => {
        let instance = id.inner()
        let child_design = match modules.get(of.inner()) {
          Some(child) => child
          None => raise Unsupported(message="external or unknown module '{of.inner()}' has no simulation model")
        }
        children[instance] = Simulator::new_with_modules(child_design, modules~)
        for port_name, port in sig.ports {
          signals[instance + "." + port_name] = SimValue::new(type_width(port.ty), 0, known=false)
        }
      }
      _ => ()
    }
  }

  {
    design,
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
  }
}

pub fn Simulator::messages(self: Simulator) -> Array[SimMessage] {
  self.messages
}

pub fn Simulator::is_halted(self: Simulator) -> Bool { self.halted }

pub fn Simulator::exit_code(self: Simulator) -> Int? { self.exit_code }

pub fn Simulator::failure(self: Simulator) -> String? { self.failure }

pub fn Simulator::poke(self: Simulator, name: String, value: SimValue) -> Unit raise SimulatorError {
  if !self.signals.contains(name) {
    raise MissingSignal(name~)
  }
  self.signals[name] = SimValue::new(type_width_for_name(self, name), value.raw, known=value.known)
}

pub fn Simulator::peek(self: Simulator, name: String) -> SimValue raise SimulatorError {
  match self.signals.get(name) {
    Some(value) => value
    None => raise MissingSignal(name~)
  }
}

/// Re-evaluate all combinational statements until their values stop changing.
/// Low FIRRTL is normally acyclic; the bounded iteration also makes this safe
/// for hand-built circuits while avoiding an accidental infinite loop.
pub fn Simulator::settle(self: Simulator) -> Unit raise SimulatorError {
  if self.halted { return }
  let mut changed = true
  let mut iterations = 0
  let mut last_changed = ""
  while changed {
    changed = false
    iterations += 1
    if iterations > 1024 {
      raise CombinationalLoop(message="last signal: " + last_changed)
    }

    for stmt in self.design.body {
      match stmt {
        @firrtl.Stmt::Node(id~, expr~) => {
          let value = self.eval_expr(expr)
          let did_change = self.assign_signal(id.inner(), value)
          if did_change { last_changed = id.inner() }
          changed = did_change || changed
        }
        @firrtl.Stmt::Connect(lhs, rhs) => {
          let value = self.eval_expr(rhs)
          let did_change = self.assign_lhs(lhs, value, false)
          if did_change { last_changed = ref_name(lhs) }
          changed = did_change || changed
        }
        @firrtl.Stmt::When(when) => {
          let cond = self.eval_expr(when.cond)
          let body = if cond.raw != 0 { when.body } else { when.otherwise.unwrap_or([]) }
          for nested in body {
            match nested {
              @firrtl.Stmt::Connect(lhs, rhs) => {
                let value = self.eval_expr(rhs)
                let did_change = self.assign_lhs(lhs, value, false)
                if did_change { last_changed = ref_name(lhs) }
                changed = did_change || changed
              }
              _ => ()
            }
          }
        }
        _ => ()
      }
    }
    changed = self.settle_children() || changed
  }
}

fn Simulator::settle_children(self: Simulator) -> Bool raise SimulatorError {
  let mut changed = false
  for instance, child in self.children {
    for port in child.design.ports {
      if port.dir is @parse.PortDir::Input {
        let parent_name = instance + "." + port.id.inner()
        let value = self.signals.get(parent_name).unwrap_or(SimValue::zero(type_width(port.ty)))
        child.signals[port.id.inner()] = value
        if port.ty is @firrtl.Type::Clock {
          child.clocks[port.id.inner()] = value.raw != 0
        }
      }
    }
    child.settle()
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
  self.signals[name] = SimValue::new(1, BigInt::from_int(high.to_int()))
  self.settle()
  if !old && high {
    self.commit_clock(name)
  }
}

pub fn Simulator::step_clock(self: Simulator, name: String) -> Unit raise SimulatorError {
  self.set_clock(name, true)
  self.set_clock(name, false)
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
    self.signals[name] = value
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

fn Simulator::commit_memories(self: Simulator, clock: String) -> Unit raise SimulatorError {
  for id, memory in self.memories {
    let prefix = id + "."
    let reader_prefixes = memory_port_prefixes(self.design, id, "reader")
    for reader in reader_prefixes {
      let port = prefix + reader
      let port_clock = self.signal_or_zero(port + ".clk")
      if port_clock.raw == 0 || self.signal_or_zero(port + ".en").raw == 0 { continue }
      let address = self.signal_or_zero(port + ".addr").raw.to_int()
      if address < 0 || address >= memory.depth { continue }
      if memory.read_latency > 0 {
        let value = memory.data[address]
        memory.read_data[reader] = value
      }
    }

    let writer_prefixes = memory_port_prefixes(self.design, id, "writer")
    for writer in writer_prefixes {
      let port = prefix + writer
      let port_clock = self.signal_or_zero(port + ".clk")
      if port_clock.raw == 0 || self.signal_or_zero(port + ".en").raw == 0 { continue }
      let address = self.signal_or_zero(port + ".addr").raw.to_int()
      if address < 0 || address >= memory.depth { continue }
      let data = self.signal_or_zero(port + ".data")
      let mask_value = self.signal_or_zero(port + ".mask")
      if memory.width == 0 { continue }
      memory.data[address] = masked_write(memory.data[address], data, mask_value, memory.width)
    }
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

fn memory_port_prefixes(design: TypedModule, id: String, kind: String) -> Array[String] {
  let result = []
  for stmt in design.body {
    match stmt {
      @firrtl.Stmt::Mem(mem) if mem.id.inner() == id => {
        let ports = if kind == "reader" { mem.readers } else { mem.writers }
        for port in ports { result.push(port.inner()) }
      }
      _ => ()
    }
  }
  result
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
  SimValue::new(width, raw, known=old.known && value.known && mask_value.known)
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
    true
  } else {
    false
  }
}

fn Simulator::assign_lhs(
  self: Simulator,
  lhs: TypedRef,
  value: SimValue,
  next_register: Bool,
) -> Bool {
  let name = ref_name(lhs)
  if self.registers.contains(name) && next_register {
    self.next_registers[name] = value
    false
  } else if self.registers.contains(name) {
    self.next_registers[name] = value
    false
  } else {
    self.assign_signal(name, value)
  }
}

fn Simulator::eval_expr(self: Simulator, expr: TypedExpr) -> SimValue raise SimulatorError {
  match expr {
    @firrtl.Expr::Reference(reference, ty~) => self.eval_ref(reference, type_width(ty))
    @firrtl.Expr::Literal(lit, ty~) => SimValue::new(type_width(ty), lit.as_bigint())
    @firrtl.Expr::Mux(cond~, tval~, fval~, ..) => {
      if self.eval_expr(cond).raw != 0 { self.eval_expr(tval) } else { self.eval_expr(fval) }
    }
    @firrtl.Expr::PrimOp(op~, args~, ty~) => {
      let values = args.map((expr: TypedExpr) => self.eval_expr(expr))
      eval_prim(op, values, type_width(ty), type_signed(ty))
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
    @firrtl.PrimOp::Dshr => a.raw >> b.raw.to_int()
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

// JavaScript-facing helpers. Keeping these wrappers integer-based avoids
// exposing MoonBit's BigInt representation in the playground protocol; native
// callers can use SimValue::new for arbitrary-width values.
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

pub fn simulator_outputs(simulator: Simulator) -> Array[(String, Int)] {
  let outputs = []
  for port in simulator.design.ports {
    if port.dir is @parse.PortDir::Output {
      let name = port.id.inner()
      outputs.push((name, simulator.signals.get(name).unwrap_or(SimValue::zero(type_width(port.ty))).raw.to_int()))
    }
  }
  outputs
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

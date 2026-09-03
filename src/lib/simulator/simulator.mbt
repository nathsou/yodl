/// A compact, deterministic simulator for a typed FIRRTL module.
///
/// This is intentionally a module-level runner.  The compiler-facing lowering
/// step can flatten a hierarchy into this form later; keeping the execution
/// semantics here independent from the compiler makes it useful for native
/// testbenches as well as the JavaScript playground.

using @firrtl {
  type TypedModule,
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
  CombinationalLoop
} derive(Show, Debug)

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

pub(all) struct Simulator {
  design: TypedModule
  signals: Map[String, SimValue]
  registers: Map[String, RegisterState]
  next_registers: Map[String, SimValue]
  clocks: Map[String, Bool]
  messages: Array[SimMessage]
  mut halted: Bool
  mut exit_code: Int?
  mut failure: String?
}

pub fn Simulator::new(design: TypedModule) -> Simulator raise SimulatorError {
  let signals: Map[String, SimValue] = Map([])
  let registers: Map[String, RegisterState] = Map([])
  let next_registers: Map[String, SimValue] = Map([])
  let clocks: Map[String, Bool] = Map([])

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
      _ => ()
    }
  }

  {
    design,
    signals,
    registers,
    next_registers,
    clocks,
    messages: [],
    halted: false,
    exit_code: None,
    failure: None,
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
  while changed {
    changed = false
    iterations += 1
    if iterations > self.design.body.length() + 1 {
      raise CombinationalLoop
    }

    for stmt in self.design.body {
      match stmt {
        @firrtl.Stmt::Node(id~, expr~) => {
          let value = self.eval_expr(expr)
          changed = self.assign_signal(id.inner(), value) || changed
        }
        @firrtl.Stmt::Connect(lhs, rhs) => {
          let value = self.eval_expr(rhs)
          changed = self.assign_lhs(lhs, value, false) || changed
        }
        @firrtl.Stmt::When(when) => {
          let cond = self.eval_expr(when.cond)
          let body = if cond.raw != 0 { when.body } else { when.otherwise.unwrap_or([]) }
          for nested in body {
            match nested {
              @firrtl.Stmt::Connect(lhs, rhs) => {
                let value = self.eval_expr(rhs)
                changed = self.assign_lhs(lhs, value, false) || changed
              }
              _ => ()
            }
          }
        }
        _ => ()
      }
    }
  }
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
  self.run_commands(clock)
  self.settle()
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
              text = text + " " + self.eval_expr(arg).to_string()
            }
            self.messages.push({ kind: "printf", text })
          }
          @firrtl.Command::Assert(pred~, fmt~, args~, ..) => {
            if self.eval_expr(pred).raw == 0 {
              let mut text = fmt
              for arg in args {
                text = text + " " + self.eval_expr(arg).to_string()
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
    @firrtl.Reference::FieldAccess(lhs~, field~, ..) => {
      let name = ref_name(reference)
      match self.signals.get(name) {
        Some(value) => value
        None => self.eval_ref(lhs, width)
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
    @firrtl.PrimOp::Bits => (a.raw >> b.raw.to_int()) & mask(width)
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
    @firrtl.Reference::StaticIndexing(lhs~, index~, ..) => "{ref_name(lhs)}[{index}]"
    @firrtl.Reference::DynamicIndexing(lhs~, ..) => ref_name(lhs)
    @firrtl.Reference::FieldAccess(lhs~, field~, ..) => "{ref_name(lhs)}.{field.inner()}"
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

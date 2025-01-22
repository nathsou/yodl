
pub(all) enum Expr {
  Const(value~: Const, span~: @parse.Span)
  Variable(name~: String, width~: Int, span~: @parse.Span)
  Unary(op~: @parse.UnaryOp, expr~: Expr, width~: Int, span~: @parse.Span)
  Binary(op~: @parse.BinaryOp, lhs~: Expr, rhs~: Expr, width~: Int, span~: @parse.Span)
  Concat(elems~: Array[Expr], width~: Int, span~: @parse.Span)
  Select(expr~: Expr, offset~: Int, width~: Int, span~: @parse.Span)
  Mux(subject~: Expr, cases~: Array[(Const, Expr)], default~: Expr?, width~: Int, span~: @parse.Span)
  MemRead(mem_name~: String, addr~: Expr, width~: Int, span~: @parse.Span)
} derive(Show)

pub(all) enum Stmt {
  Expr(expr~: Expr, span~: @parse.Span)
  Wire(name~: String, width~: Int, span~: @parse.Span)
  Reg(name~: String, width~: Int, async_reset~: Bool, span~: @parse.Span)
  Assign(lhs~: Expr, rhs~: Expr, span~: @parse.Span)
  Memory(name~: String, width~: Int, depth~: Int, read_ports~: Int, write_ports~: Int, span~: @parse.Span)
  MemWrite(mem_name~: String, addr~: Expr, data~: Expr, span~: @parse.Span)
  Instance(name~: String, module_name~: String, ports~: Map[String, Expr], span~: @parse.Span)
  Process(triggers~: ProcessTriggers, body~: Array[Stmt], span~: @parse.Span)
} derive(Show)

pub(all) enum ProcessTriggers {
  All
  Events(Array[SensitivityListEvent])
} derive(Show)

pub(all) struct SensitivityListEvent {
  polarity: Polarity?
  signal: String
} derive(Show)

pub(all) enum Polarity {
  Posedge; Negedge
} derive(Eq, Show)

pub(all) struct Port {
  name: String
  width: Int
  direction: @parse.PortDirection
  span: @parse.Span
} derive(Show)

pub(all) struct Module {
  name: String
  ports: Array[Port]
  body: Array[Stmt]
  span: @parse.Span
} derive(Show)

pub(all) enum ConstBase {
  Bin; Oct; Dec; Hex
} derive(Show)

pub(all) struct Const {
  bits: @parse.Bits
  width: Int
  base: ConstBase
  span: @parse.Span
} derive(Show)

pub fn Const::zeros(width: Int, span: @parse.Span) -> Const {
  {
    bits: { bits: @utils.fill(width, Zero), value: Some(BigInt::from_int(0)), span },
    width,
    base: ConstBase::Bin,
    span,
  }
}

pub fn Const::xs(width: Int, span: @parse.Span) -> Const {
  { bits: { bits: @utils.fill(width, X), value: None, span }, width, base: ConstBase::Bin, span }
}

pub fn Expr::width(self: Expr) -> Int {
  match self {
    Const(value~, ..) => value.width
    Variable(width~, ..) => width
    Unary(width~, ..) => width
    Binary(width~, ..) => width
    Concat(width~, ..) => width
    Select(width~, ..) => width
    Mux(width~, ..) => width
    MemRead(width~, ..) => width
  }
}

pub fn Module::add_stmt(self: Module, stmt: Stmt) -> Unit {
  self.body.push(stmt)
}


pub(all) enum Expr {
  Const(value~: Const, span~: @parse.Span)
  Variable(name~: String, span~: @parse.Span)
  Unary(op~: @parse.UnaryOp, expr~: Expr, span~: @parse.Span)
  Binary(op~: @parse.BinaryOp, lhs~: Expr, rhs~: Expr, span~: @parse.Span)
  Concat(exprs~: Array[Expr], span~: @parse.Span)
  Select(expr~: Expr, offset~: Int, width~: Int, span~: @parse.Span)
  Mux(subject~: Expr, cases~: Array[(Const, Expr)], span~: @parse.Span)
  Instance(name~: String, ports~: Map[String, Expr], span~: @parse.Span)
  MemRead(mem_name~: String, addr~: Expr, span~: @parse.Span)
}

pub(all) enum Stmt {
  Expr(expr~: Expr, span~: @parse.Span)
  Wire(name~: String, width~: Int, span~: @parse.Span)
  Reg(name~: String, width~: Int, async_reset~: Bool, span~: @parse.Span)
  Assign(lhs~: Expr, rhs~: Expr, span~: @parse.Span)
  Memory(name~: String, width~: Int, depth~: Int, span~: @parse.Span)
  MemWrite(mem_name~: String, addr~: Expr, data~: Expr, span~: @parse.Span)
  Process(triggers~: ProcessTriggers, body~: Array[Stmt], span~: @parse.Span)
}

pub(all) enum ProcessTriggers {
  All
  Events(Array[SensitivityListEvent])
}

pub(all) struct SensitivityListEvent {
  polarity: Polarity?
  signal: String
}

pub(all) enum Polarity {
  Posedge; Negedge
} derive(Eq)

pub(all) struct Port {
  name: String
  width: Int
  direction: @parse.PortDirection
  span: @parse.Span
}

pub(all) struct Module {
  name: String
  ports: Array[Port]
  body: Array[Stmt]
  span: @parse.Span
}

pub(all) enum ConstBase {
  Bin; Oct; Dec; Hex
}

pub(all) struct Const {
  bits: @parse.Bits
  width: Int
  base: ConstBase
  span: @parse.Span
}

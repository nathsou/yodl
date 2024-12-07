
enum UnaryOp {
  LogicalNot; Complement
}

enum BinaryOp {
  And; Or; Xor; Nand; Nor; Xnor
}

fn precedence(self: BinaryOp) -> Int {
  match self {
    And => 10
    Or => 9
    Xor => 8
    Nand => 7
    Nor => 6
    Xnor => 5

  }
}

pub(readonly) enum Expr {
  Natural(value~: UInt, span~: Span)
  Identifier(name~: String, span~: Span)
  Unary(op~: UnaryOp, expr~: Expr, span~: Span)
  Binary(op~: BinaryOp, lhs~: Expr, rhs~: Expr, span~: Span)
}

pub(readonly) enum Stmt {
  Let(name~: String, expr~: Expr, span~: Span)
  Assign(name~: String, expr~: Expr, span~: Span)
}

pub(readonly) enum Type {
  Logic
  Vector(ty~: Type, len~: UInt)
}

pub(readonly) enum PortDirection {
  Input; Output
}

pub(readonly) struct Port {
  name: String
  ty: Type
  dir: PortDirection
}

pub(readonly) enum Decl {
  Module(
    name~: String,
    inputs~: Array[Port],
    outputs~: Array[Port],
    body~: Array[Stmt],
    span~: Span,
  )
}

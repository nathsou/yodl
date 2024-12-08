
pub(readonly) enum UnaryOp {
  Not
}

pub(readonly) enum BinaryOp {
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
  Natural(value~: UInt, width~: UInt?, span~: Span, ty~: Ref[Type?])
  Identifier(name~: String, span~: Span, ty~: Ref[Type?])
  Unary(op~: UnaryOp, expr~: Expr, span~: Span, ty~: Ref[Type?])
  Binary(op~: BinaryOp, lhs~: Expr, rhs~: Expr, span~: Span, ty~: Ref[Type?])
}

pub(readonly) enum Stmt {
  Let(name~: String, expr~: Expr, span~: Span)
  Assign(name~: String, expr~: Expr, span~: Span)
}

pub(readonly) enum Type {
  Logic
  Vector(ty~: Type, len~: UInt)
} derive(Eq)

pub(readonly) enum PortDirection {
  Input; Output
}

pub(readonly) struct Port {
  name: String
  ty: Type
  dir: PortDirection
  span: Span
}

pub(readonly) struct ModuleDecl {
    name: String
    inputs: Array[Port]
    outputs: Array[Port]
    body: Array[Stmt]
    span: Span
}

pub(readonly) enum Decl {
  Module(ModuleDecl)
}

pub fn ty(self: Expr) -> Ref[Type?] {
  match self {
    Natural(ty~, ..) => ty
    Identifier(ty~, ..) => ty
    Unary(ty~, ..) => ty
    Binary(ty~, ..) => ty
  }
}

pub fn set_ty(self: Expr, ty: Type) -> Unit {
  self.ty().val = Some(ty)
}

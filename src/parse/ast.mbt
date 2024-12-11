
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
  Indexing(expr~: Expr, index~: Expr, span~: Span, ty~: Ref[Type?])
  Slicing(expr~: Expr, start~: Expr, end~: Expr, span~: Span, ty~: Ref[Type?])
  PortAccess(expr~: Expr, port~: String, span~: Span, ty~: Ref[Type?])
  Instance(name~: String, ports~: Map[String, Expr], span~: Span, ty~: Ref[Type?])
}

pub(readonly) enum Stmt {
  Let(name~: String, expr~: Expr, span~: Span)
  Assign(lhs~: Expr, rhs~: Expr, span~: Span)
}

pub(all) struct ModuleSignature {
    name: String
    inputs: Array[Port]
    outputs: Array[Port]
    span: Span
}

impl Eq for ModuleSignature with op_equal(self, other) {
  self.name == other.name && self.span.file == other.span.file
}

pub(all) enum Type {
  Nat
  Logic
  Vector(ty~: Type, len~: UInt)
  Instance(ModuleSignature)
} derive(Eq)

pub(all) enum PortDirection {
  Input; Output
} derive(Hash, Eq)

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
    Indexing(ty~, ..) => ty
    Slicing(ty~, ..) => ty
    PortAccess(ty~, ..) => ty
    Instance(ty~, ..) => ty
  }
}

pub fn span(self: Expr) -> Span {
  match self {
    Natural(span~, ..) => span
    Identifier(span~, ..) => span
    Unary(span~, ..) => span
    Binary(span~, ..) => span
    Indexing(span~, ..) => span
    Slicing(span~, ..) => span
    PortAccess(span~, ..) => span
    Instance(span~, ..) => span
  }
}

pub fn set_ty(self: Expr, ty: Type) -> Unit {
  self.ty().val = Some(ty)
}

pub fn is_constant_expr(self: Expr) -> Bool {
  match self {
    Natural(..) => true
    Identifier(..) => false
    Unary(expr~, ..) => expr.is_constant_expr()
    Binary(lhs~, rhs~, ..) => lhs.is_constant_expr() && rhs.is_constant_expr()
    Indexing(_) => false
    Slicing(_) => false
    PortAccess(_) => false
    Instance(_) => false
  }
}

pub fn get_port(self: ModuleSignature, name: String) -> Port? {
  for input in self.inputs {
    if input.name == name {
      return Some(input)
    }
  }

  for output in self.outputs {
    if output.name == name {
      return Some(output)
    }
  }

  None
}

pub fn width(self: Type) -> UInt? {
  match self {
    Nat => None
    Logic => Some(1)
    Vector(len~, ..) => Some(len)
    Instance(_) => None
  }
}

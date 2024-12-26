
pub(readonly) enum UnaryOp {
  Not
}

pub(readonly) enum BinaryOp {
  And; Or; Xor; Nand; Nor; Xnor
  Add; Sub; Mul
}

fn precedence(self: BinaryOp) -> Int {
  match self {
    Mul => 12
    Add | Sub => 11
    And => 10
    Or => 9
    Xor => 8
    Nand => 7
    Nor => 6
    Xnor => 5
  }
}

pub(all) enum Expr {
  Natural(value~: Int, width~: Int?, span~: Span, ty~: Ref[Type?])
  Identifier(name~: String, span~: Span, ty~: Ref[Type?])
  Unary(op~: UnaryOp, expr~: Expr, span~: Span, ty~: Ref[Type?])
  Binary(op~: BinaryOp, lhs~: Expr, rhs~: Expr, span~: Span, ty~: Ref[Type?])
  Indexing(expr~: Expr, index~: Expr, span~: Span, ty~: Ref[Type?])
  Slicing(expr~: Expr, msb~: Expr, lsb~: Expr, span~: Span, ty~: Ref[Type?])
  PortAccess(expr~: Expr, port~: String, span~: Span, ty~: Ref[Type?])
  Instance(name~: String, params~: Array[Expr], ports~: Map[String, Expr], span~: Span, ty~: Ref[Type?])
  Vector(elems~: Array[Expr], span~: Span, ty~: Ref[Type?])
  Spread(expr~: Expr, span~: Span, ty~: Ref[Type?])
}

pub(all) enum Stmt {
  Expr(expr~: Expr, span~: Span)
  Let(name~: String, ty~: Ref[Type?], expr~: Expr?, span~: Span)
  Assign(lhs~: Expr, rhs~: Expr, span~: Span)
  For(var~: String, range~: ForRange, body~: Array[Stmt], span~: Span)
  Scope(body~: Array[Stmt], span~: Span)
}

pub(all) struct ForRange {
  start: Expr
  end: Expr
  inclusive: Bool
}

pub(all) struct ModuleSignature {
    name: String
    params: Array[String]
    inputs: Array[Port]
    outputs: Array[Port]
    span: Span
}

impl Eq for ModuleSignature with op_equal(self, other) {
  self.name == other.name && self.span.file == other.span.file
}

pub(all) enum VectorLen {
  Fixed(Int)
  Dynamic(Expr)
}

impl Eq for VectorLen with op_equal(self, other) {
  match (self, other) {
    (Fixed(a), Fixed(b)) => a == b
    _ => false
  }
}

pub fn expect_fixed(self: VectorLen, span: Span) -> Int!Error {
  match self {
    Fixed(value) => value
    Dynamic(_) => {
      raise Failure("Expected fixed vector length \{span}")
    }
  }
}

pub(all) enum Type {
  Nat
  Logic
  Vector(ty~: Type, len~: VectorLen)
  Instance(ModuleSignature)
  Name(name~: String)
} derive(Eq)

pub(all) enum PortDirection {
  Input; Output
} derive(Hash, Eq)

pub(all) struct Port {
  name: String
  ty: Type
  dir: PortDirection
  span: Span
}

pub(all) struct ModuleDecl {
    name: String
    params: Array[String]
    inputs: Array[Port]
    outputs: Array[Port]
    body: Array[Stmt]
    span: Span
}

pub(all) enum Decl {
  Module(ModuleDecl)
  ModuleDeclaration(ModuleSignature)
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
    Vector(ty~, ..) => ty
    Spread(ty~, ..) => ty
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
    Vector(span~, ..) => span
    Spread(span~, ..) => span
  }
}

pub fn set_ty(self: Expr, ty: Type) -> Unit {
  self.ty().val = Some(ty)
}

pub fn is_constant_expr(self: Expr) -> Bool {
  match self {
    Natural(..) => true
    Identifier(..) => true
    Unary(expr~, ..) => expr.is_constant_expr()
    Binary(lhs~, rhs~, ..) => lhs.is_constant_expr() && rhs.is_constant_expr()
    Indexing(_) => false
    Slicing(_) => false
    PortAccess(_) => false
    Instance(_) => false
    Vector(_) => false
    Spread(_) => false
  }
}

pub fn constant_folding(self: Expr) -> Expr!Error {
  rewrite_expr!(self, fn!(expr) {
    match expr {
      Binary(op = Mul | Add | Sub as op, lhs~, rhs~, span~, ty~) => {
        match (lhs.expect_int?(), rhs.expect_int?()) {
          (Ok(lhs), Ok(rhs)) => {
            let value = match op {
              Mul => lhs * rhs
              Add => lhs + rhs
              Sub => lhs - rhs
              _ => raise Failure("Invalid arithmetical binary operator")
            }

            Natural(value=value, width=None, span~, ty~)
          }
          _ => expr
        }
      }
      _ => expr
    }
  })
}

pub fn expect_int(self: Expr) -> Int!Error {
  match self {
    Natural(value~, ..) => value
    _ => raise Failure("Expected integer expression")
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

pub fn width(self: Type, params_env~: Map[String, Int]?) -> Int? {
  match self {
    Nat => None
    Logic => Some(1)
    Vector(len=Fixed(len), ..) => Some(len)
    Vector(len=Dynamic(Identifier(name~, ..)), ..) => {
      match params_env {
        Some(env) => env[name]
        None => None
      }
    }
    Vector(..) => None
    Instance(_) => None
    Name(_) => None
  }
}

pub fn signature(self: ModuleDecl) -> ModuleSignature {
  {
    name: self.name,
    params: self.params,
    inputs: self.inputs,
    outputs: self.outputs,
    span: self.span,
  }
}

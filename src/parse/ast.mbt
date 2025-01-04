
pub(all) enum Expr {
  Natural(bits~: Bits, width~: Int?, base~: Int, span~: Span, ty~: Ref[Type?])
  Identifier(name~: String, span~: Span, ty~: Ref[Type?])
  Unary(op~: UnaryOp, expr~: Expr, span~: Span, ty~: Ref[Type?])
  Binary(op~: BinaryOp, lhs~: Expr, rhs~: Expr, span~: Span, ty~: Ref[Type?])
  Indexing(expr~: Expr, index~: Expr, span~: Span, ty~: Ref[Type?])
  Slicing(expr~: Expr, msb~: Expr, lsb~: Expr, span~: Span, ty~: Ref[Type?])
  FieldAccess(expr~: Expr, field~: String, span~: Span, ty~: Ref[Type?])
  Instance(name~: String, params~: Array[Expr], ports~: Map[String, Expr], span~: Span, ty~: Ref[Type?])
  Vector(elems~: Array[Expr], span~: Span, ty~: Ref[Type?])
  Spread(expr~: Expr, span~: Span, ty~: Ref[Type?])
  Ternary(cond~: Expr, then~: Expr, else_~: Expr, span~: Span, ty~: Ref[Type?])
  Match(subject~: Expr, cases~: Array[(Expr, Expr)], default~: Expr?, span~: Span, ty~: Ref[Type?])
  Tuple(elems~: Array[Expr], span~: Span, ty~: Ref[Type?])
  Struct(fields~: Map[String, Expr], span~: Span, ty~: Ref[Type?])
  Replicate(expr~: Expr, count~: Expr, concat~: Bool, span~: Span, ty~: Ref[Type?])
  FunCall(name~: String, args~: Array[Expr], span~: Span, ty~: Ref[Type?])
}

pub(all) enum Stmt {
  Expr(expr~: Expr, span~: Span)
  Const(decl~: ConstDecl, span~: Span)
  Let(name~: String, ty~: Ref[Type?], expr~: Expr?, span~: Span)
  Assign(lhs~: Expr, rhs~: Expr, span~: Span)
  For(var~: String, range~: ForRange, body~: Array[Stmt], span~: Span)
  Scope(body~: Array[Stmt], span~: Span)
}

pub(all) enum Decl {
  Module(ModuleDecl)
  ModuleDeclaration(ModuleSignature)
  Const(ConstDecl)
}

pub(all) enum Type {
  Nat
  Logic
  Vector(ty~: Type, len~: VectorLen)
  Instance(sig~: ModuleSignature, params~: Map[String, Int], accessed_ports~: Set[String])
  Name(name~: String, params~: Array[Int])
  Struct(Map[String, Type])
} derive(Eq)

pub(all) enum UnaryOp {
  Not
}

pub(all) enum BinaryOp {
  And; Or; Xor; Nand; Nor; Xnor
  Add; Sub; Mul; Div; Mod
  Equ; Neq; Lss; Gtr; Leq; Geq
  Shl; Shr
  Ternary // hack for precedence climbing
}

pub(all) enum BinaryDigit {
  Zero; One; X; Z; M; DontCare
} derive(Eq)

pub fn is_determined(self: BinaryDigit) -> Bool {
  match self {
    Zero | One => true
    _ => false
  }
}

pub impl Show for BinaryDigit with output(self, logger) {
  logger.write_char(match self {
    Zero => '0'
    One => '1'
    X => 'x'
    Z => 'z'
    M => 'm'
    DontCare => '-'
  })
}

pub(all) struct Bits {
  bits: Array[BinaryDigit]
  mut value: Int?
  span: Span
}

impl Eq for Bits with op_equal(self, other) {
  self.bits == other.bits
}

impl Show for Bits with output(self, logger) {
  match self.value {
    Some(value) => logger.write_string(value.to_string())
    None => {
      for bit in self.bits {
        logger.write_string(bit.to_string())
      }
    }
  }
}

fn precedence(self: BinaryOp) -> Int {
  match self {
    Mul | Div | Mod => 8
    Add | Sub => 7
    Shl | Shr => 6
    Lss | Gtr | Leq | Geq => 5
    Equ | Neq => 4
    And | Nand => 3
    Or | Nor | Xor | Xnor => 2
    Ternary => 1
  }
}

pub(all) enum AttributeValue {
  String(String)
  Int(Int)
}

pub(all) struct Attribute {
  name: String
  args: Array[AttributeValue]
  span: Span
}

pub(all) struct ForRange {
  start: Expr
  end: Expr
  inclusive: Bool
}

pub(all) struct ModuleSignature {
    name: String
    params: Array[String]
    attributes: Map[String, Attribute]
    ports: Array[Port]
    span: Span
}

impl Eq for ModuleSignature with op_equal(self, other) {
  self.name == other.name && self.span.file == other.span.file
}

pub(all) struct ConstDecl {
  name: String
  ty: Type?
  expr: Expr
  span: Span
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

pub type! AstError {
  ExpectedFixedVectorLength(span~: Span)
  ExpectedIntegerExpression(expr~: Expr, span~: Span)
  NaturalContainsUndeterminedDigit(span~: Span)
  ValueTooLargeForWidth(value~: Int, width~: Int, span~: Span)
  VectorLengthNotFixed(span~: Span)
  CannotGetWidthOfUnresolvedNamedType(span~: Span)
  InvalidFunCallArity(name~: String, expected~: Int, actual~: Int, span~: Span)
}

pub impl Show for AstError with output(self, logger) {
  match self {
    ExpectedFixedVectorLength(_) => logger.write_string("Expected a fixed vector length")
    ExpectedIntegerExpression(expr~, ..) => logger.write_string("Expected an integer expression, got: \{expr.ctor()}")
    NaturalContainsUndeterminedDigit(_) => logger.write_string("Natural contains an undetermined digit")
    ValueTooLargeForWidth(value~, width~, ..) => logger.write_string("Value \{value} is too large for width \{width}")
    VectorLengthNotFixed(_) => logger.write_string("Vector length must be fixed")
    CannotGetWidthOfUnresolvedNamedType(_) => logger.write_string("Cannot get width of unresolved named type")
    InvalidFunCallArity(name~, expected~, actual~, ..) => logger.write_string("Function '\{name}' expected \{expected} argument(s), but got \{actual}")
  }

  logger.write_string(self.show_context())
}

pub impl Spanned for AstError with span(self) -> Span {
  match self {
    ExpectedFixedVectorLength(span~) => span
    ExpectedIntegerExpression(span~, ..) => span
    NaturalContainsUndeterminedDigit(span~) => span
    ValueTooLargeForWidth(span~, ..) => span
    VectorLengthNotFixed(span~) => span
    CannotGetWidthOfUnresolvedNamedType(span~) => span
    InvalidFunCallArity(span~, ..) => span
  }
}

pub fn expect_fixed(self: VectorLen, span: Span) -> Int! {
  match self {
    Fixed(value) => value
    Dynamic(_) => {
      raise ExpectedFixedVectorLength(span~)
    }
  }
}

pub(all) enum PortDirection {
  Input; Output; Inout
} derive(Hash, Eq)

pub impl Show for PortDirection with output(self, logger) {
  logger.write_string(match self {
    Input => "input"
    Output => "output"
    Inout => "inout"
  })
}

pub(all) struct Port {
  name: String
  ty: Type
  dir: PortDirection
  span: Span
  optional: Bool
  attributes: Map[String, Attribute]
}

pub(all) struct ModuleDecl {
    name: String
    params: Array[String]
    attributes: Map[String, Attribute]
    ports: Array[Port]
    body: Array[Stmt]
    span: Span
}

pub fn ty(self: Expr) -> Ref[Type?] {
  match self {
    Natural(ty~, ..) => ty
    Identifier(ty~, ..) => ty
    Unary(ty~, ..) => ty
    Binary(ty~, ..) => ty
    Indexing(ty~, ..) => ty
    Slicing(ty~, ..) => ty
    FieldAccess(ty~, ..) => ty
    Instance(ty~, ..) => ty
    Vector(ty~, ..) => ty
    Spread(ty~, ..) => ty
    Ternary(ty~, ..) => ty
    Match(ty~, ..) => ty
    Tuple(ty~, ..) => ty
    Struct(ty~, ..) => ty
    Replicate(ty~, ..) => ty
    FunCall(ty~, ..) => ty
  }
}

pub(open) trait Spanned {
  span(Self) -> Span
  show_context(Self) -> String
}

impl Spanned with show_context(self) -> String {
  let span = self.span()
  let builder = StringBuilder::new()

  builder.write_string(", ")
  builder.write_string("\x1b[4m")
  builder.write_string("\{span}")
  builder.write_string("\x1b[0m")
  
  match span.context?() {
    Ok(ctx) => {
      builder.write_string("\n\n")
      builder.write_string(ctx)
    }
    Err(_) => ()
  }

  builder.to_string()
}

pub impl Spanned for Expr with span(self: Expr) -> Span {
  match self {
    Natural(span~, ..) => span
    Identifier(span~, ..) => span
    Unary(span~, ..) => span
    Binary(span~, ..) => span
    Indexing(span~, ..) => span
    Slicing(span~, ..) => span
    FieldAccess(span~, ..) => span
    Instance(span~, ..) => span
    Vector(span~, ..) => span
    Spread(span~, ..) => span
    Ternary(span~, ..) => span
    Match(span~, ..) => span
    Tuple(span~, ..) => span
    Struct(span~, ..) => span
    Replicate(span~, ..) => span
    FunCall(span~, ..) => span
  }
}

pub fn ctor(self: Expr) -> String {
  match self {
    Natural(_) => "Natural"
    Identifier(_) => "Identifier"
    Unary(_) => "Unary"
    Binary(_) => "Binary"
    Indexing(_) => "Indexing"
    Slicing(_) => "Slicing"
    FieldAccess(_) => "PortAccess"
    Instance(_) => "Instance"
    Vector(_) => "Vector"
    Spread(_) => "Spread"
    Ternary(_) => "Ternary"
    Match(_) => "Match"
    Tuple(_) => "Tuple"
    Struct(_) => "Struct"
    Replicate(_) => "Replicate"
    FunCall(_) => "FunCall"
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
    FieldAccess(_) => false
    Instance(_) => false
    Vector(_) => false
    Spread(_) => false
    Ternary(_) => false
    Match(_) => false
    Tuple(_) => false
    Struct(_) => false
    Replicate(_) => false
    FunCall(_) => false
  }
}

// perform partial evaluation on the expression
pub fn partial_eval(self: Expr, params~: Map[String, Int] = {}) -> Expr! {
  rewrite_expr!(self, fn!(expr) {
    match expr {
      Identifier(name~, ..) => {
        match params[name] {
          Some(value) => Natural(bits=Bits::from!(value, span=expr.span()), width=None, base=10, span=expr.span(), ty=expr.ty())
          None => expr
        }
      }
      Binary(op = Add | Sub | Mul | Div | Mod as op, lhs~, rhs~, span~, ty~) => {
        match (lhs.expect_int?(), rhs.expect_int?()) {
          (Ok(lhs), Ok(rhs)) => {
            let value = match op {
              Add => lhs + rhs
              Sub => lhs - rhs
              Mul => lhs * rhs
              Div => lhs / rhs
              Mod => lhs % rhs
              _ => raise Failure("Invalid arithmetical binary operator")
            }

            Natural(bits=Bits::from!(value, span~), width=None, base=10, span~, ty~)
          }
          _ => expr
        }
      }
      Ternary(cond~, then~, else_~, ..) => {
        match cond.expect_int?() {
          Ok(cond) => if cond != 0 { then } else { else_ }
          _ => expr
        }
      }
      Match(subject~, cases~, ..) => {
        match subject.expect_int?() {
          Ok(subject) => {
            for case in cases {
              let (value, _) = case
              match value.expect_int?() {
                Ok(case) => if subject == case { return value }
                _ => ()
              }
            }

            expr
          }
          _ => expr
        }
      }
      FunCall(name~, args~, span~, ty=_) => {
        let fun = match builtin_functions[name] {
          Some(fun) => fun
          None => return expr
        }

        if args.length() != fun.arity {
          raise InvalidFunCallArity(name~, expected=fun.arity, actual=args.length(), span~)
        }

        (fun.apply)!(args, span)
      }
      _ => expr
    }
  })
}

struct BuiltinFunction {
  arity: Int
  apply: (Array[Expr], Span) -> Expr!
}

let builtin_functions: Map[String, BuiltinFunction] = {
  "$clog2": {
    arity: 1,
    apply: fn(args, span) {
      let arg = args[0].expect_int!()
      let value = @utils.clog2(arg)
      nat!(value, span~)
    }
  },
  "$pow": {
    arity: 2,
    apply: fn(args, span) {
      let base = args[0].expect_int!()
      let exp = args[1].expect_int!()
      nat!(@utils.pow(base, exp), span~)
    }
  },
  "$cdiv": {
    arity: 2,
    apply: fn(args, span) {
      let dividend = args[0].expect_int!()
      let divisor = args[1].expect_int!()
      nat!(@utils.cdiv(dividend, divisor), span~)
    }
  },
}

pub fn as_int(self: Bits) -> Int!AstError {
  match self.value {
    Some(value) => value
    None => {
      let value = bits_to_int!(self.bits, span=self.span)
      self.value = Some(value)
      value
    }
  }
}

///|
/// attempts to interpret the bits as a binary integer
/// returns an error if any bit is undetermined (not a 0 or a 1)
fn bits_to_int(bits: Array[BinaryDigit], span~: Span) -> Int!AstError {
  let mut value = 0

  for i in 0..<bits.length() {
    let bit = bits[bits.length() - i - 1]

    value = match bit {
      Zero => value * 2
      One => value * 2 + 1
      _ => raise NaturalContainsUndeterminedDigit(span~)
    }
  }

  value
}

pub fn Bits::new(bits: Array[BinaryDigit], value~: Int? = None, span~: Span) -> Bits {
  { bits, value, span }
}

pub fn Bits::from(value: Int, width~: Int? = None, span~: Span) -> Bits!AstError {
  let required_width = @utils.clog2(value + 1)

  match width {
    Some(width) => {
      if width < required_width {
        raise ValueTooLargeForWidth(value~, width~, span~)
      }
    }
    _ => ()
  }

  let bits = if value == 0 {
    [Zero]
  } else {
    let bits_rev = Array::new(capacity=required_width)
    let mut n = value

    while n > 0 {
      bits_rev.push(if (n & 1) == 0 { Zero } else { One })
      n = n >> 1
    }

    bits_rev.rev()
  }

  { bits, value: Some(value), span }
}

pub fn expect_int(self: Expr) -> Int! {
  match self {
    Natural(bits~, ..) => bits.as_int!()
    _ => raise ExpectedIntegerExpression(expr=self, span=self.span())
  }
}

pub fn get_port(self: ModuleSignature, name: String) -> Port? {
  for port in self.ports {
    if port.name == name {
      return Some(port)
    }
  }

  None
}

pub fn width(self: Type, span: Span) -> Int!AstError {
  match self {
    Nat => 32
    Logic => 1
    Vector(ty~, len~) => match len {
        Fixed(len) => ty.width!(span) * len
        Dynamic(_) => raise VectorLengthNotFixed(span~)
      }
    Instance(sig~, params~, accessed_ports~) => {
      let mut width = 0
      let params_env = Map::from_iter(params.iter())

      for port in sig.ports {
        if accessed_ports.contains(port.name) {
          width += port.ty.substitute(params_env~).width!(span)
        }
      }

      width
    }
    Name(_) => raise CannotGetWidthOfUnresolvedNamedType(span~)
    Struct(fields) => {
      let mut width = 0

      for expr in fields.values() {
        width += expr.width!(span)
      }

      width
    }
  }
}

pub fn substitute(self: Type, params_env~: Map[String, Int]) -> Type {
  match self {
    Nat => Nat
    Logic => Logic
    Vector(ty~, len=Dynamic(expr)) => {
      Vector(ty=substitute(ty, params_env~), len=match expr.partial_eval?(params=params_env) {
        Ok(Natural(bits~, ..)) => match bits.as_int?() {
          Ok(value) => Fixed(value)
          _ => Dynamic(expr)
        }
        _ => Dynamic(expr)
      })
    }
    Vector(ty~, len~) => Vector(ty=substitute(ty, params_env~), len~)
    Instance(sig~, params~, accessed_ports~) => {
      let new_params: Map[String, Int] = {}

      for name, value in params {
        new_params[name] = match params_env[name] {
          Some(new_value) => new_value
          None => value
        }
      }

      Instance(sig~, params=new_params, accessed_ports~)
    }
    Name(name~, params~) => {
      match params_env[name] {
        Some(_) => Nat
        None => Name(name~, params~)
      }
    }
    Struct(fields) => Struct(@utils.map_values(fields, fn(expr) { substitute(expr, params_env~) }))
  }
}

pub fn signature(self: ModuleDecl) -> ModuleSignature {
  {
    name: self.name,
    params: self.params,
    attributes: self.attributes,
    ports: self.ports,
    span: self.span,
  }
}

pub fn output_width(self: BinaryOp, wa: Int, wb: Int) -> Int {
  let wy = match self {
    Add => @utils.max(wa, wb) + 1
    Sub => @utils.max(wa, wb)
    Mul => wa + wb
    Div => wa
    Mod => wb
    Equ => 1
    Neq => 1
    Gtr => 1
    Lss => 1
    Geq => 1
    Leq => 1
    Shl => wa
    Shr => wa
    And => @utils.max(wa, wb)
    Or => @utils.max(wa, wb)
    Xor => @utils.max(wa, wb)
    Nand => @utils.max(wa, wb)
    Nor => @utils.max(wa, wb)
    Xnor => @utils.max(wa, wb)
    Ternary => @utils.max(wa, wb)
  }

  println("output_width: \{wa} \{self} \{wb} -> \{wy}")
  wy
}

pub fn inputs(self: ModuleSignature) -> Iter[Port] {
  self.ports.iter().filter(fn(port) { port.dir == Input })
}

pub fn outputs(self: ModuleSignature) -> Iter[Port] {
  self.ports.iter().filter(fn(port) { port.dir == Output })
}

pub fn inouts(self: ModuleSignature) -> Iter[Port] {
  self.ports.iter().filter(fn(port) { port.dir == Inout })
}

pub fn is_numerical(self: Type) -> Bool {
  match self {
    Nat => true
    Logic => true
    Vector(ty~, ..) => ty.is_numerical()
    _ => false
  }
}

pub fn Expr::nat(n: Int, width~: Int? = None, base~: Int = 10, span~: Span) -> Expr!AstError {
  let ty = match width {
    Some(width) => Type::Vector(ty=Logic, len=Fixed(width))
    None => Nat
  }

  Natural(bits=Bits::from!(n, width~, span~), width~, base~, span~, ty={ val: Some(ty) })
}

pub fn is_internal(self: Decl) -> Bool {
  match self {
    Module({ attributes, .. }) => attributes.contains("internal")
    ModuleDeclaration(sig) => sig.attributes.contains("internal")
    Const(_) => false
  }
}

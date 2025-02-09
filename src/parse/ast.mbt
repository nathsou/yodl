
pub(all) enum Expr {
  Natural(value~: BigInt, width~: Int?, base~: Int, span~: Span, ty~: Ref[Type?])
  Identifier(path~: Path, span~: Span, ty~: Ref[Type?])
  Unary(op~: UnaryOp, expr~: Expr, span~: Span, ty~: Ref[Type?])
  Binary(op~: BinaryOp, lhs~: Expr, rhs~: Expr, span~: Span, ty~: Ref[Type?])
  Indexing(expr~: Expr, index~: Expr, span~: Span, ty~: Ref[Type?])
  Slicing(expr~: Expr, hi~: Expr, lo~: Expr, kind~: PartSelect, span~: Span, ty~: Ref[Type?])
  FieldAccess(expr~: Expr, field~: String, span~: Span, ty~: Ref[Type?])
  Instance(path~: Path, params~: InstanceParams, ports~: Map[String, Expr], span~: Span, ty~: Ref[Type?])
  Vector(elems~: Array[Expr], span~: Span, ty~: Ref[Type?])
  Spread(expr~: Expr, span~: Span, ty~: Ref[Type?])
  Ternary(cond~: Expr, then~: Expr, else_~: Expr, span~: Span, ty~: Ref[Type?])
  Match(subject~: Expr, cases~: Array[(Expr, Expr)], default~: Expr?, span~: Span, ty~: Ref[Type?])
  Tuple(elems~: Array[Expr], span~: Span, ty~: Ref[Type?])
  Struct(fields~: Map[String, Expr], span~: Span, ty~: Ref[Type?])
  Replicate(expr~: Expr, count~: Expr, concat~: Bool, span~: Span, ty~: Ref[Type?])
  FunCall(name~: String, args~: Array[Expr], span~: Span, ty~: Ref[Type?])
  String(value~: String, span~: Span, ty~: Ref[Type?])
  Block(body~: Array[Stmt], last~: Expr?, span~: Span, ty~: Ref[Type?])
  If(cond~: Expr, then~: Expr, else_~: Expr?, span~: Span, ty~: Ref[Type?])
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
  Package(PackageDecl)
  Import(ImportDecl)
}

pub const BITS_PER_CHAR = 8

pub(all) enum Type {
  Nat(min_width~: Int)
  UInt(IntParam)
  SInt(IntParam)
  Vector(ty~: Type, len~: IntParam)
  Instance(sig~: ModuleSignature, params~: Map[String, Param], accessed_ports~: Set[String])
  Name(path~: Path, params~: Array[Param])
  Struct(Map[String, Type])
  String(len~: Int)
} derive(Eq)

pub fn Type::bool() -> Type {
  UInt(Fixed(1))
}

pub fn Type::uint(width: Int) -> Type {
  UInt(Fixed(width))
}

pub fn Type::sint(width: Int) -> Type {
  SInt(Fixed(width))
}

pub fn Type::empty() -> Type {
  UInt(Fixed(0))
}

pub(all) enum InstanceParam {
  Expr(name~: String?, value~: Expr)
  Type(name~: String?, value~: Type, span~: Span)
}

pub impl Spanned for InstanceParam with span(self) -> Span {
  match self {
    Expr(value~, ..) => value.span()
    Type(span~, ..) => span
  }
}

pub fn InstanceParam::as_param(self: InstanceParam) -> Param! {
  match self {
    Expr(value~, ..) => IntParam(value.as_int!())
    Type(value=ty, ..) => TypeParam(ty)
  }
}

pub fn InstanceParam::as_int(self: InstanceParam) -> Int! {
  match self {
    Expr(value~, ..) => value.as_int!()
    _ => raise Failure("Expected an integer parameter")
  }
}

pub fn InstanceParam::as_type(self: InstanceParam) -> Type! {
  match self {
    Type(value~, ..) => value
    _ => raise Failure("Expected a type parameter")
  }
}

pub(all) struct InstanceParams {
  params: Array[InstanceParam]
  instantiated: Array[(Expr, Type, Span)]
}

pub fn InstanceParams::new(params: Array[InstanceParam]) -> InstanceParams {
  { params, instantiated: [] }
}

pub(all) struct Path {
  packages: Array[String]
  member: String
} derive(Eq)

pub impl Hash for Path with hash_combine(self, hasher) {
  for package in self.packages {
    hasher.combine(package)
  }

  hasher.combine(self.member)
}

pub impl Show for Path with output(self, logger) {
  for package in self.packages {
    logger.write_string(package)
    logger.write_string("::")
  }

  logger.write_string(self.member)
}

pub fn Path::new(packages: Array[String], member: String) -> Path {
  { packages, member }
}

pub fn prepend(self: Path, packages: Array[String]) -> Path {
  let joined = packages + self.packages
  joined.dedup()
  Path::new(joined, self.member)
}

pub fn map[E: Error](self: InstanceParams, map_expr~: (Expr) -> Expr!E, map_type~: (Type) -> Type!E) -> InstanceParams!E {
  let new_list = Array::new(capacity=self.params.length())

  for param in self.params {
    match param {
      Expr(name~, value~) => {
        let value = map_expr!(value)
        new_list.push(InstanceParam::Expr(name~, value~))
      }
      Type(name~, value~, span~) => {
        let value = map_type!(value)
        new_list.push(InstanceParam::Type(name~, value~, span~))
      }
    }
  }

  {
    params: new_list,
    instantiated: self.instantiated,
  }
}

pub(all) enum UnaryOp {
  Not
} derive(Eq)

pub(all) enum BinaryOp {
  And; Or; Xor; Nand; Nor; Xnor
  Add; Sub; Mul; Div; Mod
  Equ; Neq; Lss; Gtr; Leq; Geq
  Shl; Shr
  Ternary // hack for precedence climbing
} derive(Eq)

fn precedence(self: BinaryOp) -> Int {
  match self {
    Mul | Div | Mod => 8
    Add | Sub => 7
    Shl | Shr => 6
    Lss | Gtr | Leq | Geq => 5
    Equ | Neq => 4
    And | Nand => 3
    Xor | Xnor => 2
    Or | Nor => 1
    Ternary => 0
  }
}

pub(all) enum PartSelect {
  Absolute; Width
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

pub(all) enum ModuleParameterAnnotation {
  Type(Type)
  AnyType
}

pub impl Show for ModuleParameterAnnotation with output(self, logger) {
  match self {
    Type(ty) => logger.write_object(ty)
    AnyType => logger.write_string("type")
  }
}

pub(all) struct ModuleParameter {
  name: String
  ty: ModuleParameterAnnotation
  span: Span
}

pub(all) struct ModuleSignature {
    path: Path
    params: Array[ModuleParameter]
    attributes: Map[String, Attribute]
    ports: Array[Port]
    span: Span
}

impl Eq for ModuleSignature with op_equal(self, other) {
  self.path == other.path && self.span.file == other.span.file
}

pub fn ModuleSignature::get_param(self: ModuleSignature, name: String) -> ModuleParameter? {
  for param in self.params {
    if param.name == name {
      return Some(param)
    }
  }

  None
}

pub(all) struct ConstDecl {
  path: Path
  ty: Type?
  expr: Expr
  span: Span
}

pub(all) struct PackageDecl {
  name: String
  mut body: Array[Decl]
  span: Span
}

pub(all) struct ImportDecl {
  packages: Array[String]
  span: Span
}

pub(all) enum IntParam {
  Fixed(Int)
  Dynamic(Expr)
}

impl Eq for IntParam with op_equal(self, other) {
  match (self, other) {
    (Fixed(a), Fixed(b)) => a == b
    _ => false
  }
}

pub type! AstError {
  ExpectedIntegerExpression(expr~: Expr, span~: Span)
  IntParamNotFixed(span~: Span)
  CannotGetWidthOfUnresolvedNamedType(span~: Span)
  InvalidFunCallArity(name~: String, expected~: Arity, actual~: Int, span~: Span)
  ExpectedStringExpression(expr~: Expr, span~: Span)
  InvalidModuleParameter(span~: Span)
  ConflictingInstanceParameterValue(name~: String, span~: Span)
  UnknownModuleParameter(name~: String, span~: Span)
  TypeParamInsteadOfExpr(span~: Span)
  UnknownFunction(name~: String, span~: Span)
}

pub impl Show for AstError with output(self, logger) {
  match self {
    ExpectedIntegerExpression(expr~, ..) => logger.write_string("Expected an integer expression, got: \{expr.ctor()}")
    IntParamNotFixed(_) => logger.write_string("Int parameter must be fixed")
    CannotGetWidthOfUnresolvedNamedType(_) => logger.write_string("Cannot get width of unresolved named type")
    InvalidFunCallArity(name~, expected~, actual~, ..) => logger.write_string("Function '\{name}' expected \{expected} argument(s), but got \{actual}")
    ExpectedStringExpression(expr~, ..) => logger.write_string("Expected a string expression, got: \{expr.ctor()}")
    InvalidModuleParameter(_) => logger.write_string("Invalid module parameter")
    ConflictingInstanceParameterValue(name~, ..) => {
      logger.write_string("Conflicting value for instance parameter '\{name}'")
    }
    UnknownModuleParameter(name~, ..) => {
      logger.write_string("Unknown module parameter '\{name}'")
    }
    TypeParamInsteadOfExpr(_) => {
      logger.write_string("Received a type parameter instead of an expression")
    }
    UnknownFunction(name~, ..) => logger.write_string("Unknown function '\{name}'")
  }

  logger.write_string(self.show_context())
}

pub impl Spanned for AstError with span(self) -> Span {
  match self {
    ExpectedIntegerExpression(span~, ..) => span
    IntParamNotFixed(span~) => span
    CannotGetWidthOfUnresolvedNamedType(span~) => span
    InvalidFunCallArity(span~, ..) => span
    ExpectedStringExpression(span~, ..) => span
    InvalidModuleParameter(span~) => span
    ConflictingInstanceParameterValue(span~, ..) => span
    UnknownModuleParameter(span~, ..) => span
    TypeParamInsteadOfExpr(span~) => span
    UnknownFunction(span~, ..) => span
  }
}

pub fn expect_fixed(self: IntParam, span: Span) -> Int! {
  match self {
    Fixed(value) => value
    Dynamic(_) => {
      raise IntParamNotFixed(span~)
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
  direction: PortDirection
  span: Span
  optional: Bool
  attributes: Map[String, Attribute]
}

pub(all) struct ModuleDecl {
    path: Path
    params: Array[ModuleParameter]
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
    String(ty~, ..) => ty
    Block(ty~, ..) => ty
    If(ty~, ..) => ty
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
    String(span~, ..) => span
    Block(span~, ..) => span
    If(span~, ..) => span
  }
}

pub impl Spanned for Stmt with span(self: Stmt) -> Span {
  match self {
    Expr(span~, ..) => span
    Const(span~, ..) => span
    Let(span~, ..) => span
    Assign(span~, ..) => span
    For(span~, ..) => span
    Scope(span~, ..) => span
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
    FieldAccess(_) => "FieldAccess"
    Instance(_) => "Instance"
    Vector(_) => "Vector"
    Spread(_) => "Spread"
    Ternary(_) => "Ternary"
    Match(_) => "Match"
    Tuple(_) => "Tuple"
    Struct(_) => "Struct"
    Replicate(_) => "Replicate"
    FunCall(_) => "FunCall"
    String(_) => "String"
    Block(_) => "Block"
    If(_) => "If"
  }
}

pub fn set_ty(self: Expr, ty: Type) -> Unit {
  self.ty().val = Some(ty)
}

pub fn is_constant_expr(self: Expr) -> Bool {
  match self {
    Natural(..) => true
    Identifier(..) => true
    String(..) => true
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
    Block(body=[], last=Some(last), ..) => last.is_constant_expr()
    Block(..) => false
    If(_) => false
  }
}

pub(all) enum Param {
  IntParam(Int)
  ValParam(value~: BigInt, width~: Int)
  TypeParam(Type)
} derive(Eq)

pub impl Show for Param with output(self, logger) -> Unit {
  match self {
    IntParam(n) => logger.write_string(n.to_string())
    ValParam(value~, width~) => {
      logger.write_string("\{width}'b")
      let bytes = value.to_octets()

      if bytes.length() <= 4 {
        for byte in bytes {
          logger.write_string(byte.to_string())
        }
      } else {
        for i in 0..<3 {
          logger.write_string(bytes[i].to_string())
        }

        logger.write_string("...")
      }
    }
    TypeParam(ty) => logger.write_string(ty.to_string())
  }
}

pub impl Hash for Param with hash_combine(self, hasher) {
  match self {
    IntParam(n) => hasher.combine(n)
    ValParam(value~, width~) => {
      for byte in value.to_octets() {
        hasher.combine(byte)
      }

      hasher.combine(width)
    }
    TypeParam(ty) => hasher.combine(ty.to_string())
  }
}

pub fn Expr::as_param(self: Expr) -> Param!AstError {
  match self {
    Natural(value~, width=Some(width), ..) => ValParam(value~, width~)
    Natural(value~, width=None, ..) => IntParam(value.to_int())
    _ => raise InvalidModuleParameter(span=self.span())
  }
}

pub fn as_expr(self: Param, span~: Span) -> Expr! {
  match self {
    IntParam(n) => {
      let bn = BigInt::from_int(n)
      Natural(value=bn, width=None, base=10, span=span, ty={ val: Some(Nat(min_width=@utils.significant_bits(bn))) })
    }
    ValParam(value~, width~) => Natural(value~, width=Some(width), base=2, span=span, ty={ val: Some(Type::uint(width)) })
    TypeParam(_) => raise TypeParamInsteadOfExpr(span~)
  }
}

// perform partial evaluation on the expression
pub fn partial_eval(self: Expr, params~: Map[String, Param] = {}) -> Expr! {
  rewrite_expr!(self, rewr_stmt=fn(stmt) { Iter::singleton(stmt) }, rewr_expr=fn!(expr) {
    match expr {
      Identifier(path={ packages: [], member }, ..) => {
        match params[member] {
          Some(IntParam(n)) => {
            Some(Natural(value=BigInt::from_int(n), width=None, base=10, span=expr.span(), ty=expr.ty()))
          }
          Some(ValParam(value~, width~)) => {
            Some(Natural(value~, width=Some(width), base=2, span=expr.span(), ty=expr.ty()))
          }
          Some(TypeParam(_)) => {
            raise TypeParamInsteadOfExpr(span=expr.span())
          }
          None => None
        }
      }
      Unary(op~, expr~, span~, ty~) => {
        match expr.as_int?() {
          Ok(value) => {
            let value = match op {
              Not => if value == 0 { 1 } else { 0 }
            }

            Some(Natural(value=BigInt::from_int(value), width=None, base=10, span~, ty~))
          }
          _ => None
        }
      }
      Binary(op~, lhs~, rhs~, span~, ty~) => {
        let lhs_value = lhs.as_bigint?()
        let rhs_value = rhs.as_bigint?()
        match (lhs_value, rhs_value, lhs, rhs, op) {
          (Ok(lhs), Ok(rhs), _, _, _) => {
            let value = match op {
              Add => lhs + rhs
              Sub => lhs - rhs
              Mul => lhs * rhs
              Div => lhs / rhs
              Mod => lhs % rhs
              Shl => lhs << rhs.to_int()
              Shr => lhs >> rhs.to_int()
              Equ => if lhs == rhs { 1 } else { 0 }
              Neq => if lhs != rhs { 1 } else { 0 }
              Lss => if lhs < rhs { 1 } else { 0 }
              Gtr => if lhs > rhs { 1 } else { 0 }
              Leq => if lhs <= rhs { 1 } else { 0 }
              Geq => if lhs >= rhs { 1 } else { 0 }
              And => lhs & rhs
              Or => lhs | rhs
              Xor => lhs ^ rhs
              Nand => @utils.bitwise_not(lhs & rhs)
              Nor => @utils.bitwise_not(lhs | rhs)
              Xnor => @utils.bitwise_not(lhs ^ rhs)
              _ => raise Failure("Invalid arithmetical binary operator")
            }

            Some(Natural(value~, width=None, base=10, span~, ty~))
          }
          (Ok(0), _, _, b, op) | (_, Ok(0), b, _, op) => {
            match op {
              And => Some(Expr::nat(0, span~))
              Or | Xor => Some(b)
              Nand => Some(Expr::nat(1, span~))
              Xnor | Nor => Some(Expr::Unary(op=Not, expr=b, span~, ty~))
              _ => None
            }
          }
          (Ok(1), _, _, b, op) | (_, Ok(1), b, _, op) => {
            match op {
              And | Xnor => Some(b)
              Or => Some(Expr::nat(1, span~))
              Xor | Nand => Some(Expr::Unary(op=Not, expr=b, span~, ty~))
              Nor => Some(Expr::nat(0, span~))
              _ => None
            }
          }
          _ => None
        }
      }
      Ternary(cond~, then~, else_~, ..) | If(cond~, then~, else_=Some(else_), ..) => {
        match cond.partial_eval!().as_int?() {
          Ok(cond) => {
            Some(if cond != 0 { then } else { else_ })
          }
          _ => None
        }
      }
      If(cond~, then~, else_=None, span~, ty~) => {
        match cond.as_int?() {
          Ok(cond) => {
            if cond != 0 { Some(then) } else { Some(Block(body=[], last=None, span~, ty~)) }
          }
          _ => None
        }
      }
      Match(subject~, cases~, ..) => {
        match subject.as_int?() {
          Ok(subject) => {
            for case in cases {
              let (value, rhs) = case
              match value.as_int?() {
                Ok(case) => if subject == case { return Some(rhs) }
                _ => ()
              }
            }

            None
          }
          _ => None
        }
      }
      FunCall(name~, args~, span~, ty=_) => {
        let fun = match builtin_functions[name] {
          Some(fun) => fun
          None => raise UnknownFunction(name~, span~)
        }

        let (min_arity, max_arity) = fun.arity.as_range()

        if args.length() < min_arity || args.length() > max_arity {
          raise InvalidFunCallArity(name~, expected=fun.arity, actual=args.length(), span~)
        }

        (fun.apply)!(args, span)
      }
      _ => None
    }
  })
}

enum Arity {
  Fixed(Int)
  Range(min~: Int, max~: Int)
}

fn as_range(self: Arity) -> (Int, Int) {
  match self {
    Fixed(value) => (value, value)
    Range(min~, max~) => (min, max)
  }
}

impl Show for Arity with output(self, logger) {
  match self {
    Fixed(value) => logger.write_string(value.to_string())
    Range(min~, max~) => logger.write_string("\{min}..\{max}")
  }
}

struct BuiltinFunction {
  arity: Arity
  apply: (Array[Expr], Span) -> Expr?!
}

let builtin_functions: Map[String, BuiltinFunction] = {
  "$clog2": {
    arity: Fixed(1),
    apply: fn(args, span) {
      let arg = args[0].as_int!()
      let value = @utils.clog2(arg)
      Some(Expr::nat(value, span~))
    }
  },
  "$pow": {
    arity: Fixed(2),
    apply: fn(args, span) {
      let base = args[0].as_int!()
      let exp = args[1].as_int!()
      Some(Expr::nat(@utils.pow(base, exp), span~))
    }
  },
  "$cdiv": {
    arity: Fixed(2),
    apply: fn(args, span) {
      let dividend = args[0].as_int!()
      let divisor = args[1].as_int!()
      Some(Expr::nat(@utils.cdiv(dividend, divisor), span~))
    }
  },
  "$readmemb": {
    arity: Range(min=2, max=2),
    apply: fn(args, span) {
      match args {
        [path, _mem] => { let _ = path.expect_string!() }
        _ => raise InvalidFunCallArity(name="$readmemb", expected=Range(min=2, max=2), actual=args.length(), span~)
      }

      None
    }
  },
  "uint": {
    arity: Fixed(1),
    apply: fn(_, _) { None }
  },
  "sint": {
    arity: Fixed(1),
    apply: fn(_, _) { None }
  },
}

pub fn Expr::as_int(self: Expr) -> Int! {
  match self {
    Natural(value~, ..) => value.to_int()
    _ => {
      raise ExpectedIntegerExpression(expr=self, span=self.span())
    }
  }
}

pub fn Expr::as_bigint(self: Expr) -> BigInt! {
  match self {
    Natural(value~, ..) => value
    _ => raise ExpectedIntegerExpression(expr=self, span=self.span())
  }
}

pub fn expect_string(self: Expr) -> String! {
  match self {
    String(value=str, ..) => str
    _ => raise ExpectedStringExpression(expr=self, span=self.span())
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
    Nat(min_width~) => @math.maximum(min_width, 32)
    UInt(Fixed(width)) => width
    SInt(Fixed(width)) => width
    Vector(ty~, len=Fixed(len)) => ty.width!(span) * len
    UInt(Dynamic(_)) | SInt(Dynamic(_)) | Vector(ty=_, len=Dynamic(_)) => {
      raise IntParamNotFixed(span~)
    }
    Instance(sig~, params~, accessed_ports~) => {
      let mut width = 0

      for port in sig.ports {
        if accessed_ports.contains(port.name) {
          width += port.ty.substitute(params).width!(span)
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
    String(len~) => len * BITS_PER_CHAR // ascii encoding
  }
}

pub fn substitute(self: Type, params_env: Map[String, Param]) -> Type {
  match self {
    Nat(_) | String(_) => self
    UInt(Fixed(width)) => UInt(Fixed(width))
    SInt(Fixed(width)) => SInt(Fixed(width))
    UInt(Dynamic(expr)) | SInt(Dynamic(expr)) => {
      let is_unsigned = match self { UInt(_) => true; _ => false }
      match expr.partial_eval?(params=params_env) {
        Ok(Natural(value~, ..)) => if is_unsigned { UInt(Fixed(value.to_int())) } else { SInt(Fixed(value.to_int())) }
        _ => if is_unsigned { UInt(Dynamic(expr)) } else { SInt(Dynamic(expr)) }
      }
    }
    Vector(ty~, len=Dynamic(expr)) => {
      Vector(ty=ty.substitute(params_env), len=match expr.partial_eval?(params=params_env) {
        Ok(Natural(value~, ..)) => Fixed(value.to_int())
        _ => Dynamic(expr)
      })
    }
    Vector(ty~, len~) => Vector(ty=ty.substitute(params_env), len~)
    Instance(sig~, params~, accessed_ports~) => {
      let new_params = Map::new(capacity=params.size()) 

      for name, value in params {
        new_params[name] = match params_env[name] {
          Some(new_value) => new_value
          None => value
        }
      }

      Instance(sig~, params=new_params, accessed_ports~)
    }
    Name(path~, params~) => {
      match path.packages {
        [] => match params_env[path.member] {
          Some(TypeParam(ty)) => ty.substitute(params_env)
          None | Some(IntParam(_) | ValParam(_)) => Name(path~, params~)
        }
        _ => Name(path~, params~)
      }
    }
    Struct(fields) => Struct(@utils.map_values(fields, fn(ty) { ty.substitute(params_env) }))
  }
}

pub fn signature(self: ModuleDecl) -> ModuleSignature {
  {
    path: self.path,
    params: self.params,
    attributes: self.attributes,
    ports: self.ports,
    span: self.span,
  }
}

pub fn inputs(self: ModuleSignature) -> Iter[Port] {
  self.ports.iter().filter(fn(port) { port.direction == Input })
}

pub fn outputs(self: ModuleSignature) -> Iter[Port] {
  self.ports.iter().filter(fn(port) { port.direction == Output })
}

pub fn inouts(self: ModuleSignature) -> Iter[Port] {
  self.ports.iter().filter(fn(port) { port.direction == Inout })
}

pub fn is_numerical(self: Type) -> Bool {
  match self {
    Nat(_) | UInt(_) | SInt(_) => true
    Vector(ty~, ..) => ty.is_numerical()
    _ => false
  }
}

pub fn has_zero_width(self: Type) -> Bool {
  match self {
    Nat(_) => false
    UInt(Fixed(width)) | SInt(Fixed(width)) => width == 0
    UInt(Dynamic(_)) | SInt(Dynamic(_)) => false
    Vector(ty~, len~) => match len {
      Fixed(0) => true
      _ => ty.has_zero_width()
    }
    Instance(sig~, ..) => sig.ports.is_empty()
    Name(_) => false
    Struct(fields) => fields.values().all(fn(ty) { ty.has_zero_width() })
    String(len~) => len == 0
  }
}

pub fn Expr::nat(n: Int, width~: Int? = None, base~: Int = 10, span~: Span) -> Expr {
  let ty = match width {
    Some(width) => if n > 0 { Type::uint(width) } else { Type::uint(width) }
    None => Nat(min_width=@utils.significant_bits(BigInt::from_int(n)))
  }

  Natural(value=BigInt::from_int(n), width~, base~, span~, ty={ val: Some(ty) })
}

pub fn InstanceParams::as_map(self: InstanceParams, names~: Array[String]) -> Map[String, InstanceParam]!AstError {
  let map = Map::new(capacity=names.length())

  fn checked_set(name: String, param: InstanceParam) -> Unit!AstError {
    if not(names.contains(name)) {
      raise UnknownModuleParameter(name~, span=param.span())
    }

    if map.contains(name) {
      raise ConflictingInstanceParameterValue(name~, span=param.span())
    } else {
      map[name] = param
    }
  }

  for idx, param in self.params {
    match param {
      Expr(name=Some(name), ..) | Type(name=Some(name), ..) => {
        checked_set!(name, param)
      }
      _ => {
        if idx >= names.length() {
          raise InvalidModuleParameter(span=param.span())
        }

        checked_set!(names[idx], param)
      }
    }
  }

  map
}

pub fn clone(self: Type) -> Type {
  match self {
    Nat(min_width~) => Nat(min_width~)
    UInt(width) => UInt(width)
    SInt(width) => SInt(width)
    Vector(ty~, len~) => Vector(ty=ty.clone(), len~)
    Instance(sig~, params~, accessed_ports~) => Instance(sig~, params~, accessed_ports~)
    Name(path~, params~) => Name(path~, params~)
    Struct(fields) => Struct(@utils.map_values(fields, clone))
    String(len~) => String(len~)
  }
}

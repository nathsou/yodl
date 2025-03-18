
pub(all) enum Expr {
  Natural(value~: BigInt, width~: Int?, base~: Int, span~: Span, ty~: Ref[Type?])
  Identifier(path~: Path, span~: Span, ty~: Ref[Type?])
  Unary(op~: UnaryOp, expr~: Expr, span~: Span, ty~: Ref[Type?])
  Binary(op~: BinaryOp, lhs~: Expr, rhs~: Expr, output_width~: Ref[Int?], span~: Span, ty~: Ref[Type?])
  Indexing(expr~: Expr, index~: Expr, span~: Span, ty~: Ref[Type?])
  Slicing(expr~: Expr, hi~: Expr, lo~: Expr, kind~: PartSelect, span~: Span, ty~: Ref[Type?])
  FieldAccess(expr~: Expr, field~: String, span~: Span, ty~: Ref[Type?])
  Instance(path~: Path, params~: InstanceParams, ports~: Map[String, Expr], span~: Span, ty~: Ref[Type?])
  Vector(elems~: Array[Expr], span~: Span, ty~: Ref[Type?])
  Spread(expr~: Expr, span~: Span, ty~: Ref[Type?])
  Concat(elems~: Array[Expr], span~: Span, ty~: Ref[Type?])
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
  TypeAlias(TypeAliasDecl)
}

pub const BITS_PER_CHAR = 8

pub(all) enum Type {
  Nat(min_width~: Int)
  UInt(IntParam)
  SInt(IntParam)
  Clock
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

pub fn Type::is_ground(self: Type) -> Bool {
  match self {
    Nat(_) | UInt(_) | SInt(_) => true
    _ => false
  }
}

pub fn Type::is_string(self: Type) -> Bool {
  match self {
    String(_) => true
    Vector(ty~, ..) => match ty {
      UInt(Fixed(BITS_PER_CHAR)) => true
      _ => false
    }
    _ => false
  }
}

// FIRRTL spec 4.1.0, section 14.2:
// Intuitively, the mask type
// mirrors the aggregate structure of the element type except with all ground types replaced
// with a single bit unsigned integer type. The non-masked portion of the data value is defined
// as the set of data value leaf sub-elements where the corresponding mask leaf sub-element is
// high.
pub fn Type::mask(self: Type, span~: Span) -> Type! {
  match self {
    UInt(_) | SInt(_) | Nat(_) | Clock | String(_) => UInt(Fixed(1))
    Vector(ty~, len~) => Vector(ty=ty.mask!(span~), len~)
    Struct(fields) => Struct({
      let new_fields = Map::new(capacity=fields.size())

      for name, ty in fields {
        new_fields[name] = ty.mask!(span~)
      }

      new_fields
    })
    Instance(_) | Name(_) => raise NonStorableType(ty=self, span~)
  }
}

pub(all) struct InstanceParams {
  params: Array[(String?, Param)]
  instantiated: Array[(Expr, Type, Span)]
}

pub fn InstanceParams::new(params: Array[(String?, Param)]) -> InstanceParams {
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
    let name = param.0
    match param.1 {
      Resolved(TypeParam(ty~, span~)) => {
        let new_ty = map_type!(ty)
        new_list.push((name, Resolved(TypeParam(ty=new_ty, span~))))
      }
      Unresolved(PathParam(path~, span~)) => {
        new_list.push((name, Unresolved(PathParam(path~, span~))))
      }
      Unresolved(ExprParam(expr)) => {
        let new_expr = map_expr!(expr)
        new_list.push((name, Unresolved(ExprParam(new_expr))))
      }
      Unresolved(TypeParam(ty~, span~)) => {
        let new_ty = map_type!(ty)
        new_list.push((name, Resolved(TypeParam(ty=new_ty, span~))))
      }
      Resolved(param) => {
        new_list.push((name, Resolved(param)))
      }
    }
  }

  {
    params: new_list,
    instantiated: self.instantiated,
  }
}

pub(all) enum UnaryOp {
  Not; Neg; Andr; Orr; Xorr
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

pub(all) struct TypeAliasDecl {
  name: String
  parameters: Array[String]
  ty: Type
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
  UnresolvedParameter(name~: String, span~: Span)
  CannotMixNamedAndOrderedModuleParameters(span~: Span)
  ExpectedTypeParameter(span~: Span)
  ExpectedIntParameter(span~: Span)
  NonStorableType(ty~: Type, span~: Span)
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
    UnresolvedParameter(name~, ..) => logger.write_string("Unresolved parameter '\{name}'")
    CannotMixNamedAndOrderedModuleParameters(_) => logger.write_string("Cannot mix named and ordered module parameters")
    ExpectedTypeParameter(_) => logger.write_string("Expected a type parameter")
    ExpectedIntParameter(_) => logger.write_string("Expected an integer parameter")
    NonStorableType(ty~, ..) => logger.write_string("Type '\{ty}' is not storable")
  }

  logger.write_string(self.show_context(use_ansi_colors=false))
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
    UnresolvedParameter(span~, ..) => span
    CannotMixNamedAndOrderedModuleParameters(span~) => span
    ExpectedTypeParameter(span~) => span
    ExpectedIntParameter(span~) => span
    NonStorableType(span~, ..) => span
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
    Concat(ty~, ..) => ty
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
  show_context(Self, use_ansi_colors~: Bool) -> String
}

impl Spanned with show_context(self, use_ansi_colors~: Bool) -> String {
  let span = self.span()
  let builder = StringBuilder::new()

  builder.write_string(", ")

  if use_ansi_colors {
    builder.write_string("\x1b[4m")
  }

  builder.write_string("\{span}")
  
  if use_ansi_colors {
    builder.write_string("\x1b[0m")
  }

  builder.write_string("\n\n")
  builder.write_string(span.context(use_ansi_colors~))

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
    Concat(span~, ..) => span
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
    Concat(_) => "Concat"
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

pub fn Expr::is_constant_expr(self: Expr) -> Bool {
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
    Vector(elems~, ..) => elems.iter().all(Expr::is_constant_expr)
    Spread(_) => false
    Concat(_) => false
    Ternary(_) => false
    Match(_) => false
    Tuple(_) => false
    Struct(_) => false
    Replicate(_) => false
    FunCall(name="$flip" | "$rev", args=[arg], ..) => arg.is_constant_expr()
    FunCall(_) => false
    Block(body=[], last=Some(last), ..) => last.is_constant_expr()
    Block(..) => false
    If(_) => false
  }
}

pub(all) enum UnresolvedParam {
  PathParam(path~: Path, span~: Span)
  ExprParam(Expr)
  TypeParam(ty~: Type, span~: Span)
}

pub(all) enum ResolvedParam {
  ConstParam(value~: ConstValue, span~: Span)
  TypeParam(ty~: Type, span~: Span)
}

pub(all) enum ConstValue {
  Natural(value~: BigInt, width~: Int?, base~: Int, span~: Span)
  String(value~: String, span~: Span)
} derive(Eq)

pub fn ConstValue::from(expr: Expr) -> ConstValue? {
  match expr {
    Natural(value~, width~, base~, span~, ty=_) => Some(Natural(value~, width~, base~, span~))
    String(value~, span~, ty=_) => Some(String(value~, span~))
    _ => None
  }
}

pub(all) enum Param {
  Unresolved(UnresolvedParam)
  Resolved(ResolvedParam)
} derive(Eq)

pub impl Eq for ResolvedParam with op_equal(self, other) {
  match (self, other) {
    (ConstParam(value=a, ..), ConstParam(value=b, ..)) => a == b
    (TypeParam(ty=a, ..), TypeParam(ty=b, ..)) => a == b
    _ => false
  }
}

pub impl Eq for UnresolvedParam with op_equal(self, other) {
  match (self, other) {
    (PathParam(path=a, ..), PathParam(path=b, ..)) => a == b
    (ExprParam(_), ExprParam(_)) => false
    (TypeParam(ty=a, ..), TypeParam(ty=b, ..)) => a == b
    _ => false
  }
}

pub impl Hash for ResolvedParam with hash_combine(self, hasher) {
  match self {
    ConstParam(value~, ..) => {
      match value {
        Natural(value~, width~, base=_, span=_) => {
          for byte in value.to_octets() {
            hasher.combine(byte)
          }

          hasher.combine(width)
        }
        String(value~, span=_) => hasher.combine(value)
      }
    }
    TypeParam(ty~, ..) => hasher.combine(ty.to_string())
  }
}

pub impl Spanned for Param with span(self) -> Span {
  match self {
    Unresolved(param) => match param {
      PathParam(span~, ..) => span
      ExprParam(expr) => expr.span()
      TypeParam(span~, ..) => span
    }
    Resolved(param) => match param {
      ConstParam(span~, ..) => span
      TypeParam(span~, ..) => span
    }
  }
}

pub fn Param::as_type(self: Param) -> Type! {
  match self {
    Unresolved(TypeParam(ty~, ..)) => ty
    Resolved(TypeParam(ty~, ..)) => ty
    _ => raise ExpectedTypeParameter(span=self.span())
  }
}

pub fn Param::as_int(self: Param) -> Int! {
  match self {
    Unresolved(ExprParam(expr)) => expr.as_int!()
    Resolved(ConstParam(value=Natural(value~, ..), span=_)) => value.to_int()
    _ => raise ExpectedIntParameter(span=self.span())
  }
}

pub fn ConstValue::as_expr(self: ConstValue) -> Expr {
  match self {
    Natural(value~, width~, base~, span~) => Natural(value~, width~, base~, span~, ty={ val: None })
    String(value~, span~) => String(value~, span~, ty={ val: None })
  }
}

pub fn ResolvedParam::as_expr(self: ResolvedParam) -> Expr! {
  match self {
    ConstParam(value~, span=_) => value.as_expr()
    TypeParam(span~, ..) => raise TypeParamInsteadOfExpr(span~)
  }
}

pub fn keep_and_check_resolved(params: Map[String, Param], span~: Span) -> Map[String, ResolvedParam]!AstError {
  let resolved_params = {}

  for name, param in params {
    if param is Resolved(p) {
      resolved_params[name] = p
    } else {
      
      raise UnresolvedParameter(name~, span~)
    }
  }

  resolved_params
}

// perform partial evaluation on the expression
pub fn partial_eval(self: Expr, params~: Map[String, ResolvedParam] = {}) -> Expr! {
  rewrite_expr!(self, rewr_stmt=fn(stmt) { Iter::singleton(stmt) }, rewr_expr=fn!(expr) {
    match expr {
      Identifier(path={ packages: [], member }, ..) => {
        match params[member] {
          Some(ConstParam(value~, span=_)) => {
            Some(value.as_expr())
          }
          Some(TypeParam(_)) => {
            raise TypeParamInsteadOfExpr(span=expr.span())
          }
          None => None
        }
      }
      Unary(op=Neg, ..) => None
      Unary(op~, expr~, span~, ty~) => {
        match expr.as_int?() {
          Ok(value) => {
            let value = match op {
              Not => @utils.bitwise_not(BigInt::from_int(value)).to_int()
              Andr => @utils.bits(value).all(fn(b) { b }).to_int()
              Orr => @utils.bits(value).any(fn(b) { b }).to_int()
              Xorr => @utils.bits(value).fold(init=0, fn(acc, b) { acc ^ b.to_int() })
              Neg => raise @utils.unreachable()
            }

            Some(Natural(value=BigInt::from_int(value), width=None, base=10, span~, ty~))
          }
          _ => None
        }
      }
      Binary(op~, lhs~, rhs~, output_width=_, span~, ty~) => {
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

priv struct BuiltinFunction {
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
  "$rev": {
    arity: Fixed(1),
    apply: fn(_, _) { None }
  },
  "$flip": {
    arity: Fixed(1),
    apply: fn(_, _) { None }
  },
  "$readmemb": {
    arity: Range(min=2, max=2),
    apply: fn(args, _) {
      match args {
        [path, _mem] => { let _ = path.expect_string!() }
        _ => ()
      }

      None
    }
  },
  "$readmemh": {
    arity: Range(min=2, max=2),
    apply: fn(args, _) {
      match args {
        [path, _mem] => { let _ = path.expect_string!() }
        _ => ()
      }

      None
    }
  },
  "$printf": {
    arity: Range(min=1, max=@int.max_value),
    apply: fn(_, _) { None }
  },
  "$assert": {
    arity: Range(min=1, max=@int.max_value),
    apply: fn(_, _) { None }
  },
  "$stop": {
    arity: Range(min=0, max=1),
    apply: fn(_, _) { None }
  },
  "uint": {
    arity: Fixed(1),
    apply: fn(_, _) { None }
  },
  "sint": {
    arity: Fixed(1),
    apply: fn(_, _) { None }
  },
  "clock": {
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
    Nat(min_width~) => min_width
    UInt(Fixed(width)) => width
    SInt(Fixed(width)) => width
    Clock => 1
    Vector(ty~, len=Fixed(len)) => ty.width!(span) * len
    UInt(Dynamic(_)) | SInt(Dynamic(_)) | Vector(ty=_, len=Dynamic(_)) => {
      raise IntParamNotFixed(span~)
    }
    Instance(sig~, params~, accessed_ports~) => {
      let mut width = 0
      let resolved_params = keep_and_check_resolved!(params, span~)

      for port in sig.ports {
        if accessed_ports.contains(port.name) {
          width += port.ty.substitute!(resolved_params, span~).width!(span)
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

pub fn substitute(self: Type, params_env: Map[String, ResolvedParam], span~: Span) -> Type!AstError {
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
    Clock => Clock
    Vector(ty~, len=Dynamic(expr)) => {
      Vector(ty=ty.substitute!(params_env, span~), len=match expr.partial_eval?(params=params_env) {
        Ok(Natural(value~, ..)) => Fixed(value.to_int())
        _ => Dynamic(expr)
      })
    }
    Vector(ty~, len~) => Vector(ty=ty.substitute!(params_env, span~), len~)
    Instance(sig~, params~, accessed_ports~) => {
      let new_params = Map::new(capacity=params.size()) 

      for name, value in params {
        new_params[name] = match params_env[name] {
          Some(new_value) => Resolved(new_value)
          None => value
        }
      }

      Instance(sig~, params=new_params, accessed_ports~)
    }
    Name(path~, params~) => {
      let new_params = Array::new(capacity=params.length())

      for param in params {
        match param {
          Unresolved(PathParam(path~, span~)) => {
            new_params.push(Unresolved(PathParam(path~, span~)))
          }
          Resolved(TypeParam(ty~, span~)) | Unresolved(TypeParam(ty~, span~)) => {
            let new_ty = ty.substitute!(params_env, span~)
            new_params.push(Resolved(TypeParam(ty=new_ty, span~)))
          }
          _ => new_params.push(param)
        }
      }

      if path is { packages: [], member: "MemoryMask" } && new_params is [Resolved(TypeParam(ty~, ..))] {
        if ty.mask?(span~) is Ok(mask) {
          return mask
        }
      }

      match path.packages {
        [] => match params_env[path.member] {
          Some(TypeParam(ty~, ..)) => ty.substitute!(params_env, span~)
          None | Some(ConstParam(_)) => Name(path~, params=new_params)
        }
        _ => Name(path~, params=new_params)
      }
    }
    Struct(fields) => Struct({
      let new_fields = Map::new(capacity=fields.size())

      for name, ty in fields {
        new_fields[name] = ty.substitute!(params_env, span~)
      }

      new_fields
    })
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
    _ => false
  }
}

pub fn has_zero_width(self: Type) -> Bool {
  match self {
    Nat(_) => false
    UInt(Fixed(width)) | SInt(Fixed(width)) => width == 0
    UInt(Dynamic(_)) | SInt(Dynamic(_)) => false
    Clock => false
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

pub fn InstanceParams::as_map(self: InstanceParams, names~: Array[String]) -> Map[String, Param]!AstError {
  let map = Map::new(capacity=names.length())

  fn checked_set(name: String, param: Param) -> Unit!AstError {
    if not(names.contains(name)) {
      raise UnknownModuleParameter(name~, span=param.span())
    }

    if map.contains(name) {
      raise ConflictingInstanceParameterValue(name~, span=param.span())
    } else {
      map[name] = param
    }
  }

  let mut ordered = false
  let mut named = false

  for idx, entry in self.params {
    let (name, param) = entry

    match name {
      Some(name) => {
        named = true
        checked_set!(name, param)
      }
      _ => {
        ordered = true
        if idx >= names.length() {
          raise InvalidModuleParameter(span=param.span())
        }

        checked_set!(names[idx], param)
      }
    }

    if ordered && named {
      raise CannotMixNamedAndOrderedModuleParameters(span=param.span())
    }
  }
  map
}

pub fn Type::clone(self: Type) -> Type {
  match self {
    Nat(min_width~) => Nat(min_width~)
    UInt(width) => UInt(width)
    SInt(width) => SInt(width)
    Vector(ty~, len~) => Vector(ty=ty.clone(), len~)
    Instance(sig~, params~, accessed_ports~) => Instance(sig~, params~, accessed_ports~)
    Name(path~, params~) => Name(path~, params~)
    Struct(fields) => Struct(@utils.map_values(fields, Type::clone))
    String(len~) => String(len~)
    Clock => Clock
  }
}


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
  Ternary(cond~: Expr, then~: Expr, else_~: Expr, span~: Span, ty~: Ref[Type?])
  Match(subject~: Expr, cases~: Array[(Expr, Expr)], default~: Expr?, span~: Span, ty~: Ref[Type?])
  Struct(fields~: Map[String, Expr], span~: Span, ty~: Ref[Type?])
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
  For(variable~: String, range~: ForRange, body~: Array[Stmt], span~: Span)
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
  Nat(MinWidth)
  UInt(IndexExpr)
  SInt(IndexExpr)
  Clock
  Vector(ty~: Type, len~: IndexExpr)
  Instance(sig~: ModuleSignature, params~: Map[String, ResolvedParam], accessed_ports~: AccessedPorts)
  Name(path~: Path, params~: Array[Type])
  Struct(Map[String, Type])
  String(len~: Int)
  MemoryMask(Type)
} derive(Eq)

pub(all) struct MinWidth {
  mut min_width: Int
} derive(Eq)

pub fn MinWidth::update(self: Self, width: Int) -> Unit {
  if width > self.min_width {
    self.min_width = width
  }
}

pub fn Type::bool() -> Type {
  UInt(Lit(1))
}

pub fn Type::uint(width: Int) -> Type {
  UInt(Lit(width))
}

pub fn Type::sint(width: Int) -> Type {
  SInt(Lit(width))
}

pub fn Type::empty() -> Type {
  UInt(Lit(0))
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
      UInt(Lit(BITS_PER_CHAR)) => true
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
pub fn Type::mask(self: Type, span~: Span) -> Type raise AstError {
  match self {
    UInt(_) | SInt(_) | Nat(_) | Clock | String(_) => UInt(Lit(1))
    Vector(ty~, len~) => Vector(ty=ty.mask(span~), len~)
    Struct(fields) => Struct({
      let new_fields = Map([], capacity=fields.length())

      for name, ty in fields {
        new_fields[name] = ty.mask(span~)
      }

      new_fields
    })
    MemoryMask(_) | Instance(_) | Name(_) => raise NonStorableType(ty=self, span~)
  }
}

pub(all) struct InstanceParams {
  params: Array[(String?, Param)]
  instantiated: Array[(Expr, Type, Span)]
}

pub fn InstanceParams::new(params: Array[(String?, Param)]) -> InstanceParams {
  { params, instantiated: [] }
}


pub fn[E: Error] InstanceParams::map_raw(self: Self, map_type~: (Type) -> Type raise E) -> Self raise E {
  let new_list = Array::new(capacity=self.params.length())

  for param in self.params {
    let name = param.0
    match param.1 {
      Unresolved(unresolved) => {
        new_list.push((name, Unresolved(unresolved)))
      }
      Resolved(TypeParam(ty~, span~)) => {
        let new_ty = map_type(ty)
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

/// Returns the parameter list as `(name?, ResolvedParam)` pairs, raising if any
/// parameter is still `Unresolved`. Intended for use after monomorphization,
/// where all parameters must have been resolved.
pub fn InstanceParams::unwrap_resolved(self: Self) -> Array[(String?, ResolvedParam)] raise AstError {
  let out = Array::new(capacity=self.params.length())

  for entry in self.params {
    let (name, param) = entry
    match param {
      Resolved(p) => out.push((name, p))
      Unresolved(_) => raise UnresolvedParameter(name=name.unwrap_or(""), span=Spanned::span(param))
    }
  }

  out
}

/// Like `as_map`, but ensures every value is a `ResolvedParam`, raising
/// otherwise. Intended for post-monomorphization consumers (type checker,
/// lowering) where unresolved parameters indicate an internal invariant
/// violation.
pub fn InstanceParams::as_resolved_map(self: Self, names~: Array[String]) -> Map[String, ResolvedParam] raise AstError {
  let params = self.as_map(names~)
  let out = Map([], capacity=params.length())

  for name, param in params {
    match param {
      Resolved(p) => out[name] = p
      Unresolved(_) => raise UnresolvedParameter(name~, span=Spanned::span(param))
    }
  }

  out
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

fn BinaryOp::precedence(self: BinaryOp) -> Int {
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
  Absolute        // [hi:lo]
  WidthAscending  // [base +: w]
  WidthDescending // [base -: w]
}

pub(all) enum AttributeValue {
  String(String)
  Int(Int)
  Dict(Map[String, AttributeValue])
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


pub(all) struct ConstDecl {
  path: Path
  ty: Type?
  expr: Expr
  span: Span
}

pub(all) struct TypeAliasDecl {
  name: String
  parameters: Array[StaticParam]
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


pub trait Ctor {
  ctor(Self) -> String
}

pub suberror AstError {
  ExpectedIntegerExpression(expr~: &Ctor, span~: Span)
  IndexExprNotLiteral(span~: Span)
  CannotGetWidthOfUnresolvedNamedType(span~: Span)
  InvalidFunCallArity(name~: String, expected~: Arity, actual~: Int, span~: Span)
  ExpectedStringExpression(expr~: &Ctor, span~: Span)
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
    IndexExprNotLiteral(_) => logger.write_string("Index expression must be a compile-time literal")
    CannotGetWidthOfUnresolvedNamedType(_) => logger.write_string("Cannot get width of unresolved named type")
    InvalidFunCallArity(name~, expected~, actual~, ..) => logger.write_string("Function '\{name}' expected \{expected} argument(s), but got \{actual}")
    ExpectedStringExpression(expr~, ..) => logger.write_string("Expected a string expression, got: \{expr.ctor()}")
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

  logger.write_string(Spanned::show_context(self, use_ansi_colors=false))
}

pub impl Spanned for AstError with span(self) -> Span {
  match self {
    ExpectedIntegerExpression(span~, ..) => span
    IndexExprNotLiteral(span~) => span
    CannotGetWidthOfUnresolvedNamedType(span~) => span
    InvalidFunCallArity(span~, ..) => span
    ExpectedStringExpression(span~, ..) => span
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



pub fn Expr::ty(self: Expr) -> Ref[Type?] {
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
    Struct(ty~, ..) => ty
    FunCall(ty~, ..) => ty
    String(ty~, ..) => ty
    Block(ty~, ..) => ty
    If(ty~, ..) => ty
  }
}

pub impl Ctor for Expr with ctor(self: Expr) -> String {
  match self {
    Natural(..) => "Natural"
    Identifier(..) => "Identifier"
    Unary(..) => "Unary"
    Binary(..) => "Binary"
    Indexing(..) => "Indexing"
    Slicing(..) => "Slicing"
    FieldAccess(..) => "FieldAccess"
    Instance(..) => "Instance"
    Vector(..) => "Vector"
    Spread(..) => "Spread"
    Ternary(..) => "Ternary"
    Match(..) => "Match"
    Struct(..) => "Struct"
    FunCall(..) => "FunCall"
    String(..) => "String"
    Block(..) => "Block"
    If(..) => "If"
  }
}

pub(open) trait Spanned {
  span(Self) -> Span
  show_context(Self, use_ansi_colors~ : Bool) -> String = _
}

impl Spanned with show_context(self, use_ansi_colors~: Bool) -> String {
  let span = self.span()
  let builder = StringBuilder::new()

  builder.write_string(", ")

  if use_ansi_colors {
    builder.write_string("\u001b[1;31m")
  }

  builder.write_string("\{span}")
  
  if use_ansi_colors {
    builder.write_string("\u001b[0m")
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
    Ternary(span~, ..) => span
    Match(span~, ..) => span
    Struct(span~, ..) => span
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

pub fn Expr::ctor(self: Expr) -> String {
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
    Struct(_) => "Struct"
    FunCall(_) => "FunCall"
    String(_) => "String"
    Block(_) => "Block"
    If(_) => "If"
  }
}

pub fn Expr::set_ty(self: Expr, ty: Type) -> Unit {
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
    Ternary(_) => false
    Match(_) => false
    Struct(_) => false
    FunCall(name="flip" | "rev", args=[arg], ..) => arg.is_constant_expr()
    FunCall(_) => false
    Block(body=[], last=Some(last), ..) => last.is_constant_expr()
    Block(..) => false
    If(_) => false
  }
}

pub fn Expr::contains_statements(self: Expr) -> Bool {
  match self {
    Block(body~, last~, ..) => {
      for stmt in body {
        match stmt {
          Expr(expr~, span=_) => {
            if expr.contains_statements() {
              return true
            }
          }
          _ => return true
        }
      }

      last.map_or(false, Expr::contains_statements)
    }
    If(cond~, then~, else_~, ..) => cond.contains_statements() || then.contains_statements() || else_.map_or(false, Expr::contains_statements)
    Unary(expr~, ..) => expr.contains_statements()
    Binary(lhs~, rhs~, ..) => lhs.contains_statements() || rhs.contains_statements()
    Indexing(expr~, index~, ..) => expr.contains_statements() || index.contains_statements()
    Slicing(expr~, hi~, lo~, ..) => expr.contains_statements() || hi.contains_statements() || lo.contains_statements()
    FieldAccess(expr~, ..) => expr.contains_statements()
    Instance(ports~, ..) => ports.values().any(Expr::contains_statements)
    Vector(elems~, ..) => elems.iter().any(Expr::contains_statements)
    Spread(expr~, ..) => expr.contains_statements()
    Ternary(cond~, then~, else_~, ..) => cond.contains_statements() || then.contains_statements() || else_.contains_statements()
    Match(subject~, cases~, default~, ..) => {
      if subject.contains_statements() || cases.iter().any(case => case.0.contains_statements() || case.1.contains_statements()) {
        return true
      }
      
      default.map_or(false, Expr::contains_statements)
    }
    Struct(fields~, ..) => fields.values().any(Expr::contains_statements)
    FunCall(args~, ..) => args.iter().any(Expr::contains_statements)
    Natural(_) | Identifier(_) | String(_) => false
  }
}



pub fn Type::width(self: Type, span: Span) -> Int raise AstError {
  match self {
    Nat({min_width}) => min_width
    UInt(idx) => idx.expect_lit(span)
    SInt(idx) => idx.expect_lit(span)
    Clock => 1
    Vector(ty~, len~) => ty.width(span) * len.expect_lit(span)
    Instance(sig~, params~, accessed_ports~) => {
      let mut width = 0

      for port in sig.ports {
        if accessed_ports.contains(port.name) {
          width += port.ty.substitute(params, span~).width(span)
        }
      }

      width
    }
    Name(_) => raise CannotGetWidthOfUnresolvedNamedType(span~)
    Struct(fields) => {
      let mut width = 0

      for expr in fields.values() {
        width += expr.width(span)
      }

      width
    }
    String(len~) => len * BITS_PER_CHAR // ascii encoding
    MemoryMask(ty) => ty.mask(span~).width(span)
  }
}

pub fn Type::substitute(self: Type, params_env: Map[String, ResolvedParam], span~: Span) -> Type raise AstError {
  match self {
    Nat(_) | String(_) => self
    UInt(idx) => UInt(idx.substitute(params_env))
    SInt(idx) => SInt(idx.substitute(params_env))
    Clock => Clock
    Vector(ty~, len~) => Vector(ty=ty.substitute(params_env, span~), len=len.substitute(params_env))
    MemoryMask(ty) => {
      let ty = ty.substitute(params_env, span~)
      try ty.mask(span~) catch {
        _ => MemoryMask(ty)
      }
    }
    Instance(sig~, params~, accessed_ports~) => {
      let new_params = Map([], capacity=params.length()) 

      for name, value in params {
        new_params[name] = match params_env.get(name) {
          Some(new_value) => new_value
          None => value
        }
      }

      Instance(sig~, params=new_params, accessed_ports~)
    }
    Name(path~, params~) => {
      let new_params = Array::new(capacity=params.length())

      for ty in params {
        new_params.push(ty.substitute(params_env, span~))
      }

      match path.packages {
        [] => match params_env.get(path.elem) {
          Some(TypeParam(ty~, ..)) => ty.substitute(params_env, span~)
          None | Some(NatParam(_)) => Name(path~, params=new_params)
        }
        _ => Name(path~, params=new_params)
      }
    }
    Struct(fields) => Struct({
      let new_fields = Map([], capacity=fields.length())

      for name, ty in fields {
        new_fields[name] = ty.substitute(params_env, span~)
      }

      new_fields
    })
  }
}


pub fn Type::is_numerical(self: Type) -> Bool {
  match self {
    Nat(_) | UInt(_) | SInt(_) => true
    _ => false
  }
}

pub fn Type::has_zero_width(self: Type) -> Bool {
  match self {
    Nat(_) => false
    UInt(idx) | SInt(idx) => idx == Lit(0)
    Clock => false
    Vector(ty~, len~) => match len {
      Lit(0) => true
      _ => ty.has_zero_width()
    }
    Instance(sig~, ..) => sig.ports.is_empty()
    Name(_) => false
    Struct(fields) => fields.values().all(Type::has_zero_width)
    String(len~) => len == 0
    MemoryMask(ty) => ty.has_zero_width()
  }
}

pub fn Expr::nat(n: Int, width~: Int? = None, base~: Int = 10, span~: Span) -> Expr {
  Expr::bignat(BigInt::from_int(n), width~, base~, span~)
}

pub fn Expr::bignat(n: BigInt, width~: Int? = None, base~: Int = 10, span~: Span) -> Expr {
  let ty = match width {
    Some(width) => if n > 0 { Type::uint(width) } else { Type::uint(width) }
    None => Nat({min_width: @utils.significant_bits(n)})
  }

  Natural(value=n, width~, base~, span~, ty={ val: Some(ty) })
}

pub fn InstanceParams::as_map(self: InstanceParams, names~: Array[String]) -> Map[String, Param] raise AstError {
  let map = Map([], capacity=names.length())

  fn checked_set(name: String, param: Param) -> Unit raise AstError {
    if !names.contains(name) {
      raise UnknownModuleParameter(name~, span=Spanned::span(param))
    }

    if map.contains(name) {
      raise ConflictingInstanceParameterValue(name~, span=Spanned::span(param))
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
        checked_set(name, param)
      }
      _ => {
        ordered = true
        if idx >= names.length() {
          raise UnknownModuleParameter(name=idx.to_string(), span=Spanned::span(param))
        }

        checked_set(names[idx], param)
      }
    }

    if ordered && named {
      raise CannotMixNamedAndOrderedModuleParameters(span=Spanned::span(param))
    }
  }
  map
}

pub fn Type::clone(self: Type) -> Type {
  match self {
    Nat({min_width}) => Nat({min_width,})
    UInt(width) => UInt(width)
    SInt(width) => SInt(width)
    Vector(ty~, len~) => Vector(ty=ty.clone(), len~)
    Instance(sig~, params~, accessed_ports~) => Instance(sig~, params~, accessed_ports~)
    Name(path~, params~) => Name(path~, params~)
    Struct(fields) => Struct(@utils.map_values(fields, Type::clone))
    String(len~) => String(len~)
    Clock => Clock
    MemoryMask(ty) => MemoryMask(ty.clone())
  }
}
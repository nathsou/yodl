
// Synthesisable subset of the AST, produced by the simplifier and consumed by the elaborator.
//
// Invariants guaranteed by construction (enforced by the simplifier):
//   - No Ternary, If (all rewritten to Match)
//   - Slicing is always Absolute — the `kind` field is absent
//   - BinaryOp::Nand does not appear (rewritten to Not(And(...)))
//   - CoreStmt has no For, Scope, or Const
//   - CoreDecl has no Package, Import, TypeAlias, or parameterised Module
//   - Concat is expressed via FunCall(name="cat", ..) and routed through lower

/// Concrete, immutable types accepted by Core and lowering. Surface names,
/// sugar, symbolic sizes, and literal inference state are unrepresentable.
pub(all) enum CoreType {
  UInt(Int)
  SInt(Int)
  Clock
  Vector(ty~: CoreType, len~: Int)
  Instance(sig~: CoreInstanceSignature, params~: Map[String, CoreStaticArg], ids~: Array[InstanceId])
  Struct(Map[String, CoreType])
  Unit
}

/// Static arguments after crossing the Core boundary. Type arguments contain
/// only Core types and Nat arguments contain evaluated integers.
pub(all) enum CoreStaticArg {
  CoreNat(value~: Int, span~: Span)
  CoreTy(ty~: CoreType, span~: Span)
}

/// Concrete view of an instance signature. Generic surface port types are
/// substituted and frozen before this signature enters Core.
pub(all) struct CoreInstanceSignature {
  path: Path
  params: Array[ModuleParameter]
  attributes: Map[String, Attribute]
  ports: Array[CorePort]
  span: Span
}

pub impl Eq for CoreType with equal(self, other) {
  match (self, other) {
    (UInt(a), UInt(b)) | (SInt(a), SInt(b)) => a == b
    (Clock, Clock) | (Unit, Unit) => true
    (Vector(ty=a, len=al), Vector(ty=b, len=bl)) => a == b && al == bl
    (Instance(sig=a, params=ap, ..), Instance(sig=b, params=bp, ..)) => a.path == b.path && a.span.file == b.span.file && ap == bp
    (Struct(a), Struct(b)) => a == b
    _ => false
  }
}

pub impl Eq for CoreStaticArg with equal(self, other) {
  match (self, other) {
    (CoreNat(value=a, ..), CoreNat(value=b, ..)) => a == b
    (CoreTy(ty=a, ..), CoreTy(ty=b, ..)) => a == b
    _ => false
  }
}

pub impl Show for CoreStaticArg with output(self, logger) {
  match self {
    CoreNat(value~, ..) => logger.write_object(value)
    CoreTy(ty~, ..) => logger.write_object(ty)
  }
}

pub impl Show for CoreType with output(self, logger) {
  match self {
    UInt(width) => logger.write_string("u\{width}")
    SInt(width) => logger.write_string("s\{width}")
    Clock => logger.write_string("clock")
    Vector(ty~, len~) => logger.write_string("[\{len}]\{ty}")
    Instance(sig~, params~, ..) => {
      logger.write_object(sig.path)
      if !params.is_empty() {
        logger.write_iter(params.values(), prefix="[", sep=", ", suffix="]")
      }
    }
    Struct(fields) => {
      logger.write_char('(')
      let mut first = true
      for name, ty in fields {
        if !first { logger.write_string(", ") }
        logger.write_string(name)
        logger.write_string(": ")
        logger.write_object(ty)
        first = false
      }
      logger.write_char(')')
    }
    Unit => logger.write_string("unit")
  }
}

pub fn CoreType::from_type(ty: Type, span~: Span) -> CoreType raise AstError {
  match ty {
    Nat({ min_width }) if min_width >= 0 => UInt(min_width)
    Type::UInt(Lit(width)) if width >= 0 => UInt(width)
    Type::SInt(Lit(width)) if width >= 0 => SInt(width)
    Type::Clock => Clock
    Type::Vector(ty~, len=Lit(len)) if len >= 0 => Vector(ty=CoreType::from_type(ty, span~), len~)
    Type::Instance(sig~, params~, ids~) => {
      let core_params: Map[String, CoreStaticArg] = Map([], capacity=params.length())
      for name, param in params {
        core_params[name] = match param {
          TypeParam(ty~, span=param_span) => {
            let core_ty = CoreType::from_type(ty, span=param_span)
            CoreTy(ty=core_ty, span=param_span)
          }
          NatParam(value=ConstValue::Natural(value~, ..), span=param_span) =>
            CoreNat(value=value.to_int(), span=param_span)
          NatParam(span=param_span, ..) => raise ExpectedIntParameter(span=param_span)
        }
      }
      let core_sig = CoreInstanceSignature::from_signature(sig, params, span)
      Instance(sig=core_sig, params=core_params, ids=Array::copy(ids))
    }
    Type::Struct(fields) => {
      let core_fields = Map([], capacity=fields.length())
      for name, field_ty in fields { core_fields[name] = CoreType::from_type(field_ty, span~) }
      Struct(core_fields)
    }
    Type::Unit => Unit
    Nat({ min_width }) => raise InvalidCoreDimension(kind="literal width", value=min_width, span~)
    Type::UInt(Lit(width)) | Type::SInt(Lit(width)) =>
      raise InvalidCoreDimension(kind="integer width", value=width, span~)
    Type::Vector(len=Lit(len), ..) =>
      raise InvalidCoreDimension(kind="vector length", value=len, span~)
    _ => raise InvalidCoreType(ty~, span~)
  }
}

pub fn CoreType::width(self: CoreType) -> Int {
  match self {
    UInt(width) | SInt(width) => width
    Clock => 1
    Vector(ty~, len~) => ty.width() * len
    Struct(fields) => @utils.sum(fields.values().map(CoreType::width))
    Instance(_) | Unit => 0
  }
}

pub fn CoreType::to_type(self: CoreType) -> Type {
  match self {
    UInt(width) => Type::UInt(Lit(width))
    SInt(width) => Type::SInt(Lit(width))
    Clock => Type::Clock
    Vector(ty~, len~) => Type::Vector(ty=ty.to_type(), len=Lit(len))
    Instance(sig~, params~, ids~) => {
      let surface_params: Map[String, StaticArg] = Map([], capacity=params.length())
      for name, param in params {
        surface_params[name] = param.to_static_arg()
      }
      Type::Instance(sig=sig.to_signature(), params=surface_params, ids=Array::copy(ids))
    }
    Struct(fields) => Type::Struct(@utils.map_values(fields, CoreType::to_type))
    Unit => Type::Unit
  }
}

pub(all) enum CoreExpr {
  Natural(value~: BigInt, width~: Int?, base~: Int, span~: Span, ty~: Ref[CoreType?])
  Identifier(path~: Path, span~: Span, ty~: Ref[CoreType?])
  Unary(op~: UnaryOp, expr~: CoreExpr, span~: Span, ty~: Ref[CoreType?])
  Binary(op~: BinaryOp, lhs~: CoreExpr, rhs~: CoreExpr, output_width~: Ref[Int?], span~: Span, ty~: Ref[CoreType?])
  Indexing(expr~: CoreExpr, index~: CoreExpr, span~: Span, ty~: Ref[CoreType?])
  Slicing(expr~: CoreExpr, hi~: CoreExpr, lo~: CoreExpr, span~: Span, ty~: Ref[CoreType?])
  FieldAccess(expr~: CoreExpr, field~: String, span~: Span, ty~: Ref[CoreType?])
  Instance(path~: Path, ports~: Map[String, CoreExpr], span~: Span, ty~: Ref[CoreType?])
  Vector(elems~: Array[CoreExpr], span~: Span, ty~: Ref[CoreType?])
  Spread(expr~: CoreExpr, span~: Span, ty~: Ref[CoreType?])
  Match(subject~: CoreExpr, cases~: Array[(CoreExpr, CoreExpr)], default~: CoreExpr?, span~: Span, ty~: Ref[CoreType?])
  Struct(fields~: Map[String, CoreExpr], span~: Span, ty~: Ref[CoreType?])
  FunCall(name~: String, args~: Array[CoreExpr], span~: Span, ty~: Ref[CoreType?])
  String(value~: String, span~: Span, ty~: Ref[CoreType?])
  Block(body~: Array[CoreStmt], last~: CoreExpr?, span~: Span, ty~: Ref[CoreType?])
}

pub(all) enum CoreStmt {
  Expr(expr~: CoreExpr, span~: Span)
  Let(name~: String, ty~: Ref[CoreType?], expr~: CoreExpr?, span~: Span)
  Assign(lhs~: CoreExpr, rhs~: CoreExpr, span~: Span)
}

pub(all) struct CorePort {
  name: String
  ty: CoreType
  dir: PortDir
  span: Span
  optional: Bool
  attributes: Map[String, Attribute]
}

pub fn CorePort::from_port(port: Port) -> CorePort raise AstError {
  { name: port.name, ty: CoreType::from_type(port.ty, span=port.span), dir: port.dir, span: port.span, optional: port.optional, attributes: port.attributes }
}

pub fn CorePort::to_port(self: CorePort) -> Port {
  { name: self.name, ty: self.ty.to_type(), dir: self.dir, span: self.span, optional: self.optional, attributes: self.attributes }
}

pub fn CoreStaticArg::to_static_arg(self: CoreStaticArg) -> StaticArg {
  match self {
    CoreNat(value~, span~) => NatParam(
      value=ConstValue::Natural(
        value=BigInt::from_int(value),
        width=None,
        base=10,
        span~,
      ),
      span~,
    )
    CoreTy(ty~, span~) => TypeParam(ty=ty.to_type(), span~)
  }
}

pub fn CoreStaticArg::as_int(self: CoreStaticArg) -> Int raise AstError {
  match self {
    CoreNat(value~, ..) => value
    CoreTy(span~, ..) => raise ExpectedIntParameter(span~)
  }
}

pub fn CoreStaticArg::as_type(self: CoreStaticArg) -> CoreType raise AstError {
  match self {
    CoreTy(ty~, ..) => ty
    CoreNat(span~, ..) => raise ExpectedTypeParameter(span~)
  }
}

pub fn CoreInstanceSignature::from_signature(
  sig: ModuleSignature,
  params: Map[String, StaticArg],
  span: Span,
) -> CoreInstanceSignature raise AstError {
  let ports = Array::new(capacity=sig.ports.length())
  for port in sig.ports {
    let resolved_ty = port.ty.substitute(params, span~)
    let core_port: CorePort = {
      name: port.name,
      ty: CoreType::from_type(resolved_ty, span=port.span),
      dir: port.dir,
      span: port.span,
      optional: port.optional,
      attributes: port.attributes,
    }
    ports.push(core_port)
  }
  { path: sig.path, params: sig.params, attributes: sig.attributes, ports, span: sig.span }
}

pub fn CoreInstanceSignature::get_port(self: CoreInstanceSignature, name: String) -> CorePort? {
  for port in self.ports {
    if port.name == name {
      return Some(port)
    }
  }
  None
}

pub fn CoreInstanceSignature::to_signature(self: CoreInstanceSignature) -> ModuleSignature {
  {
    path: self.path,
    params: self.params,
    attributes: self.attributes,
    ports: self.ports.map(CorePort::to_port),
    span: self.span,
  }
}

pub(all) struct CoreModuleDecl {
  path: Path
  attributes: Map[String, Attribute]
  ports: Array[CorePort]
  body: Array[CoreStmt]
  span: Span
}

pub(all) enum CoreDecl {
  Module(CoreModuleDecl)
  ModuleDeclaration(ModuleSignature)
}

pub fn CoreExpr::ty(self: CoreExpr) -> Ref[CoreType?] {
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
    Match(ty~, ..) => ty
    Struct(ty~, ..) => ty
    FunCall(ty~, ..) => ty
    String(ty~, ..) => ty
    Block(ty~, ..) => ty
  }
}

pub fn CoreExpr::set_ty(self: CoreExpr, ty: CoreType) -> Unit {
  self.ty().val = Some(ty)
}

pub impl Ctor for CoreExpr with ctor(self: CoreExpr) -> String {
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
    Match(..) => "Match"
    Struct(..) => "Struct"
    FunCall(..) => "FunCall"
    String(..) => "String"
    Block(..) => "Block"
  }
}

pub impl Spanned for CoreExpr with span(self: CoreExpr) -> Span {
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
    Match(span~, ..) => span
    Struct(span~, ..) => span
    FunCall(span~, ..) => span
    String(span~, ..) => span
    Block(span~, ..) => span
  }
}

pub impl Spanned for CoreStmt with span(self: CoreStmt) -> Span {
  match self {
    Expr(span~, ..) => span
    Let(span~, ..) => span
    Assign(span~, ..) => span
  }
}

pub fn CoreExpr::contains_statements(self: CoreExpr) -> Bool {
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

      last.map_or(false, CoreExpr::contains_statements)
    }
    Unary(expr~, ..) => expr.contains_statements()
    Binary(lhs~, rhs~, ..) => lhs.contains_statements() || rhs.contains_statements()
    Indexing(expr~, index~, ..) => expr.contains_statements() || index.contains_statements()
    Slicing(expr~, hi~, lo~, ..) => expr.contains_statements() || hi.contains_statements() || lo.contains_statements()
    FieldAccess(expr~, ..) => expr.contains_statements()
    Instance(ports~, ..) => ports.values().any(CoreExpr::contains_statements)
    Vector(elems~, ..) => elems.iter().any(CoreExpr::contains_statements)
    Spread(expr~, ..) => expr.contains_statements()
    Match(subject~, cases~, default~, ..) => {
      if subject.contains_statements() || cases.iter().any(case => case.0.contains_statements() || case.1.contains_statements()) {
        return true
      }

      default.map_or(false, CoreExpr::contains_statements)
    }
    Struct(fields~, ..) => fields.values().any(CoreExpr::contains_statements)
    FunCall(args~, ..) => args.iter().any(CoreExpr::contains_statements)
    Natural(_) | Identifier(_) | String(_) => false
  }
}

pub fn CoreExpr::as_int(self: CoreExpr) -> Int raise {
  match self {
    Natural(value~, ..) => value.to_int()
    _ => raise ExpectedIntegerExpression(expr=self, span=Spanned::span(self))
  }
}

pub fn CoreExpr::as_string(self: CoreExpr) -> String raise {
  match self {
    String(value=str, ..) => str
    _ => raise ExpectedStringExpression(expr=self, span=Spanned::span(self))
  }
}

pub fn CoreExpr::nat(n: Int, width~: Int? = None, base~: Int = 10, span~: Span) -> CoreExpr {
  let ty = match width {
    Some(width) => CoreType::UInt(width)
    None => CoreType::UInt(@utils.significant_bits(BigInt::from_int(n), is_signed=false))
  }

  Natural(value=BigInt::from_int(n), width~, base~, span~, ty={ val: Some(ty) })
}

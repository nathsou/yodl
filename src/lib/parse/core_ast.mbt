
// Synthesisable subset of the AST, produced by the simplifier and consumed by the elaborator.
//
// Invariants guaranteed by construction (enforced by the simplifier):
//   - No Ternary, If (all rewritten to Match)
//   - Slicing is always Absolute — the `kind` field is absent
//   - BinaryOp::Nand does not appear (rewritten to Not(And(...)))
//   - CoreStmt has no For, Scope, or Const
//   - CoreDecl has no Package, Import, TypeAlias, or parameterised Module
//   - Concat is expressed via FunCall(name="cat", ..) and routed through lower

pub(all) enum CoreExpr {
  Natural(value~: BigInt, width~: Int?, base~: Int, span~: Span, ty~: Ref[Type?])
  Identifier(path~: Path, span~: Span, ty~: Ref[Type?])
  Unary(op~: UnaryOp, expr~: CoreExpr, span~: Span, ty~: Ref[Type?])
  Binary(op~: BinaryOp, lhs~: CoreExpr, rhs~: CoreExpr, output_width~: Ref[Int?], span~: Span, ty~: Ref[Type?])
  Indexing(expr~: CoreExpr, index~: CoreExpr, span~: Span, ty~: Ref[Type?])
  Slicing(expr~: CoreExpr, hi~: CoreExpr, lo~: CoreExpr, span~: Span, ty~: Ref[Type?])
  FieldAccess(expr~: CoreExpr, field~: String, span~: Span, ty~: Ref[Type?])
  Instance(path~: Path, params~: InstanceParams, ports~: Map[String, CoreExpr], span~: Span, ty~: Ref[Type?])
  Vector(elems~: Array[CoreExpr], span~: Span, ty~: Ref[Type?])
  Spread(expr~: CoreExpr, span~: Span, ty~: Ref[Type?])
  Match(subject~: CoreExpr, cases~: Array[(CoreExpr, CoreExpr)], default~: CoreExpr?, span~: Span, ty~: Ref[Type?])
  Struct(fields~: Map[String, CoreExpr], span~: Span, ty~: Ref[Type?])
  FunCall(name~: String, args~: Array[CoreExpr], span~: Span, ty~: Ref[Type?])
  String(value~: String, span~: Span, ty~: Ref[Type?])
  Block(body~: Array[CoreStmt], last~: CoreExpr?, span~: Span, ty~: Ref[Type?])
}

pub(all) enum CoreStmt {
  Expr(expr~: CoreExpr, span~: Span)
  Let(name~: String, ty~: Ref[Type?], expr~: CoreExpr?, span~: Span)
  Assign(lhs~: CoreExpr, rhs~: CoreExpr, span~: Span)
}

pub(all) struct CoreModuleDecl {
  path: Path
  attributes: Map[String, Attribute]
  ports: Array[Port]
  body: Array[CoreStmt]
  span: Span
}

pub(all) enum CoreDecl {
  Module(CoreModuleDecl)
  ModuleDeclaration(ModuleSignature)
}

pub fn CoreExpr::ty(self: CoreExpr) -> Ref[Type?] {
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

pub fn CoreExpr::set_ty(self: CoreExpr, ty: Type) -> Unit {
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
    Some(width) => Type::uint(width)
    None => Nat({min_width: @utils.significant_bits(BigInt::from_int(n), is_signed=false)})
  }

  Natural(value=BigInt::from_int(n), width~, base~, span~, ty={ val: Some(ty) })
}

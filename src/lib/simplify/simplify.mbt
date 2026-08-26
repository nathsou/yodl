
pub struct Simplifier {
  name_counts: Map[String, Int]
}

struct UniqueName {
  name: String
  id: Int
}

impl Show for UniqueName with output(self, logger) {
  if self.id > 0 {
    logger.write_string(self.name)
    logger.write_char('$')
    logger.write_string(self.id.to_string())
  } else {
    logger.write_string(self.name)
  }
}

pub enum SimplifierEnvEntry {
  Name(UniqueName)
  Const(@parse.CoreExpr)
}

type SimplifierEnv = Scope[@parse.Path, SimplifierEnvEntry]

pub fn Simplifier::new() -> Simplifier {
  { name_counts: {} }
}

fn freeze_ty(ty: Ref[@parse.Type?], span: @parse.Span) -> Ref[@parse.CoreType?] raise {
  { val: match ty.val {
    Some(ty) => Some(@parse.CoreType::from_type(ty, span~))
    None => raise Failure::Failure("Expression is untyped at Core construction: \{span}")
  } }
}

fn explicit_coercion(
  expr: @parse.CoreExpr,
  expected: @parse.CoreType,
) -> @parse.CoreExpr raise {
  let actual = expr.ty().val.unwrap_or_error(
    Failure::Failure("Expression is untyped while elaborating a coercion: \{expr.span()}"),
  )
  if actual == expected {
    return expr
  }

  let ty = @ref.new(Some(expected))
  match (actual, expected) {
    (@parse.CoreType::UInt(actual_width), @parse.CoreType::UInt(expected_width)) =>
      if expected_width < actual_width {
        @parse.CoreExpr::Truncate(expr~, span=expr.span(), ty~)
      } else {
        @parse.CoreExpr::ZeroExtend(expr~, span=expr.span(), ty~)
      }
    (@parse.CoreType::SInt(actual_width), @parse.CoreType::SInt(expected_width)) =>
      if expected_width < actual_width {
        @parse.CoreExpr::Truncate(expr~, span=expr.span(), ty~)
      } else {
        @parse.CoreExpr::SignExtend(expr~, span=expr.span(), ty~)
      }
    _ => raise Failure::Failure(
      "Invalid coercion from '\{actual}' to '\{expected}' after type checking",
    )
  }
}

fn Simplifier::simplify_checked_expr(
  self: Self,
  expr: @parse.Expr,
  expected: @parse.CoreType,
  env~ : SimplifierEnv,
) -> @parse.CoreExpr raise {
  explicit_coercion(self.simplify_expr(expr, env~), expected)
}

pub fn Simplifier::declare_unique(self: Self, name: String) -> UniqueName {
  let count = match self.name_counts.get(name) {
    Some(count) => count
    None => 0
  }

  self.name_counts[name] = count + 1

  { name, id: count }
}

pub suberror SimplifierError {
  AssertionAlwaysFails(span~: @parse.Span)
}

pub impl Show for SimplifierError with output(self, logger) {
  match self {
    AssertionAlwaysFails(span=_) => {
      logger.write_string("Assertion always fails")
    }
  }

  logger.write_string(@parse.Spanned::show_context(self, use_ansi_colors=false))
}

pub impl @parse.Spanned for SimplifierError with span(self) -> @parse.Span {
  match self {
    AssertionAlwaysFails(span~) => span
  }
}

// Simplify a surface expression directly into a CoreExpr.
//
// Rewrites performed:
// - Resolve identifiers to unique names / inline constants
// - Binary Nand -> Not(And(...))
// - Ternary -> Match
// - If -> Match
// - Width-select Slicing -> Absolute Slicing
// - Port accesses on Match expressions are pushed inside the cases
// - Static assertions are checked; always-true ones produce an empty struct
pub fn Simplifier::simplify_expr(
  self: Self,
  expr: @parse.Expr,
  env~ : SimplifierEnv,
) -> @parse.CoreExpr raise {
  let simp = fn(e) raise { self.simplify_expr(e, env~) }

  match expr {
    Natural(value~, width~, base~, span~, ty~) =>
      Natural(value~, width~, base~, span~, ty=freeze_ty(ty, span))

    Identifier(path~, span~, ty~) =>
      match env.resolve(path) {
        Some(Const(core_expr)) => core_expr
        Some(Name(unique_name)) =>
          Identifier(
            path=@parse.Path::new(path.packages, Show::to_string(unique_name)),
            span~,
            ty=freeze_ty(ty, span),
          )
        None => Identifier(path~, span~, ty=freeze_ty(ty, span))
      }

    String(value~, span~, ty~) => String(value~, span~, ty=freeze_ty(ty, span))

    Unary(op~, expr~, span~, ty~) =>
      Unary(op~, expr=simp(expr), span~, ty=freeze_ty(ty, span))

    Binary(op=Nand, lhs~, rhs~, span~, ty~) =>
      Unary(
        op=Not,
        expr=Binary(
          op=And,
          lhs=simp(lhs),
          rhs=simp(rhs),
          span~,
          ty=freeze_ty(ty, span),
        ),
        span~,
        ty=freeze_ty(ty, span),
      )

    Binary(op~, lhs~, rhs~, span~, ty~) =>
      Binary(
        op~,
        lhs=simp(lhs),
        rhs=simp(rhs),
        span~,
        ty=freeze_ty(ty, span),
      )

    Indexing(expr~, index~, span~, ty~) =>
      Indexing(expr=simp(expr), index=simp(index), span~, ty=freeze_ty(ty, span))

    Slicing(expr~, hi=msb, lo=lsb, kind=Absolute, span~, ty~) =>
      Slicing(
        expr=simp(expr),
        hi=simp(msb),
        lo=simp(lsb),
        span~,
        ty=freeze_ty(ty, span),
      )

    Slicing(expr~, hi=msb, lo=width, kind=WidthDescending, span~, ty~) => {
      // [base -: w] selects bits [base : base - w + 1]
      let msb_simplified = simp(msb)
      let width_simplified = simp(width)
      let lsb = msb_simplified.as_int() - width_simplified.as_int() + 1
      Slicing(
        expr=simp(expr),
        hi=msb_simplified,
        lo=@parse.CoreExpr::nat(lsb, span=width.span()),
        span~,
        ty=freeze_ty(ty, span),
      )
    }

    Slicing(expr~, hi=base, lo=width, kind=WidthAscending, span~, ty~) => {
      // [base +: w] selects bits [base + w - 1 : base]
      let base_simplified = simp(base)
      let width_simplified = simp(width)
      let base_val = base_simplified.as_int()
      let width_val = width_simplified.as_int()
      let new_msb = base_val + width_val - 1
      Slicing(
        expr=simp(expr),
        hi=@parse.CoreExpr::nat(new_msb, span=base.span()),
        lo=@parse.CoreExpr::nat(base_val, span=base.span()),
        span~,
        ty=freeze_ty(ty, span),
      )
    }

    FieldAccess(expr~, field=port, span=port_acc_span, ty=port_acc_ty) => {
      let simplified_expr = simp(expr)
      let core_port_ty = freeze_ty(port_acc_ty, port_acc_span)
      // Push field access inside match cases
      match simplified_expr {
        Match(subject~, cases~, default~, span~, ty=_) => {
          let new_cases = cases.map(case => {
            let (pat, e) = case
            (pat, @parse.CoreExpr::FieldAccess(expr=e, field=port, span=port_acc_span, ty=core_port_ty))
          })
          let new_default = default.map(e => {
            @parse.CoreExpr::FieldAccess(expr=e, field=port, span=port_acc_span, ty=core_port_ty)
          })
          Match(subject~, cases=new_cases, default=new_default, span~, ty=core_port_ty)
        }
        _ => FieldAccess(expr=simplified_expr, field=port, span=port_acc_span, ty=core_port_ty)
      }
    }

    Instance(path~, params=_, ports~, span~, ty~) => {
      let core_ty = freeze_ty(ty, span)
      let core_sig = match core_ty.val {
        Some(@parse.CoreType::Instance(sig~, ..)) => sig
        _ => raise Failure::Failure("Instance expression has a non-instance type")
      }
      let core_ports = Map([], capacity=ports.length())
      for port, e in ports {
        let expected = core_sig.get_port(port).unwrap().ty
        core_ports[port] = self.simplify_checked_expr(e, expected, env~)
      }
      Instance(path~, ports=core_ports, span~, ty=core_ty)
    }

    Vector(elems~, span~, ty~) => {
      let core_ty = freeze_ty(ty, span)
      let elem_ty = match core_ty.val {
        Some(@parse.CoreType::Vector(ty~, ..)) => ty
        _ => raise Failure::Failure("Vector expression has a non-vector type")
      }
      Vector(
        elems=elems.map(elem => match elem {
          Spread(_) => simp(elem)
          _ => self.simplify_checked_expr(elem, elem_ty, env~)
        }),
        span~,
        ty=core_ty,
      )
    }

    Spread(expr~, span~, ty~) =>
      Spread(expr=simp(expr), span~, ty=freeze_ty(ty, span))

    Match(subject~, cases~, default~, span~, ty~) => {
      let core_ty = freeze_ty(ty, span)
      let expected = core_ty.val.unwrap()
      Match(
        subject=simp(subject),
        cases=cases.map(case => {
          let (pat, e) = case
          (simp(pat), self.simplify_checked_expr(e, expected, env~))
        }),
        default=default.map(e => self.simplify_checked_expr(e, expected, env~)),
        span~,
        ty=core_ty,
      )
    }

    Struct(fields~, span~, ty~) => {
      let core_fields = Map([], capacity=fields.length())
      let core_ty = freeze_ty(ty, span)
      let expected_fields = match core_ty.val {
        Some(@parse.CoreType::Struct(fields)) => fields
        _ => raise Failure::Failure("Struct expression has a non-struct type")
      }

      // Expand spreads first so later explicit fields override.
      for name, e in fields {
        if name.has_prefix("..") {
          // The spread expression must have a Struct type at this point
          let spread_base = match e {
            Spread(expr~, ..) => expr
            _ => raise Failure::Failure("Internal: spread field is not a Spread expression")
          }
          let simp_base = simp(spread_base)
          match simp_base.ty().val {
            Some(@parse.CoreType::Struct(spread_tys)) => {
              for spread_name, spread_ty in spread_tys {
                core_fields[spread_name] = @parse.CoreExpr::FieldAccess(
                  expr=simp_base,
                  field=spread_name,
                  span=spread_base.span(),
                  ty={ val: Some(spread_ty) },
                )
              }
            }
            _ => raise Failure::Failure("Spread inside a record must have a record type")
          }
        }
      }

      for name, e in fields {
        if !name.has_prefix("..") {
          core_fields[name] = self.simplify_checked_expr(e, expected_fields.get(name).unwrap(), env~)
        }
      }

      Struct(fields=core_fields, span~, ty=core_ty)
    }

    FunCall(name="assert", args=[pred, ..rest], span~, ty~) => {
      let core_pred = self.simplify_checked_expr(pred, @parse.CoreType::UInt(1), env~)
      try core_pred.as_int() catch {
        _ => FunCall(name="assert", args=[core_pred, ..rest.map(simp)], span~, ty=freeze_ty(ty, span))
      } noraise {
        0 => raise AssertionAlwaysFails(span~)
        1 => Struct(fields=Map([]), span~, ty=freeze_ty(ty, span))
        _ => FunCall(name="assert", args=[core_pred, ..rest.map(simp)], span~, ty=freeze_ty(ty, span))
      }
    }

    // fill!(n, x) expands into a Vector of n elements at simplify-time so the
    // elaborator calls lower_expr on each element independently. This is
    // critical for instance-typed elements: lowering the same Instance N
    // times produces N distinct hardware instances, whereas filling the
    // Vector with N references to a single lowered Value would alias the
    // hardware (one instance shared by all positions).
    FunCall(name="fill", args=[count, elem], span~, ty~) => {
      let count_simplified = simp(count)
      let n = count_simplified.as_int()
      let elems = Array::new(capacity=n)

      for _ in 0..<n {
        elems.push(simp(elem))
      }

      Vector(elems~, span~, ty=freeze_ty(ty, span))
    }

    FunCall(name="clock", args=[arg], span~, ty~) =>
      FunCall(
        name="clock",
        args=[self.simplify_checked_expr(arg, @parse.CoreType::UInt(1), env~)],
        span~,
        ty=freeze_ty(ty, span),
      )

    FunCall(name~, args~, span~, ty~) =>
      FunCall(name~, args=args.map(simp), span~, ty=freeze_ty(ty, span))

    Block(body~, last~, span~, ty~) => {
      let core_ty = freeze_ty(ty, span)
      let expected = core_ty.val.unwrap()
      let core_body = []
      for stmt in body {
        core_body.push_iter(self.simplify_stmt(stmt, env~))
      }
      Block(
        body=core_body,
        last=last.map(expr => self.simplify_checked_expr(expr, expected, env~)),
        span~,
        ty=core_ty,
      )
    }

    Ternary(cond~, then~, else_~, span~, ty~) => {
      // Rewrite: cond ? then : else  ->  match cond { 0 => else, 1 => then }
      let core_ty = freeze_ty(ty, span)
      let expected = core_ty.val.unwrap()
      Match(
        subject=self.simplify_checked_expr(cond, @parse.CoreType::UInt(1), env~),
        cases=[
          (@parse.CoreExpr::nat(0, width=Some(1), span~), self.simplify_checked_expr(else_, expected, env~)),
          (@parse.CoreExpr::nat(1, width=Some(1), span~), self.simplify_checked_expr(then, expected, env~)),
        ],
        default=None,
        span~,
        ty=core_ty,
      )
    }

    If(cond~, then~, else_~, span~, ty~) => {
      // Rewrite: if cond { then } else { else }  ->  match cond { 1 => then, 0 => else }
      let core_ty = freeze_ty(ty, span)
      let expected = core_ty.val.unwrap()
      Match(
        subject=self.simplify_checked_expr(cond, @parse.CoreType::UInt(1), env~),
        cases={
          let cases = [(@parse.CoreExpr::nat(1, width=Some(1), span~), self.simplify_checked_expr(then, expected, env~))]
          match else_ {
            Some(else_) => cases.push((@parse.CoreExpr::nat(0, width=Some(1), span~), self.simplify_checked_expr(else_, expected, env~)))
            None => ()
          }
          cases
        },
        default=None,
        span~,
        ty=core_ty,
      )
    }
  }
}

pub fn Simplifier::simplify_stmt(
  self: Self,
  stmt: @parse.Stmt,
  env~ : SimplifierEnv,
) -> Iter[@parse.CoreStmt] raise {
  match stmt {
    Expr(expr~, span~) =>
      Iter::singleton(@parse.CoreStmt::Expr(
        expr=self.simplify_expr(expr, env~),
        span~,
      ))

    Let(name~, ty~, expr~, span~) => {
      let core_ty = freeze_ty(ty, span)
      let simplified_expr = match expr {
        Some(e) => Some(self.simplify_checked_expr(e, core_ty.val.unwrap(), env~))
        None => None
      }
      let unique_name = self.declare_unique(name)
      env.declare_shadowing(@parse.Path::new([], name), Name(unique_name))
      Iter::singleton(@parse.CoreStmt::Let(
        name=Show::to_string(unique_name),
        ty=core_ty,
        expr=simplified_expr,
        span~,
      ))
    }

    Assign(lhs~, rhs~, span~) => {
      let core_lhs = self.simplify_expr(lhs, env~)
      let expected = core_lhs.ty().val.unwrap()
      Iter::singleton(@parse.CoreStmt::Assign(
        lhs=core_lhs,
        rhs=self.simplify_checked_expr(rhs, expected, env~),
        span~,
      ))
    }

    For(_) => raise Failure::Failure("For stmt after monomorphization")

    Scope(body~, ..) => {
      let scope_env = env.child()
      let stmts = []
      for s in body {
        stmts.push_iter(self.simplify_stmt(s, env=scope_env))
      }
      stmts.iter()
    }

    Const(decl~, span=_) => {
      env.declare_(decl.path, Const(self.simplify_expr(decl.expr, env~)))
      Iter::empty()
    }
  }
}

fn Simplifier::simplify_decl(
  self: Self,
  decl: @parse.Decl,
  env~ : SimplifierEnv,
) -> @parse.CoreDecl? raise {
  match decl {
    Module({ path, attributes, ports, body, span, .. }) => {
      let simplified_body = []
      let mod_env = env.child()

      for port in ports {
        let _ = self.declare_unique(port.name)
      }

      for stmt in body {
        for core_stmt in self.simplify_stmt(stmt, env=mod_env) {
          // Discard empty-struct expressions (produced by always-true assertions)
          match core_stmt {
            @parse.CoreStmt::Expr(expr=@parse.CoreExpr::Struct(fields=fields, ..), ..) =>
              if !fields.is_empty() { simplified_body.push(core_stmt) }
            _ => simplified_body.push(core_stmt)
          }
        }
      }

      let core_ports = ports.map(port => @parse.CorePort::from_port(port))
      Some(@parse.CoreDecl::Module({ path, attributes, ports: core_ports, body: simplified_body, span }))
    }
    ModuleDeclaration(sig) => Some(@parse.CoreDecl::ModuleDeclaration(sig))
    Const(decl) => {
      env.declare_(decl.path, Const(self.simplify_expr(decl.expr, env~)))
      None
    }
    Package(_) | Import(_) | TypeAlias(_) => None
  }
}

pub fn simplify_decls(decls: Array[@parse.Decl]) -> Array[@parse.CoreDecl] raise {
  let simplifier = Simplifier::new()
  let top_env = Scope::new()
  let core_decls = []

  for decl in decls {
    match simplifier.simplify_decl(decl, env=top_env) {
      Some(core_decl) => core_decls.push(core_decl)
      None => ()
    }
  }

  core_decls
}


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
  Const(@parse.Expr)
}

type SimplifierEnv = Scope[@parse.Path, SimplifierEnvEntry]

pub fn Simplifier::new() -> Simplifier {
  { name_counts: {} }
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

  logger.write_string(self.show_context(use_ansi_colors=false))
}

pub impl @parse.Spanned for SimplifierError with span(self) -> @parse.Span {
  match self {
    AssertionAlwaysFails(span~) => span
  }
}

// - Resolve identifiers to unique names
// - Rewrite port accesses on match expressions
// - Rewrite replication expressions into concatenation expressions
// - Hardcode constant references
// - Rewrite nand expressions into not + and expressions
// - Rewrite ternary expressions into match expressions
// - Rewrite slicing expressions using width and offset to absolute slicing expressions
// - Rewrite if expressions into match expressions
// - Check static assertions
// - Rewrite dynamic indexing into static indexing
pub fn Simplifier::simplify_expr(self: Self, expr: @parse.Expr, env~: SimplifierEnv, scope~: Array[@parse.Stmt]) -> @parse.Expr raise {
  let rewr_stmt = fn(stmt) raise { self.simplify_stmt(stmt, env~, scope~) }

  @parse.rewrite_expr(expr, rewr_stmt~, rewr_expr=expr => {
    match expr {
      Identifier(path~, span~, ty~) => {
        match env.resolve(path) {
          Some(Const(expr)) => Some(expr)
          Some(Name(unique_name)) => Some(
            @parse.Expr::Identifier(path=@parse.Path::new(path.packages, unique_name.to_string()), span~, ty~)
          )
          None => None
        }
      }
      Binary(op=Nand, lhs~, rhs~, output_width~, span~, ty~) => Some(
        @parse.Expr::Unary(op=Not, expr=Binary(op=And, lhs~, rhs~, output_width~, span~, ty~), span~, ty~)
      )
      Tuple(elems~, span~, ty=_) => Some({
        let fields = Map::new(capacity=elems.length())
        let types = Map::new(capacity=elems.length())

        for idx, elem in elems {
          let key = idx.to_string()
          fields[key] = elem
          types[key] = elem.ty().val.unwrap_or_error(Failure::Failure("Untyped tuple element"))
        }

        @parse.Expr::Struct(fields=fields, span~, ty={ val: Some(Struct(types)) })
      })
      FieldAccess(expr~, field=port, span=port_acc_span, ty=port_acc_ty) => {
        // Rewrite port accesses on match expressions
        match expr {
          Match(subject~, cases~, default~, span~, ty=_) => {
            let new_cases = []
            let new_default = match default {
              Some(default) => Some(@parse.FieldAccess(expr=default, field=port, span=port_acc_span, ty=port_acc_ty))
              None => None
            }

            for case in cases {
              let (value, expr) = case
              let new_expr = @parse.FieldAccess(expr~, field=port, span=port_acc_span, ty=port_acc_ty)
              new_cases.push((value, new_expr))
            }

            Some(@parse.Expr::Match(subject=subject, cases=new_cases, default=new_default, span~, ty=port_acc_ty))
          }
          _ => None
        }
      }
      Replicate(expr~, count~, concat~, span~, ty~) => Some({
        // Replication of single-bit integers can be rewritten using the pad! function
        // e.g. 21*{a.q[31]} -> pad!(sint(a.q[31]), 21)
        if concat && expr.ty() is { val: Some(UInt(_) | SInt(_) as expr_ty) } && expr_ty.width(span) == 1 {
          let width = count.as_int()
          let pad_expr = @parse.Expr::FunCall(
            name="pad", 
            args=[
              if expr_ty is UInt(_) {
                // pad! sign-extends if the input is signed, so we need to convert to sint first
                @parse.Expr::FunCall(name="sint", args=[expr], span=expr.span(), ty={ val: Some(SInt(Fixed(1))) })
              } else {
                expr
              },
              @parse.Expr::nat(width, span=count.span())],
            span~,
            ty={ val: Some(SInt(Fixed(width))) },
          )

          let final_expr = if expr_ty is UInt(_) {
            @parse.Expr::FunCall(name="uint", args=[pad_expr], span~, ty~)
          } else {
            pad_expr
          }

          self.simplify_expr(final_expr, env~, scope~)
        } else {
          // Rewrite replication expressions into concatenation expressions
          let mut repeated_expr = self.simplify_expr(
            expr,
            env~,
            scope~,
          )

          if concat {
            repeated_expr = @parse.Expr::Spread(expr=repeated_expr, span~, ty~)
          }

          let elems = @utils.fill(count.as_int(), repeated_expr)
          let res = @parse.Expr::Vector(elems~, span~, ty~)

          self.simplify_expr(res, env~, scope~)
        }
      })
      Ternary(cond~, then~, else_~, span~, ty~) => {
        // Rewrite ternary expressions into match expressions
        let match_expr = @parse.Expr::Match(
          subject=cond,
          cases=[
            (@parse.Expr::nat(0, width=Some(1), span~), else_),
            (@parse.Expr::nat(1, width=Some(1), span~), then),
          ],
          default=None,
          span~,
          ty~,
        )

        Some(self.simplify_expr(match_expr, env~, scope~))
      }
      Slicing(expr~, hi=msb, lo=width, kind=Width, span~, ty~) => Some({
        let lsb = msb.as_int() - width.as_int() + 1
        @parse.Expr::Slicing(expr~, hi=msb, lo=@parse.Expr::nat(lsb, span=width.span()), kind=Absolute, span~, ty~)
      })
      If(cond~, then~, else_~, span~, ty~) => {
        // Rewrite if expressions into match expressions
        let match_expr = @parse.Expr::Match(
          subject=cond,
          cases={
            let cases = [
              (@parse.Expr::nat(1, width=Some(1), span~), then),
            ]

            match else_ {
              Some(else_) => {
                cases.push((@parse.Expr::nat(0, width=Some(1), span~), else_))
              }
              None => ()
            }
          
            cases
          },
          default=None,
          span~,
          ty~,
        )

        Some(self.simplify_expr(match_expr, env~, scope~))
      }
      FunCall(name="assert", args=[pred, ..], span~, ty~) => {
        try pred.as_int() catch {
          _ => None
        } noraise {
          0 => raise AssertionAlwaysFails(span~)
          1 => Some(@parse.Expr::Tuple(elems=[], span~, ty~))
          _ => None
        }
      }
      _ => None
    }
  })
}

pub fn Simplifier::simplify_stmt(self: Self, stmt: @parse.Stmt, env~: SimplifierEnv, scope~: Array[@parse.Stmt]) -> Iter[@parse.Stmt] raise {
  match stmt {
    Expr(expr~, span~) => {
      let simplified_expr = self.simplify_expr(expr, env~, scope~)
      Iter::singleton(@parse.Stmt::Expr(expr=simplified_expr, span~))
    }
    Let(name~, ty~, expr~, span~) => {
      let simplified_expr = match expr {
        Some(expr) => Some(self.simplify_expr(expr, env~, scope~))
        None => None
      }

      // references to this name from now on until the next redefinition will resolve to this unique name
      let unique_name = self.declare_unique(name)
      env.declare_shadowing(@parse.Path::new([], name), Name(unique_name))

      Iter::singleton(@parse.Stmt::Let(name=unique_name.to_string(), ty~, expr=simplified_expr, span~))
    }
    Assign(lhs~, rhs~, span~) => {
      let simplified_lhs = self.simplify_expr(lhs, env~, scope~)
      let simplified_rhs = self.simplify_expr(rhs, env~, scope~)
      Iter::singleton(@parse.Stmt::Assign(lhs=simplified_lhs, rhs=simplified_rhs, span~))
    }
    For(_) => {
      raise Failure::Failure("For stmt after monomorphization")
    }
    Scope(body~, ..) => {
      let simplified_body = []
      let scope_env = env.child()

      for stmt in body {
        simplified_body.push_iter(self.simplify_stmt(stmt, env=scope_env, scope~))
      }

      simplified_body.iter()
    }
    Const(decl~, span=_) => {
      env.declare_(decl.path, Const(decl.expr))
      Iter::empty()
    }
  }
}

fn Simplifier::simplify_decl(self: Self, decl: @parse.Decl, env~: SimplifierEnv) -> @parse.Decl? raise {
  match decl {
    Module({ path, params, attributes, ports, body, span }) => {
      let simplified_body = []
      let mod_env = env.child()

      for port in ports {
        let _ = self.declare_unique(port.name)
      }

      for stmt in body {
        let scope = []
        let stmts = self.simplify_stmt(stmt, env=mod_env, scope~)

        for stmt in stmts {
          // ignore empty tuples, whcih are used to represent empty expressions
          if not(stmt is @parse.Stmt::Expr(expr=Tuple(elems=[], ..), ..)) {
            scope.push(stmt)
          }
        }

        simplified_body.push_iter(scope.iter())
      }

      Some(@parse.Decl::Module({ path, params, attributes, ports, body: simplified_body, span }))
    }
    ModuleDeclaration(sig) => {
      Some(@parse.Decl::ModuleDeclaration(sig))
    }
    Const(decl) => {
      env.declare_(decl.path, Const(decl.expr))
      None
    }
    Package(_) => None
    Import(_) => None
    TypeAlias(_) => None
  }
}

pub fn simplify_decls(decls: Array[@parse.Decl]) -> Array[@parse.Decl] raise {
  let simplifier = Simplifier::new()
  let top_env = Scope::new()
  let simplified_decls = []

  for decl in decls {
    match simplifier.simplify_decl(decl, env=top_env) {
      Some(simplified_decl) => {
        simplified_decls.push(simplified_decl)
      }
      None => ()
    }
  }

  simplified_decls
}

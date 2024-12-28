
pub(readonly) struct Simplifier {
  genvars: @elaborate.Scope[Int]
  names: @elaborate.Scope[UniqueName]
  name_counts: Map[String, Int]
}

struct UniqueName {
  name: String
  id: Int
}

impl Show for UniqueName with output(self, logger) {
  if self.id > 0 {
    logger.write_string("%")
    logger.write_string(self.name)
    logger.write_string(self.id.to_string())
  } else {
    logger.write_string(self.name)
  }
}

pub fn Simplifier::new() -> Simplifier {
  {
    genvars: @elaborate.Scope::new(),
    names: @elaborate.Scope::new(),
    name_counts: {},
  }
}

pub(readonly) type! SimplificationError {

}

pub fn declare_unique(self: Simplifier, name: String) -> UniqueName {
  let count = match self.name_counts[name] {
    Some(count) => count
    None => 0
  }

  self.name_counts[name] = count + 1

  { name, id: count }
}

// 1. Resolve identifiers to unique names
// 2. Replace genvars with their values
// 3. Rewrite non-constant indexing expressions to match expressions
// 4. Rewrite port accesses on match expressions
pub fn simplify_expr(self: Simplifier, expr: @parse.Expr) -> @parse.Expr!Error {
  @parse.rewrite_expr!(expr, fn(expr) {
    (match expr {
      Identifier(name~, span~, ty~) => {
        match self.genvars.resolve(name) {
          Some(value) => @parse.Expr::Natural(value=value, width=None, span~, ty~)
          None => match self.names.resolve(name) {
            Some(unique_name) => @parse.Expr::Identifier(name=unique_name.to_string(), span~, ty~)
            None => expr
          }
        }
      }
      Indexing(expr~, index~, span~, ty~) as indexing_expr => {
        match index.expect_int?() {
          Ok(_) => indexing_expr
          Err(_) => {
            let s_width = index.ty().val.unwrap().width().or_error!(Failure("Unsized index"))
            let match_expr = @parse.Expr::Match(
              subject=index,
              cases={
                let cases = []

                for i in 0..<@utils.pow2(s_width) {
                  let lhs = @parse.Expr::Natural(value=i, width=Some(s_width), span~, ty=index.ty())
                  let idx = @parse.Expr::Natural(value=i, width=None, span~, ty=index.ty())
                  cases.push((lhs, @parse.Expr::Indexing(expr~, index=idx, span~, ty~)))
                }

                cases
              },
              default=None,
              span~,
              ty~,
            )

            self.simplify_expr!(match_expr)
          }
        }
      }
      PortAccess(expr~, port~, span=port_acc_span, ty=port_acc_ty) as port_access_expr => {
        match expr {
          Match(subject~, cases~, default~, span~, ty=_) => {
            let new_cases = []
            let new_default = match default {
              Some(default) => Some(@parse.PortAccess(expr=default, port~, span=port_acc_span, ty=port_acc_ty))
              None => None
            }

            for case in cases {
              let (value, expr) = case
              let new_expr = @parse.PortAccess(expr~, port~, span=port_acc_span, ty=port_acc_ty)
              new_cases.push((value, new_expr))
            }

            @parse.Expr::Match(subject=subject, cases=new_cases, default=new_default, span~, ty=port_acc_ty)
          }
          _ => port_access_expr
        }
      }
      _ => expr
    }).constant_folding!()
  })
}

pub fn simplify_stmt(self: Simplifier, stmt: @parse.Stmt) -> Array[@parse.Stmt]!Error {
  match stmt {
    Expr(expr~, span~) => {
      let simplified_expr = self.simplify_expr!(expr)
      [@parse.Stmt::Expr(expr=simplified_expr, span~)]
    }
    Let(name~, ty~, expr~, span~) => {
      let simplified_expr = match expr {
        Some(expr) => Some(self.simplify_expr!(expr))
        None => None
      }

      let unique_name = self.declare_unique(name)
      self.names.declare_shadowing(name, unique_name)

      [@parse.Stmt::Let(name=unique_name.to_string(), ty~, expr=simplified_expr, span~)]
    }
    Assign(lhs~, rhs~, span~) => {
      let simplified_lhs = self.simplify_expr!(lhs)
      let simplified_rhs = self.simplify_expr!(rhs)
      [@parse.Stmt::Assign(lhs=simplified_lhs, rhs=simplified_rhs, span~)]
    }
    For(var~, range~, body~, ..) => {
      let unrolled_stmts = []
      let start = self.simplify_expr!(range.start).expect_int!()
      let mut end = self.simplify_expr!(range.end).expect_int!()

      if range.inclusive {
        end += 1
      }

      for i in start..<end {
        self.genvars.declare!(var, i)

        for stmt in body {
          unrolled_stmts.push_iter(self.simplify_stmt!(stmt).iter())
        }

        self.genvars.remove(var)
      }

      unrolled_stmts
    }
    Scope(body~, ..) => {
      let simplified_body = []

      for stmt in body {
        simplified_body.push_iter(self.simplify_stmt!(stmt).iter())
      }

      simplified_body
    }
  }
}

pub fn simplify_decl(self: Simplifier, decl: @parse.Decl) -> @parse.Decl!Error {
  match decl {
    Module({ name, params, attributes, ports, body, span }) => {
      let simplified_body = []

      for stmt in body {
        simplified_body.push_iter(self.simplify_stmt!(stmt).iter())
      }

      @parse.Decl::Module({ name, params, attributes, ports, body: simplified_body, span })
    }
    ModuleDeclaration(sig) => {
      @parse.Decl::ModuleDeclaration(sig)
    }
  }
}


pub struct Simplifier {
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

pub type! SimplificationError {
  TupleAccessOutOfBounds(span~: @parse.Span)
}

pub impl @parse.Spanned for SimplificationError with span(self) -> @parse.Span {
  match self {
    TupleAccessOutOfBounds(span~) => span
  }
}

pub impl Show for SimplificationError with output(self, logger) -> Unit {
  match self {
    TupleAccessOutOfBounds(_) => {
      logger.write_string("Tuple access out of bounds")
    }
  }

  logger.write_string(self.show_context())
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
// 5. Rewrite tuples with struct expressions and tuple indexing with field access
// 6. Rewrite replication expressions into concatenation expressions
// 7. Remove unecessary spreads
// 8. Rewrite flat constant vectors to natural expressions
pub fn simplify_expr(self: Simplifier, expr: @parse.Expr) -> @parse.Expr! {
  @parse.rewrite_expr!(expr, fn(expr) {
    (match expr {
      Identifier(name~, span~, ty~) => {
        // Resolve identifiers to unique names
        match self.genvars.resolve(name) {
          Some(value) => @parse.Expr::Natural(bits=@parse.Bits::from!(value, span~), width=None, base=10, span~, ty~)
          None => match self.names.resolve(name) {
            Some(unique_name) => @parse.Expr::Identifier(name=unique_name.to_string(), span~, ty~)
            None => expr
          }
        }
      }
      Tuple(elems~, span~, ty=_) => {
        let fields = Map::new(capacity=elems.length())
        let types = Map::new(capacity=elems.length())

        for idx, elem in elems {
          let key = idx.to_string()
          fields[key] = elem
          types[key] = elem.ty().val.or_error!(Failure("Untyped tuple element"))
        }

        @parse.Expr::Struct(fields=fields, span~, ty={ val: Some(Struct(types)) })
      }
      Indexing(expr~, index~, span~, ty~) as indexing_expr => {
        match index.expect_int?() {
          Ok(idx) => {
            match expr.ty().val {
              // Rewrite tuple indexing into struct field access
              Some(Tuple(types)) => {
                if idx >= types.length() {
                  raise TupleAccessOutOfBounds(span~)
                }

                let key = idx.to_string()
                @parse.Expr::FieldAccess(expr=expr, field=key, span~, ty={ val: Some(types[idx]) })
              }
              _ => indexing_expr
            }
          }
          Err(_) => {
            // Rewrite non-constant indexing expressions to match expressions
            let s_width = index.ty().val.unwrap().width!(index.span())
            let match_expr = @parse.Expr::Match(
              subject=index,
              cases={
                let cases = []

                for i in 0..<@utils.pow2(s_width) {
                  let lhs = @parse.Expr::nat!(i, width=Some(s_width), base=10, span~)
                  let idx = @parse.Expr::nat!(i, width=None, base=10, span~)
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
      FieldAccess(expr~, field=port, span=port_acc_span, ty=port_acc_ty) as port_access_expr => {
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

            @parse.Expr::Match(subject=subject, cases=new_cases, default=new_default, span~, ty=port_acc_ty)
          }
          _ => port_access_expr
        }
      }
      Replicate(expr~, count~, concat~, span~, ty~) => {
        // Rewrite replication expressions into concatenation expressions
        let repeated_expr = self.simplify_expr!(match concat {
          true => @parse.Expr::Spread(expr~, span~, ty~)
          false => expr
        })

        let elems = @utils.fill(count.expect_int!(), repeated_expr)
        
        self.simplify_expr!(@parse.Expr::Vector(elems~, span~, ty~))
      }
      Spread(expr~, ..) as spread_expr => {
        // Remove unecessary spreads
        match expr.ty().val.unwrap().width!(expr.span()) {
          1 => expr
          _ => spread_expr
        }
      }
      Vector(elems~, span~, ty={ val: Some(Vector(ty=Logic, len=Fixed(len))) } as ty) => {
        // Rewrite flat constant vectors to natural expressions
        if elems.iter().all(fn(elem) { match elem { Natural(_) => true; _ => false } }) {
          let bits = []

          for elem in elems {
            bits.append(match elem {
              Natural(bits={bits, ..}, ..) => bits
              _ => []
            })
          }

          @parse.Expr::Natural(bits=@parse.Bits::new(bits, span~), width=Some(len), base=2, span~, ty~)
        } else {
          expr
        }
      }
      _ => expr
    }).partial_eval!()
  })
}

pub fn simplify_stmt(self: Simplifier, stmt: @parse.Stmt) -> Array[@parse.Stmt]! {
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

pub fn simplify_decl(self: Simplifier, decl: @parse.Decl) -> @parse.Decl! {
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

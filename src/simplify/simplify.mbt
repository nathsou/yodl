
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
    logger.write_string(self.id.to_string())
  } else {
    logger.write_string(self.name)
  }
}

enum SimplifierEnvEntry {
  GenVar(Int)
  Name(UniqueName)
  Const(@parse.Expr)
}

typealias SimplifierEnv = @elaborate.Scope[@parse.Path, SimplifierEnvEntry]

pub fn Simplifier::new() -> Simplifier {
  { name_counts: {} }
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
// 5. Rewrite replication expressions into concatenation expressions
// 6. Remove unecessary spreads
// 7. Rewrite flat constant vectors to natural expressions
// 8. Hardcode constant references
// 9. Rewrite strings into vectors
// 10. Rewrite nand expressions into not + and expressions
// 11. Rewrite match expressions with two cases: 0 and 1, as ternary expressions
pub fn simplify_expr(self: Simplifier, expr: @parse.Expr, env~: SimplifierEnv) -> @parse.Expr! {
  @parse.rewrite_expr!(expr, fn(expr) {
    (match expr {
      Identifier(path~, span~, ty~) => {
        match env.resolve(path) {
          Some(GenVar(value)) => @parse.Expr::Natural(bits=@parse.Bits::from!(value, span~), width=None, base=10, span~, ty~)
          Some(Const(expr)) => expr
          Some(Name(unique_name)) => @parse.Expr::Identifier(path=@parse.Path::new(path.packages, unique_name.to_string()), span~, ty~)
          None => expr
        }
      }
      Binary(op=Nand, lhs~, rhs~, span~, ty~) => {
        @parse.Expr::Unary(op=Not, expr=Binary(op=And, lhs~, rhs~, span~, ty~), span~, ty~)
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
        match index.as_int?() {
          Ok(_) => indexing_expr
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

            self.simplify_expr!(match_expr, env~)
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
        let repeated_expr = self.simplify_expr!(
          match concat {
            true => @parse.Expr::Spread(expr~, span~, ty~)
            false => expr
          },
          env~
        )

        let elems = @utils.fill(count.as_int!(), repeated_expr)
        self.simplify_expr!(@parse.Expr::Vector(elems~, span~, ty~), env~)
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
      String(str~, span~, ty=_) => {
        let ascii = Array::new(capacity=str.length() * @parse.BITS_PER_ASCII_CHAR)

        for char in str {
          for bit in @utils.bin(char.to_int(), width=@parse.BITS_PER_ASCII_CHAR) {
            ascii.push(match bit {
              1 => @parse.BinaryDigit::One
              _ => @parse.BinaryDigit::Zero
            })
          }
        }

        @parse.Expr::Natural(
          bits=@parse.Bits::new(ascii, span~),
          width=Some(ascii.length()),
          base=2,
          span~,
          ty={ val: Some(Vector(ty=Logic, len=Fixed(ascii.length()))),
        })
      }
      Match(subject~, cases=[(Natural(bits=bits1, ..), rhs1), (Natural(bits=bits2, ..), rhs2)], default=None, span~, ty~) => {
        // Rewrite match expressions with two cases: 0 and 1, as ternary expression
        match (bits1.as_int?(), bits2.as_int?()) {
          (Ok(1), Ok(0)) => Ternary(cond=subject, then=rhs1, else_=rhs2, span~, ty~)
          (Ok(0), Ok(1)) => Ternary(cond=subject, then=rhs2, else_=rhs1, span~, ty~)
          _ => expr
        }
      }
      _ => expr
    }).partial_eval!()
  })
}

pub fn simplify_stmt(self: Simplifier, stmt: @parse.Stmt, env~: SimplifierEnv) -> Array[@parse.Stmt]! {
  match stmt {
    Expr(expr~, span~) => {
      let simplified_expr = self.simplify_expr!(expr, env~)
      [@parse.Stmt::Expr(expr=simplified_expr, span~)]
    }
    Let(name~, ty~, expr~, span~) => {
      let simplified_expr = match expr {
        Some(expr) => Some(self.simplify_expr!(expr, env~))
        None => None
      }

      let unique_name = self.declare_unique(name)
      env.declare_shadowing(@parse.Path::new([], name), Name(unique_name))

      [@parse.Stmt::Let(name=unique_name.to_string(), ty~, expr=simplified_expr, span~)]
    }
    Assign(lhs~, rhs~, span~) => {
      let simplified_lhs = self.simplify_expr!(lhs, env~)
      let simplified_rhs = self.simplify_expr!(rhs, env~)
      [@parse.Stmt::Assign(lhs=simplified_lhs, rhs=simplified_rhs, span~)]
    }
    For(var~, range~, body~, ..) => {
      let unrolled_stmts = []
      let start = self.simplify_expr!(range.start, env~).as_int!()
      let mut end = self.simplify_expr!(range.end, env~).as_int!()

      if range.inclusive {
        end += 1
      }

      let var_path = @parse.Path::new([], var)

      for i in start..<end {
        env.declare!(var_path, GenVar(i))

        for stmt in body {
          unrolled_stmts.push_iter(self.simplify_stmt!(stmt, env~).iter())
        }

        env.remove(var_path)
      }

      unrolled_stmts
    }
    Scope(body~, ..) => {
      let simplified_body = []
      let scope_env = env.child()

      for stmt in body {
        simplified_body.push_iter(self.simplify_stmt!(stmt, env=scope_env).iter())
      }

      simplified_body
    }
    Const(decl~, span=_) => {
      env.declare!(decl.path, Const(decl.expr))
      []
    }
  }
}

fn simplify_decl(self: Simplifier, decl: @parse.Decl, env~: SimplifierEnv) -> @parse.Decl?! {
  match decl {
    Module({ path, params, attributes, ports, body, span }) => {
      let simplified_body = []
      let mod_env = env.child()

      for stmt in body {
        simplified_body.push_iter(self.simplify_stmt!(stmt, env=mod_env).iter())
      }

      Some(@parse.Decl::Module({ path, params, attributes, ports, body: simplified_body, span }))
    }
    ModuleDeclaration(sig) => {
      Some(@parse.Decl::ModuleDeclaration(sig))
    }
    Const(decl) => {
      env.declare!(decl.path, Const(decl.expr))
      None
    }
    Package(_) => None
    Import(_) => None
  }
}

pub fn simplify_decls(decls: Array[@parse.Decl]) -> Array[@parse.Decl]! {
  let simplifier = Simplifier::new()
  let top_env = @elaborate.Scope::new()
  let simplified_decls = []

  for decl in decls {
    match simplifier.simplify_decl!(decl, env=top_env) {
      Some(simplified_decl) => {
        simplified_decls.push(simplified_decl)
      }
      None => ()
    }
  }

  simplified_decls
}


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
  Name(UniqueName)
  Const(@parse.Expr)
}

typealias SimplifierEnv = @elaborate.Scope[@parse.Path, SimplifierEnvEntry]

pub fn Simplifier::new() -> Simplifier {
  { name_counts: {} }
}

pub type! SimplifierError {
  InvalidCharacterInString(char~: Char, span~: @parse.Span)
}

pub impl @parse.Spanned for SimplifierError with span(self) {
  match self {
    InvalidCharacterInString(span~, ..) => span
  }
}

pub impl Show for SimplifierError with output(self, logger) {
  match self {
    InvalidCharacterInString(char~, span=_) => {
      logger.write_string("Character '\{char}'' is not part of the ISO/IEC 8859-1 standard and cannot be used in a string literal ")
      logger.write_char(char)
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

// - Resolve identifiers to unique names
// - Rewrite non-constant indexing expressions to match expressions
// - Rewrite port accesses on match expressions
// - Rewrite replication expressions into concatenation expressions
// - Remove unecessary spreads
// - Rewrite flat constant vectors to natural expressions
// - Hardcode constant references
// - Rewrite strings into vectors
// - Rewrite nand expressions into not + and expressions
// - Rewrite ternary expressions into match expressions
// - Rewrite slicing expressions using width and offset to absolute slicing expressions
pub fn simplify_expr(self: Simplifier, expr: @parse.Expr, env~: SimplifierEnv, scope~: Array[@parse.Stmt]) -> @parse.Expr! {
  let rewr_stmt = fn!(stmt) { self.simplify_stmt!(stmt, env~, scope~) }

  @parse.rewrite_expr!(expr, rewr_stmt~, rewr_expr=fn(expr) {
    (match expr {
      Identifier(path~, span~, ty~) => {
        match env.resolve(path) {
          Some(Const(expr)) => Some(expr)
          Some(Name(unique_name)) => Some(
            @parse.Expr::Identifier(path=@parse.Path::new(path.packages, unique_name.to_string()), span~, ty~)
          )
          None => None
        }
      }
      Binary(op=Nand, lhs~, rhs~, span~, ty~) => Some(
        @parse.Expr::Unary(op=Not, expr=Binary(op=And, lhs~, rhs~, span~, ty~), span~, ty~)
      )
      Tuple(elems~, span~, ty=_) => Some({
        let fields = Map::new(capacity=elems.length())
        let types = Map::new(capacity=elems.length())

        for idx, elem in elems {
          let key = idx.to_string()
          fields[key] = elem
          types[key] = elem.ty().val.or_error!(Failure("Untyped tuple element"))
        }

        @parse.Expr::Struct(fields=fields, span~, ty={ val: Some(Struct(types)) })
      })
      Indexing(expr~, index~, span~, ty~) as indexing_expr => Some({
        match index.as_int?() {
          Ok(_) => indexing_expr
          Err(_) => {
            // Rewrite non-constant indexing expressions to match expressions
            let s_width = index.ty().val.unwrap().width!(index.span())
            let match_expr = @parse.Expr::Match(
              subject=index,
              cases={
                let cases = []
                let max = @utils.pow2(s_width) - 1

                for i in 0..=max {
                  let lhs = @parse.Expr::nat!(i, width=Some(s_width), base=10, span~)
                  let idx = @parse.Expr::nat!(max - i, width=None, base=10, span~)
                  cases.push((lhs, @parse.Expr::Indexing(expr~, index=idx, span~, ty~)))
                }

                cases
              },
              default=None,
              span~,
              ty~,
            )

            self.simplify_expr!(match_expr, env~, scope~)
          }
        }
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
        // Rewrite replication expressions into concatenation expressions
        let repeated_expr = self.simplify_expr!(
          match concat {
            true => @parse.Expr::Spread(expr~, span~, ty~)
            false => expr
          },
          env~,
          scope~,
        )

        let elems = @utils.fill(count.as_int!(), repeated_expr)
        self.simplify_expr!(@parse.Expr::Vector(elems~, span~, ty~), env~, scope~)
      })
      Spread(expr~, ..) as spread_expr => Some({
        // Remove unecessary spreads
        match expr.ty().val.unwrap().width!(expr.span()) {
          1 => expr
          _ => spread_expr
        }
      })
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

          Some(@parse.Expr::Natural(bits=@parse.Bits::new(bits, span~), width=Some(len), base=2, span~, ty~))
        } else {
          None
        }
      }
      String(str~, span~, ty=_) => Some({
        let encoded = Array::new(capacity=str.length() * @parse.BITS_PER_CHAR)

        for char in str {
          let char_latin1 = char.to_int()

          if char_latin1 < 0 || char_latin1 > 255 {
            raise InvalidCharacterInString(char~, span~)
          }

          for bit in @utils.bin(char_latin1, width=@parse.BITS_PER_CHAR) {
            encoded.push(match bit {
              1 => @parse.BinaryDigit::One
              _ => @parse.BinaryDigit::Zero
            })
          }
        }

        @parse.Expr::Natural(
          bits=@parse.Bits::new(encoded, span~),
          width=Some(encoded.length()),
          base=2,
          span~,
          ty={ val: Some(Vector(ty=Logic, len=Fixed(encoded.length()))),
        })
      })
      Ternary(cond~, then~, else_~, span~, ty~) => {
        // Rewrite ternary expressions into match expressions
        let match_expr = @parse.Expr::Match(
          subject=cond,
          cases=[
            (@parse.Expr::nat!(0, width=Some(1), span~), else_),
            (@parse.Expr::nat!(1, width=Some(1), span~), then),
          ],
          default=None,
          span~,
          ty~,
        )

        Some(self.simplify_expr!(match_expr, env~, scope~))
      }
      Slicing(expr~, msb~, lsb=width, kind=Width, span~, ty~) => Some({
        let lsb = msb.as_int!() - width.as_int!() + 1
        @parse.Expr::Slicing(expr~, msb~, lsb=@parse.Expr::nat!(lsb, span=width.span()), kind=Absolute, span~, ty~)
      })
      _ => None
    })
  })
}

pub fn simplify_stmt(self: Simplifier, stmt: @parse.Stmt, env~: SimplifierEnv, scope~: Array[@parse.Stmt]) -> Iter[@parse.Stmt]! {
  match stmt {
    Expr(expr~, span~) => {
      let simplified_expr = self.simplify_expr!(expr, env~, scope~)
      Iter::singleton(@parse.Stmt::Expr(expr=simplified_expr, span~))
    }
    Let(name~, ty~, expr~, span~) => {
      let simplified_expr = match expr {
        Some(expr) => Some(self.simplify_expr!(expr, env~, scope~))
        None => None
      }

      // references to this name from now on until the next redefinition will resolve to this unique name
      let unique_name = self.declare_unique(name)
      env.declare_shadowing(@parse.Path::new([], name), Name(unique_name))

      Iter::singleton(@parse.Stmt::Let(name=unique_name.to_string(), ty~, expr=simplified_expr, span~))
    }
    Assign(lhs~, rhs~, span~) => {
      let simplified_lhs = self.simplify_expr!(lhs, env~, scope~)
      let simplified_rhs = self.simplify_expr!(rhs, env~, scope~)
      Iter::singleton(@parse.Stmt::Assign(lhs=simplified_lhs, rhs=simplified_rhs, span~))
    }
    For(_) => {
      raise Failure("For stmt after monomorphization")
    }
    Scope(body~, ..) => {
      let simplified_body = []
      let scope_env = env.child()

      for stmt in body {
        simplified_body.push_iter(self.simplify_stmt!(stmt, env=scope_env, scope~))
      }

      simplified_body.iter()
    }
    Const(decl~, span=_) => {
      env.declare!(decl.path, Const(decl.expr))
      Iter::empty()
    }
    Procedural(body~, span~) => {
      let simplified_body = []
      let scope_env = env.child()

      for stmt in body {
        simplified_body.push_iter(self.simplify_stmt!(stmt, env=scope_env, scope~))
      }

      Iter::singleton(@parse.Stmt::Procedural(body=simplified_body, span~))
    }
  }
}

fn simplify_decl(self: Simplifier, decl: @parse.Decl, env~: SimplifierEnv) -> @parse.Decl?! {
  match decl {
    Module({ path, params, attributes, ports, body, span }) => {
      let simplified_body = []
      let mod_env = env.child()

      for port in ports {
        let _ = self.declare_unique(port.name)
      }

      for stmt in body {
        let scope = []
        let stmts = self.simplify_stmt!(stmt, env=mod_env, scope~)

        for stmt in stmts {
          scope.push(stmt)
        }

        simplified_body.push_iter(scope.iter())
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

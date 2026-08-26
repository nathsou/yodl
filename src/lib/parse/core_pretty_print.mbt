
// Pretty-printing for Core AST types (synthesisable subset).
// Mirrors emit_expr/emit_stmt/emit_decl but operates on CoreExpr/CoreStmt/CoreDecl.

pub fn AstEmitter::emit_core_expr(self: AstEmitter, expr: CoreExpr, indent~: Bool = false) -> Unit {
  if indent {
    self.write_indent()
  }

  if self.show_expr_types && !(expr.ty().val is None) {
    self.write("(")
  }

  match expr {
    Natural(value~, width~, base~, ..) => {
      self.write(show_natural(value~, base~, width~))
    }
    Identifier(path~, ..) => {
      self.write(Show::to_string(path))
    }
    String(value=str, ..) => {
      self.write("\"")
      self.write(str)
      self.write("\"")
    }
    Unary(op~, expr~, ..) => {
      self.write("(")
      self.write(Show::to_string(op))
      self.write(" ")
      self.emit_core_expr(expr)
      self.write(")")
    }
    Binary(op~, lhs~, rhs~, ..) => {
      self.write("(")
      self.emit_core_expr(lhs)
      self.write(" ")
      self.write(Show::to_string(op))
      self.write(" ")
      self.emit_core_expr(rhs)
      self.write(")")
    }
    Truncate(expr~, ..) => {
      self.write("truncate(")
      self.emit_core_expr(expr)
      self.write(")")
    }
    ZeroExtend(expr~, ..) => {
      self.write("zero_extend(")
      self.emit_core_expr(expr)
      self.write(")")
    }
    SignExtend(expr~, ..) => {
      self.write("sign_extend(")
      self.emit_core_expr(expr)
      self.write(")")
    }
    Indexing(expr~, index~, ..) => {
      self.emit_core_expr(expr)
      self.write("[")
      self.emit_core_expr(index)
      self.write("]")
    }
    Slicing(expr~, hi=msb, lo=lsb, ..) => {
      self.emit_core_expr(expr)
      self.write("[")
      self.emit_core_expr(msb)
      self.write(":")
      self.emit_core_expr(lsb)
      self.write("]")
    }
    FieldAccess(expr~, field=port, ..) => {
      self.emit_core_expr(expr)
      self.write(".")
      self.write(port)
    }
    Instance(path~, ports~, ty~, ..) => {
      self.write(Show::to_string(path))

      let params = match ty.val {
        Some(CoreType::Instance(params~, ..)) => params
        _ => Map([])
      }
      if !params.is_empty() {
        self.write("[")

        let mut first = true
        for name, param in params {
          if !first {
            self.write(", ")
          }
          self.write(name)
          self.write(": ")
          self.write(Show::to_string(param))
          first = false
        }

        self.write("]")
      }

      self.write("(")

      let wrap = ports.length() > 2

      if wrap {
        self.indent += 1
      }

      let mut i = 0

      for port, expr in ports {
        if wrap {
          self.write("\n")
          self.write_indent()
        }

        self.write(port)
        self.write(": ")
        self.emit_core_expr(expr)

        if wrap || i < ports.length() - 1 {
          self.write(", ")
        }

        i += 1
      }

      if wrap {
        self.indent -= 1
        self.write("\n")
        self.write_indent()
      }

      self.write(")")
    }
    Vector(elems~, ..) => {
      self.write("[")
      self.indent += 1

      for i, elem in elems {
        if i > 0 {
          self.write(", ")
        }

        self.emit_core_expr(elem)
      }

      self.indent -= 1
      self.write("]")
    }
    Spread(expr~, ..) => {
      self.write("..")
      self.emit_core_expr(expr)
    }
    Match(subject~, cases~, default~, ..) => {
      self.write("match ")
      self.emit_core_expr(subject)
      self.write(" {\n")
      self.indent += 1

      for case in cases {
        let (value, expr) = case
        self.write_indent()
        self.emit_core_expr(value)
        self.write(" => ")
        self.emit_core_expr(expr)
        self.write(",\n")
      }

      match default {
        Some(expr) => {
          self.write_indent()
          self.write("_ => ")
          self.emit_core_expr(expr)
          self.write(",\n")
        }
        None => ()
      }

      self.indent -= 1
      self.write_indent()
      self.write("}")
    }
    FunCall(name~, args~, ..) => {
      self.write(name)
      self.write("!(")

      for i, arg in args {
        if i > 0 {
          self.write(", ")
        }

        self.emit_core_expr(arg)
      }

      self.write(")")
    }
    Struct(fields~, ..) => {
      let n = fields.length()
      let mut is_positional = n > 0

      for i in 0..<n {
        if !fields.contains(i.to_string()) {
          is_positional = false
          break
        }
      }

      if n == 0 {
        self.write("()")
      } else if is_positional {
        self.write("(")
        for i in 0..<n {
          if i > 0 {
            self.write(", ")
          }
          self.emit_core_expr(fields.get(i.to_string()).unwrap())
        }
        if n == 1 {
          self.write(",")
        }
        self.write(")")
      } else {
        self.write("(")
        let mut first = true

        for field in fields {
          let (name, expr) = field

          if !first {
            self.write(", ")
          }

          first = false

          if name.has_prefix("..") {
            self.emit_core_expr(expr)
          } else {
            self.write(name)
            self.write(": ")
            self.emit_core_expr(expr)
          }
        }

        self.write(")")
      }
    }
    Block(body~, last~, ..) => {
      self.write("{\n")
      self.indent += 1

      for stmt in body {
        self.emit_core_stmt(stmt)
        self.write("\n")
      }

      match last {
        Some(expr) => {
          self.write_indent()
          self.emit_core_expr(expr)
          self.write(";\n")
        }
        None => ()
      }

      self.indent -= 1
      self.write_indent()
      self.write("}")
    }
  }

  if self.show_expr_types {
    match expr.ty().val {
      Some(ty) => self.write(": \{ty})")
      None => ()
    }
  }
}

pub fn AstEmitter::emit_core_stmt(self: AstEmitter, stmt: CoreStmt) -> Unit {
  self.write_indent()

  match stmt {
    Expr(expr~, ..) => {
      self.emit_core_expr(expr)
      self.write(";")
    }
    Let(name~, ty~, expr~, ..) => {
      self.write("let \{name}")

      match ty.val {
        Some(ty) => {
          self.write(": ")
          self.write(Show::to_string(ty))
        }
        None => ()
      }

      match expr {
        Some(expr) => {
          self.write(" = ")
          self.emit_core_expr(expr)
        }
        None => ()
      }

      self.write(";")
    }
    Assign(lhs~, rhs~, ..) => {
      self.emit_core_expr(lhs)
      self.write(" = ")
      self.emit_core_expr(rhs)
      self.write(";")
    }
  }
}

pub fn AstEmitter::emit_core_module_decl(self: AstEmitter, mod: CoreModuleDecl) -> Unit {
  let sig: ModuleSignature = {
    path: mod.path,
    params: [],
    attributes: mod.attributes,
    ports: mod.ports.map(CorePort::to_port),
    span: mod.span,
  }

  self.emit_module_sig(sig)
  self.write(" {\n")
  self.indent += 1

  for stmt in mod.body {
    self.emit_core_stmt(stmt)
    self.write("\n")
  }

  self.indent -= 1
  self.emit("}")
}

pub fn AstEmitter::emit_core_decl(self: AstEmitter, decl: CoreDecl) -> Unit {
  match decl {
    Module(mod) => self.emit_core_module_decl(mod)
    ModuleDeclaration(sig) => self.emit_module_sig(sig)
  }
}

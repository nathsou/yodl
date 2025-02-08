
pub(all) struct AstEmitter {
  mut indent: Int
  builder: StringBuilder
  show_expr_types: Bool
}

pub fn AstEmitter::new(show_expr_types~: Bool = false) -> AstEmitter {
  { indent: 0, builder: StringBuilder::new(), show_expr_types }
}

let show_instance_accessed_ports = true

pub impl Show for AstEmitter with output(self, logger) {
  logger.write_string(self.builder.to_string())
}

pub fn emit(self: AstEmitter, s: String) -> Unit {
  self.builder.write_string("  ".repeat(self.indent) + s)
}

pub fn write_indent(self: AstEmitter) -> Unit {
  self.builder.write_string("  ".repeat(self.indent))
}

pub fn write(self: AstEmitter, s: String) -> Unit {
  self.builder.write_string(s)
}

pub impl Show for UnaryOp with output(op, logger) {
  logger.write_string(match op {
    Not => "not"
  })
}

pub impl Show for BinaryOp with output(op, logger) {
  logger.write_string(match op {
    Add => "+"
    Sub => "-"
    Mul => "*"
    Div => "/"
    Mod => "%"
    Equ => "=="
    Neq => "!="
    Lss => "<:"
    Gtr => ">:"
    Leq => "<="
    Geq => ">="
    Shl => "shl"
    Shr => "shr"
    Ternary => "?:"
    And => "and"
    Or => "or"
    Xor => "xor"
    Nand => "nand"
    Nor => "nor"
    Xnor => "xnor"
  })
}

pub fn emit_expr(self: AstEmitter, expr: Expr, indent~: Bool = false) -> Unit {
  if indent {
    self.write_indent()
  }

  if self.show_expr_types && not(expr.ty().val.is_empty()) {
    self.write("(")
  }

  match expr {
    Natural(value~, width~, base~, ..) => {
      match width {
        Some(width) => {
          self.write(width.to_string())
          self.write("'")

          let base_prefix = match base {
            2 => 'b'
            8 => 'o'
            10 => 'd'
            16 => 'h'
            _ => '?'
          }

          self.builder.write_char(base_prefix)
          self.write(@utils.show_nat(value, base~, width=Some(width)))
        }
        None => {
          self.write(@utils.show_nat(value, base~, width=None))
        }
      }
    }
    Identifier(path~, ..) => {
      self.write(path.to_string())
    }
    String(value=str, ..) => {
      self.write("\"")
      self.write(str)
      self.write("\"")
    }
    Unary(op~, expr~, ..) => {
      self.write("(")
      self.write(op.to_string())
      self.write(" ")
      self.emit_expr(expr)
      self.write(")")
    }
    Binary(op~, lhs~, rhs~, ..) => {
      self.write("(")
      self.emit_expr(lhs)
      self.write(" ")
      self.write(op.to_string())
      self.write(" ")
      self.emit_expr(rhs)
      self.write(")")
    }
    Indexing(expr~, index~, ..) => {
      self.emit_expr(expr)
      self.write("[")
      self.emit_expr(index)
      self.write("]")
    }
    Slicing(expr~, hi=msb, lo=lsb, kind~, ..) => {
      self.emit_expr(expr)
      self.write("[")
      self.emit_expr(msb)
      self.write(match kind { Absolute => ":"; Width => "-:" })
      self.emit_expr(lsb)
      self.write("]")
    }
    FieldAccess(expr~, field=port, ..) => {
      self.emit_expr(expr)
      self.write(".")
      self.write(port)
    }
    Instance(path~, params~, ports~, ..) => {
      self.write(path.to_string())

      if params.params.length() > 0 {
        self.write("<")

        for i, param in params.params {
          if i > 0 {
            self.write(", ")
          }

          match param {
            Expr(name~, value~) => {
              match name {
                Some(name) => {
                  self.write(name)
                  self.write(": ")
                }
                None => ()
              }

              self.emit_expr(value)
            }
            Type(name~, value~, ..) => {
              match name {
                Some(name) => {
                  self.write(name)
                  self.write(": ")
                }
                None => ()
              }

              self.write(value.to_string())
            }
          }
        }

        self.write(">")
      }

      self.write("(")

      let wrap = ports.size() > 2

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
        self.emit_expr(expr)

        if wrap || i < ports.size() - 1 {
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

        self.emit_expr(elem)
      }

      self.indent -= 1
      self.write("]")
    }
    Spread(expr~, ..) => {
      self.write("...")
      self.emit_expr(expr)
    }
    Ternary(cond~, then~, else_~, ..) => {
      self.write("(")
      self.emit_expr(cond)
      self.write(" ? ")
      self.emit_expr(then)
      self.write(" : ")
      self.emit_expr(else_)
      self.write(")")
    }
    Match(subject~, cases~, default~, ..) => {
      self.write("match ")
      self.emit_expr(subject)
      self.write(" {\n")
      self.indent += 1

      for case in cases {
        let (value, expr) = case
        self.write_indent()
        self.emit_expr(value)
        self.write(" => ")
        self.emit_expr(expr)
        self.write(",\n")
      }

      match default {
        Some(expr) => {
          self.write_indent()
          self.write("_ => ")
          self.emit_expr(expr)
          self.write(",\n")
        }
        None => ()
      }

      self.indent -= 1
      self.write_indent()
      self.write("}")
    }
    Tuple(elems~, ..) => {
      self.write("(")
      self.indent += 1

      for i, elem in elems {
        if i > 0 {
          self.write(", ")
        }

        self.emit_expr(elem)
      }

      self.indent -= 1
      self.write(")")
    }
    Replicate(expr~, count~, concat~, ..) => {
      self.emit_expr(count)
      self.write("*")
      self.write(if concat { "{" } else { "[" })
      self.emit_expr(expr)
      self.write(if concat { "}" } else { "]" })
    }
    FunCall(name~, args~, ..) => {
      self.write(name)
      self.write("(")

      for i, arg in args {
        if i > 0 {
          self.write(", ")
        }

        self.emit_expr(arg)
      }

      self.write(")")
    }
    Struct(fields~, ..) => {
      let is_tuple = fields.contains("0") && fields.contains("1")

      if is_tuple {
        self.write("(")

        fields.values().eachi(fn(idx, elem) {
          if idx > 0 {
            self.write(", ")
          }

          self.emit_expr(elem)
        })

        self.write(")")
      } else {
        self.write("{\n")
        self.indent += 1

        for field in fields {
          let (name, expr) = field
          self.write_indent()
          self.write(name)
          self.write(": ")
          self.emit_expr(expr)
          self.write(",\n")
        }

        self.indent -= 1
        self.write_indent()
        self.write("}")
      }
    }
    Block(body~, last~, ..) => {
      self.write("{\n")
      self.indent += 1

      for stmt in body {
        self.emit_stmt(stmt)
        self.write("\n")
      }

      match last {
        Some(expr) => {
          self.write_indent()
          self.emit_expr(expr)
          self.write(";\n")
        }
        None => ()
      }

      self.indent -= 1
      self.write_indent()
      self.write("}")
    }
    If(cond~, then~, else_~, span=_, ty=_) => {
      self.write("if ")
      self.emit_expr(cond)
      self.write(" ")
      self.emit_expr(then)
      self.write("\n")

      match else_ {
        Some(else_) => {
          self.write_indent()
          self.write("else ")
          self.emit_expr(else_)
        }
        None => ()
      }
    }
  }

  if self.show_expr_types {
    match expr.ty().val {
      Some(ty) => self.write(": \{ty})")
      None => ()
    }
  }
}

fn emit_const_decl(self: AstEmitter, decl: ConstDecl) -> Unit {
  self.write("const ")
  self.write(decl.path.to_string())

  match decl.ty {
    Some(ty) => {
      self.write(": ")
      self.write(ty.to_string())
    }
    None => ()
  }

  self.write(" = ")
  self.emit_expr(decl.expr)
  self.write(";")
}

fn emit_package_decl(self: AstEmitter, decl: PackageDecl) -> Unit {
  self.emit("package ")
  self.write(decl.name)
  self.write(" {\n")
  self.indent += 1

  for decl in decl.body {
    self.emit_decl(decl)
    self.write("\n")
  }

  self.indent -= 1
  self.write("}")
}

pub fn emit_stmt(self: AstEmitter, stmt: Stmt) -> Unit {
  self.write_indent()

  match stmt {
    Expr(expr~, ..) => {
      self.emit_expr(expr)
      self.write(";")
    }
    Let(name~, ty~, expr~, ..) => {
      self.write("let \{name}")

      match ty.val {
        Some(ty) => {
          self.write(": ")
          self.write(ty.to_string())
        }
        None => ()
      }

      match expr {
        Some(expr) => {
          self.write(" = ")
          self.emit_expr(expr)
        }
        None => ()
      }

      self.write(";")
    }
    Assign(lhs~, rhs~, ..) => {
      self.emit_expr(lhs)
      self.write(" = ")
      self.emit_expr(rhs)
      self.write(";")
    }
    For(var~, range~, body~, ..) => {
      self.write("\n")
      self.write_indent()
      self.write("for ")
      self.write(var)
      self.write(" in ")
      self.emit_expr(range.start)
      self.write(if range.inclusive { "..=" } else { "..<" })
      self.emit_expr(range.end)

      self.indent += 1
      self.write(" {\n")
      
      for i, stmt in body {
        if i > 0 {
          self.write("\n")
        }
        
        self.emit_stmt(stmt)
      }

      self.write("\n")
      self.indent -= 1
      self.write_indent()
      self.write("}\n")
    }
    Scope(body~, ..) => {
      self.write("{\n")
      self.indent += 1

      for stmt in body {
        self.emit_stmt(stmt)
        self.write("\n")
      }

      self.indent -= 1
      self.write_indent()
      self.write("}")
    }
    Const(decl~, ..) => {
      self.emit_const_decl(decl)
    }
  }
}

struct StructField {
  name: String
  ty: Type
}

impl Show for StructField with output(field, logger) {
  logger.write_string(field.name)
  logger.write_string(": ")
  logger.write_string(field.ty.to_string())
}

impl Show for IntParam with output(param, logger) {
  match param {
    Fixed(n) => {
      logger.write_string(n.to_string())
    }
    Dynamic(expr) => {
      let emitter = AstEmitter::new()
      emitter.emit_expr(expr)
      logger.write_string(emitter.to_string())
    }
  }
}

pub impl Show for Type with output(ty, logger) {
  match ty {
    Nat(_) => {
      logger.write_string("nat")
    }
    UInt(width) => {
      logger.write_string("uint<\{width}>")
    }
    SInt(width) => {
      logger.write_string("sint<\{width}>")
    }
    Vector(ty~, len~) => {
      logger.write_string(ty.to_string())
      logger.write_char('[')
      logger.write_object(len)
      logger.write_char(']')
    }
    Instance(sig={ path, .. }, params~, accessed_ports~) => {
      logger.write_object(path)

      if params.size() > 0 {
        logger.write_iter(
          params.values(),
          prefix="<",
          sep=", ",
          suffix=">",
        )
      }

      if show_instance_accessed_ports {
        logger.write_iter(
          prefix=".[",
          { let ports = accessed_ports.iter().collect(); ports.sort(); ports.iter() },
          suffix="]",
          sep=", ",
        )
      }
    }
    Name(path~, params~) => {
      logger.write_object(path)

      if params.length() > 0 {
        logger.write_iter(
          params.iter(),
          prefix="<",
          sep=", ",
          suffix=">",
        )
      }
    }
    Struct(fields) => {
      let is_tuple = fields.contains("0") && fields.contains("1")

      if is_tuple {
        logger.write_iter(
          prefix="(",
          fields.values(),
          sep=", ",
          suffix=")",
        )
      } else {
        logger.write_iter(
          prefix="{ ",
          fields.iter().map(fn(field) {
            let (name, ty) = field
            { name, ty }
          }),
          sep=", ",
          suffix=" }",
        )
      }
    }
    String(len~) => {
      logger.write_string("string<\{len}>")
    }
  }
}

pub impl Show for Port with output(port, logger) {
  logger.write_string(port.name)

  if port.optional {
    logger.write_string("?")
  }

  logger.write_string(": ")

  for attr in port.attributes.values() {
    logger.write_string(attr.to_string())
    logger.write_char(' ')
  }

  logger.write_string(port.ty.to_string())
}

fn emit_port_list(self: AstEmitter, ports: Iter[Port]) -> Unit {
  self.write("(\n")
  self.indent += 1

  for port in ports {
    self.write_indent()
    self.write(port.to_string())
    self.write(",\n")
  }

  self.indent -= 1

  self.emit(")")
}

pub impl Show for AttributeValue with output(val, logger) {
  match val {
    String(str) => {
      logger.write_char('"')
      logger.write_string(str)
      logger.write_char('"')
    }
    Int(n) => {
      logger.write_string(n.to_string())
    }
  }
}

pub impl Show for Attribute with output(attr, logger) {
  logger.write_char('@')
  logger.write_string(attr.name)
  if attr.args.length() > 0 {
    logger.write_iter(
      attr.args.iter(),
      prefix="(",
      sep=", ",
      suffix=")",
    )
  }
}

pub impl Show for ModuleParameter with output(param, logger) {
  logger.write_string(param.name)
  logger.write_string(": ")
  logger.write_object(param.ty)
}

fn emit_module_sig(self: AstEmitter, sig: ModuleSignature) -> Unit {
  if sig.attributes.size() > 0 {
    for attr in sig.attributes.values() {
      self.emit(attr.to_string())
      self.write("\n")
    }
  }

  self.emit("module ")
  self.write(sig.path.to_string())

  if sig.params.length() > 0 {
    self.write("<")
    self.write(String::concat(sig.params.map(Show::to_string), separator=", "))
    self.write(">")
  }

  self.emit_port_list(sig.inputs() + sig.inouts())
  self.write(" -> ")
  self.emit_port_list(sig.outputs())
}

pub fn emit_decl(self: AstEmitter, decl: Decl) -> Unit {
  match decl {
    Module({ body, .. } as mod) => {
      self.emit_module_sig(mod.signature())
      self.write(" {\n")
      self.indent += 1

      for stmt in body {
        self.emit_stmt(stmt)
        self.write("\n")
      }

      self.indent -= 1
      self.emit("}")
    }
    ModuleDeclaration(sig) => {
      self.emit_module_sig(sig)
    }
    Const(decl) => {
      self.emit_const_decl(decl)
    }
    Package(decl) => {
      self.emit_package_decl(decl)
    }
    Import({ packages, span: _ }) => {
      self.write("import ")
      self.write(String::concat(packages, separator="::"))
    }
  }
}

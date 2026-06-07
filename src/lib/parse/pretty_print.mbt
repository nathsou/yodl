
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

pub fn AstEmitter::emit(self: AstEmitter, s: String) -> Unit {
  self.builder.write_string("  ".repeat(self.indent) + s)
}

pub fn AstEmitter::write_indent(self: AstEmitter) -> Unit {
  self.builder.write_string("  ".repeat(self.indent))
}

pub fn AstEmitter::write(self: AstEmitter, s: String) -> Unit {
  self.builder.write_string(s)
}

pub impl Show for UnaryOp with output(op, logger) {
  logger.write_string(match op {
    Not => "not"
    Neg => "-"
    Andr => "andr"
    Orr => "orr"
    Xorr => "xorr"
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

pub impl Show for ConstValue with output(value, logger) {
  match value {
    Natural(value~, width~, base~, span=_) => {
      logger.write_string(show_natural(value~, base~, width~))
    }
    String(value~, ..) => {
      logger.write_string(value)
    }
  }
}

pub impl Show for ResolvedParam with output(param, logger) {
  match param {
    NatParam(value~, span=_) => {
      logger.write_string(value.to_string())
    }
    TypeParam(ty~, span=_) => {
      logger.write_string(ty.to_string())
    }
  }
}

pub impl Show for UnresolvedParam with output(param, logger) {
  logger.write(param.text)
}

pub impl Show for Param with output(param, logger) {
  match param {
    Unresolved(param) => {
      logger.write_string(param.to_string())
    }
    Resolved(param) => {
      logger.write_string(param.to_string())
    }
  }
}

pub fn show_natural(value~: BigInt, base~: Int, width~: Int?) -> String {
  match width {
    Some(width) => {
      let builder = StringBuilder::new()
      builder.write_string(width.to_string())
      builder.write_char('\'')

      let base_prefix = match base {
        2 => 'b'
        8 => 'o'
        10 => 'd'
        16 => 'h'
        _ => '?'
      }

      builder.write_char(base_prefix)
      builder.write_string(@utils.show_nat(value, base~, width=Some(width)))
      builder.to_string()
    }
    None => {
      @utils.show_nat(value, base~, width=None)
    }
  }
}

pub fn AstEmitter::emit_expr(self: AstEmitter, expr: Expr, indent~: Bool = false) -> Unit {
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

        for i, entry in params.params {
          if i > 0 {
            self.write(", ")
          }

          let (name, param) = entry

          if name is Some(name) {
            self.write(name)
            self.write(": ")
          }

          self.write(param.to_string())
        }

        self.write(">")
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
        self.emit_expr(expr)

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

        self.emit_expr(elem)
      }

      self.indent -= 1
      self.write("]")
    }
    Spread(expr~, ..) => {
      self.write("..")
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
    FunCall(name~, args~, ..) => {
      self.write(name)
      self.write("!(")

      for i, arg in args {
        if i > 0 {
          self.write(", ")
        }

        self.emit_expr(arg)
      }

      self.write(")")
    }
    Struct(fields~, ..) => {
      // Detect a positional record: keys are "0", "1", ..., "n-1" contiguously.
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
          self.emit_expr(fields.get(i.to_string()).unwrap())
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
            self.emit_expr(expr)
          } else {
            self.write(name)
            self.write(": ")
            self.emit_expr(expr)
          }
        }

        self.write(")")
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

fn AstEmitter::emit_const_decl(self: AstEmitter, decl: ConstDecl) -> Unit {
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

fn AstEmitter::emit_package_decl(self: AstEmitter, decl: PackageDecl) -> Unit {
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

pub fn AstEmitter::emit_stmt(self: AstEmitter, stmt: Stmt) -> Unit {
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
    For(variable~, range~, body~, ..) => {
      self.write("\n")
      self.write_indent()
      self.write("for ")
      self.write(variable)
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

priv struct StructField {
  name: String
  ty: Type
}

impl Show for StructField with output(field, logger) {
  logger.write_string(field.name)
  logger.write_string(": ")
  logger.write_string(field.ty.to_string())
}

fn index_expr_prec(expr: IndexExpr) -> Int {
  match expr {
    Lit(_) | Var(_) | Clog2(_) | CDiv(_, _) => 3
    Mul(_, _) => 2
    Add(_, _) | Sub(_, _) => 1
  }
}

fn write_index_expr_child(expr: IndexExpr, logger: &Logger, min_prec: Int) -> Unit {
  if index_expr_prec(expr) < min_prec {
    logger.write_char('(')
    logger.write_object(expr)
    logger.write_char(')')
  } else {
    logger.write_object(expr)
  }
}

pub impl Show for IndexExpr with output(self, logger) {
  match self {
    Lit(n) => logger.write_string(n.to_string())
    Var(name) => logger.write_string(name)
    Add(a, b) => {
      // Add is left-associative; no children need wrapping at prec 1
      write_index_expr_child(a, logger, 1)
      logger.write_string(" + ")
      write_index_expr_child(b, logger, 1)
    }
    Sub(a, b) => {
      write_index_expr_child(a, logger, 1)
      logger.write_string(" - ")
      // Right child of Sub needs parens when it is Add or Sub (prec <= 1),
      // since a - (b + c) ≠ a - b + c
      write_index_expr_child(b, logger, 2)
    }
    Mul(a, b) => {
      // Both children need parens when they are Add or Sub (prec < 2)
      write_index_expr_child(a, logger, 2)
      logger.write_string(" * ")
      write_index_expr_child(b, logger, 2)
    }
    Clog2(a) => {
      logger.write_string("clog2!(")
      logger.write_object(a)
      logger.write_char(')')
    }
    CDiv(a, b) => {
      logger.write_string("cdiv!(")
      logger.write_object(a)
      logger.write_string(", ")
      logger.write_object(b)
      logger.write_char(')')
    }
  }
}

pub impl Show for Type with output(ty, logger) {
  match ty {
    Nat({min_width}) => {
      logger.write_string("nat<\{min_width}>")
    }
    UInt(width) => {
      logger.write_string("uint<\{width}>")
    }
    SInt(width) => {
      logger.write_string("sint<\{width}>")
    }
    Clock => {
      logger.write_string("clock")
    }
    Vector(ty~, len~) => {
      logger.write_string(ty.to_string())
      logger.write_char('[')
      logger.write_object(len)
      logger.write_char(']')
    }
    Instance(sig={ path, .. }, params~, accessed_ports~) => {
      logger.write_object(path)

      if params.length() > 0 {
        logger.write_iter(
          params.values(),
          prefix="<",
          sep=", ",
          suffix=">",
        )
      }

      if show_instance_accessed_ports {
        logger.write_char('.')
        logger.write_object(accessed_ports)
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
      let n = fields.length()
      let mut is_positional = n > 0

      for i in 0..<n {
        if !fields.contains(i.to_string()) {
          is_positional = false
          break
        }
      }

      if n == 0 {
        logger.write_string("()")
      } else if is_positional {
        logger.write_char('(')
        for i in 0..<n {
          if i > 0 {
            logger.write_string(", ")
          }
          logger.write_object(fields.get(i.to_string()).unwrap())
        }
        if n == 1 {
          logger.write_char(',')
        }
        logger.write_char(')')
      } else {
        logger.write_iter(
          prefix="(",
          fields.iter().map(fn(field) {
            let (name, ty) = field
            { name, ty }
          }),
          sep=", ",
          suffix=")",
        )
      }
    }
    String(len~) => {
      logger.write_string("string<\{len}>")
    }
    MemoryMask(ty) => {
      logger.write_string("MemoryMask<\{ty}>")
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

fn AstEmitter::emit_port_list(self: AstEmitter, ports: Iter[Port]) -> Unit {
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
    Dict(dict) => {
      logger.write_char('{')
      let mut first = true

      for key, value in dict {
        if !first {
          logger.write_string(", ")
        }
        first = false

        logger.write_string(key)
        logger.write_string(": ")
        logger.write_string(value.to_string())
      }

      logger.write_char('}')
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
  logger.write_object(param.sort)
}

fn AstEmitter::emit_module_sig(self: AstEmitter, sig: ModuleSignature) -> Unit {
  if sig.attributes.length() > 0 {
    for attr in sig.attributes.values() {
      self.emit(attr.to_string())
      self.write("\n")
    }
  }

  self.emit("module ")
  self.write(sig.path.to_string())

  if sig.params.length() > 0 {
    self.write("<")
    self.write(sig.params.map(Show::to_string).join(", "))
    self.write(">")
  }

  self.emit_port_list(sig.inputs() + sig.inouts())
  self.write(" -> ")
  self.emit_port_list(sig.outputs())
}

pub fn AstEmitter::emit_decl(self: AstEmitter, decl: Decl) -> Unit {
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
      self.write(packages.join("::"))
    }
    TypeAlias({ name, parameters, ty, span: _ }) => {
      self.write("type \{name}")
      
      if parameters.length() > 0 {
        self.write("<")
        self.write(parameters.map(fn(p) {
          match p.sort {
            NatSort => "\{p.name}: Nat"
            TypeSort => p.name
          }
        }).join(", "))
        self.write(">")
      }

      self.write(" = \{ty};")
    }
  }
}

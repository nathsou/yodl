
struct Emitter {
  mut indent: Int
  builder: StringBuilder
}

pub fn Emitter::new() -> Emitter {
  { indent: 0, builder: StringBuilder::new() }
}

pub impl Show for Emitter with output(self, logger) {
  logger.write_string(self.builder.to_string())
}

fn emit(self: Emitter, s: String) -> Unit {
  self.builder.write_string("  ".repeat(self.indent) + s + "\n")
}

fn write_indent(self: Emitter) -> Unit {
  self.builder.write_string("  ".repeat(self.indent))
}

fn write(self: Emitter, s: String) -> Unit {
  self.builder.write_string(s)
}

pub impl Show for UnaryOp with output(op, logger) {
  logger.write_string(match op {
    LogicalNot => "not"
    Complement => "~"
  })
}

pub impl Show for BinaryOp with output(op, logger) {
  logger.write_string(match op {
    And => "and"
    Or => "or"
    Xor => "xor"
    Nand => "nand"
    Nor => "nor"
    Xnor => "xnor"
  })
}

pub fn emit_expr(self: Emitter, expr: Expr, indent~: Bool = false) -> Unit {
  if indent {
    self.write_indent()
  }

  match expr {
    Natural(value~, ..) => {
      self.write(value.to_string())
    }
    Identifier(name~, ..) => {
      self.write(name)
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
  }
}

pub fn emit_stmt(self: Emitter, stmt: Stmt) -> Unit {
  self.write_indent()

  match stmt {
    Let(name~, expr~, ..) => {
      self.write("let ")
      self.write(name)
      self.write(" = ")
      self.emit_expr(expr)
      self.write(";")
    }
    Assign(name~, expr~, ..) => {
      self.write(name)
      self.write(" = ")
      self.emit_expr(expr)
      self.write(";")
    }
  }
}

pub impl Show for Type with output(ty, logger) {
  match ty {
    Logic => {
      logger.write_string("logic")
    }
    Vector(ty~, len~) => {
      logger.write_string(ty.to_string())
      logger.write_char('[')
      logger.write_string(len.to_string())
      logger.write_char(']')
    }
  }
}

pub impl Show for Port with output(port, logger) {
  logger.write_string(port.name)
  logger.write_string(": ")
  logger.write_string(port.ty.to_string())
}

fn emit_port_list(self: Emitter, ports: Array[Port]) -> Unit {
  self.write("(\n")
  self.indent += 1

  for port in ports {
    self.write_indent()
    self.write(port.to_string())
    self.write(",\n")
  }

  self.indent -= 1

  self.write(")")
}

pub fn emit_decl(self: Emitter, decl: Decl) -> Unit {
  match decl {
    Module(name~, inputs~, outputs~, body~, ..) => {
      self.write("module ")
      self.write(name)
      self.write(" ")
      self.emit_port_list(inputs)
      self.write(" -> ")
      self.emit_port_list(outputs)
      self.write(" {\n")
      self.indent += 1

      for stmt in body {
        self.emit_stmt(stmt)
        self.write("\n")
      }

      self.indent -= 1
      self.write("}")
    }
  }
}


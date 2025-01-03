
pub struct VerilogEmitter {
  mut indent: Int
  builder: StringBuilder
}

pub fn VerilogEmitter::new() -> VerilogEmitter {
  { indent: 0, builder: StringBuilder::new() }
}

pub impl Show for VerilogEmitter with output(self, logger) {
  logger.write_string(self.builder.to_string())
}

impl Logger for VerilogEmitter with write_string(self, s) {
  self.builder.write_string(s)
}

impl Logger for VerilogEmitter with write_char(self, c) {
  self.builder.write_char(c)
}

impl Logger for VerilogEmitter with write_substring(self, str, start, end) {
  self.write_string(str.substring(start~, end~))
}

pub fn emit(self: VerilogEmitter, s: String) -> Unit {
  self.builder.write_string("  ".repeat(self.indent) + s + "\n")
}

pub fn write_indent(self: VerilogEmitter) -> Unit {
  self.builder.write_string("  ".repeat(self.indent))
}

pub fn write(self: VerilogEmitter, s: String) -> Unit {
  self.builder.write_string(s)
}

pub fn write_iter[T: Show](
  self: VerilogEmitter,
  iter: Iter[T],
  prefix~: String,
  suffix~: String,
  sep~: String,
  trailing~: Bool = false,
  indent~: Bool = false
) -> Unit {
  self.write(prefix)

  if trailing {
    for x in iter {
      if indent {
        self.write_indent()
      }

      self.builder.write_object(x)
      self.write(sep)
    }
  } else {
    let mut first = true

    for x in iter {
      if first {
        first = false
      } else {
        self.write(sep)
      }

      if indent {
        self.write_indent()
      }

      self.builder.write_object(x)
    }
  }
  self.write(suffix)
}

fn show_binary_digit(digit: @parse.BinaryDigit, is_case_expr~: Bool = false) -> Char {
  match digit {
    Zero => '0'
    One => '1'
    X => 'x'
    Z => 'z'
    M => 'm'
    DontCare => if is_case_expr { '?' } else { '-' }
  }
}

impl Show for FunctionArgument with output(self, logger) {
  logger.write_string("\{self.direction} [\{self.width - 1}:0] \{self.name};")
}

fn show_expr(expr: Expr, logger: &Logger, is_case_expr~: Bool = false) -> Unit {
  match expr {
    Identifier(name) => logger.write_string(name)
    Const(constant) => {
      match constant {
        ConstInteger(value) => logger.write_string(value.to_string())
        ConstValue(width~, bits~) => {
          logger.write_string("\{width}'b")

          for d in bits {
            logger.write_char(show_binary_digit(d, is_case_expr~))
          }
        }
        ConstString(value) => logger.write_string("\"" + value + "\"")
      }
    }
    BitSelect(expr~, offset~) => {
      logger.write_string("\{expr}[\{offset}]")
    }
    PartSelect(expr~, offset~, width~) => {
      logger.write_string("\{expr}[\{offset}:\{(offset + 1) - width}]")
    }
    Concat(exprs) => {
      logger.write_iter(exprs.iter(), prefix="{", suffix="}", sep=", ")
    }
    Unary(op~, expr~) => {
      let op = match op {
        Not => "~"
      }

      logger.write_string("\{op}\{expr}")
    }
    Binary(op~, lhs~, rhs~) => {
      let op = match op {
        And => "&"
        Or => "|"
        Xor => "^"
        Nand => "~&"
        Nor => "~|"
        Xnor => "~^"
        Add => "+"
        Sub => "-"
        Mul => "*"
        Div => "/"
        Mod => "%"
        Equ => "=="
        Neq => "!="
        Gtr => ">"
        Lss => "<"
        Geq => ">="
        Leq => "<="
        Shl => "<<"
        Shr => ">>"
        Ternary => "?"
      }

      logger.write_string("\{lhs} \{op} \{rhs}")
    }
    Ternary(cond~, then~, else_~) => {
      logger.write_string("\{cond} ? \{then} : \{else_}")
    }
    FunctionCall(name~, args~) => {
      logger.write_string(name)
      logger.write_iter(args.iter(), prefix="(", suffix=")", sep=", ")
    }
  }
}

pub impl Show for Expr with output(self, logger) {
  show_expr(self, logger, is_case_expr=false)
}

pub impl Show for SensitivityListItem with output(self, logger) {
  match self.polarity {
    Some(Posedge) => logger.write_string("posedge ")
    Some(Negedge) => logger.write_string("negedge ")
    None => ()
  }

  logger.write_string(self.signal)
}

pub impl Show for Port with output(self, logger) {
  match self.width {
    1 => logger.write_string("\{self.direction} \{self.name}")
    _ => logger.write_string("\{self.direction} [\{self.width - 1}:0] \{self.name}")
  }
}

struct Parameter {
  name: String
  value: @rtlil.Constant
}

impl Show for Parameter with output(self, logger) {
  logger.write_string(".\{self.name}(\{self.value})")
}

fn emit_expr(self: VerilogEmitter, expr: Expr) -> Unit {
  self.write(expr.to_string())
}

fn emit_stmt(self: VerilogEmitter, stmt: Stmt) -> Unit {
  match stmt {
    WireDecl(name~, msb~, lsb~, init~) | RegDecl(name~, msb~, lsb~, init~) => {
      let decl_type = match stmt { WireDecl(_) => "wire"; _ => "reg" }
      self.write_indent()

      if msb == lsb {
        self.write("\{decl_type} \{name}")
      } else {
        self.write("\{decl_type} [\{msb}:\{lsb}] \{name}")
      }

      match init {
        Some(init) => {
          self.write(" = ")
          self.emit_expr(init)
        }
        None => ()
      }

      self.write(";\n")
    }
    Assign(lhs~, rhs~, kind~) => {
      self.write_indent()

      match kind {
        Continous => {
          self.write("assign ")
          self.emit_expr(lhs)
          self.write(" = ")
          self.emit_expr(rhs)
          self.write(";\n")
        }
        Blocking | NonBlocking => {
          self.emit_expr(lhs)
          self.write(if kind == Blocking { " = " } else { " <= " })
          self.emit_expr(rhs)
          self.write(";")
        }
      }
    }
    If(cond~, then~, else_~) => {
      self.write_indent()
      self.write("if (\{cond}) ")
      self.emit_stmt(then)

      match else_ {
        Some(else_) => {
          self.write_indent()
          self.write("else ")
          self.emit_stmt(else_)
        }
        None => ()
      }
    }
    Casez(cond~, cases~, default~) => {
      self.emit("casez (\{cond})")
      self.indent += 1

      for case in cases {
        let (case_cond, case_body) = case
        self.write_indent()
        show_expr(case_cond, self, is_case_expr=true)
        self.write(":\n")
        self.indent += 1
        self.emit_stmt(case_body)
        self.write("\n")
        self.indent -= 1
      }

      match default {
        Some(default) => {
          self.emit("default:")
          self.indent += 1
          self.emit_stmt(default)
          self.indent -= 1
        }
        None => ()
      }

      self.indent -= 1
      self.write("\n")
      self.emit("endcase")
    }
    Instance(mod~, name~, parameters~, ports~) => {
      self.write_indent()
      self.write(mod)
      self.indent += 1

      if parameters.length() > 0 {
        self.write_iter(
          parameters.iter().map(fn(p) { { name: p.0, value: p.1 } }),
          prefix=" #(",
          suffix=")",
          sep=", ",
        )
      }

      self.write(" \{name} (\n")
      
      for index, port in ports {
        let (port, val) = port
        self.write_indent()
        self.write(".\{port}(\{val})")
        
        if index < (ports.length() - 1) {
          self.write(",")
        }

        self.write("\n")
      }

      self.indent -= 1
      self.emit(");")
    }
    Block(body) => {
      self.write("begin\n")
      self.indent += 1

      for stmt in body {
        self.emit_stmt(stmt)
      }

      self.indent -= 1
      self.write("\n")
      self.emit("end")
    }
    Always(sensitivity_list~, body~) => {
      self.write_indent()
      self.write("always @")
      self.write_iter(sensitivity_list.iter(), prefix="(", suffix=") ", sep=", ")
      self.emit_stmt(body)
    }
    FunctionDecl(name~, output_width~, args~, body~) => {
      self.write_indent()
      self.write("function [\{output_width - 1}:0] \{name};\n")
      self.indent += 1
      
      for arg in args {
        self.write_indent()
        self.write(arg.to_string())
        self.write("\n")
      }

      self.emit_stmt(body)
      self.indent -= 1
      self.write_indent()
      self.write("endfunction\n")
    }
  }
}

fn emit_decl(self: VerilogEmitter, decl: Decl) -> Unit {
  match decl {
    Module({ name, ports, body }) => {
      self.emit("module \{name}(")
      self.indent += 1
      self.write_iter(ports.iter(), prefix="", suffix="", sep=",\n", indent=true)
      self.indent -= 1
      self.emit("\n);")

      self.indent += 1

      for stmt in body {
        self.emit_stmt(stmt)
      }

      self.indent -= 1

      self.emit("endmodule\n")
    }
  }
}

pub fn emit_decls(self: VerilogEmitter, decls: Array[Decl]) -> Unit {
  for decl in decls {
    self.emit_decl(decl)
  }
}


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
fn show_expr(expr: Expr, logger: &Logger) -> Unit {
  match expr {
    Identifier(name) => logger.write_string(name)
    Const(c) => {
      match c.width { 
        32 => logger.write_string(c.bits.as_bigint?().unwrap().to_string())
        _ => logger.write_object(c)
      }
    }
    PartSelect(expr~, offset~, width~) => {
      match offset {
        Const(offset) => {
          let offset = offset.bits.as_int?().unwrap()
          let msb = (offset + 1) - width
          let lsb = offset

          if msb == lsb {
            logger.write_string("\{expr}[\{offset}]")
          } else {
            logger.write_string("\{expr}[\{lsb}:\{msb}]")
          }
        }
        _ => {
          match width {
            1 => logger.write_string("\{expr}[\{offset}]")
            _ => {
              logger.write_string("\{expr}[\{offset} +: \{width}]")
            }
          }
        }
      }
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

      logger.write_string("(\{lhs} \{op} \{rhs})")
    }
  }
}

pub impl Show for Expr with output(self, logger) {
  show_expr(self, logger)
}

pub impl Show for SensitivityListEvent with output(self, logger) {
  match self.polarity {
    Some(Posedge) => logger.write_string("posedge ")
    Some(Negedge) => logger.write_string("negedge ")
    None => ()
  }

  logger.write_object(self.signal)
}

pub impl Show for PortType with output(self, logger) {
  match self {
    Wire => logger.write_string("wire")
    Reg => logger.write_string("reg")
  }
}

pub impl Show for Port with output(self, logger) {
  match self.width {
    1 => logger.write_string("\{self.direction} \{self.type_} \{self.name}")
    _ => logger.write_string("\{self.direction} \{self.type_} [\{self.width - 1}:0] \{self.name}")
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
    Expr(expr~) => {
      self.write_indent()
      self.emit_expr(expr)
      self.write(";\n")
    }
    WireDecl(name~, top=msb, bot=lsb, init~) | RegDecl(name~, top=msb, bot=lsb, width=_, init~) => {
      let decl_type = match stmt { WireDecl(_) => "wire"; _ => "reg" }
      self.write_indent()

      let width = match stmt {
        RegDecl(width~, ..) => width
        _ => 1
      }

      fn pos(n: Int) -> Int {
        @math.maximum(n, 0)
      }

      match (width, msb == lsb) {
        (1, true) => self.write("\{decl_type} \{name}")
        (1, false) => self.write("\{decl_type} [\{pos(msb)}:\{lsb}] \{name}")
        (_, true) => self.write("\{decl_type} [\{pos(width - 1)}:0] \{name}")
        (_, false) => self.write("\{decl_type} [\{pos(width - 1)}:0] \{name} [\{msb}:\{lsb}]")
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
          self.write(";\n")
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
        show_expr(case_cond, self)
        self.write(": ")
        self.indent += 1
        self.emit_stmt(case_body)
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
      self.emit("end")
    }
    Always(sensitivity_list~, body~) => {
      self.write_indent()
      self.write("always @")
      
      match sensitivity_list {
        All => self.write("(*) ")
        Events(events) => self.write_iter(events.iter(), prefix="(", suffix=") ", sep=" or ")
      }

      self.emit_stmt(body)
    }
    Initial(body~) => {
      self.write_indent()
      self.write("initial ")
      self.emit_stmt(body)
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


pub type YirEmitter @utils.Emitter

pub fn YirEmitter::new() -> YirEmitter {
  YirEmitter(@utils.Emitter::new())
}

pub impl Show for Const with output(self, logger) {
  let base = match self.base {
    2 => 'b'
    8 => 'o'
    10 => 'd'
    16 => 'h'
    _ => '?'
  }

  match self.bits.value {
    Some(value) => logger.write_string("\{self.width}'\{base}" + @utils.show_nat(value, base=self.base, width=Some(self.width)))
    None => logger.write_string("\{self.width}'\{base}\{self.bits}")
  }
}

pub fn emit_expr(self: YirEmitter, expr: Expr) -> Unit {
  match expr {
    Const(value~, ..) => {
      self._.write(value)
    }
    Variable(name~, ..) => {
      self._.write(name)
    }
    Unary(op~, expr~, ..) => {
      self._.write(op)
      self._.write("(")
      self.emit_expr(expr)
      self._.write(")")
    }
    Binary(lhs~, op~, rhs~, ..) => {
      self._.write("(")
      self.emit_expr(lhs)
      self._.write(" ")
      self._.write(op)
      self._.write(" ")
      self.emit_expr(rhs)
      self._.write(")")
    }
    Concat(elems~, ..) => {
      self._.write("{")

      for idx, elem in elems {
        self.emit_expr(elem)
        if idx < elems.length() - 1 {
          self._.write(", ")
        }
      }

      self._.write("}")
    }
    Select(expr~, offset~, width~, ..) => {
      self.emit_expr(expr)
      self._.write("[")
      match width {
        1 => self._.write(offset)
        _ => {
          let msb = offset
          let lsb = offset - width + 1
          self._.write("\{msb}:\{lsb}")
        }
      }
      self._.write("]")
    }
    Mux(subject~, cases~, default~, ..) => {
      self._.write("mux ")
      self.emit_expr(subject)
      self._.write(" {\n")
      self._.indent += 1

      for case in cases {
        let (cond, value) = case
        self._.write_indent()
        self._.write(cond)
        self._.write(" => ")
        self.emit_expr(value)
        self._.write(",\n")
      }

      match default {
        Some(value) => {
          self._.write_indent()
          self._.write("default: ")
          self.emit_expr(value)
          self._.write(",\n")
        }
        None => ()
      }

      self._.indent -= 1
      self._.write_indent()
      self._.write("}")
    }
    Block(body~, last~, ..) => {
      self._.write("{\n")
      self._.indent += 1

      for stmt in body {
        self.emit_stmt(stmt)
      }

      match last {
        Some(expr) => {
          self._.write_indent()
          self.emit_expr(expr)
          self._.write("\n")
        }
        None => ()
      }

      self._.indent -= 1
      self._.write_indent()
      self._.write("}")
    }
    FunCall(name~, args~, ..) => {
      self._.write("$\{name}(")

      for idx, arg in args {
        self.emit_expr(arg)
        if idx < args.length() - 1 {
          self._.write(", ")
        }
      }
      
      self._.write(")")
    }
    String(value~, ..) => {
      self._.write("\"")
      self._.write(value)
      self._.write("\"")
    }
    Indexing(expr~, index~, ..) => {
      self.emit_expr(expr)
      self._.write("[")
      self.emit_expr(index)
      self._.write("]")
    }
    Vector(elems~, ..) => {
      self._.write("[")
      for idx, elem in elems {
        self.emit_expr(elem)
        if idx < elems.length() - 1 {
          self._.write(", ")
        }
      }
      self._.write("]")
    }
  }
}

pub fn emit_stmt(self: YirEmitter, stmt: Stmt) -> Unit {
  match stmt {
    Expr(expr~, ..) => {
      self._.write_indent()
      self.emit_expr(expr)
      self._.write("\n")
    }
    Wire(name~, width~, dims~, ..) => {
      self._.write_indent()
      self._.write("wire [\{width}]")

      for dim in dims {
        self._.write("[")
        self._.write(dim)
        self._.write("]")
      }

      self._.write(" \{name}\n")
    }
    Reg(width~, clk~, data_in~, async_reset~, enable~, reset~, data_out~, ..) => {
      self._.emit("reg [\{width}](")
      self._.indent += 1
      self._.write_indent()
      self._.write("async_reset: ")
      self._.write(async_reset)
      self._.write(",\n")
      self._.write_indent()
      self._.write("clk: ")
      self.emit_expr(clk)
      self._.write(",\n")
      self._.write_indent()
      self._.write("data_in: ")
      self.emit_expr(data_in)
      self._.write(",\n")
      self._.write_indent()
      self._.write("data_out: ")
      self.emit_expr(data_out)
      self._.write(",\n")

      match enable {
        Some(enable) => {
          self._.write_indent()
          self._.write("enable: ")
          self.emit_expr(enable)
          self._.write(",\n")
        }
        _ => ()
      }

      match reset {
        Some(reset) => {
          self._.write_indent()
          self._.write("reset: ")
          self.emit_expr(reset)
          self._.write(",\n")
        }
        _ => ()
      }

      self._.indent -= 1
      self._.emit(")")
    }
    Assign(lhs~, rhs~, ..) => {
      self._.write_indent()
      self.emit_expr(lhs)
      self._.write(" = ")
      self.emit_expr(rhs)
      self._.write("\n")
    }
    Memory(width~, depth~, init~, clk~, read_addr~, write_addr~, write_enable~, data_in~, data_out~, span=_) => {
      self._.emit("memory \{width}x\{depth}(")
      self._.indent += 1

      match init {
        Some(init) => {
          self._.write_indent()
          self._.write("init: ")
          self._.write(init)
          self._.write(",\n")
        }
        None => ()
      }

      self._.write_indent()
      self._.write("clk: ")
      self.emit_expr(clk)
      self._.write(",\n")
      self._.write_indent()
      self._.write("read_addr: ")
      self.write_expr_array(read_addr)
      self._.write(",\n")
      self._.write_indent()
      self._.write("write_addr: ")
      self.write_expr_array(write_addr)
      self._.write(",\n")
      
      match write_enable {
        Some(write_enable) => {
          self._.write_indent()
          self._.write("write_enable: ")
          self.write_expr_array(write_enable)
          self._.write(",\n")
        }
        None => ()
      }

      self._.write_indent()
      self._.write("data_in: ")
      self.write_expr_array(data_in)
      self._.write(",\n")
      self._.write_indent()
      self._.write("data_out: ")
      self.write_expr_array(data_out)
      self._.write(",\n")
      self._.indent -= 1
      self._.emit(")")
    }
    Instance(module_name~, ports~, ..) => {
      self._.emit("\{module_name}(")
      self._.indent += 1

      for port_name, port_expr in ports {
        self._.write_indent()
        self._.write("\{port_name}: ")
        self.emit_expr(port_expr)
        self._.write(",\n")
      }

      self._.indent -= 1
      self._.emit(")")
    }
    Process(triggers~, body~, ..) => {
      self._.write_indent()
      self._.write("process ")

      match triggers {
        All => self._.write("all")
        Events(events) => {
          self._.write("events ")
          
          for event in events {
            match event.polarity {
              Some(Posedge) => self._.write("posedge ")
              Some(Negedge) => self._.write("negedge ")
              None => ()
            }

            self._.write(event.signal)
            self._.write(", ")
          }
        }
      }

      self._.write(" {\n")
      self._.indent += 1
      
      for stmt in body {
        self.emit_stmt(stmt)
      }

      self._.indent -= 1
      self._.emit("}")
    }
  }
}

pub impl Show for Port with output(self, logger) {
  logger.write_string("\{self.direction} \{self.name}[\{self.width}]")
}

pub fn emit_module(self: YirEmitter, mod: Module) -> Unit {
  self._.emit("module \{mod.name}(")
  self._.indent += 1
  self._.write_iter(mod.ports.iter(), prefix="", suffix="", sep=",\n", indent=true, trailing=true)
  self._.indent -= 1
  self._.emit(") {")
  self._.indent += 1

  for stmt in mod.body {
    self.emit_stmt(stmt)
  }

  self._.indent -= 1
  self._.write("}\n\n")
}

fn write_expr_array(self: YirEmitter, exprs: Array[Expr]) -> Unit {
  self._.write("[")

  for idx, expr in exprs {
    self.emit_expr(expr)
    if idx < exprs.length() - 1 {
      self._.write(", ")
    }
  }

  self._.write("]")
}

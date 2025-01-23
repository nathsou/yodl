
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
    MemRead(mem_name~, addr~, ..) => {
      self._.write(mem_name)
      self._.write("[")
      self.emit_expr(addr)
      self._.write("]")
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
  }
}

pub fn emit_stmt(self: YirEmitter, stmt: Stmt) -> Unit {
  match stmt {
    Expr(expr~, ..) => {
      self._.write_indent()
      self.emit_expr(expr)
      self._.write("\n")
    }
    Wire(name~, width~, ..) => {
      self._.emit("wire \{name}[\{width}]")
    }
    Reg(name~, width~, async_reset~, ..) => {
      let cell = if async_reset { "adff" } else { "dff" }
      self._.emit("\{cell} \{name}[\{width}]")
    }
    Assign(lhs~, rhs~, ..) => {
      self._.write_indent()
      self.emit_expr(lhs)
      self._.write(" = ")
      self.emit_expr(rhs)
      self._.write("\n")
    }
    Memory(name~, width~, depth~, read_ports~, write_ports~, ..) => {
      self._.write("memory \{name}[\{width}x\{depth}] \{read_ports} \{write_ports}")
    }
    MemWrite(mem_name~, addr~, data~, ..) => {
      self._.emit("\{mem_name}[")
      self.emit_expr(addr)
      self._.write("] = ")
      self.emit_expr(data)
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

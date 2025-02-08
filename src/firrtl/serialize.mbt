pub type FIRRTLEmitter @utils.Emitter

pub fn FIRRTLEmitter::new() -> FIRRTLEmitter {
  FIRRTLEmitter(@utils.Emitter::new())
}

pub impl Show for Id with output(self, logger) {
  match self {
    Ident(s) => logger.write_string(s)
    Literal(s) => logger.write_string("`\{s}`")
  }
}

pub impl Show for Type with output(self, logger) {
  match self {
    Clock => logger.write_string("Clock")
    AsyncReset => logger.write_string("AsyncReset")
    Reset => logger.write_string("Reset")
    UInt(width) => {
      logger.write_string("UInt<\{width}>")
    }
    SInt(width) => {
      logger.write_string("SInt<\{width}>")
    }
    UIntInferred => {
      logger.write_string("UInt")
    }
    SIntInferred => {
      logger.write_string("SInt")
    }
    Const(ty) => {
      logger.write_string("const \{ty}")
    }
    Vec(ty, size) => {
      logger.write_string("\{ty}[\{size}]")
    }
    Bundle(fields) => {
      logger.write_string("{ ")

      for idx, field in fields {
        if field.flip {
          logger.write_string("flip ")
        }

        logger.write_object(field.id)
        logger.write_string(": ")
        logger.write_object(field.ty)

        if idx < fields.length() - 1 {
          logger.write_string(", ")
        }
      }

      logger.write_string(" }")
    }
  }
}

pub fn emit_circuit(self: FIRRTLEmitter, circuit: Circuit) -> Unit {
  let (major, minor, patch) = circuit.version
  self._.write("FIRRTL version \{major}.\{minor}.\{patch}\n")
  self._.write("circuit ")
  self._.write(circuit.id)
  self._.write(":\n")
  self._.indent += 1

  for decl in circuit.decls {
    self.emit_decl(decl)
  }

  self._.indent -= 1
}

pub fn emit_decl(self: FIRRTLEmitter, decl: Decl) -> Unit {
  match decl {
    Module(mod) => self.emit_module(mod)
  }

  self._.write("\n")
}

pub fn emit_module(self: FIRRTLEmitter, mod: Module) -> Unit {
  self._.write_indent()

  if mod.public {
    self._.write("public ")
  }

  self._.write("module ")
  self._.write(mod.id)
  self._.write(":\n")
  self._.indent += 1

  for port in mod.ports {
    self.emit_port(port)
    self._.write("\n")
  }

  if mod.ports.length() > 0 {
    self._.write("\n")
  }

  for stmt in mod.body {
    self.emit_stmt(stmt)
    self._.write("\n")
  }

  self._.indent -= 1
}

pub fn emit_port(self: FIRRTLEmitter, port: Port) -> Unit {
  self._.write_indent()
  self._.write(port.direction)
  self._.write(" ")
  self._.write(port.id)
  self._.write(": ")
  self._.write(port.ty)
}

pub fn emit_reference(self: FIRRTLEmitter, reference: Reference) -> Unit {
  match reference {
    Id(id) => self._.write(id)
    Indexing(lhs~, index~) => {
      self.emit_reference(lhs)
      self._.write("[")
      self.emit_expr(index)
      self._.write("]")
    }
    FieldAccess(lhs~, field~) => {
      self.emit_reference(lhs)
      self._.write(".")
      self._.write(field)
    }
  }
}

pub fn emit_stmt(self: FIRRTLEmitter, stmt: Stmt, glued~: Bool = false) -> Unit {
  match stmt {
    Node(id~, expr~) => {
      self._.write_indent()
      self._.write("node ")
      self._.write(id)
      self._.write(" = ")
      self.emit_expr(expr)
    }
    Wire(id~, ty~) => {
      self._.write_indent()
      self._.write("wire ")
      self._.write(id)
      self._.write(": ")
      self._.write(ty)
    }
    Connect(lhs, rhs) => {
      self._.write_indent()
      self._.write("connect ")
      self.emit_reference(lhs)
      self._.write(", ")
      self.emit_expr(rhs)
    }
    Inst(id~, of~) => {
      self._.write_indent()
      self._.write("inst ")
      self._.write(id)
      self._.write(" of ")
      self._.write(of)
    }
    Reg(id~, ty~, clock~) => {
      self._.write_indent()
      self._.write("reg ")
      self._.write(id)
      self._.write(": ")
      self._.write(ty)
      self._.write(", ")
      self.emit_expr(clock)
    }
    RegReset(id~, ty~, clock~, reset~, init~) => {
      self._.write_indent()
      self._.write("regreset ")
      self._.write(id)
      self._.write(": ")
      self._.write(ty)
      self._.write(", ")
      self.emit_expr(clock)
      self._.write(", ")
      self.emit_expr(reset)
      self._.write(", ")
      self.emit_expr(init)
    }
    When({ cond, body, otherwise }) => {
      if not(glued) {
        self._.write_indent()
      }

      self._.write("when ")
      self.emit_expr(cond)
      self._.write(":\n")
      self._.indent += 1

      for stmt in body {
        self.emit_stmt(stmt)
        self._.write("\n")
      }

      self._.indent -= 1

      match otherwise {
        Some([When(otherwise)]) => {
          self._.write_indent()
          self._.write("else ")
          self.emit_stmt(When(otherwise), glued=true)
        }
        Some(otherwise) => {
          self._.write_indent()
          self._.write("else:\n")
          self._.indent += 1

          for stmt in otherwise {
            self.emit_stmt(stmt)
            self._.write("\n")
          }

          self._.indent -= 1
        }
        None => ()
      }
    }
    Mem(
      id~,
      data_type~,
      depth~,
      read_latency~,
      write_latency~,
      read_under_write~,
      readers~,
      writers~,
      readwriters~,
    ) => {
      self._.write_indent()
      self._.write("mem ")
      self._.write(id)
      self._.write(":\n")
      self._.indent += 1
      self._.write_indent()
      self._.write("data-type => ")
      self._.write(data_type)
      self._.write("\n")
      self._.write_indent()
      self._.write("depth => ")
      self._.write(depth)
      self._.write("\n")
      self._.write_indent()
      self._.write("read-latency => ")
      self._.write(read_latency)
      self._.write("\n")
      self._.write_indent()
      self._.write("write-latency => ")
      self._.write(write_latency)
      self._.write("\n")
      self._.write_indent()
      self._.write("read-under-write => ")
      self._.write(match read_under_write {
        Undefined => "undefined"
        Old => "old"
        New => "new"
      })
      self._.write("\n")
      
      for reader in readers {
        self._.write_indent()
        self._.write("reader => ")
        self._.write(reader)
        self._.write("\n")
      }

      for writer in writers {
        self._.write_indent()
        self._.write("writer => ")
        self._.write(writer)
        self._.write("\n")
      }

      for readwriter in readwriters {
        self._.write_indent()
        self._.write("readwriter => ")
        self._.write(readwriter)
        self._.write("\n")
      }

      self._.indent -= 1
    }
    Invalidate(reference) => {
      self._.write_indent()
      self._.write("invalidate ")
      self.emit_reference(reference)
    }
    Skip => {
      self._.write_indent()
      self._.write("skip")
    }
  }
}

fn show_int(radix~: Int?, value: BigInt) -> String {
  match radix {
    Some(16) => "0h\{value.to_hex()}"
    _ => "\{value}"
  }
}

pub fn emit_literal(self: FIRRTLEmitter, literal: Literal) -> Unit {
  match literal {
    UInt(width~, radix~, value~) => {
      self._.write("UInt<\{width}>(\{show_int(radix~, value)})")
    }
    SInt(width~, radix~, value~) => {
      self._.write("SInt<\{width}>(\{show_int(radix~, value)})")
    }
  }
}

pub impl Show for PrimOp with output(self, logger) {
  logger.write_string(match self {
    AsUInt => "asUInt"
    AsSInt => "asSInt"
    AsClock => "asClock"
    AsAsyncReset => "asAsyncReset"
    Cvt => "cvt"
    Add => "add"
    Sub => "sub"
    Mul => "mul"
    Div => "div"
    Rem => "rem"
    Neg => "neg"
    Not => "not"
    Andr => "andr"
    Orr => "orr"
    Xorr => "xorr"
    Lt => "lt"
    Leq => "leq"
    Gt => "gt"
    Geq => "geq"
    Eq => "eq"
    Neq => "neq"
    Dshl => "dshl"
    Dshr => "dshr"
    And => "and"
    Or => "or"
    Xor => "xor"
    Cat => "cat"
    Pad => "pad"
    Shl => "shl"
    Shr => "shr"
    Head => "head"
    Tail => "tail"
    Bits => "bits"
  })
}

pub fn emit_expr(self: FIRRTLEmitter, expr: Expr) -> Unit {
  match expr {
    Reference(reference) => self.emit_reference(reference)
    Int(value) => self._.write(value)
    Literal(literal) => self.emit_literal(literal)
    Mux(cond~, tval~, fval~) => {
      self._.write("mux ")
      self.emit_expr(cond)
      self._.write(", ")
      self.emit_expr(tval)
      self._.write(", ")
      self.emit_expr(fval)
    }
    PrimOp(op~, args~) => {
      self._.write(op)
      self._.write("(")

      for idx, arg in args {
        self.emit_expr(arg)

        if idx < args.length() - 1 {
          self._.write(", ")
        }
      }

      self._.write(")")
    }
  }
}

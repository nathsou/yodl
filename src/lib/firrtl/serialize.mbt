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
  self.inner().write("FIRRTL version \{major}.\{minor}.\{patch}\n")
  self.inner().write("circuit ")
  self.inner().write(circuit.id)
  self.inner().write(":\n")
  self.inner().indent += 1

  if circuit.annotations.length() > 0 {
    self.inner().emit("%[[")
    self.inner().indent += 1
    self.inner().write(@utils.join(circuit.annotations.map(fn(j) { j.stringify(indent=4) }), ",\n"))
    self.inner().write("\n")
    self.inner().emit("]]")
  }

  for decl in circuit.decls {
    self.emit_decl(decl)
  }

  self.inner().indent -= 1
}

pub fn emit_decl(self: FIRRTLEmitter, decl: Decl) -> Unit {
  match decl {
    Module(mod) => self.emit_module(mod)
    ExtModule(ext_mod) => self.emit_ext_module(ext_mod)
  }

  self.inner().write("\n")
}

pub fn emit_module(self: FIRRTLEmitter, mod: Module) -> Unit {
  self.inner().write_indent()

  if mod.public {
    self.inner().write("public ")
  }

  self.inner().write("module ")
  self.inner().write(mod.id)
  self.inner().write(":\n")
  self.inner().indent += 1

  for port in mod.ports {
    self.emit_port(port)
    self.inner().write("\n")
  }

  if mod.ports.length() > 0 {
    self.inner().write("\n")
  }

  for stmt in mod.body {
    self.emit_stmt(stmt)
    self.inner().write("\n")
  }

  self.inner().indent -= 1
}

pub fn emit_ext_module(self: FIRRTLEmitter, ext_mod: ExtModule) -> Unit {
  self.inner().write_indent()
  self.inner().write("extmodule ")
  self.inner().write(ext_mod.id)
  self.inner().write(":\n")
  self.inner().indent += 1

  for port in ext_mod.ports {
    self.emit_port(port)
    self.inner().write("\n")
  }

  if ext_mod.defname is Some(defname) {
    self.inner().write_indent()
    self.inner().write("defname = ")
    self.inner().write(defname)
    self.inner().write("\n")
  }

  for param in ext_mod.parameters {
    let (name, value) = param
    self.inner().write_indent()
    self.inner().write("parameter \{name} = ")
    let value_str = match value {
      IntLiteral(value) => value.to_string()
      StringLiteral(value) => "\"" + value + "\""
      RawStringLiteral(value) => "r\"" + value + "\""
    }

    self.inner().write(value_str)
    self.inner().write("\n")
  }

  self.inner().indent -= 1
}

pub fn emit_port(self: FIRRTLEmitter, port: Port) -> Unit {
  self.inner().write_indent()
  self.inner().write(port.direction)
  self.inner().write(" ")
  self.inner().write(port.id)
  self.inner().write(": ")
  self.inner().write(port.ty)
}

pub fn emit_reference(self: FIRRTLEmitter, reference: Reference) -> Unit {
  match reference {
    Id(id) => self.inner().write(id)
    Indexing(lhs~, index~) => {
      self.emit_reference(lhs)
      self.inner().write("[")
      self.emit_expr(index)
      self.inner().write("]")
    }
    FieldAccess(lhs~, field~) => {
      self.emit_reference(lhs)
      self.inner().write(".")
      self.inner().write(field)
    }
  }
}

pub fn emit_stmt(self: FIRRTLEmitter, stmt: Stmt, glued~: Bool = false) -> Unit {
  match stmt {
    Node(id~, expr~) => {
      self.inner().write_indent()
      self.inner().write("node ")
      self.inner().write(id)
      self.inner().write(" = ")
      self.emit_expr(expr)
    }
    Wire(id~, ty~) => {
      self.inner().write_indent()
      self.inner().write("wire ")
      self.inner().write(id)
      self.inner().write(": ")
      self.inner().write(ty)
    }
    Connect(lhs, rhs) => {
      self.inner().write_indent()
      self.inner().write("connect ")
      self.emit_reference(lhs)
      self.inner().write(", ")
      self.emit_expr(rhs)
    }
    Inst(id~, of~) => {
      self.inner().write_indent()
      self.inner().write("inst ")
      self.inner().write(id)
      self.inner().write(" of ")
      self.inner().write(of)
    }
    Reg(id~, ty~, clock~) => {
      self.inner().write_indent()
      self.inner().write("reg ")
      self.inner().write(id)
      self.inner().write(": ")
      self.inner().write(ty)
      self.inner().write(", ")
      self.emit_expr(clock)
    }
    RegReset(id~, ty~, clock~, reset~, init~) => {
      self.inner().write_indent()
      self.inner().write("regreset ")
      self.inner().write(id)
      self.inner().write(": ")
      self.inner().write(ty)
      self.inner().write(", ")
      self.emit_expr(clock)
      self.inner().write(", ")
      self.emit_expr(reset)
      self.inner().write(", ")
      self.emit_expr(init)
    }
    When({ cond, body, otherwise }) => {
      if not(glued) {
        self.inner().write_indent()
      }

      self.inner().write("when ")
      self.emit_expr(cond)
      self.inner().write(":\n")
      self.inner().indent += 1

      for stmt in body {
        self.emit_stmt(stmt)
        self.inner().write("\n")
      }

      self.inner().indent -= 1

      match otherwise {
        Some([When(otherwise)]) => {
          self.inner().write_indent()
          self.inner().write("else ")
          self.emit_stmt(When(otherwise), glued=true)
        }
        Some(otherwise) => {
          self.inner().write_indent()
          self.inner().write("else:\n")
          self.inner().indent += 1

          for stmt in otherwise {
            self.emit_stmt(stmt)
            self.inner().write("\n")
          }

          self.inner().indent -= 1
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
      self.inner().write_indent()
      self.inner().write("mem ")
      self.inner().write(id)
      self.inner().write(":\n")
      self.inner().indent += 1
      self.inner().write_indent()
      self.inner().write("data-type => ")
      self.inner().write(data_type)
      self.inner().write("\n")
      self.inner().write_indent()
      self.inner().write("depth => ")
      self.inner().write(depth)
      self.inner().write("\n")
      self.inner().write_indent()
      self.inner().write("read-latency => ")
      self.inner().write(read_latency)
      self.inner().write("\n")
      self.inner().write_indent()
      self.inner().write("write-latency => ")
      self.inner().write(write_latency)
      self.inner().write("\n")
      self.inner().write_indent()
      self.inner().write("read-under-write => ")
      self.inner().write(match read_under_write {
        Undefined => "undefined"
        Old => "old"
        New => "new"
      })
      self.inner().write("\n")
      
      for reader in readers {
        self.inner().write_indent()
        self.inner().write("reader => ")
        self.inner().write(reader)
        self.inner().write("\n")
      }

      for writer in writers {
        self.inner().write_indent()
        self.inner().write("writer => ")
        self.inner().write(writer)
        self.inner().write("\n")
      }

      for readwriter in readwriters {
        self.inner().write_indent()
        self.inner().write("readwriter => ")
        self.inner().write(readwriter)
        self.inner().write("\n")
      }

      self.inner().indent -= 1
    }
    Invalidate(reference) => {
      self.inner().write_indent()
      self.inner().write("invalidate ")
      self.emit_reference(reference)
    }
    Skip => {
      self.inner().write_indent()
      self.inner().write("skip")
    }
    Command(command) => {
      match command {
        Printf(clk~, cond~, fmt~, args~) => {
          self.inner().write_indent()
          self.inner().write("printf(")
          self.emit_expr(clk)
          self.inner().write(", ")
          self.emit_expr(cond)
          self.inner().write(", \"")
          self.inner().write(show_format_string(fmt))
          self.inner().write("\"")

          if args.length() > 0 {
            self.inner().write(", ")
            
            for idx, arg in args {
              self.emit_expr(arg)

              if idx < args.length() - 1 {
                self.inner().write(", ")
              }
            }
          }

          self.inner().write(")\n")
        }
        Assert(clk~, pred~, en~, fmt~, args~) => {
          self.inner().write_indent()
          self.inner().write("assert(")
          self.emit_expr(clk)
          self.inner().write(", ")
          self.emit_expr(pred)
          self.inner().write(", ")
          self.emit_expr(en)
          self.inner().write(", \"")
          self.inner().write(show_format_string(fmt))
          self.inner().write("\"")
          
          if args.length() > 0 {
            self.inner().write(", ")
            
            for idx, arg in args {
              self.emit_expr(arg)

              if idx < args.length() - 1 {
                self.inner().write(", ")
              }
            }
          }

          self.inner().write(")\n")
        }
        Stop(clk~, cond~, code~) => {
          self.inner().write_indent()
          self.inner().write("stop(")
          self.emit_expr(clk)
          self.inner().write(", ")
          self.emit_expr(cond)
          self.inner().write(", ")
          self.inner().write(code)
          self.inner().write(")\n")
        }
      }
    }
  }
}

fn show_format_string(fmt: String) -> String {
  let result = StringBuilder::new()
  
  for c in fmt {
    match c {
      '\\' => result.write_string("\\\\")
      '"' => result.write_string("\\\"")
      '\n' => result.write_string("\\n")
      '\t' => result.write_string("\\t")
      '\'' => result.write_string("\'")
      _ => result.write_char(c)
    }
  }

  result.to_string()
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
      self.inner().write("UInt<\{width}>(\{show_int(radix~, value)})")
    }
    SInt(width~, radix~, value~) => {
      self.inner().write("SInt<\{width}>(\{show_int(radix~, value)})")
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
    Int(value) => self.inner().write(value)
    Literal(literal) => self.emit_literal(literal)
    Mux(cond~, tval~, fval~) => {
      self.inner().write("mux ")
      self.emit_expr(cond)
      self.inner().write(", ")
      self.emit_expr(tval)
      self.inner().write(", ")
      self.emit_expr(fval)
    }
    PrimOp(op~, args~) => {
      self.inner().write(op)
      self.inner().write("(")

      for idx, arg in args {
        self.emit_expr(arg)

        if idx < args.length() - 1 {
          self.inner().write(", ")
        }
      }

      self.inner().write(")")
    }
  }
}

pub struct FIRRTLEmitter(@utils.Emitter)

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

pub fn[T] emit_circuit(self: FIRRTLEmitter, circuit: Circuit[T]) -> Unit {
  let (major, minor, patch) = circuit.version
  self.inner().write("FIRRTL version \{major}.\{minor}.\{patch}\n")
  self.inner().write("circuit ")
  self.inner().write(circuit.id)
  self.inner().write(":\n")
  self.inner().indent += 1

  if circuit.annotations.length() > 0 {
    self.inner().emit("%[[")
    self.inner().indent += 1
    self.inner().write(circuit.annotations.map(ann => ann.to_json().stringify(indent=4)).join(",\n"))
    self.inner().write("\n")
    self.inner().emit("]]")
  }

  for decl in circuit.decls {
    self.emit_decl(decl)
  }

  self.inner().indent -= 1
}

pub fn[T] emit_decl(self: FIRRTLEmitter, decl: Decl[T]) -> Unit {
  match decl {
    Module(mod) => self.emit_module(mod)
    ExtModule(ext_mod) => self.emit_ext_module(ext_mod)
  }

  self.inner().write("\n")
}

pub fn[T] emit_module(self: FIRRTLEmitter, mod: Module[T]) -> Unit {
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
  self.inner().write(port.dir)
  self.inner().write(" ")
  self.inner().write(port.id)
  self.inner().write(": ")
  self.inner().write(port.ty)
}

pub impl[T] Show for Reference[T] with output(self, logger) {
  match self {
    Id(id, ty=_) => logger.write_string(id.value())
    StaticIndexing(lhs~, index~, ty=_) => {
      lhs.output(logger)
      logger.write_char('[')
      logger.write_string(index.to_string())
      logger.write_char(']')
    }
    DynamicIndexing(lhs~, index~, ty=_) => {
      lhs.output(logger)
      logger.write_char('[')
      logger.write_object(index)
      logger.write_char(']')
    }
    FieldAccess(lhs~, field~, ty=_) => {
      lhs.output(logger)
      logger.write_char('.')
      logger.write_string(field.value())
    }
  }
}

pub fn[T] emit_stmt(self: FIRRTLEmitter, stmt: Stmt[T], glued~: Bool = false) -> Unit {
  match stmt {
    Node(id~, expr~) => {
      self.inner().write_indent()
      self.inner().write("node ")
      self.inner().write(id)
      self.inner().write(" = ")
      self.inner().write(expr)
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
      self.inner().write(lhs)
      self.inner().write(", ")
      self.inner().write(rhs)
    }
    Inst(id~, of~, sig=_) => {
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
      self.inner().write(clock)
    }
    RegReset(id~, ty~, clock~, reset~, init~) => {
      self.inner().write_indent()
      self.inner().write("regreset ")
      self.inner().write(id)
      self.inner().write(": ")
      self.inner().write(ty)
      self.inner().write(", ")
      self.inner().write(clock)
      self.inner().write(", ")
      self.inner().write(reset)
      self.inner().write(", ")
      self.inner().write(init)
    }
    When({ cond, body, otherwise }) => {
      if !glued {
        self.inner().write_indent()
      }

      self.inner().write("when ")
      self.inner().write(cond)
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
    Mem(mem) => {
      self.inner().write_indent()
      self.inner().write(if mem.is_flat { "flatmem " } else { "mem " })
      self.inner().write(mem.id)
      self.inner().write(":\n")
      self.inner().indent += 1
      self.inner().write_indent()

      if mem.is_flat {
        let (data_width, mask_width)  = match (mem.data_type, mem.mask_ty)  {
          (UInt(data_width), UInt(mask_width)) => (data_width, mask_width)
          _ => @utils.fail("Flat memory data and mask types must be UInt")
        }
        
        self.inner().write("width => ")
        self.inner().write(data_width)
        self.inner().write("\n")
        self.inner().write_indent()
        self.inner().write("mask_granularity => ")
        self.inner().write(data_width / mask_width)
      } else {
        self.inner().write("data-type => ")
        self.inner().write(mem.data_type)
      }
      
      self.inner().write("\n")
      self.inner().write_indent()
      self.inner().write("depth => ")
      self.inner().write(mem.depth)
      self.inner().write("\n")
      self.inner().write_indent()
      self.inner().write("read-latency => ")
      self.inner().write(mem.read_latency)
      self.inner().write("\n")
      self.inner().write_indent()
      self.inner().write("write-latency => ")
      self.inner().write(mem.write_latency)
      self.inner().write("\n")
      self.inner().write_indent()
      self.inner().write("read-under-write => ")
      self.inner().write(match mem.read_under_write {
        Undefined => "undefined"
        Old => "old"
        New => "new"
      })
      self.inner().write("\n")

      for reader in mem.readers {
        self.inner().write_indent()
        self.inner().write("reader => ")
        self.inner().write(reader)
        self.inner().write("\n")
      }

      for writer in mem.writers {
        self.inner().write_indent()
        self.inner().write("writer => ")
        self.inner().write(writer)
        self.inner().write("\n")
      }

      for readwriter in mem.readwriters {
        self.inner().write_indent()
        self.inner().write("readwriter => ")
        self.inner().write(readwriter)
        self.inner().write("\n")
      }

      self.inner().indent -= 1
    }
    Skip => {
      self.inner().write_indent()
      self.inner().write("skip")
    }
    Command(command) => {
      match command {
        Printf(clk~, en~, fmt~, args~) => {
          self.inner().write_indent()
          self.inner().write("printf(")
          self.inner().write(clk)
          self.inner().write(", ")
          self.inner().write(en)
          self.inner().write(", \"")
          self.inner().write(show_format_string(fmt))
          self.inner().write("\"")

          if args.length() > 0 {
            self.inner().write(", ")
            
            for idx, arg in args {
              self.inner().write(arg)

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
          self.inner().write(clk)
          self.inner().write(", ")
          self.inner().write(pred)
          self.inner().write(", ")
          self.inner().write(en)
          self.inner().write(", \"")
          self.inner().write(show_format_string(fmt))
          self.inner().write("\"")
          
          if args.length() > 0 {
            self.inner().write(", ")
            
            for idx, arg in args {
              self.inner().write(arg)

              if idx < args.length() - 1 {
                self.inner().write(", ")
              }
            }
          }

          self.inner().write(")\n")
        }
        Stop(clk~, en~, code~) => {
          self.inner().write_indent()
          self.inner().write("stop(")
          self.inner().write(clk)
          self.inner().write(", ")
          self.inner().write(en)
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

pub impl Show for Literal with output(self, logger) {
  match self {
    UInt(width~, radix~, value~) => {
      logger.write_string("UInt<\{width}>(\{show_int(radix~, value)})")
    }
    SInt(width~, radix~, value~) => {
      logger.write_string("SInt<\{width}>(\{show_int(radix~, value)})")
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

fn[T: Show] show_mux(cond~: T, tval~: T, fval~: T, logger: &Logger) -> Unit {
  logger.write_string("mux(")
  logger.write_object(cond)
  logger.write_string(", ")
  logger.write_object(tval)
  logger.write_string(", ")
  logger.write_object(fval)
  logger.write_string(")")
}

fn[T] show_primop(op~: PrimOp, args~: Array[Expr[T]], logger: &Logger) -> Unit {
  logger.write_object(op)
  logger.write_string("(")

  match op {
    Pad | Shl | Shr | Head | Tail => {
      logger.write_object(args[0])
      logger.write_string(", ")
      logger.write_object(args[1].as_int().unwrap())
    }
    Bits => {
      logger.write_object(args[0])
      logger.write_string(", ")
      logger.write_object(args[1].as_int().unwrap())
      logger.write_string(", ")
      logger.write_object(args[2].as_int().unwrap())
    }
    _ => {
      for idx, arg in args {
        logger.write_object(arg)

        if idx < args.length() - 1 {
          logger.write_string(", ")
        }
      }
    }
  }

  logger.write_string(")")
}

fn[T] Expr::as_int(self: Expr[T]) -> BigInt? {
  match self {
    Literal(lit, ty=_) => Some(lit.as_bigint())
    _ => None
  }
}

pub impl[T] Show for Expr[T] with output(self, logger) {
  match self {
    Reference(reference, ty=_) => logger.write_object(reference)
    Literal(literal, ty=_) => logger.write_object(literal)
    Mux(cond~, tval~, fval~, ty=_) => show_mux(cond~, tval~, fval~, logger)
    PrimOp(op~, args~, ty=_) => show_primop(op~, args~, logger)
  }
}

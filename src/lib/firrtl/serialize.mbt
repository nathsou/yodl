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

pub fn[T] FIRRTLEmitter::emit_circuit(self: Self, circuit: Circuit[T]) -> Unit {
  let (major, minor, patch) = circuit.version
  self.0.write("FIRRTL version \{major}.\{minor}.\{patch}\n")
  self.0.write("circuit ")
  self.0.write(circuit.id)
  self.0.write(":\n")
  self.0.indent += 1

  if circuit.annotations.length() > 0 {
    self.0.emit("%[[")
    self.0.indent += 1
    self.0.write(circuit.annotations.map(ann => ann.to_json().stringify(indent=4)).join(",\n"))
    self.0.write("\n")
    self.0.emit("]]")
  }

  for decl in circuit.decls {
    self.emit_decl(decl)
  }

  self.0.indent -= 1
}

pub fn[T] FIRRTLEmitter::emit_decl(self: Self, decl: Decl[T]) -> Unit {
  match decl {
    Module(mod) => self.emit_module(mod)
    ExtModule(ext_mod) => self.emit_ext_module(ext_mod)
  }

  self.0.write("\n")
}

pub fn[T] FIRRTLEmitter::emit_module(self: Self, mod: Module[T]) -> Unit {
  self.0.write_indent()

  if mod.public {
    self.0.write("public ")
  }

  self.0.write("module ")
  self.0.write(mod.id)
  self.0.write(":\n")
  self.0.indent += 1

  for port in mod.ports {
    self.emit_port(port)
    self.0.write("\n")
  }

  if mod.ports.length() > 0 {
    self.0.write("\n")
  }

  for stmt in mod.body {
    self.emit_stmt(stmt)
    self.0.write("\n")
  }

  self.0.indent -= 1
}

pub fn FIRRTLEmitter::emit_ext_module(self: Self, ext_mod: ExtModule) -> Unit {
  self.0.write_indent()
  self.0.write("extmodule ")
  self.0.write(ext_mod.id)
  self.0.write(":\n")
  self.0.indent += 1

  for port in ext_mod.ports {
    self.emit_port(port)
    self.0.write("\n")
  }

  if ext_mod.defname is Some(defname) {
    self.0.write_indent()
    self.0.write("defname = ")
    self.0.write(defname)
    self.0.write("\n")
  }

  for param in ext_mod.parameters {
    let (name, value) = param
    self.0.write_indent()
    self.0.write("parameter \{name} = ")
    let value_str = match value {
      IntLiteral(value) => value.to_string()
      StringLiteral(value) => "\"" + value + "\""
      RawStringLiteral(value) => "r\"" + value + "\""
    }

    self.0.write(value_str)
    self.0.write("\n")
  }

  self.0.indent -= 1
}

pub fn FIRRTLEmitter::emit_port(self: Self, port: Port) -> Unit {
  self.0.write_indent()
  self.0.write(port.dir)
  self.0.write(" ")
  self.0.write(port.id)
  self.0.write(": ")
  self.0.write(port.ty)
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

pub impl[T] @debug.Debug for Reference[T] with to_repr(self) {
  @debug.Repr::literal(self.to_string())
}

pub fn[T] FIRRTLEmitter::emit_stmt(self: Self, stmt: Stmt[T], glued~: Bool = false) -> Unit {
  match stmt {
    Node(id~, expr~) => {
      self.0.write_indent()
      self.0.write("node ")
      self.0.write(id)
      self.0.write(" = ")
      self.0.write(expr)
    }
    Wire(id~, ty~) => {
      self.0.write_indent()
      self.0.write("wire ")
      self.0.write(id)
      self.0.write(": ")
      self.0.write(ty)
    }
    Connect(lhs, rhs) => {
      self.0.write_indent()
      self.0.write("connect ")
      self.0.write(lhs)
      self.0.write(", ")
      self.0.write(rhs)
    }
    Inst(id~, of~, sig=_) => {
      self.0.write_indent()
      self.0.write("inst ")
      self.0.write(id)
      self.0.write(" of ")
      self.0.write(of)
    }
    Reg(id~, ty~, clock~) => {
      self.0.write_indent()
      self.0.write("reg ")
      self.0.write(id)
      self.0.write(": ")
      self.0.write(ty)
      self.0.write(", ")
      self.0.write(clock)
    }
    RegReset(id~, ty~, clock~, reset~, init~) => {
      self.0.write_indent()
      self.0.write("regreset ")
      self.0.write(id)
      self.0.write(": ")
      self.0.write(ty)
      self.0.write(", ")
      self.0.write(clock)
      self.0.write(", ")
      self.0.write(reset)
      self.0.write(", ")
      self.0.write(init)
    }
    When({ cond, body, otherwise }) => {
      if !glued {
        self.0.write_indent()
      }

      self.0.write("when ")
      self.0.write(cond)
      self.0.write(":\n")
      self.0.indent += 1

      for stmt in body {
        self.emit_stmt(stmt)
        self.0.write("\n")
      }

      self.0.indent -= 1

      match otherwise {
        Some([When(otherwise)]) => {
          self.0.write_indent()
          self.0.write("else ")
          self.emit_stmt(When(otherwise), glued=true)
        }
        Some(otherwise) => {
          self.0.write_indent()
          self.0.write("else:\n")
          self.0.indent += 1

          for stmt in otherwise {
            self.emit_stmt(stmt)
            self.0.write("\n")
          }

          self.0.indent -= 1
        }
        None => ()
      }
    }
    Mem(mem) => {
      self.0.write_indent()
      self.0.write(if mem.is_flat { "flatmem " } else { "mem " })
      self.0.write(mem.id)
      self.0.write(":\n")
      self.0.indent += 1
      self.0.write_indent()

      if mem.is_flat {
        let (data_width, mask_width)  = match (mem.data_type, mem.mask_ty)  {
          (UInt(data_width), UInt(mask_width)) => (data_width, mask_width)
          _ => @utils.fail("Flat memory data and mask types must be UInt")
        }
        
        self.0.write("width => ")
        self.0.write(data_width)
        self.0.write("\n")
        self.0.write_indent()
        self.0.write("mask_granularity => ")
        self.0.write(data_width / mask_width)
      } else {
        self.0.write("data-type => ")
        self.0.write(mem.data_type)
      }
      
      self.0.write("\n")
      self.0.write_indent()
      self.0.write("depth => ")
      self.0.write(mem.depth)
      self.0.write("\n")
      self.0.write_indent()
      self.0.write("read-latency => ")
      self.0.write(mem.read_latency)
      self.0.write("\n")
      self.0.write_indent()
      self.0.write("write-latency => ")
      self.0.write(mem.write_latency)
      self.0.write("\n")
      self.0.write_indent()
      self.0.write("read-under-write => ")
      self.0.write(match mem.read_under_write {
        Undefined => "undefined"
        Old => "old"
        New => "new"
      })
      self.0.write("\n")

      for reader in mem.readers {
        self.0.write_indent()
        self.0.write("reader => ")
        self.0.write(reader)
        self.0.write("\n")
      }

      for writer in mem.writers {
        self.0.write_indent()
        self.0.write("writer => ")
        self.0.write(writer)
        self.0.write("\n")
      }

      for readwriter in mem.readwriters {
        self.0.write_indent()
        self.0.write("readwriter => ")
        self.0.write(readwriter)
        self.0.write("\n")
      }

      self.0.indent -= 1
    }
    Skip => {
      self.0.write_indent()
      self.0.write("skip")
    }
    Command(command) => {
      match command {
        Printf(clk~, en~, fmt~, args~) => {
          self.0.write_indent()
          self.0.write("printf(")
          self.0.write(clk)
          self.0.write(", ")
          self.0.write(en)
          self.0.write(", \"")
          self.0.write(show_format_string(fmt))
          self.0.write("\"")

          if args.length() > 0 {
            self.0.write(", ")
            
            for idx, arg in args {
              self.0.write(arg)

              if idx < args.length() - 1 {
                self.0.write(", ")
              }
            }
          }

          self.0.write(")\n")
        }
        Assert(clk~, pred~, en~, fmt~, args~) => {
          self.0.write_indent()
          self.0.write("assert(")
          self.0.write(clk)
          self.0.write(", ")
          self.0.write(pred)
          self.0.write(", ")
          self.0.write(en)
          self.0.write(", \"")
          self.0.write(show_format_string(fmt))
          self.0.write("\"")
          
          if args.length() > 0 {
            self.0.write(", ")
            
            for idx, arg in args {
              self.0.write(arg)

              if idx < args.length() - 1 {
                self.0.write(", ")
              }
            }
          }

          self.0.write(")\n")
        }
        Stop(clk~, en~, code~) => {
          self.0.write_indent()
          self.0.write("stop(")
          self.0.write(clk)
          self.0.write(", ")
          self.0.write(en)
          self.0.write(", ")
          self.0.write(code)
          self.0.write(")\n")
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
    Some(16) => "0h\{value.to_string(radix=16)}"
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

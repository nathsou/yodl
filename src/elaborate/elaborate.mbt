
pub(readonly) struct Elaborator {
  mut autoidx: UInt
  modules: Map[String, @rtlil.Module]
  env: Map[String, Value]
}

pub fn Elaborator::new() -> Elaborator {
  { autoidx: 0, modules: {}, env: {} }
}

type! ElaboratorError {
  ModuleAlreadyDeclared(name~: String, span~: @parse.Span)
  UnknownIdentifier(name~: String, span~: @parse.Span)
  Unsupported(message~: String, span~: @parse.Span)
  NameConflict(name~: String, span~: @parse.Span)
  ExpectedSignal(span~: @parse.Span)
  UnknownModule(name~: String, span~: @parse.Span)
  ExtraPorts(extra_ports~: Array[String], span~: @parse.Span)
  UntypedLet(span~: @parse.Span)
  UnresolvedType(span~: @parse.Span)
  IndexOutOfBounds(index~: UInt, len~: UInt, span~: @parse.Span)
  Unreachable(message~: String, span~: @parse.Span)
} derive(Show)

enum Value {
  Signal(@rtlil.Signal)
  Instance(@rtlil.Cell)
  Vector(Array[Value])
}

fn bits(bits: Array[@rtlil.BinaryDigit]) -> Value {
  Value::Signal(@rtlil.SigConst(ConstValue({ width: bits.length().reinterpret_as_uint(), bits })))
}

fn default_value(self: Elaborator, ty~: @parse.Type, mod~: @rtlil.Module, span~: @parse.Span, name_binding~: @rtlil.Id) -> Value!Error {
  match ty {
    Nat => Value::Signal(@rtlil.SigConst(ConstInteger(0)))
    Logic => {
      bits([X])
    }
    Vector(ty~, len~) => match ty {
      Logic => {
        let wire = mod.add_wire!(
          name=name_binding,
          width=len,
          port=None,
          attributes=src_attribute(span),
        )

        Value::Signal(SigWire(wire))
      }
      _ => {
        let val = Array::new(capacity=len.reinterpret_as_int())

        for i in 0..<len.reinterpret_as_int() {
          val.push(self.default_value!(ty~, mod~, span~, name_binding=name_binding.join("[\{i}]")))
        }

        Value::Vector(val)
      }
    }
    Instance({ name, span, .. }) => {
      let inst: @parse.Expr = @parse.Expr::Instance(
        name~,
        ports={},
        span~,
        ty={ val: Some(ty) },
      )

      self.elaborate_expr!(inst, mod, name_binding=Some(name_binding))
    }
    Name(_) => {
      raise UnresolvedType(span~)
    }
  }
}

fn expect_signal(self: Value, span: @parse.Span) -> @rtlil.Signal!ElaboratorError {
  match self {
    Signal(sig) => sig
    _ => raise ExpectedSignal(span~)
  }
}

fn expect_integer(self: Value, span: @parse.Span) -> Int!ElaboratorError {
  match self {
    Signal(@rtlil.SigConst(ConstInteger(n))) => n
    _ => raise ExpectedSignal(span~)
  }
}

fn src_attribute(span: @parse.Span) -> Map[@rtlil.Id, @rtlil.Constant] {
  let attributes = {}
  attributes[@rtlil.PubId("src")] = @rtlil.ConstString(span.to_string())
  attributes
}

fn elaborate_module(self: Elaborator, mod: @parse.ModuleDecl) -> Unit! {
  let mod_def = @rtlil.Module::new(PubId(mod.name))

  let mut port_id: UInt = 1

  for input in mod.inputs {
    let _ = mod_def.add_wire!(
      name=PubId(input.name),
      width=input.ty.width().or_error!(ElaboratorError::Unsupported(message="Only logic types are supported", span=mod.span)),
      port=Some({ direction: Input, id: port_id }),
      attributes=src_attribute(input.span),
    )

    port_id += 1
  }

  for output in mod.outputs {
    let _ = mod_def.add_wire!(
      name=PubId(output.name),
      width=output.ty.width().or_error!(ElaboratorError::Unsupported(message="Only logic types are supported", span=mod.span)),
      port=Some({ direction: Output, id: port_id }),
      attributes=src_attribute(output.span),
    )

    port_id += 1
  }

  for stmt in mod.body {
    let _ = self.elaborate_stmt!(stmt, mod_def)
  }

  if self.modules.contains(mod.name) {
    raise ModuleAlreadyDeclared(name=mod.name, span=mod.span)
  }

  self.modules[mod.name] = mod_def
}

fn next_genidx(self: Elaborator) -> UInt {
  let idx = self.autoidx
  self.autoidx += 1
  idx
}

fn declare(self: Elaborator, name: String, value: Value, span~: @parse.Span) -> Unit!ElaboratorError {
  if self.env.contains(name) {
    raise NameConflict(name=name, span=span)
  }
  
  self.env[name] = value
}

fn elaborate_expr(
  self: Elaborator,
  expr: @parse.Expr,
  mod: @rtlil.Module,
  name_binding~: @rtlil.Id? = None,
) -> Value! {
  match expr {
    Identifier(name~, span~, ..) => {
      match self.env[name] {
        Some(value) => value
        None => match mod.wires[PubId(name)] {
          Some(wire) => Value::Signal(SigWire(wire))
          None => raise UnknownIdentifier(name~, span~)
        }
      }
    }
    Natural(value~, ..) => {
      Value::Signal(@rtlil.SigConst(ConstInteger(value.reinterpret_as_int())))
    }
    Unary(span~, ..) => {
      raise Unsupported(message="Unary operators are not supported yet", span~)
    }
    Binary(
      op=And | Or | Xor | Nand | Nor | Xnor as op,
      lhs~,
      rhs~,
      span~,
      ..
    ) => {
      let mod_name = match op {
        And => "and"
        Or => "or"
        Xor => "xor"
        Nand => "nand"
        Nor => "nor"
        Xnor => "xnor"
        _ => raise Unreachable(message="Invalid logical binary operator", span~)
      }

      let output = mod.add_wire!(
        name=GenId("\{mod_name}_y_\{self.next_genidx()}"),
        width=1,
        port=None,
        attributes=src_attribute(span),
      )
      
      let _ = mod.add_cell!(
        type_=GenId(mod_name),
        name=GenId("\{mod_name}_\{self.next_genidx()}"),
        parameters={
          let parameters: Map[@rtlil.Id, @rtlil.Constant] = {}
          parameters[@rtlil.PubId("A_SIGNED")] = @rtlil.ConstInteger(0)
          parameters[@rtlil.PubId("A_WIDTH")] = @rtlil.ConstInteger(1)
          parameters[@rtlil.PubId("B_SIGNED")] = @rtlil.ConstInteger(0)
          parameters[@rtlil.PubId("B_WIDTH")] = @rtlil.ConstInteger(1)
          parameters[@rtlil.PubId("Y_WIDTH")] = @rtlil.ConstInteger(1)
          parameters
        },
        connections={
          let connections: Map[@rtlil.Id, @rtlil.Signal] = {}
          connections[@rtlil.PubId("A")] = self.elaborate_expr!(lhs, mod).expect_signal!(lhs.span())
          connections[@rtlil.PubId("B")] = self.elaborate_expr!(rhs, mod).expect_signal!(rhs.span())
          connections[@rtlil.PubId("Y")] = SigWire(output)
          connections
        },
        attributes=src_attribute(span),
      )

      Value::Signal(SigWire(output))
    }
    Binary(op=Add | Sub | Mul as op, lhs~, rhs~, span~, ..) => {
      let lhs_val = self.elaborate_expr!(lhs, mod).expect_integer!(lhs.span())
      let rhs_val = self.elaborate_expr!(rhs, mod).expect_integer!(rhs.span())

      let result = match op {
        Add => lhs_val + rhs_val
        Sub => lhs_val - rhs_val
        Mul => lhs_val * rhs_val
        _ => raise Unreachable(message="Invalid arithmetical binary operator", span~)
      }

      Value::Signal(@rtlil.SigConst(ConstInteger(result)))
    }
    Instance(name~, ports~, span~, ty=_) => {
      let mod_def = self.modules[name].or_error!(ElaboratorError::UnknownModule(name~, span~))

      let connections: Map[@rtlil.Id, @rtlil.Signal] = {}
      let unconnected_wires: Map[@rtlil.Id, @rtlil.Signal] = {}

      let extra_ports = []
      let cell_name = name_binding.or(GenId("\{name}_\{self.next_genidx()}"))

      for name, wire in mod_def.wires {
        match wire.port {
          Some(_) => {
            if not(ports.contains(name.inner())) {
              let wire = mod.add_wire!(
                name=GenId("\{cell_name.inner()}_\{name.inner()}"),
                width=wire.width,
                port=None,
                attributes=src_attribute(span),
              )

              unconnected_wires[@rtlil.PubId(name.inner())] = SigWire(wire)
            }
          }
          _ => ()
        }
      }

      for port_name, expr in ports {
        if not(mod_def.wires.contains(PubId(port_name))) {
          extra_ports.push(port_name)
        }

        let sig = self.elaborate_expr!(expr, mod).expect_signal!(expr.span())
        connections[@rtlil.PubId(port_name)] = sig
      }
      
      if not(extra_ports.is_empty()) {
        raise ExtraPorts(extra_ports~, span~)
      }

      for id, wire in unconnected_wires {
        connections[id] = wire
      }

      let cell = mod.add_cell!(
        name=cell_name,
        type_=PubId(name),
        attributes=src_attribute(span),
        connections~,
        parameters={},
      )

      Value::Instance(cell)
    }
    PortAccess(expr~, port~, span~, ..) => {
      let val = self.elaborate_expr!(expr, mod)

      match val {
        Instance(cell) => {
          match mod.wires[GenId("\{cell.name.inner()}_\{port}")] {
            Some(wire) => Value::Signal(SigWire(wire))
            None => raise UnknownModulePort(module_name=cell.name.inner(), port_name=port, span=span)
          }
        }
        _ => raise Unsupported(message="Port access on non-instance", span=span)
      }
    }
    Indexing(expr~, index~, ..) => {
      let idx = self.elaborate_expr!(index, mod).expect_integer!(index.span()).reinterpret_as_uint()

      match self.elaborate_expr!(expr, mod){
        Signal(sig) => {
          if idx > sig.size() {
            raise IndexOutOfBounds(index=idx, len=sig.size(), span=expr.span())
          }

          Value::Signal(@rtlil.SigChunk(signal=sig, offset=idx, width=1))
        }
        Vector(values) => {
          let len = values.length().reinterpret_as_uint()

          if idx >= len {
            raise IndexOutOfBounds(index=idx, len~, span=expr.span())
          }
          
          values[idx.reinterpret_as_int()]
        }
        _ => raise Unsupported(message="Indexing on non-vector data type", span=expr.span())
      }
    }
    Slicing(expr~, msb~, lsb~, ..) => {
      let sig = self.elaborate_expr!(expr, mod).expect_signal!(expr.span())
      let msb = self.elaborate_expr!(msb, mod).expect_integer!(msb.span()).reinterpret_as_uint()
      let lsb = self.elaborate_expr!(lsb, mod).expect_integer!(lsb.span()).reinterpret_as_uint()

      Value::Signal(@rtlil.SigChunk(signal=sig, offset=msb, width=(msb - lsb) + 1))
    }
  }
}

fn elaborate_stmt(self: Elaborator, stmt: @parse.Stmt, mod: @rtlil.Module) -> Unit! {
  match stmt {
    Expr(expr~, ..) => {
      let _ = self.elaborate_expr!(expr, mod)
    }
    Let(name~, ty~, expr~, span~) => {
      match expr {
        Some(expr) => {
          match self.elaborate_expr!(expr, mod, name_binding=Some(PubId(name))) {
            Signal(sig) => {
              let wire = mod.add_wire!(
                name=PubId(name),
                width=sig.size(),
                port=None,
                attributes=src_attribute(span),
              )

              self.declare!(name, Value::Signal(SigWire(wire)), span=expr.span())
              mod.connect!(SigWire(wire), sig)
            }
            Instance(cell) => {
              self.declare!(name, Value::Instance(cell), span=expr.span())
            }
            Vector(values) => {
              self.declare!(name, Value::Vector(values), span=expr.span())
            }
          }
        }
        None => {
          let ty = ty.val.or_error!(UntypedLet(span~))
          let val = self.default_value!(ty~, mod~, span~, name_binding=PubId(name))
          self.declare!(name, val, span~)
        }
      }
    }
    Assign(lhs~, rhs~, ..) => {
      let sig1 = self.elaborate_expr!(lhs, mod).expect_signal!(lhs.span())
      let sig2 = self.elaborate_expr!(rhs, mod).expect_signal!(rhs.span())
      mod.connect!(sig1, sig2)
    }
    For(span~, ..) => {
      raise Unreachable(message="For loop after simplification", span~)
    }
    Scope(body~, ..) => {
      for stmt in body {
        self.elaborate_stmt!(stmt, mod)
      }
    }
  }
}

pub fn elaborate_decl(self: Elaborator, decl: @parse.Decl) -> Unit! {
  match decl {
    Module(mod) => {
      self.env.clear()
      self.elaborate_module!(mod)
    }
  }
}

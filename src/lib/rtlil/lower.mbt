
priv struct RTLILLowering {
  design: Design
  mod: Module
  reg_ids: Set[@firrtl.Id]
}

fn RTLILLowering::next_idx(self: Self) -> Int {
  let idx = self.design.autoidx
  self.design.autoidx = self.design.autoidx + 1
  idx
}

fn RTLILLowering::next_gen_id(self: Self, prefix: String) -> Id {
  GenId("\{prefix}_\{self.next_idx()}")
}

pub fn lower_circuit(circuit: @firrtl.TypedCircuit) -> Design raise {
  let design = {
    autoidx: 0,
    modules: {},
  }

  for decl in circuit.decls {
    match decl {
      Module(mod) => {
        let lowering: RTLILLowering = {
          design,
          mod: {
            name: PubId(mod.id.inner()),
            parameters: {},
            wires: {},
            cells: {},
            connections: [],
            attributes: {},
          },
          reg_ids: @set.new(),
        }

        lowering.lower_module(mod)
        design.modules[lowering.mod.name] = lowering.mod
      }
      ExtModule(_) => {
        raise Failure("External modules are not yet supported in RTLIL lowering")
      }
    }
  }

  design
}

fn lower_id(id: String) -> Id {
  if id.contains_char('$') {
    GenId(id)
  } else {
    PubId(id)
  }
}

fn RTLILLowering::lower_module(self: Self, mod: @firrtl.TypedModule) -> Unit raise {
  for idx, port in mod.ports.iter2() {
    let wire: Wire = {
      name: lower_id(port.id.inner()),
      width: port.ty.width(),
      attributes: {},
      mod: self.mod,
      port: Some({
        id: idx,
        optional: false,
        direction: port.dir,
      }),
    }

    self.mod.wires[lower_id(port.id.inner())] = wire
  }

  for stmt in mod.body.iter() {
    self.lower_stmt(stmt)
  }
}

fn RTLILLowering::lower_stmt(self: Self, stmt: @firrtl.TypedStmt) -> Unit raise {
  match stmt {
    Node(id~, expr~) => {
      let wire = self.mod.add_wire(name=lower_id(id.inner()), width=expr.ty().width())
      let signal = self.lower_expr(expr)
      self.mod.connect(SigWire(wire), signal)
    }
    Wire(id~, ty~) => {
      let _ = self.mod.add_wire(name=lower_id(id.inner()), width=ty.width())
    }
    Inst(id~, of~, sig~) => {
      let inst_id = lower_id(id.inner())
      self.mk_cell(
        id=inst_id,
        kind=PubId(of.inner()),
        parameters={},
        connections={
          let conns = {}

          for port_name, port_sig in sig.ports.iter2() {
            let wire_name = lower_id("\{inst_id.inner()}.\{port_name}")
            let wire = self.mod.add_wire(name=wire_name, width=port_sig.ty.width())
            conns[port_name] = SigWire(wire)
          }

          conns
        },
      )
    }
    Reg(id~, ty~, clock~) => {
      self.lower_register(id~, ty~, clock~, reset_init=None)
    }
    RegReset(id~, ty~, clock~, reset~, init~) => {
      self.lower_register(id~, ty~, clock~, reset_init=Some((reset, init)))
    }
    Mem(_) => {
      raise Failure("Memories are not yet supported in RTLIL lowering")
    }
    Connect(lhs, rhs) => {
      self.mod.connect(self.lower_reference(lhs, is_lvalue=true), self.lower_expr(rhs))
    }
    When(_) => {
      raise Failure("When statements are not supported in RTLIL lowering")
    }
    Command(_) => {
      raise Failure("Commands are not yet supported in RTLIL lowering")
    }
    Skip => ()
  }
}

fn RTLILLowering::lower_register(
  self: Self,
  id~: @firrtl.Id,
  ty~: @firrtl.Type,
  clock~: @firrtl.TypedExpr,
  reset_init~: (@firrtl.TypedExpr, @firrtl.TypedExpr)?,
) -> Unit raise {
  guard ty.is_ground() else {
    raise Failure("Register '\{id}' must have a ground type")
  }

  self.reg_ids.add(id)
  let width = ty.width()
  let (uses_rst, async_rst) = match reset_init {
    None => (false, false)
    Some((rst, _)) => (true, rst.ty() is AsyncReset)
  }

  let cell_kind = match (uses_rst, async_rst) {
    (false, _) => "dff"
    (true, false) => "sdff"
    (true, true) => "adff"
  }

  let parameters: Map[String, Constant] = {
    "CLK_POLARITY": ConstInteger(1),
    "WIDTH": ConstInteger(width),
  }

  let connections: Map[String, Signal] = {
    "CLK": self.lower_expr(clock),
    "D": SigWire(self.mod.add_wire(name=lower_id("\{id.inner()}.d"), width~)),
    "Q": SigWire(self.mod.add_wire(name=lower_id("\{id.inner()}.q"), width~)),
  }

  if reset_init is Some((reset, init)) {
    let rst = self.lower_expr(reset)
    let init = match init {
      Literal(lit, ..) => lower_literal(lit)
        _ => raise Failure("Register init expression must be a literal value")
    }

    if async_rst {
      parameters["ARST_POLARITY"] = ConstInteger(1)
      parameters["ARST_VALUE"] = init
      connections["ARST"] = rst
    } else {
      parameters["SRST_POLARITY"] = ConstInteger(1)
      parameters["SRST_VALUE"] = init
      connections["SRST"] = rst
    }
  }
 
  self.mk_cell(
    id=lower_id(id.inner()),
    kind=GenId(cell_kind),
    parameters~,
    connections~,
  )
}

fn RTLILLowering::lower_expr(self: Self, expr: @firrtl.TypedExpr) -> Signal raise {
  match expr {
    Reference(r, ty=_) => self.lower_reference(r, is_lvalue=false)
    Literal(literal, ty=_) => SigConst(lower_literal(literal))
    Mux(cond~, tval~, fval~, ty~) => self.lower_mux(cond~, tval~, fval~, ty~)
    PrimOp(op~, args~, ty~) => self.lower_primop(op~, args~, ty~)
  }
}

fn RTLILLowering::lower_reference(self: Self, reference: @firrtl.TypedRef, is_lvalue~: Bool) -> Signal raise {
  let wire_name = if reference is Id(id, ..) && self.reg_ids.contains(id) {
    if is_lvalue {
      "\{id.inner()}.d"
    } else {
      "\{id.inner()}.q"
    }
  } else {
    reference.to_string()
  }

  let id = lower_id(wire_name)

  match self.mod.wires.get(id) {
    Some(wire) => SigWire(wire)
    None => {
      println(self.mod.wires.keys())
      raise Failure("Wire '\{id}' not found in module '\{self.mod.name}'")
    }
  }
}

fn lower_literal(literal: @firrtl.Literal) -> Constant raise {
  let (width, value) = match literal {
    UInt(width~, radix=_, value~) => (width, value)
    SInt(width~, radix=_, value~) => (width, value)
  }

  ConstValue(width~, bits=@utils.bin(value, width~).map(bit => if bit { One } else { Zero }))
}

fn RTLILLowering::mk_cell(self: Self, id~: Id, kind~: Id, parameters~: Map[String, Constant], connections~: Map[String, Signal]) -> Unit raise {
  let _ = self.mod.add_cell(
    name=id,
    cell_name=kind,
    parameters=@utils.map_keys(parameters, (id, _) => PubId(id)),
    connections=@utils.map_keys(connections, (id, _) => PubId(id)),
    attributes={},
  )
}

fn RTLILLowering::lower_mux(self: Self, cond~: @firrtl.TypedExpr, tval~: @firrtl.TypedExpr, fval~: @firrtl.TypedExpr, ty~: @firrtl.Type) -> Signal raise {
  let id = self.next_gen_id("mux")
  let width = ty.width()
  let y = self.mod.add_wire(name=id.join("_y"), width~)

  self.mk_cell(
    id~,
    kind=GenId("mux"),
    parameters={"WIDTH": ConstInteger(width)},
    connections={
      "A": self.pad(fval, width),
      "B": self.pad(tval, width),
      "S": self.lower_expr(cond),
      "Y": SigWire(y), // Y = S ? B : A
    },
  )

  SigWire(y)
}

fn RTLILLowering::lower_primop(self: Self, op~: @firrtl.PrimOp, args~: Array[@firrtl.TypedExpr], ty~: @firrtl.Type) -> Signal raise {
  match (op, args) {
    (AsUInt | AsSInt | AsClock | AsAsyncReset | Cvt | Neg | Not | Andr | Orr | Xorr, [arg]) => {
      self.lower_primop_1expr(op~, arg~, ty~)
    }
    (Add | Sub | Mul | Div | Rem | Lt | Leq | Gt | Geq | Eq | Neq | Shl | Dshl | Shr | Dshr | And | Or | Xor | Cat, [lhs, rhs]) => {
      self.lower_primop_2expr(op~, lhs~, rhs~, ty~)
    }
    (Pad | Head | Tail, [arg, Literal(lit, ..)]) => {
      self.lower_primop_1expr1int(op~, arg~, n=lit.as_int())
    }
    (Bits, [arg, Literal(lit_hi, ..), Literal(lit_lo, ..)]) => {
      let signal = self.lower_expr(arg)
      let hi = lit_hi.as_int()
      let lo = lit_lo.as_int()
      SigChunk(signal~, width=hi - lo + 1, offset=hi)
    }
    _ => {
      raise Failure("Invalid primop '\{op}' with \{args.length()} arguments")
    }
  }
}

fn RTLILLowering::lower_primop_1expr(self: Self, op~: @firrtl.PrimOp, arg~: @firrtl.TypedExpr, ty~: @firrtl.Type) -> Signal raise {
  if op is (AsUInt | AsSInt | AsClock | AsAsyncReset) {
    return self.lower_expr(arg)
  }

  if op is Cvt {
    if arg.ty().is_signed() {
      return self.lower_expr(arg)
    } else {
      // zero-extend
      return SigConcat([SigConst(ConstValue(width=1, bits=[Zero])), self.lower_expr(arg)])
    }
  }

  let cell_kind = match op {
    Neg => "neg"
    Not => "not"
    Andr => "reduce_and"
    Orr => "reduce_or"
    Xorr => "reduce_xor"
    _ => @utils.unreachable()
  }

  let id = self.next_gen_id(cell_kind)
  let arg_ty = arg.ty()
  let y_width = ty.width()
  let y = self.mod.add_wire(name=id.join("_y"), width=y_width)

  self.mk_cell(
    id~,
    kind=GenId(cell_kind),
    parameters={
      "A_SIGNED": ConstInteger(if arg_ty.is_signed() { 1 } else { 0 }),
      "A_WIDTH": ConstInteger(arg_ty.width()),
      "Y_WIDTH": ConstInteger(y_width),
    },
    connections={
      "A": self.lower_expr(arg),
      "Y": SigWire(y),
    },
  )

  SigWire(y)
}

fn RTLILLowering::lower_primop_2expr(
  self: Self,
  op~: @firrtl.PrimOp,
  lhs~: @firrtl.TypedExpr,
  rhs~: @firrtl.TypedExpr,
  ty~: @firrtl.Type,
) -> Signal raise {
  if op is Cat {
    return SigConcat([self.lower_expr(lhs), self.lower_expr(rhs)])
  }

  let lhs_ty = lhs.ty()
  let rhs_ty = rhs.ty()
  let is_lhs_signed = lhs_ty.is_signed()
  let cell_kind = match op {
    Add => "add"
    Sub => "sub"
    Mul => "mul"
    Div => "div"
    Rem => "mod"
    Lt => "lt"
    Leq => "le"
    Gt => "gt"
    Geq => "ge"
    Eq => "eq"
    Neq => "ne"
    Shl | Dshl => "shl"
    Shr | Dshr => if is_lhs_signed { "sshr" } else { "shr" }
    And => "and"
    Or => "or"
    Xor => "xor"
    _ => @utils.unreachable()
  }

  let id = self.next_gen_id(cell_kind)
  let y_width = ty.width()
  let y = self.mod.add_wire(name=id.join(".y"), width=y_width)

  self.mk_cell(
    id~,
    kind=GenId(cell_kind),
    parameters={
      "A_SIGNED": ConstInteger(if is_lhs_signed { 1 } else { 0 }),
      "B_SIGNED": ConstInteger(if rhs_ty.is_signed() { 1 } else { 0 }),
      "A_WIDTH": ConstInteger(lhs_ty.width()),
      "B_WIDTH": ConstInteger(rhs_ty.width()),
      "Y_WIDTH": ConstInteger(y_width),
    },
    connections={
      "A": self.lower_expr(lhs),
      "B": self.lower_expr(rhs),
      "Y": SigWire(y),
    },
  )

  SigWire(y)
}

fn RTLILLowering::lower_primop_1expr1int(self: Self, op~: @firrtl.PrimOp, arg~: @firrtl.TypedExpr, n~: Int) -> Signal raise {
  match op {
    Pad => self.pad(arg, n)
    Head => {
      let signal = self.lower_expr(arg)
      SigChunk(signal~, width=n, offset=arg.ty().width() - 1)
    }
    Tail => {
      let signal = self.lower_expr(arg)
      let arg_width = arg.ty().width()
      SigChunk(signal~, width=arg_width - n, offset=arg_width - 1 - n)
    }
    _ => @utils.unreachable()
  }
}

fn RTLILLowering::pad(self: Self, expr: @firrtl.TypedExpr, width: Int) -> Signal raise {
  let sig = self.lower_expr(expr)
  let ty = expr.ty()
  let old_width = ty.width()
  let is_signed = ty.is_signed()

  if old_width < width {
    let padding = width - old_width
    let pad_bits = Array::new(capacity=padding)
    let sign_ext_bit: Signal = if is_signed {
      SigChunk(signal=sig, offset=old_width - 1, width=1)
    } else {
      SigConst(ConstValue(width=1, bits=[Zero]))
    }

    for _ in 0..<padding {
      pad_bits.push(sign_ext_bit)
    }

    pad_bits.push(sig)

    SigConcat(pad_bits)
  } else {
    sig
  }
}

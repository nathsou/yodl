///|
priv struct RTLILLowering {
  design : Design
  mod : Module
  reg_ids : Set[@firrtl.Id]
  ann_target : @firrtl.AnnotationTarget
  annotations : Array[@firrtl.Annotation]
  fs : @utils.FileSystem
}

///|
fn RTLILLowering::next_idx(self : Self) -> Int {
  let idx = self.design.autoidx
  self.design.autoidx = self.design.autoidx + 1
  idx
}

///|
fn RTLILLowering::next_gen_id(self : Self, prefix : String) -> Id {
  GenId("\{prefix}_\{self.next_idx()}")
}

///|
pub fn lower_circuit(
  circuit : @firrtl.TypedCircuit,
  fs~ : @utils.FileSystem,
) -> Design raise {
  let design = { autoidx: 0, modules: {} }
  for decl in circuit.decls {
    match decl {
      Module(mod) => {
        let lowering : RTLILLowering = {
          design,
          mod: {
            name: PubId(mod.id.inner()),
            parameters: {},
            wires: {},
            cells: {},
            connections: [],
            attributes: {},
            memories: {},
          },
          reg_ids: @set.new(),
          ann_target: { circuit: circuit.id.inner(), mod: mod.id, leaf: None },
          annotations: circuit.annotations,
          fs,
        }
        lowering.lower_module(mod)
        design.modules[lowering.mod.name] = lowering.mod
      }
      ExtModule(_) =>
        raise Failure::Failure(
          "External modules are not yet supported in RTLIL lowering",
        )
    }
  }
  design
}

///|
fn lower_id(id : String) -> Id {
  if id.contains_char('$') {
    GenId(id)
  } else {
    PubId(id)
  }
}

///|
fn RTLILLowering::lower_module(
  self : Self,
  mod : @firrtl.TypedModule,
) -> Unit raise {
  for idx, port in mod.ports.iter2() {
    let wire : Wire = {
      name: lower_id(port.id.inner()),
      width: port.ty.width(),
      attributes: {},
      mod: self.mod,
      port: Some({ id: idx, optional: false, direction: port.dir }),
    }
    self.mod.wires[lower_id(port.id.inner())] = wire
  }
  for stmt in mod.body.iter() {
    self.lower_stmt(stmt)
  }
}

///|
fn RTLILLowering::lower_stmt(
  self : Self,
  stmt : @firrtl.TypedStmt,
) -> Unit raise {
  match stmt {
    Node(id~, expr~) => {
      let wire = self.mod.add_wire(
        name=lower_id(id.inner()),
        width=expr.ty().width(),
      )
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
            let wire = self.mod.add_wire(
              name=wire_name,
              width=port_sig.ty.width(),
            )
            conns[port_name] = SigWire(wire)
          }
          conns
        },
      )
    }
    Reg(id~, ty~, clock~) =>
      self.lower_register(id~, ty~, clock~, reset_init=None)
    RegReset(id~, ty~, clock~, reset~, init~) =>
      self.lower_register(id~, ty~, clock~, reset_init=Some((reset, init)))
    Mem(mem) => self.lower_mem(mem)
    Connect(lhs, rhs) =>
      self.mod.connect(
        self.lower_reference(lhs, is_lvalue=true),
        self.lower_expr(rhs),
      )
    When(_) =>
      raise Failure::Failure("When statements are not supported in RTLIL lowering")
    Command(cmd) =>
      match cmd {
        Printf(clk~, en~, fmt~, args~) => {
          self.mk_cell(
            id=self.next_gen_id("print"),
            kind=GenId("print"),
            parameters={
              // TODO: parse FIRRTL format and convert to RTLIL format
              "FORMAT": ConstString(RTLILLowering::lower_format_string(fmt, args)),
              "ARGS_WIDTH": ConstInteger(
                @utils.sum(args.map(arg => arg.ty().width()).iter()),
              ),
              "PRIORITY": ConstInteger(1),
              "TRG_ENABLE": ConstInteger(1),
              "TRG_POLARITY": ConstInteger(1),
              "TRG_WIDTH": ConstInteger(1),
            },
            connections={
              "TRG": self.lower_expr(clk),
              "EN": self.lower_expr(en),
              "ARGS": SigConcat(args.map(arg => self.lower_expr(arg))),
            },
          )
        }
        _ =>
          raise Failure::Failure("Unsupported command '\{cmd.name()}' in RTLIL lowering")
      }
    Skip => ()
  }
}

fn RTLILLowering::lower_format_string(fmt: String, args: Array[@firrtl.TypedExpr]) -> String raise {
  let parsed = @firrtl.FormatString::parse(fmt)
  let rtlil_fmt = StringBuilder::new()
  let mut arg_index = 0

  for part in parsed.parts {
    match part {
      StringPart(s) => rtlil_fmt.write_string(s)
      EscapedChar(c) => {
        match c {
          '\n' => rtlil_fmt.write_string("\\n")
          '\r' => rtlil_fmt.write_string("\\r")
          '\t' => rtlil_fmt.write_string("\\t")
          '\'' => rtlil_fmt.write_string("\\'")
          '\"' => rtlil_fmt.write_string("\\\"")
          '%' => rtlil_fmt.write_string("%%")
          _ => rtlil_fmt.write_char(c)
        }
      }
      BinaryPlaceholder => {
        let arg_width = args[arg_index].ty().width()
        rtlil_fmt.write_string("{\{arg_width}:> bu}")
        arg_index += 1
      }
      AsciiPlaceholder => {
        let arg_width = args[arg_index].ty().width()
        rtlil_fmt.write_string("{\{arg_width}:> c}")
        arg_index += 1
      }
      DecimalPlaceholder => {
        let arg_ty = args[arg_index].ty()
        let arg_width = arg_ty.width()
        rtlil_fmt.write_string("{\{arg_width}:> d")
        rtlil_fmt.write_char(if arg_ty.is_signed() { 's' } else { 'u' })
        rtlil_fmt.write_char('}')
        arg_index += 1
      }
      HexadecimalPlaceholder => {
        let arg_width = args[arg_index].ty().width()
        rtlil_fmt.write_string("{\{arg_width}:> hu}")
        arg_index += 1
      }
    }
  }
  
  rtlil_fmt.to_string()
}

///|
fn RTLILLowering::lower_register(
  self : Self,
  id~ : @firrtl.Id,
  ty~ : @firrtl.Type,
  clock~ : @firrtl.TypedExpr,
  reset_init~ : (@firrtl.TypedExpr, @firrtl.TypedExpr)?,
) -> Unit raise {
  guard ty.is_ground() else {
    raise Failure::Failure("Register '\{id}' must have a ground type")
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
  let parameters : Map[String, Constant] = {
    "CLK_POLARITY": ConstInteger(1),
    "WIDTH": ConstInteger(width),
  }
  let connections : Map[String, Signal] = {
    "CLK": self.lower_expr(clock),
    "D": SigWire(self.mod.add_wire(name=lower_id("\{id.inner()}.d"), width~)),
    "Q": SigWire(self.mod.add_wire(name=lower_id("\{id.inner()}.q"), width~)),
  }
  if reset_init is Some((reset, init)) {
    let rst = self.lower_expr(reset)
    let init = match init {
      Literal(lit, ..) => lower_literal(lit)
      _ => raise Failure::Failure("Register init expression must be a literal value")
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

///|
fn RTLILLowering::lower_mem(self : Self, mem : @firrtl.Mem) -> Unit raise {
  guard mem.data_type.is_ground() else {
    raise Failure::Failure("Memory '\{mem.id}' must have a ground data type")
  }
  guard mem.read_latency <= 1 else {
    raise Failure::Failure(
      "Memories with read latency > 1 are not yet supported in RTLIL lowering",
    )
  }
  guard mem.write_latency <= 1 else {
    raise Failure::Failure(
      "Memories with write latency > 1 are not yet supported in RTLIL lowering",
    )
  }
  guard mem.read_under_write is Undefined else {
    raise Failure::Failure(
      "Memories with defined read-under-write behaviour are not yet supported in RTLIL lowering",
    )
  }
  guard mem.readwriters.is_empty() else {
    raise Failure::Failure(
      "Memories with read-write ports are not yet supported in RTLIL lowering",
    )
  }
  let addr_width = @utils.clog2_int(mem.depth)
  let data_width = mem.data_type.width()
  let mask_type = mem.mask_ty
  let mask_granularity = mask_type.mem_mask_granularity()
  let mask_width = mask_type.width()
  let mem_target = { ..self.ann_target, leaf: Some(mem.id) }
  let mut init : Constant? = None
  for ann in self.annotations {
    if ann is MemoryFileInlineAnnotation(target~, filename~, is_hex~) &&
      target == mem_target {
      let content = (self.fs.read_file_to_string)(filename)
      try
        @parse.parse_mem_file(
          content,
          base=if is_hex { 16 } else { 2 },
          start=0,
          end=None,
        )
      catch {
        err => raise err
      } noraise {
        bits => {
          if bits.length() != mem.depth * data_width {
            raise Failure::Failure(
              "Inconsistent memory initialization width: expected \{mem.depth * data_width} bits, got \{bits.length()} bits",
            )
          }
          init = Some(ConstValue(width=bits.length(), bits~))
        }
      }
    }
  }
  let rtlil_mem = self.mod.add_memory(
    id=lower_id(mem.id.inner()),
    width=data_width,
    size=mem.depth,
  )
  let mem_id = ConstString(rtlil_mem.id.to_string())
  if init is Some(init_const) {
    self.mk_cell(
      id=GenId("\{mem.id.inner()}_init"),
      kind=GenId("meminit_v2"),
      parameters={
        "MEMID": mem_id,
        "ABITS": ConstInteger(addr_width),
        "WIDTH": ConstInteger(data_width),
        "WORDS": ConstInteger(mem.depth),
        "PRIORITY": ConstInteger(0),
      },
      connections={
        "ADDR": SigConst(
          ConstValue(width=addr_width, bits=Array::make(addr_width, Zero)),
        ),
        "DATA": SigConst(init_const),
        "EN": SigConst(
          ConstValue(width=data_width, bits=Array::make(data_width, One)),
        ),
      },
    )
  }
  for read_port in mem.readers {
    let is_combinational = mem.read_latency == 0
    self.mk_cell(
      id=GenId("\{mem.id.inner()}.\{read_port}"),
      kind=GenId("memrd"),
      parameters={
        "MEMID": mem_id,
        "ABITS": ConstInteger(addr_width),
        "WIDTH": ConstInteger(data_width),
        "CLK_ENABLE": ConstInteger(if is_combinational { 0 } else { 1 }),
        "CLK_POLARITY": ConstInteger(1),
        "TRANSPARENT": ConstInteger(0),
      },
      connections={
        "CLK": {
          let clk = self.mod.add_wire(
            name=GenId("\{mem.id.inner()}.\{read_port}.clk"),
            width=1,
          )
          if is_combinational {
            SigConst(ConstValue(width=1, bits=[Zero]))
          } else {
            SigWire(clk)
          }
        },
        "ADDR": SigWire(
          self.mod.add_wire(
            name=GenId("\{mem.id.inner()}.\{read_port}.addr"),
            width=addr_width,
          ),
        ),
        "DATA": SigWire(
          self.mod.add_wire(
            name=GenId("\{mem.id.inner()}.\{read_port}.data"),
            width=data_width,
          ),
        ),
        "EN": {
          let en = self.mod.add_wire(
            name=GenId("\{mem.id.inner()}.\{read_port}.en"),
            width=1,
          )
          // yosys requires EN to be 1 if read latency is 0
          if is_combinational {
            SigConst(ConstValue(width=1, bits=[One]))
          } else {
            SigWire(en)
          }
        },
      },
    )
  }
  for port_id, write_port in mem.writers.iter2() {
    let is_combinational = mem.write_latency == 0
    self.mk_cell(
      id=GenId("\{mem.id.inner()}.\{write_port}"),
      kind=GenId("memwr_v2"),
      parameters={
        "MEMID": mem_id,
        "ABITS": ConstInteger(addr_width),
        "WIDTH": ConstInteger(data_width),
        "CLK_ENABLE": ConstInteger(if is_combinational { 0 } else { 1 }),
        "CLK_POLARITY": ConstInteger(1),
        "PORTID": ConstInteger(port_id),
        "PRIORITY_MASK": ConstValue(width=0, bits=[X]),
      },
      connections={
        "CLK": {
          let clk = self.mod.add_wire(
            name=GenId("\{mem.id.inner()}.\{write_port}.clk"),
            width=1,
          )
          if is_combinational {
            SigConst(ConstValue(width=1, bits=[Zero]))
          } else {
            SigWire(clk)
          }
        },
        "ADDR": SigWire(
          self.mod.add_wire(
            name=GenId("\{mem.id.inner()}.\{write_port}.addr"),
            width=addr_width,
          ),
        ),
        "DATA": SigWire(
          self.mod.add_wire(
            name=GenId("\{mem.id.inner()}.\{write_port}.data"),
            width=data_width,
          ),
        ),
        "EN": {
          let en = SigWire(
            self.mod.add_wire(
              name=GenId("\{mem.id.inner()}.\{write_port}.en"),
              width=1,
            ),
          )
          let mask = self.mod.add_wire(
            name=GenId("\{mem.id.inner()}.\{write_port}.mask"),
            width=mask_width,
          )
          let mask_bits = Array::new(capacity=data_width)
          let data_bits_per_mask_bit = data_width / mask_granularity
          let mask_chunks = data_width / data_bits_per_mask_bit
          for chunk_idx in 0..<mask_chunks {
            let chunk_sig = SigChunk(
              signal=SigWire(mask),
              offset=chunk_idx,
              width=1,
            )
            for _ in 0..<data_bits_per_mask_bit {
              mask_bits.push(chunk_sig)
            }
          }
          let mask_and_en = self.mod.add_wire(
            name=GenId("\{mem.id.inner()}.\{write_port}.mask_and_en.y"),
            width=data_width,
          )
          self.mk_cell(
            id=GenId("\{mem.id.inner()}.\{write_port}.mask_and_en"),
            kind=GenId("and"),
            parameters={
              "A_SIGNED": ConstInteger(0),
              "B_SIGNED": ConstInteger(0),
              "A_WIDTH": ConstInteger(data_width),
              "B_WIDTH": ConstInteger(data_width),
              "Y_WIDTH": ConstInteger(data_width),
            },
            connections={
              "A": SigConcat(mask_bits.rev()),
              "B": SigConcat(Array::make(data_width, en)),
              "Y": SigWire(mask_and_en),
            },
          )
          SigWire(mask_and_en)
        },
      },
    )
  }
}

///|
fn RTLILLowering::lower_expr(
  self : Self,
  expr : @firrtl.TypedExpr,
) -> Signal raise {
  match expr {
    Reference(r, ty=_) => self.lower_reference(r, is_lvalue=false)
    Literal(literal, ty=_) => SigConst(lower_literal(literal))
    Mux(cond~, tval~, fval~, ty~) => self.lower_mux(cond~, tval~, fval~, ty~)
    PrimOp(op~, args~, ty~) => self.lower_primop(op~, args~, ty~)
  }
}

///|
fn RTLILLowering::lower_reference(
  self : Self,
  reference : @firrtl.TypedRef,
  is_lvalue~ : Bool,
) -> Signal raise {
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
    None => raise Failure::Failure("Wire '\{id}' not found in module '\{self.mod.name}'")
  }
}

///|
fn lower_literal(literal : @firrtl.Literal) -> Constant raise {
  let (width, value) = match literal {
    UInt(width~, radix=_, value~) => (width, value)
    SInt(width~, radix=_, value~) => (width, value)
  }
  ConstValue(
    width~,
    bits=@utils.bin(value, width~).map(bit => if bit { One } else { Zero }),
  )
}

///|
fn RTLILLowering::mk_cell(
  self : Self,
  id~ : Id,
  kind~ : Id,
  parameters~ : Map[String, Constant],
  connections~ : Map[String, Signal],
) -> Unit raise {
  let _ = self.mod.add_cell(
    name=id,
    cell_name=kind,
    parameters=@utils.map_keys(parameters, (id, _) => PubId(id)),
    connections=@utils.map_keys(connections, (id, _) => PubId(id)),
    attributes={},
  )

}

///|
fn RTLILLowering::lower_mux(
  self : Self,
  cond~ : @firrtl.TypedExpr,
  tval~ : @firrtl.TypedExpr,
  fval~ : @firrtl.TypedExpr,
  ty~ : @firrtl.Type,
) -> Signal raise {
  let id = self.next_gen_id("mux")
  let width = ty.width()
  let y = self.mod.add_wire(name=id.join("_y"), width~)
  self.mk_cell(
    id~,
    kind=GenId("mux"),
    parameters={ "WIDTH": ConstInteger(width) },
    connections={
      "A": self.pad(fval, width),
      "B": self.pad(tval, width),
      "S": self.lower_expr(cond),
      "Y": SigWire(y), // Y = S ? B : A
    },
  )
  SigWire(y)
}

///|
fn RTLILLowering::lower_primop(
  self : Self,
  op~ : @firrtl.PrimOp,
  args~ : Array[@firrtl.TypedExpr],
  ty~ : @firrtl.Type,
) -> Signal raise {
  match (op, args) {
    (
      AsUInt
      | AsSInt
      | AsClock
      | AsAsyncReset
      | Cvt
      | Neg
      | Not
      | Andr
      | Orr
      | Xorr,
      [arg],
    ) => self.lower_primop_1expr(op~, arg~, ty~)
    (
      Add
      | Sub
      | Mul
      | Div
      | Rem
      | Lt
      | Leq
      | Gt
      | Geq
      | Eq
      | Neq
      | Shl
      | Dshl
      | Shr
      | Dshr
      | And
      | Or
      | Xor
      | Cat,
      [lhs, rhs],
    ) => self.lower_primop_2expr(op~, lhs~, rhs~, ty~)
    (Pad | Head | Tail, [arg, Literal(lit, ..)]) =>
      self.lower_primop_1expr1int(op~, arg~, n=lit.as_int())
    (Bits, [arg, Literal(lit_hi, ..), Literal(lit_lo, ..)]) => {
      let signal = self.lower_expr(arg)
      let hi = lit_hi.as_int()
      let lo = lit_lo.as_int()
      SigChunk(signal~, width=hi - lo + 1, offset=hi)
    }
    _ => raise Failure::Failure("Invalid primop '\{op}' with \{args.length()} arguments")
  }
}

///|
fn RTLILLowering::lower_primop_1expr(
  self : Self,
  op~ : @firrtl.PrimOp,
  arg~ : @firrtl.TypedExpr,
  ty~ : @firrtl.Type,
) -> Signal raise {
  if op is (AsUInt | AsSInt | AsClock | AsAsyncReset) {
    return self.lower_expr(arg)
  }
  if op is Cvt {
    if arg.ty().is_signed() {
      return self.lower_expr(arg)
    } else {
      // zero-extend
      return SigConcat([
        SigConst(ConstValue(width=1, bits=[Zero])),
        self.lower_expr(arg),
      ])
    }
  }
  let cell_kind = match op {
    Neg => "neg"
    Not => "not"
    Andr => "reduce_and"
    Orr => "reduce_or"
    Xorr => "reduce_xor"
    _ => @utils.unreachable_code()
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
    connections={ "A": self.lower_expr(arg), "Y": SigWire(y) },
  )
  SigWire(y)
}

///|
fn RTLILLowering::lower_primop_2expr(
  self : Self,
  op~ : @firrtl.PrimOp,
  lhs~ : @firrtl.TypedExpr,
  rhs~ : @firrtl.TypedExpr,
  ty~ : @firrtl.Type,
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
    _ => @utils.unreachable_code()
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

///|
fn RTLILLowering::lower_primop_1expr1int(
  self : Self,
  op~ : @firrtl.PrimOp,
  arg~ : @firrtl.TypedExpr,
  n~ : Int,
) -> Signal raise {
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
    _ => @utils.unreachable_code()
  }
}

///|
fn RTLILLowering::pad(
  self : Self,
  expr : @firrtl.TypedExpr,
  width : Int,
) -> Signal raise {
  let sig = self.lower_expr(expr)
  let ty = expr.ty()
  let old_width = ty.width()
  let is_signed = ty.is_signed()
  if old_width < width {
    let padding = width - old_width
    let pad_bits = Array::new(capacity=padding)
    let sign_ext_bit : Signal = if is_signed {
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

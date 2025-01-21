
pub struct VerilogExporter {
  rtlil_modules: Array[@rtlil.Module]
  verilog_decls: Array[Decl]
  wires_assigned_in_processes: Set[@rtlil.Id]
}

pub fn VerilogExporter::new(modules: Array[@rtlil.Module]) -> VerilogExporter {
  {
    rtlil_modules: modules,
    verilog_decls: [],
    wires_assigned_in_processes: collect_wires_assigned_in_processes(modules),
  }
}

pub type! VerilogExportError {
  UnknownConnection(id~: @rtlil.Id)
  UnknownParameter(id~: @rtlil.Id)
  InvalidUnopCellType(cell_type~: @rtlil.Id)
  InvalidBinopCellType(cell_type~: @rtlil.Id)
  ExpectedIdentifier(expr~: Expr)
  Unreachable(msg~: String)
  UnsupportedMemV2Instance(id~: @rtlil.Id, reason~: String)
  ProcessSwitchWithMultipleCasesNotSupported(span~: @parse.Span)
  ProcessSyncNotSupportedYet
} derive(Show)

fn show_id(id: @rtlil.Id) -> String {
  let name = match id {
    PubId(name) => {
      if is_reserved_keyword(name) {
        "_$" + name
      } else {
        name
      }
    }
    GenId(name) => name + "$"
  }

  name.replace_all(old=".", new="_").replace_all(old="::", new="_")
}

fn expect_identifier(self: Expr) -> String!VerilogExportError {
  match self {
    Identifier(name) => name
    _ => raise ExpectedIdentifier(expr=self)
  }
}

fn as_concat(self: Expr) -> Array[Expr] {
  match self {
    Concat(elems) => elems
    expr => [expr]
  }
}

fn export_signal(self: VerilogExporter, signal: @rtlil.Signal) -> Expr {
  match signal {
    SigConst(constant) => Const(constant)
    SigWire(wire) => Identifier(show_id(wire.name))
    SigChunk(signal~, offset~, width~) => {
      let expr = self.export_signal(signal)

      match width {
        1 => BitSelect(expr~, offset~)
        _ => PartSelect(expr~, offset=Const(ConstInteger(offset)), width~)
      }
    }
    SigConcat(signals) => {
      Concat(signals.iter().map(fn(sig) { self.export_signal(sig) }).collect())
    }
  }
}

fn conditional_not(expr: Expr, polarity: Polarity) -> Expr {
  match polarity {
    Posedge => expr
    Negedge => Unary(op=Not, expr~)
  }
}

fn remove_wire_decl(self: ModuleDecl, name: String) -> Unit {
  let index = self.body.search_by(fn(stmt) {
    match stmt {
      WireDecl(name=wire_name, ..) => wire_name == name
      _ => false
    }
  })

  match index {
    Some(index) => {
      let _ = self.body.remove(index)
    }
    None => ()
  }
}

fn export_cell(self: VerilogExporter, cell: @rtlil.Cell, mod: ModuleDecl) -> Unit!VerilogExportError {
  match cell.type_ {
    GenId("not") => {
      let { op, a, y, .. } = self.extract_unop_cell!(cell)
      mod.body.push(Assign(lhs=y, rhs=Unary(op~, expr=a), kind=Continous))
    }
    GenId(
      "add" | "sub" | "mul" | "div" | "mod" | "eq" | "ne" | "gt" | "lt" | "ge" |
      "le" | "shl" | "shr" | "and" | "or" | "xor" | "xnor"
    ) => {
      let { op, a, b, y, .. } = self.extract_binop_cell!(cell)
      mod.body.push(Assign(lhs=y, rhs=Binary(op~, lhs=a, rhs=b), kind=Continous))
    }
    GenId("dff" | "dffe" | "adff" | "adffe" | "sdff" | "sdffe" as cell_type) => {
      let (uses_reset, uses_enable, sync_reset) = match cell_type {
        "dff" => (false, false, false)
        "dffe" => (false, true, false)
        "adff" => (true, false, false)
        "adffe" => (true, true, false)
        "sdff" => (true, false, true)
        "sdffe" => (true, true, true)
        _ => raise Unreachable(msg="Invalid dff cell type: \{cell_type}")
      }

      let clk = self.get_connection!(cell, "CLK").expect_identifier!()
      let d = self.get_connection!(cell, "D").expect_identifier!()
      let q = self.get_connection!(cell, "Q").expect_identifier!()
      
      let clk_polarity = match get_parameter!(cell, PubId("CLK_POLARITY")) {
        ConstInteger(0) => Negedge
        ConstInteger(1) => Posedge
        _ => raise Unreachable(msg="Invalid CLK_POLARITY parameter in \{cell_type} cell")
      }

      let sensitivity_list: Array[SensitivityListEvent] = [
        { polarity: Some(clk_polarity), signal: clk },
      ]

      let width = match get_parameter!(cell, PubId("WIDTH")) {
        ConstInteger(width) => width
        _ => raise Unreachable(msg="Invalid WIDTH parameter in \{cell_type} cell")
      }

      mod.remove_wire_decl(q)
      mod.body.push(RegDecl(name=q, msb=width - 1, lsb=0, width=1, init=None))

      let mut body = Block([
        Assign(lhs=Identifier(q), rhs=Identifier(d), kind=NonBlocking)
      ])

      if uses_enable {
        let en = self.get_connection!(cell, "EN").expect_identifier!()
        let en_polarity = match get_parameter!(cell, PubId("EN_POLARITY")) {
          ConstInteger(0) => Negedge
          ConstInteger(1) => Posedge
          _ => raise Unreachable(msg="Invalid enable polarity parameter in \{cell_type} cell")
        }

        body = Block([
          If(
            cond=conditional_not(Identifier(en), en_polarity),
            then=body,
            else_=None,
          )
        ])
      }

      if uses_reset {
        let (rst_name, polarity_name, initial_value) = match sync_reset {
          true => ("SRST", "SRST_POLARITY", "SRST_VALUE")
          false => ("ARST", "ARST_POLARITY", "ARST_VALUE")
        }

        let rst = self.get_connection!(cell, rst_name).expect_identifier!()
        let rst_polarity = match get_parameter!(cell, PubId(polarity_name)) {
          ConstInteger(0) => Negedge
          ConstInteger(1) => Posedge
          _ => raise Unreachable(msg="Invalid reset polarity parameter in \{cell_type} cell")
        }

        if not(sync_reset) {
          sensitivity_list.push({ polarity: Some(rst_polarity), signal: rst })
        }

        let rst_value = get_parameter!(cell, PubId(initial_value))

        body = Block([
          If(
            cond=conditional_not(Identifier(rst), rst_polarity),
            then=Block([
              Assign(lhs=Identifier(q), rhs=Const(rst_value), kind=NonBlocking)
            ]),
            else_=Some(body),
          )
        ])
      }

      mod.body.push(Always(sensitivity_list=Events(sensitivity_list), body~))
    }
    GenId("mux") => {
      let a = self.get_connection!(cell, "A")
      let b = self.get_connection!(cell, "B")
      let s = self.get_connection!(cell, "S")
      let y = self.get_connection!(cell, "Y").expect_identifier!()

      mod.body.push(Assign(
        lhs=Identifier(y),
        rhs=Ternary(cond=s, then=b, else_=a),
        kind=Continous,
      ))
    }
    GenId("pmux") => {
      let s_width = match get_parameter!(cell, PubId("S_WIDTH")) {
        ConstInteger(width) => width
        _ => raise Unreachable(msg="Invalid S_WIDTH parameter in $pmux cell")
      }

      let width = match get_parameter!(cell, PubId("WIDTH")) {
        ConstInteger(width) => width
        _ => raise Unreachable(msg="Invalid WIDTH parameter in $pmux cell")
      }

      let a = self.get_connection!(cell, "A")
      let b = self.get_connection!(cell, "B")
      let s = self.get_connection!(cell, "S")
      let y = self.get_connection!(cell, "Y").expect_identifier!()

      let func_name = show_id(cell.name)
      let cases: Array[(Expr, Stmt)] = []
      let mut offset = 0

      for idx in 0..<s_width {
        let bits = @utils.fill(s_width, @parse.BinaryDigit::DontCare)
        bits[s_width - idx - 1] = @parse.BinaryDigit::One
        let pattern = Const(@rtlil.Constant::ConstValue(width=s_width, bits~))
        let slice = PartSelect(expr=Identifier("b"), offset=Const(ConstInteger(offset + width - 1)), width~)
        cases.push((pattern, Assign(lhs=Identifier(func_name), rhs=slice, kind=Blocking)))
        offset += width
      }
      
      let casez = Casez(
        cond=Identifier("s"),
        cases~,
        default=Some(
          Assign(lhs=Identifier(func_name), rhs=Identifier("a"), kind=Blocking),
        ),
      )

      let func = Stmt::FunctionDecl(
        name=func_name,
        output_width=width,
        args=[
          { name: "a", width: width, direction: Input },
          { name: "b", width: width * s_width, direction: Input },
          { name: "s", width: s_width, direction: Input },
        ],
        body=casez,
      )

      mod.body.push(func)
      mod.body.push(Assign(
        lhs=Identifier(y),
        rhs=FunctionCall(name=func_name, args=[a, b, s]),
        kind=Continous,
      ))
    }
    GenId("mem_v2") => {
      // TODO: Validate unused parameters and connections
      let abits = get_int_parameter!(cell, PubId("ABITS"))
      let init = get_parameter!(cell, PubId("INIT"))
      let offset = get_int_parameter!(cell, PubId("OFFSET"))
      let size = get_int_parameter!(cell, PubId("SIZE"))
      let width = get_int_parameter!(cell, PubId("WIDTH"))
      let read_ports = get_int_parameter!(cell, PubId("RD_PORTS"))
      let write_ports = get_int_parameter!(cell, PubId("WR_PORTS"))

      let read_addr = self.get_connection!(cell, "RD_ADDR")
      let read_data = self.get_connection!(cell, "RD_DATA").expect_identifier!()
      let read_enable = self.get_connection!(cell, "RD_EN").as_concat()
      let write_addr = self.get_connection!(cell, "WR_ADDR").as_concat()
      let write_clk = self.get_connection!(cell, "WR_CLK").as_concat()
      let write_data = self.get_connection!(cell, "WR_DATA")
      let write_enable = self.get_connection!(cell, "WR_EN").as_concat()

      if read_enable.length() != read_ports {
        raise UnsupportedMemV2Instance(id=cell.name, reason="Inconsistent RD_EN width")
      }

      if (
        write_addr.length() != write_ports ||
        write_enable.length() != write_ports ||
        write_clk.length() != write_ports
      ) {
        raise UnsupportedMemV2Instance(id=cell.name, reason="Inconsistent WR_ADDR, WR_EN, or WR_CLK width")
      }

      if offset != 0 {
        raise UnsupportedMemV2Instance(id=cell.name, reason="Non-zero OFFSET")
      }

      if init.size() != width * size {
        raise UnsupportedMemV2Instance(id=cell.name, reason="Invalid INIT width, expected \{width * size}, got \{init.size()}")
      }

      let mem_reg_name = show_id(cell.name)
      mod.body.push(RegDecl(name=mem_reg_name, msb=size - 1, lsb=0, width~, init=None))

      mod.body.push(Initial(
        body=Block({
          let bits = match init.as_bits?(span=cell.span) {
            Ok(bits) => bits
            Err(_) => raise Unreachable(msg="Invalid bits in INIT parameter")
          }

          let assignments = Array::new(capacity=size)
          let mut i = 0

          for chunk in @utils.chunk(bits, width) {
            assignments.push(Assign(
              lhs=BitSelect(
                expr=Identifier(mem_reg_name),
                offset=(size - 1) - i,
              ),
              rhs=Const(ConstValue(width~, bits=chunk)),
              kind=Blocking,
            ))

            i += 1
          }

          { assignments.rev_inplace(); assignments }
        }),
      ))

      for i in 0..<read_ports {
        let lhs = PartSelect(
          expr=Identifier(read_data),
          offset=Const(ConstInteger((i + 1) * width - 1)),
          width=width,
        )

        let rhs = PartSelect(
          expr=Identifier(mem_reg_name),
          offset=PartSelect(
            expr=read_addr,
            offset=Const(ConstInteger((i + 1) * abits - 1)),
            width=abits,
          ),
          width=1,
        )

        mod.body.push(Assign(lhs~, rhs~, kind=Continous))
      }

      for i in 0..<write_ports {
        let always_block_body = []

        // check that all the bits are enabled or disabled uniformly
        let write_enable_i = write_enable[i].as_concat()
        if not(@utils.all_eq(write_enable_i)) {
          raise UnsupportedMemV2Instance(id=cell.name, reason="Non-uniform write enable signals for port \{i}")
        }

        always_block_body.push(If(
          cond=write_enable_i[0],
          then=Block([
            Assign(
              lhs=PartSelect(
                expr=Identifier(mem_reg_name),
                offset=PartSelect(
                  expr=write_addr[i],
                  offset=Const(ConstInteger(abits - 1)),
                  width=abits,
                ),
                width=1,
              ),
              rhs=PartSelect(
                expr=write_data,
                offset=Const(ConstInteger((i + 1) * width - 1)),
                width=width,
              ),
              kind=NonBlocking,
            )
          ]),
          else_=None,
        ))

        mod.body.push(Always(
          sensitivity_list=Events([
            { polarity: Some(Posedge), signal: write_clk[i].expect_identifier!() },
          ]),
          body=Block(always_block_body),
        ))
      }
    }
    _ => {
      let parameters = []
      let ports = []

      for param in cell.parameters {
        parameters.push((show_id(param.0), param.1))
      }

      for conn in cell.connections {
        let (id, signal) = conn
        let expr = self.export_signal(signal)
        ports.push((show_id(id), expr))
      }

      let inst = Instance(
        mod=show_id(cell.type_),
        name=show_id(cell.name),
        parameters~,
        ports~,
      )

      mod.body.push(inst)
    }
  }
}

fn export_process_case_stmt(self: VerilogExporter, case_stmt: @rtlil.ProcessCaseStmt) -> Stmt!VerilogExportError {
  match case_stmt {
    @rtlil.ProcessCaseStmt::Assign({ lhs, rhs, span: _ }) => {
      Assign(lhs=self.export_signal(lhs), rhs=self.export_signal(rhs), kind=Blocking)
    }
    @rtlil.ProcessCaseStmt::Switch(switch) => {
      self.export_proc_switch!(switch)
    }
  }
}

fn export_process_stmt(self: VerilogExporter, stmt: @rtlil.ProcessStmt) -> Stmt!VerilogExportError {
  match stmt {
    @rtlil.ProcessStmt::Assign({ lhs, rhs, span: _ }) => {
      Assign(lhs=self.export_signal(lhs), rhs=self.export_signal(rhs), kind=Blocking)
    }
    @rtlil.ProcessStmt::Switch(switch) => {
      self.export_proc_switch!(switch)
    }
    @rtlil.ProcessStmt::Sync(_) => {
      raise ProcessSyncNotSupportedYet
    }
  }
}

fn export_proc_switch(self: VerilogExporter, switch: @rtlil.ProcessSwitch) -> Stmt!VerilogExportError {
  let cases: Array[(Expr, Stmt)] = Array::new(capacity=switch.cases.length())
  let cond = self.export_signal(switch.subject)
  let mut default = None

  for case in switch.cases {
    let stmts = Array::new(capacity=case.body.length())

    for case_stmt in case.body {
      stmts.push(self.export_process_case_stmt!(case_stmt))
    }

    match case.conditions {
      [] => {
        default = Some(Block(stmts))
      }
      [cond] => {
        cases.push((self.export_signal(cond), Block(stmts)))
      }
      _ => raise ProcessSwitchWithMultipleCasesNotSupported(span=switch.span)
    }
  }

  Casez(cond~, cases~, default~)
}

fn export_process(self: VerilogExporter, proc: @rtlil.Process, mod: ModuleDecl) -> Unit!VerilogExportError {
  let body = Array::new(capacity=proc.body.length())

  for stmt in proc.body {
    body.push(self.export_process_stmt!(stmt))
  }

  let always_block = Always(sensitivity_list=All, body=Block(body))
  mod.body.push(always_block)
}

fn collect_wires_assigned_in_switch(switch: @rtlil.ProcessSwitch, acc~: Set[@rtlil.Id]) -> Unit {
  for case in switch.cases {
    for stmt in case.body {
      match stmt {
        Assign({ lhs, .. }) => {
          for wire in lhs.wires() {
            acc.add(wire.name)
          }
        }
        Switch(switch) => {
          collect_wires_assigned_in_switch(switch, acc~)
        }
      }
    }
  }
}

fn collect_wires_assigned_in_process(proc: @rtlil.Process, acc~: Set[@rtlil.Id]) -> Unit {
  for stmt in proc.body {
    match stmt {
      Assign({ lhs, .. }) => {
        for wire in lhs.wires() {
          acc.add(wire.name)
        }
      }
      Switch(switch) => {
        collect_wires_assigned_in_switch(switch, acc~)
      }
      Sync(sync) => {
        for update in sync.updates {
          for wire in update.dst.wires() {
            acc.add(wire.name)
          }
        }
      }
    }
  }
}

fn collect_wires_assigned_in_processes(modules: Array[@rtlil.Module]) -> Set[@rtlil.Id] {
  let wires_assigned_in_processes = Set::new()

  for mod in modules {
    for proc in mod.procs.values() {
      collect_wires_assigned_in_process(proc, acc=wires_assigned_in_processes)
    }
  }

  wires_assigned_in_processes
}

struct UnopCell {
  op: @parse.UnaryOp
  a: Expr
  y: Expr
}

struct BinopCell {
  op: @parse.BinaryOp
  a: Expr
  b: Expr
  y: Expr
}

fn get_connection(self: VerilogExporter, cell: @rtlil.Cell, name: String) -> Expr!VerilogExportError {
  let signal = cell.connections[PubId(name)].or_error!(UnknownConnection(id=PubId(name)))
  self.export_signal(signal)
}

fn get_parameter(cell: @rtlil.Cell, id: @rtlil.Id) -> @rtlil.Constant!VerilogExportError {
  cell.parameters[id].or_error!(UnknownParameter(id~))
}

fn get_int_parameter(cell: @rtlil.Cell, id: @rtlil.Id) -> Int!VerilogExportError {
  match get_parameter!(cell, id) {
    ConstInteger(value) => value
    _ => raise Unreachable(msg="Expected integer parameter")
  }
}

fn extract_unop_cell(self: VerilogExporter, cell: @rtlil.Cell) -> UnopCell!VerilogExportError {
  let a = self.get_connection!(cell, "A")
  let y = self.get_connection!(cell, "Y")

  let op: @parse.UnaryOp = match cell.type_.inner() {
    "not" => Not
    _ => raise InvalidUnopCellType(cell_type=cell.type_)
  }

  { op, a, y }
}

fn extract_binop_cell(self: VerilogExporter, cell: @rtlil.Cell) -> BinopCell!VerilogExportError {
  let a = self.get_connection!(cell, "A")
  let b = self.get_connection!(cell, "B")
  let y = self.get_connection!(cell, "Y")

  let op: @parse.BinaryOp = match cell.type_.inner() {
    "add" => Add
    "sub" => Sub
    "mul" => Mul
    "div" => Div
    "mod" => Mod
    "eq" => Equ
    "ne" => Neq
    "gt" => Gtr
    "lt" => Lss
    "ge" => Geq
    "le" => Leq
    "shl" => Shl
    "shr" => Shr
    "and" => And
    "or" => Or
    "xor" => Xor
    "xnor" => Xnor
    _ => raise InvalidBinopCellType(cell_type=cell.type_)
  }

  { op, a, b, y }
}

fn export_module(self: VerilogExporter, mod: @rtlil.Module) -> Unit!VerilogExportError {
  let verilog_mod: ModuleDecl = {
    name: show_id(mod.name),
    ports: [],
    body: [],
  }

  for wire in mod.wires.values() {
    match wire.port {
      Some({ direction, id: _, optional: _ }) => {
        let type_ = if self.wires_assigned_in_processes.contains(wire.name) { Reg } else { Wire }
        verilog_mod.ports.push({ name: show_id(wire.name), direction, type_, width: wire.width })
      }
      None => {
        if self.wires_assigned_in_processes.contains(wire.name) {
          // Note: A reg declaration in Verilog does not imply a register
          // as it can also represent combinational logic, like here
          verilog_mod.body.push(RegDecl(name=show_id(wire.name), msb=wire.width - 1, lsb=0, width=1, init=None))
        } else {
          verilog_mod.body.push(WireDecl(name=show_id(wire.name), msb=wire.width - 1, lsb=0, init=None))
        }
      }
    }
  }

  for cell in mod.cells.values() {
    self.export_cell!(cell, verilog_mod)
  }

  for proc in mod.procs.values() {
    self.export_process!(proc, verilog_mod) 
  }

  for conn in mod.connections {
    let lhs = self.export_signal(conn.0)
    let rhs = self.export_signal(conn.1)
    verilog_mod.body.push(Assign(lhs~, rhs~, kind=Continous))
  }

  self.verilog_decls.push(Decl::Module(verilog_mod))
}

pub fn export(self: VerilogExporter) -> Array[Decl]!VerilogExportError {
  for mod in self.rtlil_modules {
    self.export_module!(mod)
  }

  self.verilog_decls
}

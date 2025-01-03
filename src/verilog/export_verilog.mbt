
pub struct VerilogExporter {
  rtlil_modules: Array[@rtlil.Module]
  verilog_decls: Array[Decl]
}

pub fn VerilogExporter::new(modules: Array[@rtlil.Module]) -> VerilogExporter {
  { rtlil_modules: modules, verilog_decls: [] }
}

pub type! VerilogExportError {
  UnknownConnection(id~: @rtlil.Id)
  UnknownParameter(id~: @rtlil.Id)
  InvalidUnopCellType(cell_type~: @rtlil.Id)
  InvalidBinopCellType(cell_type~: @rtlil.Id)
  ExpectedIdentifier(expr~: Expr)
  Unreachable(msg~: String)
} derive(Show)

fn show_id(id: @rtlil.Id) -> String {
  match id {
    PubId(name) => {
      if is_reserved_keyword(name) {
        "_" + name
      } else {
        name
      }
    }
    GenId(name) => "$" + name
  }
}

fn expect_identifier(self: Expr) -> String!VerilogExportError {
  match self {
    Identifier(name) => name
    _ => raise ExpectedIdentifier(expr=self)
  }
}

fn expect_concat(self: Expr) -> Array[Expr]!VerilogExportError {
  match self {
    Concat(elems) => elems
    _ => raise Unreachable(msg="Expected concat expr")
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
        _ => PartSelect(expr~, offset~, width~)
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
    GenId("dff" | "adff" | "adffe" | "sdff" | "sdffe" as cell_type) => {
      let (uses_reset, uses_enable, sync_reset) = match cell_type {
        "dff" => (false, false, false)
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

      let sensitivity_list: Array[SensitivityListItem] = [
        { polarity: Some(clk_polarity), signal: clk },
      ]

      let width = match get_parameter!(cell, PubId("WIDTH")) {
        ConstInteger(width) => width
        _ => raise Unreachable(msg="Invalid WIDTH parameter in \{cell_type} cell")
      }

      mod.remove_wire_decl(q)
      mod.body.push(RegDecl(name=q, msb=width - 1, lsb=0, init=None))

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

      mod.body.push(Always(sensitivity_list~, body~))
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
        let slice = PartSelect(expr=Identifier("b"), offset=offset + width - 1, width~)
        cases.push((pattern, Assign(lhs=Identifier(func_name), rhs=slice, kind=Blocking)))
        offset += width
      }
      
      let casez = Casez(
        cond=Identifier("s"),
        cases~,
        default=Some(
          Assign(lhs=Identifier(func_name), rhs=a, kind=Blocking),
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
      Some({ direction, id: _ }) => {
        verilog_mod.ports.push({ name: show_id(wire.name), direction, width: wire.width })
      }
      None => {
        verilog_mod.body.push(WireDecl(name=show_id(wire.name), msb=wire.width - 1, lsb=0, init=None))
      }
    }
  }

  for cell in mod.cells.values() {
    self.export_cell!(cell, verilog_mod)
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

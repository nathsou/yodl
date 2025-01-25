
pub struct VerilogExporter {
  yir_modules: Array[@yir.Module]
  verilog_decls: Array[Decl]
  mut is_inside_always_block: Bool
  mut autoidx: Int
  wires_assigned_in_always_blocks: Set[String]
}

pub fn VerilogExporter::new(modules: Array[@yir.Module]) -> VerilogExporter {
  {
    yir_modules: modules,
    verilog_decls: [],
    is_inside_always_block: false,
    autoidx: 0,
    wires_assigned_in_always_blocks: collect_wires_assigned_in_always_blocks(modules),
  }
}

fn collect_wires_assigned_in_always_blocks(modules: Array[@yir.Module]) -> Set[String] {
  let acc = Set::new()

  for mod in modules {
    for stmt in mod.child_statements() {
      match stmt {
        Process(_) as proc => {
          for sub_stmt in proc.child_statements() {
            match sub_stmt {
              Assign(lhs=Variable(name~, ..), ..) | Reg(data_out=Variable(name~, ..), ..) => {
                acc.add(name)
              }
              _ => ()
            }
          }
        }
        Reg(data_out=Variable(name~, ..), ..) => {
          acc.add(name)
        }
        _ => ()
      }
    }
  }

  acc
}

pub type! VerilogExportError {
  ExpectedIdentifier(expr~: Expr)
} derive(Show)

fn next_id(self: VerilogExporter, prefix: String) -> String {
  let id = self.autoidx
  self.autoidx += 1
  "\{prefix}$\{id}"
}

fn show_id(name: String) -> String {
  let name = if is_reserved_keyword(name) {
    "_$" + name
  } else {
    name
  }

  let new_name = name.replace_all(old=".", new="_").replace_all(old="::", new="_")

  if new_name != name {
    new_name + "$"
  } else {
    new_name
  }
}

struct StmtScope {
  wire_decls: Array[Stmt]
  stmts: Array[Stmt]
}

fn StmtScope::new() -> StmtScope {
  { wire_decls: [], stmts: [] }
}

fn StmtScope::push(self: StmtScope, stmt: Stmt) -> Unit {
  self.stmts.push(stmt)
}

fn StmtScope::append(self: StmtScope, other: StmtScope) -> Unit {
  self.stmts.append(other.stmts)
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

fn conditional_not(expr: Expr, polarity: Polarity) -> Expr {
  match polarity {
    Posedge => expr
    Negedge => Unary(op=Not, expr~)
  }
}

fn export_expr(self: VerilogExporter, expr: @yir.Expr, scope~: StmtScope) -> Expr! {
  match expr {
    Const(value~, ..) => Const(value)
    Variable(name~, ..) => Identifier(show_id(name))
    Unary(op~, expr~, ..) => Unary(op~, expr=self.export_expr!(expr, scope~))
    Binary(op~, lhs~, rhs~, ..) => {
      let v_lhs = self.export_expr!(lhs, scope~)
      let v_rhs = self.export_expr!(rhs, scope~)
      Binary(op~, lhs=v_lhs, rhs=v_rhs)
    }
    Concat(elems~, ..) => {
      let v_elems = Array::new(capacity=elems.length())

      for elem in elems {
        let v_elem = self.export_expr!(elem, scope~)
        v_elems.push(v_elem)
      }

      Concat(v_elems)
    }
    Select(expr~, offset~, width~, span~) => {
      let v_expr = self.export_expr!(expr, scope~)

      let lhs = match v_expr {
        Identifier(_) => v_expr
        _ => {
          let id = self.next_id("sel")
          let kind = if self.is_inside_always_block {
            scope.wire_decls.push(RegDecl(name=id, top=expr.width() - 1, bot=0, width=1, init=None))
            Blocking
          } else {
            scope.wire_decls.push(WireDecl(name=id, top=expr.width() - 1, bot=0, init=None))
            Continous
          }
          
          scope.push(Assign(lhs=Identifier(id), rhs=v_expr, kind~))
          Identifier(id)
        }
      }
      PartSelect(expr=lhs, offset=Const(@yir.Const::from!(offset, width=32, span~)), width=width)
    }
    Mux(subject~, cases~, default~, width~, span=_) => {
      let mux_id = self.next_id("mux")
      let mux = Identifier(mux_id)
      scope.wire_decls.push(RegDecl(name=mux_id, top=width - 1, bot=0, width=1, init=None))
      let prev_is_inside_always_block = self.is_inside_always_block
      self.is_inside_always_block = true
      let v_cases = []

      for case in cases {
        let (cond, value) = case
        let case_scope = StmtScope::new()
        let v_value = self.export_expr!(value, scope=case_scope)
        case_scope.push(Assign(lhs=mux, rhs=v_value, kind=Blocking))

        let block = if case_scope.stmts.length() == 1 {
          case_scope.stmts[0]
        } else {
          Block(case_scope.stmts)
        }

        scope.wire_decls.append(case_scope.wire_decls)
        v_cases.push((Expr::Const(cond), block))
      }

      let v_default = match default {
        Some(expr) => {
          let v_expr = self.export_expr!(expr, scope~)
          Some(Stmt::Assign(lhs=mux, rhs=v_expr, kind=Blocking))
        }
        None => None
      }

      let v_subject = self.export_expr!(subject, scope~)
      let casez = Casez(cond=v_subject, cases=v_cases, default=v_default)

      if not(prev_is_inside_always_block) {
        scope.push(Always(
          sensitivity_list=All,
          body=Block([casez]),
        ))
      } else {
        scope.push(casez)
      }

      self.is_inside_always_block = prev_is_inside_always_block
      mux
    }
    Block(body~, last~, width~, span~) => {
      for stmt in body {
        self.export_stmt!(stmt, scope~)
      }

      match last {
        Some(expr) => self.export_expr!(expr, scope~)
        None => Const(@yir.Const::zeros(width, span~))
      }
    }
  }
}

fn export_stmt(self: VerilogExporter, stmt: @yir.Stmt, scope~: StmtScope) -> Unit! {
  match stmt {
    Expr(expr~, ..) => {
      let v_expr = self.export_expr!(expr, scope~)
      scope.push(Expr(expr=v_expr))
    }
    Wire(name~, width~, ..) => {
      if self.wires_assigned_in_always_blocks.contains(name) {
        scope.wire_decls.push(RegDecl(name=show_id(name), top=width - 1, bot=0, width=1, init=None))
      } else {
        scope.wire_decls.push(WireDecl(name=show_id(name), top=width - 1, bot=0, init=None))
      }
    }
    Reg(
      width~,
      async_reset~,
      clk~,
      data_in~,
      enable~,
      reset~,
      data_out~,
      span~,
    ) => {
      let clk = self.export_expr!(clk, scope~)
      let d = self.export_expr!(data_in, scope~)
      let q = self.export_expr!(data_out, scope~)

      let sensitivity_list: Array[SensitivityListEvent] = [
        { polarity: Some(Posedge), signal: clk },
      ]

      let mut body = Block([
        Assign(lhs=q, rhs=d, kind=NonBlocking)
      ])

      match enable {
        Some(en) => {
          let en = self.export_expr!(en, scope~)

          body = Block([
            If(
              cond=conditional_not(en, Posedge),
              then=body,
              else_=None,
            )
          ])
        }
        _ => ()
      }

      match reset {
        Some(rst) => {
          let rst = self.export_expr!(rst, scope~)
          let rst_value = @yir.Const::zeros(width, span~)
          if async_reset {
            sensitivity_list.push({ polarity: Some(Posedge), signal: rst })
          }

          body = Block([
            If(
              cond=conditional_not(rst, Posedge),
              then=Block([
                Assign(lhs=q, rhs=Const(rst_value), kind=NonBlocking)
              ]),
              else_=Some(body),
            )
          ])
        }
        _ => ()
      }

      scope.push(Always(sensitivity_list=Events(sensitivity_list), body~))
    }
    Assign(lhs~, rhs~, span=_) => {
      let v_lhs = self.export_expr!(lhs, scope~)
      let v_rhs = self.export_expr!(rhs, scope~)
      let kind = if self.is_inside_always_block { Blocking } else { Continous }
      scope.push(Assign(lhs=v_lhs, rhs=v_rhs, kind~))
    }
    Instance(module_name~, ports~, span=_) => {
      let instance_id = self.next_id("inst")
      let v_ports = []

      for port_name, port_expr in ports {
        let v_port_expr = self.export_expr!(port_expr, scope~)
        v_ports.push((port_name, v_port_expr))
      }

      scope.push(Instance(
        mod=show_id(module_name),
        name=instance_id,
        parameters=[],
        ports=v_ports,
      ))
    }
    Process(triggers~, body~, span=_) => {
      let sensitivity_list = match triggers {
        All => All
        Events(events) => {
          let list = Array::new(capacity=events.length())

          for event in events {
            let signal = Identifier(event.signal)
            let polarity = event.polarity.map(fn(p) {
              match p {
                Posedge => Posedge
                Negedge => Negedge
              }
            })

            list.push({ polarity, signal })
          }

          Events(list)
        }
      }

      let body_scope = StmtScope::new()

      for stmt in body {
        self.export_stmt!(stmt, scope=body_scope)
      }

      scope.wire_decls.append(body_scope.wire_decls)
      let body = Block(body_scope.stmts)
      scope.push(Always(sensitivity_list~, body~))
    }
    Memory(_) => {
      raise Failure("Memory statements are not supported yet")
    }
  }
}

fn export_module(self: VerilogExporter, mod: @yir.Module) -> Unit! {
  let verilog_mod: ModuleDecl = {
    name: show_id(mod.name),
    ports: mod.ports.map(fn(port) {
      {
        name: show_id(port.name),
        type_: Wire,
        width: port.width,
        direction: port.direction,
      }
    }),
    body: [],
  }

  let scope = StmtScope::new()

  for stmt in mod.body {
    self.export_stmt!(stmt, scope~)
  }

  verilog_mod.body = scope.wire_decls + scope.stmts

  self.verilog_decls.push(Decl::Module(verilog_mod))
}

pub fn export(self: VerilogExporter) -> Array[Decl]! {
  for mod in self.yir_modules {
    self.export_module!(mod)
  }

  self.verilog_decls
}

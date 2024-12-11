
pub(readonly) struct Elaborator {
  mut autoidx: UInt
  modules: Map[String, @rtlil.Module]
}

pub fn Elaborator::new() -> Elaborator {
  { autoidx: 0, modules: {} }
}

type! ElaboratorError {
  ModuleAlreadyDeclared(name~: String, span~: @parse.Span)
  UnknownIdentifier(name~: String, span~: @parse.Span)
  Unsupported(message~: String, span~: @parse.Span)
} derive(Show)

fn elaborate_module(self: Elaborator, mod: @parse.ModuleDecl) -> Unit! {
  let mod_def = @rtlil.Module::new(PubId(mod.name))

  let mut port_id: UInt = 1

  for input in mod.inputs {
    let _ = mod_def.add_wire!(
      name=PubId(input.name),
      width=1,
      port=Some({ direction: Input, id: port_id }),
      attributes=[],
    )

    port_id += 1
  }

  for output in mod.outputs {
    let _ = mod_def.add_wire!(
      name=PubId(output.name),
      width=1,
      port=Some({ direction: Output, id: port_id }),
      attributes=[],
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

fn elaborate_expr(self: Elaborator, expr: @parse.Expr, mod: @rtlil.Module) -> @rtlil.Signal! {
  match expr {
    Identifier(name~, span~, ..) => {
      match mod.wires[PubId(name)] {
        Some(wire) => SigWire(wire)
        None => raise UnknownIdentifier(name~, span~)
      }
    }
    Natural(span~, ..) => {
      raise Unsupported(message="Natural literals are not supported yet", span~)
    }
    Unary(span~, ..) => {
      raise Unsupported(message="Unary operators are not supported yet", span~)
    }
    Binary(op~, lhs~, rhs~, ..) => {
      let mod_name = match op {
        And => "and"
        Or => "or"
        Xor => "xor"
        Nand => "nand"
        Nor => "nor"
        Xnor => "xnor"
      }

      let output = mod.add_wire!(
        name=GenId("\{mod_name}_y_\{self.next_genidx()}"),
        width=1,
        port=None,
        attributes=[],
      )
      
      let _ = mod.add_cell!(
        type_=GenId(mod_name),
        name=GenId("\{mod_name}_\{self.next_genidx()}"),
        parameters=[
          { id: PubId("A_SIGNED"), value: ConstInteger(0) },
          { id: PubId("A_WIDTH"), value: ConstInteger(1) },
          { id: PubId("B_SIGNED"), value: ConstInteger(0) },
          { id: PubId("B_WIDTH"), value: ConstInteger(1) },
          { id: PubId("Y_WIDTH"), value: ConstInteger(1) },
        ],
        connections={
          let connections: Map[@rtlil.Id, @rtlil.Signal] = {}
          connections[@rtlil.PubId("A")] = self.elaborate_expr!(lhs, mod)
          connections[@rtlil.PubId("B")] = self.elaborate_expr!(rhs, mod)
          connections[@rtlil.PubId("Y")] = SigWire(output)
          connections
        },
      )

      SigWire(output)
    }
    _ => raise Unsupported(message="Unsupported expression", span=expr.span())
  }
}

fn elaborate_stmt(self: Elaborator, stmt: @parse.Stmt, mod: @rtlil.Module) -> Unit! {
  match stmt {
    Let(name~, expr~, ..) => {
      let wire = mod.add_wire!(
        name=PubId(name),
        width=1,
        port=None,
        attributes=[],
      )

      let sig2 = self.elaborate_expr!(expr, mod)

      mod.connect!(SigWire(wire), sig2)
    }
    Assign(lhs~, rhs~, ..) => {
      let sig1 = self.elaborate_expr!(lhs, mod)
      let sig2 = self.elaborate_expr!(rhs, mod)
      mod.connect!(sig1, sig2)
    }
  }
}

pub fn elaborate_decl(self: Elaborator, decl: @parse.Decl) -> Unit! {
  match decl {
    Module(mod) => {
      self.elaborate_module!(mod)
    }
  }
}

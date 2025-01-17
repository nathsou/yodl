
pub struct FlattenPass {
  modules: Map[Id, Module]
}

pub fn FlattenPass::new(modules: Map[Id, Module]) -> FlattenPass {
  { modules, }
}

fn flatten_wire(wire~: Wire, parent~: Module, prefix~: String) -> Wire {
  {
    name: join(prefix, wire.name),
    width: wire.width,
    port: if prefix.is_empty() { wire.port } else { None },
    attributes: wire.attributes,
    span: wire.span,
    mod: parent,
  }
}

fn flatten_signal(signal~: Signal, parent~: Module, prefix~: String) -> Signal {
    match signal {
      SigConst(constant) => SigConst(constant)
      SigWire(wire) => SigWire(flatten_wire(wire~, parent~, prefix~))
      SigChunk(signal~, offset~, width~) => SigChunk(signal=flatten_signal(signal~, parent~, prefix~), offset~, width~)
      SigConcat(signals) => SigConcat(signals.map(fn(signal) { flatten_signal(signal~, parent~, prefix~) }))
    }
}

fn join(prefix: String, name: Id) -> Id {
  if prefix.is_empty() {
    name
  } else {
    GenId("\{prefix}.\{name.inner()}")
  }
}

fn flatten_cell(self: FlattenPass, cell~: Cell, parent~: Module, prefix~: String) -> Unit {
    match self.modules[cell.type_] {
      Some(mod) => {
        let prefix = join(prefix, cell.name).inner()

        for wire in mod.wires.values() {
          let new_wire = flatten_wire(wire~, parent~, prefix~)

          if parent.wires.contains(new_wire.name) {
            // TODO: handle wire id conflicts
          }
          
          parent.wires[new_wire.name] = new_wire
        }

        for cell in mod.cells.values() {
          flatten_cell(self, cell~, parent~, prefix~)
        }

        for conn in mod.connections {
          let (lhs, rhs) = conn
          let new_lhs = flatten_signal(signal=lhs, parent~, prefix~)
          let new_rhs = flatten_signal(signal=rhs, parent~, prefix~)
          parent.connections.push((new_lhs, new_rhs))
        }
      }
      None => {
        let new_cell: Cell = {
          name: join(prefix, cell.name),
          type_: cell.type_,
          attributes: cell.attributes,
          parameters: cell.parameters,
          connections: {},
          span: cell.span,
        }

        for id, signal in cell.connections {
          let new_signal = flatten_signal(signal~, parent~, prefix~)
          new_cell.connections[id] = new_signal
        }

        parent.cells[new_cell.name] = new_cell
      }
    }
}

fn flatten_module(self: FlattenPass, mod~: Module) -> Module {
  let new_mod: Module = Module::new(mod.name)

  for wire in mod.wires.values() {
    let new_wire = flatten_wire(wire~, parent=new_mod, prefix="")
    new_mod.wires[new_wire.name] = new_wire
  }

  for cell in mod.cells.values() {
    flatten_cell(self, cell~, parent=new_mod, prefix="")
  }

  for conn in mod.connections {
    new_mod.connections.push(conn)
  }

  new_mod
}

pub fn FlattenPass::run(self: FlattenPass) -> Map[Id, Module] {
  let result = Map::new(capacity=self.modules.size())

  for mod in self.modules.values() {
    let new_mod = flatten_module(self, mod~)
    result[new_mod.name] = new_mod
  }

  result
}

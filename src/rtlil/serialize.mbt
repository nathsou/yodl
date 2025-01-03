
pub(all) struct Serializer {
  autoidx: Int
  modules: Map[String, Module]
  builder: StringBuilder
  mut indent: Int
}

fn write(self: Serializer, s: String) -> Unit {
  self.builder.write_string("  ".repeat(self.indent))
  self.builder.write_string(s)
}

pub fn Serializer::new(autoidx~: Int, modules~: Map[String, Module]) -> Serializer {
  { autoidx, modules, builder: StringBuilder::new(), indent: 0 }
}

pub impl Show for Value with output(self, logger) {
  let bits = String::concat(self.bits.map(fn(bit) { bit.to_string() }))
  logger.write_string("\{self.width}'\{bits}")
}

pub impl Show for Constant with output(self, logger) {
  match self {
    ConstValue(width~, bits~) => {
      let bits = String::concat(bits.map(fn(bit) { bit.to_string() })).pad_start(width, '0')
      logger.write_string("\{width}'\{bits}")
    }
    ConstInteger(n) => logger.write_string(n.to_string())
    ConstString(s) => logger.write_string("\"\{s}\"")
  }
}

fn show_attribute(id: Id, value: Constant) -> String {
  "attribute \{id} \{value}"
}

fn show_parameter(id: Id, value: Constant) -> String {
  "parameter \{id} \{value}"
}

fn write_wire(self: Serializer, wire: Wire) -> Unit {
  for attrib in wire.attributes {
    self.write(show_attribute(attrib.0, attrib.1) + "\n")
  }

  self.write("wire")

  if wire.width != 1 {
    self.builder.write_string(" width \{wire.width}")
  }

  match wire.port {
    Some(port) => {
      self.builder.write_string(" \{port.direction} \{port.id}")
    }
    None => ()
  }

  self.builder.write_string(" \{wire.name}\n")
}

pub impl Show for Signal with output(self, logger) {
  match self {
    SigConst(c) => logger.write_string(c.to_string())
    SigWire(w) => logger.write_string(w.name.to_string())
    SigChunk(signal~, offset~, width~) => {
      if width == 1 {
        logger.write_string("\{signal} [\{offset}]")
      } else {
        logger.write_string("\{signal} [\{offset}:\{(offset + 1) - width}]")
      }
    }
    SigConcat(signals) => {
      logger.write_iter(
        prefix="{ ",
        signals.iter(),
        sep=" ",
        suffix=" }",
      )
    }
  }
}

fn emit_cell(self: Serializer, cell: Cell) -> Unit {
  for attrib in cell.attributes {
    self.write(show_attribute(attrib.0, attrib.1) + "\n")
  }

  self.write("cell \{cell.type_} \{cell.name}\n")
  self.indent += 1

  for param in cell.parameters {
    self.write(show_parameter(param.0, param.1) + "\n")
  }

  for id, sig in cell.connections {
    self.write("connect \{id} \{sig}\n")
  }

  self.indent -= 1

  self.write("end\n")
}

fn emit_module(self: Serializer, mod: Module) -> Unit {
  for attrib in mod.attributes {
    self.write(show_attribute(attrib.0, attrib.1) + "\n")
  }

  self.write("module \{mod.name}\n")

  self.indent += 1

  for param in mod.parameters {
    self.write(show_parameter(param.0, param.1) + "\n")
  }

  for wire in mod.wires.values() {
    self.write_wire(wire)
  }

  for cell in mod.cells.values() {
    self.emit_cell(cell)
  }

  for conn in mod.connections {
    self.write("connect \{conn.0} \{conn.1}\n")
  }

  self.indent -= 1

  self.write("end\n")
}

pub impl Show for Serializer with output(self, logger) {
  self.write("autoidx \{self.autoidx}\n")

  for mod in self.modules.values() {
    self.emit_module(mod)
  }

  logger.write_string(self.builder.to_string())
}

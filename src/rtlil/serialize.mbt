
pub(all) struct Serializer {
  autoidx: UInt
  modules: Map[String, Module]
  builder: StringBuilder
  mut indent: Int
}

fn write(self: Serializer, s: String) -> Unit {
  self.builder.write_string("  ".repeat(self.indent))
  self.builder.write_string(s)
}

pub fn Serializer::new(autoidx~: UInt, modules~: Map[String, Module]) -> Serializer {
  { autoidx, modules, builder: StringBuilder::new(), indent: 0 }
}

pub impl Show for BinaryDigit with output(self, logger) {
  logger.write_char(match self {
    Zero => '0'
    One => '1'
    X => 'x'
    Z => 'z'
    M => 'm'
    DontCare => '-'
  })
}

pub impl Show for Value with output(self, logger) {
  let bits = String::concat(self.bits.map(fn(bit) { bit.to_string() }))
  logger.write_string("\{self.width}'\{bits}")
}

pub impl Show for Constant with output(self, logger) {
  match self {
    ConstValue(v) => logger.write_string(v.to_string())
    ConstInteger(i) => logger.write_string(i.to_string())
    ConstString(s) => logger.write_string(s)
  }
}

pub impl Show for Attribute with output(self, logger) {
  logger.write_string("attribute \{self.id} \{self.value}")
}

pub impl Show for Parameter with output(self, logger) {
  logger.write_string("parameter \{self.id} \{self.value}")
}

pub impl Show for Wire with output(self, logger) {
  logger.write_string("wire")

  if self.width != 1 {
    logger.write_string(" width \{self.width}")
  }

  match self.port {
    Some(port) => {
      let dir = match port.direction {
        Input => "input"
        Output => "output"
      }

      logger.write_string(" \{dir} \{port.id}")
    }
    None => ()
  }
   
  logger.write_string(" \{self.name}")
}

pub impl Show for Signal with output(self, logger) {
  match self {
    SigConst(c) => logger.write_string(c.to_string())
    SigWire(w) => logger.write_string(w.name.to_string())
    SigChunk(signal~, offset~, width~) => {
      if width == 1 {
        logger.write_string("\{signal}[\{offset}]")
      } else {
        logger.write_string("\{signal}[\{offset}:\{offset + width}]")
      }
    }
    SigConcat(signals) => {
      logger.write_string("{")
      logger.write_iter(signals.iter(), sep=", ")
      logger.write_string("}")
    }
  }
}

fn emit_cell(self: Serializer, cell: Cell) -> Unit {
  for attrib in cell.attributes {
    self.write("\{attrib}\n")
  }

  self.write("cell \{cell.type_} \{cell.name}\n")
  self.indent += 1

  for param in cell.parameters {
    self.write("\{param}\n")
  }

  for id, sig in cell.connections {
    self.write("connect \{id} \{sig}\n")
  }

  self.indent -= 1

  self.write("end\n")
}

fn emit_module(self: Serializer, mod: Module) -> Unit {
  for attrib in mod.attributes {
    self.write("\{attrib}\n")
  }

  self.write("module \{mod.name}\n")

  self.indent += 1

  for param in mod.parameters {
    self.write("\{param}\n")
  }

  for wire in mod.wires.values() {
    self.write("\{wire}\n")
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

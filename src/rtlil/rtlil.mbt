// https://yosyshq.readthedocs.io/projects/yosys/en/latest/yosys_internals/formats/rtlil_rep.html

pub type! RTLILError {
  WireAlreadyDeclared(name~: Id, span~: @parse.Span)
  CellAlreadyDeclared(name~: Id, span~: @parse.Span)
  IncompatibleWidths(width1~: Int, width2~: Int, span~: @parse.Span)
}

pub impl @parse.Spanned for RTLILError with span(self) -> @parse.Span {
  match self {
    WireAlreadyDeclared(span~, ..) => span
    CellAlreadyDeclared(span~, ..) => span
    IncompatibleWidths(span~, ..) => span
  }
}

pub impl Show for RTLILError with output(self, logger) -> Unit {
  match self {
    WireAlreadyDeclared(name~, ..) => {
      logger.write_string("Wire '\{name}' already declared")
    }
    CellAlreadyDeclared(name~, ..) => {
      logger.write_string("Cell '\{name}' already declared")
    }
    IncompatibleWidths(width1~, width2~, ..) => {
      logger.write_string("Incompatible widths: \{width1} and \{width2}")
    }
  }

  logger.write_string(self.show_context())
}

pub(all) enum Id {
    PubId(String) // Publically visible identifiers
    GenId(String) // Auto-generated identifiers
} derive(Eq, Hash)

pub impl Show for Id with output(self, logger) {
    match self {
      PubId(id) => logger.write_string("\\\{id}")
      GenId(id) => logger.write_string("$\{id}")
    }
}

pub fn inner(self: Id) -> String {
  match self {
    PubId(id) => id
    GenId(id) => id
  }
}

pub fn join(self: Id, suffix: String) -> Id {
  match self {
    PubId(id) => PubId(id + suffix)
    GenId(id) => GenId(id + suffix)
  }
}

// A value consists of a width in bits and a bit representation, most significant bit first
pub(all) struct Value {
    width: Int
    bits: Array[@parse.BinaryDigit]
}

pub(all) enum Constant {
  ConstValue(width~: Int, bits~: Array[@parse.BinaryDigit])
  ConstInteger(Int)
  ConstString(String)
}

pub fn size(self: Constant) -> Int {
  match self {
    ConstValue(width~, ..) => width
    ConstInteger(_) => 32
    ConstString(str) => str.length() * 8
  }
}

pub(all) struct PortSpec {
  id: Int
  direction: @parse.PortDirection
  optional: Bool
}

pub(all) struct Wire {
  name: Id
  width: Int
  port: PortSpec?
  attributes: Map[Id, Constant]
  mod: Module
  span: @parse.Span
}

// A signal is anything that can be applied to a cell port, i.e. a constant value, all bits or a selection of bits from a wire, or concatenations of those.
pub(all) enum Signal {
  SigConst(Constant)
  SigWire(Wire)
  SigChunk(signal~: Signal, offset~: Int, width~: Int)
  SigConcat(Array[Signal])
}

pub fn size(self: Signal) -> Int {
  match self {
    SigConst(c) => c.size()
    SigWire(w) => w.width
    SigChunk(width~, ..) => width
    SigConcat(signals) => @utils.sum(signals.iter().map(Signal::size))
  }
}

pub(all) struct Cell {
  name: Id
  mut type_: Id
  attributes: Map[Id, Constant]
  parameters: Map[Id, Constant]
  connections: Map[Id, Signal]
  span: @parse.Span
}

pub(all) struct Module {
  name: Id
  wires: Map[Id, Wire]
  cells: Map[Id, Cell]
  attributes: Map[Id, Constant]
  parameters: Map[Id, Constant]
  connections: Array[(Signal, Signal)]
}

pub fn Module::new(name: Id) -> Module {
  { name, wires: {}, cells: {}, attributes: {}, parameters: {}, connections: [] }
}

pub fn add_wire(
  self: Module, 
  name~: Id,
  width~: Int,
  port~: PortSpec? = None,
  attributes~: Map[Id, Constant] = {},
  span~: @parse.Span,  
) -> Wire!RTLILError {
  if self.wires.contains(name) {
    raise WireAlreadyDeclared(name~, span~)
  }

  let wire: Wire = {
    mod: self,
    name,
    width,
    port,
    attributes,
    span,
  }

  self.wires[name] = wire

  wire
}

pub fn add_cell(
  self: Module,
  name~: Id,
  type_~: Id,
  connections~: Map[Id, Signal] = {},
  attributes~: Map[Id, Constant] = {},
  parameters~: Map[Id, Constant] = {},
  span~: @parse.Span,
) -> Cell!RTLILError {
  if self.cells.contains(name) {
    raise CellAlreadyDeclared(name~, span~)
  }

  let cell: Cell = {
    name,
    type_,
    connections,
    attributes,
    parameters,
    span,
  }

  self.cells[name] = cell

  cell
}

pub fn connect(self: Module, sig1: Signal, sig2: Signal, span~: @parse.Span) -> Unit!RTLILError {
  if sig1.size() != sig2.size() {
    raise IncompatibleWidths(width1=sig1.size(), width2=sig2.size(), span~)
  }

  self.connections.push((sig1, sig2))
}

pub fn ports(mod: Module) -> Iter[PortSpec] {
  @utils.filter_map(mod.wires.values(), fn(wire) { wire.port })
}

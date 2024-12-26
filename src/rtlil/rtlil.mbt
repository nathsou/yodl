// https://yosyshq.readthedocs.io/projects/yosys/en/latest/yosys_internals/formats/rtlil_rep.html

pub(readonly) type! RTLILError {
  WireAlreadyDeclared(name~: Id)
  CellAlreadyDeclared(name~: Id)
  IncompatibleWidths(width1~: Int, width2~: Int)
} derive(Show)

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
    bits: Array[BinaryDigit]
}

pub(all) enum BinaryDigit {
  Zero; One; X; Z; M; DontCare
} derive(Eq)

pub(all) enum Constant {
  ConstValue(width~: Int, bits~: Array[BinaryDigit])
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
}

pub(all) struct Wire {
  name: Id
  width: Int
  port: PortSpec?
  attributes: Map[Id, Constant]
  mod: Module
}

// A signal is anything that can be applied to a cell port, i.e. a constant value, all bits or a selection of bits from a wire, or concatenations of those.
pub(all) enum Signal {
  SigConst(Constant)
  SigWire(Wire)
  SigChunk(signal~: Signal, offset~: Int, width~: Int)
  SigConcat(Array[Signal])
}

fn sum(iter: Iter[Int]) -> Int {
  iter.fold(fn(a, b) { a + b }, init=0)
}

pub fn size(self: Signal) -> Int {
  match self {
    SigConst(c) => c.size()
    SigWire(w) => w.width
    SigChunk(width~, ..) => width
    SigConcat(signals) => sum(signals.iter().map(fn(sig) { sig.size() }))
  }
}

pub(all) struct Cell {
  name: Id
  type_: Id
  attributes: Map[Id, Constant]
  parameters: Map[Id, Constant]
  connections: Map[Id, Signal]
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

pub fn add_wire(self: Module, name~: Id, width~: Int, port~: PortSpec? = None, attributes~: Map[Id, Constant] = {}) -> Wire!RTLILError {
  if self.wires.contains(name) {
    raise WireAlreadyDeclared(name~)
  }

  let wire: Wire = {
    mod: self,
    name,
    width,
    port,
    attributes,
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
) -> Cell!RTLILError {
  if self.cells.contains(name) {
    raise CellAlreadyDeclared(name~)
  }

  let cell: Cell = {
    name,
    type_,
    connections,
    attributes,
    parameters,
  }

  self.cells[name] = cell

  cell
}

pub fn connect(self: Module, sig1: Signal, sig2: Signal) -> Unit!RTLILError {
  if sig1.size() != sig2.size() {
    raise IncompatibleWidths(width1=sig1.size(), width2=sig2.size())
  }

  self.connections.push((sig1, sig2))
}

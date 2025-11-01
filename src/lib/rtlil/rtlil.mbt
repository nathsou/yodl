using @parse { type PortDir }

// https://yosyshq.readthedocs.io/projects/yosys/en/latest/yosys_internals/formats/rtlil_rep.html

pub(all) enum Id {
    PubId(String) // Publicly visible identifiers
    GenId(String) // Auto-generated identifiers
} derive(Eq, Hash)
  
pub impl Show for Id with output(self, logger) {
    match self {
      PubId(id) => logger.write_string("\\\{id}")
      GenId(id) => logger.write_string("$\{id}")
    }
}

pub fn Id::inner(self: Self) -> String {
  match self {
    PubId(id) => id
    GenId(id) => id
  }
}

pub fn Id::join(self: Self, suffix: String) -> Self {
  match self {
    PubId(id) => PubId(id + suffix)
    GenId(id) => GenId(id + suffix)
  }
}

pub impl Add for Id with add(self, other) -> Id {
  self.join(other.inner())
}

pub(all) enum BinaryDigit {
  Zero; One; X; Z; M; DontCare
} derive(Eq, Hash)

pub fn BinaryDigit::is_determined(self: Self) -> Bool {
  match self {
    Zero | One => true
    _ => false
  }
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

pub(all) struct Bits {
  bits: Array[BinaryDigit]
  mut value: BigInt?
}

pub impl Hash for Bits with hash_combine(self, hasher) {
  for bit in self.bits {
    hasher.combine(bit)
  }
}

pub impl Eq for Bits with equal(self, other) {
  self.bits == other.bits
}

pub impl Show for Bits with output(self, logger) {
  match self.value {
    Some(value) => logger.write_string(value.to_string())
    None => {
      for bit in self.bits {
        logger.write_string(bit.to_string())
      }
    }
  }
}

// A value consists of a width in bits and a bit representation, most significant bit first
pub(all) struct Value {
    width: Int
    bits: Array[BinaryDigit]
}

pub(all) enum Constant {
  ConstValue(width~: Int, bits~: Array[BinaryDigit])
  ConstInteger(Int)
  ConstString(String)
}

pub fn Constant::size(self: Self) -> Int {
  match self {
    ConstValue(width~, ..) => width
    ConstInteger(_) => 32
    ConstString(str) => str.length() * 8
  }
}

pub(all) struct PortSpec {
  id: Int
  direction: PortDir
  optional: Bool
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

pub fn Signal::size(self: Self) -> Int {
  match self {
    SigConst(c) => c.size()
    SigWire(w) => w.width
    SigChunk(width~, ..) => width
    SigConcat(signals) => @utils.sum(signals.iter().map(Signal::size))
  }
}

pub(all) struct Cell {
  name: Id
  mut cell_name: Id
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

pub fn Module::add_wire(
  self: Self, 
  name~: Id,
  width~: Int,
  port~: PortSpec? = None,
  attributes~: Map[Id, Constant] = {},
) -> Wire raise {
  if self.wires.contains(name) {
    raise Failure("Wire '\{name}' is already declared")
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

pub fn Module::add_cell(
  self: Self,
  name~: Id,
  cell_name~: Id,
  parameters~: Map[Id, Constant] = {},
  connections~: Map[Id, Signal] = {},
  attributes~: Map[Id, Constant] = {},
) -> Cell raise {
  if self.cells.contains(name) {
    raise Failure("Cell '\{name}' is already declared")
  }

  let cell: Cell = {
    name,
    cell_name,
    connections,
    attributes,
    parameters,
  }

  self.cells[name] = cell

  cell
}

pub fn Module::connect(self: Self, sig1: Signal, sig2: Signal) -> Unit raise {
  if sig1.size() != sig2.size() {
    raise Failure("Cannot connect signals of different widths: \{sig1.size()} and \{sig2.size()}")
  }

  self.connections.push((sig1, sig2))
}

pub fn Module::ports(mod: Self) -> Iter[PortSpec] {
  mod.wires
    .values()
    .filter(wire => !wire.port.is_empty())
    .map(wire => wire.port.unwrap())
}

pub(all) struct Design {
  mut autoidx: Int
  modules: Map[Id, Module]
}

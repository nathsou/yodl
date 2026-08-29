pub(all) struct Path {
  packages: Array[String]
  elem: String
} derive(Eq)

pub impl Hash for Path with hash_combine(self, hasher) {
  for pkg in self.packages {
    hasher.combine(pkg)
  }

  hasher.combine(self.elem)
}

pub impl Show for Path with output(self, logger) {
  for pkg in self.packages {
    logger.write_string(pkg)
    logger.write_string("::")
  }

  logger.write_string(self.elem)
}

pub fn Path::new(packages: Array[String], elem: String) -> Path {
  { packages, elem }
}

pub fn Path::prepend(self: Path, packages: Array[String]) -> Path {
  let joined = packages + self.packages
  joined.dedup()
  Path::new(joined, self.elem)
}

pub(all) enum ParamSort {
  NatSort  // N: Nat
  TypeSort // T: type  or  T: Type
} derive(Eq)

pub impl Show for ParamSort with output(self, logger) {
  match self {
    NatSort => logger.write_string("Nat")
    TypeSort => logger.write_string("Type")
  }
}

pub(all) struct StaticParam {
  name: String
  sort: ParamSort
  span: Span
}

pub(all) struct ModuleParameter {
  name: String
  sort: ParamSort
  span: Span
}

pub(all) struct ModuleSignature {
    path: Path
    params: Array[ModuleParameter]
    attributes: Map[String, Attribute]
    ports: Array[Port]
    span: Span
}

impl Eq for ModuleSignature with equal(self, other) {
  self.path == other.path && self.span.file == other.span.file
}

pub fn ModuleSignature::get_param(self: ModuleSignature, name: String) -> ModuleParameter? {
  for param in self.params {
    if param.name == name {
      return Some(param)
    }
  }

  None
}

pub fn ModuleSignature::get_port(self: Self, name: String) -> Port? {
  for port in self.ports {
    if port.name == name {
      return Some(port)
    }
  }

  None
}

pub fn ModuleSignature::inputs(self: ModuleSignature) -> Iter[Port] {
  self.ports.iter().filter(port => port.dir == Input)
}

pub fn ModuleSignature::outputs(self: ModuleSignature) -> Iter[Port] {
  self.ports.iter().filter(port => port.dir == Output)
}

pub fn ModuleSignature::inouts(self: ModuleSignature) -> Iter[Port] {
  self.ports.iter().filter(port => port.dir == InOut)
}

pub(all) enum PortDir {
  Input; Output; InOut
} derive(Eq)

pub impl Show for PortDir with output(self, logger) {
  logger.write_string(match self {
    Input => "input"
    Output => "output"
    InOut => "inout"
  })
}

pub(all) struct Port {
  name: String
  ty: Type
  dir: PortDir
  span: Span
  optional: Bool
  attributes: Map[String, Attribute]
}

pub(all) struct ModuleDecl {
    path: Path
    params: Array[ModuleParameter]
    attributes: Map[String, Attribute]
    ports: Array[Port]
    body: Array[Stmt]
    span: Span
}

pub fn ModuleDecl::signature(self: Self) -> ModuleSignature {
  {
    path: self.path,
    params: self.params,
    attributes: self.attributes,
    ports: self.ports,
    span: self.span,
  }
}

// FIRRTL https://github.com/chipsalliance/firrtl-spec

using @parse { type PortDir }

pub fn min_version() -> (Int, Int, Int) {
  (4, 1, 0)
}

pub(all) enum Id {
  Ident(String)
  Literal(String)
} derive (Eq, Hash)

pub fn Id::from(s: String) -> Id {
  Ident(s)
}

pub fn Id::value(self: Id) -> String {
  match self {
    Ident(s) | Literal(s) => s
  }
}

pub fn Id::inner(self: Id) -> String {
  match self {
    Ident(s) => s
    Literal(s) => s
  }
}

pub fn Id::join(self: Id, str: String) -> Id {
  match self {
    Ident(s) => Ident(s + str)
    Literal(s) => Literal(s + str)
  }
}

pub(all) struct Circuit[T] {
  version: (Int, Int, Int)
  id: Id
  annotations: Array[Annotation]
  decls: Array[Decl[T]]
}

pub type UntypedCircuit = Circuit[Unit]
pub type TypedCircuit = Circuit[Type]

pub(all) struct AnnotationTarget {
  circuit: String
  mod: Id
  leaf: Id?
} derive (Eq)

pub impl Show for AnnotationTarget with output(self, logger) -> Unit {
  logger.write_string("\{self.circuit}")

  logger.write_string(".\{self.mod}")

  if self.leaf is Some(leaf) {
    logger.write_string(".\{leaf}")
  }
}

pub(all) enum Annotation {
  MemoryFileInlineAnnotation(target~: AnnotationTarget, filename~: String, is_hex~: Bool)
  InlineAnnotation(target~: AnnotationTarget)
  FlattenAnnotation(target~: AnnotationTarget)
  BlackBoxPathAnnotation(target~: AnnotationTarget, path~: String)
}

pub impl ToJson for Annotation with to_json(self) -> Json {
  let map = match self {
    MemoryFileInlineAnnotation(target~, filename~, is_hex~) => {
      {
        "class": "firrtl.annotations.MemoryFileInlineAnnotation",
        "target": Show::to_string(target),
        "filename": filename,
        "hexOrBinary": if is_hex { "h" } else { "b" },
        "originalMemoryNameOpt": target.leaf.unwrap().value(),
      }
    }
    InlineAnnotation(target~) => {
      {
        "class": "firrtl.passes.InlineAnnotation",
        "target": Show::to_string(target),
      }
    }
    FlattenAnnotation(target~) => {
      {
        "class": "firrtl.transforms.FlattenAnnotation",
        "target": Show::to_string(target),
      }
    }
    BlackBoxPathAnnotation(target~, path~) => {
      {
        "class": "firrtl.transforms.BlackBoxPathAnno",
        "target": Show::to_string(target),
        "path": path,
      }
    }
  }

  map.to_json()
}

pub fn Annotation::target(self: Annotation) -> AnnotationTarget {
  match self {
    MemoryFileInlineAnnotation(target~, ..) | InlineAnnotation(target~) | FlattenAnnotation(target~) | BlackBoxPathAnnotation(target~, ..) => target
  }
}

pub fn Annotation::with_target(self: Annotation, new_target: AnnotationTarget) -> Annotation {
  match self {
    MemoryFileInlineAnnotation(target=_, filename~, is_hex~) => {
      MemoryFileInlineAnnotation(target=new_target, filename~, is_hex~)
    }
    InlineAnnotation(target=_) => InlineAnnotation(target=new_target)
    FlattenAnnotation(target=_) => FlattenAnnotation(target=new_target)
    BlackBoxPathAnnotation(target=_, path~) => BlackBoxPathAnnotation(target=new_target, path~)
  }
}

pub(all) enum Decl[T] {
  Module(Module[T])
  ExtModule(ExtModule)
}

pub fn[T] Decl::id(self: Decl[T]) -> Id {
  match self {
    Module(mod) => mod.id
    ExtModule(extmod) => extmod.id
  }
}

pub type UntypedDecl = Decl[Unit]
pub type TypedDecl = Decl[Type]

pub(all) enum Stmt[T] {
  Node(id~: Id, expr~: Expr[T])
  Wire(id~: Id, ty~: Type)
  Inst(id~: Id, of~: Id, sig~: ModuleSignature)
  Reg(id~: Id, ty~: Type, clock~: Expr[T])
  RegReset(id~: Id, ty~: Type, clock~: Expr[T], reset~: Expr[T], init~: Expr[T])
  Mem(Mem)
  Connect(Reference[T], Expr[T])
  When(When[T])
  Command(Command[T])
  Skip
}

pub(all) struct Mem {
    id: Id
    is_flat: Bool
    data_type: Type
    depth: Int
    mask_ty: Type
    read_latency: Int
    write_latency: Int
    read_under_write: ReadUnderWrite
    readers: Array[Id]
    writers: Array[Id]
    readwriters: Array[Id]
}

pub fn Type::mem_mask(self: Type) -> Type {
  match self {
    Const(inner) => Const(inner.mem_mask())
    UInt(_) | SInt(_) | Clock | AsyncReset | Reset => UInt(1)
    Bundle(fields) => Bundle(fields.map(field => {
        id: field.id,
        flip: field.flip,
        ty: field.ty.mem_mask(),
      }
    ))
    Vec(elem_ty, size) => Vec(elem_ty.mem_mask(), size)
  }
}

pub struct MemPorts {
  read: Type
  write: Type
  read_write: Type
}

pub fn Mem::reader_writer_types(self: Mem) -> MemPorts {
  let depth_clog2 = @utils.clog2_int(self.depth)
  
  {
    read: Bundle([
      BundleField::from(id=Id::from("addr"), ty=UInt(depth_clog2)),
      BundleField::from(id=Id::from("en"), ty=UInt(1)),
      BundleField::from(id=Id::from("clk"), ty=Clock),
      BundleField::from(id=Id::from("data"), ty=self.data_type, flip=true),
    ]),
    write: Bundle([
      BundleField::from(id=Id::from("addr"), ty=UInt(depth_clog2)),
      BundleField::from(id=Id::from("en"), ty=UInt(1)),
      BundleField::from(id=Id::from("clk"), ty=Clock),
      BundleField::from(id=Id::from("data"), ty=self.data_type),
      BundleField::from(id=Id::from("mask"), ty=self.mask_ty),
    ]),
    read_write: Bundle([
      BundleField::from(id=Id::from("addr"), ty=UInt(depth_clog2)),
      BundleField::from(id=Id::from("en"), ty=UInt(1)),
      BundleField::from(id=Id::from("clk"), ty=Clock),
      BundleField::from(id=Id::from("rdata"), ty=self.data_type, flip=true),
      BundleField::from(id=Id::from("wmode"), ty=UInt(1)),
      BundleField::from(id=Id::from("wdata"), ty=self.data_type),
      BundleField::from(id=Id::from("wmask"), ty=self.mask_ty),
    ]),
  }
}

pub fn Mem::as_bundle(self: Mem) -> Type {
  let ports = self.reader_writer_types()
  let fields: Array[BundleField] = []

  for r in self.readers {
    fields.push(BundleField::from(flip=true, id=r, ty=ports.read))
  }

  for w in self.writers {
    fields.push(BundleField::from(flip=true, id=w, ty=ports.write))
  }

  for rw in self.readwriters {
    fields.push(BundleField::from(flip=true, id=rw, ty=ports.read_write))
  }

  Bundle(fields)
}

pub fn Mem::ports(self: Mem) -> Array[(Id, Type)] {
  let ports: Array[(Id, Type)] = []
  let port_types = self.reader_writer_types()

  for r in self.readers {
    ports.push((r, port_types.read))
  }

  for w in self.writers {
    ports.push((w, port_types.write))
  }

  for rw in self.readwriters {
    ports.push((rw, port_types.read_write))
  }

  ports
}

pub type UntypedStmt = Stmt[Unit]
pub type TypedStmt = Stmt[Type]

pub(all) struct When[T] {
  cond: Expr[T]
  body: Array[Stmt[T]]
  mut otherwise: Array[Stmt[T]]?
}

pub type UntypedWhen = When[Unit]
pub type TypedWhen = When[Type]

pub fn[T] Expr::build_mux_tree(cases: Array[(Expr[T], Expr[T])], default: Expr[T]) -> Expr[T] {
  fn aux(cases: @list.List[(Expr[T], Expr[T])], acc: Expr[T]) -> Expr[T] {
    match cases {
      Empty => acc
      More((cond, tval), tail~) => aux(tail, Mux(cond~, tval~, fval=acc, ty=tval.ty()))
    }
  }

  aux(@list.List({ cases.rev_in_place(); cases }), default)
}

pub fn[T] Expr::build_when_tree(cases: Array[(Expr[T], Array[Stmt[T]])], default~: Array[Stmt[T]]? = None) -> Array[Stmt[T]] {
  fn aux(cases: @list.List[(Expr[T], Array[Stmt[T]])], acc: Array[Stmt[T]]?) -> Array[Stmt[T]] {
    match cases {
      Empty => match acc {
        Some(stmts) => stmts
        None => [Skip]
      }
      More((cond, body), tail~) => {
        let when: When[T] = {
          cond,
          body,
          otherwise: acc,
        }

        aux(tail, Some([When(when)]))
      }
    }
  }

  aux(@list.List({ cases.rev_in_place(); cases }), default)
}

pub(all) enum ReadUnderWrite { Undefined; Old; New }

pub(all) enum Expr[T] {
  Reference(Reference[T], ty~: T)
  Literal(Literal, ty~: T)
  Mux(cond~: Expr[T], tval~: Expr[T], fval~: Expr[T], ty~: T)
  PrimOp(op~: PrimOp, args~: Array[Expr[T]], ty~: T)
} derive (Eq)

pub trait Default {
  default() -> Self
}

pub impl Default for Unit with default() -> Unit { () }

pub fn[T: Default] mk_ref(r: Reference[T]) -> Expr[T] {
  Reference(r, ty=T::default())
}

pub fn[T: Default] mk_lit(lit: Literal) -> Expr[T] {
  Literal(lit, ty=T::default())
}

pub fn[T: Default] mk_mux(cond: Expr[T], tval: Expr[T], fval: Expr[T]) -> Expr[T] {
  Mux(cond~, tval~, fval~, ty=T::default())
}

pub fn[T: Default] mk_prim(op: PrimOp, args: Array[Expr[T]]) -> Expr[T] {
  PrimOp(op~, args~, ty=T::default())
}

pub type UntypedExpr = Expr[Unit]
pub type TypedExpr = Expr[Type]

pub fn Expr::uint(n: Int) -> UntypedExpr {
  Literal(Literal::uint(n), ty=())
}

pub fn[T] Expr::ty(self: Expr[T]) -> T {
  match self {
    Reference(_, ty~) | Literal(_, ty~) | Mux(ty~, ..) | PrimOp(ty~, ..) => ty
  }
}

pub(all) enum Literal {
  UInt(width~: Int, radix~: Int?, value~: BigInt)
  SInt(width~: Int, radix~: Int?, value~: BigInt)
} derive (Eq, Hash)

pub fn Literal::uint(n: Int) -> Literal {
  guard n >= 0 else {
    abort("Literal::uint: n must be non-negative")
  }

  let value = BigInt::from_int(n)
  // `clog2` gives the number of bits needed to address a value, not the
  // number of bits needed to represent it.  Powers of two (for example the
  // bit-slice index 16) therefore need one additional bit.
  let width = @utils.significant_bits(value)
  UInt(width~, radix=None, value~)
}

pub fn Literal::sint(n: Int) -> Literal {
  let abs_value = BigInt::from_int(n.abs())
  let width = @utils.max(@utils.clog2(abs_value).to_int(), 1) + (if n < 0 { 1 } else { 0 })
  SInt(width~, radix=None, value=BigInt::from_int(n))
}

pub fn Literal::as_bigint(self: Literal) -> BigInt {
  match self {
    UInt(value~, ..) | SInt(value~, ..) => value
  }
}

pub fn Literal::as_int(self: Literal) -> Int {
  match self {
    UInt(value~, ..) | SInt(value~, ..) => value.to_int()
  }
}

pub(all) enum Reference[T] {
  Id(Id, ty~: T)
  StaticIndexing(lhs~: Reference[T], index~: Int, ty~: T)
  DynamicIndexing(lhs~: Reference[T], index~: Expr[T], ty~: T)
  FieldAccess(lhs~: Reference[T], field~: Id, ty~: T)
}

// Supporting arbitrary dynamic indexing would make initialisation analysis undecidable
impl[T] Hash for Reference[T] with hash_combine(self, hasher) {
  match self {
    Id(id, ty=_) => Hash::hash_combine(id, hasher)
    StaticIndexing(lhs~, index~, ty=_) => {
      Hash::hash_combine(lhs, hasher)
      hasher.combine_int(index)
    }
    DynamicIndexing(..) => {
      @utils.fail("Dynamic indexing is not supported in hashing")
    }
    FieldAccess(lhs~, field~, ty=_) => {
      Hash::hash_combine(lhs, hasher)
      Hash::hash_combine(field, hasher)
    }
  }
}

impl[T] Eq for Reference[T] with equal(self, other) {
  match (self, other) {
    (Id(id1, ty=_), Id(id2, ty=_)) => id1 == id2
    (StaticIndexing(lhs=lhs1, index=idx1, ty=_), StaticIndexing(lhs=lhs2, index=idx2, ty=_)) => lhs1 == lhs2 && idx1 == idx2
    (DynamicIndexing(..), DynamicIndexing(..)) => @utils.fail("Dynamic indexing is not supported in equality")
    (FieldAccess(lhs=lhs1, field=field1, ty=_), FieldAccess(lhs=lhs2, field=field2, ty=_)) => lhs1 == lhs2 && field1 == field2
    _ => false
  }
}

pub fn[T: Default] mk_id(id: Id) -> Reference[T] {
  Id(id, ty=T::default())
}

pub fn[T: Default] mk_static_indexing(lhs~: Reference[T], index~: Int) -> Reference[T] {
  StaticIndexing(lhs~, index~, ty=T::default())
}

pub fn[T: Default] mk_dynamic_indexing(lhs~: Reference[T], index~: Expr[T]) -> Reference[T] {
  DynamicIndexing(lhs~, index~, ty=T::default())
}

pub fn[T: Default] mk_field_access(lhs~: Reference[T], field~: Id) -> Reference[T] {
  FieldAccess(lhs~, field~, ty=T::default())
}

pub fn[T] Reference::ty(self: Reference[T]) -> T {
  match self {
    Id(_, ty~) | StaticIndexing(ty~, ..) | DynamicIndexing(ty~, ..) | FieldAccess(ty~, ..) => ty
  }
}

pub type UntypedRef = Reference[Unit]
pub type TypedRef = Reference[Type]

pub fn TypedRef::as_expr(self: TypedRef) -> TypedExpr {
  Reference(self, ty=self.ty())
}

pub fn[T] Reference::indexing_from(lhs~: Reference[T], index~: Expr[T], ty~: T) -> Reference[T] {
  match index {
    Literal(UInt(value~, ..) | SInt(value~, ..), ..) => StaticIndexing(lhs~, index=value.to_int(), ty~)
    _ => DynamicIndexing(lhs~, index~, ty~)
  }
}

pub fn[T] Reference::as_id(self: Reference[T]) -> Id? {
  match self {
    Id(id, ..) => Some(id)
    _ => None
  }
}

pub(all) struct Module[T] {
  public: Bool
  id: Id
  ports: Array[Port]
  body: Array[Stmt[T]]
}

pub type UntypedModule = Module[Unit]
pub type TypedModule = Module[Type]

pub(all) enum Flow {
  Sink; Source; Duplex
} derive(Hash, Eq)

pub fn Flow::swap(self: Flow) -> Flow {
  match self {
    Sink => Source
    Source => Sink
    Duplex => Duplex
  }
}

pub fn Flow::from_port_dir(self: PortDir) -> Flow {
  match self {
    Input => Sink
    Output => Source
    InOut => Duplex
  }
}

pub(all) struct PortSignature {
  dir: PortDir
  ty: Type
}

pub fn PortSignature::from(port: Port) -> PortSignature {
  { dir: port.dir, ty: port.ty }
}

pub(all) struct ModuleSignature {
  ports: Map[String, PortSignature]
}

pub fn ModuleSignature::as_bundle(self: ModuleSignature) -> Type {
  let fields: Array[BundleField] = []

  for name, port in self.ports.iter2() {
    fields.push(BundleField::from(id=Id::from(name), ty=port.ty, flip=port.dir is Input))
  }

  Bundle(fields)
}

pub(all) struct ExtModule {
  id: Id
  ports: Array[Port]
  defname: String?
  parameters: Array[(String, ParameterLiteral)]
}

pub(all) enum ParameterLiteral {
  IntLiteral(BigInt)
  StringLiteral(String)
  RawStringLiteral(String)
}

pub(all) struct Port {
  dir: PortDir
  id: Id
  ty: Type
}

pub(all) enum Type {
  Const(Type)
  Clock
  Reset
  AsyncReset
  UInt(Int)
  SInt(Int)
  Bundle(Array[BundleField])
  Vec(Type, Int)
} derive(Eq)

pub fn Type::bool() -> Type {
  UInt(1)
}

pub fn Type::is_signed(self: Type) -> Bool {
  match self {
    Const(inner) => inner.is_signed()
    SInt(_) => true
    _ => false
  }
}

// see FIRRTL spec. 5.0 "Type Equivalence"
pub fn Type::is_equivalent_to(self: Type, other: Type) -> Bool {
  match (self, other) {
    (UInt(_), UInt(_)) => true
    (SInt(_), SInt(_)) => true
    (Clock, Clock) => true
    (Reset, Reset | UInt(1) | AsyncReset) => true
    (AsyncReset, AsyncReset | Reset) => true
    (Vec(ty1, size1), Vec(ty2, size2)) => size1 == size2 && ty1.is_equivalent_to(ty2)
    (Bundle(fields1), Bundle(fields2)) => {
      if fields1.length() != fields2.length() {
        return false
      }
      
      for f1, f2 in @utils.zip2(fields1, fields2) {
        if f1.id != f2.id || f1.flip != f2.flip || !f1.ty.is_equivalent_to(f2.ty) {
          return false
        }
      }

      true
    }
    _ => false
  }
}

pub fn Type::without_const(self: Type) -> Type {
  let mut ty = self

  while ty is Const(inner) {
    ty = inner
  }

  ty
}

pub fn Type::no_flips(self: Type) -> Type {
  match self {
    Bundle(fields) => Bundle(fields.map(field => {
        id: field.id,
        flip: false,
        ty: field.ty.no_flips(),
      }
    ))
    Vec(elem_ty, size) => Vec(elem_ty.no_flips(), size)
    Const(inner) => Const(inner.no_flips())
    other => other
  }
}

pub fn Type::bundle_fields(self: Type) -> Array[BundleField] {
  match self {
    Bundle(fields) => fields
    _ => abort("Expected Bundle type, found \{self}")
  }
}

pub fn Type::is_aggregate(self: Type) -> Bool {
  match self {
    Bundle(_) | Vec(_, _) => true
    Const(inner) => inner.is_aggregate()
    _ => false
  }
}

pub fn Type::is_ground(self: Type) -> Bool {
  !self.is_aggregate()
}

pub fn Type::width(self: Type) -> Int {
  match self {
    UInt(width) | SInt(width) => width
    Clock | Reset | AsyncReset => 1
    Bundle(fields) => @utils.sum(fields.map(field => field.ty.width()).iter())
    Vec(elem_ty, size) => elem_ty.width() * size
    Const(inner) => inner.width()
  }
}

fn Type::leaf_types(self: Type) -> Array[Type] {
  let leaf_types = []

  fn aux(ty: Type) -> Unit {
    match ty {
      Bundle(fields) => {
        for field in fields {
          aux(field.ty)
        }
      }
      Vec(elem_ty, size) => {
        for _ in 0..<size {
          aux(elem_ty)
        }
      }
      _ => {
        leaf_types.push(ty)
      }
    }
  }

  aux(self)

  leaf_types
}

// Returns the maximum number of bits that can be masked together in a memory of this type
pub fn Type::mem_mask_granularity(self: Type) -> Int {
  let leaf_widths = self.leaf_types().map(Type::width)
  leaf_widths[1:].fold((acc, w) => @utils.gcd(acc, w), init=leaf_widths[0])
}

pub(all) struct BundleField {
  id: Id
  flip: Bool
  ty: Type
} derive(Eq)

pub fn BundleField::from(id~: Id, ty~: Type, flip~: Bool = false) -> BundleField {
  { id, flip, ty }
}

pub(all) enum PrimOp {
  AsUInt; AsSInt; AsClock; AsAsyncReset; Cvt
  Neg; Not; Andr; Orr; Xorr
  Add; Sub; Mul; Div; Rem
  Lt; Leq; Gt; Geq; Eq; Neq
  Dshl; Dshr
  And; Or; Xor; Cat
  Pad; Shl; Shr; Head; Tail
  Bits
} derive (Eq, Hash)

pub(all) enum Command[T] {
  Printf(clk~: Expr[T], en~: Expr[T], fmt~: String, args~: Array[Expr[T]])
  Assert(clk~: Expr[T], pred~: Expr[T], en~: Expr[T], fmt~: String, args~: Array[Expr[T]])
  Stop(clk~: Expr[T], en~: Expr[T], code~: Int)
}

pub type UntypedCommand = Command[Unit]
pub type TypedCommand = Command[Type]
    
pub fn[T] Command::replace_en(self: Command[T], update_en: (Expr[T]) -> Expr[T]) -> Command[T] {
  match self {
    Printf(clk~, en~, fmt~, args~) => Printf(clk~, en=update_en(en), fmt~, args~)
    Assert(clk~, pred~, en~, fmt~, args~) => Assert(clk~, pred~, en=update_en(en), fmt~, args~)
    Stop(clk~, en~, code~) => Stop(clk~, en=update_en(en), code~)
  }
}

pub fn[T] Command::name(self: Command[T]) -> String {
  match self {
    Printf(..) => "printf"
    Assert(..) => "assert"
    Stop(..) => "stop"
  }
}

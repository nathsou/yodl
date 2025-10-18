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
  annotations: Array[Json]
  decls: Array[Decl[T]]
}

pub typealias Circuit[Unit] as UntypedCircuit
pub typealias Circuit[Type] as TypedCircuit

pub(all) enum Decl[T] {
  Module(Module[T])
  ExtModule(ExtModule)
}

pub typealias Decl[Unit] as UntypedDecl
pub typealias Decl[Type] as TypedDecl

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
    data_type: Type
    depth: Int
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
  let depth_clog2 = @utils.clog2(BigInt::from_int(self.depth)).to_int()
  
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
      BundleField::from(id=Id::from("data"), ty=self.data_type, flip=true),
      BundleField::from(id=Id::from("mask"), ty=self.data_type.mem_mask()),
    ]),
    read_write: Bundle([
      BundleField::from(id=Id::from("addr"), ty=UInt(depth_clog2)),
      BundleField::from(id=Id::from("en"), ty=UInt(1)),
      BundleField::from(id=Id::from("clk"), ty=Clock),
      BundleField::from(id=Id::from("rdata"), ty=self.data_type, flip=true),
      BundleField::from(id=Id::from("wmode"), ty=UInt(1)),
      BundleField::from(id=Id::from("wdata"), ty=self.data_type),
      BundleField::from(id=Id::from("wmask"), ty=self.data_type.mem_mask()),
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

pub typealias Stmt[Unit] as UntypedStmt
pub typealias Stmt[Type] as TypedStmt

pub(all) struct When[T] {
  cond: Expr[T]
  body: Array[Stmt[T]]
  mut otherwise: Array[Stmt[T]]?
}

pub typealias When[Unit] as UntypedWhen
pub typealias When[Type] as TypedWhen

pub fn[T] Expr::build_mux_tree(cases: Array[(Expr[T], Expr[T])], default: Expr[T]) -> Expr[T] {
  fn aux(cases: @list.List[(Expr[T], Expr[T])], acc: Expr[T]) -> Expr[T] {
    match cases {
      Empty => acc
      More((cond, tval), tail~) => aux(tail, Mux(cond~, tval~, fval=acc, ty=tval.ty()))
    }
  }

  aux(@list.List::from_array({ cases.rev_inplace(); cases }), default)
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

  aux(@list.List::from_array({ cases.rev_inplace(); cases }), default)
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

pub typealias Expr[Unit] as UntypedExpr
pub typealias Expr[Type] as TypedExpr

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
  let width = @utils.max(@utils.clog2(value).to_int(), 1)
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

pub typealias Reference[Unit] as UntypedRef
pub typealias Reference[Type] as TypedRef

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

pub typealias Module[Unit] as UntypedModule
pub typealias Module[Type] as TypedModule

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

pub typealias Command[Unit] as UntypedCommand
pub typealias Command[Type] as TypedCommand
    
pub fn[T] Command::replace_en(self: Command[T], update_en: (Expr[T]) -> Expr[T]) -> Command[T] {
  match self {
    Printf(clk~, en~, fmt~, args~) => Printf(clk~, en=update_en(en), fmt~, args~)
    Assert(clk~, pred~, en~, fmt~, args~) => Assert(clk~, pred~, en=update_en(en), fmt~, args~)
    Stop(clk~, en~, code~) => Stop(clk~, en=update_en(en), code~)
  }
}

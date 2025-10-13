// FIRRTL https://github.com/chipsalliance/firrtl-spec

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

pub typealias Circuit[TypedExpr] as TypedCircuit

pub(all) enum Decl[T] {
  Module(Module[T])
  ExtModule(ExtModule)
}

pub typealias Decl[TypedExpr] as TypedDecl

pub(all) enum Stmt[T] {
  Node(id~: Id, expr~: T)
  Wire(id~: Id, ty~: Type)
  Inst(id~: Id, of~: Id, sig~: ModuleSignature)
  Reg(id~: Id, ty~: Type, clock~: T)
  RegReset(id~: Id, ty~: Type, clock~: T, reset~: T, init~: T)
  Mem(
    id~: Id,
    data_type~: Type,
    depth~: Int,
    read_latency~: Int,
    write_latency~: Int,
    read_under_write~: ReadUnderWrite,
    readers~: Array[Id],
    writers~: Array[Id],
    readwriters~: Array[Id],
  )
  Connect(Reference[T], T)
  When(When[T])
  Invalidate(Reference[T])
  Command(Command[T])
  Skip
}

pub typealias Stmt[TypedExpr] as TypedStmt

pub(all) struct When[T] {
  cond: T
  body: Array[Stmt[T]]
  mut otherwise: Array[Stmt[T]]?
}

pub(all) enum ReadUnderWrite { Undefined; Old; New }

pub(all) enum Expr {
  Reference(Reference[Expr])
  Literal(Literal)
  Mux(cond~: Expr, tval~: Expr, fval~: Expr)
  PrimOp(op~: PrimOp, args~: Array[Expr])
}

pub fn Expr::uint(n: Int) -> Expr {
  Literal(Literal::uint(n))
}

pub enum TypedExpr {
  Reference(reference~: Reference[TypedExpr], ty~: Type)
  Literal(value~: Literal, ty~: Type)
  Mux(cond~: TypedExpr, tval~: TypedExpr, fval~: TypedExpr, ty~: Type)
  PrimOp(op~: PrimOp, args~: Array[TypedExpr], ty~: Type)
}

pub fn TypedExpr::ty(self: TypedExpr) -> Type {
  match self {
    Reference(ty~, ..) | Literal(ty~, ..) | Mux(ty~, ..) | PrimOp(ty~, ..) => ty
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

pub fn Literal::value(self: Literal) -> BigInt {
  match self {
    UInt(value~, ..) | SInt(value~, ..) => value
  }
}

pub(all) enum Reference[T] {
  Id(Id)
  StaticIndexing(lhs~: Reference[T], index~: Int)
  DynamicIndexing(lhs~: Reference[T], index~: T)
  FieldAccess(lhs~: Reference[T], field~: Id)
}

pub typealias Reference[TypedExpr] as TypedReference

pub fn Reference::indexing_from(lhs~: Reference[Expr], index~: Expr) -> Reference[Expr] {
  match index {
    Literal(UInt(value~, ..) | SInt(value~, ..)) => StaticIndexing(lhs~, index=value.to_int())
    _ => DynamicIndexing(lhs~, index~)
  }
}

pub fn[T] Reference::as_id(self: Reference[T]) -> Id? {
  match self {
    Id(id) => Some(id)
    _ => None
  }
}

pub(all) struct Module[T] {
  public: Bool
  id: Id
  ports: Array[Port]
  body: Array[Stmt[T]]
}

pub typealias Module[TypedExpr] as TypedModule

pub(all) struct PortSignature {
  flow: @parse.Flow
  ty: Type
}

pub(all) struct ModuleSignature {
  ports: Map[String, PortSignature]
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
  flow: @parse.Flow
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
  UIntInferred
  SIntInferred
  Bundle(Array[BundleField])
  Vec(Type, Int)
} derive(Eq)

pub fn Type::bool() -> Type {
  UInt(1)
}

pub(all) struct BundleField {
  id: Id
  flip: Bool
  ty: Type
} derive(Eq)

pub fn BundleField::from(id~: Id, ty~: Type, flip~: Bool = false) -> BundleField {
  { id, flip, ty }
}

pub struct MemReaderWriterTypes {
  reader_type: Type
  writer_type: Type
}

pub fn Type::mem_mask(self: Type) -> Type {
  match self {
    UInt(_) | UIntInferred | SInt(_) | SIntInferred |
    Clock | AsyncReset | Reset | Const(_) => UInt(1)
    Bundle(fields) => Bundle(fields.map(field => {
        id: field.id,
        flip: field.flip,
        ty: field.ty.mem_mask(),
      }
    ))
    Vec(elem_ty, size) => Vec(elem_ty.mem_mask(), size)
  }
}

pub fn Type::mem_reader_writer_types(self: Type, depth~: Int) -> MemReaderWriterTypes {
  let depth_clog2 = @utils.clog2(BigInt::from_int(depth)).to_int()
  
  {
    reader_type: Bundle([
      BundleField::from(id=Id::from("clk"), ty=Clock),
      BundleField::from(id=Id::from("en"), ty=UInt(1)),
      BundleField::from(id=Id::from("addr"), ty=UInt(depth_clog2)),
    ]),
    writer_type: Bundle([
      BundleField::from(id=Id::from("clk"), ty=Clock),
      BundleField::from(id=Id::from("en"), ty=UInt(1)),
      BundleField::from(id=Id::from("addr"), ty=UInt(depth_clog2)),
      BundleField::from(id=Id::from("data"), ty=self),
      BundleField::from(id=Id::from("mask"), ty=self.mem_mask()),
    ]),
  }
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
  Printf(clk~: T, en~: T, fmt~: String, args~: Array[T])
  Assert(clk~: T, pred~: T, en~: T, fmt~: String, args~: Array[T])
  Stop(clk~: T, en~: T, code~: Int)
}

pub fn[T] Command::replace_en(self: Command[T], update_en: (T) -> T) -> Command[T] {
  match self {
    Printf(clk~, en~, fmt~, args~) => Printf(clk~, en=update_en(en), fmt~, args~)
    Assert(clk~, pred~, en~, fmt~, args~) => Assert(clk~, pred~, en=update_en(en), fmt~, args~)
    Stop(clk~, en~, code~) => Stop(clk~, en=update_en(en), code~)
  }
}
    
pub trait FIRRTLPass {
  run(self: Self, TypedCircuit) -> TypedCircuit raise
}

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

pub(all) struct Circuit {
  version: (Int, Int, Int)
  id: Id
  annotations: Array[Json]
  decls: Array[Decl]
}

pub(all) enum Decl {
  Module(Module)
  ExtModule(ExtModule)
}

pub(all) enum Stmt {
  Node(id~: Id, expr~: Expr)
  Wire(id~: Id, ty~: Type)
  Inst(id~: Id, of~: Id, sig~: ModuleSignature)
  Reg(id~: Id, ty~: Type, clock~: Expr)
  RegReset(id~: Id, ty~: Type, clock~: Expr, reset~: Expr, init~: Expr)
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
  Connect(Reference, Expr)
  When(When)
  Invalidate(Reference)
  Command(Command)
  Skip
}

pub(all) struct When {
  cond: Expr
  body: Array[Stmt]
  mut otherwise: Array[Stmt]?
}

pub(all) enum ReadUnderWrite { Undefined; Old; New }

pub(all) enum Expr {
  Reference(Reference)
  Int(BigInt)
  Literal(Literal)
  Mux(cond~: Expr, tval~: Expr, fval~: Expr)
  PrimOp(op~: PrimOp, args~: Array[Expr])
}

pub(all) enum Literal {
  UInt(width~: Int, radix~: Int?, value~: BigInt)
  SInt(width~: Int, radix~: Int?, value~: BigInt)
} derive (Eq, Hash)

pub fn Literal::value(self: Literal) -> BigInt {
  match self {
    UInt(value~, ..) | SInt(value~, ..) => value
  }
}

pub(all) enum Reference {
  Id(Id)
  StaticIndexing(lhs~: Reference, index~: Int)
  DynamicIndexing(lhs~: Reference, index~: Expr)
  FieldAccess(lhs~: Reference, field~: Id)
}

pub impl Show for Reference with output(self, logger) {
  match self {
    Id(id) => logger.write_string(id.value())
    StaticIndexing(lhs~, index~) => {
      lhs.output(logger)
      logger.write_char('[')
      logger.write_string(index.to_string())
      logger.write_char(']')
    }
    DynamicIndexing(lhs~, index=_) => {
      lhs.output(logger)
      logger.write_string("[expr]")
    }
    FieldAccess(lhs~, field~) => {
      lhs.output(logger)
      logger.write_char('.')
      logger.write_string(field.value())
    }
  }
}

pub fn Reference::indexing_from(lhs~: Reference, index~: Expr) -> Reference {
  match index {
    Int(value) | Literal(UInt(value~, ..) | SInt(value~, ..)) => StaticIndexing(lhs~, index=value.to_int())
    _ => DynamicIndexing(lhs~, index~)
  }
}

pub fn Reference::as_id(self: Reference) -> Id? {
  match self {
    Id(id) => Some(id)
    _ => None
  }
}

pub(all) struct Module {
  public: Bool
  id: Id
  ports: Array[Port]
  body: Array[Stmt]
}

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

pub fn primop(op: PrimOp, args: Array[Expr]) -> Expr {
  // ensure that integer arguments for some operations are not Literals
  match op {
    Pad | Shl | Shr | Head | Tail | Bits => {
      if args.length() > 1 {
        args[1] = match args[1] {
          Literal(lit) => Int(lit.value())
          _ => args[1]
        }

        if op == Bits && args.length() > 2 {
          args[2] = match args[2] {
            Literal(lit) => Int(lit.value())
            _ => args[2]
          }
        }
      }
    }
    _ => ()
  }

  PrimOp(op~, args~)
}

pub(all) enum Command {
  Printf(clk~: Expr, en~: Expr, fmt~: String, args~: Array[Expr])
  Assert(clk~: Expr, pred~: Expr, en~: Expr, fmt~: String, args~: Array[Expr])
  Stop(clk~: Expr, en~: Expr, code~: Int)
}

pub fn Command::replace_en(self: Command, update_en: (Expr) -> Expr) -> Command {
  match self {
    Printf(clk~, en~, fmt~, args~) => Printf(clk~, en=update_en(en), fmt~, args~)
    Assert(clk~, pred~, en~, fmt~, args~) => Assert(clk~, pred~, en=update_en(en), fmt~, args~)
    Stop(clk~, en~, code~) => Stop(clk~, en=update_en(en), code~)
  }
}

pub trait FIRRTLPass {
  run(self: Self, Circuit) -> Circuit raise
}

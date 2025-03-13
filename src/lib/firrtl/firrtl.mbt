// FIRRTL https://github.com/chipsalliance/firrtl-spec

pub fn version() -> (Int, Int, Int) {
  (4, 1, 0)
}

pub(all) enum Id {
  Ident(String)
  Literal(String)
} derive(Eq)

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
}

pub(all) enum Stmt {
  Node(id~: Id, expr~: Expr)
  Wire(id~: Id, ty~: Type)
  Inst(id~: Id, of~: Id)
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
}

pub fn Literal::value(self: Literal) -> BigInt {
  match self {
    UInt(value~, ..) | SInt(value~, ..) => value
  }
}

pub(all) enum Reference {
  Id(Id)
  Indexing(lhs~: Reference, index~: Expr) // static or dynamic
  FieldAccess(lhs~: Reference, field~: Id)
}

pub(all) struct Module {
  public: Bool
  id: Id
  ports: Array[Port]
  body: Array[Stmt]
}

pub(all) struct Port {
  direction: @parse.PortDirection
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

pub(all) enum PrimOp {
  AsUInt; AsSInt; AsClock; AsAsyncReset; Cvt
  Neg; Not; Andr; Orr; Xorr
  Add; Sub; Mul; Div; Rem
  Lt; Leq; Gt; Geq; Eq; Neq
  Dshl; Dshr
  And; Or; Xor; Cat
  Pad; Shl; Shr; Head; Tail
  Bits
} derive(Eq)

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
  Printf(clk~: Expr, cond~: Expr, fmt~: String, args~: Array[Expr])
  Assert(clk~: Expr, pred~: Expr, en~: Expr, fmt~: String, args~: Array[Expr])
  Stop(clk~: Expr, cond~: Expr, code~: Int)
}

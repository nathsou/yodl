using @firrtl {
  type Id,
  type Type,
  type Literal,
  type Expr,
  type Reference,
  type Stmt,
  type Module,
  type Port,
}
using @parse { type PortDir }

fn id(name: String, ty: Type) -> Reference[Type] {
  @firrtl.Reference::Id(@firrtl.Id::Ident(name), ty~)
}

fn ref_expr(name: String, ty: Type) -> Expr[Type] {
  @firrtl.Expr::Reference(id(name, ty), ty~)
}

fn lit(value: Int, width: Int) -> Expr[Type] {
  let ty = Type::UInt(width)
  @firrtl.Expr::Literal(
    Literal::UInt(width~, radix=None, value=@bigint.BigInt::from_int(value)),
    ty~,
  )
}

test "simulator evaluates combinational FIRRTL" {
  let u8 = Type::UInt(8)
  let design: Module[Type] = {
    public: true,
    id: @firrtl.Id::Ident("Top"),
    ports: [
      { dir: PortDir::Input, id: @firrtl.Id::Ident("a"), ty: u8 },
      { dir: PortDir::Input, id: @firrtl.Id::Ident("b"), ty: u8 },
      { dir: PortDir::Output, id: @firrtl.Id::Ident("out"), ty: u8 },
    ],
    body: [
      @firrtl.Stmt::Connect(
        id("out", u8),
    @firrtl.Expr::PrimOp(op=@firrtl.PrimOp::Add, args=[ref_expr("a", u8), ref_expr("b", u8)], ty=u8),
      ),
    ],
  }
  let sim = @simulator.Simulator::new(design)
  sim.poke("a", @simulator.SimValue::new(8, @bigint.BigInt::from_int(17)))
  sim.poke("b", @simulator.SimValue::new(8, @bigint.BigInt::from_int(25)))
  sim.settle()
  assert_eq(sim.peek("out").as_bigint(), @bigint.BigInt::from_int(42))
}

test "simulator commits a register on a rising edge" {
  let u8 = Type::UInt(8)
  let clock = Type::Clock
  let design: Module[Type] = {
    public: true,
    id: @firrtl.Id::Ident("Counter"),
    ports: [
      { dir: PortDir::Input, id: @firrtl.Id::Ident("clk"), ty: clock },
      { dir: PortDir::Output, id: @firrtl.Id::Ident("out"), ty: u8 },
    ],
    body: [
      @firrtl.Stmt::Reg(
        id=@firrtl.Id::Ident("state"),
        ty=u8,
        clock=ref_expr("clk", clock),
      ),
      @firrtl.Stmt::Connect(
        id("state", u8),
        @firrtl.Expr::PrimOp(op=@firrtl.PrimOp::Add, args=[ref_expr("state", u8), lit(1, 8)], ty=u8),
      ),
      @firrtl.Stmt::Connect(id("out", u8), ref_expr("state", u8)),
    ],
  }
  let sim = @simulator.Simulator::new(design)
  sim.step_clock("clk")
  assert_eq(sim.peek("out").as_bigint(), @bigint.BigInt::from_int(1))
  sim.step_clock("clk")
  assert_eq(sim.peek("out").as_bigint(), @bigint.BigInt::from_int(2))
}

test "simulator masks values to their declared width" {
  let value = @simulator.SimValue::new(4, @bigint.BigInt::from_int(0x1f))
  assert_eq(value.as_bigint(), @bigint.BigInt::from_int(0xf))
}

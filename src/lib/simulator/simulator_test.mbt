using @firrtl {
  type Type,
  type Literal,
  type Expr,
  type Reference,
  type Module,
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

test "testbench facade advances cycles and checks expectations" {
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
      @firrtl.Stmt::Reg(id=@firrtl.Id::Ident("state"), ty=u8, clock=ref_expr("clk", clock)),
      @firrtl.Stmt::Connect(
        id("state", u8),
        @firrtl.Expr::PrimOp(op=@firrtl.PrimOp::Add, args=[ref_expr("state", u8), lit(1, 8)], ty=u8),
      ),
      @firrtl.Stmt::Connect(id("out", u8), ref_expr("state", u8)),
    ],
  }
  let tb = @simulator.Simulator::new(design).testbench()
  tb.step("clk")
  tb.expect("out", @simulator.SimValue::new(8, @bigint.BigInt::from_int(1), known=false))
  tb.run("clk", 2)
  assert_eq(tb.cycle(), 3)
}

test "semantic output sinks collect framebuffer pixels and text" {
  let framebuffer = @simulator.Framebuffer::new(2, 2)
  framebuffer.write(1, 0, 255, 16, 3)
  assert_eq(framebuffer.pixel(1, 0), 0xFF1003)
  framebuffer.clear(color=7)
  assert_eq(framebuffer.pixel(0, 1), 7)

  let text = @simulator.TextSink::new()
  text.write('A'.to_int())
  text.write(10)
  assert_eq(text.text(), "A\n")
}

test "signed comparisons use operand signedness" {
  let s8 = Type::SInt(8)
  let bit = Type::UInt(1)
  let design: Module[Type] = {
    public: true,
    id: @firrtl.Id::Ident("Compare"),
    ports: [
      { dir: PortDir::Input, id: @firrtl.Id::Ident("a"), ty: s8 },
      { dir: PortDir::Input, id: @firrtl.Id::Ident("b"), ty: s8 },
      { dir: PortDir::Output, id: @firrtl.Id::Ident("lt"), ty: bit },
    ],
    body: [
      @firrtl.Stmt::Connect(
        id("lt", bit),
        @firrtl.Expr::PrimOp(op=@firrtl.PrimOp::Lt, args=[ref_expr("a", s8), ref_expr("b", s8)], ty=bit),
      ),
    ],
  }
  let sim = @simulator.Simulator::new(design)
  sim.poke("a", @simulator.SimValue::from_int(8, 255))
  sim.poke("b", @simulator.SimValue::from_int(8, 1))
  sim.settle()
  assert_eq(sim.peek("lt").as_bigint(), @bigint.BigInt::from_int(1))
}

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

test "simulator extracts high bits from wide values" {
  let u1 = Type::UInt(1)
  let u40 = Type::UInt(40)
  let design: Module[Type] = {
    public: true,
    id: @firrtl.Id::Ident("Bits"),
    ports: [
      { dir: PortDir::Input, id: @firrtl.Id::Ident("a"), ty: u40 },
      { dir: PortDir::Output, id: @firrtl.Id::Ident("out"), ty: u1 },
    ],
    body: [
      @firrtl.Stmt::Connect(id("out", u1), @firrtl.Expr::PrimOp(op=@firrtl.PrimOp::Bits, args=[ref_expr("a", u40), lit(2, 6), lit(2, 6)], ty=u1)),
    ],
  }
  let sim = @simulator.Simulator::new(design)
  sim.poke("a", @simulator.SimValue::from_int(40, 1 << 2))
  sim.settle()
  assert_eq(sim.peek("out").as_bigint(), @bigint.BigInt::from_int(1))
}

test "simulator requeues aggregate slices when their source changes" {
  let u1 = Type::UInt(1)
  let vec40 = Type::Vec(u1, 40)
  let design: Module[Type] = {
    public: true,
    id: @firrtl.Id::Ident("AggregateSlice"),
    ports: [
      { dir: PortDir::Input, id: @firrtl.Id::Ident("a"), ty: vec40 },
      { dir: PortDir::Output, id: @firrtl.Id::Ident("out"), ty: u1 },
    ],
    body: [
      @firrtl.Stmt::Connect(
        id("out", u1),
        @firrtl.Expr::Reference(
          @firrtl.Reference::StaticIndexing(lhs=id("a", vec40), index=16, ty=u1),
          ty=u1,
        ),
      ),
    ],
  }
  let sim = @simulator.Simulator::new(design)
  sim.poke("a", @simulator.SimValue::from_int(40, 1 << 16))
  sim.settle()
  assert_eq(sim.peek("out").as_bigint(), @bigint.BigInt::from_int(1))
}

test "simulator propagates adjacent wide slices" {
  let u1 = Type::UInt(1)
  let u40 = Type::UInt(40)
  let design: Module[Type] = {
    public: true,
    id: @firrtl.Id::Ident("Slices"),
    ports: [
      { dir: PortDir::Output, id: @firrtl.Id::Ident("out2"), ty: u1 },
      { dir: PortDir::Output, id: @firrtl.Id::Ident("out16"), ty: u1 },
    ],
    body: [
      @firrtl.Stmt::Node(id=@firrtl.Id::Ident("tmp"), expr=lit(50528268, 40)),
      @firrtl.Stmt::Connect(id("out2", u1), @firrtl.Expr::PrimOp(op=@firrtl.PrimOp::Bits, args=[ref_expr("tmp", u40), lit(2, 6), lit(2, 6)], ty=u1)),
      @firrtl.Stmt::Connect(id("out16", u1), @firrtl.Expr::PrimOp(op=@firrtl.PrimOp::Bits, args=[ref_expr("tmp", u40), lit(16, 6), lit(16, 6)], ty=u1)),
    ],
  }
  let sim = @simulator.Simulator::new(design)
  sim.settle()
  assert_eq(sim.peek("out2").as_bigint(), @bigint.BigInt::from_int(1))
  assert_eq(sim.peek("out16").as_bigint(), @bigint.BigInt::from_int(1))
}

test "simulator handles generated dollar names in wide slices" {
  let u1 = Type::UInt(1)
  let u40 = Type::UInt(40)
  let design: Module[Type] = {
    public: true,
    id: @firrtl.Id::Ident("DollarSlices"),
    ports: [{ dir: PortDir::Output, id: @firrtl.Id::Ident("out"), ty: u1 }],
    body: [
      @firrtl.Stmt::Node(id=@firrtl.Id::Ident("tmp_16$"), expr=lit(50528268, 40)),
      @firrtl.Stmt::Connect(id("out", u1), @firrtl.Expr::PrimOp(op=@firrtl.PrimOp::Bits, args=[ref_expr("tmp_16$", u40), lit(2, 6), lit(2, 6)], ty=u1)),
    ],
  }
  let sim = @simulator.Simulator::new(design)
  sim.settle()
  assert_eq(sim.peek("out").as_bigint(), @bigint.BigInt::from_int(1))
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

test "waveform tracing records filtered transitions and cycles" {
  let u1 = Type::UInt(1)
  let design: Module[Type] = {
    public: true,
    id: @firrtl.Id::Ident("Trace"),
    ports: [
      { dir: PortDir::Input, id: @firrtl.Id::Ident("a"), ty: u1 },
      { dir: PortDir::Output, id: @firrtl.Id::Ident("out"), ty: u1 },
    ],
    body: [@firrtl.Stmt::Connect(id("out", u1), ref_expr("a", u1))],
  }
  let sim = @simulator.Simulator::new(design)
  sim.enable_waveform(signals=["out"])
  sim.poke("a", @simulator.SimValue::from_int(1, 1))
  sim.settle()
  let trace = sim.waveform()
  assert_true(trace.length() > 0)
  assert_eq(trace[0].signal(), "out")
  assert_eq(trace[0].value().as_bigint(), @bigint.BigInt::from_int(1))
}

test "external primitive models drive instance outputs" {
  let u8 = Type::UInt(8)
  let sig_ports : Map[String, @firrtl.PortSignature] = Map([])
  sig_ports["a"] = { dir: PortDir::Input, ty: u8 }
  sig_ports["y"] = { dir: PortDir::Output, ty: u8 }
  let signature : @firrtl.ModuleSignature = { ports: sig_ports }
  let ext : @firrtl.ExtModule = {
    id: @firrtl.Id::Ident("Box"),
    ports: [
      { dir: PortDir::Input, id: @firrtl.Id::Ident("a"), ty: u8 },
      { dir: PortDir::Output, id: @firrtl.Id::Ident("y"), ty: u8 },
    ],
    defname: None,
    parameters: [],
  }
  let box_ty = signature.as_bundle()
  let box_ref = @firrtl.Reference::Id(@firrtl.Id::Ident("box"), ty=box_ty)
  let box_a = @firrtl.Reference::FieldAccess(lhs=box_ref, field=@firrtl.Id::Ident("a"), ty=u8)
  let box_y = @firrtl.Reference::FieldAccess(lhs=box_ref, field=@firrtl.Id::Ident("y"), ty=u8)
  let top : @firrtl.TypedModule = {
    public: true,
    id: @firrtl.Id::Ident("Top"),
    ports: [
      { dir: PortDir::Input, id: @firrtl.Id::Ident("a"), ty: u8 },
      { dir: PortDir::Output, id: @firrtl.Id::Ident("y"), ty: u8 },
    ],
    body: [
      @firrtl.Stmt::Inst(id=@firrtl.Id::Ident("box"), of=@firrtl.Id::Ident("Box"), sig=signature),
      @firrtl.Stmt::Connect(box_a, ref_expr("a", u8)),
      @firrtl.Stmt::Connect(id("y", u8), @firrtl.Expr::Reference(box_y, ty=u8)),
    ],
  }
  let circuit : @firrtl.TypedCircuit = {
    version: @firrtl.min_version(),
    id: @firrtl.Id::Ident("Top"),
    annotations: [],
    decls: [@firrtl.Decl::ExtModule(ext), @firrtl.Decl::Module(top)],
  }
  let models : Map[String, @simulator.PrimitiveModel] = Map([])
  models["Box"] = {
    eval: fn(sim) {
      let input = sim.peek("a")
      sim.poke("y", @simulator.SimValue::from_int(8, input.as_bigint().to_int() + 1))
    },
  }
  let sim = @simulator.Simulator::from_circuit_with_models(circuit, "Top", models)
  sim.poke("a", @simulator.SimValue::from_int(8, 41))
  sim.settle()
  assert_eq(sim.peek("y").as_bigint().to_int(), 42)
}

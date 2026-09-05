test "review3 conditional default assignments" {
  let bit = Type::UInt(1)
  let u8 = Type::UInt(8)
  let design: Module[Type] = {
    public: true, id: @firrtl.Id::Ident("Top"),
    ports: [
      { dir: PortDir::Input, id: @firrtl.Id::Ident("en"), ty: bit },
      { dir: PortDir::Output, id: @firrtl.Id::Ident("out"), ty: u8 },
    ],
    body: [
      @firrtl.Stmt::Connect(id("out", u8), lit(0, 8)),
      @firrtl.Stmt::When({cond: ref_expr("en", bit), body: [@firrtl.Stmt::Connect(id("out", u8), lit(1, 8))], otherwise: None}),
    ],
  }
  let sim = @simulator.Simulator::new(design)
  sim.poke("en", @simulator.SimValue::from_int(1, 1))
  sim.settle()
  assert_eq(sim.peek("out").as_bigint().to_int(), 1)
  sim.poke("en", @simulator.SimValue::from_int(1, 0))
  sim.settle()
  assert_eq(sim.peek("out").as_bigint().to_int(), 0)
}

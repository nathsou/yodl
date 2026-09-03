test "compile_simulation produces a runnable low FIRRTL module" {
  let source =
    #|module Top(clk: clock) -> (value: u8) {
    #|  let state = Reg[u8](clk)
    #|  state.d = state.q + 1'b1
    #|  value = state.q
    #|}
  let files : Map[String, String] = Map([])
  files["fixture.yodl"] = source
  let output : Ref[String] = { val: "" }
  let ext : @utils.Externals = {
    fs: make_vfs(files),
    println: fn(text) { output.val = text },
    get_args: fn() { [] },
    exit: fn(_) { () },
  }
  let circuit = @driver.compile_simulation(path="fixture.yodl", ext~)
  let mut top : @firrtl.TypedModule? = None
  for decl in circuit.decls {
    match decl {
      @firrtl.Decl::Module(mod) if mod.id.inner() == "Top" => top = Some(mod)
      _ => ()
    }
  }
  let design = top.unwrap_or_error(Failure::Failure("Top module missing"))
  let sim = @simulator.Simulator::new(design)
  sim.step_clock("clk")
  inspect(sim.peek("state").as_bigint().to_int(), content="1")
  assert_eq(sim.peek("value").as_bigint().to_int(), 1)
}

test "compiled simulator models a synchronous memory" {
  let source =
    #|module Top(clk: clock, addr: u2, wdata: u8, we: bool) -> (rdata: u8) {
    #|  let mem = Memory[T: u8, Depth: 4, ReadPorts: 1, WritePorts: 1, ReadLatency: 1, WriteLatency: 1](
    #|    read: [(clk: clk, en: true, addr: addr)],
    #|    write: [(clk: clk, en: we, addr: addr, data: wdata, mask: true)],
    #|  )
    #|  rdata = mem.q[0]
    #|}
  let files : Map[String, String] = Map([])
  files["fixture.yodl"] = source
  let ext : @utils.Externals = {
    fs: make_vfs(files),
    println: fn(_) { () },
    get_args: fn() { [] },
    exit: fn(_) { () },
  }
  let circuit = @driver.compile_simulation(path="fixture.yodl", ext~)
  let mut top : @firrtl.TypedModule? = None
  for decl in circuit.decls {
    match decl {
      @firrtl.Decl::Module(mod) if mod.id.inner() == "Top" => top = Some(mod)
      _ => ()
    }
  }
  let sim = @simulator.Simulator::new(top.unwrap_or_error(Failure::Failure("Top module missing")))
  sim.poke("addr", @simulator.SimValue::new(2, @bigint.BigInt::from_int(2)))
  sim.poke("wdata", @simulator.SimValue::new(8, @bigint.BigInt::from_int(99)))
  sim.poke("we", @simulator.SimValue::new(1, @bigint.BigInt::from_int(1)))
  sim.step_clock("clk")
  sim.poke("we", @simulator.SimValue::new(1, @bigint.BigInt::from_int(0)))
  sim.step_clock("clk")
  assert_eq(sim.peek("rdata").as_bigint().to_int(), 99)
}

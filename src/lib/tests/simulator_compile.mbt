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

test "async reset updates a register without a clock edge" {
  let source =
    #|module Top(clk: clock, rst: bool, d: u8) -> (q: u8) {
    #|  let state = RegAsyncReset[u8](clk, rst: rst)
    #|  state.d = d
    #|  q = state.q
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
  let sim = @simulator.Simulator::from_circuit(circuit, "Top")
  sim.poke("rst", @simulator.SimValue::from_int(1, 1))
  assert_eq(sim.peek("state").as_bigint().to_int(), 0)
  sim.poke("rst", @simulator.SimValue::from_int(1, 0))
  sim.poke("d", @simulator.SimValue::from_int(8, 23))
  sim.step_clock("clk")
  assert_eq(sim.peek("q").as_bigint().to_int(), 23)
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

test "hierarchical instances share clocked state with their parent" {
  let source =
    #|module Child(clk: clock) -> (value: u8) {
    #|  let state = Reg[u8](clk)
    #|  state.d = state.q + 1'b1
    #|  value = state.q
    #|}
    #|
    #|module Top(clk: clock) -> (value: u8) {
    #|  let child = Child(clk)
    #|  value = child.value
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
  let sim = @simulator.Simulator::from_circuit(circuit, "Top")
  sim.step_clock("clk")
  assert_eq(sim.peek("value").as_bigint().to_int(), 1)
  sim.step_clock("clk")
  assert_eq(sim.peek("value").as_bigint().to_int(), 2)
}

test "external module instances can use a host primitive model" {
  let source =
    #|declare module Box(a: u8) -> (y: u8)
    #|
    #|module Top(a: u8) -> (y: u8) {
    #|  let box = Box(a)
    #|  y = box.y
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
  let models : Map[String, @simulator.PrimitiveModel] = Map([])
  models["Box"] = {
    eval: (sim) => {
      let value = sim.peek("a").as_bigint().to_int()
      sim.poke("y", @simulator.SimValue::from_int(8, value + 1))
    },
  }
  let sim = @simulator.Simulator::from_circuit_with_models(circuit, "Top", models)
  sim.poke("a", @simulator.SimValue::from_int(8, 41))
  sim.settle()
  assert_eq(sim.peek("y").as_bigint().to_int(), 42)
}

test "external aggregate ports are flattened for primitive models" {
  let source =
    #|declare module Box(a: [2]u8) -> (y: [2]u8)
    #|
    #|module Top(a: [2]u8) -> (y: [2]u8) {
    #|  let box = Box(a)
    #|  y = box.y
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
  let models : Map[String, @simulator.PrimitiveModel] = Map([])
  models["Box"] = {
    eval: (sim) => {
      for index in 0..<2 {
        let suffix = index.to_string()
        let value = sim.peek("a_" + suffix).as_bigint().to_int()
        sim.poke("y_" + suffix, @simulator.SimValue::from_int(8, value + 1))
      }
    },
  }
  let sim = @simulator.Simulator::from_circuit_with_models(circuit, "Top", models)
  sim.poke("a_0", @simulator.SimValue::from_int(8, 10))
  sim.poke("a_1", @simulator.SimValue::from_int(8, 20))
  sim.settle()
  assert_eq(sim.peek("y_0").as_bigint().to_int(), 11)
  assert_eq(sim.peek("y_1").as_bigint().to_int(), 21)
}

test "boolean framebuffers execute as packed rows across word boundaries" {
  let source =
    #|module Top(clk: clock, init: bool) -> (pixel: [2][35]bool) {
    #|  let cells = Reg[[2][35]bool](clk)
    #|  for y in 0..<2 {
    #|    for x in 0..<35 {
    #|      cells.d[y][x] = init ? (x == 0) : cells.q[y][(x + 34) % 35]
    #|      pixel[y][x] = cells.q[y][x]
    #|    }
    #|  }
    #|}
  let files: Map[String, String] = { "fixture.yodl": source }
  let ext: @utils.Externals = {
    fs: make_vfs(files), println: fn(_) { () }, get_args: fn() { [] }, exit: fn(_) { () },
  }
  let design = @driver.compile_simulation_design(path="fixture.yodl", ext~)
  assert_eq(design.displays.length(), 1)
  let display = design.displays[0]
  assert_eq(display.width, 35)
  assert_eq(display.height, 2)
  assert_eq(display.ports.length(), 2)
  let sim = @simulator.Simulator::from_circuit(design.circuit, "Top")
  sim.poke("init", @simulator.SimValue::from_int(1, 1))
  sim.step_clock("clk")
  sim.poke("init", @simulator.SimValue::from_int(1, 0))
  for _ in 0..<33 { sim.step_clock("clk") }
  let frame = @simulator.simulator_frame(sim, display.ports, 35, 2, true)
  assert_eq(frame.words, [0U, 2U, 0U, 2U])
  assert_true(frame.valid.iter().all(word => word == 0xffffffffU))
}

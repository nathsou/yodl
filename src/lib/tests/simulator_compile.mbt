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
    evaluate: (inputs) => [@simulator.SimValue::from_int(8, inputs[0].as_bigint().to_int() + 1)],
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
    evaluate: (inputs) => inputs.map(value => @simulator.SimValue::from_int(8, value.as_bigint().to_int() + 1)),
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

fn compile_test_simulator(source: String) -> @simulator.Simulator raise {
  let files: Map[String, String] = { "fixture.yodl": source }
  let ext: @utils.Externals = {
    fs: make_vfs(files), println: fn(_) { () }, get_args: fn() { [] }, exit: fn(_) { () },
  }
  @simulator.Simulator::from_circuit(@driver.compile_simulation(path="fixture.yodl", ext~), "Top")
}

test "asynchronous memory reads follow address and enable without an edge" {
  let source =
    #|module Top(clk: clock, addr: u2, wdata: u8, we: bool, en: bool) -> (rdata: u8) {
    #|  let mem = Memory[T: u8, Depth: 4, ReadPorts: 1, WritePorts: 1, ReadLatency: 0, WriteLatency: 1](
    #|    read: [(clk: clk, en: en, addr: addr)],
    #|    write: [(clk: clk, en: we, addr: addr, data: wdata, mask: true)],
    #|  )
    #|  rdata = mem.q[0]
    #|}
  let sim = compile_test_simulator(source)
  sim.poke("en", @simulator.SimValue::from_int(1, 1))
  sim.poke("we", @simulator.SimValue::from_int(1, 1))
  for address in 0..<2 {
    sim.poke("addr", @simulator.SimValue::from_int(2, address))
    sim.poke("wdata", @simulator.SimValue::from_int(8, (address + 1) * 11))
    sim.step_clock("clk")
  }
  sim.poke("we", @simulator.SimValue::from_int(1, 0))
  sim.poke("addr", @simulator.SimValue::from_int(2, 0))
  sim.settle()
  assert_eq(sim.peek("rdata").as_bigint().to_int(), 11)
  assert_true(sim.peek("rdata").is_known())
  sim.poke("en", @simulator.SimValue::from_int(1, 0))
  sim.settle()
  assert_false(sim.peek("rdata").is_known())
  sim.poke("en", @simulator.SimValue::from_int(1, 1))
  sim.settle()
  assert_true(sim.peek("rdata").is_known())
  assert_eq(sim.peek("rdata").as_bigint().to_int(), 11)
}

test "clock aliases drive local and nested registers in the selected domain" {
  let source =
    #|module Child(clk: clock, d: u8) -> (q: u8) {
    #|  let c = clk
    #|  let r = Reg[u8](clk: c)
    #|  r.d = d
    #|  q = r.q
    #|}
    #|module Top(clk: clock, other: clock, d: u8) -> (q: u8, nested: u8, independent: u8) {
    #|  let c = clk
    #|  let alias = c
    #|  let r = Reg[u8](clk: alias)
    #|  r.d = d
    #|  q = r.q
    #|  let child = Child(clk: alias, d: d)
    #|  nested = child.q
    #|  let separate = Child(clk: other, d: d)
    #|  independent = separate.q
    #|}
  let sim = compile_test_simulator(source)
  sim.poke("d", @simulator.SimValue::from_int(8, 23))
  sim.step_clock("clk")
  for name in ["q", "nested"] {
    assert_true(sim.peek(name).is_known())
    assert_eq(sim.peek(name).as_bigint().to_int(), 23)
  }
  assert_false(sim.peek("independent").is_known())
  sim.step_clock("other")
  assert_eq(sim.peek("independent").as_bigint().to_int(), 23)
}

test "nested asynchronous resets settle through combinational reset logic" {
  let source =
    #|module Child(clk: clock, rst: bool, d: u8) -> (q: u8) {
    #|  let r = RegAsyncReset[u8](clk, rst: rst)
    #|  r.d = d
    #|  q = r.q
    #|}
    #|module Middle(clk: clock, rst: bool, d: u8) -> (q: u8) {
    #|  let child = Child(clk, rst: rst, d: d)
    #|  q = child.q
    #|}
    #|module Top(clk: clock, rst: bool, enable: bool, d: u8) -> (q: u8) {
    #|  let child = Middle(clk, rst: rst and enable, d: d)
    #|  q = child.q
    #|}
  let sim = compile_test_simulator(source)
  sim.poke("d", @simulator.SimValue::from_int(8, 23))
  sim.poke("enable", @simulator.SimValue::from_int(1, 1))
  sim.step_clock("clk")
  assert_eq(sim.peek("q").as_bigint().to_int(), 23)
  sim.poke("rst", @simulator.SimValue::from_int(1, 1))
  sim.settle()
  assert_true(sim.peek("q").is_known())
  assert_eq(sim.peek("q").as_bigint().to_int(), 0)
  sim.step_clock("clk")
  assert_eq(sim.peek("q").as_bigint().to_int(), 0)
  sim.poke("rst", @simulator.SimValue::from_int(1, 0))
  sim.settle()
  assert_eq(sim.peek("q").as_bigint().to_int(), 0)
  sim.step_clock("clk")
  assert_eq(sim.peek("q").as_bigint().to_int(), 23)
}

test "signed widening and unsigned negation preserve operand interpretation" {
  let source =
    #|module Top(a: s8, u: u8, wide: s24, uwide: u24) -> (
    #|  implicit: s16, explicit: s16, unsigned: u16, neg: s9,
    #|  implicit_wide: s32, explicit_wide: s32, neg_wide: s25,
    #|) {
    #|  implicit = a
    #|  explicit = pad!(a, 16)
    #|  unsigned = pad!(u, 16)
    #|  neg = -u
    #|  implicit_wide = wide
    #|  explicit_wide = pad!(wide, 32)
    #|  neg_wide = -uwide
    #|}
  let sim = compile_test_simulator(source)
  for pair in [("a", 8), ("u", 8), ("wide", 24), ("uwide", 24)] {
    let (name, width) = pair
    sim.poke(name, @simulator.SimValue::from_int(width, (1 << width) - 1))
  }
  sim.settle()
  for name in ["implicit", "explicit"] {
    assert_eq(sim.peek(name).as_bigint().to_string(), "65535")
  }
  for name in ["implicit_wide", "explicit_wide"] {
    assert_eq(sim.peek(name).as_bigint().to_string(), "4294967295")
  }
  assert_eq(sim.peek("unsigned").as_bigint().to_int(), 255)
  assert_eq(sim.peek("neg").as_bigint().to_int(), 257)
  assert_eq(sim.peek("neg_wide").as_bigint().to_int(), 16777217)
  sim.poke("a", @simulator.SimValue::from_int(8, 12))
  sim.settle()
  assert_eq(sim.peek("implicit").as_bigint().to_int(), 12)
  sim.poke("a", @simulator.SimValue::new(8, 255, known=false))
  sim.settle()
  assert_false(sim.peek("implicit").is_known())
  assert_false(sim.peek("explicit").is_known())
}

test "clocked commands sample the pre-edge register state" {
  let source =
    #|module Top(clk: clock, rst: bool) -> (q: u8) {
    #|  let r = RegAsyncReset[u8](clk, rst: rst)
    #|  r.d = r.q + 1'b1
    #|  q = r.q
    #|  printf!("counter %d", r.q)
    #|  assert!(r.q == 0)
    #|  if r.q == 1 { stop!(); }
    #|}
  let sim = compile_test_simulator(source)
  sim.poke("rst", @simulator.SimValue::from_int(1, 1))
  sim.settle()
  sim.poke("rst", @simulator.SimValue::from_int(1, 0))
  sim.step_clock("clk")
  assert_eq(sim.messages().map(m => m.text()), ["counter 0"])
  assert_eq(sim.failure(), None)
  assert_false(sim.is_halted())
  assert_eq(sim.peek("q").as_bigint().to_int(), 1)
  sim.step_clock("clk")
  assert_true(sim.failure() is Some(_))
  assert_true(sim.is_halted())
  assert_eq(sim.peek("q").as_bigint().to_int(), 2)
}

test "clocked commands use the shared FIRRTL formatter" {
  let source =
    #|module Top(clk: clock) -> () {
    #|  printf!("b=%b c=%c d=%d x=%x %%", 8'd42, 8'd42, 8'd42, 8'd42)
    #|}
  let sim = compile_test_simulator(source)
  sim.step_clock("clk")
  assert_eq(sim.messages().map(m => m.text()), ["b=00101010 c=* d=42 x=2a %"])
}

test "simulation compilation rejects clockless runtime commands at their span" {
  for command in ["printf!(\"checked\")", "assert!(input)"] {
    let source = "module Top(input: bool) -> () {\n  " + command + "\n}\n"
    let files: Map[String, String] = { "fixture.yodl": source }
    let ext: @utils.Externals = {
      fs: make_vfs(files), println: fn(_) { () }, get_args: fn() { [] }, exit: fn(_) { () },
    }
    let diagnostic = try {
      let _ = @driver.compile_simulation(path="fixture.yodl", ext~)
      fail("Expected simulation compilation to fail")
    } catch {
      Failure::Failure(message) => message
      error => error.to_string()
    }
    assert_true(diagnostic.contains("No clock found in current module"))
    assert_true(diagnostic.contains("fixture.yodl:2"))
  }
}

fn repository_externals() -> @utils.Externals {
  {
    fs: {
      path_exists: @fs.path_exists,
      read_file_to_string: path => @fs.read_file_to_string(path),
      read_dir: path => @fs.read_dir(path),
      is_dir: path => @fs.is_dir(path),
      create_dir: path => @fs.create_dir(path),
      write_string_to_file: (path, contents) => @fs.write_string_to_file(path, contents),
    },
    println: fn(_) { () },
    get_args: fn() { [] },
    exit: fn(_) { () },
  }
}

test "clock text converts binary time to decimal digits" {
  let ext = repository_externals()
  let design = @driver.compile_simulation_design(
    path="examples/Clock.yodl",
    ext~,
    top=Some("ClockText"),
  )
  let sim = @simulator.Simulator::from_circuit(design.circuit, "ClockText")
  let cases = [
    (0, 0, 9, [48, 48, 58, 48, 48, 58, 48, 57]),
    (0, 0, 10, [48, 48, 58, 48, 48, 58, 49, 48]),
    (0, 0, 59, [48, 48, 58, 48, 48, 58, 53, 57]),
    (0, 1, 0, [48, 48, 58, 48, 49, 58, 48, 48]),
    (1, 0, 0, [48, 49, 58, 48, 48, 58, 48, 48]),
  ]
  for case in cases {
    let (hours, minutes, seconds, expected) = case
    sim.poke("hours", @simulator.SimValue::from_int(8, hours))
    sim.poke("minutes", @simulator.SimValue::from_int(8, minutes))
    sim.poke("seconds", @simulator.SimValue::from_int(8, seconds))
    sim.settle()
    let chars: Array[Int] = []
    for index in 0..<8 {
      chars.push(sim.peek("chars_\{index}").as_bigint().to_int())
    }
    assert_eq(chars, expected)
  }
}

test "clock state rolls seconds, minutes, hours, and day explicitly" {
  let ext = repository_externals()
  let design = @driver.compile_simulation_design(
    path="examples/Clock.yodl",
    ext~,
    top=Some("ClockState"),
  )
  let sim = @simulator.Simulator::from_circuit(design.circuit, "ClockState")
  sim.poke("rst", @simulator.SimValue::from_int(1, 1))
  sim.step_clock("clk")
  sim.poke("rst", @simulator.SimValue::from_int(1, 0))
  for _ in 0..<3600 { sim.step_clock("clk") }
  assert_eq(sim.peek("hours").as_bigint().to_int(), 1)
  assert_eq(sim.peek("minutes").as_bigint().to_int(), 0)
  assert_eq(sim.peek("seconds").as_bigint().to_int(), 0)
  assert_eq(sim.cycle(), 3601)
  for _ in 3600..<(24 * 60 * 60) { sim.step_clock("clk") }
  assert_eq(sim.peek("hours").as_bigint().to_int(), 0)
  assert_eq(sim.peek("minutes").as_bigint().to_int(), 0)
  assert_eq(sim.peek("seconds").as_bigint().to_int(), 0)
  assert_eq(sim.cycle(), 24 * 60 * 60 + 1)
}

test "tied child clocks sample a pipeline simultaneously through hierarchy" {
  let source =
    #|module Child(c1: clock, c2: clock, d: u8) -> (q: u8) {
    #|  let a = Reg[u8](clk: c1)
    #|  let b = Reg[u8](clk: c2)
    #|  a.d = d
    #|  b.d = a.q
    #|  q = b.q
    #|}
    #|module Middle(c1: clock, c2: clock, d: u8) -> (q: u8) {
    #|  let child = Child(c1: c1, c2: c2, d: d)
    #|  q = child.q
    #|}
    #|module Top(clk: clock, d: u8) -> (q: u8) {
    #|  let child = Middle(c1: clk, c2: clk, d: d)
    #|  q = child.q
    #|}
  let sim = compile_test_simulator(source)
  sim.poke("d", @simulator.SimValue::from_int(8, 23))
  sim.step_clock("clk")
  assert_false(sim.peek("q").is_known())
  sim.poke("d", @simulator.SimValue::from_int(8, 42))
  sim.step_clock("clk")
  assert_true(sim.peek("q").is_known())
  assert_eq(sim.peek("q").as_bigint().to_int(), 23)
  sim.step_clock("clk")
  assert_eq(sim.peek("q").as_bigint().to_int(), 42)
}

test "asynchronous memory reads preserve unknown address and enable" {
  let source =
    #|module Top(clk: clock, addr: u2, en: bool, we: bool, data: u8) -> (q: u8) {
    #|  let mem = Memory[T: u8, Depth: 4, ReadPorts: 1, WritePorts: 1, ReadLatency: 0, WriteLatency: 1](
    #|    read: [(clk: clk, en: en, addr: addr)],
    #|    write: [(clk: clk, en: we, addr: 2'd0, data: data, mask: true)])
    #|  q = mem.q[0]
    #|}
  let sim = compile_test_simulator(source)
  sim.poke("en", @simulator.SimValue::from_int(1, 1))
  sim.poke("we", @simulator.SimValue::from_int(1, 1))
  sim.poke("data", @simulator.SimValue::from_int(8, 23))
  sim.step_clock("clk")
  assert_true(sim.peek("q").is_known())
  assert_eq(sim.peek("q").as_bigint().to_int(), 23)
  sim.poke("addr", @simulator.SimValue::new(2, 0, known=false))
  sim.settle()
  assert_false(sim.peek("q").is_known())
  sim.poke("addr", @simulator.SimValue::from_int(2, 0))
  sim.poke("en", @simulator.SimValue::new(1, 1, known=false))
  sim.settle()
  assert_false(sim.peek("q").is_known())
  sim.poke("en", @simulator.SimValue::from_int(1, 1))
  sim.settle()
  assert_true(sim.peek("q").is_known())
  assert_eq(sim.peek("q").as_bigint().to_int(), 23)
}

test "tied child clocks preserve synchronous read-under-write collisions" {
  let source =
    #|module Child(c1: clock, c2: clock, we: bool) -> (q: u8) {
    #|  let mem = Memory[T: u8, Depth: 4, ReadPorts: 1, WritePorts: 1, ReadLatency: 1, WriteLatency: 1](
    #|    read: [(clk: c2, en: true, addr: 2'd0)],
    #|    write: [(clk: c1, en: we, addr: 2'd0, data: 8'd23, mask: true)])
    #|  q = mem.q[0]
    #|}
    #|module Top(clk: clock, we: bool) -> (q: u8) {
    #|  let child = Child(c1: clk, c2: clk, we: we)
    #|  q = child.q
    #|}
  let sim = compile_test_simulator(source)
  sim.poke("we", @simulator.SimValue::from_int(1, 1))
  sim.step_clock("clk")
  assert_false(sim.peek("q").is_known())
  sim.poke("we", @simulator.SimValue::from_int(1, 0))
  sim.step_clock("clk")
  assert_true(sim.peek("q").is_known())
  assert_eq(sim.peek("q").as_bigint().to_int(), 23)
}

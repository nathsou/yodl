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

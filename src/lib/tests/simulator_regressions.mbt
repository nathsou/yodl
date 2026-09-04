test "review3 unknown reset" {
  let sim = compile_test_simulator(
    (#|module Top(clk: clock, rst: bool, d: u8) -> (q: u8) {
     #|  let r = Reg[u8](clk, rst)
     #|  r.d = d
     #|  q = r.q
     #|}
    )
  )
  sim.poke("rst", @simulator.SimValue::new(1, 0, known=false))
  sim.poke("d", @simulator.SimValue::from_int(8, 23))
  sim.step_clock("clk")
  assert_false(sim.peek("q").is_known())
}

test "review3 primitive initial zero inputs" {
  let source =
    #|declare module Box(a: u8) -> (y: u8)
    #|module Top(a: u8) -> (y: u8) { let box = Box(a); y = box.y; }
  let files: Map[String, String] = { "fixture.yodl": source }
  let ext: @utils.Externals = { fs: make_vfs(files), println: fn(_) { () }, get_args: fn() { [] }, exit: fn(_) { () } }
  let circuit = @driver.compile_simulation(path="fixture.yodl", ext~)
  let models: Map[String, @simulator.PrimitiveModel] = {
    "Box": { evaluate: (inputs) => [@simulator.SimValue::from_int(8, inputs[0].as_bigint().to_int() + 1)] },
  }
  let sim = @simulator.Simulator::from_circuit_with_models(circuit, "Top", models)
  sim.settle()
  assert_eq(sim.peek("y").as_bigint().to_int(), 1)
}

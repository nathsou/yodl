test "procedural testbenches run bound and unbound DUTs" {
  let source =
    "module And(a: bool, b: bool) -> (out: bool) {\n" +
    "  out = a and b\n" +
    "}\n" +
    "test \"bound\" for And {\n" +
    "  drive!(a, true)\n" +
    "  drive!(b, false)\n" +
    "  expect!(out, false)\n" +
    "}\n" +
    "test \"unbound\" {\n" +
    "  let dut = And()\n" +
    "  drive!(dut.a, true)\n" +
    "  drive!(dut.b, true)\n" +
    "  expect!(dut.out, true)\n" +
    "}\n"
  let files : Map[String, String] = Map([])
  files["fixture.yodl"] = source
  let output : Ref[String] = { val: "" }
  let ext : @utils.Externals = {
    fs: make_vfs(files),
    println: fn(text) { output.val = output.val + text + "\n" },
    get_args: fn() { [] },
    exit: fn(_) { () },
  }
  @driver.run(path="fixture.yodl", commands=@driver.parse_commands("test"), ext~)
  assert_eq(output.val, "PASS bound\nPASS unbound\n")
}

test "test command filters by name" {
  let source =
    "module And(a: bool, b: bool) -> (out: bool) { out = a and b; }\n" +
    "test \"one\" for And { expect!(out, false); }\n" +
    "test \"two\" for And { expect!(out, false); }\n"
  let files : Map[String, String] = Map([])
  files["fixture.yodl"] = source
  let output : Ref[String] = { val: "" }
  let ext : @utils.Externals = {
    fs: make_vfs(files),
    println: fn(text) { output.val = output.val + text + "\n" },
    get_args: fn() { [] },
    exit: fn(_) { () },
  }
  @driver.run(path="fixture.yodl", commands=@driver.parse_commands("test two"), ext~)
  assert_eq(output.val, "PASS two\n")
}

test "test names with spaces can be selected" {
  let source =
    "module And(a: bool) -> (out: bool) { out = a; }\n" +
    "test \"one\" for And { expect!(out, false); }\n" +
    "test \"two words\" for And { expect!(out, false); }\n"
  let files : Map[String, String] = Map([])
  files["fixture.yodl"] = source
  let output : Ref[String] = { val: "" }
  let ext : @utils.Externals = {
    fs: make_vfs(files),
    println: fn(text) { output.val = output.val + text + "\n" },
    get_args: fn() { [] },
    exit: fn(_) { () },
  }
  @driver.run(path="fixture.yodl", commands=@driver.parse_commands("test two words"), ext~)
  assert_eq(output.val, "PASS two words\n")
}

test "test locals can capture peek values and preserve signed values" {
  let source =
    "module Pass(a: uint[8]) -> (out: uint[8]) { out = a; }\n" +
    "test \"peek\" for Pass {\n" +
    "  drive!(a, -1)\n" +
    "  let observed = peek!(out)\n" +
    "  expect!(out, 255)\n" +
    "  let two = 1 + 1\n" +
    "  drive!(a, two)\n" +
    "  expect!(out, 2)\n" +
    "  let composed = peek!(out) and 255\n" +
    "  expect!(out, composed)\n" +
    "  let quotient = 8 / observed\n" +
    "  drive!(a, quotient)\n" +
    "  expect!(out, 0)\n" +
    "  drive!(a, 2)\n" +
    "  let divisor = peek!(out)\n" +
    "  let four = 8 / divisor\n" +
    "  drive!(a, four)\n" +
    "  expect!(out, 4)\n" +
    "}\n"
  let files : Map[String, String] = Map([])
  files["fixture.yodl"] = source
  let output : Ref[String] = { val: "" }
  let ext : @utils.Externals = {
    fs: make_vfs(files),
    println: fn(text) { output.val = output.val + text + "\n" },
    get_args: fn() { [] },
    exit: fn(_) { () },
  }
  @driver.run(path="fixture.yodl", commands=@driver.parse_commands("test"), ext~)
  assert_eq(output.val, "PASS peek\n")
}

test "test values preserve known bits, reject overflow, and honor signed locals" {
  let source =
    "module Values(flag: bool, value: uint[8]) -> (out: uint[8]) { out = value; }\n" +
    "test \"values\" for Values {\n" +
    "  drive!(flag, true)\n" +
    "  let widened = peek!(flag)\n" +
    "  drive!(value, widened)\n" +
    "  expect!(out, 1)\n" +
    "  let negative: sint[8] = -1\n" +
    "  drive!(flag, negative < 0)\n" +
    "  expect!(flag, true)\n" +
    "}\n"
  let files : Map[String, String] = Map([])
  files["fixture.yodl"] = source
  let output : Ref[String] = { val: "" }
  let ext : @utils.Externals = {
    fs: make_vfs(files),
    println: fn(text) { output.val = output.val + text + "\n" },
    get_args: fn() { [] },
    exit: fn(_) { () },
  }
  @driver.run(path="fixture.yodl", commands=@driver.parse_commands("test"), ext~)
  assert_eq(output.val, "PASS values\n")

  let overflow =
    "module Pass(a: uint[8]) -> (out: uint[8]) { out = a; }\n" +
    "test \"overflow\" for Pass { drive!(a, 1 shl 8); }\n"
  assert_true(compile_error(overflow, cmd_str="test").contains("requires 9 bits"))
}

test "test constants store peek values and signed peeks preserve their type" {
  let source =
    "module Values(a: sint[8], flag: bool) -> (signed: sint[8], ok: bool) { signed = a; ok = flag; }\n" +
    "test \"stored and signed\" for Values {\n" +
    "  const saved = peek!(ok)\n" +
    "  drive!(flag, true)\n" +
    "  expect!(ok, true)\n" +
    "  drive!(flag, saved)\n" +
    "  expect!(ok, false)\n" +
    "}\n" +
    "test \"signed peek\" for Values {\n" +
    "  drive!(a, -1)\n" +
    "  let observed = peek!(signed)\n" +
    "  drive!(flag, observed < 0)\n" +
    "  expect!(ok, true)\n" +
    "}\n"
  assert_eq(compile_stage(source, "test"), "PASS signed peek")
}

test "test validation rejects invalid ports and DUT aliases" {
  let bad_output =
    "module And(a: bool) -> (out: bool) { out = a; }\n" +
    "test \"bad output\" for And { drive!(out, true); }\n"
  assert_true(compile_error(bad_output, cmd_str="test").contains("Cannot drive output port"))

  let bad_name =
    "module And(a: bool) -> (out: bool) { out = a; }\n" +
    "test \"bad name\" for And { expect!(missing, false); }\n"
  assert_true(compile_error(bad_name, cmd_str="test").contains("Unknown DUT port"))

  let bad_alias =
    "module And(a: bool) -> (out: bool) { out = a; }\n" +
    "test \"bad alias\" {\n" +
    "  let first = And()\n" +
    "  let second = And()\n" +
    "  expect!(first.out, false)\n" +
    "}\n"
  assert_true(compile_error(bad_alias, cmd_str="test").contains("exactly one DUT instance"))

  let bad_clock =
    "module Dual(clk_a: clock, clk_b: clock) -> (out: bool) { out = false; }\n" +
    "test \"bad clock\" for Dual { step!(1); }\n"
  assert_true(compile_error(bad_clock, cmd_str="test").contains("exactly one clock"))

  let connected_instance =
    "module Pass(a: bool) -> (out: bool) { out = a; }\n" +
    "test \"connected\" { let dut = Pass(a: true); expect!(dut.out, true); }\n"
  assert_true(compile_error(connected_instance, cmd_str="test").contains("connections in a test instance are not supported"))

  let typed_local =
    "module Pass(a: uint[8]) -> (out: uint[8]) { out = a; }\n" +
    "test \"typed local\" for Pass { let x: bool = 255; drive!(a, x); }\n"
  assert_true(compile_error(typed_local, cmd_str="test").contains("local 'x' is only 1 bits"))

  let negative_step =
    "module Clocked(clk: clock) -> (out: bool) { out = false; }\n" +
    "test \"negative step\" for Clocked { step!(-1); }\n"
  assert_true(compile_error(negative_step, cmd_str="test").contains("cycle count must be non-negative"))

  let runtime_zero =
    "module Pass(a: uint[8]) -> (out: uint[8]) { out = a; }\n" +
    "test \"division\" for Pass { let zero = peek!(out); let q = 8 / zero; drive!(a, q); }\n"
  let zero_error = compile_error(runtime_zero, cmd_str="test")
  assert_true(zero_error.contains("Division by zero in test expression"))
  assert_false(zero_error.contains("RuntimeError"))
}

test "test scopes restore shadowed local values" {
  let source =
    "module Pass(a: uint[8]) -> (out: uint[8]) { out = a; }\n" +
    "test \"scope\" for Pass {\n" +
    "  let x = 1\n" +
    "  for i in 0..<1 { let x = 2; }\n" +
    "  drive!(a, x)\n" +
    "  expect!(out, 1)\n" +
    "}\n"
  let files : Map[String, String] = Map([])
  files["fixture.yodl"] = source
  let output : Ref[String] = { val: "" }
  let ext : @utils.Externals = {
    fs: make_vfs(files),
    println: fn(text) { output.val = output.val + text + "\n" },
    get_args: fn() { [] },
    exit: fn(_) { () },
  }
  @driver.run(path="fixture.yodl", commands=@driver.parse_commands("test"), ext~)
  assert_eq(output.val, "PASS scope\n")
}

test "test execution fails on DUT assertions and stops" {
  let assertion =
    "module Guard(clk: clock, a: bool) -> (out: bool) {\n" +
    "  out = a\n" +
    "  assert!(a)\n" +
    "}\n" +
    "test \"assertion\" for Guard { drive!(a, false); step!(1); }\n"
  assert_true(compile_error(assertion, cmd_str="test").contains("simulation assertion failed"))

  let stopped =
    "module Stopper(clk: clock) -> (out: bool) {\n" +
    "  out = false\n" +
    "  stop!()\n" +
    "}\n" +
    "test \"stop\" for Stopper { step!(1); }\n"
  assert_true(compile_error(stopped, cmd_str="test").contains("simulation stopped"))
}

test "test-only top selection does not change normal ambiguity errors" {
  let source =
    "module First(a: bool) -> (out: bool) { out = a; }\n" +
    "module Second(a: bool) -> (out: bool) { out = a; }\n" +
    "test \"first\" { let dut = First(); expect!(dut.out, false); }\n"
  assert_true(compile_error(source, cmd_str="write_source").contains("Multiple top-level modules"))

  let generic_only =
    "module Pass[N: Nat](a: uint[N]) -> (out: uint[N]) { out = a; }\n" +
    "test \"generic\" { let dut = Pass[8](); expect!(dut.out, 0); }\n"
  assert_true(compile_error(generic_only, cmd_str="write_source").contains("No top-level module"))
}

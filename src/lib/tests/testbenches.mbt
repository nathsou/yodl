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
    "  expect!(out, observed)\n" +
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
    "test \"first\" for First { expect!(out, false); }\n"
  assert_true(compile_error(source, cmd_str="write_source").contains("Multiple top-level modules"))
}

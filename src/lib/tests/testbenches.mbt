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

test "instance parameters resolve constants before builtins" {
  let source =
    "const N = 20\n" +
    "module Child[Width: Nat](input: uint[Width]) -> (output: uint[Width]) {\n" +
    "  output = input\n" +
    "}\n" +
    "module Top(input: u8) -> (output: u8) {\n" +
    "  let child = Child[Width: cdiv!(N, 3) + 1](input: input)\n" +
    "  output = child.output\n" +
    "}\n"

  let mono = compile_stage(source, "write_mono")
  assert_eq(mono.contains("module Child$0(\n  input: u8"), true)
}

test "builtin evaluation defers non-literal arguments" {
  let source =
    "module Top() -> () {\n" +
    "  let value = cdiv!(Unknown, 3)\n" +
    "}\n"
  let body = module_body(parse_source(source))
  let expr = match body[0] {
    @parse.Stmt::Let(expr=Some(expr), ..) => expr
    _ => @utils.fail("expected a let expression")
  }

  match expr.partial_eval() {
    @parse.Expr::FunCall(name="cdiv", args~, ..) => assert_eq(args.length(), 2)
    _ => @utils.fail("expected unresolved cdiv expression")
  }
}

test "invalid instance parameters report a diagnostic" {
  let source =
    "module Child[Width: Nat](input: uint[Width]) -> (output: uint[Width]) {\n" +
    "  output = input\n" +
    "}\n" +
    "module Top(input: u8) -> (output: u8) {\n" +
    "  let child = Child[Width: cdiv!(Unknown, 3)](input: input)\n" +
    "  output = child.output\n" +
    "}\n"
  let message = try {
    let _ = compile_stage(source, "write_mono")
    ""
  } catch {
    error => error.to_string()
  }

  assert_eq(message.contains("Invalid parameter"), true)
}

test "invalid size-function domains in Nat parameters report diagnostics" {
  let invalid = [
    (
      "module Child[N: Nat]() -> () {}\n" +
      "module Top() -> () {\n" +
      "  let child = Child[N: cdiv!(8, 0)]()\n" +
      "}\n",
      "ceiling-division divisor must be positive, got 0",
    ),
    (
      "module Child[N: Nat]() -> () {}\n" +
      "module Top() -> () {\n" +
      "  let child = Child[N: clog2!(0 - 1)]()\n" +
      "}\n",
      "Invalid negative clog2 argument -1",
    ),
  ]

  for case in invalid {
    let (source, expected) = case
    let message = try {
      let _ = compile_stage(source, "write_mono")
      ""
    } catch {
      error => error.to_string()
    }
    assert_true(message.contains(expected))
    assert_false(message.contains("RuntimeError"))
  }
}

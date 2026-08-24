///|
/// Phase-0 regression: an unsigned FIRRTL-producing operator may be resized by
/// an unsigned context, but must never be context-retagged as signed.
test "unsigned addition is rejected in a signed context" {
  let source =
    #|module Top(a: u8, b: u8) -> (out: s9) {
    #|  out = a + b
    #|}
  let diagnostic = compile_error(source)
  assert_true(
    diagnostic.has_prefix(
      "Incompatible types 's9' and 'u9', fixture.yodl:2.3-2.14",
    ),
  )
  assert_true(diagnostic.contains("2   out = a + b\n    ^^^^^^^^^^^"))
}

///|
/// Phase-0 regression: aggregate contexts flow recursively to unsized
/// literals, so their intrinsic checked type is concrete before Core is built.
test "annotated vector and record literals accept unsized elements" {
  let source =
    #|type Pair = (x: u8, ys: [2]s5)
    #|
    #|module Top() -> (vec: [2]u8, rec: Pair) {
    #|  vec = [1, 255]
    #|  rec = (x: 3, ys: [4, 7])
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("output vec_0: UInt<8>"))
  assert_true(firrtl.contains("output rec_x: UInt<8>"))
  assert_true(firrtl.contains("output rec_ys_0: SInt<5>"))
}

///|
test "aggregate compatibility rejects shape errors and normalizes strings" {
  let accepted =
    #|module Top() -> (text: [2]u8, nested: (x: [2]u4)) {
    #|  text = "yo"
    #|  nested = (x: [1, 2])
    #|}
  let _ = compile_stage(accepted, "write_low_firrtl")

  let rejected = [
    (
      #|module Top() -> (out: [2]u8) { out = [1]; }
    ),
    (
      #|module Top() -> (out: (x: u8, y: u8)) { out = (x: 1); }
    ),
    (
      #|module Top() -> (out: (x: u8)) { out = (x: 1, y: 2); }
    ),
    (
      #|module Top() -> (out: [2](x: u8)) { out = [(x: 1), (y: 2)]; }
    ),
  ]
  for source in rejected {
    assert_true(compile_error(source).contains("Incompatible types"))
  }
}

///|
test "contextual literals report overflow at the literal span" {
  let source =
    #|module Top() -> (out: [2]u3) {
    #|  out = [7, 8]
    #|}
  let diagnostic = compile_error(source)
  assert_true(
    diagnostic.contains("Literal requires 4 bits but context provides u3"),
  )
  assert_true(diagnostic.contains("fixture.yodl:2.13-2.14"))
}

///|
test "operator signedness rules have positive and negative coverage" {
  let accepted = [
    (
      #|module Top(a: u8, b: u8) -> (out: u9) { out = a + b; }
    ),
    (
      #|module Top(a: s8, b: s8) -> (out: s9) { out = a - b; }
    ),
    (
      #|module Top(a: u8, n: u3) -> (out: u8) { out = a shl n; }
    ),
  ]
  for source in accepted {
    let _ = compile_stage(source, "write_low_firrtl")
  }

  let rejected = [
    (
      #|module Top(a: u8, b: s8) -> (out: u9) { out = a + b; }
    ),
    (
      #|module Top(a: s8, b: s8) -> (out: u9) { out = a - b; }
    ),
    (
      #|module Top(a: u8, n: s3) -> (out: u8) { out = a shl n; }
    ),
  ]
  for source in rejected {
    let diagnostic = compile_error(source)
    assert_true(
      diagnostic.contains("Invalid operands") ||
      diagnostic.contains("Incompatible types"),
    )
  }
}

///|
test "unary operators retain intrinsic result kinds" {
  let accepted =
    #|module Top(a: u8, b: s8) -> (inv: u8, neg: s9, red: bool) {
    #|  inv = not a
    #|  neg = -b
    #|  red = xorr a
    #|}
  let _ = compile_stage(accepted, "write_low_firrtl")

  let rejected =
    #|module Top(clk: clock) -> (out: u1) {
    #|  out = not clk
    #|}
  let diagnostic = compile_error(rejected)
  assert_true(diagnostic.contains("Invalid operand type 'clock' for unary operator"))
}

///|
test "literal width inference is traversal-order independent" {
  let source =
    #|module Top() -> () {
    #|  let ascending = [1, 255]
    #|  let descending = [255, 1]
    #|}
  let simplified = compile_stage(source, "write_simplified")
  assert_true(simplified.contains("let ascending: [2]u8"))
  assert_true(simplified.contains("let descending: [2]u8"))
}

///|
test "instance aliases preserve identity while port usage stays outside types" {
  let source =
    #|module Child(input: u8) -> (output: u8) {
    #|  output = input
    #|}
    #|
    #|module Top(value: u8) -> (result: u8) {
    #|  let child = Child()
    #|  let alias = child
    #|  alias.input = value
    #|  result = alias.output
    #|}
  let first = compile_stage(source, "write_low_firrtl")
  let second = compile_stage(source, "write_low_firrtl")
  assert_eq(first, second)
  assert_true(first.contains("wire child_input: UInt<8>"))
  assert_true(first.contains("wire child_output: UInt<8>"))
  assert_true(first.contains("connect inst_0$.input, child_input"))
  assert_true(first.contains("connect child_output, inst_0$.output"))
}

///|
test "instance branches union actual port demand deterministically" {
  let source =
    #|module Child(value: u8) -> (output: u8) {
    #|  output = value
    #|}
    #|
    #|module Top(select: bool, left_value: u8, right_value: u8) -> (result: u8) {
    #|  let left = Child(value: left_value)
    #|  let right = Child(value: right_value)
    #|  let selected = select ? left : right
    #|  result = selected.output
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("wire left_output: UInt<8>"))
  assert_true(firrtl.contains("wire right_output: UInt<8>"))
}

///|
test "instance direction errors stay attached to the assignment" {
  let source =
    #|module Child() -> (output: u8) {
    #|  output = 0
    #|}
    #|
    #|module Top(value: u8) -> () {
    #|  let child = Child()
    #|  child.output = value
    #|}
  let diagnostic = compile_error(source)
  assert_true(
    diagnostic.has_prefix(
      "Cannot assign to output port 'output' of module 'Child', fixture.yodl:7.3-7.23",
    ),
  )
}

///|
test "every accepted fixture passes FIRRTL type checking" {
  let fixture_files = @fs.read_dir(fixture_dir)
  fixture_files.sort()
  for fixture_file in fixture_files {
    if fixture_file.has_suffix(".yodl") {
      let source = @fs.read_file_to_string("\{fixture_dir}/\{fixture_file}")
      let _ = compile_stage(source, "write_firrtl")
    }
  }
}

///|
test "Nat-parameterized aliases fail with an explicit phase-boundary diagnostic" {
  let source =
    #|type Bytes[N: Nat] = [N]u8
    #|module Top() -> () {}
  let diagnostic = compile_error(source)
  assert_true(
    diagnostic.contains(
      "Type alias 'Bytes' declares a Nat parameter, which is not supported yet",
    ),
  )
}

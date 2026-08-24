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
test "contextual signed literals retain their frozen FIRRTL width" {
  let source =
    #|module Top() -> (out: s4) {
    #|  out = 7
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("SInt<4>(7)"))
}

///|
test "contextual negative literals check the signed value as a whole" {
  for value in ["-7", "-8"] {
    let source =
      "module Top() -> (out: s4) { out = \{value}; }"
    let firrtl = compile_stage(source, "write_low_firrtl")
    assert_true(firrtl.contains("SInt<4>(\{value})"))
  }

  let overflow =
    #|module Top() -> (out: s4) {
    #|  out = -9
    #|}
  assert_true(
    compile_error(overflow).contains(
      "Negative literal does not fit in contextual type s4",
    ),
  )
}

///|
test "empty vectors adopt only a contextual zero-length vector type" {
  let accepted =
    #|module Top() -> (out: [0]u8) {
    #|  out = []
    #|}
  let _ = compile_stage(accepted, "write_simplified")

  let ambiguous =
    #|module Top() -> () {
    #|  let ambiguous = []
    #|}
  let diagnostic = compile_error(ambiguous)
  assert_true(
    diagnostic.contains("Empty vector literal requires a contextual [0]T type"),
  )
}

///|
test "every binary operator has positive and negative coverage" {
  let unsigned_rules = [
    ("+", "u9"), ("-", "u9"), ("*", "u16"), ("/", "u8"),
    ("%", "u8"), ("==", "bool"), ("!=", "bool"), ("<", "bool"),
    (">", "bool"), ("<=", "bool"), (">=", "bool"), ("and", "u8"),
    ("or", "u8"), ("xor", "u8"), ("nand", "u8"), ("nor", "u8"),
    ("xnor", "u8"),
  ]
  for rule in unsigned_rules {
    let (op, out_ty) = rule
    let source =
      "module Top(a: u8, b: u8) -> (out: \{out_ty}) { out = a \{op} b; }"
    let _ = compile_stage(source, "write_low_firrtl")
  }

  let signed_rules = [
    ("+", "s9"), ("-", "s9"), ("*", "s16"), ("/", "s9"),
    ("%", "s8"), ("==", "bool"), ("!=", "bool"), ("<", "bool"),
    (">", "bool"), ("<=", "bool"), (">=", "bool"), ("and", "u8"),
    ("or", "u8"), ("xor", "u8"), ("nand", "u8"), ("nor", "u8"),
    ("xnor", "u8"),
  ]
  for rule in signed_rules {
    let (op, out_ty) = rule
    let source =
      "module Top(a: s8, b: s8) -> (out: \{out_ty}) { out = a \{op} b; }"
    let _ = compile_stage(source, "write_low_firrtl")
  }

  let shifts = [
    "module Top(a: u8) -> (out: u10) { out = a shl 2; }",
    "module Top(a: s8) -> (out: s10) { out = a shl 2; }",
    "module Top(a: u8) -> (out: u6) { out = a shr 2; }",
    "module Top(a: s8) -> (out: s6) { out = a shr 2; }",
    "module Top(a: u8, n: u3) -> (out: u15) { out = a shl n; }",
    "module Top(a: s8, n: u3) -> (out: s15) { out = a shl n; }",
    "module Top(a: u8, n: u3) -> (out: u8) { out = a shr n; }",
    "module Top(a: s8, n: u3) -> (out: s8) { out = a shr n; }",
  ]
  for source in shifts {
    let _ = compile_stage(source, "write_low_firrtl")
  }

  for rule in unsigned_rules {
    let (op, _) = rule
    let source =
      "module Top(a: u8, b: s8) -> (out: u16) { out = a \{op} b; }"
    let diagnostic = compile_error(source)
    assert_true(
      diagnostic.contains("Invalid operands") ||
      diagnostic.contains("Incompatible types"),
    )
  }

  for op in ["shl", "shr"] {
    let source =
      "module Top(a: u8, n: s3) -> (out: u16) { out = a \{op} n; }"
    assert_true(compile_error(source).contains("Invalid operands"))
  }

  let ternary =
    #|module Top(select: bool, a: u8, b: u8) -> (out: u8) {
    #|  out = select ? a : b
    #|}
  let _ = compile_stage(ternary, "write_low_firrtl")
  let invalid_ternary =
    #|module Top(select: bool, a: u8, b: s8) -> (out: u8) {
    #|  out = select ? a : b
    #|}
  assert_true(compile_error(invalid_ternary).contains("Incompatible types"))
}

///|
test "every unary operator has positive and negative coverage" {
  let accepted =
    #|module Top(a: u8, b: s8) -> (inv: u8, neg: s9, and_red: bool, or_red: bool, xor_red: bool) {
    #|  inv = not a
    #|  neg = -b
    #|  and_red = andr a
    #|  or_red = orr a
    #|  xor_red = xorr a
    #|}
  let _ = compile_stage(accepted, "write_low_firrtl")

  for op in ["not", "-", "andr", "orr", "xorr"] {
    let source =
      "module Top(clk: clock) -> (out: u1) { out = \{op} clk; }"
    let diagnostic = compile_error(source)
    assert_true(
      diagnostic.contains("Invalid operand type 'clock' for unary operator"),
    )
  }
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
test "explicitly typed instance aliases retain identity" {
  let source =
    #|module Child(input: u8) -> (output: u8) {
    #|  output = input
    #|}
    #|
    #|module Top(value: u8) -> (result: u8) {
    #|  let child = Child()
    #|  let alias: Child = child
    #|  alias.input = value
    #|  result = alias.output
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("wire child_input: UInt<8>"))
  assert_true(firrtl.contains("wire child_output: UInt<8>"))
}

///|
test "instance aliases assigned after declaration retain identity" {
  let source =
    #|module Child(input: u8) -> (output: u8) {
    #|  output = input
    #|}
    #|
    #|module Top(value: u8) -> (result: u8) {
    #|  let child = Child()
    #|  let alias: Child
    #|  alias = child
    #|  alias.input = value
    #|  result = alias.output
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("wire child_input: UInt<8>"))
  assert_true(firrtl.contains("wire child_output: UInt<8>"))
  assert_true(firrtl.contains("wire alias_input: UInt<8>"))
  assert_true(firrtl.contains("wire alias_output: UInt<8>"))
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
test "if branches and nested records union instance identities" {
  let source =
    #|module Child(value: u8) -> (output: u8) {
    #|  output = value
    #|}
    #|
    #|module Top(select: bool, left_value: u8, right_value: u8) -> (direct: u8, nested: u8) {
    #|  let if_left = Child(value: left_value)
    #|  let if_right = Child(value: right_value)
    #|  let record_left = Child(value: left_value)
    #|  let record_right = Child(value: right_value)
    #|  let left_wrapped = (child: record_left)
    #|  let right_wrapped = (child: record_right)
    #|  let selected = if select { if_left; } else { if_right; }
    #|  let wrapped = [left_wrapped, right_wrapped][select]
    #|  direct = selected.output
    #|  nested = wrapped.child.output
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("wire if_left_output: UInt<8>"))
  assert_true(firrtl.contains("wire if_right_output: UInt<8>"))
  assert_true(firrtl.contains("wire record_left_output: UInt<8>"))
  assert_true(firrtl.contains("wire record_right_output: UInt<8>"))
}

///|
test "instance constructor ports receive contextual literal and aggregate types" {
  let source =
    #|module Child(signed: s4, values: [2]s5) -> (output: s4) {
    #|  output = signed
    #|}
    #|
    #|module Top() -> (result: s4) {
    #|  let child = Child(signed: 7, values: [4, 7])
    #|  result = child.output
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("SInt<4>(7)"))
  assert_true(firrtl.contains("SInt<5>(4)"))
}

///|
test "instance static type arguments are resolved before Core" {
  let source =
    #|module Top(clk: clock, mask: bool) -> (result: bool) {
    #|  let reg = Reg[T: MemoryMask[u8]](clk, d: mask)
    #|  result = reg.q
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("wire reg_d: UInt<1>"))
  assert_true(firrtl.contains("wire reg_q: UInt<1>"))
}

///|
test "Unit-valued let bindings lower their effects without hardware wires" {
  let source =
    #|module Top(clk: clock, pred: bool) -> () {
    #|  let ignored = assert!(pred)
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("assert("))
  assert_false(firrtl.contains("wire ignored"))
}

///|
test "negative hardware dimensions are rejected at the Core boundary" {
  let invalid = [
    "module Top() -> (out: uint[1 - 2]) {}",
    "module Top() -> (out: [1 - 2]u8) {}",
  ]
  for source in invalid {
    assert_true(compile_error(source).contains("Invalid negative"))
  }
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

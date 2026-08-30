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
      "Incompatible types 's9' and 'u9', fixture.yodl:2.11-2.14",
    ),
  )
  assert_true(diagnostic.contains("2   out = a + b"))
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
test "aggregate compatibility recursively coerces typed values" {
  let source =
    #|module Top() -> (vector: [2]u8, record: (value: u8, nested: [2]u8)) {
    #|  let narrow_vector: [2]u4 = [1, 2]
    #|  let narrow_record: (value: u4, nested: [2]u4) = (value: 3, nested: [4, 5])
    #|  vector = narrow_vector
    #|  record = narrow_record
    #|}
  let simplified = compile_stage(source, "write_simplified")
  assert_true(simplified.contains("vector = [zero_extend(narrow_vector[0]), zero_extend(narrow_vector[1])]"))
  assert_true(simplified.contains("zero_extend(narrow_record.value)"))
  assert_true(simplified.contains("zero_extend(__coerced[0])"))
  assert_true(simplified.contains("zero_extend(__coerced[1])"))
  let _ = compile_stage(source, "write_low_firrtl")
}

///|
test "aggregate coercions evaluate statementful sources once" {
  let source =
    #|module Top() -> (out: [2]u8) {
    #|  out = {
    #|    let narrow: [2]u4 = [1, 2]
    #|    narrow
    #|  }
    #|}
  let _ = compile_stage(source, "write_low_firrtl")
}

///|
test "aggregate coercions bind statement-free sources before projecting" {
  let source =
    #|module Top(a: u4, b: u4) -> (out: [2]u8) {
    #|  out = fill!(2, a + b)
    #|}
  let simplified = compile_stage(source, "write_simplified")
  assert_true(simplified.contains("let __coerced"))
  assert_true(simplified.contains("zero_extend(__coerced[0])"))
  assert_true(simplified.contains("zero_extend(__coerced[1])"))
  let _ = compile_stage(source, "write_low_firrtl")
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
test "match patterns adopt the concrete integer subject type" {
  let source =
    #|module Top(unsigned: u8, signed: s8) -> (uout: u1, sout: u1, nout: u1) {
    #|  uout = match unsigned {
    #|    1 => 1'd1
    #|    _ => 1'd0
    #|  }
    #|  sout = match signed {
    #|    1 => 1'd1
    #|    _ => 1'd0
    #|  }
    #|  nout = match 1 {
    #|    1 => 1'd1
    #|    _ => 1'd0
    #|  }
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("eq(unsigned, UInt<8>(1))"))
  assert_true(firrtl.contains("eq(signed, SInt<8>(1))"))
  assert_true(firrtl.contains("connect nout, UInt<1>(1)"))
}

///|
test "match patterns reject literals that do not fit the subject" {
  let source =
    #|module Top(subject: u3) -> (out: u1) {
    #|  out = match subject {
    #|    8 => 1'd1
    #|    _ => 1'd0
    #|  }
    #|}
  let diagnostic = compile_error(source)
  assert_true(
    diagnostic.contains("Literal requires 4 bits but context provides u3"),
  )
  assert_true(diagnostic.contains("fixture.yodl:3.5-3.6"))
}

///|
test "constant assertions fold through explicit coercions" {
  let always_true =
    #|module Top() -> () {
    #|  assert!(2'd1)
    #|}
  let simplified = compile_stage(always_true, "write_simplified")
  assert_false(simplified.contains("assert!("))

  let always_false =
    #|module Top() -> () {
    #|  assert!(2'd0)
    #|}
  assert_true(compile_error(always_false).contains("Assertion always fails"))

  let truncated_false =
    #|module Top() -> () {
    #|  assert!(2'd2)
    #|}
  assert_true(compile_error(truncated_false).contains("Assertion always fails"))
}

///|
test "inferred unsigned literals cannot acquire signedness from context" {
  let source =
    #|module Top() -> () {
    #|  let n = 1
    #|  let s: s8 = n
    #|}
  let diagnostic = compile_error(source)
  assert_true(diagnostic.contains("Incompatible types 's8' and 'u1'"))
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
test "folded negative literals remain signed and reject unsigned contexts" {
  let source =
    #|module Top() -> () {
    #|  let minus_one = 0 - 1
    #|  let minus_four = 0 - 4
    #|}
  let simplified = compile_stage(source, "write_simplified")
  assert_true(simplified.contains("let minus_one: s1"))
  assert_true(simplified.contains("let minus_four: s3"))

  let signed =
    #|module Top() -> (minus_one: s1, minus_four: s3) {
    #|  minus_one = 0 - 1
    #|  minus_four = 0 - 4
    #|}
  let firrtl = compile_stage(signed, "write_low_firrtl")
  assert_true(firrtl.contains("SInt<1>(-1)"))
  assert_true(firrtl.contains("SInt<3>(-4)"))

  let unsigned = "module Top() -> (out: u1) { out = 0 - 1; }"
  assert_true(
    compile_error(unsigned).contains(
      "Negative literal cannot be represented as unsigned type u1",
    ),
  )

  let overflow = "module Top() -> (out: s3) { out = 0 - 5; }"
  assert_true(
    compile_error(overflow).contains(
      "Literal requires 4 signed bits but context provides s3",
    ),
  )
}

///|
test "signed binary narrowing preserves FIRRTL signedness" {
  let source =
    #|module Top(a: s8, b: s8) -> (out: s8) {
    #|  out = a + b
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("asSInt(bits(add("))
}

///|
test "integer resizing is explicit in Core and FIRRTL" {
  let source =
    #|module Top(a: u8, b: u8, c: s8, d: s8) -> (un: u8, uw: u12, sn: s8, sw: s12) {
    #|  un = a + b
    #|  uw = a + b
    #|  sn = c + d
    #|  sw = c + d
    #|}
  let simplified = compile_stage(source, "write_simplified")
  assert_true(simplified.contains("un = truncate((a + b))"))
  assert_true(simplified.contains("uw = zero_extend((a + b))"))
  assert_true(simplified.contains("sn = truncate((c + d))"))
  assert_true(simplified.contains("sw = sign_extend((c + d))"))

  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("connect un, bits(add(a, b), 7, 0)"))
  assert_true(firrtl.contains("connect uw, pad(add(a, b), 12)"))
  assert_true(firrtl.contains("connect sn, asSInt(bits(add(c, d), 7, 0))"))
  assert_true(firrtl.contains("connect sw, pad(add(c, d), 12)"))
}

///|
test "resizing applies to values, conditionals, and instance ports" {
  let source =
    #|module Child(input: u12) -> (output: u12) {
    #|  output = input
    #|}
    #|
    #|module Top(select: u2, a: u8, b: u8) -> (direct: u12, selected: u8, port: u12) {
    #|  direct = a
    #|  selected = select ? a + b : a
    #|  let child = Child(input: a + b)
    #|  port = child.output
    #|}
  let simplified = compile_stage(source, "write_simplified")
  assert_true(simplified.contains("direct = zero_extend(a)"))
  assert_true(simplified.contains("selected = truncate("))
  assert_true(simplified.contains("match truncate(select)"))
  assert_true(simplified.contains("zero_extend(a)"))
  assert_true(simplified.contains("input: zero_extend((a + b))"))
  let _ = compile_stage(source, "write_low_firrtl")
}

///|
test "signedness changes require explicit conversion" {
  let signed_to_unsigned =
    #|module Top(a: s8) -> (out: u4) {
    #|  out = a
    #|}
  assert_true(
    compile_error(signed_to_unsigned).contains("Incompatible types 'u4' and 's8'"),
  )

  let explicit =
    #|module Top(a: u8) -> (out: s8) {
    #|  out = sint!(a)
    #|}
  let _ = compile_stage(explicit, "write_low_firrtl")
}

///|
test "contextual literals need no resize coercion" {
  let source =
    #|module Top() -> (unsigned: u12, signed: s12) {
    #|  unsigned = 7
    #|  signed = 7
    #|}
  let simplified = compile_stage(source, "write_simplified")
  assert_false(simplified.contains("extend(7)"))
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("UInt<12>(7)"))
  assert_true(firrtl.contains("SInt<12>(7)"))
}

///|
test "typed constants retain their resolved declared type" {
  let source =
    #|const VALUE: s4 = 7
    #|module Top() -> (out: s4) {
    #|  out = VALUE
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("SInt<4>(7)"))
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
test "unsigned literal joins are traversal-order independent" {
  let source =
    #|module Top(select: bool, unsigned: u8, signed: s8, narrow: u4) -> () {
    #|  let ternary_nat_first = select ? 1 : unsigned
    #|  let ternary_nat_last = select ? unsigned : 1
    #|  let match_nat_first = match select {
    #|    1 => 1
    #|    _ => unsigned
    #|  }
    #|  let match_nat_last = match select {
    #|    1 => unsigned
    #|    _ => 1
    #|  }
    #|  let vector_nat_first = [1, unsigned]
    #|  let vector_nat_last = [unsigned, 1]
    #|  let vector_branch_nat_first = select ? [1] : [unsigned]
    #|  let vector_branch_nat_last = select ? [unsigned] : [1]
    #|  let record_branch_nat_first = select ? (value: 1) : (value: unsigned)
    #|  let record_branch_nat_last = select ? (value: unsigned) : (value: 1)
    #|  let widened_nat_first = select ? 255 : narrow
    #|  let widened_nat_last = select ? narrow : 255
    #|}
  let simplified = compile_stage(source, "write_simplified")
  for name in [
    "ternary_nat_first", "ternary_nat_last", "match_nat_first",
    "match_nat_last", "widened_nat_first", "widened_nat_last",
  ] {
    assert_true(simplified.contains("let \{name}: u8"))
  }
  assert_true(simplified.contains("let vector_nat_first: [2]u8"))
  assert_true(simplified.contains("let vector_nat_last: [2]u8"))
  assert_true(simplified.contains("let vector_branch_nat_first: [1]u8"))
  assert_true(simplified.contains("let vector_branch_nat_last: [1]u8"))
  assert_false(simplified.contains("truncate(unsigned)"))
  let _ = compile_stage(source, "write_low_firrtl")

  let signed =
    #|module Top(select: bool, value: s8) -> () {
    #|  let result = select ? 1 : value
    #|}
  assert_true(compile_error(signed).contains("Incompatible types 'u1' and 's8'"))
}

///|
test "uncontextualized natural literals synthesize canonical unsigned widths" {
  let source =
    #|module Top() -> () {
    #|  let one = 1
    #|  let wide = 255
    #|}
  let simplified = compile_stage(source, "write_simplified")
  assert_true(simplified.contains("let one: u1"))
  assert_true(simplified.contains("let wide: u8"))
}

///|
test "unsized integer type annotations report a missing width" {
  for ty in ["uint", "sint"] {
    let source = "module Top(value: \{ty}) -> () {}"
    assert_true(
      compile_error(source).contains("Integer types require a width"),
    )
  }
}

///|
test "static Nat arguments reject negative constant expressions" {
  for width in ["0 - 1", "-1"] {
    let source = "module Top() -> () { let value = pad!(1'b0, \{width}); }"
    assert_true(
      compile_error(source).contains("Expected a nonnegative constant expression"),
    )
  }
}

///|
test "module Nat arguments must be nonnegative numeric constants" {
  let source =
    #|module Box[N: Nat](input: uint[N]) -> (output: uint[N]) {
    #|  output = input
    #|}
    #|
    #|module Top(value: u1) -> () {
    #|  let box = Box[N: 0 - 1](input: value)
    #|}
  assert_true(compile_error(source).contains("Invalid parameter of sort 'Nat'"))
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
test "instance aliases assigned through aggregates retain identity" {
  let source =
    #|module Child(input: u8) -> (output: u8) {
    #|  output = input
    #|}
    #|
    #|module Top(value: u8) -> (result: u8) {
    #|  let child = Child()
    #|  let holder: (child: Child)
    #|  holder.child = child
    #|  holder.child.input = value
    #|  result = holder.child.output
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("wire child_input: UInt<8>"))
  assert_true(firrtl.contains("wire child_output: UInt<8>"))
  assert_true(firrtl.contains("wire holder_child_input: UInt<8>"))
  assert_true(firrtl.contains("wire holder_child_output: UInt<8>"))
}

///|
test "instance input assignments are tracked as writes without spurious reads" {
  let source =
    #|module Child(input: u8) -> (output: u8) {
    #|  output = input
    #|}
    #|
    #|module Top(first: u8, second: u8) -> (result: u8) {
    #|  let child = Child(input: first)
    #|  child.input = second
    #|  result = child.output
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("connect child_input, second"))
  assert_true(firrtl.contains("connect inst_0$.input, child_input"))
  assert_false(firrtl.contains("connect inst_0$.input, first"))
}

///|
test "lvalue checking preserves reads used by dynamic indices" {
  let source =
    #|module Index(value: bool) -> (output: bool) {
    #|  output = value
    #|}
    #|module Child(input: [2]u8) -> (output: u8) {
    #|  output = input[0]
    #|}
    #|module Top(select: bool, first: u8, second: u8) -> (result: u8) {
    #|  let index = Index(value: select)
    #|  let child = Child(input: [first, first])
    #|  child.input[index.output] = second
    #|  result = child.output
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("wire index_output: UInt<1>"))
  assert_true(firrtl.contains("mux(eq(index_output, UInt<1>(0)), second"))
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
test "declared module type annotations resolve nested static types" {
  let source =
    #|declare module Cell[T: Type](input: T) -> (output: T)
    #|module Top(value: bool) -> (result: bool) {
    #|  let cell = Cell[T: MemoryMask[u8]]()
    #|  let alias: Cell[MemoryMask[u8]] = cell
    #|  alias.input = value
    #|  result = alias.output
    #|}
  let simplified = compile_stage(source, "write_simplified")
  assert_true(simplified.contains("Cell[u1]"))
}

///|
test "source module type annotations use the monomorphized nominal type" {
  let source =
    #|module Cell[T: Type](input: T) -> (output: T) {
    #|  output = input
    #|}
    #|module Top(value: u8) -> (result: u8) {
    #|  let cell = Cell[T: u8]()
    #|  let alias: Cell[u8] = cell
    #|  alias.input = value
    #|  result = alias.output
    #|}
  let firrtl = compile_stage(source, "write_low_firrtl")
  assert_true(firrtl.contains("wire cell_input: UInt<8>"))
  assert_true(firrtl.contains("wire cell_output: UInt<8>"))
}

///|
test "module type annotations reject Nat-sorted static arguments" {
  let source =
    #|declare module Box[N: Nat](input: uint[N]) -> (output: uint[N])
    #|module Top() -> () {
    #|  let box: Box[u4]
    #|}
  let diagnostic = compile_error(source)
  assert_true(
    diagnostic.contains(
      "parameter 'N' expects a Nat argument, which cannot be written in a type annotation",
    ),
  )
}

///|
test "MemoryMask defers generic parameters but rejects concrete non-storable types" {
  let generic =
    #|declare module Masked[T: Type](mask: MemoryMask[T]) -> ()
    #|module Top() -> () {}
  let _ = compile_stage(generic, "write_simplified")

  let concrete =
    #|module Child() -> () {}
    #|module Top() -> () {
    #|  let mask: MemoryMask[Child]
    #|}
  let diagnostic = compile_error(concrete)
  assert_true(diagnostic.contains("Type 'Child' is not storable"))
  assert_false(diagnostic.contains("reached Core construction"))
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
test "negative hardware dimensions are rejected during type resolution" {
  let invalid = [
    "module Top() -> (out: uint[1 - 2]) {}",
    "module Top() -> (out: [1 - 2]u8) {}",
  ]
  for source in invalid {
    assert_true(compile_error(source).contains("Invalid negative"))
  }
}

///|
test "size expressions reject invalid function domains during type resolution" {
  let invalid = [
    (
      "module Top() -> (out: uint[clog2!(1 - 2)]) {}",
      "Invalid negative clog2 argument -1",
    ),
    (
      "module Top() -> (out: uint[cdiv!(1 - 2, 4)]) {}",
      "Invalid negative ceiling-division dividend -1",
    ),
    (
      "module Top() -> (out: uint[cdiv!(8, 0)]) {}",
      "ceiling-division divisor must be positive, got 0",
    ),
  ]
  for case in invalid {
    let (source, expected) = case
    let diagnostic = compile_error(source)
    assert_true(diagnostic.contains(expected))
    assert_true(diagnostic.contains("fixture.yodl:1"))
  }
}

///|
test "size expressions define zero behavior for clog2 and ceiling division" {
  let source =
    #|module Top() -> (log: uint[clog2!(0)], div: uint[cdiv!(0, 4)]) {}
  let simplified = compile_stage(source, "write_simplified")
  assert_true(simplified.contains("log: u0"))
  assert_true(simplified.contains("div: u0"))
}

///|
test "symbolic affine sizes are canonicalized during type resolution" {
  let source =
    #|declare module Shapes[M: Nat, N: Nat](
    #|  a: uint[N + 1],
    #|  b: uint[1 + N],
    #|  c: uint[2 * N + 2],
    #|  d: uint[N + N + 2],
    #|  e: uint[cdiv!(N, 4)],
    #|  f: uint[N * 0],
    #|  g: uint[N + M],
    #|  h: uint[M + N],
    #|) -> ()
    #|
    #|module Top() -> () {}
  let typed = compile_stage(source, "write_typed")
  assert_true(typed.contains("a: uint<N + 1>"))
  assert_true(typed.contains("b: uint<N + 1>"))
  assert_true(typed.contains("c: uint<2 * N + 2>"))
  assert_true(typed.contains("d: uint<2 * N + 2>"))
  assert_true(typed.contains("e: uint<cdiv!(N, 4)>"))
  assert_true(typed.contains("f: u0"))
  assert_true(typed.contains("g: uint<M + N>"))
  assert_true(typed.contains("h: uint<M + N>"))
}

///|
test "declared module ports revalidate size domains after Nat substitution" {
  let source =
    #|declare module Cell[N: Nat](unused: uint[cdiv!(8, N)]) -> ()
    #|
    #|module Top() -> () {
    #|  let cell = Cell[N: 0]()
    #|}
  let diagnostic = compile_error(source)
  assert_true(diagnostic.contains("ceiling-division divisor must be positive, got 0"))
  assert_true(diagnostic.contains("fixture.yodl:1"))
  assert_false(diagnostic.contains("reached Core construction"))
}

///|
test "ordinary module unresolved sizes are rejected before Core construction" {
  let source =
    #|module Top() -> (out: uint[Unknown]) {}
  let diagnostic = compile_error(source)
  assert_true(diagnostic.contains("Unresolved integer width"))
  assert_false(diagnostic.contains("reached Core construction"))
}

///|
test "declared module unresolved non-parameter sizes are rejected" {
  let source =
    #|declare module Cell(input: uint[Unknown]) -> ()
    #|module Top() -> () {}
  let diagnostic = compile_error(source)
  assert_true(diagnostic.contains("Unresolved integer width"))
  assert_false(diagnostic.contains("reached Core construction"))
}

///|
test "declared module signatures resolve global size constants" {
  let source =
    #|const D = 0
    #|
    #|declare module Cell(unused: uint[cdiv!(8, D)]) -> ()
    #|
    #|module Top() -> () {
    #|  let cell = Cell()
    #|}
  let diagnostic = compile_error(source)
  assert_true(diagnostic.contains("ceiling-division divisor must be positive, got 0"))
  assert_true(diagnostic.contains("fixture.yodl:3"))
  assert_false(diagnostic.contains("reached Core construction"))
}

///|
test "declared module Nat parameters shadow global size constants" {
  let source =
    #|const N = 4
    #|
    #|declare module Cell[N: Nat](input: uint[N]) -> ()
    #|
    #|module Top() -> () {}
  let typed = compile_stage(source, "write_typed")
  assert_true(typed.contains("input: uint<N>"))
  assert_false(typed.contains("input: u4"))
}

///|
test "non-affine size identity multiplication is canonicalized" {
  let source =
    #|declare module Shapes[N: Nat](
    #|  multiplied: uint[1 * clog2!(N)],
    #|  direct: uint[clog2!(N)],
    #|) -> ()
    #|
    #|module Top() -> () {}
  let typed = compile_stage(source, "write_typed")
  assert_true(typed.contains("multiplied: uint<clog2!(N)>"))
  assert_true(typed.contains("direct: uint<clog2!(N)>"))
}

///|
test "nested non-affine constant multiplication is canonicalized" {
  let source =
    #|declare module Shapes[N: Nat](
    #|  nested: uint[2 * (3 * clog2!(N))],
    #|  combined: uint[6 * clog2!(N)],
    #|) -> ()
    #|
    #|module Top() -> () {}
  let typed = compile_stage(source, "write_typed")
  assert_true(typed.contains("nested: uint<6 * clog2!(N)>"))
  assert_true(typed.contains("combined: uint<6 * clog2!(N)>"))
}

///|
test "zero multiplication of non-affine sizes is canonicalized" {
  let source =
    #|declare module Shapes[N: Nat, M: Nat](
    #|  left: uint[0 * clog2!(N)],
    #|  right: uint[clog2!(N) * 0],
    #|  nested: uint[(N * M) * 0],
    #|) -> ()
    #|
    #|module Top() -> () {}
  let typed = compile_stage(source, "write_typed")
  assert_true(typed.contains("left: u0"))
  assert_true(typed.contains("right: u0"))
  assert_true(typed.contains("nested: u0"))
}

///|
test "zero multiplication still validates non-affine size domains" {
  let invalid = [
    "module Top() -> (out: uint[0 * clog2!(1 - 2)]) {}",
    "module Top() -> (out: uint[0 * cdiv!(8, 0)]) {}",
  ]
  for source in invalid {
    let diagnostic = compile_error(source)
    assert_true(diagnostic.contains("Invalid negative") || diagnostic.contains("must be positive"))
    assert_true(diagnostic.contains("fixture.yodl:1"))
  }
}

///|
test "size-function diagnostics use the failing call span" {
  let source =
    #|module Top() -> (
    #|  out: uint[1 +
    #|    cdiv!(8, 0)]) {}
  let diagnostic = compile_error(source)
  assert_true(diagnostic.contains("fixture.yodl:3.5-3.15"))
}

///|
test "size-function spans do not affect semantic type equality" {
  let source =
    #|module Box[N: Nat](input: uint[clog2!(N)]) -> (output: uint[clog2!(N)]) {
    #|  output = input
    #|}
  let decls = parse_source(source)
  let (input_width, output_width) = match decls[0] {
    @parse.Decl::Module(mod) => match (mod.ports[0].ty, mod.ports[1].ty) {
      (@parse.Type::UInt(input_width), @parse.Type::UInt(output_width)) =>
        (input_width, output_width)
      _ => @utils.fail("expected integer module ports")
    }
    _ => @utils.fail("expected a module declaration")
  }
  assert_true(input_width == output_width)
}

///|
test "zero multiplication preserves domains through declared instantiation" {
  let source =
    #|declare module Cell[N: Nat](unused: uint[0 * clog2!(N - 2)]) -> ()
    #|module Top() -> () {
    #|  let cell = Cell[N: 1]()
    #|}
  let diagnostic = compile_error(source)
  assert_true(diagnostic.contains("Invalid negative clog2 argument -1"))
}

///|
test "invalid size-function diagnostics preserve the inner call span" {
  let source =
    #|module Child[N: Nat]() -> () {}
    #|module Top() -> () {
    #|  let child = Child[N: 1 + cdiv!(8, 0)]()
    #|}
  let diagnostic = compile_error(source, cmd_str="write_mono")
  assert_true(diagnostic.contains("fixture.yodl:3.32-3.38"))
  assert_false(diagnostic.contains("fixture.yodl:3.24-3.38"))
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

  let nested =
    #|module Child() -> (output: (value: u8)) {
    #|  output = (value: 0)
    #|}
    #|module Top(value: u8) -> () {
    #|  let child = Child()
    #|  child.output.value = value
    #|}
  assert_true(
    compile_error(nested).contains(
      "Cannot assign to output port 'output' of module 'Child'",
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

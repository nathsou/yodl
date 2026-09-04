
test "memory masks preserve validity only for bits that survive the write" {
  let unknown = SimValue::new(8, 0, known=false)
  let known = SimValue::from_int(8, 165)
  let full = masked_write(unknown, known, SimValue::from_int(1, 1), 8)
  assert_true(full.is_known())
  assert_eq(full.as_bigint().to_int(), 165)
  let noop = masked_write(known, unknown, SimValue::from_int(1, 0), 8)
  assert_true(noop.is_known())
  assert_eq(noop.as_bigint().to_int(), 165)
  assert_false(masked_write(unknown, known, SimValue::from_int(2, 1), 8).is_known())
  assert_false(masked_write(known, known, SimValue::new(1, 1, known=false), 8).is_known())
}


test "memory masks preserve validity only for bits that survive the write" {
  let unknown = SimValue::new(8, 0, known=false)
  let known = SimValue::from_int(8, 165)
  let full = masked_write(unknown, known, SimValue::from_int(1, 1), 8)
  assert_true(full.is_known())
  assert_eq(full.as_bigint().to_int(), 165)
  let noop = masked_write(known, unknown, SimValue::from_int(1, 0), 8)
  assert_true(noop.is_known())
  assert_eq(noop.as_bigint().to_int(), 165)
  let low_lane = masked_write(unknown, known, SimValue::from_int(2, 1), 8)
  assert_eq(low_lane.as_bigint().to_int(), 5)
  assert_eq(low_lane.known_mask().to_int(), 15)
  let completed = masked_write(low_lane, SimValue::from_int(8, 0x30), SimValue::from_int(2, 2), 8)
  assert_true(completed.is_known())
  assert_eq(completed.as_bigint().to_int(), 0x35)

  let unknown_mask = masked_write(known, known, SimValue::new(1, 1, known=false), 8)
  assert_eq(unknown_mask.known_mask().to_int(), 0)
}

test "memory write collisions invalidate only overlapping lanes" {
  let old = SimValue::new(8, 0, known=false)
  let disjoint = resolve_writes(old, [
    { address: Some(0), data: SimValue::from_int(8, 0x05), mask: SimValue::from_int(2, 1) },
    { address: Some(0), data: SimValue::from_int(8, 0xa0), mask: SimValue::from_int(2, 2) },
  ], 8)
  assert_true(disjoint.is_known())
  assert_eq(disjoint.as_bigint().to_int(), 0xa5)

  let overlap = resolve_writes(SimValue::from_int(8, 0xff), [
    { address: Some(0), data: SimValue::from_int(8, 0x01), mask: SimValue::from_int(2, 1) },
    { address: Some(0), data: SimValue::from_int(8, 0x02), mask: SimValue::from_int(2, 1) },
  ], 8)
  assert_eq(overlap.known_mask().to_int(), 0xf0)
  assert_eq(overlap.as_bigint().to_int(), 0xf0)
}

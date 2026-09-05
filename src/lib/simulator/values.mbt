/// A fixed-width value with independent validity for every bit. Unknown
/// backing bits are canonicalized to zero so equality and transition checks
/// observe only meaningful state.
pub(all) struct SimValue {
  width: Int
  raw: BigInt
  known_mask: BigInt
}

pub fn SimValue::new(width: Int, raw: BigInt, known~: Bool = true) -> SimValue {
  let known_mask = if known { mask(width) } else { 0 }
  SimValue::with_mask(width, raw, known_mask)
}

pub fn SimValue::with_mask(width: Int, raw: BigInt, known_mask: BigInt) -> SimValue {
  let known_mask = normalize(known_mask, width)
  { width, raw: normalize(raw, width) & known_mask, known_mask }
}

pub fn SimValue::zero(width: Int) -> SimValue { SimValue::new(width, 0) }

pub fn SimValue::from_int(width: Int, value: Int) -> SimValue {
  SimValue::new(width, BigInt::from_int(value))
}

pub fn SimValue::as_bigint(self: SimValue) -> BigInt { self.raw }

pub fn SimValue::is_known(self: SimValue) -> Bool {
  self.known_mask == mask(self.width)
}

pub fn SimValue::known_mask(self: SimValue) -> BigInt { self.known_mask }

pub fn SimValue::bit(self: SimValue, index: Int) -> SimValue {
  if index < 0 || index >= self.width {
    SimValue::new(1, 0, known=false)
  } else {
    SimValue::with_mask(1, (self.raw >> index) & 1, (self.known_mask >> index) & 1)
  }
}

pub impl Show for SimValue with output(self, logger) {
  if self.is_known() { logger.write_string(self.raw.to_string()) } else { logger.write_string("x") }
}

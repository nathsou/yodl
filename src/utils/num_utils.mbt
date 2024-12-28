
pub fn max(a: Int, b: Int) -> Int {
  if a > b { a } else { b }
}

pub fn min(a: Int, b: Int) -> Int {
  if a < b { a } else { b }
}

pub fn sum(iter: Iter[Int]) -> Int {
  iter.fold(fn(a, b) { a + b }, init=0)
}

pub fn clog2(n: Int) -> Int {
  @math.ceil(@math.log2(n.to_double())).to_int()
}

pub fn pow2(n: Int) -> Int {
  1 << n
}

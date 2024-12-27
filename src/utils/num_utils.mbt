
pub fn max(a: Int, b: Int) -> Int {
  if a > b { a } else { b }
}

pub fn min(a: Int, b: Int) -> Int {
  if a < b { a } else { b }
}

pub fn sum(iter: Iter[Int]) -> Int {
  iter.fold(fn(a, b) { a + b }, init=0)
}

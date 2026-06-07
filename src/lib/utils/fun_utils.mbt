
pub fn[T] unreachable_code() -> T {
  fail("unreachable")
}

pub fn[T] fail(msg: String) -> T {
  abort(msg)
}

pub fn[T] identity(x: T) -> T { x }

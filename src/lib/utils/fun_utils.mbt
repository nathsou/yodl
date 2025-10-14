
pub fn unreachable() -> Failure {
  Failure("unreachable")
}

pub fn[T] fail(msg: String) -> T {
  println("Error: " + msg)
  abort(msg)
}
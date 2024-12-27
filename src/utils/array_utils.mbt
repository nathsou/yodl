
pub fn zip[X, Y](xs: Array[X], ys: Array[Y]) -> Iter2[X, Y] {
  let len = min(xs.length(), ys.length())

  Iter2::new(fn(visit: ((X, Y) -> IterResult)) -> IterResult {
    for i in 0..<len {
      if visit(xs[i], ys[i]) == IterEnd {
        break IterEnd
      }
    } else {
      IterContinue
    }
  })
}

pub fn concat[T](xs: Array[T], ys: Array[T]) -> Array[T] {
  let result = Array::new(capacity=xs.length() + ys.length())

  for i in 0..<xs.length() {
    result.push(xs[i])
  }

  for i in 0..<ys.length() {
    result.push(ys[i])
  }

  result
}

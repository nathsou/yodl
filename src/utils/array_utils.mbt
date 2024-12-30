
pub fn zip[X, Y](xs: Array[X], ys: Array[Y]) -> Iter[(X, Y)] {
  let len = min(xs.length(), ys.length())

  Iter::new(fn(visit: (((X, Y)) -> IterResult)) -> IterResult {
    for i in 0..<len {
      if visit((xs[i], ys[i])) == IterEnd {
        break IterEnd
      }
    } else {
      IterContinue
    }
  })
}

pub fn zip2[X, Y](xs: Array[X], ys: Array[Y]) -> Iter2[X, Y] {
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
  result.push_iter(xs.iter())
  result.push_iter(ys.iter())
  result
}

pub fn fill[T](n: Int, value: T) -> Array[T] {
  let result = Array::new(capacity=n)

  for _ in 0..<n {
    result.push(value)
  }

  result
}

pub fn merge[K: Eq + Hash, V](map1: Map[K, V], map2: Map[K, V]) -> Map[K, V] {
  let result = {}

  for key, value in map1 {
    result[key] = value
  }

  for key, value in map2 {
    result[key] = value
  }

  result
}

pub fn map[A, B, E: Error](values: Array[A], f: (A) -> B!E) -> Array[B]!E {
  let mapped = Array::new(capacity=values.length())

  for index, value in values {
    mapped[index] = f!(value)
  }
  
  mapped
}

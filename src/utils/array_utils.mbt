
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
  let result = Map::new(capacity=map1.size() + map2.size())

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

pub fn map_values[K: Eq + Hash, V](map: Map[K, V], f: (V) -> V) -> Map[K, V] {
  let result = Map::new(capacity=map.size())

  for key, value in map {
    result[key] = f(value)
  }

  result
}

pub fn map_keys[K1: Eq + Hash, K2: Eq + Hash, V](map: Map[K1, V], f: (K1, V) -> K2) -> Map[K2, V] {
  let result = Map::new(capacity=map.size())

  for key, value in map {
    result[f(key, value)] = value
  }

  result
}

pub fn sorted_keys[K: Eq + Hash + Compare, V](map: Map[K, V]) -> Map[K, V] {
  let sorted_keys = { let keys = map.keys().collect(); keys.sort(); keys }
  let new_map = Map::new(capacity=map.size())

  for key in sorted_keys {
    new_map[key] = map[key].unwrap()
  }

  new_map
}

pub fn is_ascii(c: Char) -> Bool {
  let n = c.to_int()
  n >= 0 && n <= 255
}

pub fn filter_map[A, B](elems: Iter[A], f: (A) -> B?) -> Iter[B] {
  Iter::new(fn(visit: ((B) -> IterResult)) -> IterResult {
    for elem in elems {
      match f(elem) {
        Some(mapped) => {
          if visit(mapped) == IterEnd {
            break IterEnd
          }
        }
        None => ()
      }
    } else {
      IterContinue
    }
  })
}

pub fn chunk[T](elems: Iter[T], size: Int) -> Iter[Array[T]] {
  Iter::new(fn(visit: ((Array[T]) -> IterResult)) -> IterResult {
    let mut chunk = Array::new(capacity=size)

    for elem in elems {
      chunk.push(elem)

      if chunk.length() == size {
        if visit(chunk) == IterEnd {
          break IterEnd
        }

        chunk = Array::new(capacity=size)
      }
    } else {
      if chunk.length() > 0 {
        visit(chunk)
      } else {
        IterContinue
      }
    }
  })
}

pub fn all_eq[T: Eq](elems: Array[T]) -> Bool {
  if elems.length() == 0 {
    true
  } else {
    let first = elems[0]

    for i in 1..<elems.length() {
      if elems[i] != first {
        return false
      }
    }

    true
  }
}

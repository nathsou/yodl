
pub fn[X, Y] zip_iter(xs: Iterator[X], ys: Iterator[Y]) -> Iterator[(X, Y)] {
  Iterator::new(() => {
    match (xs.next(), ys.next()) {
      (Some(x), Some(y)) => {
        Some((x, y))
      }
      _ => None
    }
  })
}

pub fn[X, Y] zip(xs: Array[X], ys: Array[Y]) -> Iterator[(X, Y)] {
  zip_iter(xs.iterator(), ys.iterator())
}

pub fn[X, Y] zip2_iter(xs: Iterator[X], ys: Iterator[Y]) -> Iterator2[X, Y] {
  let iter = zip_iter(xs, ys)

  Iterator::new(() => {
    match iter.next() {
      Some((x, y)) => Some((x, y))
      None => None
    }
  })
}

pub fn[X, Y] zip2(xs: Array[X], ys: Array[Y]) -> Iterator2[X, Y] {
  zip2_iter(xs.iterator(), ys.iterator())
}

pub fn[T] concat(xs: Array[T], ys: Array[T]) -> Array[T] {
  let result = Array::new(capacity=xs.length() + ys.length())
  result.push_iter(xs.iter())
  result.push_iter(ys.iter())
  result
}

pub fn[T] fill(n: Int, value: T) -> Array[T] {
  let result = Array::new(capacity=n)

  for _ in 0..<n {
    result.push(value)
  }

  result
}

pub fn[K: Eq + Hash, V] merge(map1: Map[K, V], map2: Map[K, V]) -> Map[K, V] {
  let result = Map::new(capacity=map1.length() + map2.length())

  for key, value in map1 {
    result[key] = value
  }

  for key, value in map2 {
    result[key] = value
  }

  result
}

pub fn[A, B, E: Error] map(values: Array[A], f: (A) -> B raise E) -> Array[B] raise E {
  let mapped = Array::new(capacity=values.length())

  for value in values {
    mapped.push(f(value))
  }
  
  mapped
}

pub fn[K: Eq + Hash, U, V] map_values(map: Map[K, U], f: (U) -> V) -> Map[K, V] {
  let result = Map::new(capacity=map.length())

  for key, value in map {
    result[key] = f(value)
  }

  result
}

pub fn[K1, K2: Eq + Hash, V] map_keys(map: Map[K1, V], f: (K1, V) -> K2) -> Map[K2, V] {
  let result = Map::new(capacity=map.length())

  for key, value in map {
    result[f(key, value)] = value
  }

  result
}

pub fn[K: Eq + Hash + Compare, V] sorted_keys(map: Map[K, V]) -> Map[K, V] {
  let sorted_keys = { let keys = map.keys().collect(); keys.sort(); keys }
  let new_map = Map::new(capacity=map.length())

  for key in sorted_keys {
    new_map[key] = map.get(key).unwrap()
  }

  new_map
}

pub fn is_ascii(c: Char) -> Bool {
  let n = c.to_int()
  n >= 0 && n <= 255
}

pub fn[A, B] filter_map(elems: Iterator[A], f: (A) -> B?) -> Iterator[B] {
  Iterator::new(() => {
    while true {
      match elems.next() {
        Some(elem) => {
          if f(elem) is Some(mapped) {
            return Some(mapped)
          }
        }
        None => return None
      }
    } else {
      None
    }
  })
}

pub fn[T] chunk(elems: Iterator[T], size: Int) -> Iterator[Array[T]] {
  let mut chunks = Array::new(capacity=size)

  Iterator::new(() => {
    match elems.next() {
      Some(elem) => {
        chunks.push(elem)

        if chunks.length() == size {
          let result = chunks
          chunks = Array::new(capacity=size)
          Some(result)
        } else {
          None
        }
      }
      None => {
        if chunks.length() > 0 {
          Some(chunks)
        } else {
          None
        }
      }
    }
  })
}

pub fn[T: Eq] all_eq(elems: Array[T]) -> Bool {
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

pub fn [K: Eq + Hash, V] push_map(map: Map[K, Array[V]], key: K, value: V) -> Unit {
  if map.get(key) is Some(values) {
    values.push(value)
  } else {
    map[key] = [value]
  }
}
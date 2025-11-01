
pub fn max(a: Int, b: Int) -> Int {
  if a > b { a } else { b }
}

pub fn min(a: Int, b: Int) -> Int {
  if a < b { a } else { b }
}

pub fn clamp(n: Int, min~: Int, max~: Int) -> Int {
  if n < min { min } else if n > max { max } else { n }
}

pub fn sum(iter: Iter[Int]) -> Int {
  iter.fold(Int::add, init=0)
}

pub fn clog2(n: BigInt) -> BigInt {
  let mut p: BigInt = 1
  let mut i: BigInt = 0

  while i < 1024 {
    if p >= n {
      return i
    }

    p = p << 1
    i += 1
  }

  1024
}

pub fn cdiv(dividend: BigInt, divisor: BigInt) -> BigInt {
  let quotient = dividend / divisor

  if quotient * divisor == dividend {
    quotient
  } else {
    quotient + 1
  }
}

// returns the ceiling of the square root of n
pub fn csqrt(n: BigInt) -> BigInt {
  let mut i: BigInt = 0

  while i < n {
    if i * i >= n {
      return i
    }

    i += 1
  }

  0
}

pub fn pow2(n: Int) -> BigInt {
  BigInt::from_int(1) << n
}

pub fn pow(n: BigInt, exp: BigInt) -> BigInt {
  let mut n = n
  let mut exp = exp
  let mut res: BigInt = 1

  while exp > 0 {
    if (exp & 1) == 1 {
      res *= n
    }

    n *= n
    exp /= 2
  }

  res
}

pub fn log_n(n: Double, base: Double) -> Double {
  let d = match base {
    2 => 1.0
    8 => 3.0
    10 => 3.321928094887362
    16 => 4.0
    _ => @math.log2(base)
  }

  @math.log2(n) / d
}

pub fn abs(n: BigInt) -> BigInt {
  if n < 0 { -n } else { n }
}

pub fn log_b_2(base: Int) -> Double {
  match base {
    2 => 1.0
    8 => 0.3333333333333333
    10 => 0.3010299956639812
    16 => 0.25
    _ => 1.0 / @math.log2(base.to_double())
  }
}

pub fn show_nat(n: BigInt, base~: Int, width~: Int? = None) -> String {
  let builder = StringBuilder::new()
  let is_neg = n < 0
  let n = abs(n)
  let base_b = BigInt::from_int(base)

  if n == 0 {
    builder.write_char('0')
  } else {
    let mut n = n

    while n > 0 {
      let div = n / base_b
      let digit = n - (div * base_b)
      n = div
      builder.write_char(match digit {
          0 => '0'; 1 => '1'; 2 => '2'; 3 => '3'; 4 => '4'; 5 => '5'; 6 => '6'; 7 => '7'; 8 => '8'; 9 => '9'
          10 => 'a'; 11 => 'b'; 12 => 'c'; 13 => 'd'; 14 => 'e'; 15 => 'f'
          _ => '?'
      })
    }
  }

  let res = builder.to_string().rev()
  let res = if is_neg { "-" + res } else { res }
  
  match width {
    Some(width) => {
      let required_digits = @math.ceil(log_b_2(base) * width.to_double()).to_int()
      res.pad_start(required_digits, '0')
    }
    None => res
  }
}

pub fn bin(n: BigInt, width~: Int) -> Array[Bool] raise {
  let bits = Array::make(width, false)
  let a = if n < 0N {
    // two's complement for negative numbers
    let modulus = 1N << width
    (modulus + n) & (modulus - 1N)
  } else {
    n
  }

  if a.bit_length() > width {
    raise Failure("Value does not fit in specified width")
  }

  let octets = a.to_octets()
  let mut bit_idx = width - 1

  for i in 0..<octets.length() {
    let mut p = octets[octets.length() - 1 - i].to_uint()

    for _ in 0..<8 {
      if bit_idx < 0 {
        break
      }

      bits[bit_idx] = (p & 1) != 0
      p = p >> 1
      bit_idx -= 1
    }
  }

  bits
}

test "bin" {
  fn bin_str(n: BigInt, width: Int) -> String raise {
    bin(n, width~).map(bit => if bit { "1" } else { "0" }).join("")
  }

  inspect(bin_str(BigInt::from_int(17), 8), content="00010001")
  inspect(bin_str(BigInt::from_int64(473483), 24), content="000001110011100110001011")
  inspect(bin_str(BigInt::from_int64(473483), 20), content="01110011100110001011")
  inspect(bin_str(BigInt::from_int64(473483), 19), content="1110011100110001011")
  inspect((try? bin_str(BigInt::from_int64(473483), 18)) is Err(_), content="true")
  inspect(bin_str(BigInt::from_int64(-1), 8), content="11111111")
  inspect(bin_str(BigInt::from_int64(-473483), 24), content="111110001100011001110101")
  inspect(bin_str(BigInt::from_int64(0x3E676F7B73633E), 64), content="0000000000111110011001110110111101111011011100110110001100111110")
}

pub fn bits(n: BigInt) -> Array[Bool] raise {
  if n == 0 {
    return [false]
  }

  let width = clog2(abs(n) + 1).to_int()
  bin(n, width~)
}

pub fn bitwise_not(n: BigInt, width~: Int) -> BigInt raise {
  let mut res = 0N
  let mut p = 1N

  for bit in bin(n, width~).rev_iter() {
    if !bit {
      res += p
    }

    p = p << 1
  }

  res
}

test "bitwise_not" {
  inspect(bitwise_not(17, width=8), content="238")
  inspect(bitwise_not(1998, width=16), content="63537")
  inspect(bitwise_not(49, width=12), content="4046")
  inspect(bitwise_not(-17, width=8), content="16")
}

pub fn bools_to_bytes(bools: Iter[Bool]) -> Bytes {
  let bytes = FixedArray::from_iter(chunk(bools, 8).map(fn(chunk) {
    let mut byte = 0U

      for i in 0..<8 {
        if i < chunk.length() && chunk[i] {
          byte = byte | (1U << i)
        }
      }

    byte.to_byte()
  }))

  Bytes::from_fixedarray(bytes, len=bytes.length())
}

pub fn bools_to_bigint(bools: Iter[Bool]) -> BigInt {
  BigInt::from_octets(bools_to_bytes(bools))
}

pub fn significant_bits(n: BigInt, is_signed~: Bool = false) -> Int {
  if n == 0 {
    return 1
  }

  if n < 0 {
    return significant_bits(-n, is_signed=true)
  }

  let bytes = n.to_octets()
  let head = n.to_octets()[0].to_uint()
  let mut leading_zeros = 0

  for i in 0..=7 {
    let bit = head & (1U << (7 - i))
    if bit == 0U {
      leading_zeros += 1
    } else {
      break
    }
  }

  bytes.length() * 8 - leading_zeros + is_signed.to_int()
}

pub fn gcd(a: Int, b: Int) -> Int {
  let mut a = a
  let mut b = b

  while b != 0 {
    let temp = b
    b = a % b
    a = temp
  }

  a
}

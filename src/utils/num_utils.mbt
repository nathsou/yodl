
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
  iter.fold(fn(a, b) { a + b }, init=0)
}

pub fn clog2(n: Int) -> Int {
  let mut p = 1

  for i in 0..<64 {
    if p >= n {
      return i
    }

    p = p << 1
  }

  64
}

pub fn cdiv(dividend: Int, divisor: Int) -> Int {
  @math.ceil(dividend.to_double() / divisor.to_double()).to_int()
}

pub fn pow2(n: Int) -> Int {
  1 << n
}

pub fn pow(n: Int, exp: Int) -> Int {
  let mut n = n
  let mut exp = exp
  let mut res = 1

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
  @math.log10(n) / @math.log10(base)
}

pub fn show_digit(digit: BigInt) -> Char {
  match digit {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'a'
    11 => 'b'
    12 => 'c'
    13 => 'd'
    14 => 'e'
    15 => 'f'
    _ => '?'
  }
}

pub fn abs(n: BigInt) -> BigInt {
  if n < 0 { -n } else { n }
}

pub fn show_nat(n: BigInt, base~: Int, width~: Int? = None) -> String {
  let builder = StringBuilder::new()
  let is_neg = n < 0
  let n = abs(n)
  let base_bn = BigInt::from_int(base)

  if n == 0 {
    builder.write_char('0')
  } else {
    let mut n = n

    while n > 0 {
      let digit = n % base_bn
      n /= base_bn
      builder.write_char(show_digit(digit))
    }
  }

  let res = builder.to_string().rev()
  let res = if is_neg { "-" + res } else { res }
  
  match width {
    Some(width) => {
      let required_digits = @math.ceil(width.to_double() * log_n(2.0, base.to_double())).to_int()
      res.pad_start(required_digits, '0')
    }
    None => res
  }
}

pub fn bin(n: Int, width~: Int) -> Iter[Int] {
  let mut p = 1 << (width - 1)

  Iter::new(fn(visit: (Int) -> IterResult) -> IterResult {
    for i in 0..<width {
      if visit(if (n & p) == 0 { 0 } else { 1 }) == IterEnd {
        break IterEnd
      }

      p = p >> 1
    } else {
      IterContinue
    }
  })
}

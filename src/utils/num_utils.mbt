
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
  match n {
    0 => 1 // 1 bit is required to represent 0
    _ => @math.ceil(@math.log2(n.to_double())).to_int()
  }
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

pub fn show_digit(digit: Int) -> Char {
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

pub fn abs(n: Int) -> Int {
  if n < 0 { -n } else { n }
}

pub fn show_nat(n: Int, base~: Int, width~: Int? = None) -> String {
  let builder = StringBuilder::new()
  let is_neg = n < 0
  let n = abs(n)

  if n == 0 {
    builder.write_char('0')
  } else {
    let mut n = n

    while n > 0 {
      let digit = n % base
      n /= base
      builder.write_char(show_digit(digit))
    }
  }

  let res = builder.to_string().rev()
  let res = if is_neg { "-" + res } else { res }
  
  match width {
    Some(width) => {
      let required_digits = @math.ceil(log_n((pow2(width) - 1).to_double(), base.to_double())).to_int()
      res.pad_start(required_digits, '0')
    }
    None => res
  }
}

pub fn bin(n: Int, width~: Int) -> Array[Int] {
  let bits = Array::new(capacity=width)
  let mut n = n

  for i in 0..<width {
    bits.push(n & 1)
    n = n >> 1
  }

  bits.rev()
}

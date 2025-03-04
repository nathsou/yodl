
pub fn is_whitespace(c: Char) -> Bool {
  match c {
    ' ' => true
    '\t' => true
    '\n' => true
    '\r' => true
    _ => false
  }
}

pub fn is_digit(c: Char, base~: Int) -> Bool {
  match base {
    2 => c == '0' || c == '1'
    8 => c >= '0' && c <= '7'
    16 => (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
    _ => c >= '0' && c <= '9'
  }
}

pub fn is_alpha(c: Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

pub fn is_alphanumeric(c: Char) -> Bool {
  is_alpha(c) || is_digit(c, base=10)
}

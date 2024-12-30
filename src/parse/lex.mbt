
pub(readonly) struct Lexer {
  input: String
  mut index: Int
  mut line: Int
  mut column: Int
  file: String
}

pub(readonly) type! LexerError {
  UnexepectedChar(Char)
  InvalidWidthSpecifierDigit(Char)
  InvalidDigitInBase(digit~: Char, base~: Int)
} derive(Show)

fn is_whitespace(c: Char) -> Bool {
  match c {
    ' ' => true
    '\t' => true
    '\n' => true
    '\r' => true
    _ => false
  }
}

fn is_undetermined_digit(c: Char) -> Bool {
  c == 'x' || c == 'X' || c == 'z' || c == 'Z'
}

fn is_digit(c: Char, base~: Int) -> Bool {
  match base {
    2 => c == '0' || c == '1' || is_undetermined_digit(c)
    8 => c >= '0' && c <= '7'
    16 => (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F') // TODO: support x z in hex
    _ => c >= '0' && c <= '9'
  }
}

fn is_alpha(c: Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

fn is_alphanumeric(c: Char) -> Bool {
  is_alpha(c) || is_digit(c, base=10)
}

pub fn Lexer::new(input: String, file~: String) -> Lexer {
  { input, index: 0, line: 1, column: 1, file }
}

fn peek(self: Lexer) -> Char {
  self.input[self.index]
}

fn lookahead(self: Lexer, n: Int) -> Char {
  self.input[self.index + n]
}

fn next_non_whitespace(self: Lexer) -> Char? {
  let mut i = self.index

  while i < self.input.length() {
    let char = self.input[i]

    if not(is_whitespace(char)) {
      return Some(char)
    }

    i += 1
  }

  None
}

fn matches(self: Lexer, char: Char) -> Bool {
  self.peek() == char
}

fn matches_str(self: Lexer, chars: String) -> Bool {
  for i, char in chars {
    if self.lookahead(i) != char {
      return false
    }
  }

  true
}

fn consumes(self: Lexer, char: Char) -> Bool {
  if self.matches(char) {
    self.index += 1
    true
  } else {
    false
  }
}

fn skip_whitespaces(self: Lexer) -> Unit {
  while self.index < self.input.length() && is_whitespace(self.peek()) {
    self.advance()
  }
}

fn parse_identifier(self: Lexer) -> String {
  let builder = StringBuilder::new()
  
  for i in self.index..<self.input.length() {
    let char = self.input[i]

    if is_alphanumeric(char) || char == '_' {
      builder.write_char(char)
      self.advance()
    } else {
      break
    }
  }

  builder.to_string()
}

fn parse_digit(c: Char) -> Int!LexerError {
  match c {
    '0' => 0
    '1' => 1
    '2' => 2
    '3' => 3
    '4' => 4
    '5' => 5
    '6' => 6
    '7' => 7
    '8' => 8
    '9' => 9
    'a' | 'A' => 10
    'b' | 'B' => 11
    'c' | 'C' => 12
    'd' | 'D' => 13
    'e' | 'E' => 14
    'f' | 'F' => 15
    _ => raise InvalidWidthSpecifierDigit(c)
  }
}

fn parse_uint(s: String, base~: Int) -> Int!LexerError {
  let mut n = 0

  for c in s {
    n = n * base + parse_digit!(c)
  }

  n
}

struct ParsedInteger {
  bits: Bits
  width: Int?
  base: Int
}

fn parse_integer(self: Lexer) -> ParsedInteger! {
  let builder = StringBuilder::new()
  let mut base = 10
  let mut width = None
  let mut is_undetermined = false
  let span_start = (self.line, self.column)

  while self.index < self.input.length() {
    let char = self.peek()

    if is_digit(char, base~) {
      builder.write_char(char)

      if not(is_undetermined) {
        is_undetermined = is_undetermined_digit(char)
      }
      self.advance()
    } else if char == '\'' {
      self.advance()

      match self.peek() {
        'b' => { self.advance(); base = 2 }
        'o' => { self.advance(); base = 8 }
        'd' => { self.advance(); base = 10 }
        'h' => { self.advance(); base = 16 }
        _ => ()
      }

      width = Some(parse_uint!(builder.to_string(), base=10))
      builder.reset()
    } else if char == '_' {
      // ignore, used as a separator for readability
      self.advance()
    } else {
      break
    }
  }

  let span = { start: span_start, end: (self.line, self.column), file: self.file }

  let bits = if is_undetermined {
    let digits = builder.to_string()
    let bits = Array::new(capacity=digits.length())

    for digit in digits {
      bits.push(match digit {
        '0' => BinaryDigit::Zero
        '1' => BinaryDigit::One
        'x' | 'X' => BinaryDigit::X
        'z' | 'Z' => BinaryDigit::Z
        _ => raise InvalidDigitInBase(digit~, base=2)
      })
    }

    Bits::new(bits, span~)
  } else {
    let value = parse_uint!(builder.to_string(), base~)
    Bits::from!(value, width~, span~)
  }

  { bits, width, base }
}

fn advance(self: Lexer) -> Unit {
  if self.peek() == '\n' {
    self.line += 1
    self.column = 1
  } else {
    self.column += 1
  }

  self.index += 1
}

enum LexerResult[T] {
  Ok(T)
  Err(LexerError)
  EOF
}

fn next(self: Lexer) -> LexerResult[Token]! {
  self.skip_whitespaces()

  if self.index >= self.input.length() {
    return EOF
  }

  let char = self.peek()

  let start = (self.line, self.column)

  let val = match char {
    '(' => {
      self.advance()
      Ok(Lparen)
    }
    ')' => {
      self.advance()
      Ok(Rparen)
    }
    '{' => {
      self.advance()
      Ok(Lbrace)
    }
    '}' => {
      self.advance()
      Ok(Rbrace)
    }
    ',' => {
      self.advance()
      Ok(Comma)
    }
    ';' => {
      self.advance()
      Ok(Semicolon)
    }
    ':' => {
      self.advance()
      Ok(Colon)
    }
    '+' => {
      self.advance()
      Ok(Plus)
    }
    '-' => {
      self.advance()
      if self.consumes('>') {
        Ok(RightThinArrow)
      } else {
        Ok(Minus)
      }
    }
    '*' => {
      self.advance()
      Ok(Star)
    }
    '/' => {
      self.advance()
      // skip comments
      if self.consumes('/') {
        while self.peek() != '\n' {
          self.advance()
        }
        
        return self.next!()
      } else {
        Ok(Slash)
      }
    }
    '<' => {
      self.advance()

      if self.consumes('=') {
        Ok(LchevronEqual)
      } else if self.consumes('<') {
        Ok(LchevronLchevron)
      } else {
        Ok(Lchevron)
      }
    }
    '>' => {
      self.advance()

      if self.consumes('=') {
        Ok(RchevronEqual)
      } else if self.consumes('>') {
        Ok(RchevronRchevron)
      } else {
        Ok(Rchevron)
      }
    }
    '!' => {
      self.advance()
      if self.consumes('=') {
        Ok(BangEqual)
      } else {
        Ok(Bang)
      }
    }
    '?' => {
      self.advance()
      Ok(QuestionMark)
    }
    '=' => {
      self.advance()
      if self.consumes('=') {
        Ok(EqualEqual)
      } else if self.consumes('>') {
        Ok(RightThickArrow)
      } else {
        Ok(Equal)
      }
    }
    '[' => {
      self.advance()
      Ok(Lbracket)
    }
    ']' => {
      self.advance()
      Ok(Rbracket)
    }
    '.' => {
      self.advance()
      
      if self.consumes('.') {
        if self.consumes('<') {
          Ok(DotDotLeftChevron)
        } else if self.consumes('=') {
          Ok(DotDotEqual)
        } else if self.consumes('.') {
          Ok(DotDotDot)
        } else {
          Err(UnexepectedChar(char))
        }
      } else {
        Ok(Dot)
      }
    }
    '%' => {
      self.advance()
      Ok(Percent)
    }
    '@' => {
      self.advance()
      Ok(At)
    }
    '$' => {
      self.advance()
      Ok(Dollar)
    }
    '_' => {
      self.advance()
      Ok(Underscore)
    }
    '\'' => {
      self.advance()
      Ok(SingleQuote)
    }
    '"' => {
      let builder = StringBuilder::new()
      self.advance()

      while self.peek() != '"' {
        builder.write_char(self.peek())
        self.advance()
      }

      self.advance()
      Ok(StringLiteral(builder.to_string()))
    }
    _ => {
      if is_digit(char, base=10) {
        let { bits, width, base } = self.parse_integer!()
        Ok(Natural(bits~, width~, base~))
      } else if is_alpha(char) || char == '_' {
        let identifier = self.parse_identifier()

        Ok(match identifier {
          "module" => Module
          "let" => Let
          "logic" => Logic
          "in" => In
          "for" => For
          "declare" => Declare
          "match" => Match
          "and" => And
          "or" => Or
          "not" => Not
          "xor" => Xor
          "nand" => Nand
          "nor" => Nor
          "xnor" => Xnor
          "x" => {
            match self.next_non_whitespace() {
              Some('{' | '[') => X
              _ => Identifier("x")
            }
          }
          _ => Identifier(identifier)
        })
      } else {
        Err(UnexepectedChar(char))
      }
    }
  }

  let end = (self.line, self.column)

  match val {
    Ok(token) => Ok({ kind: token, span: { file: self.file, start, end } })
    Err(error) => Err(error)
    EOF => EOF
  }
}

pub fn lex(self: Lexer) -> Array[Token]! {
  let tokens = []

  while true {
    match self.next!() {
      Ok(token) => tokens.push(token)
      Err(error) => raise error
      EOF => break
    }
  }

  tokens
}

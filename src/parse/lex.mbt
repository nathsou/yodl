
pub struct Lexer {
  input: String
  mut index: Int
  mut line: Int
  mut column: Int
  file: String
}

pub type! LexerError {
  UnexepectedChar(char~: Char, span~: Span)
  InvalidDigitInBase(digit~: Char, base~: Int, span~: Span)
}

pub impl Show for LexerError with output(self, logger) -> Unit {
  match self {
    UnexepectedChar(char~, ..) => {
      logger.write_string("Unexpected character '\{char}'")
    }
    InvalidDigitInBase(digit~, base~, ..) => {
      logger.write_string("Invalid digit '\{digit}' in base \{base}")
    }
  }

  logger.write_string(self.show_context())
}

pub impl Spanned for LexerError with span(self: LexerError) -> Span {
  match self {
    UnexepectedChar(span~, ..) => span
    InvalidDigitInBase(span~, ..) => span
  }
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

    if not(@utils.is_whitespace(char)) {
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
  while self.index < self.input.length() && @utils.is_whitespace(self.peek()) {
    self.advance()
  }
}

fn parse_identifier(self: Lexer) -> String {
  let builder = StringBuilder::new()
  
  for i in self.index..<self.input.length() {
    let char = self.input[i]

    if @utils.is_alphanumeric(char) || char == '_' {
      builder.write_char(char)
      self.advance()
    } else {
      break
    }
  }

  builder.to_string()
}

fn parse_uint(s: String, base~: Int) -> BigInt {
  match base {
    2 => {
      let mut n: BigInt = 0
      let mut p: BigInt = 1

      for i in 0..<s.length() {
        if s[s.length() - i - 1] == '1' {
          n += p
        }

        p = p << 1
      }

      n
    }
    16 => BigInt::from_hex(s)
    _ => BigInt::from_string(s)
  }
}

struct ParsedInteger {
  bits: Bits
  width: Int?
  base: Int
}

fn span(self: Lexer, start: (Int, Int)) -> Span {
  { start, end: (self.line, self.column), file: self.file }
} 

fn parse_integer(self: Lexer) -> ParsedInteger! {
  let builder = StringBuilder::new()
  let mut base = 10
  let mut width = None
  let mut is_undetermined = false
  let span_start = (self.line, self.column)

  while self.index < self.input.length() {
    let char = self.peek()

    if @utils.is_digit(char, base~) {
      builder.write_char(char)

      if not(is_undetermined) {
        is_undetermined = @utils.is_undetermined_digit(char)
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

      width = Some(parse_uint(builder.to_string(), base=10).to_int())
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
        _ => raise InvalidDigitInBase(digit~, base=2, span~)
      })
    }

    Bits::new(bits, span~)
  } else {
    let num_str = builder.to_string()
    let max_bits = num_str.length() * (match base { 2 => 1; 8 => 3; _ => 4 })
    let value = parse_uint(num_str, base~)

    if max_bits < 32 {
      Bits::from!(value.to_int(), width~, span~)
    } else {
      Bits::from_bigint!(value, width~, span~)
    }
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
      if self.consumes(':') {
        Ok(ColonColon)
      } else {
        Ok(Colon)
      }
    }
    '+' => {
      self.advance()
      Ok(Plus)
    }
    '-' => {
      self.advance()
      if self.consumes('>') {
        Ok(RightThinArrow)
      } else if self.consumes(':') {
        Ok(MinusColon)
      } else {
        Ok(Minus)
      }
    }
    '*' => {
      self.advance()

      match self.next_non_whitespace() {
        Some('{' | '[') => Ok(X) // replication operator
        _ => Ok(Star)
      }
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
          self.advance()
          Err(UnexepectedChar(char~, span=self.span(start)))
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
        let char = self.peek()

        match char {
          '\\' => {
            self.advance()
            let escaped = self.peek()

            match escaped {
              'n' => builder.write_char('\n')
              'r' => builder.write_char('\r')
              't' => builder.write_char('\t')
              '\\' => builder.write_char('\\')
              '"' => builder.write_char('"')
              _ => builder.write_char(escaped)
            }
          }
          _ => {
            builder.write_char(char)
          }
        }

        self.advance()
      }

      self.advance()
      Ok(StringLiteral(builder.to_string()))
    }
    _ => {
      if @utils.is_digit(char, base=10) {
        let { bits, width, base } = self.parse_integer!()
        Ok(Natural(bits~, width~, base~))
      } else if @utils.is_alpha(char) || char == '_' {
        let identifier = self.parse_identifier()

        Ok(match identifier {
          "module" => Module
          "let" => Let
          "logic" => Logic
          "in" => In
          "for" => For
          "declare" => Declare
          "match" => Match
          "const" => Const
          "package" => Package
          "import" => Import
          "procedural" => Procedural
          "and" => And
          "or" => Or
          "not" => Not
          "xor" => Xor
          "nand" => Nand
          "nor" => Nor
          "xnor" => Xnor
          _ => Identifier(identifier)
        })
      } else {
        self.advance()
        Err(UnexepectedChar(char~, span=self.span(start)))
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

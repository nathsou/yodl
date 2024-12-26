
pub(readonly) struct Lexer {
  input: String
  mut index: Int
  mut line: Int
  mut column: Int
  file: String
}

pub(readonly) type! LexerError {
  UnexepectedChar(Char)
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

fn is_digit(c: Char) -> Bool {
  c >= '0' && c <= '9'
}

fn is_alpha(c: Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

fn is_alphanumeric(c: Char) -> Bool {
  is_alpha(c) || is_digit(c)
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

let zero_ascii: Int = '0'.to_int()

fn parse_digit(c: Char) -> Int {
  c.to_int() - zero_ascii
}

fn parse_uint(s: String) -> Int {
  // assumes the string only contains (base-10) digits
  let mut n: Int = 0
  let p: Int = 10

  for c in s {
    n = n * p + parse_digit(c)
  }

  n
}

fn parse_integer(self: Lexer) -> (Int, Int?) {
  let builder = StringBuilder::new()
  let mut width = None

  for i in self.index..<self.input.length() {
    let char = self.input[i]

    if is_digit(char) {
      builder.write_char(char)
      self.advance()
    } else if char == '\'' {
      width = Some(parse_uint(builder.to_string()))
      builder.reset()
      self.advance()
    } else {
      break
    }
  }

  (parse_uint(builder.to_string()), width)
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

fn next(self: Lexer) -> LexerResult[Token] {
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
        
        return self.next()
      } else {
        Ok(Slash)
      }
    }
    '<' => {
      self.advance()
      Ok(Lchevron)
    }
    '>' => {
      self.advance()
      Ok(Rchevron)
    }
    '!' => {
      self.advance()
      if self.consumes('=') {
        Ok(BangEqual)
      } else {
        Ok(Bang)
      }
    }
    '=' => {
      self.advance()
      if self.consumes('=') {
        Ok(EqualEqual)
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
        } else {
          Err(UnexepectedChar(char))
        }
      } else {
        Ok(Dot)
      }
    }
    '\'' => {
      self.advance()
      Ok(SingleQuote)
    }
    _ => {
      if is_digit(char) {
        let (value, width) = self.parse_integer()
        Ok(Natural(value~, width~))
      } else if is_alpha(char) || char == '_' {
        let identifier = self.parse_identifier()

        Ok(match identifier {
          "module" => Module
          "let" => Let
          "logic" => Logic
          "in" => In
          "for" => For
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

pub fn lex(self: Lexer) -> Array[Token]!LexerError {
  let tokens = []

  while true {
    match self.next() {
      Ok(token) => tokens.push(token)
      Err(error) => raise error
      EOF => break
    }
  }

  tokens
}

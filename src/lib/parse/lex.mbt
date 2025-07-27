
pub struct Lexer {
  input: String
  mut index: Int
  mut line: Int
  mut column: Int
  file: String
  file_content: String
  tokens: Array[Token]
}

pub suberror LexerError {
  UnexepectedChar(char~: Char, span~: Span)
}

pub impl Show for LexerError with output(self, logger) -> Unit {
  match self {
    UnexepectedChar(char~, ..) => {
      logger.write_string("Unexpected character '\{char}'")
    }
  }

  logger.write_string(self.show_context(use_ansi_colors=false))
}

pub impl Spanned for LexerError with span(self: LexerError) -> Span {
  match self {
    UnexepectedChar(span~, ..) => span
  }
}

pub fn Lexer::new(input: String, file~: String, file_content~: String) -> Lexer {
  { input, index: 0, line: 1, column: 1, tokens: Array::new(capacity=file_content.length() / 4), file, file_content }
}

fn peek(self: Lexer) -> Char {
  @utils.char_at(self.input, self.index)
}

fn lookahead(self: Lexer, n: Int) -> Char {
  @utils.char_at(self.input, self.index + n)
}

fn next_non_whitespace(self: Lexer) -> Char? {
  let mut i = self.index

  while i < self.input.length() {
    let char = @utils.char_at(self.input, i)

    if not(@utils.is_whitespace(char)) {
      return Some(char)
    }

    i += 1
  }

  None
}

fn should_insert_semicolon(last_token: Token) -> Bool {
  match last_token.kind {
    Natural(_) | StringLiteral(_) | CharacterLiteral(_) => true
    Identifier(_) => true
    Rparen | Rbracket | Rbrace | Rchevron => true
    _ => false
  }
}

fn matches(self: Lexer, char: Char) -> Bool {
  self.peek() == char
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
    let char = @utils.char_at(self.input, i)

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
        if @utils.char_at(s, s.length() - i - 1) == '1' {
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

priv struct ParsedInteger {
  value: BigInt
  width: Int?
  base: Int
}

fn span(self: Lexer, start: (Int, Int)) -> Span {
  { start, end: (self.line, self.column), file: self.file, file_content: self.file_content }
} 

fn parse_integer(self: Lexer) -> ParsedInteger {
  let builder = StringBuilder::new()
  let mut base = 10
  let mut width = None

  while self.index < self.input.length() {
    let char = self.peek()

    if @utils.is_digit(char, base~) {
      builder.write_char(char)
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

  let num_str = builder.to_string()
  let value = parse_uint(num_str, base~)

  { value, width, base }
}

fn advance(self: Lexer) -> Unit {
  if self.peek() == '\n' {
    self.line += 1
    self.column = 1

    if self.tokens.last() is Some(t) && should_insert_semicolon(t) {
      self.tokens.push({
        kind: Semicolon,
        span: t.span,
      })
    }
  } else {
    self.column += 1
  }

  self.index += 1
}

fn next(self: Lexer) -> Bool raise LexerError {
  self.skip_whitespaces()

  if self.index >= self.input.length() {
    return false
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
        
        return self.next()
      } else {
        Ok(Slash)
      }
    }
    '<' => {
      self.advance()

      if self.consumes('=') {
        Ok(LchevronEqual)
      } else if self.consumes(':') {
        Ok(LchevronColon)
      } else {
        Ok(Lchevron)
      }
    }
    '>' => {
      self.advance()

      if self.consumes('=') {
        Ok(RchevronEqual)
      } else if self.consumes(':') {
        Ok(RchevronColon)
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
        } else {
          Ok(DotDot)
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

      if self.peek() == '\\' {
        self.advance()
        let escaped = match self.peek() {
          'n' => '\n'
          'r' => '\r'
          't' => '\t'
          '\\' => '\\'
          '\'' => '\''
          c => c
        }
        
        self.advance()
        Ok(CharacterLiteral(escaped))
      } else if self.lookahead(1) == '\'' {
        let char = self.peek()
        self.advance()
        self.advance()
        Ok(CharacterLiteral(char))
      } else {
        Ok(SingleQuote)
      }
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
        let { value, width, base } = self.parse_integer()
        Ok(Natural(value~, width~, base~))
      } else if @utils.is_alpha(char) || char == '_' {
        let identifier = self.parse_identifier()

        Ok(match identifier {
          "module" => Module
          "let" => Let
          "bool" => Bool
          "uint" => UInt
          "sint" => SInt
          "in" => In
          "for" => For
          "declare" => Declare
          "if" => If
          "else" => Else
          "match" => Match
          "const" => Const
          "package" => Package
          "import" => Import
          "and" => And
          "or" => Or
          "not" => Not
          "xor" => Xor
          "nand" => Nand
          "nor" => Nor
          "xnor" => Xnor
          "shl" => Shl
          "shr" => Shr
          "type" => Type
          "clock" => Clock
          "andr" => Andr
          "orr" => Orr
          "xorr" => Xorr
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
    Ok(token) => {
      let token = {
        kind: token,
        span: { file: self.file, file_content: self.file_content, start, end },
      }

      self.tokens.push(token)
      true
    }
    Err(error) => raise error
  }
}

pub fn lex(self: Lexer) -> Array[Token] raise {
  while self.next() {}
  self.tokens
}

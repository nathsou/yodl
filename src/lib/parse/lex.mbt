
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
  UnterminatedStringLiteral(span~: Span)
  UnterminatedCharacterLiteral(span~: Span)
}

pub impl Show for LexerError with output(self, logger) -> Unit {
  match self {
    UnexepectedChar(char~, ..) => {
      logger.write_string("Unexpected character '\{char}'")
    }
    UnterminatedStringLiteral(..) => logger.write_string("Unterminated string literal")
    UnterminatedCharacterLiteral(..) => logger.write_string("Unterminated character literal")
  }

  logger.write_string(Spanned::show_context(self, use_ansi_colors=false))
}

pub impl Spanned for LexerError with span(self: LexerError) -> Span {
  match self {
    UnexepectedChar(span~, ..) => span
    UnterminatedStringLiteral(span~) | UnterminatedCharacterLiteral(span~) => span
  }
}

pub fn Lexer::new(input: String, file~: String, file_content~: String) -> Lexer {
  { input, index: 0, line: 1, column: 1, tokens: Array::new(capacity=file_content.length() / 4), file, file_content }
}

fn Lexer::peek(self: Lexer) -> Char {
  @utils.char_at(self.input, self.index)
}

fn Lexer::lookahead(self: Lexer, n: Int) -> Char {
  @utils.char_at(self.input, self.index + n)
}

fn should_insert_semicolon(last_token: Token) -> Bool {
  match last_token.kind {
    Natural(_) | StringLiteral(_) | CharacterLiteral(_) => true
    Identifier(_) => true
    Bool | UInt | SInt | Clock => true
    UIntType(_) | SIntType(_) => true
    Rparen | Rbracket | Rbrace | Rchevron => true
    _ => false
  }
}

// Recognise sized integer type identifiers `u<digits>` and `s<digits>`
// such as `u8`, `s7`, `u32`. Returns None for plain identifiers like
// `u`, `s`, `u8_buffer`, `u_8`, `uart`.
fn sized_int_type(identifier: String) -> TokenType? {
  if identifier.length() < 2 {
    return None
  }

  let first = @utils.char_at(identifier, 0)

  if first != 'u' && first != 's' {
    return None
  }

  let mut value = 0

  for i in 1..<identifier.length() {
    let c = @utils.char_at(identifier, i)

    if @utils.is_digit(c, base=10) {
      value = value * 10 + (c.to_int() - '0'.to_int())
    } else {
      return None
    }
  }

  if first == 'u' {
    Some(UIntType(value))
  } else {
    Some(SIntType(value))
  }
}

fn Lexer::matches(self: Lexer, char: Char) -> Bool {
  self.index < self.input.length() && self.peek() == char
}

fn Lexer::consumes(self: Lexer, char: Char) -> Bool {
  if self.matches(char) {
    self.index += 1
    true
  } else {
    false
  }
}

fn Lexer::skip_whitespaces(self: Lexer) -> Unit {
  while self.index < self.input.length() && @utils.is_whitespace(self.peek()) {
    self.advance()
  }
}

fn Lexer::parse_identifier(self: Lexer) -> String {
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
    16 => BigInt::from_string(s, radix=16)
    _ => BigInt::from_string(s)
  }
}

priv struct ParsedInteger {
  value: BigInt
  width: Int?
  base: Int
}

fn Lexer::span(self: Lexer, start: SourceLoc) -> Span {
  { start, end: SourceLoc::{ index: self.index, line: self.line, column: self.column }, file: self.file, file_content: self.file_content[:] }
} 

fn Lexer::parse_integer(self: Lexer) -> ParsedInteger {
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

fn Lexer::advance(self: Lexer) -> Unit {
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

fn Lexer::next(self: Lexer) -> Bool raise LexerError {
  while true {
    self.skip_whitespaces()

    if self.index >= self.input.length() {
      return false
    }

    if self.peek() == '/' && self.index + 1 < self.input.length() && self.lookahead(1) == '/' {
      self.advance()
      self.advance()
      while self.index < self.input.length() && self.peek() != '\n' {
        self.advance()
      }
    } else {
      break
    }
  }

  if self.index >= self.input.length() {
    return false
  }

  let char = self.peek()

  let start = SourceLoc::{ index: self.index, line: self.line, column: self.column }

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
      if self.consumes(':') {
        Ok(PlusColon)
      } else {
        Ok(Plus)
      }
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
      Ok(Star)
    }
    '/' => {
      self.advance()
      Ok(Slash)
    }
    '<' => {
      self.advance()

      if self.consumes('=') {
        Ok(LchevronEqual)
      } else {
        Ok(Lchevron)
      }
    }
    '>' => {
      self.advance()

      if self.consumes('=') {
        Ok(RchevronEqual)
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
        if self.consumes('=') {
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
    '_' => {
      self.advance()
      Ok(Underscore)
    }
    '\'' => {
      self.advance()

      if self.index >= self.input.length() {
        raise UnterminatedCharacterLiteral(span=self.span(start))
      }

      if self.peek() == '\\' {
        self.advance()
        if self.index >= self.input.length() {
          raise UnterminatedCharacterLiteral(span=self.span(start))
        }

        let escaped = match self.peek() {
          'n' => '\n'
          'r' => '\r'
          't' => '\t'
          '\\' => '\\'
          '\'' => '\''
          c => c
        }
        
        self.advance()
        if self.index >= self.input.length() || self.peek() != '\'' {
          raise UnterminatedCharacterLiteral(span=self.span(start))
        }

        self.advance()
        Ok(CharacterLiteral(escaped))
      } else if self.index + 1 < self.input.length() && self.lookahead(1) == '\'' {
        let char = self.peek()
        self.advance()
        self.advance()
        Ok(CharacterLiteral(char))
      } else {
        raise UnterminatedCharacterLiteral(span=self.span(start))
      }
    }
    '"' => {
      let builder = StringBuilder::new()
      self.advance()

      while self.index < self.input.length() && self.peek() != '"' {
        let char = self.peek()

        match char {
          '\\' => {
            self.advance()
            if self.index >= self.input.length() {
              raise UnterminatedStringLiteral(span=self.span(start))
            }

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

      if self.index >= self.input.length() {
        raise UnterminatedStringLiteral(span=self.span(start))
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

        if self.consumes('!') {
          Ok(BuiltinFunction(identifier))
        } else {
          // Sized integer types: u<digits> or s<digits> (e.g. u8, s7)
          match sized_int_type(identifier) {
            Some(token) => Ok(token)
            None => Ok(match identifier {
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
              "mod" => Percent
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
          }
        }
      } else {
        self.advance()
        Err(UnexepectedChar(char~, span=self.span(start)))
      }
    }
  }

  let end = SourceLoc::{ index: self.index, line: self.line, column: self.column }

  match val {
    Ok(token) => {
      let token = {
        kind: token,
        span: { file: self.file, file_content: self.file_content[:], start, end },
      }

      self.tokens.push(token)
      true
    }
    Err(error) => raise error
  }
}

pub fn Lexer::lex(self: Lexer) -> Array[Token] raise {
  while self.next() {}
  self.tokens
}

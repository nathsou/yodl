
enum TokenType {
  // symbols
  Lparen; Rparen; Lbrace; Rbrace; Comma; Semicolon; Colon
  Lchevron; Rchevron; Lbracket; Rbracket; Dot; Bang; SingleQuote
  LchevronColon; RchevronColon
  Plus; Minus; Star; Slash
  Equal; EqualEqual; BangEqual; RightThinArrow; RightThickArrow
  LchevronEqual; RchevronEqual
  DotDotLeftChevron; DotDotEqual; DotDot
  Percent; QuestionMark; At; Underscore; X // Replication operator
  Dollar; ColonColon; MinusColon
  // keywords
  Module; Let; UInt; SInt; Bool; In; For; Declare; Const
  And; Or; Not; Xor; Nand; Nor; Xnor; Shl; Shr
  Match; Package; Import; If; Else; Type; Clock
  Andr; Orr; Xorr
  // literals
  Identifier(String); Natural(value~: BigInt, width~: Int?, base~: Int)
  StringLiteral(String); CharacterLiteral(Char)
} derive(Eq, Show)

pub(all) struct Span {
  file: String
  file_content: String
  start: (Int, Int)
  end: (Int, Int)
}

pub impl Eq for Span with equal(self, other) {
  self.file == other.file && self.start == other.start && self.end == other.end
}

pub impl Show for Span with output(self, logger) {
  logger.write_string(self.file)
  logger.write_char(':')
  logger.write_string("\{self.start.0}.\{self.start.1}-\{self.end.0}.\{self.end.1}")
}

pub fn context(self: Span, window_size~: Int = 3, use_ansi_colors~: Bool = false) -> String {
  let window = StringBuilder::new(size_hint=window_size * 2)
  let max_line_number_digits = (self.end.0 + 1).to_string().length()

  self.file_content.split("\n").eachi(fn(index, line) {
    if index >= self.start.0 - window_size && index <= self.end.0 + window_size {
      let line_nb = "\{index + 1}".pad_end(max_line_number_digits, ' ')
      let is_inside_span = index >= (self.start.0 - 1) && index < self.end.0

      window.write_string(line_nb)
      window.write_char(' ')
      window.write_string(line.to_string())

      if is_inside_span {
        let line_start = if index == self.start.0 - 1 { self.start.1 } else { 0 }
        let line_end = if index == self.end.0 - 1 { self.end.1 } else { line.length() }
        let is_blank = line.iter().all(@utils.is_whitespace)

        if not(is_blank) {
          window.write_char('\n')

          for _ in 0..<line_nb.length() {
            window.write_char(' ')
          }

          let first_non_whitespace_col = {
            let mut col = 0

            for idx, char in line {
              if not(@utils.is_whitespace(char)) {
                col = idx
                break
              }
            }

            @utils.max(col + 1, line_start)
          }

          for _ in 0..<first_non_whitespace_col {
            window.write_char(' ')
          }

          let last_non_whitespace_col = {
            let mut col = 0
            for idx, char in line {
              if not(@utils.is_whitespace(char)) {
                col = idx
              }
            }

            @utils.min(col + 1, line_end)
          }

          if use_ansi_colors {
            window.write_string("\u001b[31m")
          }

          for _ in 0..=(last_non_whitespace_col - first_non_whitespace_col) {
            window.write_char('^')
          }

          if use_ansi_colors {
            window.write_string("\u001b[0m")
          }
        }
      }

      window.write_char('\n')
    }
  })

  window.to_string()
}

struct Token {
  kind: TokenType
  span: Span
} derive(Show)

fn to_binop(self: TokenType) -> BinaryOp? {
  match self {
    Plus => Some(Add)
    Minus => Some(Sub)
    Star => Some(Mul)
    Slash => Some(Div)
    Percent => Some(Mod)
    EqualEqual => Some(Equ)
    BangEqual => Some(Neq)
    LchevronColon => Some(Lss)
    RchevronColon => Some(Gtr)
    LchevronEqual => Some(Leq)
    RchevronEqual => Some(Geq)
    Shl => Some(Shl)
    Shr => Some(Shr)
    QuestionMark => Some(Ternary)
    And => Some(And)
    Or => Some(Or)
    Xor => Some(Xor)
    Nand => Some(Nand)
    Nor => Some(Nor)
    Xnor => Some(Xnor)
    _ => None
  }
}

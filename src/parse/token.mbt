
enum TokenType {
  // symbols
  Lparen; Rparen; Lbrace; Rbrace; Comma; Semicolon; Colon
  Lchevron; Rchevron; Lbracket; Rbracket; Dot; Bang; SingleQuote
  Plus; Minus; Star; Slash
  Equal; EqualEqual; BangEqual; RightThinArrow; RightThickArrow
  LchevronEqual; RchevronEqual; LchevronLchevron; RchevronRchevron
  DotDotLeftChevron; DotDotEqual; DotDotDot
  Percent; QuestionMark; At; Underscore; X // Replication operator
  Dollar; ColonColon; MinusColon
  // keywords
  Module; Let; Logic; In; For; Declare; Const
  And; Or; Not; Xor; Nand; Nor; Xnor
  Match; Package; Import; Procedural
  // literals
  Identifier(String); Natural(bits~: Bits, width~: Int?, base~: Int)
  StringLiteral(String)
} derive(Eq, Show)

pub(all) struct Span {
  file: String
  start: (Int, Int)
  end: (Int, Int)
}

pub impl Show for Span with output(self, logger) {
  logger.write_string(self.file)
  logger.write_char(':')
  logger.write_string("\{self.start.0}.\{self.start.1}-\{self.end.0}.\{self.end.1}")
}

pub fn context(self: Span, window_size~: Int = 3) -> String! {
  let contents = @fs.read_file_to_string!(path=self.file)
  let window = StringBuilder::new(size_hint=window_size * 2)
  let max_line_number_digits = (self.end.0 + 1).to_string().length()

  contents.split("\n").eachi(fn(index, line) {
    if index >= self.start.0 - window_size && index <= self.end.0 + window_size {
      let line_nb = "\{index + 1}".pad_end(max_line_number_digits, ' ')
      let is_inside_span = index >= (self.start.0 - 1) && index < self.end.0

      window.write_string(line_nb)
      window.write_char(' ')
      window.write_string(line)

      if is_inside_span {
        let line_start = if index == self.start.0 - 1 { self.start.1 } else { 0 }
        let line_end = if index == self.end.0 - 1 { self.end.1 } else { line.length() }
        let is_blank = line.iter().all(@utils.is_whitespace)

        if not(is_blank) {
          window.write_char('\n')

          for _ in 0..<(line_nb.length() + 1) {
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

            @utils.max(col, line_start)
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

            @utils.min(col, line_end)
          }

          window.write_string("\x1b[1;31m")

          for _ in 0..=(last_non_whitespace_col - first_non_whitespace_col) {
            window.write_char('^')
          }

          window.write_string("\x1b[0m")
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
    Lchevron => Some(Lss)
    Rchevron => Some(Gtr)
    LchevronEqual => Some(Leq)
    RchevronEqual => Some(Geq)
    LchevronLchevron => Some(Shl)
    RchevronRchevron => Some(Shr)
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

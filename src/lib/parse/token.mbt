
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
  ColonColon; MinusColon
  // keywords
  Module; Let; UInt; SInt; Bool; In; For; Declare; Const
  And; Or; Not; Xor; Nand; Nor; Xnor; Shl; Shr
  Match; Package; Import; If; Else; Type; Clock
  Andr; Orr; Xorr
  // literals
  Identifier(String)
  BuiltinFunction(String)
  Natural(value~: BigInt, width~: Int?, base~: Int)
  StringLiteral(String); CharacterLiteral(Char)
} derive(Eq, Debug)

pub impl Show for TokenType with output(self, logger) {
  match self {
    Lparen => logger.write_string("(")
    Rparen => logger.write_string(")")
    Lbrace => logger.write_string("{")
    Rbrace => logger.write_string("}")
    Comma => logger.write_string(",")
    Semicolon => logger.write_string(";")
    Colon => logger.write_string(":")
    At => logger.write_string("@")
    Lchevron => logger.write_string("<")
    Rchevron => logger.write_string(">")
    Lbracket => logger.write_string("[")
    Rbracket => logger.write_string("]")
    Plus => logger.write_string("+")
    Minus => logger.write_string("-")
    Star => logger.write_string("*")
    Slash => logger.write_string("/")
    Equal => logger.write_string("=")
    EqualEqual => logger.write_string("==")
    BangEqual => logger.write_string("!=")
    RightThinArrow => logger.write_string("->")
    RightThickArrow => logger.write_string("=>")
    Dot => logger.write_string(".")
    Bang => logger.write_string("!")
    SingleQuote => logger.write_string("'")
    Underscore => logger.write_string("_")
    QuestionMark => logger.write_string("?")
    Percent => logger.write_string("%")
    X => logger.write_string("x")
    DotDot => logger.write_string("..")
    DotDotLeftChevron => logger.write_string("..<")
    DotDotEqual => logger.write_string("..=")
    ColonColon => logger.write_string("::")
    MinusColon => logger.write_string("-:")
    LchevronColon => logger.write_string("<:")
    RchevronColon => logger.write_string(">:")
    LchevronEqual => logger.write_string("<=")
    RchevronEqual => logger.write_string(">=")
    Module => logger.write_string("module")
    Let => logger.write_string("let")
    UInt => logger.write_string("uint")
    SInt => logger.write_string("sint")
    Bool => logger.write_string("bool")
    In => logger.write_string("in")
    For => logger.write_string("for")
    Declare => logger.write_string("declare")
    Const => logger.write_string("const")
    And => logger.write_string("and")
    Or => logger.write_string("or")
    Not => logger.write_string("not")
    Xor => logger.write_string("xor")
    Nand => logger.write_string("nand")
    Nor => logger.write_string("nor")
    Xnor => logger.write_string("xnor")
    Shl => logger.write_string("shl")
    Shr => logger.write_string("shr")
    Match => logger.write_string("match")
    Package => logger.write_string("package")
    Import => logger.write_string("import")
    If => logger.write_string("if")
    Else => logger.write_string("else")
    Type => logger.write_string("type")
    Clock => logger.write_string("clock")
    Andr => logger.write_string("andr")
    Orr => logger.write_string("orr")
    Xorr => logger.write_string("xorr")
    Identifier(name) => logger.write_string(name)
    BuiltinFunction(name) => logger.write_string("\{name}!")
    Natural(value~, width~, base~) => match width {
      Some(w) => {
        let base_char = match base { 2 => "b"; 16 => "h"; _ => "d" }
        logger.write_string("\{w}'\{base_char}\{value}")
      }
      None => logger.write_string("\{value}")
    }
    StringLiteral(s) => logger.write_string(s)
    CharacterLiteral(c) => logger.write_char(c)
  }
}

pub(all) struct Span {
  file: String
  file_content: String
  start: (Int, Int)
  end: (Int, Int)
} derive(Debug)

pub impl Eq for Span with equal(self, other) {
  self.file == other.file && self.start == other.start && self.end == other.end
}

pub impl Show for Span with output(self, logger) {
  logger.write_string(self.file)
  logger.write_char(':')
  logger.write_string("\{self.start.0}.\{self.start.1}-\{self.end.0}.\{self.end.1}")
}

pub fn Span::context(self: Span, window_size~: Int = 3, use_ansi_colors~: Bool = false) -> String {
  let window = StringBuilder::new(size_hint=window_size * 2)
  let max_line_number_digits = (self.end.0 + 1).to_string().length()

  self.file_content.split("\n").eachi(fn(index, line) {
    if index >= self.start.0 - window_size && index <= self.end.0 + window_size {
      let line_nb = "\{index + 1}".pad_end(max_line_number_digits, ' ')
      let is_inside_span = index >= (self.start.0 - 1) && index < self.end.0

      window.write_string(line_nb)
      window.write_char(' ')
      window.write_string(line.to_owned())

      if is_inside_span {
        let line_start = if index == self.start.0 - 1 { self.start.1 } else { 0 }
        let line_end = if index == self.end.0 - 1 { self.end.1 } else { line.length() }
        let is_blank = line.iter().all(@utils.is_whitespace)

        if !is_blank {
          window.write_char('\n')

          for _ in 0..<line_nb.length() {
            window.write_char(' ')
          }

          let first_non_whitespace_col = {
            let mut col = 0

            for idx, char in line {
              if !@utils.is_whitespace(char) {
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
              if !@utils.is_whitespace(char) {
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
} derive(Debug)

fn TokenType::to_binop(self: Self) -> BinaryOp? {
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

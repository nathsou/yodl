
enum TokenType {
  // symbols
  Lparen; Rparen; Lbrace; Rbrace; Comma; Semicolon; Colon
  Lchevron; Rchevron; Lbracket; Rbracket; Dot; Bang; SingleQuote
  Plus; Minus; Star; Slash
  Equal; EqualEqual; BangEqual; RightThinArrow
  DotDotLeftChevron; DotDotEqual; DotDotDot
  // keywords
  Module; Let; Logic; In; For; Declare
  And; Or; Not; Xor; Nand; Nor; Xnor
  // literals
  Identifier(String); Natural(value~: Int, width~: Int?)
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

struct Token {
  kind: TokenType
  span: Span
} derive(Show)

fn to_binop(self: TokenType) -> BinaryOp? {
  match self {
    Plus => Some(Add)
    Minus => Some(Sub)
    Star => Some(Mul)
    And => Some(And)
    Or => Some(Or)
    Xor => Some(Xor)
    Nand => Some(Nand)
    Nor => Some(Nor)
    Xnor => Some(Xnor)
    _ => None
  }
}

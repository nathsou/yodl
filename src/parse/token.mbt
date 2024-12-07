
enum TokenType {
  // symbols
  Lparen; Rparen; Lbrace; Rbrace; Comma; Semicolon; Colon
  Lchevron; Rchevron; Lbracket; Rbracket; Dot; Bang
  Plus; Minus; Star; Slash
  Equal; EqualEqual; BangEqual; RightThinArrow
  // keywords
  Module; Let; Logic; In; For
  And; Or; Not; Xor; Nand; Nor; Xnor
  // literals
  Identifier(String); Natural(UInt)
} derive(Eq, Show)

struct Span {
  start: (Int, Int)
  end: (Int, Int)
} derive(Show)

struct Token {
  kind: TokenType
  span: Span
} derive(Show)

fn to_binop(self: TokenType) -> BinaryOp? {
  match self {
    And => Some(And)
    Or => Some(Or)
    Xor => Some(Xor)
    Nand => Some(Nand)
    Nor => Some(Nor)
    Xnor => Some(Xnor)
    _ => None
  }
}
pub(readonly) struct Parser {
  tokens: Array[Token]
  mut index: Int
  file: String
}

pub(readonly) type! ParserError {
  UnexpectedToken(expected~: TokenType, received~: TokenType, span~: Span)
  ExpectedIdentifier(received~: TokenType, span~: Span)
  ExpectedInteger(received~: TokenType, span~: Span)
  ExpectedExpr(received~: TokenType, span~: Span)
  ExpectedStmt(received~: TokenType, span~: Span)
} derive(Show)

pub fn Parser::new(tokens: Array[Token], file~: String) -> Parser {
  { tokens, index: 0, file }
}

fn peek(self: Parser) -> TokenType {
  self.tokens[self.index].kind
}

fn lookahead(self: Parser, n: Int) -> Token {
  self.tokens[self.index + n]
}

fn advance(self: Parser) -> Unit {
  self.index += 1
}

fn expect(self: Parser, expected: TokenType, span_start_idx: Int) -> Unit!ParserError {
  let token = self.peek()

  if token == expected {
    self.advance()
  } else {
    raise UnexpectedToken(expected~, received=token, span=self.span(span_start_idx))
  }
}

fn matches(self: Parser, token: TokenType) -> Bool {
  self.peek() == token
}

fn matches_predicate(self: Parser, predicate: (TokenType) -> Bool) -> Bool {
  predicate(self.peek())
}

fn consumes(self: Parser, token: TokenType) -> Bool {
  if self.matches(token) {
    self.advance()
    true
  } else {
    false
  }
}

fn consumeIfPresent(self: Parser, token: TokenType) -> Unit {
    let _ = self.consumes(token)
}

fn parse_identifier(self: Parser) -> String!ParserError {
  let token = self.peek()
  let start_idx = self.index

  match token {
    Identifier(name) => {
      self.advance()
      name
    }
    _ => raise ExpectedIdentifier(received=token, span=self.span(start_idx))
  }
}

fn parse_integer(self: Parser) -> (UInt, UInt?)!ParserError {
  let token = self.peek()
  let start_idx = self.index

  match token {
    Natural(value~, width~) => {
      self.advance()
      (value, width)
    }
    _ => raise ExpectedInteger(received=token, span=self.span(start_idx))
  }
}

fn span(self: Parser, start_idx: Int) -> Span {
  let start = self.tokens[start_idx].span.start
  let end = self.tokens[self.index - 1].span.end
  { file: self.file, start, end }
}

fn precedence_climbing(self: Parser, min_precedence: Int) -> Expr!ParserError {
  let mut lhs = self.parse_primary_expr!()

  while self.index < self.tokens.length() {
    match self.peek().to_binop() {
      Some(op) => {
        let precedence = op.precedence()

        if precedence >= min_precedence {
          let start_idx = self.index
          self.advance() // consume the operator

          // left-associative
          let rhs = self.precedence_climbing!(precedence + 1)
          lhs = Binary(op~, lhs~, rhs~, span=self.span(start_idx), ty={ val: None })
        } else {
          break
        }
      }
      None => break
    }
  }

  lhs
}

fn parse_primary_expr(self: Parser) -> Expr!ParserError {
  let token = self.peek()
  let start_idx = self.index

  match token {
    Identifier(name) => {
      self.advance()
      Identifier(name~, span=self.span(start_idx), ty={ val: None })
    }
    Natural(value~, width~) => {
      self.advance()
      Natural(value~, width~, span=self.span(start_idx), ty={ val: None })
    }
    Not => {
      self.advance()
      let expr = self.parse_expr!()
      Unary(op=Not, expr~, span=self.span(start_idx), ty={ val: None })
    }
    Lparen => {
      self.advance()
      let expr = self.parse_expr!()
      self.expect!(Rparen, start_idx)
      expr
    }
    _ => raise ExpectedExpr(received=token, span=self.span(start_idx))
  }
}

fn parse_expr(self: Parser) -> Expr!ParserError {
  self.precedence_climbing!(0)
}

fn parse_stmt(self: Parser) -> Stmt!ParserError {
  let token = self.peek()
  let start_idx = self.index

  match token {
    Let => {
      self.advance()
      let name = self.parse_identifier!()
      self.expect!(Equal, start_idx)
      let expr = self.parse_expr!()
      self.expect!(Semicolon, start_idx)
      Let(name~, expr~, span=self.span(start_idx))
    }
    Identifier(name) => {
      self.advance()
      self.expect!(Equal, start_idx)
      let expr = self.parse_expr!()
      self.expect!(Semicolon, start_idx)
      Assign(name~, expr~, span=self.span(start_idx))
    }
    _ => raise ExpectedStmt(received=token, span=self.span(start_idx))
  }
}

fn parse_type(self: Parser) -> Type!ParserError {
  let start_idx = self.index

  if self.consumes(Logic) {
    Logic
  } else {
    let ty = self.parse_type!()
    self.expect!(Lbracket, start_idx)
    let (len, _) = self.parse_integer!()
    self.expect!(Rbracket, start_idx)
    Vector(ty~, len~)
  }
}

fn parse_port(self: Parser, dir~: PortDirection) -> Port!ParserError {
  let start_idx = self.index
  let name = self.parse_identifier!()
  self.expect!(Colon, start_idx)
  let ty = self.parse_type!()
  { name, ty, dir, span: self.span(start_idx) }
}

fn parse_port_list(self: Parser, dir~: PortDirection) -> Array[Port]!ParserError {
  let start_idx = self.index
  let ports = []

  self.expect!(Lparen, start_idx)

  while not(self.consumes(Rparen)) {
    let port = self.parse_port!(dir~)
    ports.push(port)

    if not(self.consumes(Comma)) {
      break
    }
  }

  ports
}

fn parse_module_decl(self: Parser) -> ModuleDecl!ParserError {
  let start_idx = self.index
  self.expect!(Module, start_idx)
  let name = self.parse_identifier!()
  let inputs = self.parse_port_list!(dir=Input)
  self.expect!(RightThinArrow, start_idx)
  let outputs = self.parse_port_list!(dir=Output)
  self.expect!(Lbrace, start_idx)
  let body = []

  while not(self.consumes(Rbrace)) {
    let stmt = self.parse_stmt!()
    body.push(stmt)
  }

  { name, inputs, outputs, body, span: self.span(start_idx) }
}


fn parse_decl(self: Parser) -> Decl!ParserError {
  Module(self.parse_module_decl!())
}

pub fn parse(self: Parser) -> Array[Decl]!ParserError {
  let decls = []

  while self.index < self.tokens.length() {
    let decl = self.parse_decl!()
    decls.push(decl)
  }

  decls
}

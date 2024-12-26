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
  ExpectedType(received~: TokenType, span~: Span)
  ExpectedRangeOperator(received~: TokenType, span~: Span)
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

fn parse_integer(self: Parser) -> (Int, Int?)!ParserError {
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
  let mut lhs = self.parse_indexing_expr!()

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

fn parse_indexing_expr(self: Parser) -> Expr!ParserError {
  let start_idx = self.index
  let mut lhs = self.parse_primary_expr!()

  while true {
    if self.consumes(Lbracket) {
      let index = self.parse_expr!()

      if self.consumes(Colon) {
        let lsb = self.parse_expr!()
        self.expect!(Rbracket, start_idx)
        lhs = Slicing(expr=lhs, msb=index, lsb~, span=self.span(start_idx), ty={ val: None })
      } else {
        self.expect!(Rbracket, start_idx)
        lhs = Indexing(expr=lhs, index~, span=self.span(start_idx), ty={ val: None })
      }
    } else if self.consumes(Dot) {
      let port = self.parse_identifier!()
      lhs = PortAccess(expr=lhs, port~, span=self.span(start_idx), ty={ val: None })
    } else {
      break
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
      if self.matches(Lparen) {
        self.parse_instance_expr!(module_name=name)
      } else {
        Identifier(name~, span=self.span(start_idx), ty={ val: None })
      }
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
    Lbracket => self.parse_vector_expr!()
    DotDotDot => self.parse_spread_expr!()
    _ => raise ExpectedExpr(received=token, span=self.span(start_idx))
  }
}

fn parse_spread_expr(self: Parser) -> Expr!ParserError {
  let start_idx = self.index
  self.expect!(DotDotDot, start_idx)
  let expr = self.parse_expr!()
  Spread(expr~, span=self.span(start_idx), ty={ val: None })
}

fn parse_vector_expr(self: Parser) -> Expr!ParserError {
  let start_idx = self.index
  self.expect!(Lbracket, start_idx)
  let elems = []

  while not(self.matches(Rbracket)) {
    let elem = self.parse_expr!()
    elems.push(elem)

    if not(self.consumes(Comma)) {
      break
    }
  }

  self.expect!(Rbracket, start_idx)

  Vector(elems~, span=self.span(start_idx), ty={ val: None })
}

fn parse_instance_expr(self: Parser, module_name~: String) -> Expr!ParserError {
  let start_idx = self.index
  self.expect!(Lparen, start_idx)
  let ports = {}

  while not(self.matches(Rparen)) {
    let start_idx = self.index
    let name = self.parse_identifier!()
    self.expect!(Colon, start_idx)
    let expr = self.parse_expr!()
    ports[name] = expr

    if not(self.consumes(Comma)) {
      break
    }
  }

  self.expect!(Rparen, start_idx)

  Instance(name=module_name, ports~, span=self.span(start_idx), ty={ val: None })
}

fn parse_expr(self: Parser) -> Expr!ParserError {
  self.precedence_climbing!(0)
}

fn parse_assignment_stmt(self: Parser) -> Stmt!ParserError {
  let start_idx = self.index
  let lhs = self.parse_indexing_expr!()

  if self.consumes(Equal) {
    let rhs = self.parse_expr!()
    self.expect!(Semicolon, self.index)
    Assign(lhs~, rhs~, span=self.span(start_idx))
  } else if self.consumes(Semicolon) {
    Expr(expr=lhs, span=self.span(start_idx))
  } else {
    raise ExpectedStmt(received=self.peek(), span=self.span(start_idx))
  }
}

fn parse_block(self: Parser) -> Array[Stmt]!ParserError {
  self.expect!(Lbrace, self.index)
  let stmts = []

  while self.peek() != Rbrace {
    stmts.push(self.parse_stmt!())
  }

  self.expect!(Rbrace, self.index)

  stmts
}

fn parse_stmt(self: Parser) -> Stmt!ParserError {
  let token = self.peek()
  let start_idx = self.index

  match token {
    Let => {
      self.advance()
      let name = self.parse_identifier!()

      let ty = if self.consumes(Colon) {
        Some(self.parse_type!())
      } else {
        None
      }

      let expr = if self.consumes(Equal) {
        Some(self.parse_expr!())
      } else {
        None
      }
      
      self.expect!(Semicolon, start_idx)

      Let(name~, ty={ val: ty }, expr~, span=self.span(start_idx))
    }
    For => {
      self.advance()
      let var = self.parse_identifier!()
      self.expect!(In, start_idx)

      let start = self.parse_expr!()

      let inclusive = if self.consumes(DotDotLeftChevron) {
        false
      } else if self.consumes(DotDotEqual) {
        true
      } else {
        raise ExpectedRangeOperator(received=self.peek(), span=self.span(start_idx))
      }

      let end = self.parse_expr!()

      let body = self.parse_block!()

      For(var~, range={ start, end, inclusive }, body~, span=self.span(start_idx))
    }
    _ => {
      self.parse_assignment_stmt!()
    }
  }
}

fn parse_type(self: Parser) -> Type!ParserError {
  let start_idx = self.index

  let base_ty = match self.peek() {
    Logic => {
      self.advance()
      Type::Logic
    }
    Identifier(name) => {
      self.advance()
      Type::Name(name~)
    }
    _ => raise ExpectedType(received=self.peek(), span=self.span(start_idx))
  }

  if self.consumes(Lbracket) {
    let (width, _) = self.parse_integer!()
    self.expect!(Rbracket, start_idx)
    return Vector(ty=base_ty, len=width)
  } else {
    return base_ty
  }

  raise ExpectedType(received=self.peek(), span=self.span(start_idx))
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

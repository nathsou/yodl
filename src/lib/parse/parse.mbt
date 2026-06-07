pub struct Parser {
  tokens: Array[Token]
  mut index: Int
  file: String
  file_content: StringView
}

pub suberror ParserError {
  UnexpectedToken(expected~: TokenType, received~: TokenType, span~: Span)
  ExpectedIdentifier(received~: TokenType, span~: Span)
  ExpectedExpr(received~: TokenType, span~: Span)
  ExpectedStmt(received~: TokenType, span~: Span)
  ExpectedType(received~: TokenType, span~: Span)
  ExpectedDecl(received~: TokenType, span~: Span)
  ExpectedRangeOperator(received~: TokenType, span~: Span)
  MultipleDefaultCases(span~: Span)
  InvalidPortOrTupleAccess(span~: Span)
  DuplicateStructField(name~: String, span~: Span)
  DidYouMean(received~: TokenType, suggestion~: String, span~: Span)
} derive(Debug)

pub impl Show for ParserError with output(self, logger) {
  match self {
    UnexpectedToken(expected~, received~, span~) =>
      logger.write_string("UnexpectedToken: expected '\{expected}', got '\{received}' at \{span}\n\{span.context()}")
    ExpectedType(received~, span~) =>
      logger.write_string("Expected a type, got '\{received}' at \{span}\n\{span.context()}")
    ExpectedExpr(received~, span~) =>
      logger.write_string("Expected an expression, got '\{received}' at \{span}\n\{span.context()}")
    ExpectedIdentifier(received~, span~) =>
      logger.write_string("Expected an identifier, got '\{received}' at \{span}\n\{span.context()}")
    ExpectedStmt(received~, span~) =>
      logger.write_string("Expected a statement, got '\{received}' at \{span}\n\{span.context()}")
    ExpectedDecl(received~, span~) =>
      logger.write_string("Expected a declaration, got '\{received}' at \{span}\n\{span.context()}")
    ExpectedRangeOperator(received~, span~) =>
      logger.write_string("Expected a range operator ('..' or '..='), got '\{received}' at \{span}\n\{span.context()}")
    DidYouMean(received~, suggestion~, span~) =>
      logger.write_string("Unexpected '\{received}' at \{span}: \{suggestion}\n\{span.context()}")
    MultipleDefaultCases(span~) =>
      logger.write_string("Multiple default cases in match at \{span}\n\{span.context()}")
    InvalidPortOrTupleAccess(span~) =>
      logger.write_string("Invalid port or tuple access at \{span}\n\{span.context()}")
    DuplicateStructField(name~, span~) =>
      logger.write_string("Duplicate struct field '\{name}' at \{span}\n\{span.context()}")
  }
}

pub fn Parser::new(tokens: Array[Token], file~: String, file_content~: StringView) -> Parser {
  { tokens, index: 0, file, file_content }
}

fn Parser::peek(self: Parser) -> TokenType {
  if self.tokens.get(self.index) is Some(token) {
    token.kind
  } else {
    TokenType::Semicolon
  }
}

fn Parser::lookahead(self: Parser, n: Int) -> Token {
  self.tokens[self.index + n]
}

fn Parser::advance(self: Parser) -> Unit {
  self.index += 1
}

fn Parser::expect(self: Parser, expected: TokenType, span_start_idx: Int) -> Unit raise ParserError {
  let token = self.peek()

  if token == expected {
    self.advance()
  } else {
    raise UnexpectedToken(expected~, received=token, span=self.span(span_start_idx))
  }
}

fn Parser::matches(self: Parser, token: TokenType) -> Bool {
  self.index < self.tokens.length() && self.peek() == token
}

fn Parser::consumes(self: Parser, token: TokenType) -> Bool {
  if self.matches(token) {
    self.advance()
    true
  } else {
    false
  }
}

fn Parser::ignore(self: Parser, token: TokenType) -> Unit {
  if self.matches(token) {
    self.advance()
  }
}

fn Parser::parse_identifier(self: Parser) -> String raise {
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

pub fn Parser::span(self: Parser, start_idx: Int) -> Span {
  let start = self.tokens[start_idx].span.start
  let end = self.tokens[@utils.clamp(self.index - 1, min=0, max=self.tokens.length() - 1)].span.end
  { file: self.file, file_content: self.file_content, start, end }
}

fn Parser::precedence_climbing(self: Parser, min_precedence: Int) -> Expr raise {
  let mut lhs = self.parse_indexing_expr()

  while self.index < self.tokens.length() {
    match self.peek().to_binop() {
      Some(op) => {
        let precedence = op.precedence()

        if precedence >= min_precedence {
          let start_idx = self.index
          self.advance() // consume the operator

          match op {
            Ternary => {
              let then = self.parse_expr()
              self.expect(Colon, start_idx)
              let else_ = self.precedence_climbing(precedence)
              lhs = Ternary(cond=lhs, then~, else_~, ty={ val: None }, span=self.span(start_idx))
            }
            _ => {
              // left-associative
              let rhs = self.precedence_climbing(precedence + 1)
              lhs = Binary(op~, lhs~, rhs~, output_width=@ref.new(None), span=self.span(start_idx), ty=@ref.new(None))
            }
          }

        } else {
          break
        }
      }
      None => break
    }
  }

  lhs
}

fn Parser::parse_indexing_expr(self: Parser) -> Expr raise {
  let start_idx = self.index
  let mut lhs = self.parse_primary_expr()

  while true {
    if self.consumes(Lbracket) {
      let index = self.parse_expr()

      match self.peek() {
        Colon | MinusColon as op => {
          self.advance()
          
          let kind = match op {
            Colon => PartSelect::Absolute
            _ => PartSelect::Width
          }

          let lsb = self.parse_expr()
          self.expect(Rbracket, start_idx)
          lhs = Slicing(expr=lhs, hi=index, lo=lsb, kind~, span=self.span(start_idx), ty={ val: None })
        }
        _ => {
          self.expect(Rbracket, start_idx)
          lhs = Indexing(expr=lhs, index~, span=self.span(start_idx), ty={ val: None })
        }
      }
    } else if self.consumes(Dot) {
      match self.peek() {
        Identifier(port) => {
          self.advance()
          lhs = FieldAccess(expr=lhs, field=port, span=self.span(start_idx), ty={ val: None })
        }
        Natural(value~, ..) => {
          self.advance()
          let span = self.span(start_idx)
          lhs = FieldAccess(expr=lhs, field=value.to_string(), span~, ty={ val: None })
        }
        _ => raise InvalidPortOrTupleAccess(span=self.span(start_idx))
      }
    } else {
      break
    }
  }

  lhs
}

fn Parser::parse_match_expr(self: Parser) -> Expr raise {
  let start_idx = self.index
  self.expect(Match, start_idx)
  let subject = self.parse_expr()
  self.expect(Lbrace, start_idx)
  let cases = []
  let mut default = None

  while !self.matches(Rbrace) {
    if self.consumes(Underscore) {
      self.expect(RightThickArrow, start_idx)
      let expr = self.parse_expr()

      match default {
        Some(_) => raise MultipleDefaultCases(span=self.span(start_idx))
        None => {
          default = Some(expr)
        }
      }
    } else {
      let value = self.parse_expr()
      self.expect(RightThickArrow, start_idx)
      let expr = self.parse_expr()
      cases.push((value, expr))
    }

    if !self.consumes(Semicolon) {
      break
    }
  }

  self.expect(Rbrace, start_idx)

  Match(subject~, cases~, default~, span=self.span(start_idx), ty={ val: None })
}

fn Parser::parse_if_expr(self: Parser) -> Expr raise {
  let start_idx = self.index
  self.expect(If, self.index)
  let cond = self.parse_expr()
  let then = stmt_list_to_block(self.parse_block(), span=self.span(start_idx))
  let mut else_ = None

  while self.consumes(Else) {
    if self.matches(If) {
      else_ = Some(self.parse_if_expr())
    } else {
      else_ = Some(stmt_list_to_block(self.parse_block(), span=self.span(start_idx)))
      break
    }
  }

  If(cond~, then~, else_~, span=self.span(start_idx), ty={ val: None })
}

fn Parser::parse_primary_expr(self: Parser) -> Expr raise {
  let token = self.peek()
  let start_idx = self.index

  match token {
    Identifier(name) => {
      self.advance()
      let path = self.parse_path(name)

      if self.matches(Lparen) || self.matches(Lchevron) {
        self.parse_instance_expr(path~)
      } else {
        Identifier(path~, span=self.span(start_idx), ty={ val: None })
      }
    }
    Natural(value~, width~, base~) => {
      self.advance()
      Natural(value~, width~, base~, span=self.span(start_idx), ty={ val: None })
    }
    StringLiteral(str) => {
      self.advance()
      String(value=str, span=self.span(start_idx), ty={ val: None })
    }
    CharacterLiteral(char) => {
      self.advance()
      let span = self.span(start_idx)
      let str = Expr::String(value=char.to_string(), span~, ty={ val: None })
      Indexing(expr=str, index=Expr::nat(0, span~, width=None, base=10), span~, ty={ val: None })
    }
    Not | Minus | Andr | Orr | Xorr as op => {
      self.advance()
      let expr = self.parse_indexing_expr()
      let unop: UnaryOp = match op {
        Not => Not
        Minus => Neg
        Andr => Andr
        Orr => Orr
        Xorr => Xorr
        _ => @utils.unreachable_code()
      }

      Unary(op=unop, expr~, span=self.span(start_idx), ty={ val: None })
    }
    Lparen => self.parse_paren_or_record_expr()
    Lbracket => self.parse_vector_expr()
    Lbrace => self.parse_block_expr()
    Match => self.parse_match_expr()
    If => self.parse_if_expr()
    DotDot => self.parse_spread_expr()
    BuiltinFunction(name) => { self.advance(); self.parse_function_call_expr(name) }
    Lchevron => raise DidYouMean(received=token, span=self.span(start_idx), suggestion="Expected expression but got '<', did you mean '<:' (less than operator) instead?")
    Rchevron => raise DidYouMean(received=token, span=self.span(start_idx), suggestion="Expected expression but got '>', did you mean '>:' (greater than operator) instead?")
    _ => raise ExpectedExpr(received=token, span=self.span(start_idx))
  }
}

fn Parser::parse_spread_expr(self: Parser) -> Expr raise {
  let start_idx = self.index
  self.expect(DotDot, start_idx)
  let expr = self.parse_expr()
  Spread(expr~, span=self.span(start_idx), ty={ val: None })
}

fn Parser::parse_function_call_expr(self: Parser, name: String) -> Expr raise {
  let start_idx = self.index
  let args: Array[Expr] = []
  self.expect(Lparen, start_idx)

  while !self.matches(Rparen) {
    let arg = self.parse_expr()
    args.push(arg)

    if !self.consumes(Comma) {
      break
    }
  }

  self.expect(Rparen, start_idx)

  FunCall(name~, args~, span=self.span(start_idx), ty={ val: None })
}

// Parse `( ... )` which can be:
//   ()                   -> empty record (Struct with no fields)
//   (x)                  -> grouping (returns inner expression)
//   (x,)                 -> 1-element positional record (Struct {"0": x})
//   (a, b, ...)          -> positional record (Struct {"0": a, "1": b, ...})
//   (name: e, ...)       -> named record (Struct {name: e, ...})
//   (..base, name: e)    -> named record with spread (only valid in named mode)
//
// Mixed positional + named is disallowed (Q1: all-or-nothing).
// Spread is allowed only in named records (Q6).
fn Parser::parse_paren_or_record_expr(self: Parser) -> Expr raise {
  let start_idx = self.index
  self.expect(Lparen, start_idx)

  // empty record
  if self.consumes(Rparen) {
    return Struct(fields=Map([]), span=self.span(start_idx), ty={ val: None })
  }

  // Look at the first element: is it `..` (spread) or `name :` (named)?
  let first_is_spread = self.matches(DotDot)
  let first_is_named = !first_is_spread &&
    (self.lookahead(0).kind is Identifier(_) && self.lookahead(1).kind is Colon)

  if first_is_named || first_is_spread {
    // named record (with optional leading spread)
    let fields: Map[String, Expr] = {}
    while !self.matches(Rparen) {
      if self.matches(DotDot) {
        // spread element
        let spread_start = self.index
        self.advance()
        let base = self.parse_expr()
        let spread_span = self.span(spread_start)
        // Use a synthetic field name "..n" to preserve order;
        // simplifier/type-checker can expand spreads.
        let mut idx = 0
        let mut key = "..\{idx}"
        while fields.contains(key) {
          idx += 1
          key = "..\{idx}"
        }
        fields[key] = Spread(expr=base, span=spread_span, ty={ val: None })
      } else {
        let name = self.parse_identifier()
        self.expect(Colon, start_idx)
        let value = self.parse_expr()
        if fields.contains(name) {
          raise DuplicateStructField(name~, span=self.span(start_idx))
        }
        fields[name] = value
      }

      if !self.consumes(Comma) {
        break
      }
    }

    self.expect(Rparen, start_idx)
    return Struct(fields~, span=self.span(start_idx), ty={ val: None })
  } else {
    // positional list or grouping
    let elems = [self.parse_expr()]
    let mut had_trailing_comma = false

    while self.consumes(Comma) {
      if self.matches(Rparen) {
        had_trailing_comma = true
        break
      }
      // disallow named entries in positional mode
      if self.lookahead(0).kind is Identifier(_) && self.lookahead(1).kind is Colon {
        raise ExpectedExpr(received=self.peek(), span=self.span(start_idx))
      }
      let elem = self.parse_expr()
      elems.push(elem)
    }

    self.expect(Rparen, start_idx)

    if elems.length() == 1 && !had_trailing_comma {
      // grouping
      elems[0]
    } else {
      // positional record: integer-keyed Struct
      let fields = Map([], capacity=elems.length())
      for idx, elem in elems {
        fields[idx.to_string()] = elem
      }
      Struct(fields~, span=self.span(start_idx), ty={ val: None })
    }
  }
}

// Parse a block expression `{ stmt; stmt; ...; last_expr }`.
fn Parser::parse_block_expr(self: Parser) -> Expr raise {
  let start_idx = self.index
  self.expect(Lbrace, start_idx)
  let body = []

  while !self.matches(Rbrace) {
    let stmt = self.parse_stmt()
    body.push(stmt)
  }

  self.expect(Rbrace, start_idx)
  stmt_list_to_block(body, span=self.span(start_idx))
}

fn stmt_list_to_block(body: Array[Stmt], span~: Span) -> Expr {
  let last = match body.last() {
      Some(Stmt::Expr(expr~, span=_)) => {
        let _ = body.unsafe_pop()
        Some(expr)
      }
      _ => None
    }

  Block(body~, last~, span~, ty={ val: None })
}

fn Parser::parse_vector_expr(self: Parser) -> Expr raise {
  let start_idx = self.index
  self.expect(Lbracket, start_idx)
  let elems = []

  while !self.matches(Rbracket) {
    let elem = self.parse_expr()
    elems.push(elem)

    if !self.consumes(Comma) {
      break
    }
  }

  self.expect(Rbracket, start_idx)

  Vector(elems~, span=self.span(start_idx), ty={ val: None })
}

fn Parser::parse_instance_parameter(self: Parser) -> Param {
  let start_idx = self.index
  let mut open_brackets = 1
  let tokens: Array[Token] = []

  while self.index < self.tokens.length() {
    let token = self.tokens[self.index]

    match token.kind {
      Lchevron => open_brackets += 1
      Rchevron => {
        open_brackets -= 1
        if open_brackets == 0 {
          break
        }
      }
      Comma if open_brackets == 1 => break
      _ => ()
    }

    tokens.push(token)
    self.advance()
  }

  let span = self.span(start_idx)
  let text = span.text()

  Param::Unresolved({
    tokens,
    text: text[:],
    file: self.file,
    span,
  })
}

fn Parser::parse_instance_expr(self: Parser, path~: Path) -> Expr raise {
  let start_idx = self.index
  let params: Array[(String?, Param)] = self.parse_module_parameters(() => {
    match self.lookahead(0).kind {
      Identifier(name) => {
        if self.lookahead(1).kind == Colon {
          self.advance()
          self.advance()
          return (Some(name), self.parse_instance_parameter())
        }
      }
      _ => ()
    }

    return (None, self.parse_instance_parameter())
  })

  self.expect(Lparen, start_idx)
  let ports = {}

  while !self.matches(Rparen) {
    self.ignore(Semicolon) // skip auto-inserted semicolons from newlines
    if self.matches(Rparen) {
      break
    }
    let start_idx = self.index
    let name = self.parse_identifier()
    
    if self.consumes(Colon) {
      ports[name] = self.parse_expr()
    } else {
      ports[name] = Identifier(path=Path::new([], name), span=self.span(start_idx), ty={ val: None })
    }

    if !self.consumes(Comma) {
      self.ignore(Semicolon) // consume auto-inserted semicolon before ')'
      break
    }
  }

  self.expect(Rparen, start_idx)

  Instance(
    path~,
    params=InstanceParams::new(params),
    ports~,
    span=self.span(start_idx),
    ty={ val: None },
  )
}

fn Parser::parse_expr(self: Parser) -> Expr raise {
  self.precedence_climbing(0)
}

fn Parser::parse_assignment_stmt(self: Parser) -> Stmt raise {
  let start_idx = self.index
  let lhs = self.parse_indexing_expr()

  if self.consumes(Equal) {
    let rhs = self.parse_expr()
    self.expect(Semicolon, self.index)
    Assign(lhs~, rhs~, span=self.span(start_idx))
  } else if self.consumes(Semicolon) {
    Expr(expr=lhs, span=self.span(start_idx))
  } else {
    match lhs {
      Match(_) | If(_) | Block(_) => {
        // accept match, if and block expressions without a semicolon
        Expr(expr=lhs, span=self.span(start_idx))
      }
      _ => {
        raise ExpectedStmt(received=self.peek(), span=self.span(start_idx))
      }
    }
  }
}

fn Parser::parse_block(self: Parser) -> Array[Stmt] raise {
  self.expect(Lbrace, self.index)
  let stmts = []

  while self.peek() != Rbrace {
    stmts.push(self.parse_stmt())
  }

  self.expect(Rbrace, self.index)

  stmts
}

fn Parser::parse_stmt(self: Parser) -> Stmt raise {
  let token = self.peek()
  let start_idx = self.index

  match token {
    Let => {
      self.advance()
      let name = self.parse_identifier()

      let ty = if self.consumes(Colon) {
        Some(self.parse_type())
      } else {
        None
      }

      let expr = if self.consumes(Equal) {
        Some(self.parse_expr())
      } else {
        None
      }
      
      self.expect(Semicolon, start_idx)

      Let(name~, ty={ val: ty }, expr~, span=self.span(start_idx))
    }
    For => {
      self.advance()
      let variable = self.parse_identifier()
      self.expect(In, start_idx)

      let start = self.parse_expr()

      let inclusive = if self.consumes(DotDotLeftChevron) {
        false
      } else if self.consumes(DotDotEqual) {
        true
      } else {
        raise ExpectedRangeOperator(received=self.peek(), span=self.span(start_idx))
      }

      let end = self.parse_expr()
      let body = self.parse_block()
      self.ignore(Semicolon)

      For(variable~, range={ start, end, inclusive }, body~, span=self.span(start_idx))
    }
    Const => Stmt::Const(decl=self.parse_const_decl(), span=self.span(start_idx))
    _ => {
      self.parse_assignment_stmt()
    }
  }
}

fn Parser::parse_const_decl(self: Parser) -> ConstDecl raise {
  let start_idx = self.index
  self.expect(Const, start_idx)
  let name = self.parse_identifier()

  let ty = if self.matches(Colon) {
    self.advance()
    Some(self.parse_type())
  } else {
    None
  }
  
  self.expect(Equal, start_idx)
  let expr = self.parse_expr()
  self.expect(Semicolon, start_idx)

  { path: Path::new([], name), ty, expr, span: self.span(start_idx) }
}

fn Parser::parse_package_decl(self: Parser) -> PackageDecl raise {
  let start_idx = self.index
  self.expect(Package, start_idx)
  let name = self.parse_identifier()
  let body = []

  self.expect(Lbrace, start_idx)

  while !self.consumes(Rbrace) {
    let decl = self.parse_decl()
    body.push(decl)
  }

  self.ignore(Semicolon)

  { name, body, span: self.span(start_idx) }
}

fn Parser::parse_import_decl(self: Parser) -> ImportDecl raise {
  let start_idx = self.index
  self.expect(Import, start_idx)
  let packages = [self.parse_identifier()]

  while self.consumes(ColonColon) {
    packages.push(self.parse_identifier())
  }

  self.expect(Semicolon, start_idx)

  { packages, span: self.span(start_idx) }
}

// Parse a compile-time static index expression (Nat-sorted).
// Supports: literals, identifiers (Var), +, -, *, clog2!(...), cdiv!(...), and parentheses.
fn Parser::parse_index_expr(self: Parser) -> IndexExpr raise {
  self.parse_index_expr_add()
}

fn Parser::parse_index_expr_add(self: Parser) -> IndexExpr raise {
  let mut lhs = self.parse_index_expr_mul()

  while true {
    if self.consumes(Plus) {
      let rhs = self.parse_index_expr_mul()
      lhs = Add(lhs, rhs)
    } else if self.consumes(Minus) {
      let rhs = self.parse_index_expr_mul()
      lhs = Sub(lhs, rhs)
    } else {
      break
    }
  }

  lhs
}

fn Parser::parse_index_expr_mul(self: Parser) -> IndexExpr raise {
  let mut lhs = self.parse_index_expr_primary()

  while self.consumes(Star) {
    let rhs = self.parse_index_expr_primary()
    lhs = Mul(lhs, rhs)
  }

  lhs
}

fn Parser::parse_index_expr_primary(self: Parser) -> IndexExpr raise {
  let start_idx = self.index

  match self.peek() {
    Natural(value~, ..) => {
      self.advance()
      Lit(value.to_int())
    }
    Identifier(name) => {
      self.advance()
      // Simple single-segment identifier → static variable
      Var(name)
    }
    BuiltinFunction(name) => {
      self.advance()
      self.expect(Lparen, start_idx)
      match name {
        "clog2" => {
          let arg = self.parse_index_expr()
          self.expect(Rparen, start_idx)
          Clog2(arg)
        }
        "cdiv" => {
          let dividend = self.parse_index_expr()
          self.expect(Comma, start_idx)
          let divisor = self.parse_index_expr()
          self.expect(Rparen, start_idx)
          CDiv(dividend, divisor)
        }
        _ => raise ExpectedExpr(received=BuiltinFunction(name), span=self.span(start_idx))
      }
    }
    Lparen => {
      self.advance()
      let inner = self.parse_index_expr()
      self.expect(Rparen, start_idx)
      inner
    }
    token => raise ExpectedExpr(received=token, span=self.span(start_idx))
  }
}

// Parse a parameter sort: `Nat` → NatSort; `Type` → TypeSort
fn Parser::parse_param_sort(self: Parser) -> ParamSort raise {
  let start_idx = self.index

  match self.peek() {
    Identifier("Nat") => {
      self.advance()
      NatSort
    }
    Identifier("Type") => {
      self.advance()
      TypeSort
    }
    token => raise ExpectedType(received=token, span=self.span(start_idx))
  }
}

fn Parser::parse_type_alias_decl(self: Parser) -> TypeAliasDecl raise {
  let start_idx = self.index
  self.expect(Type, start_idx)
  let name = self.parse_identifier()
  let parameters: Array[StaticParam] = []
  
  if self.consumes(Lchevron) {
    while !self.matches(Rchevron) {
      let param_start = self.index
      let param_name = self.parse_identifier()
      let sort = if self.consumes(Colon) {
        self.parse_param_sort()
      } else {
        TypeSort // default: type parameter
      }
      parameters.push({ name: param_name, sort, span: self.span(param_start) })

      if !self.consumes(Comma) {
        break
      }
    }

    self.expect(Rchevron, start_idx)
  }

  self.expect(Equal, start_idx)
  let ty = self.parse_type()
  self.expect(Semicolon, start_idx)

  { name, parameters, ty, span: self.span(start_idx) }
}

fn Parser::parse_path(self: Parser, first: String) -> Path raise {
  let packages = [first]

  while self.consumes(ColonColon) {
    let name = self.parse_identifier()
    packages.push(name)
  }

  let elem = packages.unsafe_pop()

  Path::new(packages, elem)
}

fn Parser::parse_type(self: Parser) -> Type raise {
  let start_idx = self.index

  let mut base_ty: Type = match self.peek() {
    Bool => {
      self.advance()
      UInt(Lit(1))
    }
    UInt => {
      self.advance()
      if self.consumes(Lchevron) {
        let width = self.parse_index_expr()
        self.expect(Rchevron, start_idx)
        UInt(width)
      } else {
        Nat({min_width: 0})
      }
    }
    SInt => {
      self.advance()
      self.expect(Lchevron, start_idx)
      let width = self.parse_index_expr()
      self.expect(Rchevron, start_idx)
      SInt(width)
    }
    Clock => {
      self.advance()
      Clock
    }
    Identifier(name) => {
      self.advance()
      let path = self.parse_path(name)
      let params: Array[Type] = []

      if self.consumes(Lchevron) {
        while !self.matches(Rchevron) {
          let param = self.parse_type()
          params.push(param)

          if !self.consumes(Comma) {
            break
          }
        }

        self.expect(Rchevron, start_idx)
      }

      if path is { packages: [], elem: "MemoryMask" } && params is [ty] {
        Type::MemoryMask(ty)
      } else {
        Type::Name(path~, params~)
      }
    }
    Lparen => {
      self.advance()

      // empty record
      if self.consumes(Rparen) {
        return Struct(Map([]))
      }

      // Look ahead: if first token is Identifier followed by Colon, this is a named struct type.
      let is_named = self.lookahead(0).kind is Identifier(_) && self.lookahead(1).kind is Colon

      if is_named {
        let fields = {}

        while !self.matches(Rparen) {
          let name = self.parse_identifier()
          self.expect(Colon, start_idx)
          let ty = self.parse_type()

          if fields.contains(name) {
            raise DuplicateStructField(name~, span=self.span(start_idx))
          }

          fields[name] = ty

          if !self.consumes(Comma) {
            break
          }
        }

        self.expect(Rparen, start_idx)
        Struct(fields)
      } else {
        // positional / grouping
        let elems = [self.parse_type()]
        let mut had_trailing_comma = false

        while self.consumes(Comma) {
          if self.matches(Rparen) {
            had_trailing_comma = true
            break
          }
          let elem = self.parse_type()
          elems.push(elem)
        }

        self.expect(Rparen, start_idx)

        if elems.length() == 1 && !had_trailing_comma {
          elems[0]
        } else {
          let fields = Map([], capacity=elems.length())

          for idx, elem in elems {
            fields[idx.to_string()] = elem
          }

          Struct(fields)
        }
      }
    }
    _ => raise ExpectedType(received=self.peek(), span=self.span(start_idx))
  }

  while self.consumes(Lbracket) {
    let len = self.parse_index_expr()
    self.expect(Rbracket, start_idx)
    base_ty = Vector(ty=base_ty, len~)
  }

  base_ty
}

fn Parser::parse_port(self: Parser, dir~: PortDir) -> Port raise {
  let start_idx = self.index
  let name = self.parse_identifier()
  let optional = self.consumes(QuestionMark)
  self.expect(Colon, start_idx)
  let attributes1 = self.parse_attributes()
  let ty = self.parse_type()
  let attributes2 = self.parse_attributes()
  let attributes = @utils.merge(attributes1, attributes2)
  let dir = match attributes.get("inout") {
    Some(_) => InOut
    None => dir
  }

  { name, ty, dir, optional, attributes, span: self.span(start_idx) }
}

fn Parser::parse_port_list(self: Parser, dir~: PortDir) -> Array[Port] raise {
  let start_idx = self.index
  let ports = []

  self.expect(Lparen, start_idx)

  while !self.matches(Rparen) {
    let port = self.parse_port(dir~)
    ports.push(port)

    if !self.consumes(Comma) {
      break
    }
  }

  self.expect(Rparen, start_idx)

  ports
}

fn[T] Parser::parse_module_parameters(self: Parser, parse_elem: () -> T raise) -> Array[T] raise {
  if self.consumes(Lchevron) {
    let start_idx = self.index
    let params = []

    while !self.matches(Rchevron) {
      let param = parse_elem()
      params.push(param)

      if !self.consumes(Comma) {
        break
      }
    }

    self.expect(Rchevron, start_idx)

    params
  } else {
    []
  }
}

fn Parser::parse_attribute_value(self: Parser) -> AttributeValue raise {
  let token = self.peek()
  let start_idx = self.index

  match token {
    StringLiteral(str) => {
      self.advance()
      AttributeValue::String(str)
    }
    Natural(value~, ..) => {
      self.advance()
      AttributeValue::Int(value.to_int())
    }
    Lbrace => {
      self.advance()
      let dict: Map[String, AttributeValue] = {}

      while !self.matches(Rbracket) {
        let key = match self.peek() {
          StringLiteral(str) => {
            self.advance()
            str
          }
          Identifier(name) => {
            self.advance()
            name
          }
          _ => raise ExpectedExpr(received=self.peek(), span=self.span(start_idx))
        }

        self.expect(Colon, start_idx)
        let value = self.parse_attribute_value()
        dict[key] = value

        if !self.consumes(Comma) {
          break
        }
      }

      self.expect(Rbrace, start_idx)
      AttributeValue::Dict(dict)
    }
    _ => raise ExpectedExpr(received=token, span=self.span(start_idx))
  }
}

fn Parser::parse_attribute(self: Parser) -> Attribute raise {
  let start_idx = self.index
  self.expect(At, start_idx)
  let name = self.parse_identifier()

  let args = if self.consumes(Lparen) {
    let args = []

    while !self.matches(Rparen) {
      let val = self.parse_attribute_value()
      args.push(val)

      if !self.consumes(Comma) {
        break
      }
    }

    self.expect(Rparen, start_idx)

    args
  } else {
    []
  }

  self.ignore(Semicolon)

  { name, args, span: self.span(start_idx) }
}

fn Parser::parse_attributes(self: Parser) -> Map[String, Attribute] raise {
  let attrs = {}

  while self.matches(At) {
    let attr = self.parse_attribute()
    attrs[attr.name] = attr
  }

  attrs
}

fn Parser::parse_module_signature(self: Parser, attributes~: Map[String, Attribute]) -> ModuleSignature raise {
  let start_idx = self.index
  self.expect(Module, start_idx)
  let name = self.parse_identifier()
  let params = self.parse_module_parameters(() => {
    let param_start_idx = self.index
    let param_name = self.parse_identifier()
    self.expect(Colon, start_idx)
    let sort = self.parse_param_sort()
    
    ModuleParameter::{ name: param_name, sort, span: self.span(param_start_idx) }
  })
  let inputs = self.parse_port_list(dir=Input)
  self.expect(RightThinArrow, start_idx)
  let outputs = self.parse_port_list(dir=Output)
  let ports = @utils.concat(inputs, outputs)

  { path: Path::new([], name), params, attributes, ports, span: self.span(start_idx) }
}

fn Parser::parse_module_definition(self: Parser, sig~: ModuleSignature) -> ModuleDecl raise {
  let start_idx = self.index
  let { path, params, attributes, ports, .. } = sig
  self.expect(Lbrace, start_idx)
  let body = []

  while !self.consumes(Rbrace) {
    let stmt = self.parse_stmt()
    body.push(stmt)
  }

  { path, params, attributes, ports, body, span: self.span(start_idx) }
}

fn Parser::parse_module_def_or_decl(self: Parser) -> Decl raise {
  let attributes = self.parse_attributes()
  let is_declaration = self.consumes(Declare)
  let sig = self.parse_module_signature(attributes~)

  if is_declaration {
    self.expect(Semicolon, self.index)
    ModuleDeclaration(sig)
  } else {
    let def = self.parse_module_definition(sig~)
    self.expect(Semicolon, self.index)
    Module(def)
  }
}

fn Parser::parse_decl(self: Parser) -> Decl raise {
  match self.peek() {
    At | Declare | Module => self.parse_module_def_or_decl()
    Const => Decl::Const(self.parse_const_decl())
    Package => Decl::Package(self.parse_package_decl())
    Import => Decl::Import(self.parse_import_decl())
    Type => Decl::TypeAlias(self.parse_type_alias_decl())
    token => raise ExpectedDecl(received=token, span=self.span(self.index))
  }
}

pub fn Parser::parse(self: Parser) -> Array[Decl] raise {
  let decls = []

  while self.index < self.tokens.length() {
    let decl = self.parse_decl()
    decls.push(decl)
  }

  decls
}

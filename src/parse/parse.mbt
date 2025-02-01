pub struct Parser {
  tokens: Array[Token]
  mut index: Int
  file: String
}

pub type! ParserError {
  UnexpectedToken(expected~: TokenType, received~: TokenType, span~: Span)
  ExpectedIdentifier(received~: TokenType, span~: Span)
  ExpectedInteger(received~: TokenType, span~: Span)
  ExpectedStringLiteral(received~: TokenType, span~: Span)
  ExpectedExpr(received~: TokenType, span~: Span)
  ExpectedStmt(received~: TokenType, span~: Span)
  ExpectedType(received~: TokenType, span~: Span)
  ExpectedDecl(received~: TokenType, span~: Span)
  ExpectedRangeOperator(received~: TokenType, span~: Span)
  MultipleDefaultCases(span~: Span)
  InvalidPortOrTupleAccess(span~: Span)
  DuplicateStructField(name~: String, span~: Span)
} derive(Show)

pub fn Parser::new(tokens: Array[Token], file~: String) -> Parser {
  { tokens, index: 0, file }
}

fn Parser::peek(self: Parser) -> TokenType {
  self.tokens[self.index].kind
}

fn Parser::lookahead(self: Parser, n: Int) -> Token {
  self.tokens[self.index + n]
}

fn Parser::advance(self: Parser) -> Unit {
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

fn Parser::matches(self: Parser, token: TokenType) -> Bool {
  self.index < self.tokens.length() && self.peek() == token
}

fn matches_predicate(self: Parser, predicate: (TokenType) -> Bool) -> Bool {
  predicate(self.peek())
}

fn Parser::consumes(self: Parser, token: TokenType) -> Bool {
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

fn Parser::parse_identifier(self: Parser) -> String! {
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

fn Parser::parse_integer(self: Parser) -> ParsedInteger!ParserError {
  let token = self.peek()
  let start_idx = self.index

  match token {
    Natural(bits~, width~, base~) => {
      self.advance()
      { bits, width, base }
    }
    _ => raise ExpectedInteger(received=token, span=self.span(start_idx))
  }
}

fn parse_string_literal(self: Parser) -> String! {
  let token = self.peek()
  let start_idx = self.index

  match token {
    StringLiteral(str) => {
      self.advance()
      str
    }
    _ => raise ExpectedStringLiteral(received=token, span=self.span(start_idx))
  }
}

pub fn Parser::span(self: Parser, start_idx: Int) -> Span {
  let start = self.tokens[start_idx].span.start
  let end = self.tokens[@utils.clamp(self.index - 1, min=0, max=self.tokens.length() - 1)].span.end
  { file: self.file, start, end }
}

fn precedence_climbing(self: Parser, min_precedence: Int) -> Expr! {
  let mut lhs = self.parse_indexing_expr!()

  while self.index < self.tokens.length() {
    match self.peek().to_binop() {
      Some(op) => {
        let precedence = op.precedence()

        if precedence >= min_precedence {
          let start_idx = self.index
          self.advance() // consume the operator

          match op {
            Ternary => {
              let then = self.parse_expr!()
              self.expect!(Colon, start_idx)
              let else_ = self.precedence_climbing!(precedence)
              lhs = Ternary(cond=lhs, then~, else_~, ty={ val: None }, span=self.span(start_idx))
            }
            _ => {
              // left-associative
              let rhs = self.precedence_climbing!(precedence + 1)
              lhs = Binary(op~, lhs~, rhs~, span=self.span(start_idx), ty={ val: None })
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

fn parse_indexing_expr(self: Parser) -> Expr! {
  let start_idx = self.index
  let mut lhs = self.parse_replication_expr!()

  while true {
    if self.consumes(Lbracket) {
      let index = self.parse_expr!()

      match self.peek() {
        Colon | MinusColon as op => {
          self.advance()
          
          let kind = match op {
            Colon => PartSelect::Absolute
            _ => PartSelect::Width
          }

          let lsb = self.parse_expr!()
          self.expect!(Rbracket, start_idx)
          lhs = Slicing(expr=lhs, hi=index, lo=lsb, kind~, span=self.span(start_idx), ty={ val: None })
        }
        _ => {
          self.expect!(Rbracket, start_idx)
          lhs = Indexing(expr=lhs, index~, span=self.span(start_idx), ty={ val: None })
        }
      }
    } else if self.consumes(Dot) {
      match self.peek() {
        Identifier(port) => {
          self.advance()
          lhs = FieldAccess(expr=lhs, field=port, span=self.span(start_idx), ty={ val: None })
        }
        Natural(bits~, ..) => {
          self.advance()
          let span = self.span(start_idx)
          lhs = FieldAccess(expr=lhs, field=bits.as_int!().to_string(), span~, ty={ val: None })
        }
        _ => raise InvalidPortOrTupleAccess(span=self.span(start_idx))
      }
    } else {
      break
    }
  }

  lhs
}

fn parse_match_expr(self: Parser) -> Expr! {
  let start_idx = self.index
  self.expect!(Match, start_idx)
  let subject = self.parse_expr!()
  self.expect!(Lbrace, start_idx)
  let cases = []
  let mut default = None

  while not(self.matches(Rbrace)) {
    if self.consumes(Underscore) {
      self.expect!(RightThickArrow, start_idx)
      let expr = self.parse_expr!()

      match default {
        Some(_) => raise MultipleDefaultCases(span=self.span(start_idx))
        None => {
          default = Some(expr)
        }
      }
    } else {
      let value = self.parse_expr!()
      self.expect!(RightThickArrow, start_idx)
      let expr = self.parse_expr!()
      cases.push((value, expr))
    }

    if not(self.consumes(Comma)) {
      break
    }
  }

  self.expect!(Rbrace, start_idx)

  Match(subject~, cases~, default~, span=self.span(start_idx), ty={ val: None })
}

fn parse_if_expr(self: Parser) -> Expr! {
  let start_idx = self.index
  self.expect!(If, self.index)
  let cond = self.parse_expr!()
  let then = self.parse_expr!()
  let else_ = if self.consumes(Else) {
    Some(self.parse_expr!())
  } else {
    None
  }

  If(cond~, then~, else_~, span=self.span(start_idx), ty={ val: None })
}

fn parse_primary_expr(self: Parser) -> Expr! {
  let token = self.peek()
  let start_idx = self.index

  match token {
    Identifier(name) => {
      self.advance()
      let path = self.parse_path!(name)

      if self.matches(Lparen) || self.matches(Lchevron) {
        self.parse_instance_expr!(path~)
      } else {
        Identifier(path~, span=self.span(start_idx), ty={ val: None })
      }
    }
    Natural(bits~, width~, base~) => {
      self.advance()
      Natural(bits~, width~, base~, span=self.span(start_idx), ty={ val: None })
    }
    StringLiteral(str) => {
      self.advance()
      String(value=str, span=self.span(start_idx), ty={ val: None })
    }
    Not => {
      self.advance()
      let expr = self.parse_expr!()
      Unary(op=Not, expr~, span=self.span(start_idx), ty={ val: None })
    }
    Lparen => self.parse_tuple_or_paren_expr!()
    Lbracket => self.parse_vector_expr!()
    Lbrace => self.parse_struct_or_concat_or_block_expr!()
    Match => self.parse_match_expr!()
    If => self.parse_if_expr!()
    Dollar => self.parse_function_call_expr!()
    _ => raise ExpectedExpr(received=token, span=self.span(start_idx))
  }
}

fn parse_function_call_expr(self: Parser) -> Expr! {
  let start_idx = self.index
  self.expect!(Dollar, start_idx)
  let name = self.parse_identifier!()
  let args = []
  self.expect!(Lparen, start_idx)

  while not(self.matches(Rparen)) {
    let arg = self.parse_expr!()
    args.push(arg)

    if not(self.consumes(Comma)) {
      break
    }
  }

  self.expect!(Rparen, start_idx)

  FunCall(name="$\{name}", args~, span=self.span(start_idx), ty={ val: None })
}

fn parse_replication_expr(self: Parser) -> Expr! {
  let start_idx = self.index
  let lhs = self.parse_primary_expr!()

  if self.consumes(X) {
    let mut concat = true

    if not(self.consumes(Lbrace)) {
      concat = false
      self.expect!(Lbracket, start_idx) 
    }

    let expr = self.parse_expr!()
    self.expect!(if concat { Rbrace } else { Rbracket }, start_idx)

    Replicate(expr~, count=lhs, concat~, span=self.span(start_idx), ty={ val: None })
  } else {
    lhs
  }
} 

fn parse_tuple_or_paren_expr(self: Parser) -> Expr! {
  let start_idx = self.index
  self.expect!(Lparen, start_idx)
  let elems = []

  while not(self.matches(Rparen)) {
    let elem = self.parse_expr!()
    elems.push(elem)

    if not(self.consumes(Comma)) {
      break
    }
  }

  self.expect!(Rparen, start_idx)

  if elems.length() == 1 {
    elems[0]
  } else {
    Tuple(elems~, span=self.span(start_idx), ty={ val: None })
  }
}

fn parse_concat_expr(self: Parser, first_expr: Expr, start_idx~: Int) -> Expr! {
  let elems = [first_expr]

  if self.consumes(Comma) {
    while not(self.matches(Rbrace)) {
      let expr = self.parse_expr!()
      elems.push(expr)

      if not(self.consumes(Comma)) {
        break
      }
    }
  }

  self.expect!(Rbrace, start_idx)

  Concat(elems~, span=self.span(start_idx), ty={ val: None })
}

fn parse_struct_or_concat_or_block_expr(self: Parser) -> Expr! {
  let start_idx = self.index
  self.expect!(Lbrace, start_idx)

  if self.consumes(Rbrace) {
    return Vector(elems=[], span=self.span(start_idx), ty={ val: None })
  }

  // first try to parse a block expr containing at least one stmt
  // singleton concat expressions are equivalent to blocks containing a single expr
  let backtracking_index = self.index

  match self.parse_stmt?() {
    Ok(stmt) => {
      let body = [stmt]

      while not(self.matches(Rbrace)) {
        let stmt = self.parse_stmt!()
        body.push(stmt)
      }

      self.expect!(Rbrace, start_idx)

      let last = match body.last() {
        Some(Stmt::Expr(expr~, span=_)) => {
          let _ = body.unsafe_pop()
          Some(expr)
        }
        _ => None
      }

      Block(body~, last~, span=self.span(start_idx), ty={ val: None })
    }
    Err(_) => {
      // if we failed to parse a block, backtrack and try to parse a struct or concat expression
      self.index = backtracking_index

      match self.parse_expr!() {
        Identifier(path={ packages: [], member }, ..) as first_expr => {
          if self.consumes(Colon) {
            let fields = {}
            fields[member] = self.parse_expr!()
            
            if self.consumes(Comma) {
              while not(self.matches(Rbrace)) {
                let name = self.parse_identifier!()
                self.expect!(Colon, start_idx)
                let expr = self.parse_expr!()
              
                if fields.contains(name) {
                  raise DuplicateStructField(name~, span=self.span(start_idx))
                }

                fields[name] = expr

                if not(self.consumes(Comma)) {
                  break
                }
              }
            }

            self.expect!(Rbrace, start_idx)

            Struct(fields~, span=self.span(start_idx), ty={ val: None })
          } else {
            self.parse_concat_expr!(first_expr, start_idx~)
          }
        }
        first_expr => self.parse_concat_expr!(first_expr, start_idx~)
      }
    }
  }
}

fn parse_vector_expr(self: Parser) -> Expr! {
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

fn parse_instance_expr(self: Parser, path~: Path) -> Expr! {
  let start_idx = self.index
  let params = self.parse_module_parameters!(fn(sub_parser) {
    let start_idx = sub_parser.index

    match sub_parser.parse_identifier?() {
      Ok(name) => {
        if sub_parser.consumes(Colon) {
          let param = sub_parser.parse_expr!()
          { name: Some(name), value: param }
        } else {
          let param = Expr::Identifier(path=Path::new([], name), span=sub_parser.span(start_idx), ty={ val: None })
          { name: None, value: param }
        }
      }
      _ => {
        { name: None, value: sub_parser.parse_expr!() }
      }
    }
  })

  self.expect!(Lparen, start_idx)
  let ports = {}

  while not(self.matches(Rparen)) {
    let start_idx = self.index
    let name = self.parse_identifier!()
    
    if self.consumes(Colon) {
      ports[name] = self.parse_expr!()
    } else {
      ports[name] = Identifier(path=Path::new([], name), span=self.span(start_idx), ty={ val: None })
    }

    if not(self.consumes(Comma)) {
      break
    }
  }

  self.expect!(Rparen, start_idx)

  Instance(
    path~,
    params=InstanceParams(params),
    ports~,
    span=self.span(start_idx),
    ty={ val: None },
  )
}

fn parse_expr(self: Parser) -> Expr! {
  self.precedence_climbing!(0)
}

fn parse_assignment_stmt(self: Parser) -> Stmt! {
  let start_idx = self.index
  let lhs = self.parse_indexing_expr!()

  if self.consumes(Equal) {
    let rhs = self.parse_expr!()
    self.expect!(Semicolon, self.index)
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

fn parse_block(self: Parser) -> Array[Stmt]! {
  self.expect!(Lbrace, self.index)
  let stmts = []

  while self.peek() != Rbrace {
    stmts.push(self.parse_stmt!())
  }

  self.expect!(Rbrace, self.index)

  stmts
}

fn parse_stmt(self: Parser) -> Stmt! {
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
    Const => Stmt::Const(decl=self.parse_const_decl!(), span=self.span(start_idx))
    _ => {
      self.parse_assignment_stmt!()
    }
  }
}

fn parse_const_decl(self: Parser) -> ConstDecl! {
  let start_idx = self.index
  self.expect!(Const, start_idx)
  let name = self.parse_identifier!()

  let ty = if self.matches(Colon) {
    self.advance()
    Some(self.parse_type!())
  } else {
    None
  }
  
  self.expect!(Equal, start_idx)
  let expr = self.parse_expr!()
  self.expect!(Semicolon, start_idx)

  { path: Path::new([], name), ty, expr, span: self.span(start_idx) }
}

fn parse_package_decl(self: Parser) -> PackageDecl! {
  let start_idx = self.index
  self.expect!(Package, start_idx)
  let name = self.parse_identifier!()
  let body = []

  self.expect!(Lbrace, start_idx)

  while not(self.consumes(Rbrace)) {
    let decl = self.parse_decl!()
    body.push(decl)
  }

  { name, body, span: self.span(start_idx) }
}

fn parse_import_decl(self: Parser) -> ImportDecl! {
  let start_idx = self.index
  self.expect!(Import, start_idx)
  let packages = [self.parse_identifier!()]

  while self.consumes(ColonColon) {
    packages.push(self.parse_identifier!())
  }

  { packages, span: self.span(start_idx) }
}

fn parse_path(self: Parser, first: String) -> Path! {
  let packages = [first]

  while self.consumes(ColonColon) {
    let name = self.parse_identifier!()
    packages.push(name)
  }

  let member = packages.unsafe_pop()

  Path::new(packages, member)
}

fn parse_type(self: Parser) -> Type! {
  let start_idx = self.index
  let params: Array[Param] = []

  let mut base_ty = match self.peek() {
    Logic => {
      self.advance()
      Type::Logic
    }
    Identifier(name) => {
      self.advance()
      let path = parse_path!(self, name)
      Type::Name(path~, params=[])
    }
    Lparen => {
      self.advance()
      let elems = []

      while not(self.matches(Rparen)) {
        let elem = self.parse_type!()
        elems.push(elem)

        if not(self.consumes(Comma)) {
          break
        }
      }

      self.expect!(Rparen, start_idx)

      match elems {
        [elem] => elem
        _ => {
          let fields = Map::new(capacity=elems.length())

          for idx, elem in elems {
            fields[idx.to_string()] = elem
          }

          Struct(fields)
        }
      }
    }
    Lbrace => {
      self.advance()
      let fields = {}

      while not(self.matches(Rbrace)) {
        let name = self.parse_identifier!()
        self.expect!(Colon, start_idx)
        let ty = self.parse_type!()
        
        if fields.contains(name) {
          raise DuplicateStructField(name~, span=self.span(start_idx))
        }

        fields[name] = ty

        if not(self.consumes(Comma)) {
          break
        }
      }

      self.expect!(Rbrace, start_idx)

      Struct(fields)
    }
    _ => raise ExpectedType(received=self.peek(), span=self.span(start_idx))
  }

  if self.consumes(Lchevron) {
    while not(self.matches(Rchevron)) {
      params.push(self.parse_expr!().as_param!())

      if not(self.consumes(Comma)) {
        break
      }
    }

    self.expect!(Rchevron, start_idx)

    base_ty = match base_ty {
      Type::Name(path~, params=_) => Type::Name(path~, params~)
      _ => raise ExpectedType(received=self.peek(), span=self.span(start_idx))
    }
  }

  while self.consumes(Lbracket) {
    let expr = self.parse_expr!()

    let len = match expr {
      Natural(bits~, width=_, ..) => VectorLen::Fixed(bits.as_int!())
      _ => Dynamic(expr)
    }

    self.expect!(Rbracket, start_idx)
    base_ty = Vector(ty=base_ty, len~)
  }

  base_ty
}

fn parse_port(self: Parser, dir~: PortDirection) -> Port! {
  let start_idx = self.index
  let name = self.parse_identifier!()
  let optional = self.consumes(QuestionMark)
  self.expect!(Colon, start_idx)
  let attributes1 = self.parse_attributes!()
  let ty = self.parse_type!()
  let attributes2 = self.parse_attributes!()
  let attributes = @utils.merge(attributes1, attributes2)
  let dir = match attributes["inout"] {
    Some(_) => Inout
    None => dir
  }

  { name, ty, direction: dir, optional, attributes, span: self.span(start_idx) }
}

fn parse_port_list(self: Parser, dir~: PortDirection) -> Array[Port]! {
  let start_idx = self.index
  let ports = []

  self.expect!(Lparen, start_idx)

  while not(self.matches(Rparen)) {
    let port = self.parse_port!(dir~)
    ports.push(port)

    if not(self.consumes(Comma)) {
      break
    }
  }

  self.expect!(Rparen, start_idx)

  ports
}

fn parse_module_parameters[T](self: Parser, parse_elem: (Parser) -> T!) -> Array[T]! {
  if self.consumes(Lchevron) {
    let start_idx = self.index
    let params = []

    // Parsing parameter lists can be ambiguous. For example, `$dff<N, 1>(` will attempt to parse `1>(` as a comparison operator.
    // To handle this, we create a sub-parser to parse tokens inside the parameter list only, such as `N, 1`.
    // Note that this implies that `>` cannot appear within the parameter list.
    let sub_parser = {
      let tokens = []

      for i in self.index..<self.tokens.length() {
        let token = self.tokens[i]

        if token.kind == Rchevron {
          break
        } else {
          tokens.push(token)
        }
      }

      Parser::new(tokens, file=self.file)
    }

    while sub_parser.index < sub_parser.tokens.length() {
      let param = parse_elem!(sub_parser)
      params.push(param)

      if not(sub_parser.consumes(Comma)) {
        break
      }
    }

    self.index += sub_parser.tokens.length()
    self.expect!(Rchevron, start_idx)
    params
  } else {
    []
  }
}

fn parse_attribute_value(self: Parser) -> AttributeValue! {
  let token = self.peek()
  let start_idx = self.index

  match token {
    StringLiteral(str) => {
      self.advance()
      AttributeValue::String(str)
    }
    Natural(bits~, ..) => {
      self.advance()
      AttributeValue::Int(bits.as_int!())
    }
    _ => raise ExpectedExpr(received=token, span=self.span(start_idx))
  }
}

fn parse_attribute(self: Parser) -> Attribute! {
  let start_idx = self.index
  self.expect!(At, start_idx)
  let name = self.parse_identifier!()

  let args = if self.consumes(Lparen) {
    let args = []

    while not(self.matches(Rparen)) {
      let val = self.parse_attribute_value!()
      args.push(val)

      if not(self.consumes(Comma)) {
        break
      }
    }

    self.expect!(Rparen, start_idx)

    args
  } else {
    []
  }

  { name, args, span: self.span(start_idx) }
}

fn parse_attributes(self: Parser) -> Map[String, Attribute]! {
  let attrs = {}

  while self.matches(At) {
    let attr = self.parse_attribute!()
    attrs[attr.name] = attr
  }

  attrs
}

fn parse_module_signature(self: Parser, attributes~: Map[String, Attribute]) -> ModuleSignature! {
  let start_idx = self.index
  self.expect!(Module, start_idx)
  let name = self.parse_identifier!()
  let params = self.parse_module_parameters!(Parser::parse_identifier)
  let inputs = self.parse_port_list!(dir=Input)
  self.expect!(RightThinArrow, start_idx)
  let outputs = self.parse_port_list!(dir=Output)
  let ports = @utils.concat(inputs, outputs)

  { path: Path::new([], name), params, attributes, ports, span: self.span(start_idx) }
}

fn parse_module_definition(self: Parser, sig~: ModuleSignature) -> ModuleDecl! {
  let start_idx = self.index
  let { path, params, attributes, ports, .. } = sig
  self.expect!(Lbrace, start_idx)
  let body = []

  while not(self.consumes(Rbrace)) {
    let stmt = self.parse_stmt!()
    body.push(stmt)
  }

  { path, params, attributes, ports, body, span: self.span(start_idx) }
}

fn parse_module_def_or_decl(self: Parser) -> Decl! {
  let attributes = self.parse_attributes!()
  let is_declaration = self.consumes(Declare)
  let sig = self.parse_module_signature!(attributes~)

  if is_declaration {
    ModuleDeclaration(sig)
  } else {
    Module(self.parse_module_definition!(sig~))
  }
}

fn parse_decl(self: Parser) -> Decl! {
  match self.peek() {
    At | Declare | Module => self.parse_module_def_or_decl!()
    Const => Decl::Const(self.parse_const_decl!())
    Package => Decl::Package(self.parse_package_decl!())
    Import => Decl::Import(self.parse_import_decl!())
    token => raise ExpectedDecl(received=token, span=self.span(self.index))
  }
}

pub fn parse(self: Parser) -> Array[Decl]! {
  let decls = []

  while self.index < self.tokens.length() {
    let decl = self.parse_decl!()
    decls.push(decl)
  }

  decls
}

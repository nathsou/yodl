/// Shared by interactive clients and documentation snapshots.
fn Workspace::hover(self: Self, uri: String, index: Int) -> Json {
  let workspace = self
  let file = self.files[uri]
  if self.reference_at(uri, index) is Some(reference) {
    let symbol = self.symbols[reference.symbol]
    return Json::object({ "contents": Json::object({ "kind": "markdown".to_json(), "value": "```yodl\n\{symbol.detail}\n```".to_json() }), "range": reference.span.range_json() })
  }
  for token in file.tokens {
    if token.span.start.index <= index && index <= token.span.end.index {
      if token.kind is @parse.TokenType::BuiltinFunction(name) {
        if builtin_functions().iter().find_first(b => b.0 == name) is Some(builtin) {
          return Json::object({ "contents": Json::object({ "kind": "markdown".to_json(), "value": "```yodl\n\{builtin.1}\n```".to_json() }), "range": token.span.range_json() })
        }
      }
      if workspace.expression_types.get(span_key(token.span)) is Some(ty) {
        return Json::object({ "contents": Json::object({ "kind": "markdown".to_json(), "value": "```yodl\n\{ty}\n```".to_json() }), "range": token.span.range_json() })
      }
    }
  }
  Json::null()
}

/// Static clients capture the same hovers, diagnostics and semantic tokens once.
fn Server::snapshot(self: Self, uri: String) -> Json raise ProtocolError {
  guard self.source(uri) is Some(_) else { raise ProtocolError(code=-32602, message="Unknown document '\{uri}'") }
  let _ = self.analyze(uri)
  let workspace = self.index()
  let hovers = []
  let seen = Set([])
  for token in workspace.files[uri].tokens {
    let hover = workspace.hover(uri, token.span.start.index)
    let key = field(hover, "range").stringify()
    if hover != Json::null() && !seen.contains(key) { hovers.push(hover); seen.add(key) }
  }
  Json::object({
    "hovers": Json::array(hovers),
    "diagnostics": Json::array(self.enriched_diagnostics(uri).map(d => d.to_json())),
    "semanticTokens": workspace.semantic_tokens(uri),
  })
}

fn token_types() -> Array[String] {
  ["namespace", "type", "class", "parameter", "variable", "property", "function", "keyword", "number", "string", "operator"]
}

fn builtin_functions() -> Array[(String, String, Array[String])] {
  [
    ("clog2", "clog2!(value: Nat) -> Nat", ["value: Nat"]),
    ("cdiv", "cdiv!(dividend: Nat, divisor: Nat) -> Nat", ["dividend: Nat", "divisor: Nat"]),
    ("pow", "pow!(base: Nat, exponent: Nat) -> Nat", ["base: Nat", "exponent: Nat"]),
    ("csqrt", "csqrt!(value: Nat) -> Nat", ["value: Nat"]),
    ("cat", "cat!(values...) -> uint", ["values..."]),
    ("uint", "uint!(value: sint) -> uint", ["value: sint"]),
    ("sint", "sint!(value: uint) -> sint", ["value: uint"]),
    ("flip", "flip!(value: uint) -> uint", ["value: uint"]),
    ("clock", "clock!(value: bool) -> clock", ["value: bool"]),
    ("pad", "pad!(value: uint, width: Nat) -> uint", ["value: uint", "width: Nat"]),
    ("fill", "fill!(count: Nat, value) -> vector", ["count: Nat", "value"]),
    ("stop", "stop!(code: Nat)", ["code: Nat"]),
    ("rev", "rev!(vector) -> vector", ["vector"]),
    ("printf", "printf!(format: str, values...)", ["format: str", "values..."]),
    ("assert", "assert!(condition: bool)", ["condition: bool"]),
    ("readmemh", "readmemh!(path: str, memory)", ["path: str", "memory"]),
    ("readmemb", "readmemb!(path: str, memory)", ["path: str", "memory"]),
    ("drive", "drive!(port, value)", ["port", "value"]),
    ("expect", "expect!(port, value)", ["port", "value"]),
    ("step", "step!(clock: clock, cycles: Nat)", ["clock: clock", "cycles: Nat"]),
    ("settle", "settle!()", []),
    ("peek", "peek!(port) -> uint", ["port"]),
  ]
}

fn Workspace::visible(self: Self, scope: Int, index: Int) -> Array[Int] {
  let names = Set([])
  let result = []
  let mut current = Some(scope)
  while current is Some(scope) {
    for id in self.scopes[scope].symbols.rev() {
      let symbol = self.symbols[id]
      if (symbol.kind == 13 || symbol.kind == 14) && symbol.selection.start.index > index { continue }
      if !names.contains(symbol.name) { names.add(symbol.name); result.push(id) }
    }
    current = self.scopes[scope].parent
  }
  if self.files.get(builtin_uri) is Some(file) {
    for id in self.scopes[file.scope].symbols {
      if !names.contains(self.symbols[id].name) { names.add(self.symbols[id].name); result.push(id) }
    }
  }
  result
}

fn Workspace::symbol_json(self: Self, id: Int) -> Json {
  let symbol = self.symbols[id]
  let children = []
  for child, candidate in self.symbols {
    if candidate.container == Some(id) { children.push(self.symbol_json(child)) }
  }
  Json::object({ "name": symbol.name.to_json(), "detail": symbol.detail.to_json(), "kind": symbol.kind.to_json(), "range": symbol.span.range_json(), "selectionRange": symbol.selection.range_json(), "children": Json::array(children) })
}

fn completion_kind(kind: Int) -> Int {
  match kind { 2 | 3 => 9; 8 => 5; 12 => 3; 14 => 21; 23 => 22; 26 => 25; _ => 6 }
}

fn Workspace::completion(self: Self, uri: String, index: Int) -> Json {
  let file = self.files[uri]
  let mut start = index
  let mut end = index
  while start > 0 && @utils.is_alphanumeric(@utils.char_at(file.source, start - 1)) { start -= 1 }
  while end < file.source.length() && @utils.is_alphanumeric(@utils.char_at(file.source, end)) { end += 1 }
  let prefix = file.source[start:index].to_owned()
  let replacement = @parse.Span::at(uri, file.source[:], start, end).range_json()
  let mut before = None
  for i, token in file.tokens {
    if token.span.end.index <= start && token.kind != @parse.TokenType::Semicolon { before = Some(i) }
  }
  let mut members = false
  let argument = before.bind(i => if file.tokens[i].kind == @parse.TokenType::Lparen || file.tokens[i].kind == @parse.TokenType::Lbracket || file.tokens[i].kind == @parse.TokenType::Comma { self.argument_target(uri, i + 1) } else { None })
  let candidates = if argument is Some((id, generic)) && self.symbols[id].signature is Some(_) {
    members = true
    self.symbols[id].child_scope.map(scope => self.scopes[scope].symbols.filter(id => if generic { self.symbols[id].kind == 26 } else { self.symbols[id].member })).unwrap_or([])
  } else if before is Some(before) && before > 0 && (file.tokens[before].kind == @parse.TokenType::Dot || file.tokens[before].kind == @parse.TokenType::ColonColon) {
    members = true
    self.resolve_token(uri, before - 1).bind(id => self.member_scope(id)).map(scope => self.scopes[scope].symbols.filter(id => self.symbols[id].member || file.tokens[before].kind == @parse.TokenType::ColonColon)).unwrap_or([])
  } else {
    self.scope_at(uri, index).map(scope => self.visible(scope, index)).unwrap_or([])
  }
  let items = []
  for id in candidates {
    let symbol = self.symbols[id]
    if !symbol.name.has_prefix(prefix) { continue }
    items.push(Json::object({ "label": symbol.name.to_json(), "kind": completion_kind(symbol.kind).to_json(), "detail": symbol.detail.to_json(), "textEdit": Json::object({ "range": replacement, "newText": symbol.name.to_json() }) }))
  }
  if !members {
    for word in ["module", "declare", "let", "const", "import", "package", "type", "for", "in", "if", "else", "match", "test", "u8", "u16", "u32", "s8", "s16", "s32", "bool", "clock", "Nat", "Type"] {
      if word.has_prefix(prefix) { items.push(Json::object({ "label": word.to_json(), "kind": (14).to_json(), "textEdit": Json::object({ "range": replacement, "newText": word.to_json() }) })) }
    }
    for builtin in builtin_functions() {
      if builtin.0.has_prefix(prefix) {
        items.push(Json::object({ "label": "\{builtin.0}!".to_json(), "kind": (3).to_json(), "detail": builtin.1.to_json(), "textEdit": Json::object({ "range": replacement, "newText": "\{builtin.0}!".to_json() }) }))
      }
    }
  }
  Json::object({ "isIncomplete": false.to_json(), "items": Json::array(items) })
}

fn Workspace::signature_help(self: Self, uri: String, index: Int) -> Json {
  let file = self.files[uri]
  let stack = []
  for i, token in file.tokens {
    if token.span.start.index >= index { break }
    match token.kind {
      @parse.TokenType::Lparen | @parse.TokenType::Lbracket => stack.push(i)
      @parse.TokenType::Rparen | @parse.TokenType::Rbracket => if !stack.is_empty() { let _ = stack.pop() }
      _ => ()
    }
  }
  guard stack.last() is Some(open) && open > 0 else { return Json::null() }
  let generic = file.tokens[open].kind == @parse.TokenType::Lbracket
  let mut target = open - 1
  if file.tokens[target].kind == @parse.TokenType::Rbracket {
    let mut depth = 1
    while target > 0 && depth > 0 {
      target -= 1
      if file.tokens[target].kind == @parse.TokenType::Rbracket { depth += 1 }
      if file.tokens[target].kind == @parse.TokenType::Lbracket { depth -= 1 }
    }
    if target == 0 { return Json::null() }
    target -= 1
  }
  let mut active = 0
  let mut depth = 0
  let mut argument_start = open + 1
  for i in (open + 1)..<file.tokens.length() {
    let token = file.tokens[i]
    if token.span.start.index >= index { break }
    match token.kind {
      @parse.TokenType::Lparen | @parse.TokenType::Lbracket | @parse.TokenType::Lbrace => depth += 1
      @parse.TokenType::Rparen | @parse.TokenType::Rbracket | @parse.TokenType::Rbrace => depth -= 1
      @parse.TokenType::Comma if depth == 0 => { active += 1; argument_start = i + 1 }
      _ => ()
    }
  }
  let (label, parameters) = match self.resolve_token(uri, target).bind(id => self.symbols[id].signature) {
    Some(signature) => (signature.label, if generic { signature.parameters } else { signature.inputs })
    None => match file.tokens[target].kind {
      @parse.TokenType::BuiltinFunction(name) => match builtin_functions().iter().find_first(b => b.0 == name) {
        Some(builtin) => (builtin.1, builtin.2.map(label => (label.split(":").next().unwrap_or("").to_owned(), label)))
        None => return Json::null()
      }
      _ => return Json::null()
    }
  }
  if argument_start + 1 < file.tokens.length() && file.tokens[argument_start + 1].kind == @parse.TokenType::Colon {
    if file.tokens[argument_start].kind is @parse.TokenType::Identifier(name) {
      for i, parameter in parameters { if parameter.0 == name { active = i } }
    }
  }
  let signature = Json::object({ "label": label.to_json(), "parameters": Json::array(parameters.map(p => Json::object({ "label": p.1.to_json() }))) })
  Json::object({ "signatures": Json::array([signature]), "activeSignature": (0).to_json(), "activeParameter": @utils.min(active, @utils.max(0, parameters.length() - 1)).to_json() })
}

fn Workspace::semantic_tokens(self: Self, uri: String) -> Json {
  let file = self.files[uri]
  let data = []
  let mut previous_line = 0
  let mut previous_column = 0
  for i, token in file.tokens {
    let mut modifiers = 0
    let token_type = if self.resolve_token(uri, i) is Some(id) {
      let symbol = self.symbols[id]
      if self.definitions.contains(position_key(uri, token.span.start.index)) { modifiers = modifiers | 1 }
      if symbol.read_only { modifiers = modifiers | 2 }
      Some(symbol.token_type)
    } else {
      match token.kind {
        @parse.TokenType::Natural(..) | @parse.TokenType::CharacterLiteral(_) => Some(8)
        @parse.TokenType::StringLiteral(_) => Some(9)
        @parse.TokenType::BuiltinFunction(_) => Some(6)
        @parse.TokenType::UIntType(_) | @parse.TokenType::SIntType(_) | @parse.TokenType::UInt | @parse.TokenType::SInt | @parse.TokenType::Bool | @parse.TokenType::Clock => Some(1)
        @parse.TokenType::Identifier(_) | @parse.TokenType::Semicolon | @parse.TokenType::Eof | @parse.TokenType::Lparen | @parse.TokenType::Rparen | @parse.TokenType::Lbrace | @parse.TokenType::Rbrace | @parse.TokenType::Lbracket | @parse.TokenType::Rbracket | @parse.TokenType::Comma => None
        @parse.TokenType::Module | @parse.TokenType::Declare | @parse.TokenType::Let | @parse.TokenType::Const | @parse.TokenType::Import | @parse.TokenType::Package | @parse.TokenType::Type | @parse.TokenType::Test | @parse.TokenType::For | @parse.TokenType::In | @parse.TokenType::If | @parse.TokenType::Else | @parse.TokenType::Match => Some(7)
        _ => Some(10)
      }
    }
    guard token_type is Some(token_type) else { continue }
    let mut start = token.span.start.index
    let mut line = token.span.start.line - 1
    let mut column = token.span.start.column - 1
    while start < token.span.end.index {
      let mut end = start
      while end < token.span.end.index && file.source.code_unit_at(end) != '\n' && file.source.code_unit_at(end) != '\r' { end += 1 }
      if end > start {
        data.push(line - previous_line)
        data.push(if line == previous_line { column - previous_column } else { column })
        data.push(end - start); data.push(token_type); data.push(modifiers)
        previous_line = line; previous_column = column
      }
      if end < token.span.end.index && file.source.code_unit_at(end) == '\r' && end + 1 < token.span.end.index && file.source.code_unit_at(end + 1) == '\n' { end += 1 }
      start = end + 1
      line += 1; column = 0
    }
  }
  Json::object({ "data": data.to_json() })
}

fn Workspace::folding_ranges(self: Self, uri: String) -> Json {
  let stack = []
  let ranges = []
  for token in self.files[uri].tokens {
    match token.kind {
      @parse.TokenType::Lbrace | @parse.TokenType::Lparen | @parse.TokenType::Lbracket => stack.push(token)
      @parse.TokenType::Rbrace | @parse.TokenType::Rparen | @parse.TokenType::Rbracket => {
        if stack.pop() is Some(open) && open.span.start.line < token.span.start.line {
          ranges.push(Json::object({ "startLine": (open.span.start.line - 1).to_json(), "endLine": (token.span.start.line - 1).to_json(), "kind": "region".to_json() }))
        }
      }
      _ => ()
    }
  }
  Json::array(ranges)
}

fn Server::query(self: Self, method: String, params: Json) -> Json raise {
  if method == "workspace/symbol" {
    let workspace = self.index()
    let query = required_string(params, "query").to_lower()
    let result = []
    for symbol in workspace.symbols {
      if symbol.selection.file != builtin_uri && symbol.qualified.to_lower().contains(query) {
        result.push(Json::object({ "name": symbol.name.to_json(), "kind": symbol.kind.to_json(), "location": location(symbol.selection), "containerName": symbol.container.map(id => workspace.symbols[id].qualified).unwrap_or(@utils.file_name(symbol.selection.file)).to_json() }))
      }
    }
    return Json::array(result)
  }
  if method == "yodl/source" && field(params, "uri") == builtin_uri.to_json() { return @simplify.builtin_source().to_json() }
  let supported = ["textDocument/hover", "textDocument/definition", "textDocument/declaration", "textDocument/typeDefinition", "textDocument/references", "textDocument/documentHighlight", "textDocument/documentSymbol", "textDocument/completion", "textDocument/signatureHelp", "textDocument/prepareRename", "textDocument/rename", "textDocument/codeAction", "textDocument/semanticTokens/full", "textDocument/foldingRange", "textDocument/selectionRange"]
  if !supported.contains(method) { raise ProtocolError(code=-32601, message="Unsupported method '\{method}'") }
  let uri = required_string(field(params, "textDocument"), "uri")
  let workspace = self.index()
  guard workspace.files.get(uri) is Some(file) else { raise ProtocolError(code=-32602, message="Unknown document '\{uri}'") }
  match method {
    "textDocument/documentSymbol" => {
      let symbols = []
      for id, symbol in workspace.symbols {
        if symbol.selection.file == uri && symbol.container is None { symbols.push(workspace.symbol_json(id)) }
      }
      return Json::array(symbols)
    }
    "textDocument/semanticTokens/full" => return workspace.semantic_tokens(uri)
    "textDocument/foldingRange" => return workspace.folding_ranges(uri)
    "textDocument/selectionRange" => {
      let results = []
      for position in array(field(params, "positions")) {
        let index = offset(file.source, position)
        let spans = []
        for token in file.tokens {
          if token.span.start.index <= index && index < token.span.end.index { spans.push(token.span); break }
        }
        let mut scope = workspace.scope_at(uri, index)
        while scope is Some(id) { spans.push(workspace.scopes[id].span); scope = workspace.scopes[id].parent }
        let mut parent = Json::null()
        for span in spans.rev() {
          let value: Map[String, Json] = { "range": span.range_json() }
          if parent != Json::null() { value["parent"] = parent }
          parent = Json::object(value)
        }
        results.push(parent)
      }
      return Json::array(results)
    }
    "textDocument/codeAction" => return self.code_actions(uri, params)
    _ => ()
  }
  let index = offset(file.source, field(params, "position"))
  if method == "textDocument/hover" { return workspace.hover(uri, index) }
  if method == "textDocument/completion" { return workspace.completion(uri, index) }
  if method == "textDocument/signatureHelp" { return workspace.signature_help(uri, index) }
  guard workspace.reference_at(uri, index) is Some(reference) else {
    return if method == "textDocument/references" || method == "textDocument/documentHighlight" { Json::array([]) } else { Json::null() }
  }
  let symbol = workspace.symbols[reference.symbol]
  match method {
    "textDocument/definition" | "textDocument/declaration" => Json::array([location(symbol.selection)])
    "textDocument/typeDefinition" => {
      let target = symbol.instance.bind(path => workspace.lookup_path(symbol.scope, path, symbol.selection.start.index))
      let target = prefer(target, match symbol.ty {
        Some(@parse.Type::Name(path~, ..)) => workspace.lookup_path(symbol.scope, path, symbol.selection.start.index)
        _ => None
      })
      Json::array(target.map(id => [location(workspace.symbols[id].selection)]).unwrap_or([]))
    }
    "textDocument/references" => {
      let include_declaration = field(field(params, "context"), "includeDeclaration") == true.to_json()
      Json::array(workspace.references.filter(r => r.symbol == reference.symbol && (include_declaration || !r.declaration)).map(r => location(r.span)))
    }
    "textDocument/documentHighlight" => Json::array(workspace.references.filter(r => r.symbol == reference.symbol && r.span.file == uri).map(r => Json::object({ "range": r.span.range_json(), "kind": (1).to_json() })))
    "textDocument/prepareRename" => {
      if !symbol.renameable { raise ProtocolError(code=-32602, message="This symbol cannot be renamed") }
      Json::object({ "range": reference.span.range_json(), "placeholder": symbol.name.to_json() })
    }
    "textDocument/rename" => {
      if !symbol.renameable { raise ProtocolError(code=-32602, message="This symbol cannot be renamed") }
      let name = required_string(params, "newName")
      let tokens = try @parse.Lexer::new(name, file="rename", file_content=name).lex() catch { _ => raise ProtocolError(code=-32602, message="The new name must be a Yodl identifier") }
      if tokens.length() != 2 || !(tokens[0].kind is @parse.TokenType::Identifier(_)) || tokens[0].span.text().to_owned() != name { raise ProtocolError(code=-32602, message="The new name must be a Yodl identifier, not a keyword or a type") }
      for id in workspace.scopes[symbol.scope].symbols {
        if id != reference.symbol && workspace.symbols[id].name == name { raise ProtocolError(code=-32602, message="'\{name}' is already declared in this scope") }
      }
      let changes: Map[String, Json] = Map([])
      let by_uri: Map[String, Array[Json]] = Map([])
      for r in workspace.references {
        if r.symbol != reference.symbol { continue }
        if !symbol.member {
          if workspace.scope_at(r.span.file, r.span.start.index).bind(scope => workspace.lookup(scope, name, r.span.start.index)) is Some(other) && other != reference.symbol {
            raise ProtocolError(code=-32602, message="Renaming to '\{name}' would capture another declaration")
          }
        }
        by_uri.get_or_init(r.span.file, () => []).push(Json::object({ "range": r.span.range_json(), "newText": name.to_json() }))
      }
      for uri, edits in by_uri { changes[uri] = Json::array(edits) }
      Json::object({ "changes": Json::object(changes) })
    }
    _ => Json::null()
  }
}

fn Server::code_actions(self: Self, uri: String, params: Json) -> Json {
  let actions = []
  let range = field(params, "range")
  for diagnostic in self.enriched_diagnostics(uri) {
    if diagnostic.span is Some(span) && span.file == uri {
      let start_line = integer(field(field(range, "start"), "line")).unwrap_or(0)
      let end_line = integer(field(field(range, "end"), "line")).unwrap_or(start_line)
      if span.end.line - 1 < start_line || span.start.line - 1 > end_line { continue }
      for fix in diagnostic.fixes {
        let edit = Json::object({ "range": fix.span.range_json(), "newText": fix.replacement.to_json() })
        let changes = Json::object(Map([(fix.span.file, Json::array([edit]))]))
        actions.push(Json::object({
          "title": fix.title.to_json(), "kind": "quickfix".to_json(),
          "diagnostics": Json::array([diagnostic.to_json()]), "isPreferred": true.to_json(),
          "edit": Json::object({ "changes": changes }),
        }))
      }
    }
  }
  Json::array(actions)
}

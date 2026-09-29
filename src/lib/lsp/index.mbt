using @parse { type Decl, type Expr, type Stmt, type Type, type Token, type Path }

let builtin_uri = "yodl-builtin:///builtin.yodl"

priv struct FileIndex {
  source: String
  tokens: Array[Token]
  decls: Array[Decl]
  scope: Int
}

priv struct LexicalScope {
  span: Span
  parent: Int?
  symbols: Array[Int]
}

priv struct Signature {
  label: String
  inputs: Array[(String, String)]
  parameters: Array[(String, String)]
}

priv struct Symbol {
  name: String
  qualified: String
  kind: Int
  token_type: Int
  selection: Span
  span: Span
  scope: Int
  container: Int?
  mut child_scope: Int?
  detail: String
  ty: Type?
  instance: Path?
  signature: Signature?
  member: Bool
  read_only: Bool
  renameable: Bool
}

priv struct Reference {
  symbol: Int
  span: Span
  declaration: Bool
}

struct Workspace {
  files: Map[String, FileIndex]
  scopes: Array[LexicalScope]
  symbols: Array[Symbol]
  definitions: Map[String, Int]
  references: Array[Reference]
  binding_types: Map[String, Type]
  expression_types: Map[String, String]
}

fn span_key(span: Span) -> String { "\{span.file}:\{span.start.index}:\{span.end.index}" }
fn position_key(uri: String, index: Int) -> String { "\{uri}:\{index}" }

fn visit_expr(expr: Expr, f: (Expr) -> Unit) -> Unit {
  f(expr)
  let visit = e => visit_expr(e, f)
  match expr {
    Unary(expr~, ..) | Spread(expr~, ..) | FieldAccess(expr~, ..) => visit(expr)
    Binary(lhs~, rhs~, ..) => { visit(lhs); visit(rhs) }
    Indexing(expr~, index~, ..) => { visit(expr); visit(index) }
    Slicing(expr~, hi~, lo~, ..) => { visit(expr); visit(hi); visit(lo) }
    Instance(ports~, ..) | Struct(fields=ports, ..) => for _, value in ports { visit(value) }
    Vector(elems~, ..) | FunCall(args=elems, ..) => for value in elems { visit(value) }
    Ternary(cond~, then~, else_~, ..) => { visit(cond); visit(then); visit(else_) }
    Match(subject~, cases~, default~, ..) => {
      visit(subject)
      for pair in cases { visit(pair.0); visit(pair.1) }
      if default is Some(value) { visit(value) }
    }
    Block(body~, last~, ..) => { for stmt in body { visit_stmt(stmt, f) }; if last is Some(value) { visit(value) } }
    If(cond~, then~, else_~, ..) => { visit(cond); visit(then); if else_ is Some(value) { visit(value) } }
    Natural(..) | Identifier(..) | String(..) => ()
  }
}

fn visit_stmt(stmt: Stmt, f: (Expr) -> Unit) -> Unit {
  match stmt {
    Expr(expr~, ..) | Const(decl={ expr, .. }, ..) => visit_expr(expr, f)
    Let(expr=Some(expr), ..) => visit_expr(expr, f)
    Let(expr=None, ..) => ()
    Assign(lhs~, rhs~, ..) => { visit_expr(lhs, f); visit_expr(rhs, f) }
    For(range~, body~, ..) => {
      visit_expr(range.start, f); visit_expr(range.end, f)
      for stmt in body { visit_stmt(stmt, f) }
    }
    Scope(body~, ..) => for stmt in body { visit_stmt(stmt, f) }
  }
}

fn Workspace::collect_types(self: Self, decl: Decl) -> Unit {
  let collect = fn(expr: Expr) {
    if expr.ty().val is Some(ty) { self.expression_types[span_key(@parse.Spanned::span(expr))] = ty.to_string() }
  }
  fn bindings(stmt: Stmt) -> Unit {
    match stmt {
      Let(ty~, span~, ..) => if ty.val is Some(ty) { self.binding_types[span_key(span)] = ty }
      For(body~, ..) | Scope(body~, ..) => for stmt in body { bindings(stmt) }
      _ => ()
    }
    visit_stmt(stmt, collect)
  }
  match decl {
    Module(mod) => for stmt in mod.body { bindings(stmt) }
    Test(td) => for stmt in td.body { bindings(stmt) }
    Const(decl) => collect(decl.expr)
    Package(pkg) => for decl in pkg.body { self.collect_types(decl) }
    _ => ()
  }
}

fn Server::index(self: Self) -> Workspace {
  if self.workspace is Some(workspace) { return workspace }
  let workspace: Workspace = { files: {}, scopes: [], symbols: [], definitions: {}, references: [], binding_types: {}, expression_types: {} }
  for uri, _ in self.documents {
    for decl in self.analyze(uri).typed_decls { workspace.collect_types(decl) }
  }
  let sources = self.sources()
  sources[builtin_uri] = @simplify.builtin_source()
  let uris = sources.keys().to_array()
  uris.sort()
  for uri in uris {
    if !uri.has_suffix(".yodl") && !self.documents.contains(uri) { continue }
    let source = sources[uri]
    let diagnostics = []
    let tokens = @parse.Lexer::new(source, file=uri, file_content=source).lex_recovering(diagnostics)
    let decls = @parse.Parser::new(tokens, file=uri, file_content=source).parse_recovering(diagnostics)
    let scope = workspace.add_scope(@parse.Span::at(uri, source[:], 0, source.length()), None)
    workspace.files[uri] = { source, tokens, decls, scope }
  }
  for uri in uris {
    if workspace.files.get(uri) is Some(file) {
      for decl in file.decls { workspace.index_decl(decl, file.scope, None, []) }
    }
  }
  for uri in uris {
    if workspace.files.get(uri) is Some(file) {
      for i, token in file.tokens {
        match token.kind {
          @parse.TokenType::Identifier(_) | @parse.TokenType::BuiltinFunction(_) => {
            if workspace.resolve_token(uri, i) is Some(symbol) {
              workspace.references.push({ symbol, span: token.span, declaration: workspace.definitions.contains(position_key(uri, token.span.start.index)) })
            }
          }
          _ => ()
        }
      }
    }
  }
  self.workspace = Some(workspace)
  workspace
}

fn Workspace::add_scope(self: Self, span: Span, parent: Int?) -> Int {
  let id = self.scopes.length()
  self.scopes.push({ span, parent, symbols: [] })
  id
}

fn Workspace::name_span(self: Self, span: Span, name: String) -> Span {
  if self.files.get(span.file) is Some(file) {
    for token in file.tokens {
      if token.span.start.index < span.start.index || token.span.end.index > span.end.index { continue }
      match token.kind {
        @parse.TokenType::Identifier(value) | @parse.TokenType::StringLiteral(value) if value == name => return token.span
        _ => ()
      }
    }
  }
  @parse.Span::at(span.file, span.file_content, span.start.index, span.start.index)
}

fn Workspace::add_symbol(self: Self, name: String, span: Span, scope: Int, container: Int?, namespace: Array[String], kind: Int, token_type: Int, detail: String, ty~: Type? = None, instance~: Path? = None, signature~: Signature? = None, member~: Bool = false, read_only~: Bool = false, renameable~: Bool = true) -> Int {
  let selection = self.name_span(span, name)
  let id = self.symbols.length()
  self.symbols.push({ name, qualified: (namespace + [name]).iter().join("::"), kind, token_type, selection, span, scope, container, child_scope: None, detail, ty, instance, signature, member, read_only, renameable: renameable && span.file != builtin_uri })
  self.scopes[scope].symbols.push(id)
  self.definitions[position_key(selection.file, selection.start.index)] = id
  id
}

fn Workspace::index_decl(self: Self, decl: Decl, scope: Int, container: Int?, namespace: Array[String]) -> Unit {
  match decl {
    Module(mod) => self.index_module(mod.signature(), mod.span, mod.body, scope, container, namespace)
    ModuleDeclaration(sig) => self.index_module(sig, sig.span, [], scope, container, namespace)
    Package(pkg) => {
      let id = self.add_symbol(pkg.name, pkg.span, scope, container, namespace, 3, 0, "package \{pkg.name}")
      let child = self.add_scope(pkg.span, Some(scope))
      self.symbols[id].child_scope = Some(child)
      for decl in pkg.body { self.index_decl(decl, child, Some(id), namespace + [pkg.name]) }
    }
    Import(decl) => {
      let name = decl.packages[0]
      let id = self.add_symbol(name, decl.span, scope, container, namespace, 3, 0, "import \{name}", renameable=false)
      let base = @utils.dir_name(decl.span.file) + "/"
      let uris = self.files.keys().to_array()
      uris.sort()
      for uri in uris {
        if uri.has_prefix(base) && @utils.without_extension(@utils.file_name(uri)) == name {
          self.symbols[id].child_scope = Some(self.files[uri].scope)
          break
        }
      }
    }
    Const(decl) => {
      let ty = prefer(decl.ty, self.guess_type(decl.expr))
      let _ = self.add_symbol(decl.path.elem, decl.span, scope, container, namespace, 14, 4, "const \{decl.path}: \{ty.map(t => t.to_string()).unwrap_or("unknown")}", ty~, read_only=true)
      self.index_expr(decl.expr, scope, container)
    }
    TypeAlias(alias) => {
      let id = self.add_symbol(alias.name, alias.span, scope, container, namespace, 23, 1, "type \{alias.name} = \{alias.ty}", ty=Some(alias.ty))
      let child = self.add_scope(alias.span, Some(scope))
      self.symbols[id].child_scope = Some(child)
      for param in alias.parameters {
        let _ = self.add_symbol(param.name, param.span, child, Some(id), [], 26, 3, "\{param.name}: \{param.sort}", read_only=true)
      }
      if alias.ty is @parse.Type::Struct(fields) {
        for name, ty in fields { let _ = self.add_symbol(name, alias.span, child, Some(id), [], 8, 5, "\{name}: \{ty}", ty=Some(ty), member=true) }
      }
    }
    Test(td) => {
      let id = self.add_symbol(td.name, td.span, scope, container, namespace, 12, 6, "test \{td.name}", renameable=false)
      let child = self.add_scope(td.span, Some(scope))
      self.symbols[id].child_scope = Some(child)
      if td.target is Some(target) { self.index_expr(target, child, Some(id)) }
      for stmt in td.body { self.index_stmt(stmt, child, Some(id)) }
    }
  }
}

fn Workspace::index_module(self: Self, sig: @parse.ModuleSignature, span: Span, body: Array[Stmt], scope: Int, container: Int?, namespace: Array[String]) -> Unit {
  let inputs = sig.ports.filter(p => p.dir == @parse.PortDir::Input).map(p => (p.name, "\{p.name}\{if p.optional { "?" } else { "" }}: \{p.ty}"))
  let parameters = sig.params.map(p => (p.name, "\{p.name}: \{p.sort}"))
  let outputs = sig.ports.filter(p => p.dir != @parse.PortDir::Input).map(p => "\{p.name}: \{p.ty}")
  let params_text = if parameters.is_empty() { "" } else { "[\{parameters.iter().map(p => p.1).join(", ")}]" }
  let label = "\{sig.path}\{params_text}(\{inputs.iter().map(p => p.1).join(", ")}) -> (\{outputs.iter().join(", ")})"
  let id = self.add_symbol(sig.path.elem, span, scope, container, namespace, 2, 2, "module \{label}", signature=Some({ label, inputs, parameters }))
  let child = self.add_scope(span, Some(scope))
  self.symbols[id].child_scope = Some(child)
  for param in sig.params { let _ = self.add_symbol(param.name, param.span, child, Some(id), [], 26, 3, "\{param.name}: \{param.sort}", read_only=true) }
  for port in sig.ports { let _ = self.add_symbol(port.name, port.span, child, Some(id), [], 8, 5, "\{port.dir} \{port.name}: \{port.ty}", ty=Some(port.ty), member=true) }
  for stmt in body { self.index_stmt(stmt, child, Some(id)) }
}

fn Workspace::guess_type(self: Self, expr: Expr) -> Type? {
  if expr.ty().val is Some(ty) { return Some(ty) }
  match expr {
    Natural(value~, width~, ..) => Some(@parse.Type::uint(width.unwrap_or(@utils.max(1, @utils.significant_bits(value)))))
    String(value~, ..) => Some(@parse.Type::String(len=value.length()))
    Struct(fields~, ..) => {
      let types = Map([])
      for name, expr in fields { if self.guess_type(expr) is Some(ty) { types[name] = ty } }
      Some(@parse.Type::Struct(types))
    }
    _ => None
  }
}

fn Workspace::index_stmt(self: Self, stmt: Stmt, scope: Int, container: Int?) -> Unit {
  match stmt {
    Let(name~, ty~, expr~, span~) => {
      let resolved = prefer(self.binding_types.get(span_key(span)), prefer(ty.val, expr.bind(e => self.guess_type(e))))
      let instance = expr.bind(e => match e { Instance(path~, ..) => Some(path); _ => None })
      let detail = "let \{name}: \{resolved.map(t => t.to_string()).unwrap_or(instance.map(p => p.to_string()).unwrap_or("unknown"))}"
      let _ = self.add_symbol(name, span, scope, container, [], 13, 4, detail, ty=prefer(ty.val, resolved), instance~)
      if expr is Some(expr) { self.index_expr(expr, scope, container) }
    }
    Const(decl~, ..) => self.index_decl(Decl::Const(decl), scope, container, [])
    Expr(expr~, ..) => self.index_expr(expr, scope, container)
    Assign(lhs~, rhs~, ..) => { self.index_expr(lhs, scope, container); self.index_expr(rhs, scope, container) }
    For(variable~, range~, body~, span~) => {
      let child = self.add_scope(span, Some(scope))
      let _ = self.add_symbol(variable, span, child, container, [], 13, 4, "\{variable}: Nat", read_only=true)
      self.index_expr(range.start, scope, container); self.index_expr(range.end, scope, container)
      for stmt in body { self.index_stmt(stmt, child, container) }
    }
    Scope(body~, span~) => {
      let child = self.add_scope(span, Some(scope))
      for stmt in body { self.index_stmt(stmt, child, container) }
    }
  }
}

fn Workspace::index_expr(self: Self, expr: Expr, scope: Int, container: Int?) -> Unit {
  match expr {
    Block(body~, last~, span~, ..) => {
      let child = self.add_scope(span, Some(scope))
      for stmt in body { self.index_stmt(stmt, child, container) }
      if last is Some(last) { self.index_expr(last, child, container) }
    }
    Unary(expr~, ..) | Spread(expr~, ..) | FieldAccess(expr~, ..) => self.index_expr(expr, scope, container)
    Binary(lhs~, rhs~, ..) => { self.index_expr(lhs, scope, container); self.index_expr(rhs, scope, container) }
    Indexing(expr~, index~, ..) => { self.index_expr(expr, scope, container); self.index_expr(index, scope, container) }
    Slicing(expr~, hi~, lo~, ..) => { self.index_expr(expr, scope, container); self.index_expr(hi, scope, container); self.index_expr(lo, scope, container) }
    Instance(ports~, ..) | Struct(fields=ports, ..) => for _, value in ports { self.index_expr(value, scope, container) }
    Vector(elems~, ..) | FunCall(args=elems, ..) => for value in elems { self.index_expr(value, scope, container) }
    Ternary(cond~, then~, else_~, ..) => { self.index_expr(cond, scope, container); self.index_expr(then, scope, container); self.index_expr(else_, scope, container) }
    Match(subject~, cases~, default~, ..) => {
      self.index_expr(subject, scope, container)
      for pair in cases { self.index_expr(pair.0, scope, container); self.index_expr(pair.1, scope, container) }
      if default is Some(value) { self.index_expr(value, scope, container) }
    }
    If(cond~, then~, else_~, ..) => { self.index_expr(cond, scope, container); self.index_expr(then, scope, container); if else_ is Some(value) { self.index_expr(value, scope, container) } }
    Natural(..) | Identifier(..) | String(..) => ()
  }
}

fn Workspace::scope_at(self: Self, uri: String, index: Int) -> Int? {
  let mut result = None
  let mut width = 2147483647
  for id, scope in self.scopes {
    if scope.span.file == uri && scope.span.start.index <= index && scope.span.end.index >= index && scope.span.end.index - scope.span.start.index <= width {
      width = scope.span.end.index - scope.span.start.index
      result = Some(id)
    }
  }
  result
}

fn Workspace::lookup(self: Self, scope: Int, name: String, index: Int) -> Int? {
  let mut current = Some(scope)
  while current is Some(scope) {
    let mut found = None
    for id in self.scopes[scope].symbols {
      let symbol = self.symbols[id]
      if symbol.name == name && ((symbol.kind != 13 && symbol.kind != 14) || symbol.selection.start.index <= index) { found = Some(id) }
    }
    if found is Some(_) { return found }
    current = self.scopes[scope].parent
  }
  if self.files.get(builtin_uri) is Some(file) {
    for id in self.scopes[file.scope].symbols { if self.symbols[id].name == name { return Some(id) } }
  }
  None
}

fn Workspace::member_scope(self: Self, id: Int) -> Int? {
  let symbol = self.symbols[id]
  if symbol.child_scope is Some(scope) { return Some(scope) }
  if symbol.instance is Some(path) {
    if self.lookup_path(symbol.scope, path, symbol.selection.start.index) is Some(module) { return self.symbols[module].child_scope }
  }
  match symbol.ty {
    Some(@parse.Type::Name(path~, ..)) => self.lookup_path(symbol.scope, path, symbol.selection.start.index).bind(id => self.symbols[id].child_scope)
    Some(@parse.Type::Instance(sig~, ..)) => self.lookup_path(symbol.scope, sig.path, symbol.selection.start.index).bind(id => self.symbols[id].child_scope)
    _ => None
  }
}

fn Workspace::lookup_path(self: Self, scope: Int, path: Path, index: Int) -> Int? {
  let parts = path.packages + [path.elem]
  let mut id = self.lookup(scope, parts[0], index)
  for part in parts[1:] {
    id = id.bind(id => self.member_scope(id)).bind(scope => self.scopes[scope].symbols.iter().find_first(id => self.symbols[id].name == part))
  }
  id
}

fn Workspace::resolve_token(self: Self, uri: String, index: Int) -> Int? {
  let file = self.files[uri]
  let token = file.tokens[index]
  if self.definitions.get(position_key(uri, token.span.start.index)) is Some(id) { return Some(id) }
  let name = match token.kind {
    @parse.TokenType::Identifier(name) | @parse.TokenType::BuiltinFunction(name) => name
    _ => return None
  }
  if index >= 2 && (file.tokens[index - 1].kind == @parse.TokenType::Dot || file.tokens[index - 1].kind == @parse.TokenType::ColonColon) {
    return self.resolve_token(uri, index - 2).bind(id => self.member_scope(id)).bind(scope => self.scopes[scope].symbols.iter().find_first(id => self.symbols[id].name == name && (self.symbols[id].member || file.tokens[index - 1].kind == @parse.TokenType::ColonColon)))
  }
  if index + 1 < file.tokens.length() && file.tokens[index + 1].kind == @parse.TokenType::Colon {
    return self.argument_target(uri, index).bind(pair => self.symbols[pair.0].child_scope.bind(scope => self.scopes[scope].symbols.iter().find_first(id => self.symbols[id].name == name && (if pair.1 { self.symbols[id].kind == 26 } else { self.symbols[id].member }))))
  }
  self.scope_at(uri, token.span.start.index).bind(scope => self.lookup(scope, name, token.span.start.index))
}

/// Find the module owning a named argument, including calls with generic arguments.
fn Workspace::argument_target(self: Self, uri: String, index: Int) -> (Int, Bool)? {
  let tokens = self.files[uri].tokens
  let stack = []
  for i in 0..<index {
    match tokens[i].kind {
      @parse.TokenType::Lparen | @parse.TokenType::Lbracket | @parse.TokenType::Lbrace => stack.push(i)
      @parse.TokenType::Rparen | @parse.TokenType::Rbracket | @parse.TokenType::Rbrace => { let _ = stack.pop() }
      _ => ()
    }
  }
  guard stack.last() is Some(open) && open > 0 && tokens[open].kind != @parse.TokenType::Lbrace else { return None }
  let mut target = open - 1
  if tokens[target].kind == @parse.TokenType::Rbracket {
    let mut depth = 1
    while target > 0 && depth > 0 {
      target -= 1
      if tokens[target].kind == @parse.TokenType::Rbracket { depth += 1 }
      if tokens[target].kind == @parse.TokenType::Lbracket { depth -= 1 }
    }
    guard target > 0 else { return None }
    target -= 1
  }
  self.resolve_token(uri, target).map(id => (id, tokens[open].kind == @parse.TokenType::Lbracket))
}

fn Workspace::reference_at(self: Self, uri: String, index: Int) -> Reference? {
  self.references.iter().find_first(reference => reference.span.file == uri && reference.span.start.index <= index && index <= reference.span.end.index)
}

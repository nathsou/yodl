fn distance(a: String, b: String) -> Int {
  let previous = Array::make(b.length() + 1, 0)
  for i in 0..=b.length() { previous[i] = i }
  for i in 0..<a.length() {
    let current = Array::make(b.length() + 1, 0)
    current[0] = i + 1
    for j in 0..<b.length() {
      let cost = if a.code_unit_at(i) == b.code_unit_at(j) { 0 } else { 1 }
      current[j + 1] = @utils.min(previous[j] + cost, @utils.min(previous[j + 1] + 1, current[j] + 1))
    }
    for j in 0..=b.length() { previous[j] = current[j] }
  }
  previous[b.length()]
}

fn Server::enriched_diagnostics(self: Self, uri: String) -> Array[@parse.Diagnostic] {
  let workspace = self.index()
  self.analyze(uri).diagnostics.map(fn(diagnostic) {
    let diagnostic = { ..diagnostic, related: diagnostic.related.copy(), notes: diagnostic.notes.copy(), fixes: diagnostic.fixes.copy() }
    if diagnostic.code != "Y0510" && diagnostic.code != "Y0506" && diagnostic.code != "Y0301" { return diagnostic }
    guard diagnostic.span is Some(span) else { return diagnostic }
    guard workspace.files.get(span.file) is Some(file) else { return diagnostic }
    let mut target = None
    for i, token in file.tokens {
      if token.span.start.index >= span.start.index && token.span.end.index <= span.end.index && token.kind is @parse.TokenType::Identifier(_) && workspace.resolve_token(span.file, i) is None { target = Some(i) }
    }
    guard target is Some(index) else { return diagnostic }
    let token = file.tokens[index]
    guard token.kind is @parse.TokenType::Identifier(name) else { return diagnostic }
    let candidates = if index >= 2 && file.tokens[index - 1].kind == @parse.TokenType::Dot {
      workspace.resolve_token(span.file, index - 2).bind(id => workspace.member_scope(id)).map(scope => workspace.scopes[scope].symbols.filter(id => workspace.symbols[id].member)).unwrap_or([])
    } else { workspace.scope_at(span.file, token.span.start.index).map(scope => workspace.visible(scope, token.span.start.index)).unwrap_or([]) }
    let mut best = None
    let mut best_distance = if name.length() <= 3 { 2 } else { 3 }
    let mut tied = false
    for id in candidates {
      let candidate = workspace.symbols[id]
      let d = distance(name, candidate.name)
      if d < best_distance { best = Some(id); best_distance = d; tied = false } else if d == best_distance { tied = true }
    }
    if !tied && best is Some(id) {
      let candidate = workspace.symbols[id]
      diagnostic.related.push({ span: candidate.selection, message: "'\{candidate.name}' is declared here" })
      diagnostic.notes.push("Did you mean '\{candidate.name}'?")
      diagnostic.fixes.push({ title: "Replace '\{name}' with '\{candidate.name}'", span: token.span, replacement: candidate.name })
    }
    diagnostic
  })
}

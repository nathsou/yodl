/// Diagnostics are compiler data. Rendering belongs at the CLI or editor boundary.
pub(all) struct Diagnostic {
  code: String
  message: String
  span: Span?
  severity: Int
  related: Array[DiagnosticLabel]
  notes: Array[String]
  fixes: Array[DiagnosticFix]
}

pub(all) struct DiagnosticLabel {
  span: Span
  message: String
}

pub(all) struct DiagnosticFix {
  title: String
  span: Span
  replacement: String
}

pub(open) trait Diagnosed {
  diagnostic(Self) -> Diagnostic
}

pub fn Diagnostic::new(code: String, message: String, span~: Span? = None) -> Diagnostic {
  { code, message, span, severity: 1, related: [], notes: [], fixes: [] }
}

/// Offsets are UTF-16 code units, matching MoonBit strings and LSP's default encoding.
pub fn SourceLoc::at(source: StringView, offset: Int) -> SourceLoc {
  let index = @utils.clamp(offset, min=0, max=source.length())
  let mut line = 1
  let mut column = 1
  for i in 0..<index {
    if source.unsafe_get(i) == '\n' {
      line += 1
      column = 1
    } else if source.unsafe_get(i) == '\r' {
      if i + 1 == source.length() || source.unsafe_get(i + 1) != '\n' {
        line += 1
        column = 1
      }
    } else {
      column += 1
    }
  }
  { index, line, column }
}

pub fn Span::at(file: String, source: StringView, start: Int, end: Int) -> Span {
  let start = SourceLoc::at(source, start)
  let end = SourceLoc::at(source, @utils.max(start.index, end))
  { file, file_content: source, start, end }
}

fn render_label(out: StringBuilder, span: Span, message: String) -> Unit {
  out.write_string("  --> \{span.file}:\{span.start.line}:\{span.start.column}-\{span.end.line}:\{span.end.column}\n")
  let source = span.file_content
  let mut start = @utils.clamp(span.start.index, min=0, max=source.length())
  while start > 0 && source.unsafe_get(start - 1) != '\n' && source.unsafe_get(start - 1) != '\r' { start -= 1 }
  let mut end = start
  while end < source.length() && source.unsafe_get(end) != '\n' && source.unsafe_get(end) != '\r' { end += 1 }
  let number = span.start.line.to_string()
  let gutter = " ".repeat(number.length())
  out.write_string("\{gutter} |\n\{number} | ")
  // Expand tabs consistently in both the excerpt and its underline.
  let mut display = 0
  let mut underline_start = 0
  let mut underline_end = 0
  for offset, char in source[start:end] {
    let i = start + offset
    if i == span.start.index { underline_start = display }
    if i == span.end.index { underline_end = display }
    if char == '\t' {
      let width = 4 - display % 4
      out.write_string(" ".repeat(width))
      display += width
    } else {
      out.write_char(char)
      display += if char.to_int() > 0xFFFF { 2 } else { 1 }
    }
  }
  if span.start.index >= end { underline_start = display }
  if span.end.index >= end { underline_end = display }
  let width = @utils.max(1, underline_end - underline_start)
  out.write_string("\n\{gutter} | \{" ".repeat(underline_start)}\{"^".repeat(width)}")
  if message != "" { out.write_string(" \{message}") }
  out.write_string("\n")
  if span.end.line > span.start.line { out.write_string("\{gutter} = span continues to line \{span.end.line}\n") }
}

pub fn Diagnostic::render(self: Self) -> String {
  let out = StringBuilder()
  let severity = if self.severity == 2 { "warning" } else { "error" }
  out.write_string("\{severity}[\{self.code}]: \{self.message}\n")
  if self.span is Some(span) { render_label(out, span, "") }
  for label in self.related { render_label(out, label.span, label.message) }
  for note in self.notes { out.write_string("  = note: \{note}\n") }
  for fix in self.fixes { out.write_string("  = help: \{fix.title}\n") }
  out.to_string().trim_end().to_owned()
}

pub fn diagnostic(error: Error) -> Diagnostic? {
  match error {
    LexerError::UnexepectedChar(char~, span~) => Some(LexerError::UnexepectedChar(char~, span~).diagnostic())
    LexerError::UnterminatedStringLiteral(span~) => Some(LexerError::UnterminatedStringLiteral(span~).diagnostic())
    LexerError::UnterminatedCharacterLiteral(span~) => Some(LexerError::UnterminatedCharacterLiteral(span~).diagnostic())
    ParserError::UnexpectedToken(expected~, received~, span~) => Some(ParserError::UnexpectedToken(expected~, received~, span~).diagnostic())
    ParserError::ExpectedIdentifier(received~, span~) => Some(ParserError::ExpectedIdentifier(received~, span~).diagnostic())
    ParserError::ExpectedExpr(received~, span~) => Some(ParserError::ExpectedExpr(received~, span~).diagnostic())
    ParserError::ExpectedStmt(received~, span~) => Some(ParserError::ExpectedStmt(received~, span~).diagnostic())
    ParserError::ExpectedType(received~, span~) => Some(ParserError::ExpectedType(received~, span~).diagnostic())
    ParserError::MissingIntegerWidth(span~) => Some(ParserError::MissingIntegerWidth(span~).diagnostic())
    ParserError::ExpectedDecl(received~, span~) => Some(ParserError::ExpectedDecl(received~, span~).diagnostic())
    ParserError::ExpectedRangeOperator(received~, span~) => Some(ParserError::ExpectedRangeOperator(received~, span~).diagnostic())
    ParserError::MultipleDefaultCases(span~) => Some(ParserError::MultipleDefaultCases(span~).diagnostic())
    ParserError::InvalidPortOrTupleAccess(span~) => Some(ParserError::InvalidPortOrTupleAccess(span~).diagnostic())
    ParserError::DuplicateStructField(name~, span~) => Some(ParserError::DuplicateStructField(name~, span~).diagnostic())
    ParserError::NatTypeAliasParametersUnsupported(name~, span~) => Some(ParserError::NatTypeAliasParametersUnsupported(name~, span~).diagnostic())
    AstError::ExpectedIntegerExpression(expr~, span~) => Some(AstError::ExpectedIntegerExpression(expr~, span~).diagnostic())
    AstError::IndexExprNotLiteral(span~) => Some(AstError::IndexExprNotLiteral(span~).diagnostic())
    AstError::CannotGetWidthOfUnresolvedNamedType(span~) => Some(AstError::CannotGetWidthOfUnresolvedNamedType(span~).diagnostic())
    AstError::InvalidFunCallArity(name~, expected~, actual~, span~) => Some(AstError::InvalidFunCallArity(name~, expected~, actual~, span~).diagnostic())
    AstError::ExpectedStringExpression(expr~, span~) => Some(AstError::ExpectedStringExpression(expr~, span~).diagnostic())
    AstError::ConflictingInstanceParameterValue(name~, span~) => Some(AstError::ConflictingInstanceParameterValue(name~, span~).diagnostic())
    AstError::UnknownModuleParameter(name~, span~) => Some(AstError::UnknownModuleParameter(name~, span~).diagnostic())
    AstError::TypeParamInsteadOfExpr(span~) => Some(AstError::TypeParamInsteadOfExpr(span~).diagnostic())
    AstError::UnknownFunction(name~, span~) => Some(AstError::UnknownFunction(name~, span~).diagnostic())
    AstError::UnresolvedParameter(name~, span~) => Some(AstError::UnresolvedParameter(name~, span~).diagnostic())
    AstError::CannotMixNamedAndOrderedModuleParameters(span~) => Some(AstError::CannotMixNamedAndOrderedModuleParameters(span~).diagnostic())
    AstError::ExpectedTypeParameter(span~) => Some(AstError::ExpectedTypeParameter(span~).diagnostic())
    AstError::ExpectedIntParameter(span~) => Some(AstError::ExpectedIntParameter(span~).diagnostic())
    AstError::NonStorableType(ty~, span~) => Some(AstError::NonStorableType(ty~, span~).diagnostic())
    AstError::InvalidCoreType(ty~, span~) => Some(AstError::InvalidCoreType(ty~, span~).diagnostic())
    AstError::InvalidCoreDimension(kind~, value~, span~) => Some(AstError::InvalidCoreDimension(kind~, value~, span~).diagnostic())
    AstError::InvalidSizeFunctionDomain(message~, span~) => Some(AstError::InvalidSizeFunctionDomain(message~, span~).diagnostic())
    _ => None
  }
}

pub fn Span::range_json(self: Self) -> Json {
  Json::object({
    "start": Json::object({ "line": (self.start.line - 1).to_json(), "character": (self.start.column - 1).to_json() }),
    "end": Json::object({ "line": (self.end.line - 1).to_json(), "character": (self.end.column - 1).to_json() }),
  })
}

pub fn Diagnostic::to_json(self: Self) -> Json {
  let result: Map[String, Json] = {
    "code": self.code.to_json(), "message": self.message.to_json(),
    "severity": self.severity.to_json(), "source": "yodl".to_json(),
    "notes": self.notes.to_json(), "rendered": self.render().to_json(),
    "relatedInformation": Json::array(self.related.map(label => Json::object({
      "location": Json::object({ "uri": label.span.file.to_json(), "range": label.span.range_json() }),
      "message": label.message.to_json(),
    }))),
    "fixes": Json::array(self.fixes.map(fix => Json::object({
      "title": fix.title.to_json(), "uri": fix.span.file.to_json(),
      "range": fix.span.range_json(), "newText": fix.replacement.to_json(),
    }))),
  }
  if self.span is Some(span) {
    result["uri"] = span.file.to_json()
    result["range"] = span.range_json()
  }
  Json::object(result)
}

using @parse { type Span }

priv suberror ProtocolError {
  ProtocolError(code~: Int, message~: String)
}

fn field(value: Json, key: String) -> Json {
  match value { Object(values) => values.get(key).unwrap_or(Json::null()); _ => Json::null() }
}

fn string(value: Json) -> String? {
  match value { String(value) => Some(value); _ => None }
}

fn integer(value: Json) -> Int? {
  match value {
    Number(value, ..) if value >= -2147483648.0 && value <= 2147483647.0 && value == value.to_int().to_double() => Some(value.to_int())
    _ => None
  }
}

fn array(value: Json) -> Array[Json] {
  match value { Array(values) => values; _ => [] }
}

fn required_string(value: Json, key: String) -> String raise ProtocolError {
  string(field(value, key)).unwrap_or_error(ProtocolError(code=-32602, message="Expected '\{key}' to be a string"))
}

fn required_integer(value: Json, key: String) -> Int raise ProtocolError {
  integer(field(value, key)).unwrap_or_error(ProtocolError(code=-32602, message="Expected '\{key}' to be an integer"))
}

fn response(id: Json, result: Json) -> Json {
  Json::object({ "jsonrpc": "2.0".to_json(), "id": id, "result": result })
}

fn error_response(id: Json, code: Int, message: String) -> Json {
  Json::object({ "jsonrpc": "2.0".to_json(), "id": id, "error": Json::object({ "code": code.to_json(), "message": message.to_json() }) })
}

fn notification(method: String, params: Json) -> Json {
  Json::object({ "jsonrpc": "2.0".to_json(), "method": method.to_json(), "params": params })
}

fn location(span: Span) -> Json {
  Json::object({ "uri": span.file.to_json(), "range": span.range_json() })
}

/// Translate LSP positions using UTF-16 units. Positions beyond a line are clamped per LSP.
fn offset(source: String, position: Json) -> Int raise ProtocolError {
  let line = required_integer(position, "line")
  let character = required_integer(position, "character")
  if line < 0 || character < 0 { raise ProtocolError(code=-32602, message="Positions cannot be negative") }
  let mut current_line = 0
  let mut index = 0
  while index < source.length() && current_line < line {
    let unit = source.code_unit_at(index)
    index += 1
    if unit == '\n' { current_line += 1 }
    if unit == '\r' {
      if index < source.length() && source.code_unit_at(index) == '\n' { index += 1 }
      current_line += 1
    }
  }
  let mut end = index
  while end < source.length() && source.code_unit_at(end) != '\n' && source.code_unit_at(end) != '\r' { end += 1 }
  @utils.min(end, index + @utils.min(character, source.length()))
}

fn range_span(uri: String, source: String, range: Json) -> Span raise ProtocolError {
  let start = offset(source, field(range, "start"))
  let end = offset(source, field(range, "end"))
  if end < start { raise ProtocolError(code=-32602, message="Range ends before its start") }
  @parse.Span::at(uri, source[:], start, end)
}

fn[T] prefer(value: T?, fallback: T?) -> T? { match value { Some(_) => value; None => fallback } }

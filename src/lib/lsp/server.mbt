pub struct Server {
  files: Map[String, String]
  documents: Map[String, Document]
  analyses: Map[String, @driver.Analysis]
  reads: Map[String, Map[String, String]]
  published: Set[String]
  mut workspace: Workspace?
  mut initialized: Bool
  mut shutdown: Bool
  mut exited: Bool
}

struct Document {
  source: String
  version: Int
}

pub fn new_server() -> Server {
  { files: {}, documents: {}, analyses: {}, reads: {}, published: Set([]), workspace: None, initialized: false, shutdown: false, exited: false }
}

fn Server::invalidate(self: Self) -> Unit {
  self.analyses.clear()
  self.reads.clear()
  self.workspace = None
}

fn Server::sources(self: Self) -> Map[String, String] {
  let files = self.files.copy()
  for uri, doc in self.documents { files[uri] = doc.source }
  files
}

fn Server::source(self: Self, uri: String) -> String? {
  match self.documents.get(uri) { Some(doc) => Some(doc.source); None => self.files.get(uri) }
}

fn Server::set_files(self: Self, value: Json) -> Unit raise ProtocolError {
  guard value is Object(files) else { raise ProtocolError(code=-32602, message="files must be an object") }
  let checked = Map([])
  for uri, value in files {
    guard value is String(source) else { raise ProtocolError(code=-32602, message="Source files must contain strings") }
    checked[uri] = source
  }
  self.files.clear()
  for uri, source in checked { self.files[uri] = source }
  self.invalidate()
}

fn virtual_fs(files: Map[String, String], reads: Map[String, String]) -> @utils.FileSystem {
  {
    read_file_to_string: fn(uri) raise {
      let source = files.get(uri).unwrap_or_error(Failure::Failure("File not found: '\{uri}'"))
      reads[uri] = source
      source
    },
    read_dir: fn(dir) raise {
      let entries = Set([])
      let prefix = dir + "/"
      for uri, _ in files {
        if uri.has_prefix(prefix) {
          let rest = uri[prefix.length():]
          if rest.split("/").next() is Some(entry) { entries.add(entry.to_owned()) }
        }
      }
      let result = entries.to_array()
      result.sort()
      result
    },
    path_exists: uri => files.contains(uri) || files.iter().any(pair => pair.0.has_prefix(uri + "/")),
    is_dir: fn(uri) raise { !files.contains(uri) && files.iter().any(pair => pair.0.has_prefix(uri + "/")) },
    create_dir: fn(_) raise { () }, write_string_to_file: fn(_, _) raise { () },
  }
}

fn Server::analyze(self: Self, uri: String) -> @driver.Analysis {
  // Builtins are already injected by the resolver. Their virtual preview is
  // indexed for navigation, but must not be compiled as a second user library.
  if uri == builtin_uri { return { source_decls: [], typed_decls: [], diagnostics: [] } }
  match self.analyses.get(uri) {
    Some(analysis) => analysis
    None => {
      let reads = Map([])
      let ext: @utils.Externals = { fs: virtual_fs(self.sources(), reads), println: _ => (), get_args: () => [], exit: _ => () }
      let analysis = @driver.analyze(uri, ext)
      self.analyses[uri] = analysis
      self.reads[uri] = reads
      analysis
    }
  }
}

pub fn handle_message(server: Server, message: String) -> String {
  let self = server
  let input = try @json.parse(message[:]) catch { _ => return Json::array([error_response(Json::null(), -32700, "Invalid JSON")]).stringify() }
  guard input is Object(values) else { return Json::array([error_response(Json::null(), -32600, "Expected a JSON-RPC object")]).stringify() }
  let id = field(input, "id")
  let is_request = values.contains("id")
  let replies = []
  let method = string(field(input, "method"))
  if field(input, "jsonrpc") != "2.0".to_json() || method is None {
    return Json::array([error_response(id, -32600, "Invalid JSON-RPC request")]).stringify()
  }
  if is_request && !(id is String(_) || id is Number(_) || id is Null) {
    return Json::array([error_response(Json::null(), -32600, "Invalid request id")]).stringify()
  }
  try self.dispatch(method.unwrap(), field(input, "params"), replies) catch {
    ProtocolError(code~, message~) => if is_request { replies.push(error_response(id, code, message)) }
    error => {
      if is_request { replies.push(error_response(id, -32603, "Language service failed: \{error}")) }
      replies.push(notification("window/logMessage", Json::object({ "type": (1).to_json(), "message": "Yodl language service: \{error}".to_json() })))
    }
  } noraise {
    result => if is_request { replies.push(response(id, result)) }
  }
  Json::array(replies).stringify()
}

fn Server::dispatch(self: Self, method: String, params: Json, replies: Array[Json]) -> Json raise {
  if self.exited { raise ProtocolError(code=-32600, message="Server has exited") }
  if method == "exit" { self.exited = true; return Json::null() }
  if method == "initialize" {
    if self.initialized { raise ProtocolError(code=-32600, message="Server is already initialized") }
    let files = field(field(params, "initializationOptions"), "files")
    if files != Json::null() { self.set_files(files) }
    self.initialized = true
    return Json::object({ "serverInfo": Json::object({ "name": "yodl".to_json(), "version": "0.3.1".to_json() }), "capabilities": capabilities() })
  }
  if !self.initialized { raise ProtocolError(code=-32002, message="Server is not initialized") }
  if self.shutdown { raise ProtocolError(code=-32600, message="Server is shutting down") }
  match method {
    "initialized" | "$/cancelRequest" | "$/setTrace" | "workspace/didChangeConfiguration" => Json::null()
    "workspace/didChangeWorkspaceFolders" => { self.invalidate(); Json::null() }
    "shutdown" => { self.shutdown = true; Json::null() }
    "yodl/setFiles" => { self.set_files(field(params, "files")); Json::null() }
    "yodl/dependencies" => {
      let uri = required_string(params, "uri")
      let _ = self.analyze(uri)
      self.reads.get(uri).unwrap_or({}).to_json()
    }
    "yodl/source" => {
      let uri = required_string(params, "uri")
      if uri == builtin_uri { @simplify.builtin_source().to_json() } else { self.source(uri).map(s => s.to_json()).unwrap_or(Json::null()) }
    }
    "textDocument/didOpen" => {
      let document = field(params, "textDocument")
      let uri = required_string(document, "uri")
      let source = required_string(document, "text")
      let version = required_integer(document, "version")
      self.documents[uri] = { source, version }
      self.invalidate()
      Json::null()
    }
    "textDocument/didChange" => {
      let document = field(params, "textDocument")
      let uri = required_string(document, "uri")
      let version = required_integer(document, "version")
      guard self.documents.get(uri) is Some(old) else { return Json::null() }
      if version <= old.version { return Json::null() }
      let mut source = old.source
      guard field(params, "contentChanges") is Array(changes) else { raise ProtocolError(code=-32602, message="contentChanges must be an array") }
      for change in changes {
        let text = required_string(change, "text")
        let range = field(change, "range")
        source = if range == Json::null() { text } else {
          let span = range_span(uri, source, range)
          source[:span.start.index].to_owned() + text + source[span.end.index:].to_owned()
        }
      }
      self.documents[uri] = { source, version }
      self.invalidate()
      Json::null()
    }
    "textDocument/didClose" => {
      let uri = required_string(field(params, "textDocument"), "uri")
      self.documents.remove(uri)
      self.invalidate()
      replies.push(notification("textDocument/publishDiagnostics", Json::object({ "uri": uri.to_json(), "diagnostics": Json::array([]) })))
      self.published.remove(uri)
      Json::null()
    }
    "textDocument/didSave" | "workspace/didChangeWatchedFiles" => { self.invalidate(); Json::null() }
    _ => self.query(method, params)
  }
}

fn capabilities() -> Json {
  Json::object({
    "positionEncoding": "utf-16".to_json(),
    "workspace": Json::object({ "workspaceFolders": Json::object({ "supported": true.to_json(), "changeNotifications": true.to_json() }) }),
    "textDocumentSync": Json::object({ "openClose": true.to_json(), "change": (2).to_json(), "save": true.to_json() }),
    "hoverProvider": true.to_json(), "definitionProvider": true.to_json(), "declarationProvider": true.to_json(),
    "typeDefinitionProvider": true.to_json(), "referencesProvider": true.to_json(), "documentHighlightProvider": true.to_json(),
    "documentSymbolProvider": true.to_json(), "workspaceSymbolProvider": true.to_json(),
    "completionProvider": Json::object({ "triggerCharacters": [".", ":", "["].to_json(), "resolveProvider": false.to_json() }),
    "signatureHelpProvider": Json::object({ "triggerCharacters": ["(", "[", ",", ":"].to_json(), "retriggerCharacters": [","].to_json() }),
    "renameProvider": Json::object({ "prepareProvider": true.to_json() }),
    "codeActionProvider": Json::object({ "codeActionKinds": ["quickfix"].to_json() }),
    "semanticTokensProvider": Json::object({ "legend": Json::object({ "tokenTypes": token_types().to_json(), "tokenModifiers": ["declaration", "readonly"].to_json() }), "full": true.to_json(), "range": false.to_json() }),
    "foldingRangeProvider": true.to_json(), "selectionRangeProvider": true.to_json(),
  })
}

pub fn flush_diagnostics(server: Server) -> String {
  let self = server
  if !self.initialized || self.shutdown || self.exited { return "[]" }
  let by_uri: Map[String, Array[Json]] = Map([])
  let seen = Set([])
  for uri, _ in self.documents {
    let _ = by_uri.get_or_init(uri, () => [])
    for diagnostic in self.enriched_diagnostics(uri) {
      let target = diagnostic.span.map(span => span.file).unwrap_or(uri)
      let encoded = diagnostic.to_json()
      let fingerprint = encoded.stringify()
      if !seen.contains(fingerprint) {
        seen.add(fingerprint)
        let value = match encoded { Object(value) => value; _ => {} }
        value["range"] = diagnostic.span.map(span => span.range_json()).unwrap_or(@parse.Span::at(uri, "", 0, 0).range_json())
        value["data"] = field(encoded, "fixes")
        by_uri.get_or_init(target, () => []).push(Json::object(value))
      }
    }
  }
  let notifications = []
  for uri in self.published {
    if !by_uri.contains(uri) { by_uri[uri] = [] }
  }
  self.published.clear()
  for uri, diagnostics in by_uri {
    let params: Map[String, Json] = { "uri": uri.to_json(), "diagnostics": Json::array(diagnostics) }
    if self.documents.get(uri) is Some(doc) { params["version"] = doc.version.to_json() }
    notifications.push(notification("textDocument/publishDiagnostics", Json::object(params)))
    self.published.add(uri)
  }
  Json::array(notifications).stringify()
}

fn analyze_source(source: String, files~: Map[String, String] = {}) -> @driver.Analysis {
  files["fixture.yodl"] = source
  let ext: @utils.Externals = {
    fs: make_vfs(files), println: _ => (), get_args: () => [], exit: _ => (),
  }
  @driver.analyze("fixture.yodl", ext)
}

test "analysis checks libraries without selecting a top module" {
  let result = analyze_source("module First() -> () {}\nmodule Second() -> () {}")
  assert_eq(result.diagnostics.length(), 0)
  assert_true(result.typed_decls.length() >= 2)
}

test "diagnostics preserve codes, messages and exact source locations" {
  let result = analyze_source("module Top() -> () {\n  let value: u8 = 256\n}")
  assert_eq(result.diagnostics.length(), 1)
  let diagnostic = result.diagnostics[0]
  assert_eq(diagnostic.code, "Y0501")
  assert_true(diagnostic.message.contains("Literal requires 9 bits"))
  let span = diagnostic.span.unwrap()
  assert_eq(span.text().to_owned(), "256")
  assert_eq(span.start.line, 2)
  assert_eq(span.start.column, 19)
  assert_true(diagnostic.render().contains("2 |   let value: u8 = 256"))
  assert_true(diagnostic.render().contains("^^^"))
}

test "parser recovery retains valid statements and following declarations" {
  let source = "module Broken() -> () {\n  let bad = )\n  let good: u8 = 1\n}\nmodule Good() -> () {}"
  let diagnostics = []
  let tokens = @parse.Lexer::new(source, file="fixture.yodl", file_content=source).lex_recovering(diagnostics)
  let decls = @parse.Parser::new(tokens, file="fixture.yodl", file_content=source).parse_recovering(diagnostics)
  assert_true(!diagnostics.is_empty())
  assert_eq(decls.length(), 2)
  match decls[0] {
    @parse.Decl::Module(mod) => assert_eq(mod.body.length(), 1)
    _ => fail("Expected a recovered module")
  }
}

test "incomplete module reports EOF and remains available for navigation" {
  let result = analyze_source("module Top() -> () {\n  let value = 1\n")
  assert_true(result.diagnostics[0].message.contains("end of file"))
  assert_eq(result.diagnostics[0].span.unwrap().start.line, 3)
  assert_true(result.source_decls.iter().any(decl => match decl {
    @parse.Decl::Module(mod) => mod.path.elem == "Top"
    _ => false
  }))
  assert_eq(result.typed_decls.length(), 0)
}

test "missing imports underline their own source declaration" {
  let result = analyze_source("import Missing\nmodule Top() -> () {}")
  assert_eq(result.diagnostics[0].code, "Y0701")
  assert_true(result.diagnostics[0].span.unwrap().text().to_owned().contains("Missing"))
}

test "import cycles are diagnosed rather than recursing indefinitely" {
  let result = analyze_source("import A\nmodule Top() -> () {}", files={
    "./A.yodl": "import B\nmodule A() -> () {}",
    "./B.yodl": "import A\nmodule B() -> () {}",
  })
  assert_true(result.diagnostics.iter().any(d => d.code == "Y0704"))
}

test "source positions use UTF16 with CRLF and empty EOF spans" {
  let source = "// 😀\r\n\tmodule"
  let start = @parse.SourceLoc::at(source[:], 7)
  assert_eq(start.line, 2)
  assert_eq(start.column, 1)
  let eof = @parse.Span::at("unicode.yodl", source[:], source.length(), source.length())
  assert_eq(eof.start.line, 2)
  assert_eq(eof.start.column, 8)
  assert_true(@parse.Diagnostic::new("TEST", "expected a name", span=Some(eof)).render().contains("^"))
}

test "editor analysis reports independent statement errors and retains valid types" {
  let result = analyze_source("module Top() -> () {\n let first: u8 = 256\n let second: u8 = 512\n let valid: u8 = 1\n}")
  assert_eq(result.diagnostics.length(), 2)
  assert_eq(result.diagnostics[0].span.unwrap().text().to_owned(), "256")
  assert_eq(result.diagnostics[1].span.unwrap().text().to_owned(), "512")
  assert_true(!result.typed_decls.is_empty())
}

test "deferred parameters retain complete source and their own EOF boundary" {
  let source = "module Child[N: Nat]() -> () {}\nmodule Top() -> () {\n let inst = Child[N: 1 +]()\n}"
  let result = analyze_source(source)
  let span = result.diagnostics[0].span.unwrap()
  assert_eq(span.file_content.length(), source.length())
  assert_eq(span.start.index, source.rev_find("]").unwrap())
  assert_true(result.diagnostics[0].render().contains("let inst = Child[N: 1 +]()"))
  let invalid_type = analyze_source("module Top() -> () {\n let inst = Reg[T: 8]()\n}")
  assert_true(invalid_type.diagnostics[0].render().contains("let inst = Reg[T: 8]()"))
}

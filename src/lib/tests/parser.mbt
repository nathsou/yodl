fn parse_source(source: String) -> Array[@parse.Decl] raise {
  let tokens = @parse.Lexer::new(source, file="parser-test.yodl", file_content=source).lex()
  @parse.Parser::new(tokens, file="parser-test.yodl", file_content=source).parse()
}

fn module_body(decls: Array[@parse.Decl]) -> Array[@parse.Stmt] {
  match decls {
    [@parse.Decl::Module(mod)] => mod.body
    _ => @utils.fail("expected one module definition")
  }
}

test "parser inserts semicolons after clock types" {
  let source =
    "module Top(clk: clock) -> () {\n" +
    "  let x: clock\n" +
    "  let y: bool = x\n" +
    "}\n"
  let body = module_body(parse_source(source))
  assert_eq(body.length(), 2)
}

test "parser accepts mod as a modulo operator" {
  let source =
    "module Top() -> () {\n" +
    "  let x = 5 mod 2\n" +
    "}\n"
  let body = module_body(parse_source(source))
  let is_mod = match body[0] {
    @parse.Stmt::Let(expr=Some(@parse.Expr::Binary(op=@parse.BinaryOp::Mod, ..)), ..) => true
    _ => false
  }
  assert_eq(is_mod, true)
}

test "parser accepts empty attribute dictionaries" {
  let source = "@foo({})\nmodule Top() -> () {}\n"
  assert_eq(parse_source(source).length(), 1)
}

test "instance parameters keep commas inside calls" {
  let source =
    "module Top() -> () {\n" +
    "  let x = Child[\n" +
    "    cdiv!(8, 2)\n" +
    "  ]()\n" +
    "}\n"
  let body = module_body(parse_source(source))
  let param = match body[0] {
    @parse.Stmt::Let(expr=Some(@parse.Expr::Instance(params~, ..)), ..) => params.params[0].1
    _ => @utils.fail("expected an instance expression")
  }

  match param {
    @parse.Param::Unresolved(raw) => match raw.parse(@parse.ParamSort::NatSort) {
      @parse.ParsedParam::ExprParam(expr=@parse.Expr::FunCall(name="cdiv", args~, ..), ..) => {
        assert_eq(args.length(), 2)
      }
      _ => @utils.fail("expected a cdiv expression parameter")
    }
    _ => @utils.fail("expected an unresolved instance parameter")
  }
}

test "parser reports malformed EOF without crashing" {
  let did_raise = try {
    let _ = parse_source("module")
    false
  } catch {
    _ => true
  }
  assert_eq(did_raise, true)
}

test "lexer reports unterminated literals" {
  let string_did_raise = try {
    let _ = @parse.Lexer::new("\"", file="parser-test.yodl", file_content="\"").lex()
    false
  } catch {
    _ => true
  }
  let char_did_raise = try {
    let _ = @parse.Lexer::new("'", file="parser-test.yodl", file_content="'").lex()
    false
  } catch {
    _ => true
  }
  assert_eq(string_did_raise, true)
  assert_eq(char_did_raise, true)
}

test "lexer handles comments and punctuation at EOF" {
  let comment_tokens = @parse.Lexer::new("// comment", file="parser-test.yodl", file_content="// comment").lex()
  let punctuation_tokens = @parse.Lexer::new(":", file="parser-test.yodl", file_content=":").lex()
  assert_eq(comment_tokens.length(), 0)
  assert_eq(punctuation_tokens.length(), 1)
}

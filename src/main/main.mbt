
fn run(path: String) -> @parse.Decl!Error {
  let source = @fs.read_file_to_string!(path=path)
  let lexer = @parse.Lexer::new(source)
  let tokens = lexer.lex!()
  let parser = @parse.Parser::new(tokens)
  parser.parse_module_decl!()
}

fn main {
  match run?("examples/FullAdder.yodl") {
    Ok(decl) => {
      let emitter = @parse.Emitter::new()
      emitter.emit_decl(decl)
      println(emitter.to_string())
    }
    Err(error) => println(error)
  } 
}

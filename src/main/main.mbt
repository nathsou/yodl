
fn run(file: String) -> String!Error {
  let source = @fs.read_file_to_string!(path=file)
  let lexer = @parse.Lexer::new(source, file~)
  let tokens = lexer.lex!()
  let parser = @parse.Parser::new(tokens, file~)
  let decls = parser.parse!()
  let checker = @elaborate.TypeChecker::new()

  for decl in decls {
    let emitter = @parse.Emitter::new()
    emitter.emit_decl(decl)
    checker.check_decl!(decl)
  }

  let elaborator = @elaborate.Elaborator::new()

  for decl in decls {
    elaborator.elaborate_decl!(decl)
  }

  let serializer = @rtlil.Serializer::new(
    autoidx=elaborator.autoidx,
    modules=elaborator.modules,
  )

  serializer.to_string()
}

fn main {
  match run?("examples/FullAdder.yodl") {
    Ok(rtlil) => {
      if not(@fs.path_exists(path="output")) {
        @fs.create_dir(path="output")
      }

      @fs.write_string_to_file(path="output/FullAdder.rtlil", content=rtlil)
    }
    Err(error) => println(error)
  } 
}

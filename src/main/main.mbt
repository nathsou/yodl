
fn run(file: String) -> Map[String, @elaborate.ModuleDef]!Error {
  let source = @fs.read_file_to_string!(path=file)
  let lexer = @parse.Lexer::new(source, file~)
  let tokens = lexer.lex!()
  let parser = @parse.Parser::new(tokens, file~)
  let decls = parser.parse!()
  let checker = @elaborate.TypeChecker::new()

  for decl in decls {
    checker.check_decl!(decl)
  }

  let elaborator = @elaborate.Elaborator::new()

  for decl in decls {
    elaborator.elaborate_decl!(decl)
  }

  elaborator.modules
}

fn main {
  match run?("examples/FullAdder.yodl") {
    Ok(modules) => {
      for name, mod in modules {
        let dotfile = @elaborate.to_dotfile(mod)
        @fs.write_string_to_file(path="output/\{name}.dot", content=dotfile)
      }
    }
    Err(error) => println(error)
  } 
}

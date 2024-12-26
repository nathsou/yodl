
fn run(file: String) -> String!Error {
  let source = @fs.read_file_to_string!(path=file)
  let lexer = @parse.Lexer::new(source, file~)
  let tokens = lexer.lex!()
  let parser = @parse.Parser::new(tokens, file~)
  let decls = parser.parse!()
  let monomorphizer = @simplify.Monomorphizer::new()
  let mono_decls = monomorphizer.monomorphize!(decls)
  let checker = @elaborate.TypeChecker::new()
  let simplifier = @simplify.Simplifier::new()
  let simplified_decls = []
  let emitter = @parse.Emitter::new()

  // {
  //   let emitter = @parse.Emitter::new()
  //   for decl in mono_decls {
  //     emitter.emit_decl(decl)
  //     emitter.emit("\n")
  //   }

  //   println(emitter.to_string())
  // }

  for decl in mono_decls {
    checker.check_decl!(decl)
    let simplified_decl = simplifier.simplify_decl!(decl)
    simplified_decls.push(simplified_decl)
    emitter.emit_decl(simplified_decl)
    emitter.emit("\n")
  }
  
  println(emitter.to_string())

  let elaborator = @elaborate.Elaborator::new()

  for decl in simplified_decls {
    elaborator.elaborate_decl!(decl)
  }

  let serializer = @rtlil.Serializer::new(
    autoidx=elaborator.autoidx,
    modules=elaborator.modules,
  )

  serializer.to_string()
}

fn main {
  let file = "FullAdder"

  match run?("examples/\{file}.yodl") {
    Ok(rtlil) => {
      if not(@fs.path_exists(path="output")) {
        @fs.create_dir(path="output")
      }

      @fs.write_string_to_file(path="output/\{file}.rtlil", content=rtlil)
    }
    Err(error) => println(error)
  }
}

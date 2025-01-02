
struct RunOptions {
  show_monomorphized: Bool
  show_simplified: Bool
}

let builtin_decls: Array[@parse.Decl] = {
  let source =
    #|@internal
    #|declare module Reg<N>(
    #|    clk: logic,
    #|    d: logic[N],
    #|    en?: logic,
    #|    rst?: logic,
    #|) -> (
    #|    q: logic[N],
    #|)
    #|
    #|@internal
    #|
    #|declare module RegSyncReset<N>(
    #|    clk: logic,
    #|    d: logic[N],
    #|    en?: logic,
    #|    rst?: logic,
    #|) -> (
    #|    q: logic[N],
    #|)
  
  let lexer = @parse.Lexer::new(source, file="builtin.yodl")
  let tokens = lexer.lex?().unwrap()
  let parser = @parse.Parser::new(tokens, file="builtin.yodl")
  parser.parse?().unwrap()
}

fn run(file: String, options: RunOptions) -> String! {
  let source = @fs.read_file_to_string!(path=file)
  let lexer = @parse.Lexer::new(source, file~)
  let tokens = lexer.lex!()
  let parser = @parse.Parser::new(tokens, file~)
  let decls = builtin_decls + parser.parse!()
  let monomorphizer = @simplify.Monomorphizer::new()
  let mono_decls = monomorphizer.monomorphize!(decls)
  let checker = @elaborate.TypeChecker::new()
  let simplifier = @simplify.Simplifier::new()
  let simplified_decls = []

  if options.show_monomorphized {
    let emitter = @parse.Emitter::new()
    for decl in mono_decls {
      emitter.emit_decl(decl)
      emitter.emit("\n")
    }

    println(emitter.to_string())
  }

  for decl in mono_decls {
    checker.check_decl!(decl)
    let simplified_decl = simplifier.simplify_decl!(decl)
    simplified_decls.push(simplified_decl)
  }
  
  if options.show_simplified {
    let emitter = @parse.Emitter::new()

    for simplified_decl in simplified_decls {
      if not(simplified_decl.is_internal()) {
        emitter.emit_decl(simplified_decl)
        emitter.emit("\n")
      }
    }

    println(emitter.to_string())
  }

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
  let file = "Struct"

  match run?("examples/\{file}.yodl", { show_monomorphized: false, show_simplified: true }) {
    Ok(rtlil) => {
      if not(@fs.path_exists(path="output")) {
        @fs.create_dir(path="output")
      }

      @fs.write_string_to_file(path="output/\{file}.rtlil", content=rtlil)
    }
    Err(error) => println(error)
  }
}

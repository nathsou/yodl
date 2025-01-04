
enum Command {
  WriteRTLIL(path~: String?)
  WriteVerilog(path~: String?)
  WriteSource
  WriteMono(path~: String?)
  WriteSimplified(path~: String?)
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

fn run(file: String, commands: Array[Command]) -> Unit! {
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

  for decl in mono_decls {
    checker.check_decl!(decl)

    match simplifier.simplify_decl!(decl) {
      Some(simplified_decl) => {
        simplified_decls.push(simplified_decl)
      }
      None => ()
    }
  }

  let elaborator = @elaborate.Elaborator::new()

  for decl in simplified_decls {
    elaborator.elaborate_decl!(decl)
  }

  fn run_command(command: Command) -> Unit! {
    match command {
      WriteSource => {
        let emitter = @parse.AstEmitter::new()

        for decl in decls {
          emitter.emit_decl(decl)
          emitter.emit("\n")
        }

        println(emitter.to_string())
      }
      WriteMono(path~) => {
        let emitter = @parse.AstEmitter::new()

        for decl in mono_decls {
          emitter.emit_decl(decl)
          emitter.emit("\n")
        }

        let mono = emitter.to_string()

        match path {
          Some(path) => {
            @fs.write_string_to_file(path~, content=mono)
          }
          None => {
            println(mono)
          }
        }
      }
      WriteSimplified(path~) => {
        let emitter = @parse.AstEmitter::new()

        for decl in simplified_decls {
          emitter.emit_decl(decl)
          emitter.emit("\n")
        }

        let simplified = emitter.to_string()

        match path {
          Some(path) => {
            @fs.write_string_to_file(path~, content=simplified)
          }
          None => {
            println(simplified)
          }
        }
      }
      WriteRTLIL(path~) => {
        let rtlil = {
          let serializer = @rtlil.Serializer::new(
            autoidx=elaborator.autoidx,
            modules=elaborator.modules,
          )

          serializer.to_string()
        }

        match path {
          Some(path) => {
            @fs.write_string_to_file(path~, content=rtlil)
          }
          None => {
            println(rtlil)
          }
        }
      }
      WriteVerilog(path~) => {
        let exporter = @verilog.VerilogExporter::new(elaborator.modules.values().collect())
        let verilog_decls = exporter.export!()
        let emitter = @verilog.VerilogEmitter::new()
        emitter.emit_decls(verilog_decls)
        let verilog = emitter.to_string()

        match path {
          Some(path) => {
            @fs.write_string_to_file(path~, content=verilog)
          }
          None => {
            println(verilog)
          }
        }
      }
    }
  }

  for command in commands {
    run_command!(command)
  }
}

fn main {
  match @sys.get_cli_args() {
    [_, _, path] => {
      if not(path.ends_with(".yodl")) {
        println("Input file must have a .yodl extension")
        @sys.exit(1)
      }

      let file_name = path.split("/").last().unwrap().replace(old=".yodl", new="")
      let commands = [
        // WriteSource,
        WriteMono(path=None),
        WriteRTLIL(path=Some("output/\{file_name}.rtlil")),
        // WriteVerilog(path=None),
        WriteVerilog(path=Some("output/\{file_name}.v")),
      ]

      match run?(path, commands) {
        Ok(_) => ()
        Err(error) => {
          println("\x1b[1;31m\{error}")
          @sys.exit(1)
        }
      }
    }
    _ => {
      println("Usage: yodl <file>")
    }
  }
}

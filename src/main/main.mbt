
enum Command {
  WriteRTLIL(path~: String?)
  WriteVerilog(path~: String?)
  WriteSource
  WriteMono(path~: String?)
  WriteTyped
  WriteSimplified(path~: String?)
}

let builtin_decls: Array[@parse.Decl] = {
  let source =
    #|@internal
    #|declare module Reg<Width>(
    #|    clk: logic,
    #|    d: logic[Width],
    #|    en?: logic,
    #|    rst?: logic,
    #|) -> (
    #|    q: logic[Width],
    #|)
    #|
    #|@internal
    #|declare module RegSyncReset<Width>(
    #|    clk: logic,
    #|    d: logic[Width],
    #|    en?: logic,
    #|    rst?: logic,
    #|) -> (
    #|    q: logic[Width],
    #|)
    #|
    #|@internal
    #|declare module RAM<Width, Depth, Init>(
    #|    clk: logic,
    #|    addr: logic[$clog2(Depth)],
    #|    write_enable?: logic,
    #|    data_in?: logic[Width],
    #|) -> (
    #|    data_out: logic[Width],
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
  let decls = parser.parse!()

  for cmd in commands {
    match cmd {
      WriteSource => {
        let emitter = @parse.AstEmitter::new()

        for decl in decls {
          emitter.emit_decl(decl)
          emitter.emit("\n")
        }

        println(emitter.to_string())
      }
      _ => ()
    }
  }

  let monomorphizer = @simplify.Monomorphizer::new()
  let mono_decls = monomorphizer.monomorphize!(builtin_decls + decls)

  for cmd in commands {
    match cmd {
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
      _ => ()
    }
  }

  let checker = @elaborate.TypeChecker::new()

  for decl in mono_decls {
    checker.check_decl!(decl)
  }

  for cmd in commands {
    match cmd {
      WriteTyped => {
        let emitter = @parse.AstEmitter::new(show_expr_types=true)

        for decl in mono_decls {
          emitter.emit_decl(decl)
          emitter.emit("\n")
        }

        println(emitter.to_string())
      }
      _ => ()
    }
  }

  let simplified_decls = @simplify.simplify_decls!(mono_decls)

  for cmd in commands {
    match cmd {
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
      _ => ()
    }
  }

  let elaborator = @elaborate.Elaborator::new()

  for decl in simplified_decls {
    elaborator.elaborate_decl!(decl)
  }

  for cmd in commands {
    match cmd {
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
      _ => ()
    }
  }
}

fn main {
  match @sys.get_cli_args() {
    [_, _, path] => {
      if not(path.ends_with(".yodl")) {
        println("Input file must have a .yodl extension")
        @sys.exit(1)
      }

      if not(@fs.path_exists(path="output/")) {
        @fs.create_dir(path="output/")
      }

      let file_name = path.split("/").last().unwrap().replace(old=".yodl", new="")
      let commands = [
        // WriteSource,
        // WriteMono(path=None),
        // WriteTyped,
        WriteSimplified(path=None),
        WriteRTLIL(path=Some("output/\{file_name}.rtlil")),
        WriteVerilog(path=Some("output/\{file_name}.v")),
      ]

      match run?(path, commands) {
        Ok(_) => ()
        Err(error) => {
          println(error)
          @sys.exit(1)
        }
      }
    }
    _ => {
      println("Usage: yodl <file>")
    }
  }
}


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
    #|declare module Memory<Width, Depth, ReadPorts, WritePorts, Init>(
    #|    clk: logic,
    #|    read_addr: logic[$clog2(Depth) * ReadPorts],
    #|    write_addr: logic[$clog2(Depth) * WritePorts],
    #|    write_enable?: logic[WritePorts],
    #|    data_in?: logic[Width * WritePorts],
    #|) -> (
    #|    data_out: logic[Width * ReadPorts],
    #|)
  
  let lexer = @parse.Lexer::new(source, file="builtin.yodl")
  let tokens = lexer.lex?().unwrap()
  let parser = @parse.Parser::new(tokens, file="builtin.yodl")
  parser.parse?().unwrap()
}

fn run(path~: String, commands~: Array[Command]) -> Unit! {
  if not(path.ends_with(".yodl")) {
    println("Input file must have a .yodl extension")
    @sys.exit(1)
  }

  if not(@fs.path_exists(path="output/")) {
    @fs.create_dir(path="output/")
  }

  let source = @fs.read_file_to_string!(path~)
  let lexer = @parse.Lexer::new(source, file=path)
  let tokens = lexer.lex!()
  let parser = @parse.Parser::new(tokens, file=path)
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
  let mono_decls = monomorphizer.monomorphize!(decls=builtin_decls + decls, packages=[])

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
            modules=@utils.map_keys(elaborator.modules, Show::to_string),
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
      match run?(path~, commands=[WriteRTLIL(path=Some(path.replace(old=".yodl", new=".rtlil")))]) {
        Ok(_) => ()
        Err(error) => {
          println(error)
          @sys.exit(1)
        }
      }
    }
    [_, _, path, cmds] => {
      match parse_commands?(cmds) {
        Ok(commands) => {
          match run?(path~, commands~) {
            Ok(_) => ()
            Err(error) => {
              println(error)
              @sys.exit(1)
            }
          }
        }
        Err(error) => {
          println(error)
          @sys.exit(1)
        }
      }
    }
    _ => {
      println("Usage: yodl <file> [commands]")
    }
  }
}

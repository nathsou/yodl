
fn run(path~: String, commands~: Array[Command]) -> Unit! {
  if not(path.ends_with(".yodl")) {
    println("Input file must have a .yodl extension")
    @sys.exit(1)
  }

  if not(@fs.path_exists(path="output/")) {
    @fs.create_dir(path="output/")
  }

  let resolver = @simplify.Resolver::new!(@utils.dir_name(path))
  let pkg = resolver.resolve!(path~, is_top_package=true)

  for cmd in commands {
    match cmd {
      WriteSource => {
        let emitter = @parse.AstEmitter::new()

        for decl in pkg.body {
          emitter.emit_decl(decl)
          emitter.emit("\n")
        }

        println(emitter.to_string())
      }
      _ => ()
    }
  }

  let monomorphizer = @simplify.Monomorphizer::new()
  let mono_decls = monomorphizer.monomorphize!(decls=pkg.body, packages=[])

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

  let mut design = @utils.map_keys(elaborator.modules, fn(_, mod) { mod.name })

  for cmd in commands {
    match cmd {
      WriteRTLIL(path~) => {
        let rtlil = {
          let serializer = @rtlil.Serializer::new(
            autoidx=elaborator.autoidx,
            modules=@utils.map_keys(design, fn(id, _) { id.to_string() }),
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
        let exporter = @verilog.VerilogExporter::new(design.values().collect())
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
      Flatten => {
        design = @rtlil.FlattenPass::new(design).run()
      }
      _ => ()
    }
  }
}

fn main {
  match @env.args() {
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

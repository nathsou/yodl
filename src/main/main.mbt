
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

  let firrtl = {
    let low = @elaborate.Elaborator::new()
    low.lower!(simplified_decls.iter())
    low.modules
  }

  for cmd in commands {
    match cmd {
      WriteFIRRTL(path~) => {
        let emitter = @firrtl.FIRRTLEmitter::new()
        emitter.emit_circuit({
          version: (4, 1, 0),
          id: Ident("Top"),
          decls: firrtl.values().map(fn(mod) { @firrtl.Decl::Module(mod) }).collect()
        })

        match path {
          Some(path) => {
            @fs.write_string_to_file(path~, content=emitter._.to_string())
          }
          None => {
            println(emitter._.to_string())
          }
        }
      }
      _ => ()
    }
  }
}

fn main {
  match @env.args() {
    [_, _, path] => {
      match run?(path~, commands=[WriteVerilog(path=Some(path.replace(old=".yodl", new=".v")))]) {
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

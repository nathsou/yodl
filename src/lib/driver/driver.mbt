
pub fn run(path~: String, commands~: Array[Command], fs~: @utils.FileSystem) -> Unit! {
  if not(path.ends_with(".yodl")) {
    raise Failure("Input file must have a .yodl extension")
  }

  if not((fs.path_exists)("output/")) {
    (fs.create_dir)!("output/")
  }

  let resolver = @simplify.Resolver::new!(@utils.dir_name(path), fs~)
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
            (fs.write_string_to_file)!(path, mono)
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
            (fs.write_string_to_file)!(path, simplified)
          }
          None => {
            println(simplified)
          }
        }
      }
      _ => ()
    }
  }

  let top = {
    let top_level_pkg_modules = pkg.body.filter_map(fn(decl) {
      match decl {
        Module({ path, params: [], .. }) => Some(path)
        _ => None
      }
    })

    let top_candidates = top_level_pkg_modules.filter(fn(path) { not(monomorphizer.instanciated_modules.contains(path)) })

    match top_candidates {
      [] => raise Failure("No top-level module found")
      [top] => top.member
      _ => {
        if top_candidates.contains(@parse.Path::new([], "Top")) {
          "Top"
        } else {
          raise Failure("Multiple top-level modules found: \{top_candidates}, remove extraneous uninstanciated modules or call the top module `Top`")
        }
      }
    }
  }

  let firrtl = {
    let low = @elaborate.Elaborator::new(top)
    low.lower!(simplified_decls.iter())
    low
  }

  for cmd in commands {
    match cmd {
      WriteFIRRTL(path~) => {
        let emitter = @firrtl.FIRRTLEmitter::new()
        emitter.emit_circuit({
          version: @firrtl.version(),
          id: Ident(firrtl.circuit_name),
          annotations: firrtl.annotations,
          decls: firrtl.modules.values().map(fn(mod) { @firrtl.Decl::Module(mod) }).collect(),
        })

        match path {
          Some(path) => {
            (fs.write_string_to_file)!(path, emitter._.to_string())
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

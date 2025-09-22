
pub fn run(path~: String, commands~: Array[Command], fs~: @utils.FileSystem) -> Unit raise Failure {
  if not(path.has_suffix(".yodl")) {
    raise Failure("Input file must have a .yodl extension")
  }

  if not((fs.path_exists)("output/")) {
    (fs.create_dir)("output/")
  }

  let resolver = match (try? @simplify.Resolver::new(@utils.dir_name(path), fs~)) {
    Err(err) => raise Failure(err.to_string())
    Ok(resolver) => resolver
  }

  let pkg = match (try? resolver.resolve(path~, is_top_package=true)) {
    Err(err) => raise Failure(err.to_string())
    Ok(pkg) => pkg 
  }

  for cmd in commands {
    match cmd {
      WriteSource(path~) => {
        let emitter = @parse.AstEmitter::new()

        for decl in pkg.body {
          emitter.emit_decl(decl)
          emitter.emit("\n")
        }

        let source = emitter.to_string()

        match path {
          Some(path) => {
            (fs.write_string_to_file)(path, source)
          }
          None => {
            println(source)
          }
        }
      }
      _ => ()
    }
  }

  let monomorphizer = @simplify.Monomorphizer::new()
  let mono_decls = match (try? monomorphizer.monomorphize(decls=pkg.body, packages=[])) {
    Err(err) => raise Failure(err.to_string())
    Ok(mono_decls) => mono_decls
  }

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
            (fs.write_string_to_file)(path, mono)
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
    if (try? checker.check_decl(decl)) is Err(err) {
      raise Failure(err.to_string())
    }
  }

  for cmd in commands {
    match cmd {
      WriteTyped(path~) => {
        let emitter = @parse.AstEmitter::new(show_expr_types=true)

        for decl in mono_decls {
          emitter.emit_decl(decl)
          emitter.emit("\n")
        }

        match path {
          Some(path) => {
            (fs.write_string_to_file)(path, emitter.to_string())
          }
          None => {
            println(emitter.to_string())
          }
        }
      }
      _ => ()
    }
  }

  let simplified_decls = match (try? @simplify.simplify_decls(mono_decls)) {
    Err(err) => raise Failure(err.to_string())
    Ok(simplified_decls) => simplified_decls
  }

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
            (fs.write_string_to_file)(path, simplified)
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

    if (try? low.lower(simplified_decls.iter())) is Err(err) {
      raise Failure(err.to_string())
    }

    low
  }

  for cmd in commands {
    match cmd {
      WriteFIRRTL(path~) => {
        let emitter = @firrtl.FIRRTLEmitter::new()
        emitter.emit_circuit({
          version: @firrtl.min_version(),
          id: Ident(firrtl.circuit_name),
          annotations: firrtl.annotations,
          decls: (firrtl.modules.values().map(mod => @firrtl.Decl::Module(mod)) + (firrtl.extmodules.values().map(mod => @firrtl.Decl::ExtModule(mod)))).collect(),
        })

        match path {
          Some(path) => {
            (fs.write_string_to_file)(path, emitter.0.to_string())
          }
          None => {
            println(emitter.0.to_string())
          }
        }
      }
      _ => ()
    }
  }
}

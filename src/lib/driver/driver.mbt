
pub fn run(path~: String, commands~: Array[Command], fs~: @utils.FileSystem) -> Unit raise {
  if !path.has_suffix(".yodl") {
    raise Failure("Input file must have a .yodl extension")
  }

  if !(fs.path_exists)("output/") {
    (fs.create_dir)("output/")
  }

  let resolver = @simplify.Resolver::new(@utils.dir_name(path), fs~)
  let pkg = resolver.resolve(path~, is_top_package=true)

  for cmd in commands {
    if cmd is WriteSource(path~) {
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
  }

  let monomorphizer = @simplify.Monomorphizer::new()
  let mono_decls = monomorphizer.monomorphize(decls=pkg.body, packages=[])

  for cmd in commands {
    if cmd is WriteMono(path~) {
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
  }

  let checker = @elaborate.TypeChecker::new()

  for decl in mono_decls {
    if (try? checker.check_decl(decl)) is Err(err) {
      raise Failure(err.to_string())
    }
  }

  for cmd in commands {
    if cmd is WriteTyped(path~) {
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
  }

  let simplified_decls = @simplify.simplify_decls(mono_decls)

  for cmd in commands {
    if cmd is WriteSimplified(path~) {
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
  }

  let top = {
    let top_level_pkg_modules = pkg.body.filter_map(fn(decl) {
      match decl {
        Module({ path, params: [], .. }) => Some(path)
        _ => None
      }
    })

    let top_candidates = top_level_pkg_modules.filter(fn(path) { !monomorphizer.instanciated_modules.contains(path) })

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
      WriteFIRRTL(path~, passes~) => {
        let circuit = lower_firrtl(firrtl, passes~)
        let emitter = @firrtl.FIRRTLEmitter::new()
        emitter.emit_circuit(circuit)

        match path {
          Some(path) => {
            (fs.write_string_to_file)(path, emitter.0.to_string())
          }
          None => {
            println(emitter.0.to_string())
          }
        }
      }
      WriteRTLIL(path~) => {
        let firrtl_circuit = lower_firrtl(firrtl, passes=[
          @firrtl.ExpandConnectsPass::new(),
          @firrtl.ExpandWhensPass::new(),
          @firrtl.FlattenMemoriesPass::new(),
          @firrtl.LowerAggregateTypesPass::new(split_memories=false),
        ])

        let rtlil_design = @rtlil.lower_circuit(firrtl_circuit, fs~)
        let emitter = @rtlil.Serializer::new(rtlil_design)

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
}

fn lower_firrtl(firrtl: @elaborate.Elaborator, passes~: Array[&@firrtl.FIRRTLPass]) -> @firrtl.TypedCircuit raise {
  let circuit: @firrtl.UntypedCircuit = {
    version: @firrtl.min_version(),
    id: Ident(firrtl.circuit_name),
    annotations: firrtl.annotations,
    decls: {
      let extmodules = firrtl.extmodules.values().map(mod => @firrtl.Decl::ExtModule(mod))
      let modules = firrtl.modules.values().map(mod => @firrtl.Decl::Module(mod))
      (extmodules + modules).collect()
    },
  }

  let circuit: @firrtl.TypedCircuit = @firrtl.type_check_circuit(circuit)
  let mut circ = circuit

  for pass in passes {
    circ = pass.run(circ)
  }

  circ
}

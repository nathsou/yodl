pub fn run(
  path~ : String,
  commands~ : Array[Command],
  ext~ : @utils.Externals,
) -> Unit raise {
  if !path.has_suffix(".yodl") {
    raise Failure::Failure("Input file must have a .yodl extension")
  }

  let fs = ext.fs
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
        Some(path) => (fs.write_string_to_file)(path, source)
        None => (ext.println)(source)
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
        Some(path) => (fs.write_string_to_file)(path, mono)
        None => (ext.println)(mono)
      }
    }
  }

  let checker = @elaborate.TypeChecker::new()

  for decl in mono_decls {
    if (try? checker.check_decl(decl)) is Err(err) {
      raise Failure::Failure(err.to_string())
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
        Some(path) => (fs.write_string_to_file)(path, emitter.to_string())
        None => (ext.println)(emitter.to_string())
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
        Some(path) => (fs.write_string_to_file)(path, simplified)
        None => (ext.println)(simplified)
      }
    }
  }

  let top = {
    let top_level_pkg_modules = pkg.body.filter_map(decl => {
      match decl {
        Module({ path, params: [], .. }) => Some(path)
        _ => None
      }
    })

    let top_candidates = top_level_pkg_modules.filter(path => {
      !monomorphizer.instanciated_modules.contains(path)
    })

    match top_candidates {
      [] => raise Failure::Failure("No top-level module found")
      [top] => top.elem
      _ =>
        if top_candidates.contains(@parse.Path::new([], "Top")) {
          "Top"
        } else {
          raise Failure::Failure(
            "Multiple top-level modules found: \{top_candidates}, remove extraneous uninstanciated modules or rename the top module to `Top`",
          )
        }
    }
  }

  let firrtl = {
    let low = @elaborate.Elaborator::new(top)

    if (try? low.lower(simplified_decls.iter())) is Err(err) {
      raise Failure::Failure(err.to_string())
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
          Some(path) => (fs.write_string_to_file)(path, emitter.0.to_string())
          None => (ext.println)(emitter.0.to_string())
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
          Some(path) => (fs.write_string_to_file)(path, emitter.to_string())
          None => (ext.println)(emitter.to_string())
        }
      }
      _ => ()
    }
  }
}

fn lower_firrtl(firrtl : @elaborate.Elaborator, passes~ : Array[&@firrtl.FIRRTLPass]) -> @firrtl.TypedCircuit raise {
  let circuit : @firrtl.UntypedCircuit = {
    version: @firrtl.min_version(),
    id: Ident(firrtl.circuit_name),
    annotations: firrtl.annotations,
    decls: {
      let extmodules = firrtl.extmodules
        .values()
        .map(mod => @firrtl.Decl::ExtModule(mod))
      let modules = firrtl.modules
        .values()
        .map(mod => @firrtl.Decl::Module(mod))
      (extmodules + modules).collect()
    },
  }

  let circuit : @firrtl.TypedCircuit = @firrtl.type_check_circuit(circuit)
  let mut circ = circuit

  for pass in passes {
    circ = pass.run(circ)
  }

  circ
}


const VERSION: String = "0.2.2"

pub fn cli(ext: @utils.Externals) -> Unit {
  match (ext.get_args)() {
    [_, path] => {
      try run(path~, commands=[WriteFIRRTL(path=Some(path.replace(old=".yodl", new=".fir")), passes=[])], ext~) catch {
        Failure::Failure(error) => {
          (ext.println)("\{error}")
          (ext.exit)(1)
        }
        error => {
          (ext.println)("\{error}")
          (ext.exit)(1)
        }
      }
    }
    [_, path, cmds] => {
      try parse_commands(cmds) catch {
        error => {
          (ext.println)(@debug.to_string(error))
          (ext.exit)(1)
        }
      } noraise {
        commands => {
          try run(path~, commands~, ext~) catch {
            error => {
              (ext.println)("\{error}")
              (ext.exit)(1)
            }
          }
        }
      }
    }
    _ => {
      (ext.println)("Yodl - Yet another hardware description language v\{VERSION}")
      (ext.println)("Usage: yodl <file> [commands]")
      (ext.println)("\nCommands are separated by semicolons ';'. Each command can optionally take a file path argument.")
      (ext.println)("Available commands:")
      (ext.println)("  write_source [path]     - Write the source code after parsing.")
      (ext.println)("  write_mono [path]       - Write the monomorphized code.")
      (ext.println)("  write_typed [path]      - Write the typed code.")
      (ext.println)("  write_simplified [path] - Write the simplified code.")
      (ext.println)("  write_firrtl [path]     - Write the FIRRTL output (alias: write_fir).")
      (ext.println)("  write_low_firrtl [path] - Write the low FIRRTL output (alias: write_lofir).")
      (ext.println)("  write_rtlil [path]      - Write the RTLIL output.")
      (ext.println)("\nExample: yodl my_design.yodl \"write_firrtl my_design.fir; write_typed my_design.typed.txt\"")
    }
  }
}

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
  let pkg = try resolver.resolve(path~, is_top_package=true) catch {
    err => raise Failure::Failure("\{err}")
  }

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
  let mono_decls = try monomorphizer.monomorphize(decls=pkg.body, packages=[]) catch {
    err => raise Failure::Failure(err.to_string())
  }

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
  let resolved_decls = Array::new(capacity=mono_decls.length())

  for decl in mono_decls {
    let resolved = try checker.check_decl(decl) catch {
      err => raise Failure::Failure(err.to_string())
    }
    resolved_decls.push(resolved)
  }

  try checker.finalize() catch {
    err => raise Failure::Failure(err.to_string())
  }

  for cmd in commands {
    if cmd is WriteTyped(path~) {
      let emitter = @parse.AstEmitter::new(show_expr_types=true)

      for decl in resolved_decls {
        emitter.emit_decl(decl)
        emitter.emit("\n")
      }

      match path {
        Some(path) => (fs.write_string_to_file)(path, emitter.to_string())
        None => (ext.println)(emitter.to_string())
      }
    }
  }

  let simplified_decls = @simplify.simplify_decls(resolved_decls)

  for cmd in commands {
    if cmd is WriteSimplified(path~) {
      let emitter = @parse.AstEmitter::new()

      for decl in simplified_decls {
        emitter.emit_core_decl(decl)
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
          let top_str = top_candidates.iter().map(p => p.to_string()).join(", ")
          raise Failure::Failure(
            "Multiple top-level modules found: [\{top_str}], remove extraneous uninstanciated modules or rename the top module to `Top`",
          )
        }
    }
  }

  let firrtl = {
    let low = @elaborate.Elaborator::new(top, port_usage=checker.port_usage())

    try low.lower(simplified_decls.iter()) catch {
      err => raise Failure::Failure(err.to_string())
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
  let mut circ = @firrtl.CleanupPass::new().run(circuit)

  for pass in passes {
    circ = pass.run(circ)
  }

  circ
}

/// Compile a Yodl source file to the normalized FIRRTL consumed by the
/// simulator.  This intentionally returns the in-memory typed circuit instead
/// of serializing and reparsing FIRRTL, so source tools and testbenches share
/// exactly the same elaboration and lowering semantics as the CLI.
pub fn compile_simulation(
  path~: String,
  ext~: @utils.Externals,
  top~: String? = None,
  displays~: Array[SimulationDisplay] = [],
) -> @firrtl.TypedCircuit raise {
  if !path.has_suffix(".yodl") {
    raise Failure::Failure("Input file must have a .yodl extension")
  }

  let resolver = @simplify.Resolver::new(@utils.dir_name(path), fs=ext.fs)
  let pkg = try resolver.resolve(path~, is_top_package=true) catch {
    err => raise Failure::Failure("\{err}")
  }
  let monomorphizer = @simplify.Monomorphizer::new()
  let mono_decls = try monomorphizer.monomorphize(decls=pkg.body, packages=[]) catch {
    err => raise Failure::Failure(err.to_string())
  }
  let checker = @elaborate.TypeChecker::new()
  let resolved_decls = Array::new(capacity=mono_decls.length())
  for decl in mono_decls {
    let resolved = try checker.check_decl(decl) catch {
      err => raise Failure::Failure(err.to_string())
    }
    resolved_decls.push(resolved)
  }
  try checker.finalize() catch {
    err => raise Failure::Failure(err.to_string())
  }
  let simplified_decls = @simplify.simplify_decls(resolved_decls)
  let inferred_top = if top is Some(_) {
    ""
  } else {
    let candidates = pkg.body.filter_map(decl => {
      match decl {
        @parse.Decl::Module({ path, params: [], .. }) => Some(path)
        _ => None
      }
    }).filter(path => !monomorphizer.instanciated_modules.contains(path))
    match candidates {
      [] => raise Failure::Failure("No top-level module found")
      [top] => top.elem
      _ =>
        if candidates.contains(@parse.Path::new([], "Top")) {
          "Top"
        } else {
          let names = candidates.iter().map(p => p.to_string()).join(", ")
          raise Failure::Failure(
            "Multiple top-level modules found: [\{names}], remove extraneous uninstanciated modules or rename the top module to `Top`",
          )
        }
    }
  }
  let top = top.unwrap_or(inferred_top)
  let elaborator = @elaborate.Elaborator::new(top, port_usage=checker.port_usage())
  try elaborator.lower(simplified_decls.iter()) catch {
    err => raise Failure::Failure(err.to_string())
  }
  let circuit = lower_firrtl(elaborator, passes=[])
  let pass = @firrtl.LowerAggregateTypesPass::new(split_memories=false, packed_bool_rows=true)
  let lowered = pass.prepare_simulation(circuit)
  let candidates = circuit.decls.filter_map(decl => match decl {
    @firrtl.Decl::Module(mod) if mod.id.inner() == top || mod.id.inner().has_suffix("_" + top) => Some(mod)
    _ => None
  })
  let mut selected = if candidates.length() == 1 { Some(candidates[0]) } else { None }
  for mod in candidates {
    if mod.id.inner() == top { selected = Some(mod) }
  }
  if selected is Some(mod) {
    for port in mod.ports {
      if port.dir is @parse.PortDir::Output &&
        port.ty is @firrtl.Type::Vec(@firrtl.Type::Vec(@firrtl.Type::UInt(bits), width), height) {
        let ports = []
        for row in 0..<height {
          let row_ref = @firrtl.Reference::StaticIndexing(lhs=@firrtl.Reference::Id(port.id, ty=port.ty), index=row, ty=@firrtl.Type::Vec(@firrtl.Type::UInt(bits), width))
          if bits == 1 {
            ports.push(pass.lowered_name(mod.id.inner(), row_ref).unwrap_or_error(Failure::Failure("Missing packed display row")))
          } else {
            for col in 0..<width {
              let reference = @firrtl.Reference::StaticIndexing(lhs=row_ref, index=col, ty=@firrtl.Type::UInt(bits))
              ports.push(pass.lowered_name(mod.id.inner(), reference).unwrap_or_error(Failure::Failure("Missing display element")))
            }
          }
        }
        displays.push({ buffer: port.id.inner(), width, height, bits, ports })
      }
    }
  }
  lowered
}

pub(all) struct SimulationDisplay {
  buffer: String
  width: Int
  height: Int
  bits: Int
  ports: Array[String]
}

pub(all) struct SimulationDesign {
  circuit: @firrtl.TypedCircuit
  displays: Array[SimulationDisplay]
}

pub fn compile_simulation_design(path~: String, ext~: @utils.Externals, top~: String? = None) -> SimulationDesign raise {
  let displays = []
  let circuit = compile_simulation(path~, ext~, top~, displays~)
  { circuit, displays }
}

/// Return the `@simulation` attribute attached to a source module as flat
/// key/value pairs. Hosts use this descriptor instead of trying to reparse
/// Yodl syntax in another language.
pub fn simulation_metadata(
  path~: String,
  ext~: @utils.Externals,
  top~: String? = None,
) -> Array[(String, String)] raise {
  let resolver = @simplify.Resolver::new(@utils.dir_name(path), fs=ext.fs)
  let pkg = try resolver.resolve(path~, is_top_package=true) catch {
    err => raise Failure::Failure(err.to_string())
  }
  let result : Array[(String, String)] = []
  for decl in pkg.body {
    match decl {
      @parse.Decl::Module({ path, attributes, .. }) => {
        match attributes.get("simulation") {
          Some({ args: [@parse.AttributeValue::Dict(values)], span, .. }) => {
            let mut metadata_top = path.elem
            match values.get("top") {
              Some(@parse.AttributeValue::String(name)) => metadata_top = name
              _ => ()
            }
            if top.map(name => name != metadata_top).unwrap_or(false) {
              continue
            }
            result.push(("module", path.elem))
            result.push(("location", span.to_string()))
            for key, value in values {
              if !["top", "clock", "reset", "display", "cycles_per_frame", "clock_hz"].contains(key) {
                raise Failure::Failure("Unknown @simulation option '\{key}' at \{span}")
              }
              if key == "display" {
                match value {
                  @parse.AttributeValue::Dict(fields) => {
                    if !fields.contains("buffer") && !fields.contains("stream") {
                      raise Failure::Failure("display requires a buffer or stream at \{span}")
                    }
                  }
                  _ => raise Failure::Failure("display must be an object at \{span}")
                }
              }
              flatten_simulation_metadata(value, key, result~)
            }
            return result
          }
          _ => ()
        }
      }
      _ => ()
    }
  }
  result
}

fn flatten_simulation_metadata(
  value: @parse.AttributeValue,
  prefix: String,
  result~: Array[(String, String)],
) -> Unit {
  match value {
    @parse.AttributeValue::String(value) => result.push((prefix, value))
    @parse.AttributeValue::Int(value) => result.push((prefix, value.to_string()))
    @parse.AttributeValue::Dict(values) => {
      for key, value in values {
        flatten_simulation_metadata(value, prefix + "." + key, result~)
      }
    }
  }
}


const VERSION: String = "0.3.1"

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

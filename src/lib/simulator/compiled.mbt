/// Immutable execution program shared by every instance of a module.
struct CompiledModule {
  design: TypedModule
  program: Array[SimStmt]
  commands: Array[SimCommand]
}

/// Opaque, validated input for execution. Runtime construction allocates only
/// mutable state; normalization and FIRRTL-to-simulator compilation happen
/// here exactly once.
pub struct CompiledSimulation {
  circuit: TypedCircuit
  top: String
  modules: Map[String, CompiledModule]
  primitive_models: Map[String, PrimitiveModel]
}

pub fn compile_simulation(circuit: TypedCircuit, top: String) -> CompiledSimulation raise SimulatorError {
  compile_prepared_simulation(prepare_simulation_circuit(circuit), top)
}

/// Compiler-owned entry point for FIRRTL which has already passed the
/// simulator normalization pipeline. This prevents browser compilation from
/// normalizing once in the driver and again in the simulator package.
pub fn compile_prepared_simulation(circuit: TypedCircuit, top: String) -> CompiledSimulation raise SimulatorError {
  compile_prepared_simulation_with_models(circuit, top, Map([]))
}

fn compile_simulation_with_models(
  circuit: TypedCircuit,
  top: String,
  primitive_models: Map[String, PrimitiveModel],
) -> CompiledSimulation raise SimulatorError {
  compile_prepared_simulation_with_models(prepare_simulation_circuit(circuit), top, primitive_models)
}

fn compile_prepared_simulation_with_models(
  circuit: TypedCircuit,
  top: String,
  primitive_models: Map[String, PrimitiveModel],
) -> CompiledSimulation raise SimulatorError {
  let modules: Map[String, CompiledModule] = Map([])
  for decl in circuit.decls {
    match decl {
      @firrtl.Decl::Module(design) => {
        let design = { ..design, body: order_simulation_body(design.body) }
        validate_simulation_module(design)
        modules[design.id.inner()] = {
          design,
          program: design.body.map(compile_stmt),
          commands: compile_commands(design),
        }
      }
      @firrtl.Decl::ExtModule(ext) => {
        if !primitive_models.contains(ext.id.inner()) {
          raise Unsupported(message="external module '{ext.id.inner()}' has no simulation model")
        }
        let design: TypedModule = { public: false, id: ext.id, ports: ext.ports, body: [] }
        modules[ext.id.inner()] = { design, program: [], commands: [] }
      }
    }
  }
  let requested = if top.is_empty() { circuit.id.inner() } else { top }
  let selected = if modules.contains(requested) {
    requested
  } else {
    let suffix = "_" + requested
    let matches = modules.keys().filter(name => name.has_suffix(suffix)).collect()
    match matches {
      [name] => name
      _ => raise MissingSignal(name="top module " + requested)
    }
  }
  { circuit, top: selected, modules, primitive_models }
}

pub fn Simulator::from_compiled(compiled: CompiledSimulation) -> Simulator raise SimulatorError {
  Simulator::from_compiled_design(compiled)
}

/// Immutable, validated input for an execution instance. Runtime instances
/// share this prepared circuit and only allocate mutable signal/state maps.
pub struct CompiledSimulation {
  circuit: TypedCircuit
  top: String
}

pub fn compile_simulation(circuit: TypedCircuit, top: String) -> CompiledSimulation raise SimulatorError {
  let circuit = prepare_simulation_circuit(circuit)
  let selected = if top.is_empty() { circuit.id.inner() } else { top }
  let exists = circuit.decls.iter().any(decl => match decl {
    @firrtl.Decl::Module(mod) => mod.id.inner() == selected || mod.id.inner().has_suffix("_" + selected)
    @firrtl.Decl::ExtModule(_) => false
  })
  if !exists { raise MissingSignal(name="top module " + selected) }
  { circuit, top: selected }
}

pub fn Simulator::from_compiled(compiled: CompiledSimulation) -> Simulator raise SimulatorError {
  Simulator::from_prepared_circuit(compiled.circuit, compiled.top, Map([]))
}

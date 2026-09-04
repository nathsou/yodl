/// Normalize ordered assignments and aggregate memories before simulator lowering.
/// The caller retains the lowering pass to translate source display port names.
pub fn LowerAggregateTypesPass::prepare_simulation(self: LowerAggregateTypesPass, circuit: TypedCircuit) -> TypedCircuit raise {
  for annotation in circuit.annotations {
    if annotation is MemoryFileInlineAnnotation(target~, filename~, ..) {
      raise Failure::Failure("Simulation does not support readmemh/readmemb initialization for \{target} from '\{filename}'")
    }
  }
  let circuit = FIRRTLPass::run(FlattenMemoriesPass::new(), circuit)
  let circuit = FIRRTLPass::run(ExpandConnectsPass::new(), circuit)
  let circuit = FIRRTLPass::run(ExpandWhensPass::new(), circuit)
  FIRRTLPass::run(self, circuit)
}

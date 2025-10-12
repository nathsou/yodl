pub struct ExpandWhensPass(Unit)

pub fn ExpandWhensPass::new() -> Self {
  ExpandWhensPass(())
}

pub impl FIRRTLPass for ExpandWhensPass with run(_: ExpandWhensPass, circuit) -> Circuit raise {
  {
    ..circuit,
    decls: circuit.decls.map(decl => {
      match decl {
        Module(mod) => Module(rewrite_module(mod))
        ExtModule(extmod) => ExtModule(extmod)
      }
    })
  }
}

typealias Map[Reference, Expr?] as ScopeMap

fn rewrite_module(mod: Module) -> Module raise {
  // Track last connection to each destination
  let module_scope: ScopeMap = {}

  for port in mod.ports {
    if port.flow is (Output | Inout) {
      module_scope[Id(port.id)] = None
    }
  }

  let result_body = []
  // Process module body
  process_block(block=mod.body, result=result_body, module_scope~, scope=module_scope, condition=None)
  
  // Check for incomplete initialisation and add final connections
  for dest, conn_opt in module_scope {
    match conn_opt {
      Some(conn) => result_body.push(Connect(dest, conn))
      None => raise Failure("Port '\{mod.id}.\{dest}' not fully initialised")
    }
  }

  { ..mod, body: result_body }
}

fn process_block(
  block~: Array[Stmt],
  result~: Array[Stmt],
  module_scope~: ScopeMap,
  scope~: ScopeMap,
  condition~: Expr?,
) -> Unit raise {
  for stmt in block {
    match stmt {
      // Track declarations that need connections
      Wire(id~, ty~) => {
        scope.declare_sinks(reference=Id(id), ty~, flow=Input)
        result.push(stmt)
      }
      Reg(id~, ..) | RegReset(id~, ..) => {
        // registers are initialised to themselves
        // TODO: registers of bundle type are not supported.
        let reference = Id(id)
        scope[reference] = Some(Reference(reference))
        result.push(stmt)
      }
      Inst(id~, sig~, ..) => {
        // Track input ports
        for field, port in sig.ports {
          scope.declare_sinks(
            reference=FieldAccess(lhs=Id(id), field=Id::from(field)),
            ty=port.ty,
            flow=port.flow.swap(),
          )
        }

        result.push(stmt)
      }
      Mem(id~, data_type~, readers~, writers~, depth~, ..) => {
        // Track memory input ports
        let reference = Id(id)
        let { reader_type, writer_type } = data_type.mem_reader_writer_types(depth~) 

        for reader in readers {
          scope.declare_sinks(
            reference=FieldAccess(lhs=reference, field=reader),
            ty=reader_type,
            flow=Input,
          )
        }

        for writer in writers {
          scope.declare_sinks(
            reference=FieldAccess(lhs=reference, field=writer),
            ty=writer_type,
            flow=Input,
          )
        }

        result.push(stmt)
      }
      // Handle connections with last connect semantics
      Connect(dest, src) => {
        scope[dest] = Some(src)
      }
      // Expand when statements
      When(when) => {
        expand_whens(
          when~,
          parent_result=result,
          module_scope~,
          outer_condition=condition,
        )
      }
      Command(cmd) => {
        result.push(Command(cmd.replace_en(en => and_conditions(condition, en))))
      }
      // Pass through other statements
      _ => {
        result.push(stmt)
      }
    }
  }
}

fn ScopeMap::declare_sinks(self: ScopeMap, reference~: Reference, ty~: Type, flow~: @parse.Flow) -> Unit {
  if ty is Bundle(fields) {
    for field in fields {
      self.declare_sinks(
        reference=FieldAccess(lhs=reference, field=field.id),
        ty=field.ty,
        flow=if field.flip { flow.swap() } else { flow },
      )
    }
  } else {
    if flow is (Output | Inout) && !self.contains(reference) {
      self[reference] = None
    }
  }
}

fn and_conditions(outer: Expr?, inner: Expr) -> Expr {
  match outer {
    None => inner
    Some(cond) => PrimOp(op=And, args=[cond, inner])
  }
}

fn expand_whens(when~: When, parent_result~: Array[Stmt], module_scope~: ScopeMap, outer_condition~: Expr?) -> Unit raise {
  // Move non-connect statements to parent
  let then_cond = and_conditions(outer_condition, when.cond)
  let then_scope: ScopeMap = {}
  let then_stmts: Array[Stmt] = []
  process_block(
    block=when.body,
    result=then_stmts,
    module_scope~,
    scope=then_scope,
    condition=Some(then_cond),
  )
  
  // Move non-connect statements to parent
  for stmt in then_stmts {
    if !(stmt is Connect(_)) {
      parent_result.push(stmt) 
    }
  }

  // Process else block if present
  let else_scope: ScopeMap = {}

  if when.otherwise is Some(else_body) {
    let else_stmts: Array[Stmt] = []
    let else_cond = and_conditions(outer_condition, PrimOp(op=Not, args=[when.cond]))
    process_block(
      block=else_body,
      result=else_stmts,
      module_scope~,
      scope=else_scope,
      condition=Some(else_cond),
    )

    // Move non-connect statements to parent
    for stmt in else_stmts {
      if !(stmt is Connect(_)) {
        parent_result.push(stmt) 
      }
    }
  }

  merge_scopes(
    outer_scope=module_scope,
    then_scope~,
    else_scope~,
    condition=and_conditions(outer_condition, when.cond),
  )
}

fn merge_scopes(
  outer_scope~: ScopeMap,
  then_scope~: ScopeMap,
  else_scope~: ScopeMap,
  condition~: Expr,
) -> Unit raise {
  let all_refs = Set::from_iter(then_scope.keys() + else_scope.keys())

  for reference in all_refs {
    let then_conn = then_scope.get(reference).flatten()
    let else_conn = else_scope.get(reference).flatten()
    let outer_conn = outer_scope.get(reference).flatten()

    match (then_conn, else_conn, outer_conn) {
      (Some(then_conn), Some(else_conn), _) => {
        // connected in both branches
        outer_scope[reference] = Some(Mux(cond=condition, tval=then_conn, fval=else_conn))
      }
      (Some(then_conn), None, Some(outer_conn)) => {
        // connected in then branch and previously
        outer_scope[reference] = Some(Mux(cond=condition, tval=then_conn, fval=outer_conn))
      }
      (None, Some(else_conn), Some(outer_conn)) => {
        // connected in else branch and previously
        outer_scope[reference] = Some(Mux(cond=PrimOp(op=Not, args=[condition]), tval=else_conn, fval=outer_conn))
      }
      (Some(_), None, None) | (None, Some(_), None) | (None, None, Some(_)) | (None, None, None) => {
        // connected in one branch only
        raise Failure("Port '\{reference}' not fully initialised")
      }
    }
  }
}

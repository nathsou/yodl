
pub struct ExpandWhensPass(Unit)

pub fn ExpandWhensPass::new() -> Self {
  ExpandWhensPass(())
}

pub impl FIRRTLPass for ExpandWhensPass with run(_, circuit) -> TypedCircuit raise {
  {
    ..circuit,
    decls: circuit.decls.map(decl => {
      match decl {
        Module(mod) => Module(ExpandWhensPass::rewrite_module(mod))
        ExtModule(extmod) => ExtModule(extmod)
      }
    })
  }
}

// Supporting arbitrary dynamic indexing would make initialisation analysis undecidable
impl[T] Hash for Reference[T] with hash_combine(self, hasher) {
  match self {
    Id(id) => id.hash_combine(hasher)
    StaticIndexing(lhs~, index~) => {
      lhs.hash_combine(hasher)
      hasher.combine_int(index)
    }
    DynamicIndexing(..) => {
      @utils.fail("Dynamic indexing is not supported in hashing")
    }
    FieldAccess(lhs~, field~) => {
      lhs.hash_combine(hasher)
      field.hash_combine(hasher)
    }
  }
}

impl[T] Eq for Reference[T] with equal(self, other) {
  match (self, other) {
    (Id(id1), Id(id2)) => id1 == id2
    (StaticIndexing(lhs=lhs1, index=idx1), StaticIndexing(lhs=lhs2, index=idx2)) => lhs1 == lhs2 && idx1 == idx2
    (DynamicIndexing(..), DynamicIndexing(..)) => @utils.fail("Dynamic indexing is not supported in equality")
    (FieldAccess(lhs=lhs1, field=field1), FieldAccess(lhs=lhs2, field=field2)) => lhs1 == lhs2 && field1 == field2
    _ => false
  }
}

typealias Map[TypedReference, TypedExpr?] as ScopeMap

fn ExpandWhensPass::rewrite_module(mod: TypedModule) -> TypedModule raise {
  // Track last connection to each destination
  let module_scope: ScopeMap = {}

  for port in mod.ports {
    if port.flow is (Output | Inout) {
      module_scope.declare_sinks(reference=Id(port.id), ty=port.ty, flow=port.flow)
    }
  }

  // Process module body
  let body_stmts = ExpandWhensPass::process_block(block=mod.body, module_scope~, scope=module_scope, condition=None)
  let not_fully_init = []

  // Check for incomplete initialisation and add final connections
  for dest, conn_opt in module_scope {
    match conn_opt {
      Some(conn) => body_stmts.push(Connect(dest, conn))
      None => not_fully_init.push(dest)
    }
  }

  if not_fully_init.length() > 0 {
    raise Failure("The following wires are not fully initialised: \{not_fully_init}")
  }

  { ..mod, body: body_stmts }
}

fn ExpandWhensPass::process_block(
  block~: Array[TypedStmt],
  module_scope~: ScopeMap,
  scope~: ScopeMap,
  condition~: TypedExpr?,
) -> Array[TypedStmt] raise {
  let stmts: Array[TypedStmt] = []

  for stmt in block {
    match stmt {
      // Track declarations that need connections
      Wire(id~, ty~) => {
        scope.declare_sinks(reference=Id(id), ty~, flow=Input)
        stmts.push(stmt)
      }
      Reg(id~, ty~, ..) | RegReset(id~, ty~, ..) => {
        // registers are initialised to themselves
        // TODO: registers of bundle type are not supported.
        let reference = Id(id)
        scope[reference] = Some(Reference(reference~, ty~))
        stmts.push(stmt)
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

        stmts.push(stmt)
      }
      Mem({id, readers, writers, readwriters, ..} as mem) => {
        // Track memory input ports
        let reference = Id(id)
        let ports = mem.reader_writer_types()

        for reader in readers {
          scope.declare_sinks(
            reference=FieldAccess(lhs=reference, field=reader),
            ty=ports.read,
            flow=Output,
          )
        }

        for writer in writers {
          scope.declare_sinks(
            reference=FieldAccess(lhs=reference, field=writer),
            ty=ports.write,
            flow=Input,
          )
        }

        for rw in readwriters {
          scope.declare_sinks(
            reference=FieldAccess(lhs=reference, field=rw),
            ty=ports.read_write,
            flow=Inout,
          )
        }

        stmts.push(stmt)
      }
      // Handle unconditional connections with last connect semantics
      Connect(dest, src) => {
        scope[dest] = Some(src)
      }
      // Expand when statements
      When(when) => {
        ExpandWhensPass::expand_whens(
          when~,
          parent_result=stmts,
          module_scope~,
          outer_condition=condition,
        )
      }
      Command(cmd) => {
        stmts.push(Command(cmd.replace_en(en => and_conditions(condition, en))))
      }
      // Pass through other statements
      _ => {
        stmts.push(stmt)
      }
    }
  }

  stmts
}

fn ScopeMap::declare_sinks(self: ScopeMap, reference~: TypedReference, ty~: Type, flow~: @parse.Flow) -> Unit {
  match ty {
    Bundle(fields) => {
      for field in fields {
        self.declare_sinks(
          reference=FieldAccess(lhs=reference, field=field.id),
          ty=field.ty,
          flow=if field.flip { flow.swap() } else { flow },
        )
      }
    }
    Vec(elem_ty, size) => {
      for i in 0 ..<size {
        self.declare_sinks(
          reference=StaticIndexing(lhs=reference, index=i),
          ty=elem_ty,
          flow~,
        )
      }
    }
    _ => {
      if flow is (Output | Inout) && !self.contains(reference) {
        self[reference] = None
      }
    }
  }
}

fn and_conditions(outer: TypedExpr?, inner: TypedExpr) -> TypedExpr {
  match outer {
    None => inner
    Some(cond) => PrimOp(op=And, args=[cond, inner], ty=Type::bool())
  }
}

fn ExpandWhensPass::expand_whens(
  when~: When[TypedExpr],
  parent_result~: Array[TypedStmt],
  module_scope~: ScopeMap,
  outer_condition~: TypedExpr?
) -> Unit raise {
  // Move non-connect statements to parent
  let then_cond = and_conditions(outer_condition, when.cond)
  let then_scope: ScopeMap = {}
  let then_stmts = ExpandWhensPass::process_block(
    block=when.body,
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
    let else_cond = and_conditions(outer_condition, PrimOp(op=Not, args=[when.cond], ty=Type::bool()))
    let else_stmts = ExpandWhensPass::process_block(
      block=else_body,
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

  ExpandWhensPass::merge_scopes(
    outer_scope=module_scope,
    then_scope~,
    else_scope~,
    condition=and_conditions(outer_condition, when.cond),
  )
}

fn ExpandWhensPass::merge_scopes(
  outer_scope~: ScopeMap,
  then_scope~: ScopeMap,
  else_scope~: ScopeMap,
  condition~: TypedExpr,
) -> Unit {
  let all_refs = Set::from_iter(then_scope.keys() + else_scope.keys())

  for reference in all_refs {
    let then_conn = then_scope.get(reference).flatten()
    let else_conn = else_scope.get(reference).flatten()
    let outer_conn = outer_scope.get(reference).flatten()

    match (then_conn, else_conn, outer_conn) {
      (Some(then_conn), Some(else_conn), _) => {
        // connected in both branches
        outer_scope[reference] = Some(Mux(cond=condition, tval=then_conn, fval=else_conn, ty=then_conn.ty()))
      }
      (Some(then_conn), None, Some(outer_conn)) => {
        // connected in then branch and previously
        outer_scope[reference] = Some(Mux(cond=condition, tval=then_conn, fval=outer_conn, ty=then_conn.ty()))
      }
      (None, Some(else_conn), Some(outer_conn)) => {
        // connected in else branch and previously
        let cond = TypedExpr::PrimOp(op=Not, args=[condition], ty=Type::bool())
        outer_scope[reference] = Some(Mux(cond~, tval=else_conn, fval=outer_conn, ty=else_conn.ty()))
      }
      (Some(then_conn), None, None) => {
        // declared and connected in then branch only
        outer_scope[reference] = Some(then_conn)
      }
      (None, Some(else_conn), None) => {
        // declared and connected in else branch only
        outer_scope[reference] = Some(else_conn)
      }
      (None, None, _) => ()
    }
  }
}

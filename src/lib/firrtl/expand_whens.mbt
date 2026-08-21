
struct ExpandWhensPass {
  scopes: ScopeStack
}

pub fn ExpandWhensPass::new() -> Self {
  { scopes: ScopeStack::new() }
}

pub impl FIRRTLPass for ExpandWhensPass with run(self, circuit) -> TypedCircuit raise {
  {
    ..circuit,
    decls: circuit.decls.map(decl => {
      match decl {
        Module(mod) => Module(self.rewrite_module(mod))
        ExtModule(extmod) => ExtModule(extmod)
      }
    })
  }
}

fn ExpandWhensPass::rewrite_module(self: Self, mod: TypedModule) -> TypedModule raise {
  // Track last connection to each destination
  let module_scope: DriverMap = Map([])

  for port in mod.ports {
    if port.dir is (Output | InOut) {
      module_scope.declare_sinks(reference=Id(port.id, ty=port.ty), flow=match port.dir { Input => Source; _ => Sink })
    }
  }

  self.scopes.push(module_scope)

  // Process module body
  let body_stmts = self.process_block(block=mod.body, condition=ConditionStack::new())
  let not_fully_init: Array[TypedRef] = []

  // Check for incomplete initialisation and add final connections
  for dest, conn_opt in module_scope {
    match conn_opt {
      Some(conn) => {
        // avoid cyclical connections
        if !(conn is Reference(r, ..) && r == dest) {
          body_stmts.push(Connect(dest, conn))
        }
      }
      None => not_fully_init.push(dest)
    }
  }

  if not_fully_init.length() > 0 {
    let not_fully_init_str = not_fully_init.iter().map(r => Show::to_string(r)).join(", ")
    raise Failure::Failure("The following wires are not fully initialised: [\{not_fully_init_str}]")
  }

  self.scopes.pop()

  { ..mod, body: body_stmts }
}

fn ExpandWhensPass::process_block(self: Self, block~: Array[TypedStmt], condition~: ConditionStack) -> Array[TypedStmt] raise {
  let stmts: Array[TypedStmt] = []
  let scope = self.scopes.unsafe_top()

  for stmt in block {
    match stmt {
      // Track declarations that need connections
      Wire(id~, ty~) => {
        scope.declare_sinks(reference=Id(id, ty~), flow=Duplex)
        stmts.push(stmt)
      }
      Reg(id~, ty~, ..) | RegReset(id~, ty~, ..) => {
        // registers are initialised to themselves
        // TODO: registers of bundle type are not supported.
        let reference = Id(id, ty~)
        scope[reference] = Some(Reference(reference, ty~))
        stmts.push(stmt)
      }
      Inst(id~, sig~, ..) => {
        // Track input ports
        for field, port in sig.ports {
          scope.declare_sinks(
            reference=FieldAccess(lhs=Id(id, ty=sig.as_bundle()), field=Id::from(field), ty=port.ty),
            flow=match port.dir { Output => Source; _ => Sink },
          )
        }

        stmts.push(stmt)
      }
      Mem({id, writers, readwriters, ..} as mem) => {
        // Track memory input ports
        let reference = Id(id, ty=mem.as_bundle())
        let ports = mem.reader_writer_types()

        for writer in writers {
          scope.declare_sinks(
            reference=FieldAccess(lhs=reference, field=writer, ty=ports.write),
            flow=Sink,
          )
        }

        for rw in readwriters {
          scope.declare_sinks(
            reference=FieldAccess(lhs=reference, field=rw, ty=ports.read_write),
            flow=Sink,
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
        self.expand_whens(
          when~,
          parent_result=stmts,
          outer_condition=condition,
        )
      }
      Command(cmd) => {
        stmts.push(Command(cmd.replace_en(en => condition.anded_with(en).as_expr())))
      }
      // Pass through other statements
      _ => {
        stmts.push(stmt)
      }
    }
  }

  stmts
}

fn DriverMap::declare_sinks(self: DriverMap, reference~: TypedRef, flow~: Flow) -> Unit {
  match reference.ty() {
    Bundle(fields) => {
      for field in fields {
        self.declare_sinks(
          reference=FieldAccess(lhs=reference, field=field.id, ty=field.ty),
          flow=if field.flip { flow.swap() } else { flow },
        )
      }
    }
    Vec(elem_ty, size) => {
      for i in 0 ..<size {
        self.declare_sinks(
          reference=StaticIndexing(lhs=reference, index=i, ty=elem_ty),
          flow~,
        )
      }
    }
    _ => {
      // If it is a leaf node with Flow::Sink or Flow::Duplex, it must be initialised.
      if flow != Source && !self.contains(reference) {
        self[reference] = None
      }
    }
  }
}

fn ExpandWhensPass::expand_whens(
  self: Self,
  when~: TypedWhen,
  parent_result~: Array[TypedStmt],
  outer_condition~: ConditionStack,
) -> Unit raise {
  // Move non-connect statements to parent
  let then_cond = outer_condition.anded_with(when.cond)
  let then_scope: DriverMap = Map([])
  self.scopes.push(then_scope)
  let then_stmts = self.process_block(block=when.body, condition=then_cond)
  self.scopes.pop()

  // Move non-connect statements to parent
  for stmt in then_stmts {
    if !(stmt is Connect(_)) {
      parent_result.push(stmt) 
    }
  }

  // Process else block if present
  let else_scope: DriverMap = Map([])

  if when.otherwise is Some(else_body) {
    let else_cond = outer_condition.anded_with(PrimOp(op=Not, args=[when.cond], ty=Type::bool()))
    self.scopes.push(else_scope)
    let else_stmts = self.process_block(block=else_body, condition=else_cond)
    self.scopes.pop()

    // Move non-connect statements to parent
    for stmt in else_stmts {
      if !(stmt is Connect(_)) {
        parent_result.push(stmt) 
      }
    }
  }

  self.merge_scopes(
    then_scope~,
    else_scope~,
    condition=then_cond,
  )
}

fn ExpandWhensPass::merge_scopes(
  self: Self,
  then_scope~: DriverMap,
  else_scope~: DriverMap,
  condition~: ConditionStack,
) -> Unit {
  let all_refs = Set::from_iter(then_scope.keys() + else_scope.keys())
  let outer_scope = self.scopes.unsafe_top()

  for reference in all_refs {
    let then_conn = then_scope.get(reference).bind(x => x)
    let else_conn = else_scope.get(reference).bind(x => x)
    let outer_conn = self.scopes.lookup(reference)

    match (then_conn, else_conn, outer_conn) {
      (Some(then_conn), Some(else_conn), _) => {
        // connected in both branches
        outer_scope[reference] = Some(Mux(cond=condition.as_expr(), tval=then_conn, fval=else_conn, ty=then_conn.ty()))
      }
      (Some(then_conn), None, Found(Some(outer_conn))) => {
        // connected in then branch and previously
        outer_scope[reference] = Some(Mux(cond=condition.as_expr(), tval=then_conn, fval=outer_conn, ty=then_conn.ty()))
      }
      (None, Some(else_conn), Found(Some(outer_conn))) => {
        // connected in else branch and previously
        outer_scope[reference] = Some(Mux(cond=condition.as_expr(), tval=outer_conn, fval=else_conn, ty=else_conn.ty()))
      }
      (Some(conn), None, NotFound) | (None, Some(conn), NotFound) => {
        // declared and connected in one branch only
        // this reference is only accessible within the branch
        // so we can safely convert it to an unconditional connection
        outer_scope[reference] = Some(conn)
      }
      (None, None, _) | (_, _, Found(None)) => ()
    }
  }
}

// internal data structures

type DriverMap = Map[TypedRef, TypedExpr?]

priv struct ScopeStack {
  scopes: Array[DriverMap]
}

fn ScopeStack::new() -> Self {
  { scopes: [] }
}

fn ScopeStack::push(self: Self, scope: DriverMap) -> Unit {
  self.scopes.push(scope)
}

fn ScopeStack::pop(self: Self) -> Unit {
  let _ = self.scopes.pop()
}

fn ScopeStack::unsafe_top(self: Self) -> DriverMap {
  guard self.scopes.length() > 0 else {
    @utils.fail("ScopeStack is empty")
  }

  self.scopes[self.scopes.length() - 1]
}

priv enum ScopeStackLookupResult {
  Found(TypedExpr?)
  NotFound
}

fn ScopeStack::lookup(self: Self, reference: TypedRef) -> ScopeStackLookupResult {
  for i = self.scopes.length() - 1; i >= 0; i = i - 1 {
    let scope = self.scopes[i]

    if scope.get(reference) is Some(expr_opt) { 
      return Found(expr_opt)
    }
  }

  NotFound
}

priv struct ConditionStack {
  stack: Array[TypedExpr]
}

fn ConditionStack::new() -> Self {
  { stack: [] }
}


priv enum MutualExclusivityResult {
  KeepBoth
  KeepNone
  KeepLeft
  KeepRight
}

fn check_mutual_exclusivity(a: TypedExpr, b: TypedExpr) -> MutualExclusivityResult {
  match (a, b) {
    (x1, PrimOp(op=Not, args=[x2], ..)) | (PrimOp(op=Not, args=[x1], ..), x2) if x1 == x2 => KeepNone
    (PrimOp(op=Not, args=[PrimOp(op=Eq, args=[x1, a], ..), ..], ..), PrimOp(op=Eq, args=[x2, b], ..)) if x1 == x2 && a != b => KeepRight
    (PrimOp(op=Eq, args=[x2, b], ..), PrimOp(op=Not, args=[PrimOp(op=Eq, args=[x1, a], ..), ..], ..)) if x1 == x2 && a != b => KeepLeft
    _ => KeepBoth
  }
}

fn ConditionStack::anded_with(self: Self, new_cond: TypedExpr) -> Self {
  // remove mutually exclusive conditions
  let new_stack = Array::new(capacity=self.stack.length() + 1)
  let mut should_add = true

  for cond in self.stack {
    match check_mutual_exclusivity(cond, new_cond) {
      KeepBoth | KeepLeft => new_stack.push(cond)
      KeepNone => should_add = false
      KeepRight => ()
    }
  }

  if should_add {
    new_stack.push(new_cond)
  }

  { stack: new_stack }
}

fn ConditionStack::as_expr(self: Self) -> TypedExpr {
  if self.stack.length() == 0 {
    return Literal(Literal::uint(1), ty=Type::bool())
  }

  let mut expr = self.stack[0]

  for i in 1 ..<self.stack.length() {
    expr = PrimOp(op=And, args=[expr, self.stack[i]], ty=Type::bool())
  }

  expr
}

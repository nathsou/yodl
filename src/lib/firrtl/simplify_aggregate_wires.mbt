// Remove aggregate wires which are only used as a collection of independently
// driven leaf aliases. This is deliberately conservative: aggregate values
// used as a whole, dynamic indexing, nested aggregate fields, and conditional
// drivers are left intact so FIRRTL connection semantics cannot change.

pub struct SimplifyAggregateWiresPass(Unit)

pub fn SimplifyAggregateWiresPass::new() -> Self {
  SimplifyAggregateWiresPass(())
}

type AliasMap = Map[TypedRef, TypedExpr]

fn[T : Hash + Eq] copy_set(source: Set[T]) -> Set[T] {
  let result = Set([])
  for value in source {
    result.add(value)
  }
  result
}

fn direct_field_ref(id: Id, bundle_ty: Type, field: BundleField) -> TypedRef {
  FieldAccess(
    lhs=Id(id, ty=bundle_ty),
    field=field.id,
    ty=field.ty,
  )
}

fn is_direct_field(reference: TypedRef) -> Bool {
  match reference {
    FieldAccess(lhs=Id(_), ..) => true
    _ => false
  }
}

fn alias_for(aliases: AliasMap, reference: TypedRef) -> TypedExpr? {
  if is_direct_field(reference) {
    aliases.get(reference)
  } else {
    None
  }
}

fn expr_uses_whole_id(expr: TypedExpr, id: Id) -> Bool {
  match expr {
    Reference(reference, ..) => ref_uses_whole_id(reference, id)
    Literal(_) => false
    Mux(cond~, tval~, fval~, ..) => {
      expr_uses_whole_id(cond, id) || expr_uses_whole_id(tval, id) || expr_uses_whole_id(fval, id)
    }
    PrimOp(args~, ..) => args.iter().any(expr => expr_uses_whole_id(expr, id))
  }
}

fn expr_references_direct_field(expr: TypedExpr, id: Id) -> Bool {
  match expr {
    Reference(reference, ..) => ref_references_direct_field(reference, id)
    Literal(_) => false
    Mux(cond~, tval~, fval~, ..) => {
      expr_references_direct_field(cond, id) || expr_references_direct_field(tval, id) ||
        expr_references_direct_field(fval, id)
    }
    PrimOp(args~, ..) => args.iter().any(expr => expr_references_direct_field(expr, id))
  }
}

fn ref_references_direct_field(reference: TypedRef, id: Id) -> Bool {
  match reference {
    Id(_) => false
    StaticIndexing(lhs~, ..) => ref_references_direct_field(lhs, id)
    DynamicIndexing(lhs~, index~, ..) => {
      ref_references_direct_field(lhs, id) || expr_references_direct_field(index, id)
    }
    FieldAccess(lhs~, ..) => match lhs {
      Id(reference_id, ..) => reference_id == id
      _ => ref_references_direct_field(lhs, id)
    }
  }
}

fn ref_uses_whole_id(reference: TypedRef, id: Id) -> Bool {
  match reference {
    Id(reference_id, ..) => reference_id == id
    StaticIndexing(lhs~, ..) => ref_uses_whole_id(lhs, id)
    DynamicIndexing(lhs~, index~, ..) => {
      // A field used as a dynamic index cannot be rewritten by the conservative
      // alias pass without rebuilding the reference, so keep its aggregate live.
      ref_uses_whole_id(lhs, id) || expr_uses_whole_id(index, id) ||
        expr_references_direct_field(index, id)
    }
    FieldAccess(lhs~, ..) => match lhs {
      Id(_) => false
      FieldAccess(lhs=Id(reference_id, ..), ..) => reference_id == id
      _ => ref_uses_whole_id(lhs, id)
    }
  }
}

fn stmt_uses_whole_id(stmt: TypedStmt, id: Id) -> Bool {
  match stmt {
    Node(expr~, ..) => expr_uses_whole_id(expr, id)
    Connect(lhs, rhs) => ref_uses_whole_id(lhs, id) || expr_uses_whole_id(rhs, id)
    Reg(clock~, ..) => expr_uses_whole_id(clock, id)
    RegReset(clock~, reset~, init~, ..) => {
      expr_uses_whole_id(clock, id) || expr_uses_whole_id(reset, id) || expr_uses_whole_id(init, id)
    }
    When({ cond, body, otherwise }) => {
      expr_uses_whole_id(cond, id) || body.iter().any(stmt => stmt_uses_whole_id(stmt, id)) ||
        otherwise.map_or(false, body => body.iter().any(stmt => stmt_uses_whole_id(stmt, id)))
    }
    Command(cmd) => match cmd {
      Printf(clk~, en~, args~, ..) => {
        expr_uses_whole_id(clk, id) || expr_uses_whole_id(en, id) || args.iter().any(expr => expr_uses_whole_id(expr, id))
      }
      Assert(clk~, pred~, en~, args~, ..) => {
        expr_uses_whole_id(clk, id) || expr_uses_whole_id(pred, id) || expr_uses_whole_id(en, id) ||
          args.iter().any(expr => expr_uses_whole_id(expr, id))
      }
      Stop(clk~, en~, ..) => expr_uses_whole_id(clk, id) || expr_uses_whole_id(en, id)
    }
    _ => false
  }
}

fn resolve_expr(expr: TypedExpr, aliases: AliasMap, visiting: Set[TypedRef]) -> TypedExpr? {
  match expr {
    Reference(reference, ty~) => match alias_for(aliases, reference) {
      None => Some(Reference(reference, ty~))
      Some(replacement) => {
        if visiting.contains(reference) {
          None
        } else {
          let next = copy_set(visiting)
          next.add(reference)
          resolve_expr(replacement, aliases, next)
        }
      }
    }
    Literal(_) => Some(expr)
    Mux(cond~, tval~, fval~, ty~) => {
      match (resolve_expr(cond, aliases, visiting), resolve_expr(tval, aliases, visiting), resolve_expr(fval, aliases, visiting)) {
        (Some(cond), Some(tval), Some(fval)) => Some(Mux(cond~, tval~, fval~, ty~))
        _ => None
      }
    }
    PrimOp(op~, args~, ty~) => {
      let resolved = Array::new(capacity=args.length())
      for arg in args {
        match resolve_expr(arg, aliases, visiting) {
          Some(arg) => resolved.push(arg)
          None => return None
        }
      }
      Some(PrimOp(op~, args=resolved, ty~))
    }
  }
}

fn rename_id(id: Id, renames: Map[Id, Id]) -> Id {
  renames.get(id).unwrap_or(id)
}

fn rename_ref(reference: TypedRef, renames: Map[Id, Id]) -> TypedRef {
  match reference {
    Id(id, ty~) => Id(rename_id(id, renames), ty~)
    StaticIndexing(lhs~, index~, ty~) => StaticIndexing(lhs=rename_ref(lhs, renames), index~, ty~)
    DynamicIndexing(lhs~, index~, ty~) => DynamicIndexing(
      lhs=rename_ref(lhs, renames),
      index=rename_expr(index, renames),
      ty~,
    )
    FieldAccess(lhs~, field~, ty~) => FieldAccess(lhs=rename_ref(lhs, renames), field~, ty~)
  }
}

fn rename_expr(expr: TypedExpr, renames: Map[Id, Id]) -> TypedExpr {
  match expr {
    Reference(reference, ty~) => Reference(rename_ref(reference, renames), ty~)
    Literal(_) => expr
    Mux(cond~, tval~, fval~, ty~) => Mux(
      cond=rename_expr(cond, renames),
      tval=rename_expr(tval, renames),
      fval=rename_expr(fval, renames),
      ty~,
    )
    PrimOp(op~, args~, ty~) => PrimOp(op~, args=args.map(expr => rename_expr(expr, renames)), ty~)
  }
}

fn rewrite_expr(expr: TypedExpr, aliases: AliasMap, renames: Map[Id, Id]) -> TypedExpr {
  match expr {
    Reference(reference, ty~) => match alias_for(aliases, reference) {
      Some(replacement) => rename_expr(replacement, renames)
      None => Reference(rename_ref(reference, renames), ty~)
    }
    Literal(_) => expr
    Mux(cond~, tval~, fval~, ty~) => Mux(
      cond=rewrite_expr(cond, aliases, renames),
      tval=rewrite_expr(tval, aliases, renames),
      fval=rewrite_expr(fval, aliases, renames),
      ty~,
    )
    PrimOp(op~, args~, ty~) => PrimOp(op~, args=args.map(expr => rewrite_expr(expr, aliases, renames)), ty~)
  }
}

fn root_decl_id(expr: TypedExpr) -> Id? {
  match expr {
    Reference(reference, ..) => match reference {
      Id(id, ..) => Some(id)
      FieldAccess(lhs=Id(id, ..), ..) => Some(id)
      _ => None
    }
    _ => None
  }
}

fn direct_field_id(reference: TypedRef) -> Id? {
  match reference {
    FieldAccess(lhs=Id(_), field~, ..) => Some(field)
    _ => None
  }
}

fn has_reg_input_connection(stmts: Array[TypedStmt], reg_id: Id, d_ref: TypedRef) -> Bool {
  for stmt in stmts {
    match stmt {
      Connect(Id(lhs_id, ..), Reference(rhs, ..)) if lhs_id == reg_id && refs_equal(rhs, d_ref) => return true
      When({ body, otherwise, .. }) => {
        if has_reg_input_connection(body, reg_id, d_ref) {
          return true
        }
        match otherwise {
          Some(body) if has_reg_input_connection(body, reg_id, d_ref) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

fn refs_equal(lhs: TypedRef, rhs: TypedRef) -> Bool {
  match (lhs, rhs) {
    (Id(lhs_id, ..), Id(rhs_id, ..)) => lhs_id == rhs_id
    (StaticIndexing(lhs=lhs_lhs, index=lhs_index, ..), StaticIndexing(lhs=rhs_lhs, index=rhs_index, ..)) => {
      lhs_index == rhs_index && refs_equal(lhs_lhs, rhs_lhs)
    }
    (FieldAccess(lhs=lhs_lhs, field=lhs_field, ..), FieldAccess(lhs=rhs_lhs, field=rhs_field, ..)) => {
      lhs_field == rhs_field && refs_equal(lhs_lhs, rhs_lhs)
    }
    _ => false
  }
}

fn rewrite_stmt(
  stmt: TypedStmt,
  aliases: AliasMap,
  lhs_aliases: AliasMap,
  removed: Set[TypedRef],
  renames: Map[Id, Id],
  inside_when: Bool,
) -> TypedStmt? {
  match stmt {
    Node(id~, expr~) => Some(Node(id~, expr=rewrite_expr(expr, aliases, renames)))
    Wire(..) => Some(stmt)
    Inst(id~, of~, sig~) => Some(Inst(id=rename_id(id, renames), of~, sig~))
    Mem(_) | Skip => Some(stmt)
    Reg(id~, ty~, clock~) => Some(Reg(id=rename_id(id, renames), ty~, clock=rewrite_expr(clock, aliases, renames)))
    RegReset(id~, ty~, clock~, reset~, init~) => Some(RegReset(
      id=rename_id(id, renames), ty~,
      clock=rewrite_expr(clock, aliases, renames),
      reset=rewrite_expr(reset, aliases, renames),
      init=rewrite_expr(init, aliases, renames),
    ))
    Connect(lhs, rhs) => {
      let lhs = if is_direct_field(lhs) && removed.contains(lhs) {
        if !inside_when {
          return None
        }
        let replacement = match lhs_aliases.get(lhs) {
          Some(replacement) => Some(replacement)
          None => alias_for(aliases, lhs)
        }
        match replacement {
          Some(Reference(reference, ..)) => rename_ref(reference, renames)
          _ => return None
        }
      } else {
        rename_ref(lhs, renames)
      }
      let rhs = rewrite_expr(rhs, aliases, renames)
      match rhs {
        Reference(reference, ..) if refs_equal(lhs, reference) => None
        _ => Some(Connect(lhs, rhs))
      }
    }
    When({ cond, body, otherwise }) => {
      let new_body = body.filter_map(stmt => rewrite_stmt(stmt, aliases, lhs_aliases, removed, renames, true))
      let new_otherwise = otherwise.map(body => body.filter_map(stmt => rewrite_stmt(stmt, aliases, lhs_aliases, removed, renames, true)))
      Some(When({
        cond: rewrite_expr(cond, aliases, renames),
        body: new_body,
        otherwise: new_otherwise,
      }))
    }
    Command(cmd) => {
      let cmd = match cmd {
        Printf(clk~, en~, fmt~, args~) => Printf(
          clk=rewrite_expr(clk, aliases, renames),
          en=rewrite_expr(en, aliases, renames),
          fmt~,
          args=args.map(expr => rewrite_expr(expr, aliases, renames)),
        )
        Assert(clk~, pred~, en~, fmt~, args~) => Assert(
          clk=rewrite_expr(clk, aliases, renames),
          pred=rewrite_expr(pred, aliases, renames),
          en=rewrite_expr(en, aliases, renames),
          fmt~,
          args=args.map(expr => rewrite_expr(expr, aliases, renames)),
        )
        Stop(clk~, en~, code~) => Stop(clk=rewrite_expr(clk, aliases, renames), en=rewrite_expr(en, aliases, renames), code~)
      }
      Some(Command(cmd))
    }
  }
}

fn simplify_module(mod: TypedModule) -> TypedModule {
  let aggregate_fields: Map[Id, Array[TypedRef]] = Map([])
  let hardware_decls: Set[Id] = Set([])
  let register_decls: Set[Id] = Set([])

  for stmt in mod.body {
    match stmt {
      Wire(id~, ty~) => match ty {
        Bundle(fields) => {
          let refs = []
          for field in fields {
            refs.push(direct_field_ref(id, ty, field))
          }
          aggregate_fields[id] = refs
        }
        _ => ()
      }
      Inst(id~, ..) => hardware_decls.add(id)
      Reg(id~, ..) | RegReset(id~, ..) => {
        hardware_decls.add(id)
        register_decls.add(id)
      }
      _ => ()
    }
  }

  let whole_used: Set[Id] = Set([])
  for id, _ in aggregate_fields {
    if mod.body.iter().any(stmt => stmt_uses_whole_id(stmt, id)) {
      whole_used.add(id)
    }
  }

  let field_refs: Set[TypedRef] = Set([])
  for _, refs in aggregate_fields {
    for reference in refs {
      field_refs.add(reference)
    }
  }

  let drivers: AliasMap = Map([])
  let nested_writes: Set[TypedRef] = Set([])

  fn collect_nested_writes(
    stmts: Array[TypedStmt],
    field_refs: Set[TypedRef],
    nested_writes: Set[TypedRef],
    inside_when: Bool,
  ) -> Unit {
    for stmt in stmts {
      match stmt {
        Connect(lhs, _) if inside_when && is_direct_field(lhs) && field_refs.contains(lhs) => nested_writes.add(lhs)
        When({ body, otherwise, .. }) => {
          collect_nested_writes(body, field_refs, nested_writes, true)
          match otherwise {
            Some(body) => collect_nested_writes(body, field_refs, nested_writes, true)
            None => ()
          }
        }
        _ => ()
      }
    }
  }

  for stmt in mod.body {
    match stmt {
      Connect(lhs, rhs) if is_direct_field(lhs) && field_refs.contains(lhs) => drivers[lhs] = rhs
      _ => ()
    }
  }
  collect_nested_writes(mod.body, field_refs, nested_writes, false)

  // Build a provisional map including conditionally written fields. This lets
  // us recognize the common register proxy shape (`d` aliases `q`, which
  // aliases the physical register) without treating conditionally overridden
  // instance inputs as aliases to their source expression.
  let provisional_candidates: AliasMap = Map([])
  for reference, driver in drivers {
    match reference {
      FieldAccess(lhs=Id(id, ..), ..) => {
        if !whole_used.contains(id) && driver.ty().is_ground() {
          provisional_candidates[reference] = driver
        }
      }
      _ => ()
    }
  }

  let provisional_aliases: AliasMap = Map([])
  for reference, _ in provisional_candidates {
    match resolve_expr(provisional_candidates[reference], provisional_candidates, Set([])) {
      Some(replacement) => provisional_aliases[reference] = replacement
      None => ()
    }
  }

  let register_proxy_lhs_aliases: AliasMap = Map([])
  for id, refs in aggregate_fields {
    if !whole_used.contains(id) {
      let mut q_ref: TypedRef? = None
      let mut d_ref: TypedRef? = None
      for reference in refs {
        match direct_field_id(reference) {
          Some(field) if field == Id::from("q") => q_ref = Some(reference)
          Some(field) if field == Id::from("d") => d_ref = Some(reference)
          _ => ()
        }
      }
      let is_register_proxy = refs.all(reference => {
        match direct_field_id(reference) {
          Some(field) => field == Id::from("d") || field == Id::from("q")
          None => false
        }
      })
      match (q_ref, d_ref, is_register_proxy) {
        (Some(q_ref), Some(d_ref), true) => {
          match provisional_aliases.get(q_ref).bind(root_decl_id) {
            Some(root) if register_decls.contains(root) && has_reg_input_connection(mod.body, root, d_ref) => {
              register_proxy_lhs_aliases[d_ref] = Reference(Id(root, ty=d_ref.ty()), ty=d_ref.ty())
            }
            _ => ()
          }
        }
        _ => ()
      }
    }
  }

  let candidates: AliasMap = Map([])
  for reference, driver in provisional_candidates {
    let is_register_alias = provisional_aliases.get(reference).bind(root_decl_id).map(root => register_decls.contains(root)).unwrap_or(false)
    if !nested_writes.contains(reference) || is_register_alias || register_proxy_lhs_aliases.contains(reference) {
      candidates[reference] = driver
    }
  }

  let aliases: AliasMap = Map([])
  for reference, _ in candidates {
    match resolve_expr(candidates[reference], candidates, Set([])) {
      Some(replacement) => aliases[reference] = replacement
      None => ()
    }
  }

  if aliases.is_empty() {
    return mod
  }

  let removable_wires: Set[Id] = Set([])
  for id, refs in aggregate_fields {
    if !whole_used.contains(id) && refs.iter().all(reference => aliases.contains(reference)) {
      removable_wires.add(id)
    }
  }

  // A field alias can be used for rewriting even when its aggregate still has
  // live fields, but its driver must remain until the whole proxy disappears.
  let removed: Set[TypedRef] = Set([])
  for id, refs in aggregate_fields {
    if removable_wires.contains(id) {
      for reference in refs {
        if aliases.contains(reference) {
          removed.add(reference)
        }
      }
    }
  }

  // If a proxy disappears completely, carry its source-level name onto the
  // sole physical register or instance it represented. This is only done for
  // an unambiguous declaration, so indirect aggregates retain generated names.
  let renames: Map[Id, Id] = Map([])
  for id, refs in aggregate_fields {
    if removable_wires.contains(id) {
      let roots: Set[Id] = Set([])
      for reference in refs {
        match aliases.get(reference).bind(root_decl_id) {
          Some(root) if hardware_decls.contains(root) => roots.add(root)
          _ => ()
        }
      }

      let roots = roots.to_array()
      if roots.length() == 1 && roots[0] != id {
        renames[roots[0]] = id
      }
    }
  }

  let new_body = Array::new(capacity=mod.body.length())
  for stmt in mod.body {
    match stmt {
      Wire(id~, ..) if removable_wires.contains(id) => ()
      _ => match rewrite_stmt(stmt, aliases, register_proxy_lhs_aliases, removed, renames, false) {
        Some(stmt) => new_body.push(stmt)
        None => ()
      }
    }
  }

  // FIRRTL requires declarations to precede references in their block. When
  // an aggregate proxy is removed, its physical declaration can otherwise be
  // left after the first rewritten connection that used the proxy. Preserve
  // connection order, but hoist declarations to the start of the module.
  let declarations = Array::new(capacity=new_body.length())
  let connections = Array::new(capacity=new_body.length())
  for stmt in new_body {
    match stmt {
      Node(..) | Wire(..) | Inst(..) | Reg(..) | RegReset(..) | Mem(_) => declarations.push(stmt)
      _ => connections.push(stmt)
    }
  }
  let ordered_body = Array::new(capacity=new_body.length())
  ordered_body.push_iter(declarations.iter())
  ordered_body.push_iter(connections.iter())

  { ..mod, body: ordered_body }
}

pub impl FIRRTLPass for SimplifyAggregateWiresPass with run(_, circuit: TypedCircuit) -> TypedCircuit {
  {
    ..circuit,
    decls: circuit.decls.map(decl => match decl {
      ExtModule(extmod) => ExtModule(extmod)
      Module(mod) => Module(simplify_module(mod))
    }),
  }
}

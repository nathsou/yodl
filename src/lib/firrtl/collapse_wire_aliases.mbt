// CollapseWireAliasesPass eliminates redundant intermediate wire declarations
// that the elaborator introduces as "proxy" wires. These appear in two places:
//
//   1. Register bundles — every Reg emits a bundle wire `r: { flip d: T, q: T }`
//      and two connects (`r.q ← reg_0`, `reg_0 ← r.d`). After ExpandWhensPass
//      the wire is just an alias; the register can be read/written directly.
//
//   2. Module instance port bundles — instantiating a module produces a bundle
//      wire with one field per output port that is immediately connected to the
//      instance outputs. Again the wire is pure indirection.
//
// The pass must run after ExpandWhensPass (all When blocks resolved) so that
// FIRRTL's last-connect semantics have been flattened into simple assignments,
// and before LowerAggregateTypesPass so that bundle/vec structure is still
// intact for leaf-level analysis.

pub struct CollapseWireAliasesPass {
  dummy: Unit
}

pub fn CollapseWireAliasesPass::new() -> Self {
  { dummy: () }
}

pub impl FIRRTLPass for CollapseWireAliasesPass with run(_, circuit) -> TypedCircuit raise {
  {
    ..circuit,
    decls: circuit.decls.map(decl => match decl {
      Module(mod) => Module(rewrite_module(mod))
      ExtModule(extmod) => ExtModule(extmod)
    }),
  }
}

// Rewrite a single module to remove collapsible wire aliases.
//
// The pass runs correctly both before and after ExpandWhensPass:
//
//   - Without ExpandWhensPass: wire leaves that are the LHS of any connect
//     inside a When block are conservatively kept (marked "when_assigned");
//     only unconditional proxy wires (e.g. instance port bundles and simple
//     registers with no conditional enables) are collapsed.
//
//   - After ExpandWhensPass: all When blocks are gone, so every leaf with a
//     unique driver is eligible, giving complete cleanup.
//
// Algorithm:
//
//   Phase 1 — Scan
//     Walk all statements recursively. Record:
//     - wire_leafs:    Id → [ground-type leaf refs] for every Wire declaration
//     - drivers:       leaf ref → the expression that LAST drives it at top-level
//     - use_counts:    leaf ref → how many times it appears on any RHS
//     - when_assigned: set of wire leaves that appear as LHS inside a When block
//
//   Phase 2 — Classify leaves
//     For each wire leaf decide its fate:
//     - when_assigned                → not collapsible (conditional driver)
//     - use_count == 0               → dead (never read; connect can be dropped)
//     - driver satisfies should_inline → alias (inline driver at every use)
//     Inlining policy: References and Literals always; single-use PrimOps;
//     never Mux (would duplicate conditional logic).
//
//   Phase 3 — Resolve alias chains
//     Aliases may chain: wire_a ← wire_b ← reg_0. Transitively follow each
//     alias to its final non-alias expression. Cycle detection prevents
//     infinite recursion on pathological inputs.
//
//   Phase 4 — Decide wire collapsibility
//     A wire is fully collapsible only when:
//       (a) every leaf is either aliased or dead, AND
//       (b) the wire is never referenced as a whole aggregate — e.g. as the
//           init value of a regreset — because rewrite_expr can only substitute
//           individual leaf refs, not an entire bundle/vec reference at once.
//
//   Phase 5 — Rewrite body
//     Emit a new statement list:
//     - Connect(lhs, rhs): skip if lhs belongs to a fully-collapsible wire;
//       otherwise substitute resolved aliases inside rhs; also drop trivial
//       self-connects (connect x, x) that arise after substitution.
//     - When(..): kept in place but cond and all nested connects/exprs are
//       rewritten (aliases substituted).
//     - All other statements: substitute resolved aliases in sub-expressions.
//
//   Phase 6 — Strip Wire declarations
//     Remove Wire statements for every fully-collapsible wire.
fn rewrite_module(mod: TypedModule) -> TypedModule {
  let wire_leafs: Map[Id, Array[TypedRef]] = {}
  let drivers: Map[TypedRef, TypedExpr] = {}
  let use_counts: Map[TypedRef, Int] = {}
  let when_assigned: Set[TypedRef] = Set([])

  for stmt in mod.body {
    collect_stmt_info(stmt, wire_leafs~, drivers~, use_counts~, when_assigned~)
  }

  let raw_aliases: Map[TypedRef, TypedExpr] = {}
  let dead_wire_leafs: Set[TypedRef] = Set([])

  for _, leafs in wire_leafs {
    for leaf in leafs {
      // when_assigned leaves have conditional drivers — conservative: leave them.
      if when_assigned.contains(leaf) {
        continue
      }

      let use_count = use_counts.get(leaf).unwrap_or(0)

      if use_count == 0 {
        dead_wire_leafs.add(leaf)
      } else if drivers.get(leaf) is Some(expr) && should_inline(expr, use_count) {
        raw_aliases[leaf] = expr
      }
    }
  }

  let resolved_aliases: Map[TypedRef, TypedExpr] = {}

  for leaf, expr in raw_aliases {
    let visiting: Array[TypedRef] = [leaf]

    match resolve_alias_expr(expr, raw_aliases~, cache=resolved_aliases, visiting~) {
      Some(resolved) => {
        resolved_aliases[leaf] = resolved
      }
      None => ()
    }
  }

  // Phase 2b — Detect LHS aliases for wire leaves.
  //
  // Register proxy pattern:
  //   wire r: { flip d: T, q: T }
  //   regreset reg_N: T, ...
  //   connect r.q, reg_N      (r.q is an RHS alias for reg_N — already in resolved_aliases)
  //   connect reg_N, r.d      (reg_N is driven by r.d)
  //   connect r.d, r.q        (default self-connect or overridden later)
  //
  // Detection: for each non-wire ref T driven by Reference(L) where L is a wire
  // leaf, L is an LHS alias for T: rewrite `connect L, X` → `connect T, X`.
  // Also add L as an RHS alias for T so `connect T, Reference(L)` → self-connect.
  let lhs_aliases: Map[TypedRef, TypedRef] = {}

  // Build a set of all wire leaf refs for quick lookup
  let all_wire_leafs: Set[TypedRef] = Set([])
  for _, leafs in wire_leafs {
    for leaf in leafs {
      all_wire_leafs.add(leaf)
    }
  }

  for target, expr in drivers {
    // target must NOT be a wire leaf (it's the register/other sink)
    if all_wire_leafs.contains(target) {
      continue
    }

    // The driver must be a simple Reference to a wire leaf
    let leaf = match expr {
      Reference(r, ty=_) =>
        if all_wire_leafs.contains(r) {
          r
        } else {
          continue
        }
      _ => continue
    }

    // The leaf must not already be an RHS alias or dead
    if resolved_aliases.contains(leaf) || dead_wire_leafs.contains(leaf) {
      continue
    }

    // The leaf must be used exactly once as a source — in the connect `target ← leaf`.
    // If use_count > 1, the leaf is also referenced in expressions and we can't
    // safely replace those RHS occurrences with the LHS alias target.
    let use_count = use_counts.get(leaf).unwrap_or(0)
    if use_count != 1 {
      continue
    }

    lhs_aliases[leaf] = target
    // Also make leaf an RHS alias for target so `connect target, Reference(leaf)`
    // becomes `connect target, Reference(target)` → self-connect → dropped
    resolved_aliases[leaf] = target.as_expr()
  }

  // A wire is fully collapsible only when ALL its leaves are either aliased,
  // dead, or LHS-aliased, AND it is never referenced as an aggregate.
  // Aggregate references (e.g. a whole Vec used as a regreset init) cannot be
  // inlined by rewrite_expr, so the wire must be kept in those cases.
  let aggregate_used_wires = scan_body_aggregate_wire_uses(mod.body, wire_leafs)
  let wire_fully_collapsible: Map[Id, Bool] = {}
  for wire_id, leafs in wire_leafs {
    let all_removable = leafs.iter().all(leaf =>
      resolved_aliases.contains(leaf) || dead_wire_leafs.contains(leaf) || lhs_aliases.contains(leaf)
    ) && !aggregate_used_wires.contains(wire_id)
    wire_fully_collapsible[wire_id] = all_removable
  }

  // Build the set of connect-LHSs that are safe to drop — only leaves whose
  // enclosing wire will itself be removed AND that are RHS-aliased or dead
  // (not LHS-aliased — those connects must be kept and LHS-rewritten).
  let collapsible_connects: Set[TypedRef] = Set([])
  for wire_id, leafs in wire_leafs {
    if wire_fully_collapsible.get(wire_id).unwrap_or(false) {
      for leaf in leafs {
        if !lhs_aliases.contains(leaf) {
          collapsible_connects.add(leaf)
        }
      }
    }
  }

  // Phase 4 — Build rename map: when a proxy wire is fully collapsed and all
  // its aliases point to the same target root (e.g. a register or instance),
  // rename that target to the wire's original (user-provided) name.
  // Only rename when the wire name looks user-provided (no '$', no trailing
  // '_digits' pattern that marks elaborator-generated proxy names).
  let renames: Map[Id, Id] = {}

  // Build reverse lookup: for each wire leaf, find if any non-wire ref is
  // driven by it (i.e., `connect T, leaf` exists with T non-wire).
  let leaf_sinks: Map[TypedRef, Id] = {}
  for target, expr in drivers {
    if all_wire_leafs.contains(target) {
      continue
    }
    match expr {
      Reference(r, ty=_) => {
        if all_wire_leafs.contains(r) {
          leaf_sinks[r] = ref_root_id(target)
        }
      }
      _ => ()
    }
  }

  for wire_id, leafs in wire_leafs {
    if !wire_fully_collapsible.get(wire_id).unwrap_or(false) {
      continue
    }

    // Skip wires with generated names — only user-provided let-binding names
    // should be propagated to the underlying register/instance/memory.
    if !is_user_provided_name(wire_id) {
      continue
    }

    // Find the common alias target root for all non-dead leaves
    let mut target_root: Id? = None
    let mut all_same = true

    for leaf in leafs {
      if dead_wire_leafs.contains(leaf) {
        continue
      }

      // Determine the root: check LHS alias, then RHS alias (Reference only),
      // then the reverse driver lookup (leaf used as a source for a non-wire ref)
      let root = if lhs_aliases.get(leaf) is Some(target) {
        Some(ref_root_id(target))
      } else if resolved_aliases.get(leaf) is Some(Reference(target_ref, ty=_)) {
        Some(ref_root_id(target_ref))
      } else if leaf_sinks.get(leaf) is Some(sink_root) {
        Some(sink_root)
      } else {
        None
      }

      match (target_root, root) {
        (None, Some(_)) => target_root = root
        (Some(prev), Some(curr)) => {
          if prev != curr {
            all_same = false
            break
          }
        }
        _ => {
          all_same = false
          break
        }
      }
    }

    if all_same {
      if target_root is Some(root) && root != wire_id {
        renames[root] = wire_id
      }
    }
  }

  // Remove renames targeting memories — their reader/writer port names and
  // annotations would also need updating which adds too much complexity.
  let mem_ids: Set[Id] = Set([])
  for stmt in mod.body {
    if stmt is Mem(mem) {
      mem_ids.add(mem.id)
    }
  }
  for old, _ in renames {
    if mem_ids.contains(old) {
      renames.remove(old)
    }
  }

  let new_body = Array::new(capacity=mod.body.length())

  for stmt in mod.body {
    rewrite_stmt(
      stmt,
      body=new_body,
      resolved_aliases~,
      collapsible_connects~,
      lhs_aliases~,
    )
  }

  let filtered_body = Array::new(capacity=new_body.length())

  for stmt in new_body {
    match stmt {
      Wire(id~, ty=_) => {
        if !wire_fully_collapsible.get(id).unwrap_or(false) {
          filtered_body.push(stmt)
        }
      }
      _ => filtered_body.push(stmt)
    }
  }

  // Apply renames if any
  let final_body = if renames.is_empty() {
    filtered_body
  } else {
    filtered_body.map(stmt => rename_stmt(stmt, renames))
  }

  // Rename ports too (in case a port was renamed — unlikely but safe)
  let final_ports = if renames.is_empty() {
    mod.ports
  } else {
    mod.ports.map(port => {
      let new_id = renames.get(port.id).unwrap_or(port.id)
      { ..port, id: new_id }
    })
  }

  { ..mod, body: final_body, ports: final_ports }
}

/// Checks whether a wire name looks user-provided (from a let-binding) rather
/// than generated by the elaborator. Generated names contain '$' (from gen_id)
/// or end with '_' followed by digits (from anonymous instance proxy wires).
fn is_user_provided_name(id: Id) -> Bool {
  let s = id.value()
  if s.contains("$") {
    return false
  }
  // Check for trailing _digits pattern (e.g. "Text_AsciiTable_22")
  let chars = s.to_array()
  let len = chars.length()
  if len < 2 {
    return true
  }
  let mut i = len - 1
  while i >= 0 && chars[i].is_ascii_digit() {
    i -= 1
  }
  // If we consumed at least one digit and stopped at '_', it's generated
  if i < len - 1 && i >= 0 && chars[i] == '_' {
    return false
  }
  true
}

// Returns the root Id of any TypedRef (e.g. StaticIndexing(Id("v"), 0) → "v").
fn ref_root_id(ref_ : TypedRef) -> Id {
  match ref_ {
    Id(id, ty=_) => id
    StaticIndexing(lhs~, ..) | FieldAccess(lhs~, ..) => ref_root_id(lhs)
    DynamicIndexing(lhs~, ..) => ref_root_id(lhs)
  }
}

// Rename the root Id of a reference if it appears in the rename map.
fn rename_ref(ref_: TypedRef, renames: Map[Id, Id]) -> TypedRef {
  match ref_ {
    Id(id, ty~) => Id(renames.get(id).unwrap_or(id), ty~)
    StaticIndexing(lhs~, index~, ty~) =>
      StaticIndexing(lhs=rename_ref(lhs, renames), index~, ty~)
    DynamicIndexing(lhs~, index~, ty~) =>
      DynamicIndexing(lhs=rename_ref(lhs, renames), index=rename_expr(index, renames), ty~)
    FieldAccess(lhs~, field~, ty~) =>
      FieldAccess(lhs=rename_ref(lhs, renames), field~, ty~)
  }
}

fn rename_expr(expr: TypedExpr, renames: Map[Id, Id]) -> TypedExpr {
  match expr {
    Reference(reference, ty~) => Reference(rename_ref(reference, renames), ty~)
    Literal(_, ty=_) => expr
    Mux(cond~, tval~, fval~, ty~) =>
      Mux(
        cond=rename_expr(cond, renames),
        tval=rename_expr(tval, renames),
        fval=rename_expr(fval, renames),
        ty~,
      )
    PrimOp(op~, args~, ty~) =>
      PrimOp(op~, args=args.map(a => rename_expr(a, renames)), ty~)
  }
}

fn rename_stmt(stmt: TypedStmt, renames: Map[Id, Id]) -> TypedStmt {
  match stmt {
    Node(id~, expr~) =>
      Node(id=renames.get(id).unwrap_or(id), expr=rename_expr(expr, renames))
    Wire(id~, ty~) =>
      Wire(id=renames.get(id).unwrap_or(id), ty~)
    Inst(id~, of~, sig~) =>
      Inst(id=renames.get(id).unwrap_or(id), of~, sig~)
    Reg(id~, ty~, clock~) =>
      Reg(id=renames.get(id).unwrap_or(id), ty~, clock=rename_expr(clock, renames))
    RegReset(id~, ty~, clock~, reset~, init~) =>
      RegReset(
        id=renames.get(id).unwrap_or(id), ty~,
        clock=rename_expr(clock, renames),
        reset=rename_expr(reset, renames),
        init=rename_expr(init, renames),
      )
    Mem(mem) =>
      Mem({ ..mem, id: renames.get(mem.id).unwrap_or(mem.id),
        readers: mem.readers.map(r => renames.get(r).unwrap_or(r)),
        writers: mem.writers.map(w => renames.get(w).unwrap_or(w)),
        readwriters: mem.readwriters.map(rw => renames.get(rw).unwrap_or(rw)),
      })
    Connect(lhs, rhs) =>
      Connect(rename_ref(lhs, renames), rename_expr(rhs, renames))
    When(w) =>
      When({
        cond: rename_expr(w.cond, renames),
        body: w.body.map(s => rename_stmt(s, renames)),
        otherwise: w.otherwise.map(stmts => stmts.map(s => rename_stmt(s, renames))),
      })
    Command(cmd) => Command(rename_command(cmd, renames))
    Skip => Skip
  }
}

fn rename_command(cmd: Command[Type], renames: Map[Id, Id]) -> Command[Type] {
  match cmd {
    Printf(clk~, en~, fmt~, args~) =>
      Printf(clk=rename_expr(clk, renames), en=rename_expr(en, renames), fmt~,
        args=args.map(a => rename_expr(a, renames)))
    Assert(clk~, pred~, en~, fmt~, args~) =>
      Assert(clk=rename_expr(clk, renames), pred=rename_expr(pred, renames),
        en=rename_expr(en, renames), fmt~, args=args.map(a => rename_expr(a, renames)))
    Stop(clk~, en~, code~) =>
      Stop(clk=rename_expr(clk, renames), en=rename_expr(en, renames), code~)
  }
}

// Collect wire IDs that are referenced as aggregates (non-leaf, non-ground
// type) anywhere in expressions. Such wires must NOT be fully collapsed
// because rewrite_expr can't inline an aggregate reference — only leaf refs
// are kept in resolved_aliases.
fn scan_expr_aggregate_wire_uses(
  expr: TypedExpr,
  wire_leafs: Map[Id, Array[TypedRef]],
  aggregate_uses: Set[Id]
) -> Unit {
  match expr {
    Reference(ref_, ty=_) => {
      if !ref_.ty().is_ground() {
        let root = ref_root_id(ref_)
        if wire_leafs.contains(root) {
          aggregate_uses.add(root)
        }
      }
    }
    Literal(_, ty=_) => ()
    Mux(cond~, tval~, fval~, ..) => {
      scan_expr_aggregate_wire_uses(cond, wire_leafs, aggregate_uses)
      scan_expr_aggregate_wire_uses(tval, wire_leafs, aggregate_uses)
      scan_expr_aggregate_wire_uses(fval, wire_leafs, aggregate_uses)
    }
    PrimOp(args~, ..) => {
      for arg in args {
        scan_expr_aggregate_wire_uses(arg, wire_leafs, aggregate_uses)
      }
    }
  }
}

fn scan_body_aggregate_wire_uses(
  stmts: Array[TypedStmt],
  wire_leafs: Map[Id, Array[TypedRef]]
) -> Set[Id] {
  let aggregate_uses: Set[Id] = Set([])

  fn scan_stmts(stmts: Array[TypedStmt]) -> Unit {
    for stmt in stmts {
      match stmt {
        Wire(..) | Inst(..) | Mem(_) | Skip => ()
        When({ cond, body, otherwise }) => {
          scan_expr_aggregate_wire_uses(cond, wire_leafs, aggregate_uses)
          scan_stmts(body)
          if otherwise is Some(else_body) {
            scan_stmts(else_body)
          }
        }
        Node(expr~, ..) => scan_expr_aggregate_wire_uses(expr, wire_leafs, aggregate_uses)
        Reg(clock~, ..) => scan_expr_aggregate_wire_uses(clock, wire_leafs, aggregate_uses)
        RegReset(clock~, reset~, init~, ..) => {
          scan_expr_aggregate_wire_uses(clock, wire_leafs, aggregate_uses)
          scan_expr_aggregate_wire_uses(reset, wire_leafs, aggregate_uses)
          scan_expr_aggregate_wire_uses(init, wire_leafs, aggregate_uses)
        }
        Connect(_, rhs) => scan_expr_aggregate_wire_uses(rhs, wire_leafs, aggregate_uses)
        Command(cmd) => {
          match cmd {
            Printf(clk~, en~, args~, ..) => {
              scan_expr_aggregate_wire_uses(clk, wire_leafs, aggregate_uses)
              scan_expr_aggregate_wire_uses(en, wire_leafs, aggregate_uses)
              for arg in args {
                scan_expr_aggregate_wire_uses(arg, wire_leafs, aggregate_uses)
              }
            }
            Assert(clk~, pred~, en~, args~, ..) => {
              scan_expr_aggregate_wire_uses(clk, wire_leafs, aggregate_uses)
              scan_expr_aggregate_wire_uses(pred, wire_leafs, aggregate_uses)
              scan_expr_aggregate_wire_uses(en, wire_leafs, aggregate_uses)
              for arg in args {
                scan_expr_aggregate_wire_uses(arg, wire_leafs, aggregate_uses)
              }
            }
            Stop(clk~, en~, ..) => {
              scan_expr_aggregate_wire_uses(clk, wire_leafs, aggregate_uses)
              scan_expr_aggregate_wire_uses(en, wire_leafs, aggregate_uses)
            }
          }
        }
      }
    }
  }

  scan_stmts(stmts)
  aggregate_uses
}


// Expand a TypedRef into its ground-type leaf projections.
// e.g. Id("r", Bundle[{d: UInt<8>}, {q: UInt<8>}]) → [r.d, r.q]
fn flatten_alias_ref(reference: TypedRef) -> Array[TypedRef] {
  let leaf_refs = []

  fn aux(reference: TypedRef) -> Unit {
    match reference.ty() {
      Bundle(fields) => {
        for field in fields {
          aux(FieldAccess(lhs=reference, field=field.id, ty=field.ty))
        }
      }
      Vec(elem_ty, size) => {
        for i in 0..<size {
          aux(StaticIndexing(lhs=reference, index=i, ty=elem_ty))
        }
      }
      _ => leaf_refs.push(reference)
    }
  }

  aux(reference)

  leaf_refs
}

// Increment use counts for every ground-type leaf of `reference`.
// DynamicIndexing references (e.g. arr[i]) are skipped: they contain an
// expression as the index so they cannot be used as map keys, and they can
// never be proxy wire leaves anyway.
fn bump_ref_use(use_counts: Map[TypedRef, Int], reference: TypedRef) -> Unit {
  match reference {
    DynamicIndexing(..) => ()
    _ =>
      if reference.ty().is_ground() {
        use_counts[reference] = use_counts.get(reference).unwrap_or(0) + 1
      } else {
        for leaf in flatten_alias_ref(reference) {
          bump_ref_use(use_counts, leaf)
        }
      }
  }
}

fn collect_expr_uses(expr: TypedExpr, use_counts: Map[TypedRef, Int]) -> Unit {
  match expr {
    Reference(reference, ty=_) => bump_ref_use(use_counts, reference)
    Literal(_, ty=_) => ()
    Mux(cond~, tval~, fval~, ..) => {
      collect_expr_uses(cond, use_counts)
      collect_expr_uses(tval, use_counts)
      collect_expr_uses(fval, use_counts)
    }
    PrimOp(args~, ..) => {
      for arg in args {
        collect_expr_uses(arg, use_counts)
      }
    }
  }
}

// Phase 1 helper: populate wire_leafs, drivers, use_counts, and when_assigned
// from one statement. Connect(lhs, rhs) records the driver for lhs at the
// top level (last-connect wins) and bumps use counts for all refs in rhs.
// When-block connects mark their LHS leaves as when_assigned (conditional
// drivers) so Phase 2 treats them as non-collapsible; use counts from their
// RHSs are still collected.
fn collect_stmt_info(
  stmt: TypedStmt,
  wire_leafs~: Map[Id, Array[TypedRef]],
  drivers~: Map[TypedRef, TypedExpr],
  use_counts~: Map[TypedRef, Int],
  when_assigned~: Set[TypedRef],
) -> Unit {
  match stmt {
    Wire(id~, ty~) => {
      wire_leafs[id] = flatten_alias_ref(Id(id, ty~))
    }
    Node(expr~, ..) => collect_expr_uses(expr, use_counts)
    Reg(clock~, ..) => collect_expr_uses(clock, use_counts)
    RegReset(clock~, reset~, init~, ..) => {
      collect_expr_uses(clock, use_counts)
      collect_expr_uses(reset, use_counts)
      collect_expr_uses(init, use_counts)
    }
    Connect(lhs, rhs) => {
      if !(lhs is DynamicIndexing(..)) && lhs.ty().is_ground() {
        drivers[lhs] = rhs
      }

      collect_expr_uses(rhs, use_counts)
    }
    When({ cond, body, otherwise }) => {
      collect_expr_uses(cond, use_counts)
      collect_when_body_info(body, use_counts~, when_assigned~)
      if otherwise is Some(else_body) {
        collect_when_body_info(else_body, use_counts~, when_assigned~)
      }
    }
    Command(cmd) => {
      match cmd {
        Printf(clk~, en~, args~, ..) => {
          collect_expr_uses(clk, use_counts)
          collect_expr_uses(en, use_counts)

          for arg in args {
            collect_expr_uses(arg, use_counts)
          }
        }
        Assert(clk~, pred~, en~, args~, ..) => {
          collect_expr_uses(clk, use_counts)
          collect_expr_uses(pred, use_counts)
          collect_expr_uses(en, use_counts)

          for arg in args {
            collect_expr_uses(arg, use_counts)
          }
        }
        Stop(clk~, en~, ..) => {
          collect_expr_uses(clk, use_counts)
          collect_expr_uses(en, use_counts)
        }
      }
    }
    Inst(..) | Mem(_) | Skip => ()
  }
}

// Recursively scan a When body: collect use counts from all RHS expressions
// and mark connect LHSs as when_assigned (their drivers are conditional).
fn collect_when_body_info(
  stmts: Array[TypedStmt],
  use_counts~: Map[TypedRef, Int],
  when_assigned~: Set[TypedRef],
) -> Unit {
  for stmt in stmts {
    match stmt {
      Connect(lhs, rhs) => {
        if !(lhs is DynamicIndexing(..)) && lhs.ty().is_ground() {
          when_assigned.add(lhs)
        }
        collect_expr_uses(rhs, use_counts)
      }
      When({ cond, body, otherwise }) => {
        collect_expr_uses(cond, use_counts)
        collect_when_body_info(body, use_counts~, when_assigned~)
        if otherwise is Some(else_body) {
          collect_when_body_info(else_body, use_counts~, when_assigned~)
        }
      }
      Node(expr~, ..) => collect_expr_uses(expr, use_counts)
      Reg(clock~, ..) => collect_expr_uses(clock, use_counts)
      RegReset(clock~, reset~, init~, ..) => {
        collect_expr_uses(clock, use_counts)
        collect_expr_uses(reset, use_counts)
        collect_expr_uses(init, use_counts)
      }
      Command(cmd) => {
        match cmd {
          Printf(clk~, en~, args~, ..) => {
            collect_expr_uses(clk, use_counts)
            collect_expr_uses(en, use_counts)
            for arg in args {
              collect_expr_uses(arg, use_counts)
            }
          }
          Assert(clk~, pred~, en~, args~, ..) => {
            collect_expr_uses(clk, use_counts)
            collect_expr_uses(pred, use_counts)
            collect_expr_uses(en, use_counts)
            for arg in args {
              collect_expr_uses(arg, use_counts)
            }
          }
          Stop(clk~, en~, ..) => {
            collect_expr_uses(clk, use_counts)
            collect_expr_uses(en, use_counts)
          }
        }
      }
      Wire(..) | Inst(..) | Mem(_) | Skip => ()
    }
  }
}

// Phase 2 helper: decide whether a driver expression is cheap enough to inline.
// References and Literals are always free to duplicate. A PrimOp is inlined
// only when its result is used exactly once (avoids duplicating computation).
// Mux is never inlined — it would reconstruct conditional logic that
// ExpandWhensPass already collapsed.
fn should_inline(expr: TypedExpr, use_count: Int) -> Bool {
  match expr {
    Reference(_, ty=_) | Literal(_, ty=_) => true
    PrimOp(..) => use_count <= 1
    Mux(..) => false
  }
}

// Phase 3 helper: transitively resolve an alias expression to its final form.
// If `expr` is a Reference that is itself an alias, follow the chain. Results
// are memoised in `cache`. `visiting` is a stack used to detect cycles
// (which can arise from self-referential connects); returns None on a cycle so
// that the alias is conservatively left in place.
fn resolve_alias_expr(
  expr: TypedExpr,
  raw_aliases~: Map[TypedRef, TypedExpr],
  cache~: Map[TypedRef, TypedExpr],
  visiting~: Array[TypedRef]
) -> TypedExpr? {
  match expr {
    Reference(reference, ty=ref_ty) => {
      match reference {
        DynamicIndexing(lhs~, index~, ty~) => {
          // Can't look up dynamic indices in alias maps; resolve aliases in index only.
          match resolve_alias_expr(index, raw_aliases~, cache~, visiting~) {
            Some(new_index) =>
              Some(Reference(DynamicIndexing(lhs~, index=new_index, ty~), ty=ref_ty))
            None => None
          }
        }
        _ =>
          if cache.get(reference) is Some(resolved) {
            Some(resolved)
          } else if raw_aliases.get(reference) is Some(alias_expr) {
            if visiting.contains(reference) {
              None
            } else {
              visiting.push(reference)

              let resolved = resolve_alias_expr(alias_expr, raw_aliases~, cache~, visiting~)
              let _ = visiting.pop()

              match resolved {
                Some(resolved) => {
                  cache[reference] = resolved
                  Some(resolved)
                }
                None => None
              }
            }
          } else {
            Some(expr)
          }
      }
    }
    Literal(_, ty=_) => Some(expr)
    Mux(cond~, tval~, fval~, ty~) => {
      match (
        resolve_alias_expr(cond, raw_aliases~, cache~, visiting~),
        resolve_alias_expr(tval, raw_aliases~, cache~, visiting~),
        resolve_alias_expr(fval, raw_aliases~, cache~, visiting~),
      ) {
        (Some(new_cond), Some(new_tval), Some(new_fval)) => {
          Some(Mux(cond=new_cond, tval=new_tval, fval=new_fval, ty~))
        }
        _ => None
      }
    }
    PrimOp(op~, args~, ty~) => {
      let new_args = Array::new(capacity=args.length())

      for arg in args {
        match resolve_alias_expr(arg, raw_aliases~, cache~, visiting~) {
          Some(new_arg) => new_args.push(new_arg)
          None => return None
        }
      }

      Some(PrimOp(op~, args=new_args, ty~))
    }
  }
}

// Phase 5 helper: substitute resolved aliases throughout an expression.
fn rewrite_expr(expr: TypedExpr, resolved_aliases: Map[TypedRef, TypedExpr]) -> TypedExpr {
  match expr {
    Reference(reference, ty=ref_ty) => {
      // DynamicIndexing can't be a resolved alias (it can't be a map key);
      // also need to rewrite the index expression inside it.
      match reference {
        DynamicIndexing(lhs~, index~, ty~) => {
          Reference(DynamicIndexing(
            lhs~,
            index=rewrite_expr(index, resolved_aliases),
            ty~,
          ), ty=ref_ty)
        }
        _ => resolved_aliases.get(reference).unwrap_or(expr)
      }
    }
    Literal(_, ty=_) => expr
    Mux(cond~, tval~, fval~, ty~) => {
      Mux(
        cond=rewrite_expr(cond, resolved_aliases),
        tval=rewrite_expr(tval, resolved_aliases),
        fval=rewrite_expr(fval, resolved_aliases),
        ty~
      )
    }
    PrimOp(op~, args~, ty~) => {
      PrimOp(op~, args=args.map(arg => rewrite_expr(arg, resolved_aliases)), ty~)
    }
  }
}

// Phase 5 helper: emit the rewritten form of one statement into `body`.
fn rewrite_stmt(
  stmt: TypedStmt,
  body~: Array[TypedStmt],
  resolved_aliases~: Map[TypedRef, TypedExpr],
  collapsible_connects~: Set[TypedRef],
  lhs_aliases~: Map[TypedRef, TypedRef],
) -> Unit {
  match stmt {
    Wire(..) | Inst(..) | Mem(_) | Skip => body.push(stmt)
    Node(id~, expr~) => {
      body.push(Node(id~, expr=rewrite_expr(expr, resolved_aliases)))
    }
    Reg(id~, ty~, clock~) => {
      body.push(Reg(id~, ty~, clock=rewrite_expr(clock, resolved_aliases)))
    }
    RegReset(id~, ty~, clock~, reset~, init~) => {
      body.push(RegReset(
        id~,
        ty~,
        clock=rewrite_expr(clock, resolved_aliases),
        reset=rewrite_expr(reset, resolved_aliases),
        init=rewrite_expr(init, resolved_aliases),
      ))
    }
    Connect(lhs, rhs) => {
      if !(lhs is DynamicIndexing(..)) && collapsible_connects.contains(lhs) {
        return
      }

      let new_lhs = match lhs {
        DynamicIndexing(..) => lhs
        _ => lhs_aliases.get(lhs).unwrap_or(lhs)
      }
      let new_rhs = rewrite_expr(rhs, resolved_aliases)

      if !(new_rhs is Reference(reference, ..) && reference == new_lhs) {
        body.push(Connect(new_lhs, new_rhs))
      }
    }
    Command(cmd) => {
      match cmd {
        Printf(clk~, en~, fmt~, args~) => {
          body.push(Command(Printf(
            clk=rewrite_expr(clk, resolved_aliases),
            en=rewrite_expr(en, resolved_aliases),
            fmt~,
            args=args.map(arg => rewrite_expr(arg, resolved_aliases)),
          )))
        }
        Assert(clk~, pred~, en~, fmt~, args~) => {
          body.push(Command(Assert(
            clk=rewrite_expr(clk, resolved_aliases),
            pred=rewrite_expr(pred, resolved_aliases),
            en=rewrite_expr(en, resolved_aliases),
            fmt~,
            args=args.map(arg => rewrite_expr(arg, resolved_aliases)),
          )))
        }
        Stop(clk~, en~, code~) => {
          body.push(Command(Stop(
            clk=rewrite_expr(clk, resolved_aliases),
            en=rewrite_expr(en, resolved_aliases),
            code~,
          )))
        }
      }
    }
    When({ cond, body: when_body, otherwise }) => {
      fn rewrite_stmts(stmts: Array[TypedStmt]) -> Array[TypedStmt] {
        let out = Array::new(capacity=stmts.length())
        for s in stmts {
          rewrite_stmt(s, body=out, resolved_aliases~, collapsible_connects~, lhs_aliases~)
        }
        out
      }

      body.push(When({
        cond: rewrite_expr(cond, resolved_aliases),
        body: rewrite_stmts(when_body),
        otherwise: otherwise.map(rewrite_stmts),
      }))
    }
  }
}

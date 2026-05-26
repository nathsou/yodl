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

// Rewrite a single module to remove collapsible wire aliases
//
// Algorithm:
//
//   Phase 1 — Scan
//     Walk all statements once. Record:
//     - wire_leafs:  Id → [ground-type leaf refs] for every Wire declaration
//     - drivers:     leaf ref → the expression that last drives it
//     - use_counts:  leaf ref → how many times it appears on a RHS
//
//   Phase 2 — Classify leaves
//     For each wire leaf decide its fate:
//     - use_count == 0           → dead (never read; the connect can be dropped)
//     - driver satisfies should_inline → alias (inline the driver at every use)
//     Inlining policy: References and Literals always; single-use PrimOps;
//     never Mux (would duplicate conditionals already eliminated by ExpandWhens).
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
//     - All other statements: substitute resolved aliases in sub-expressions.
//
//   Phase 6 — Strip Wire declarations
//     Remove Wire statements for every fully-collapsible wire.
fn rewrite_module(mod: TypedModule) -> TypedModule {
  if mod.body.iter().any(has_when) {
    return mod
  }

  let wire_leafs: Map[Id, Array[TypedRef]] = {}
  let drivers: Map[TypedRef, TypedExpr] = {}
  let use_counts: Map[TypedRef, Int] = {}

  for stmt in mod.body {
    collect_stmt_info(stmt, wire_leafs~, drivers~, use_counts~)
  }

  let raw_aliases: Map[TypedRef, TypedExpr] = {}
  let dead_wire_leafs: Set[TypedRef] = Set([])

  for _, leafs in wire_leafs {
    for leaf in leafs {
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

  // A wire is fully collapsible only when ALL its leaves are either aliased or
  // dead, AND it is never referenced as an aggregate (non-leaf) expression.
  // Aggregate references (e.g. a whole Vec used as a regreset init) cannot be
  // inlined by rewrite_expr, so the wire must be kept in those cases.
  let aggregate_used_wires = scan_body_aggregate_wire_uses(mod.body, wire_leafs)
  let wire_fully_collapsible: Map[Id, Bool] = {}
  for wire_id, leafs in wire_leafs {
    let all_removable = leafs.iter().all(leaf =>
      resolved_aliases.contains(leaf) || dead_wire_leafs.contains(leaf)
    ) && !aggregate_used_wires.contains(wire_id)
    wire_fully_collapsible[wire_id] = all_removable
  }

  // Build the set of connect-LHSs that are safe to drop — only leaves whose
  // enclosing wire will itself be removed.
  let collapsible_connects: Set[TypedRef] = Set([])
  for wire_id, leafs in wire_leafs {
    if wire_fully_collapsible.get(wire_id).unwrap_or(false) {
      for leaf in leafs {
        collapsible_connects.add(leaf)
      }
    }
  }

  let new_body = Array::new(capacity=mod.body.length())

  for stmt in mod.body {
    rewrite_stmt(
      stmt,
      body=new_body,
      resolved_aliases~,
      collapsible_connects~,
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

  { ..mod, body: filtered_body }
}

fn has_when(stmt: TypedStmt) -> Bool {
  match stmt {
    When({ body, otherwise, .. }) => {
      body.iter().any(has_when) || otherwise.map_or(false, else_body => else_body.iter().any(has_when))
    }
    _ => false
  }
}

// Returns the root Id of any TypedRef (e.g. StaticIndexing(Id("v"), 0) → "v").
fn ref_root_id(ref_ : TypedRef) -> Id {
  match ref_ {
    Id(id, ty=_) => id
    StaticIndexing(lhs~, ..) | FieldAccess(lhs~, ..) => ref_root_id(lhs)
    DynamicIndexing(lhs~, ..) => ref_root_id(lhs)
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

  for stmt in stmts {
    match stmt {
      Wire(..) | Inst(..) | Mem(_) | Skip | When(_) => ()
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
fn bump_ref_use(use_counts: Map[TypedRef, Int], reference: TypedRef) -> Unit {
  if reference.ty().is_ground() {
    use_counts[reference] = use_counts.get(reference).unwrap_or(0) + 1
  } else {
    for leaf in flatten_alias_ref(reference) {
      bump_ref_use(use_counts, leaf)
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

// Phase 1 helper: populate wire_leafs, drivers, and use_counts from one statement.
// Connect(lhs, rhs) records the driver for lhs (last-connect wins — iterating
// the body in order naturally overwrites earlier drivers) and bumps use counts
// for all refs appearing in rhs.
fn collect_stmt_info(
  stmt: TypedStmt,
  wire_leafs~: Map[Id, Array[TypedRef]],
  drivers~: Map[TypedRef, TypedExpr],
  use_counts~: Map[TypedRef, Int]
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
      if lhs.ty().is_ground() {
        drivers[lhs] = rhs
      }

      collect_expr_uses(rhs, use_counts)
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
    When(_) => ()
    Inst(..) | Mem(_) | Skip => ()
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
    Reference(reference, ty=_) => {
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
    Reference(reference, ty=_) => {
      resolved_aliases.get(reference).unwrap_or(expr)
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
      if collapsible_connects.contains(lhs) {
        return
      }

      let new_rhs = rewrite_expr(rhs, resolved_aliases)

      if !(new_rhs is Reference(reference, ..) && reference == lhs) {
        body.push(Connect(lhs, new_rhs))
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
    When(_) => body.push(stmt)
  }
}

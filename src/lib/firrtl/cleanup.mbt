/// Conservative readability cleanups for typed FIRRTL.
///
/// This pass deliberately avoids general propagation. In particular, a
/// connection may resize its source, so a wire can become a node only when
/// both types are exactly equal and the wire has one unconditional driver.
pub struct CleanupPass {}

pub fn CleanupPass::new() -> CleanupPass {
  CleanupPass::{}
}

pub impl FIRRTLPass for CleanupPass with run(self, circuit) -> TypedCircuit {
  {
    ..circuit,
    decls: circuit.decls.map(decl => match decl {
      ExtModule(extmod) => ExtModule(extmod)
      Module(mod) => Module(self.cleanup_module(mod))
    }),
  }
}

fn CleanupPass::cleanup_module(self: Self, mod: TypedModule) -> TypedModule {
  let mod = self.cleanup_register_shells(mod)
  let writes: Map[Id, Int] = Map([])
  count_writes(mod.body, writes)
  { ..mod, body: self.cleanup_block(mod.body, writes) }
}


priv struct RegisterShell {
  proxy: Id
  ty: Type
}

fn field_of_proxy(reference: TypedRef, proxy: Id, name: String) -> Bool {
  reference is FieldAccess(
    lhs=Id(root, ty=_),
    field~,
    ty=_,
  ) && root == proxy && field.inner() == name
}

fn q_alias_register(stmt: TypedStmt, proxy: Id) -> (Id, Type)? {
  match stmt {
    Connect(lhs, Reference(Id(register, ty~), ..)) if field_of_proxy(lhs, proxy, "q") => Some((register, ty))
    _ => None
  }
}

fn is_register_bridge(stmt: TypedStmt, register: Id, proxy: Id) -> Bool {
  match stmt {
    Connect(Id(dest, ..), Reference(source, ..)) =>
      dest == register && field_of_proxy(source, proxy, "d")
    _ => false
  }
}

fn is_register_default(stmt: TypedStmt, proxy: Id) -> Bool {
  match stmt {
    Connect(dest, Reference(source, ..)) =>
      field_of_proxy(dest, proxy, "d") && field_of_proxy(source, proxy, "q")
    _ => false
  }
}

fn is_register_decl(stmt: TypedStmt, id: Id, ty: Type) -> Bool {
  match stmt {
    Reg(id=reg_id, ty=reg_ty, ..) | RegReset(id=reg_id, ty=reg_ty, ..) =>
      reg_id == id && reg_ty == ty
    _ => false
  }
}

fn proxy_type(ty: Type) -> Type? {
  match ty {
    Bundle([
      { id: first_id, ty: first_ty, flip: first_flip },
      { id: second_id, ty: second_ty, flip: second_flip },
    ]) => {
      let first_name = first_id.inner()
      let second_name = second_id.inner()
      if
        first_name == "d" && first_flip &&
        second_name == "q" && !second_flip &&
        first_ty == second_ty {
        Some(first_ty)
      } else if
        second_name == "d" && second_flip &&
        first_name == "q" && !first_flip &&
        first_ty == second_ty {
        Some(first_ty)
      } else {
        None
      }
    }
    _ => None
  }
}

fn count_proxy_reads_in_ref(reference: TypedRef, proxy: Id) -> (Int, Bool) {
  match reference {
    Id(id, ..) => (0, id == proxy)
    FieldAccess(lhs=Id(id, ty=_), field~, ty=_) if id == proxy =>
      (if field.inner() == "d" { 1 } else { 0 }, field.inner() != "d" && field.inner() != "q")
    StaticIndexing(lhs~, ..) | FieldAccess(lhs~, ..) => count_proxy_reads_in_ref(lhs, proxy)
    DynamicIndexing(lhs~, index~, ..) => {
      let (count, invalid) = count_proxy_reads_in_ref(lhs, proxy)
      let (index_count, index_invalid) = count_proxy_reads_in_expr(index, proxy)
      (count + index_count, invalid || index_invalid)
    }
  }
}

fn count_proxy_reads_in_expr(expr: TypedExpr, proxy: Id) -> (Int, Bool) {
  match expr {
    Reference(reference, ..) => count_proxy_reads_in_ref(reference, proxy)
    Literal(_) => (0, false)
    Mux(cond~, tval~, fval~, ..) => {
      let (a, ai) = count_proxy_reads_in_expr(cond, proxy)
      let (b, bi) = count_proxy_reads_in_expr(tval, proxy)
      let (c, ci) = count_proxy_reads_in_expr(fval, proxy)
      (a + b + c, ai || bi || ci)
    }
    PrimOp(args~, ..) => {
      let mut count = 0
      let mut invalid = false
      for arg in args {
        let (arg_count, arg_invalid) = count_proxy_reads_in_expr(arg, proxy)
        count += arg_count
        invalid = invalid || arg_invalid
      }
      (count, invalid)
    }
  }
}

fn count_proxy_reads(stmts: Array[TypedStmt], proxy: Id) -> (Int, Bool) {
  let mut count = 0
  let mut invalid = false

  fn add(expr: TypedExpr) -> Unit {
    let (new_count, new_invalid) = count_proxy_reads_in_expr(expr, proxy)
    count += new_count
    invalid = invalid || new_invalid
  }

  for stmt in stmts {
    match stmt {
      Node(expr~, ..) => add(expr)
      Reg(clock~, ..) => add(clock)
      RegReset(clock~, reset~, init~, ..) => { add(clock); add(reset); add(init) }
      Connect(lhs, rhs) => {
        add(rhs)
        if lhs is DynamicIndexing(index~, ..) {
          add(index)
        }
      }
      When({ cond, body, otherwise }) => {
        add(cond)
        let (body_count, body_invalid) = count_proxy_reads(body, proxy)
        count += body_count
        invalid = invalid || body_invalid
        if otherwise is Some(otherwise) {
          let (else_count, else_invalid) = count_proxy_reads(otherwise, proxy)
          count += else_count
          invalid = invalid || else_invalid
        }
      }
      Command(command) => match command {
        Printf(clk~, en~, args~, ..) => { add(clk); add(en); for arg in args { add(arg) } }
        Assert(clk~, pred~, en~, args~, ..) => { add(clk); add(pred); add(en); for arg in args { add(arg) } }
        Stop(clk~, en~, ..) => { add(clk); add(en) }
      }
      _ => ()
    }
  }

  (count, invalid)
}

fn rewrite_shell_ref(
  reference: TypedRef,
  by_proxy: Map[Id, RegisterShell],
  by_register: Map[Id, RegisterShell],
) -> TypedRef {
  match reference {
    Id(id, ..) if by_register.get(id) is Some(shell) => Id(shell.proxy, ty=shell.ty)
    FieldAccess(lhs=Id(id, ty=_), field~, ty=_) if by_proxy.get(id) is Some(shell) && (field.inner() == "d" || field.inner() == "q") =>
      Id(shell.proxy, ty=shell.ty)
    StaticIndexing(lhs~, index~, ty~) => StaticIndexing(
      lhs=rewrite_shell_ref(lhs, by_proxy, by_register), index~, ty~,
    )
    DynamicIndexing(lhs~, index~, ty~) => DynamicIndexing(
      lhs=rewrite_shell_ref(lhs, by_proxy, by_register),
      index=rewrite_shell_expr(index, by_proxy, by_register),
      ty~,
    )
    FieldAccess(lhs~, field~, ty~) => FieldAccess(
      lhs=rewrite_shell_ref(lhs, by_proxy, by_register), field~, ty~,
    )
    other => other
  }
}

fn rewrite_shell_expr(
  expr: TypedExpr,
  by_proxy: Map[Id, RegisterShell],
  by_register: Map[Id, RegisterShell],
) -> TypedExpr {
  match expr {
    Reference(reference, ..) => {
      let reference = rewrite_shell_ref(reference, by_proxy, by_register)
      Reference(reference, ty=reference.ty())
    }
    Mux(cond~, tval~, fval~, ty~) => Mux(
      cond=rewrite_shell_expr(cond, by_proxy, by_register),
      tval=rewrite_shell_expr(tval, by_proxy, by_register),
      fval=rewrite_shell_expr(fval, by_proxy, by_register),
      ty~,
    )
    PrimOp(op~, args~, ty~) => PrimOp(
      op~,
      args=args.map(arg => rewrite_shell_expr(arg, by_proxy, by_register)),
      ty~,
    )
    other => other
  }
}

fn CleanupPass::cleanup_register_shells(_self: Self, mod: TypedModule) -> TypedModule {
  let writes: Map[Id, Int] = Map([])
  count_writes(mod.body, writes)
  let by_proxy: Map[Id, RegisterShell] = Map([])
  let by_register: Map[Id, RegisterShell] = Map([])
  let removed: Set[Int] = Set([])

  for wire_index, stmt in mod.body {
    guard stmt is Wire(id=proxy, ty=proxy_bundle_ty) else { continue }
    guard proxy_type(proxy_bundle_ty) is Some(ty) else { continue }

    let mut alias_index = -1
    let mut register = proxy
    for i, candidate in mod.body {
      if q_alias_register(candidate, proxy) is Some((candidate_register, candidate_ty)) && candidate_ty == ty {
        alias_index = i
        register = candidate_register
        break
      }
    }
    if alias_index == -1 || writes.get(register).unwrap_or(0) != 1 {
      continue
    }

    let mut register_index = -1
    let mut bridge_index = -1
    let mut default_index = -1
    for i, candidate in mod.body {
      if is_register_decl(candidate, register, ty) { register_index = i }
      if is_register_bridge(candidate, register, proxy) { bridge_index = i }
      if is_register_default(candidate, proxy) { default_index = i }
    }

    let (d_reads, invalid_reads) = count_proxy_reads(mod.body, proxy)
    if register_index == -1 || bridge_index == -1 || default_index == -1 || d_reads != 1 || invalid_reads {
      continue
    }

    let shell: RegisterShell = { proxy, ty }
    by_proxy[proxy] = shell
    by_register[register] = shell
    removed.add(wire_index)
    removed.add(alias_index)
    removed.add(bridge_index)
    removed.add(default_index)
  }

  if by_proxy.is_empty() {
    return mod
  }

  fn rewrite_stmt(stmt: TypedStmt) -> TypedStmt {
    match stmt {
      Node(id~, expr~) => Node(id~, expr=rewrite_shell_expr(expr, by_proxy, by_register))
      Reg(id~, ty~, clock~) => {
        let (id, ty) = match by_register.get(id) {
          Some(shell) => (shell.proxy, shell.ty)
          None => (id, ty)
        }
        Reg(id~, ty~, clock=rewrite_shell_expr(clock, by_proxy, by_register))
      }
      RegReset(id~, ty~, clock~, reset~, init~) => {
        let (id, ty) = match by_register.get(id) {
          Some(shell) => (shell.proxy, shell.ty)
          None => (id, ty)
        }
        RegReset(
          id~, ty~,
          clock=rewrite_shell_expr(clock, by_proxy, by_register),
          reset=rewrite_shell_expr(reset, by_proxy, by_register),
          init=rewrite_shell_expr(init, by_proxy, by_register),
        )
      }
      Connect(lhs, rhs) => Connect(
        rewrite_shell_ref(lhs, by_proxy, by_register),
        rewrite_shell_expr(rhs, by_proxy, by_register),
      )
      When({ cond, body, otherwise }) => When({
        cond: rewrite_shell_expr(cond, by_proxy, by_register),
        body: body.map(rewrite_stmt),
        otherwise: otherwise.map(body => body.map(rewrite_stmt)),
      })
      Command(command) => Command(match command {
        Printf(clk~, en~, fmt~, args~) => Printf(
          clk=rewrite_shell_expr(clk, by_proxy, by_register),
          en=rewrite_shell_expr(en, by_proxy, by_register),
          fmt~,
          args=args.map(arg => rewrite_shell_expr(arg, by_proxy, by_register)),
        )
        Assert(clk~, pred~, en~, fmt~, args~) => Assert(
          clk=rewrite_shell_expr(clk, by_proxy, by_register),
          pred=rewrite_shell_expr(pred, by_proxy, by_register),
          en=rewrite_shell_expr(en, by_proxy, by_register),
          fmt~,
          args=args.map(arg => rewrite_shell_expr(arg, by_proxy, by_register)),
        )
        Stop(clk~, en~, code~) => Stop(
          clk=rewrite_shell_expr(clk, by_proxy, by_register),
          en=rewrite_shell_expr(en, by_proxy, by_register),
          code~,
        )
      })
      other => other
    }
  }

  let body = []
  for i, stmt in mod.body {
    if !removed.contains(i) {
      body.push(rewrite_stmt(stmt))
    }
  }
  { ..mod, body }
}

fn root_id(reference: TypedRef) -> Id {
  match reference {
    Id(id, ..) => id
    StaticIndexing(lhs~, ..) | DynamicIndexing(lhs~, ..) | FieldAccess(lhs~, ..) => root_id(lhs)
  }
}

fn increment_write(writes: Map[Id, Int], id: Id, amount: Int) -> Unit {
  writes[id] = writes.get(id).unwrap_or(0) + amount
}

fn count_writes(stmts: Array[TypedStmt], writes: Map[Id, Int]) -> Unit {
  for stmt in stmts {
    match stmt {
      Connect(Id(id, ..), _) => increment_write(writes, id, 1)
      Connect(reference, _) => {
        // A partial aggregate write makes the root ineligible for conversion.
        increment_write(writes, root_id(reference), 2)
      }
      When({ body, otherwise, .. }) => {
        count_writes(body, writes)
        if otherwise is Some(otherwise) {
          count_writes(otherwise, writes)
        }
      }
      _ => ()
    }
  }
}

fn ref_contains_id(reference: TypedRef, id: Id) -> Bool {
  match reference {
    Id(ref_id, ..) => ref_id == id
    StaticIndexing(lhs~, ..) | FieldAccess(lhs~, ..) => ref_contains_id(lhs, id)
    DynamicIndexing(lhs~, index~, ..) => ref_contains_id(lhs, id) || expr_contains_id(index, id)
  }
}

fn expr_contains_id(expr: TypedExpr, id: Id) -> Bool {
  match expr {
    Reference(reference, ..) => ref_contains_id(reference, id)
    Literal(_) => false
    Mux(cond~, tval~, fval~, ..) =>
      expr_contains_id(cond, id) || expr_contains_id(tval, id) || expr_contains_id(fval, id)
    PrimOp(args~, ..) => args.any(arg => expr_contains_id(arg, id))
  }
}

fn CleanupPass::cleanup_block(
  self: Self,
  stmts: Array[TypedStmt],
  writes: Map[Id, Int],
) -> Array[TypedStmt] {
  let result = Array::new(capacity=stmts.length())
  let mut i = 0

  while i < stmts.length() {
    if i + 1 < stmts.length() {
      match (stmts[i], stmts[i + 1]) {
        (
          Wire(id~, ty~),
          Connect(Id(dest_id, ..), rhs),
        ) if
          id == dest_id &&
          writes.get(id).unwrap_or(0) == 1 &&
          rhs.ty() == ty &&
          !expr_contains_id(rhs, id) => {
          result.push(Node(id~, expr=rhs))
          i += 2
          continue
        }
        _ => ()
      }
    }

    let stmt = match stmts[i] {
      When({ cond, body, otherwise }) => When({
        cond,
        body: self.cleanup_block(body, writes),
        otherwise: otherwise.map(body => self.cleanup_block(body, writes)),
      })
      other => other
    }
    result.push(stmt)
    i += 1
  }

  result
}

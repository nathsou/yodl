
pub struct LowerAggregateTypesPass {
  split_memories: Bool
}

pub fn LowerAggregateTypesPass::new(split_memories~: Bool = true) -> Self {
  { split_memories, }
}

pub impl FIRRTLPass for LowerAggregateTypesPass with run(self, circuit: TypedCircuit) -> TypedCircuit {
  self.lower_types(circuit)
}

let delim = "_"


priv struct LoweringTable {
  namespace_: Set[String]
  ref_mapping: Map[TypedRef, Array[TypedRef]]
}

fn LoweringTable::new() -> LoweringTable {
  {
    namespace_: Set::new(),
    ref_mapping: {},
  }
}

fn LoweringTable::register(self: Self, old_ref: TypedRef, new_ref: TypedRef) -> Unit {
  if self.ref_mapping.get(old_ref) is Some(existing) {
    existing.push(new_ref)
  } else {
    self.ref_mapping[old_ref] = [new_ref]
  }
}

fn LowerAggregateTypesPass::lower_types(self: Self, circuit: TypedCircuit) -> TypedCircuit raise {
  let new_decls = Array::new(capacity=circuit.decls.length())
  let module_tables: Map[Id, LoweringTable] = {}

  for decl in circuit.decls {
    let module_table = LoweringTable::new()
    let new_decl = module_table.process_decl(decl, self.split_memories)
    new_decls.push(new_decl)
    module_tables[decl.id()] = module_table
  }

  {
    version: circuit.version,
    id: circuit.id,
    annotations: rewrite_annotations(module_tables, circuit.annotations),
    decls: new_decls,
  }
}

fn rewrite_annotations(module_tables: Map[Id, LoweringTable], annotations: Array[Annotation]) -> Array[Annotation] raise {
  let new_annotations = Array::new(capacity=annotations.length())

  for ann in annotations {
    let target = ann.target()

    if target.mod is Some(target_mod_id) {
      let module_table = module_tables[target_mod_id]

      if target.leaf is Some(leaf_id) {
        // dummy type for lookup
        if module_table.ref_mapping.get(Id(leaf_id, ty=Type::UInt(1))) is Some(new_refs) {
          if ann is MemoryFileInlineAnnotation(..) && new_refs.length() > 1 {
            // TODO: Implement the flatten memories pass.
            raise Failure("MemoryFileInlineAnnotation cannot be applied to memories with aggregate data-types: \{target}")
          }

          for new_ref in new_refs {
            if new_ref is Id(new_leaf_id, ..) {
              let new_target = { ..target, leaf: Some(new_leaf_id) }
              new_annotations.push(ann.with_target(new_target))
            }
          }
        } else {
          // No mapping found; keep original annotation.
          new_annotations.push(ann)
        }
      }
    }
  }

  new_annotations
}

fn LoweringTable::process_decl(self: Self, decl: TypedDecl, split_memories: Bool) -> TypedDecl raise {
  match decl {
    Module(mod) => Module(self.process_module(mod, split_memories))
    ExtModule(extmod) => ExtModule(self.process_ext_module(extmod))
  }
}

fn LoweringTable::process_ext_module(self: Self, extmod: ExtModule) -> ExtModule {
  {
    ..extmod,
    ports: self.flatten_ports(extmod.ports),
  }
}

fn process_module(self: LoweringTable, mod: TypedModule, split_memories: Bool) -> TypedModule raise {
  // TODO: Handle memory annotations
  let new_ports = self.flatten_ports(mod.ports)
  let new_body = Array::new(capacity=mod.body.length())

  for stmt in mod.body {
    self.process_stmt(stmt, new_body, split_memories)
  }

  {
    ..mod,
    ports: new_ports,
    body: new_body,
  }
}

fn flatten_ports(self: LoweringTable, ports: Array[Port]) -> Array[Port] {
  let new_ports = Array::new(capacity=ports.length())

  for port in ports {
    let flattened_fields = self.flatten(prefix=port.id.value(), old_ref=Id(port.id, ty=port.ty))

    for pair in flattened_fields {
      let (old_ref, new_id) = pair
      new_ports.push({
        id: Id::from(new_id),
        ty: old_ref.ty(),
        dir: port.dir,
      })

      let new_ref = Id(Id::from(new_id), ty=old_ref.ty())
      self.register(old_ref, new_ref)
    }
  }

  new_ports
}

fn LoweringTable::process_stmt(self: Self, stmt: TypedStmt, body: Array[TypedStmt], split_memories: Bool) -> Unit raise {
  match stmt {
    Wire(id~, ty~) => {
      for pair in self.flatten(prefix=id.value(), old_ref=Id(id, ty~)) {
        let (old_ref, new_id) = pair
        let field_ty = old_ref.ty()
        body.push(Wire(id=Id::from(new_id), ty=field_ty))
        let new_ref = Id(Id::from(new_id), ty=field_ty)
        self.register(old_ref, new_ref)
      }
    }
    Node(id~, expr~) => {
      let new_expr = self.rewrite_expr(expr, body)
      body.push(Node(id~, expr=new_expr))
      let reference = Id(id, ty=new_expr.ty())
      self.register(reference, reference)
    }
    Reg(id~, ty~, clock~) => {
      let new_clock = self.rewrite_expr(clock, body)
      let sub_refs = self.flatten(prefix=id.value(), old_ref=Id(id, ty~))

      for pair in sub_refs {
        let (old_ref, new_id) = pair
        let field_ty = old_ref.ty()

        body.push(Reg(
          id=Id::from(new_id),
          ty=field_ty,
          clock=new_clock,
        ))

        let new_ref = Id(Id::from(new_id), ty=field_ty)
        self.register(old_ref, new_ref)
      }
    }
    RegReset(id~, ty~, clock~, reset~, init~) => {
      let new_clock = self.rewrite_expr(clock, body)
      let new_reset = self.rewrite_expr(reset, body)
      let sub_refs = self.flatten(prefix=id.value(), old_ref=Id(id, ty~))
      let init_exprs = self.sub_exprs_dfs(self.rewrite_expr(init, body), body)

      for pair, sub_init in @utils.zip2(sub_refs, init_exprs) {
        let (old_ref, new_id) = pair
        let field_ty = old_ref.ty()

        body.push(RegReset(
          id=Id::from(new_id),
          ty=field_ty,
          clock=new_clock,
          reset=new_reset,
          init=self.rewrite_expr(sub_init, body),
        ))

        let new_ref = Id(Id::from(new_id), ty=field_ty)
        self.register(old_ref, new_ref)
      }
    }
    Mem(mem) => {
      if split_memories {
        let original_mem = Id(mem.id, ty=mem.as_bundle())

        for flat_mem in self.split_mem(mem) {
          self.register(original_mem, Id(flat_mem.id, ty=flat_mem.as_bundle()))
          body.push(Mem(flat_mem))
        }
      } else {
        body.push(stmt)
      }
    }
    FlatMem(_) => {
      body.push(stmt)
    }
    Inst(id~, of~, sig~) => {
      let inst_ty = sig.as_bundle()
      let new_name = self.uniquify(id.value(), inst_ty)
      let inst_ref = Id(Id::from(new_name), ty=inst_ty)

      if inst_ty is Bundle(fields) {
        for field in fields {
          let old_ref = FieldAccess(lhs=inst_ref, field=field.id, ty=field.ty)
          for flat in subcomponents(field.id.value(), old_ref) {
            let new_ref = FieldAccess(
              lhs=inst_ref,
              field=Id::from(flat.name),
              ty=flat.ty,
            )

            self.register(flat.reference, new_ref)
          }
        }
      }

      body.push(Inst(id=Id::from(new_name), of~, sig~))
    }
    Connect(lhs, rhs) => {
      let new_rhs = self.rewrite_expr(rhs, body)

      if self.ref_mapping.get(lhs) is Some(new_lhs_list) {
        for new_lhs in new_lhs_list {
          body.push(Connect(new_lhs, new_rhs))
        }
      } else {
        body.push(Connect(lhs, new_rhs))
      }
    }
    When(when) => {
      let new_cond = self.rewrite_expr(when.cond, body)
      let new_body = Array::new(capacity=when.body.length())

      for stmt in when.body {
        self.process_stmt(stmt, new_body, split_memories)
      }

      let new_otherwise = when.otherwise.map(else_body => {
        let new_else = Array::new(capacity=else_body.length())
        for stmt in else_body {
          self.process_stmt(stmt, new_else, split_memories)
        }
        new_else
      })

      body.push(When({
        cond: new_cond,
        body: new_body,
        otherwise: new_otherwise,
      }))
    }
    Command(cmd) => {
      match cmd {
        Printf(clk~, en~, fmt~, args~) => {
          let new_clk = self.rewrite_expr(clk, body)
          let new_en = self.rewrite_expr(en, body)
          let new_args = args.map(arg => self.rewrite_expr(arg, body))
          body.push(Command(Printf(clk=new_clk, en=new_en, fmt~, args=new_args)))
        }
        Stop(clk~, en~, code~) => {
          let new_clk = self.rewrite_expr(clk, body)
          let new_en = self.rewrite_expr(en, body)
          body.push(Command(Stop(clk=new_clk, en=new_en, code~)))
        }
        Assert(clk~, en~, pred~, fmt~, args~) => {
          let new_clk = self.rewrite_expr(clk, body)
          let new_en = self.rewrite_expr(en, body)
          let new_pred = self.rewrite_expr(pred, body)
          let new_args = args.map(arg => self.rewrite_expr(arg, body))
          body.push(Command(Assert(clk=new_clk, en=new_en, pred=new_pred, fmt~, args=new_args)))
        }
      }
    }
    Skip => {
      body.push(Skip)
    }
  }
}

fn LoweringTable::rewrite_expr(self: Self, expr: TypedExpr, body: Array[TypedStmt]) -> TypedExpr raise {
  match expr {
    Reference(reference, ty~) => {
      if self.ref_mapping.get(reference) is Some(new_refs) {
        // If multiple new references exist (e.g., memory clocks), we cannot choose one arbitrarily.
        // This indicates an error in the lowering logic.
        if new_refs.length() == 1 {
          Reference(new_refs[0], ty~)
        } else {
          raise Failure("Reference maps to multiple new references, cannot rewrite: \{reference}")
        }
      } else {
        Reference(reference, ty~)
      }
    }
    Mux(cond~, tval~, fval~, ty~) => {
      Mux(
        cond=self.rewrite_expr(cond, body),
        tval=self.rewrite_expr(tval, body),
        fval=self.rewrite_expr(fval, body),
        ty~
      )
    }
    Literal(value, ty~) => {
      Literal(value, ty~)
    }
    PrimOp(op~, args~, ty~) => {
      PrimOp(op~, args=args.map(arg => self.rewrite_expr(arg, body)), ty~)
    }
  }
}

fn LoweringTable::flatten(self: Self, prefix~: String, old_ref~: TypedRef) -> Array[(TypedRef, String)] {
  let ty = old_ref.ty()
  let safe_prefix = self.uniquify(prefix, ty)
  let results: Array[(TypedRef, String)] = []

  match ty {
    Bundle(fields) => {
      for field in fields {
        let new_id = "\{safe_prefix}\{delim}\{field.id}"
        let field_ref = FieldAccess(lhs=old_ref, field=field.id, ty=field.ty)
        results.push_iter(self.flatten(prefix=new_id, old_ref=field_ref).iter())
      }
    }
    Vec(elem_ty, size) => {
      for i in 0 ..<size {
        let new_id = "\{safe_prefix}\{delim}\{i}"
        let index_ref = StaticIndexing(lhs=old_ref, index=i, ty=elem_ty)
        results.push_iter(self.flatten(prefix=new_id, old_ref=index_ref).iter())
      }
    }
    _ => {
      self.namespace_.add(safe_prefix)
      results.push((old_ref, safe_prefix))
    } 
  }

  results
}

fn LoweringTable::uniquify(self: Self, prefix: String, ty: Type) -> String {
  let mut current_prefix = prefix
  let mut iterations = 0

  // "If a name is already taken, that name will be made unique by appending a suffix _<i> to the
  // name, where i is the lowest nonnegative integer that gives a unique name."

  while subcomponents(current_prefix, Id(Id::from(prefix), ty~)).any(field => self.namespace_.contains(field.name)) {
    current_prefix = "\{prefix}\{delim}\{iterations}"
    iterations += 1
  }

  current_prefix
}

priv struct FlattenedField {
  reference: TypedRef
  name: String
  ty: Type
}

fn subcomponents(prefix: String, reference: TypedRef) -> Iter[FlattenedField] {
  Iter::new((visit: (FlattenedField) -> IterResult) => {
    let ty = reference.ty()
    match ty {
      Bundle(fields) => {
        for field in fields {
          let field_ref = FieldAccess(lhs=reference, field=field.id, ty=field.ty)
          for sub_field in subcomponents("\{prefix}\{delim}\{field.id}", field_ref) {
            guard visit(sub_field) is IterContinue else { break }
          }
        } else {
          IterContinue
        }
      }
      Vec(elem_ty, size) => {
        for i in 0 ..<size {
          let index_ref = StaticIndexing(lhs=reference, index=i, ty=elem_ty)
          for sub_id in subcomponents("\{prefix}\{delim}\{i}", index_ref) {
            guard visit(sub_id) is IterContinue else { break }
          }
        } else {
          IterContinue
        }
      }
      _ => visit({
        reference,
        name: prefix,
        ty,
      })
    }
  })
}

test "subcomponents" {
  let ty = Bundle([
    BundleField::from(id=Id::from("a"), ty=UInt(8)),
    BundleField::from(
      id=Id::from("b"),
      ty=Bundle([
        BundleField::from(id=Id::from("c"), ty=SInt(16)),
        BundleField::from(id=Id::from("d"), ty=Vec(UInt(4), 2)),
      ])
    ),
  ])

  let flat = subcomponents("x", Id(Id::from("x"), ty~)).collect()
  inspect(flat.map(field => field.name), content="[\"x_a\", \"x_b_c\", \"x_b_d_0\", \"x_b_d_1\"]")
}

test "flatten" {
  let table = LoweringTable::new()

  let ty = Bundle([
    BundleField::from(id=Id::from("a"), ty=UInt(8)),
    BundleField::from(
      id=Id::from("b"),
      ty=Bundle([
        BundleField::from(id=Id::from("c"), ty=SInt(16)),
        BundleField::from(id=Id::from("d"), ty=Vec(UInt(4), 2)),
      ])
    ),
  ])

  let old_ref = Id(Id::from("x"), ty~)
  let results = table.flatten(prefix="x", old_ref~)

  inspect(results, content="[(x.a, \"x_a\"), (x.b.c, \"x_b_c\"), (x.b.d[0], \"x_b_d_0\"), (x.b.d[1], \"x_b_d_1\")]")
}

test "flatten with name conflict" {
  let table = LoweringTable::new()
  table.namespace_.add("x_b_d_0") // Simulate existing name to force uniquification.

  let ty = Bundle([
    BundleField::from(id=Id::from("a"), ty=UInt(8)),
    BundleField::from(
      id=Id::from("b"),
      ty=Bundle([
        BundleField::from(id=Id::from("c"), ty=SInt(16)),
        BundleField::from(id=Id::from("d"), ty=Vec(UInt(4), 2)),
      ])
    ),
  ])

  let old_ref = Id(Id::from("x"), ty~)
  let results = table.flatten(prefix="x", old_ref~)
  inspect(results, content="[(x.a, \"x_a\"), (x.b.c, \"x_b_c\"), (x.b.d[0], \"x_b_d_0_0\"), (x.b.d[1], \"x_b_d_1\")]")
}

fn LoweringTable::expr_as_ref(self: Self, expr: TypedExpr, body: Array[TypedStmt]) -> TypedRef {
  match expr {
    Reference(reference, ..) => reference
    _ => {
      let ty = expr.ty();
      let id = Id::from(self.uniquify("ref$", ty))
      body.push(Node(id~, expr~))
      Id(id, ty~)
    }
  }
}

fn LoweringTable::sub_exprs_dfs(self: Self, expr: TypedExpr, body: Array[TypedStmt]) -> Array[TypedExpr] {
  match expr {
    Mux(cond~, tval~, fval~, ty~) => {
      let texprs = self.sub_exprs_dfs(tval, body)
      let fexprs = self.sub_exprs_dfs(fval, body)
      let results = Array::new(capacity=texprs.length())

      for tval_i, fval_i in @utils.zip2(texprs, fexprs) {
        results.push(Mux(cond~, tval=tval_i, fval=fval_i, ty~))
      }

      results
    }
    _ => match expr.ty() {
      Bundle(fields) => {
        let results = Array::new()
        let expr_ref = self.expr_as_ref(expr, body)

        for field in fields {
          let field_expr = Reference(FieldAccess(lhs=expr_ref, field=field.id, ty=field.ty), ty=field.ty)
          results.push_iter(self.sub_exprs_dfs(field_expr, body).iter())
        }

        results
      }
      Vec(elem_ty, size) => {
        let results = Array::new()
        let expr_ref = self.expr_as_ref(expr, body)

        for i in 0 ..<size {
          let index_expr = Reference(StaticIndexing(lhs=expr_ref, index=i, ty=elem_ty), ty=elem_ty)
          results.push_iter(self.sub_exprs_dfs(index_expr, body).iter())
        }

        results
      }
      _ => [expr]
    }
  }
}

fn replace_ref_lhs(reference: TypedRef, new_lhs: TypedRef) -> TypedRef {
  match reference {
    FieldAccess(lhs=Id(_), field~, ty~) => {
      FieldAccess(lhs=new_lhs, field~, ty~)
    }
    FieldAccess(lhs~, field~, ty~) => {
      FieldAccess(lhs=replace_ref_lhs(lhs, new_lhs), field~, ty~)
    }
    StaticIndexing(lhs=Id(_), index~, ty~) => {
      StaticIndexing(lhs=new_lhs, index~, ty~)
    }
    StaticIndexing(lhs~, index~, ty~) => {
      StaticIndexing(lhs=replace_ref_lhs(lhs, new_lhs), index~, ty~)
    }
    _ => reference
  }
}

fn LoweringTable::split_mem(self: Self, mem: Mem) -> Array[Mem] {
  // TODO: Handle name conflicts
  let is_groud_ty = mem.data_type.is_ground()
  let port_types = mem.reader_writer_types()
  let mem_ref = Id(Id::from(mem.id.value()), ty=mem.data_type)
  let split_mems = subcomponents(mem.id.value(), mem_ref).collect()

  for ports, port_type in @utils.zip2([mem.readers, mem.writers, mem.readwriters], [port_types.read, port_types.write, port_types.read_write]) {
    let port_type_fields = port_type.bundle_fields()
    for port in ports {
      let old_port_ref = FieldAccess(lhs=mem_ref, field=port, ty=port_type)
      for flat in split_mems {
        let sub_mem_ref = Id(Id::from(flat.name), ty=flat.ty)
        let port_ref = FieldAccess(lhs=sub_mem_ref, field=port, ty=port_type)
        for field in port_type_fields {
          let field_ref = FieldAccess(lhs=port_ref, field=field.id, ty=field.ty)
          let mut old_field_ref = FieldAccess(lhs=old_port_ref, field=field.id, ty=field.ty)
          let field_name = field.id.value()
          let is_data_field = field_name == "data" || field_name == "wdata" || field_name == "rdata"
          let is_mask_field = field_name == "mask" || field_name == "wmask"

          if !is_groud_ty && (is_data_field || is_mask_field) {
            old_field_ref = replace_ref_lhs(flat.reference, old_field_ref)
          }

          self.register(old_field_ref, field_ref)
        }
      }
    }
  }

  split_mems.map(flat => {
    ..mem,
    id: Id::from(flat.name),
    data_type: flat.ty,
  })
}

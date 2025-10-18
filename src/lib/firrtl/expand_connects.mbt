
pub struct ExpandConnectsPass {
  mut next_ref_id: Int
}

impl FIRRTLRewriter for ExpandConnectsPass

pub fn ExpandConnectsPass::new() -> Self {
  { next_ref_id: 0 }
}

pub impl FIRRTLPass for ExpandConnectsPass with run(self, circuit) -> TypedCircuit raise {
  self.rewrite_circuit(circuit)
}

impl FIRRTLRewriter for ExpandConnectsPass with rewrite_connect_stmt(self, lhs, rhs, stmts~) -> Unit raise {
  let rhs = self.rewrite_expr(rhs, stmts~)

  if lhs is DynamicIndexing(lhs=indexing_lhs, index~, ty=_) {
    let target = match rhs {
      Reference(reference, ty=_) => reference
      _ => {
        let id = Id::from("dynassign\{self.next_ref_id}$")
        self.next_ref_id += 1
        stmts.push(Node(id~, expr=rhs))
        Id(id, ty=rhs.ty().no_flips())
      }
    }

    let _ = self.dynamic_indexing_to_static(
      lhs=self.rewrite_ref(indexing_lhs, stmts),
      index~,
      stmts~,
      target~,
      flip=true,
    )
  } else {
    self.connect(
      lhs=self.rewrite_ref(lhs, stmts),
      rhs~,
      body=stmts,
    )
  }
}

impl FIRRTLRewriter for ExpandConnectsPass with rewrite_ref(self, reference, stmts) -> TypedRef raise {
  match reference {
    DynamicIndexing(lhs~, index~, ty~) => {
      let target = Id::from("dynidx\{self.next_ref_id}$")
      self.next_ref_id += 1
      let no_flips_ty = ty.no_flips()
      stmts.push(Wire(id=target, ty=no_flips_ty))
      self.dynamic_indexing_to_static(lhs=self.rewrite_ref(lhs, stmts), index~, stmts~, target=Id(target, ty=no_flips_ty), flip=false)
    }
    StaticIndexing(lhs~, index~, ty~) => {
      StaticIndexing(
        lhs=self.rewrite_ref(lhs, stmts),
        index~,
        ty~,
      )
    }
    FieldAccess(lhs~, field~, ty~) => {
      FieldAccess(
        lhs=self.rewrite_ref(lhs, stmts),
        field~,
        ty~,
      )
    }
    _ => reference
  }
}

fn ExpandConnectsPass::dynamic_indexing_to_static(
  self: Self,
  lhs~: TypedRef,
  index~: TypedExpr,
  stmts~: Array[TypedStmt],
  target~: TypedRef,
  flip~: Bool,
) -> TypedRef raise {
  if lhs.ty() is Vec(elem_ty, len) {
    let cases: Array[(TypedExpr, Array[TypedStmt])] = []
    let index_bits = @utils.significant_bits(BigInt::from_int(len - 1))

    for i in 0 ..<len {
      let case_cond = PrimOp(
        op=Eq,
        args=[index, Literal(UInt(width=index_bits, radix=None, value=BigInt::from_int(i)), ty=UInt(index_bits))],
        ty=Type::bool(),
      )
      let case_ref = StaticIndexing(lhs~, index=i, ty=elem_ty)

      if !flip {
        let body = []
        self.connect(lhs=target, rhs=Reference(case_ref, ty=elem_ty), body~)
        cases.push((case_cond, body))
      } else {
        let body = []
        self.connect(lhs=case_ref, rhs=Reference(target, ty=elem_ty), body~)
        cases.push((case_cond, body))
      }
    }

    let default = cases.unsafe_pop().1
    let when_tree = Expr::build_when_tree(cases, default=Some(default))
    self.next_ref_id += 1
    stmts.push_iter(when_tree.iter())

    target
  } else {
    raise Failure("Dynamic indexing is only supported on Vec types, got: \{lhs.ty()}")
  }
}

fn ExpandConnectsPass::expr_as_ref(self: Self, expr~: TypedExpr, body~: Array[TypedStmt]) -> TypedRef {
  match expr {
    Reference(reference, ..) => reference
    _ => {
      let id = Id::from("expconn\{self.next_ref_id}$")
      self.next_ref_id += 1
      body.push(Node(id~, expr=expr))
      Id(id, ty=expr.ty())
    }
  }
}

// FIRRTL spec 5.0 - Section 8.3.1 - The Connection Algorithm
fn ExpandConnectsPass::connect(self: Self, lhs~: TypedRef, rhs~: TypedExpr, body~: Array[TypedStmt]) -> Unit raise {
  match lhs.ty().without_const() {
    Const(_) | UInt(_) | SInt(_) | Clock | Reset | AsyncReset => {
      body.push(Connect(self.rewrite_ref(lhs, body), self.rewrite_expr(rhs, stmts=body)))
    }
    Vec(elem_ty, size) => {
      let rhs_ref = self.expr_as_ref(expr=rhs, body~)

      for i in 0 ..<size {
        let elem_lhs = StaticIndexing(lhs~, index=i, ty=elem_ty)
        let elem_rhs = TypedExpr::Reference(StaticIndexing(lhs=rhs_ref, index=i, ty=elem_ty), ty=elem_ty)
        self.connect(lhs=elem_lhs, rhs=elem_rhs, body~)
      }
    }
    Bundle(fields) => {
      let rhs_ref = self.expr_as_ref(expr=rhs, body~)

      for field in fields {
        let field_lhs = FieldAccess(lhs~, field=field.id, ty=field.ty)
        let field_rhs = FieldAccess(lhs=rhs_ref, field=field.id, ty=field.ty)

        if !field.flip {
          self.connect(lhs=field_lhs, rhs=Reference(field_rhs, ty=field.ty), body~)
        } else {
          self.connect(lhs=field_rhs, rhs=Reference(field_lhs, ty=field.ty), body~)
        }
      }
    }
  }
}

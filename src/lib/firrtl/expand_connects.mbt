
pub struct ExpandConnectsPass {
  mut next_ref_id: Int
}

pub fn ExpandConnectsPass::new() -> Self {
  { next_ref_id: 0 }
}

pub impl FIRRTLPass for ExpandConnectsPass with run(self, circuit) -> TypedCircuit raise {
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

fn ExpandConnectsPass::rewrite_module(self: Self, mod: TypedModule) -> TypedModule {
  let new_body = []

  for stmt in mod.body {
    self.process_stmt(stmt, new_body)
  }

  {
    public: mod.public,
    id: mod.id,
    ports: mod.ports,
    body: new_body,
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
fn ExpandConnectsPass::connect(self: Self, lhs~: TypedRef, rhs~: TypedExpr, body~: Array[TypedStmt]) -> Unit {
  match rhs.ty().without_const() {
    Const(_) | UInt(_) | SInt(_) | UIntInferred | SIntInferred | Clock | Reset | AsyncReset => {
      body.push(Connect(lhs, rhs))
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

fn ExpandConnectsPass::process_stmt(self: Self, stmt: TypedStmt, outer_body: Array[TypedStmt]) -> Unit {
  match stmt {
    Connect(lhs, rhs) => {
      self.connect(lhs~, rhs~, body=outer_body)
    }
    When({ cond, body, otherwise }) => {
      let new_body = Array::new(capacity=body.length())

      for stmt in body {
        self.process_stmt(stmt, new_body)
      }

      let new_otherwise = match otherwise {
        None => None
        Some(otherwise) => {
          let new_otherwise = Array::new(capacity=otherwise.length())

          for stmt in otherwise {
            self.process_stmt(stmt, new_otherwise)
          }

          Some(new_otherwise)
        }
      }

      outer_body.push(When({ cond, body: new_body, otherwise: new_otherwise }))
    }
    _ => {
      outer_body.push(stmt)
    }
  }
}

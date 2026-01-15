using @utils { type Scope, max, min, pow2 }

type TypeEnv = Scope[Id, Type]

pub fn type_check_circuit(circ: UntypedCircuit) -> TypedCircuit raise {
  let circuit_scope = TypeEnv::new()

  {
    version: circ.version,
    id: circ.id,
    annotations: circ.annotations,
    decls: circ.decls.map(decl => match decl {
      ExtModule(ext) => ExtModule(ext)
      Module(mod) => Module(circuit_scope.check_module(mod))
    }),
  }
}

fn TypeEnv::check_module(self: TypeEnv, mod: UntypedModule) -> TypedModule raise {
  let mod_scope = self.child()

  for port in mod.ports {
    mod_scope.declare_(port.id, port.ty)
  }

  {
    public: mod.public,
    id: mod.id,
    ports: mod.ports,
    body: mod.body.map(stmt => mod_scope.check_stmt(stmt)),
  }
}

fn TypeEnv::check_stmt(self: TypeEnv, stmt: UntypedStmt) -> TypedStmt raise {
  match stmt {
    Node(id~, expr~) => {
      let expr = self.check_expr(expr)
      self.declare_(id, expr.ty())
      Node(id~, expr~)
    }
    Wire(id~, ty~) => {
      self.declare_(id, ty)
      Wire(id~, ty~)
    }
    Inst(id~, of~, sig~) => {
      self.declare_(id, sig.as_bundle())
      Inst(id~, of~, sig~)
    }
    Reg(id~, ty~, clock~) => {
      let clock = self.expect(clock, Clock)
      self.declare_(id, ty)
      Reg(id~, ty~, clock~)
    }
    RegReset(id~, ty~, clock~, reset~, init~) => {
      let clock = self.expect(clock, Clock)
      let reset = self.check_expr(reset)

      if !(reset.ty() is (UInt(1) | Reset | AsyncReset)) {
        raise Failure::Failure("Register reset must be of type UInt<1>, Reset, or AsyncReset, got '\{reset.ty()}'")
      }

      let init = self.expect(init, ty)
      self.declare_(id, ty)
      RegReset(id~, ty~, clock~, reset~, init~)
    }
    Mem(mem) => {
      self.declare_(mem.id, mem.as_bundle())
      Mem(mem)
    }
    Connect(lhs, rhs) => {
      let lhs = self.check_ref(lhs)
      let rhs = self.check_expr(rhs)
      let rhs_ty = rhs.ty()

      if !lhs.ty().is_equivalent_to(rhs_ty) {
        raise Failure::Failure("Cannot connect '\{rhs_ty}' to '\{lhs.ty()}'")
      }

      Connect(lhs, rhs)
    }
    When({ cond, body, otherwise }) => {
      let cond = self.expect(cond, UInt(1))
      let body = {
        let then_scope = self.child()
        body.map(stmt => then_scope.check_stmt(stmt))
      }

      let otherwise = match otherwise {
        Some(else_block) => Some({
          let else_scope = self.child()
          else_block.map(stmt => else_scope.check_stmt(stmt))
        })
        None => None
      }

      When({ cond, body, otherwise })
    }
    Command(cmd) => {
      match cmd {
        Printf(clk~, en~, fmt~, args~) => {
          let clk = self.expect(clk, Clock)
          let en = self.expect(en, UInt(1))
          let args = args.map(arg => self.check_expr(arg))
          Command(Printf(clk~, en~, fmt~, args~))
        }
        Assert(clk~, pred~, en~, fmt~, args~) => {
          let clk = self.expect(clk, Clock)
          let pred = self.expect(pred, UInt(1))
          let en = self.expect(en, UInt(1))
          let args = args.map(arg => self.check_expr(arg))
          Command(Assert(clk~, pred~, en~, fmt~, args~))
        }
        Stop(clk~, en~, code~) => {
          let clk = self.expect(clk, Clock)
          let en = self.expect(en, UInt(1))
          Command(Stop(clk~, en~, code~))
        }
      }
    }
    Skip => Skip
  }
}

fn TypeEnv::expect(self: TypeEnv, expr: UntypedExpr, expected: Type) -> TypedExpr raise {
  let typed = self.check_expr(expr)

  if typed.ty() != expected {
    raise Failure::Failure("Expected type '\{expected}', got '\{typed.ty()}'")
  }

  typed
}

fn TypeEnv::check_expr(self: TypeEnv, expr: UntypedExpr) -> TypedExpr raise {
  match expr {
    Reference(r, ty=_) => {
      let reference = self.check_ref(r)
      TypedExpr::Reference(reference, ty=reference.ty())
    }
    Literal(UInt(width~, ..) | SInt(width~, ..) as lit, ty=_) => {
      let ty = if lit is UInt(..) {
        Type::UInt(width)
      } else {
        Type::SInt(width)
      }

      TypedExpr::Literal(lit, ty~)
    }
    Mux(cond~, tval~, fval~, ty=_) => {
      let cond = self.check_expr(cond)
      let tval = self.check_expr(tval)
      let fval = self.check_expr(fval)
      let tval_ty = tval.ty()
      let fval_ty = fval.ty()

      if !(cond.ty() is Type::UInt(1)) {
        raise Failure::Failure("Mux condition must be of type UInt<1>, got '\{cond.ty()}'")
      }

      let ty: Type = match (tval_ty, fval_ty) {
        (UInt(w1), UInt(w2)) => UInt(max(w1, w2))
        (SInt(w1), SInt(w2)) => SInt(max(w1, w2))
        (_, _) if tval_ty == fval_ty => tval_ty
        _ => raise Failure::Failure("Mux true and false values are incompatible, got '\{tval_ty}' and '\{fval_ty}'")
      }

      TypedExpr::Mux(cond~, tval~, fval~, ty~)
    }
    PrimOp(op~, args~, ty=_) => {
      let args = args.map(arg => self.check_expr(arg))
      let arg_tys = args.map(arg => arg.ty())

      let ty: Type = match (op, arg_tys, args) {
        (Add | Sub, [UInt(w1), UInt(w2)], _) => UInt(max(w1, w2) + 1)
        (Add | Sub, [SInt(w1), SInt(w2)], _) => SInt(max(w1, w2) + 1)
        (Mul, [UInt(w1), UInt(w2)], _) => UInt(w1 + w2)
        (Mul, [SInt(w1), SInt(w2)], _) => SInt(w1 + w2)
        (Div, [UInt(num), UInt(_)], _) => UInt(num)
        (Div, [SInt(num), SInt(_)], _) => SInt(num + 1)
        (Rem, [UInt(num), UInt(den)], _) => UInt(min(num, den))
        (Rem, [SInt(num), SInt(den)], _) => SInt(min(num, den))
        (Eq | Neq | Lt | Leq | Gt | Geq, [UInt(_), UInt(_)] | [SInt(_), SInt(_)], _) => UInt(1)
        (Pad, [UInt(w), _], [_, Literal(value, ..)]) => UInt(max(w, value.as_int()))
        (Pad, [SInt(w), _], [_, Literal(value, ..)]) => SInt(max(w, value.as_int()))
        (AsUInt, [UInt(w) | SInt(w)], _) => UInt(w)
        (AsUInt, [Clock | Reset | AsyncReset], _) => UInt(1)
        (AsSInt, [UInt(w) | SInt(w)], _) => SInt(w)
        (AsSInt, [Clock | Reset | AsyncReset], _) => SInt(1)
        (AsClock, [UInt(1) | SInt(1) | Clock | Reset | AsyncReset], _) => Clock
        (AsAsyncReset, [AsyncReset | UInt(1) | SInt(1) | Clock | Reset], _) => AsyncReset
        (Shl, [UInt(w), _], [_, Literal(value, ..)]) => UInt(w + value.as_int())
        (Shl, [SInt(w), _], [_, Literal(value, ..)]) => SInt(w + value.as_int())
        (Shr, [UInt(w), _], [_, Literal(value, ..)]) => UInt(max(w - value.as_int(), 0))
        (Shr, [SInt(w), _], [_, Literal(value, ..)]) => SInt(max(w - value.as_int(), 1))
        (Dshl, [UInt(w1), UInt(w2)], _) => UInt(w1 + pow2(w2).to_int() - 1)
        (Dshl, [SInt(w1), UInt(w2)], _) => SInt(w1 + pow2(w2).to_int() - 1)
        (Dshr, [UInt(w1), UInt(_)], _) => UInt(w1)
        (Dshr, [SInt(w1), UInt(_)], _) => SInt(w1)
        (Cvt, [UInt(w)], _) => SInt(w + 1)
        (Cvt, [SInt(w)], _) => SInt(w)
        (Neg, [UInt(w) | SInt(w)], _) => SInt(w + 1)
        (Not, [UInt(w) | SInt(w)], _) => UInt(w)
        (And | Or | Xor, [UInt(w1), UInt(w2)] | [SInt(w1), SInt(w2)], _) => UInt(max(w1, w2))
        (Andr | Orr | Xorr, [UInt(_) | SInt(_)], _) => UInt(1)
        (Cat, [UInt(w1), UInt(w2)] | [SInt(w1), SInt(w2)], _) => UInt(w1 + w2)
        (Bits, [UInt(w) | SInt(w), _, _], [_, Literal(hi, ..), Literal(lo, ..)]) => {
          let hi = hi.as_int()
          let lo = lo.as_int()

          if hi < lo || hi >= w || lo < 0 {
            raise Failure::Failure("Invalid bit range '\{hi}:\{lo}' for type of width '\{w}'")
          }

          UInt(hi - lo + 1)
        }
        (Head, [UInt(w) | SInt(w), _], [_, Literal(value, ..)]) => {
          let n = value.as_int()

          if n < 0 || n > w {
            raise Failure::Failure("Invalid head width '\{n}' for type of width '\{w}'")
          }

          UInt(n)
        }
        (Tail, [UInt(w) | SInt(w), _], [_, Literal(value, ..)]) => {
          let n = value.as_int()

          if n < 0 || n > w {
            raise Failure::Failure("Invalid tail width '\{n}' for type of width '\{w}'")
          }

          UInt(w - n)
        }
        _ => raise Failure::Failure("Unsupported primitive operation '\{op}' with argument types '\{arg_tys}'")
      }

      PrimOp(op~, args~, ty~)
    }
  }
}

fn TypeEnv::check_ref(self: TypeEnv, r: UntypedRef) -> TypedRef raise {
  match r {
    Id(id, ty=_) => Id(id, ty=self.resolve(id).unwrap_or_error(Failure::Failure("Undefined identifier '\{id}'")))
    StaticIndexing(lhs~, index~, ty=_) => {
      let lhs = self.check_ref(lhs)

      if lhs.ty() is Vec(elem_ty, size) {
        if index < 0 || index >= size {
          raise Failure::Failure("Index '\{index}' out of bounds for vector of size '\{size}'")
        }

        StaticIndexing(lhs~, index~, ty=elem_ty)
      } else {
        raise Failure::Failure("Cannot index non-vector type '\{lhs.ty()}'")
      }
    }
    DynamicIndexing(lhs~, index~, ty=_) => {
      let lhs = self.check_ref(lhs)
      let index = self.check_expr(index)

      if lhs.ty() is Vec(elem_ty, _) {
        if !(index.ty() is UInt(_)) {
          raise Failure::Failure("Dynamic index must be of type UInt, got '\{index.ty()}'")
        }

        DynamicIndexing(lhs~, index~, ty=elem_ty)
      } else {
        raise Failure::Failure("Cannot index non-vector type '\{lhs.ty()}'")
      }
    }
    FieldAccess(lhs~, field~, ty=_) => {
      let lhs = self.check_ref(lhs)

      if lhs.ty() is Bundle(fields) {
        match fields.search_by(f => f.id == field) {
          Some(idx) => FieldAccess(lhs~, field~, ty=fields[idx].ty)
          None => raise Failure::Failure("Field '\{field}' not found in bundle type '\{lhs.ty()}'")
        }
      } else {
        raise Failure::Failure("Cannot access field '\{field}' of non-bundle type '\{lhs.ty()}'")
      }
    }
  }
}

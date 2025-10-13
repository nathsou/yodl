pub typealias @utils.Scope[Id, Type] as TypeEnv

pub fn type_check_circuit(circ: Circuit[Expr]) -> Circuit[TypedExpr] raise {
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

fn TypeEnv::check_module(self: Self, mod: Module[Expr]) -> Module[TypedExpr] raise {
  let mod_scope = self.child()

  for port in mod.ports {
    mod_scope.declare(port.id, port.ty)
  }

  {
    public: mod.public,
    id: mod.id,
    ports: mod.ports,
    body: mod.body.map(stmt => mod_scope.check_stmt(stmt)),
  }
}

fn TypeEnv::check_stmt(self: Self, stmt: Stmt[Expr]) -> Stmt[TypedExpr] raise {
  match stmt {
    Node(id~, expr~) => {
      let expr = self.check_expr(expr)
      self.declare(id, expr.ty())
      Node(id~, expr~)
    }
    Wire(id~, ty~) => {
      self.declare(id, ty)
      Wire(id~, ty~)
    }
    Inst(id~, of~, sig~) => {
      self.declare(id, sig.as_bundle())
      Inst(id~, of~, sig~)
    }
    Reg(id~, ty~, clock~) => {
      let clock = self.expect(clock, Clock)
      self.declare(id, ty)
      Reg(id~, ty~, clock~)
    }
    RegReset(id~, ty~, clock~, reset~, init~) => {
      let clock = self.expect(clock, Clock)
      let reset = self.check_expr(reset)

      if !(reset.ty() is (UInt(1) | Reset | AsyncReset)) {
        raise Failure("Register reset must be of type UInt<1>, Reset, or AsyncReset, got '\{reset.ty()}'")
      }

      let init = self.expect(init, ty)
      self.declare(id, ty)
      RegReset(id~, ty~, clock~, reset~, init~)
    }
    Mem(mem) => {
      self.declare(mem.id, mem.as_bundle())
      Mem(mem)
    }
    Connect(lhs, rhs) => {
      let lhs = self.check_ref(lhs)
      let rhs = self.check_expr(rhs)
      let rhs_ty = rhs.ty()

      if !lhs.ty.is_equivalent_to(rhs_ty) {
        raise Failure("Cannot connect '\{rhs_ty}' to '\{lhs.ty}'")
      }

      Connect(lhs.value, rhs)
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

fn TypeEnv::expect(self: Self, expr: Expr, expected: Type) -> TypedExpr raise {
  let typed = self.check_expr(expr)

  if typed.ty() != expected {
    raise Failure("Expected type '\{expected}', got '\{typed.ty()}'")
  }

  typed
}

fn TypeEnv::check_expr(self: Self, expr: Expr) -> TypedExpr raise {
  match expr {
    Reference(r) => {
      let { value, ty } = self.check_ref(r)
      TypedExpr::Reference(reference=value, ty~)
    }
    Literal(UInt(width~, ..) | SInt(width~, ..) as lit) => {
      let ty = if lit is UInt(..) {
        Type::UInt(width)
      } else {
        Type::SInt(width)
      }

      TypedExpr::Literal(value=lit, ty~)
    }
    Mux(cond~, tval~, fval~) => {
      let cond = self.check_expr(cond)
      let tval = self.check_expr(tval)
      let fval = self.check_expr(fval)
      let tval_ty = tval.ty()
      let fval_ty = fval.ty()

      if !(cond.ty() is Type::UInt(1)) {
        raise Failure("Mux condition must be of type UInt<1>, got '\{cond.ty()}'")
      }

      if tval_ty != fval_ty {
        raise Failure("Mux true and false values must have the same type, got '\{tval_ty}' and '\{fval_ty}'")
      }

      TypedExpr::Mux(cond~, tval~, fval~, ty=tval_ty)
    }
    PrimOp(op~, args~) => {
      let args = args.map(arg => self.check_expr(arg))
      let arg_tys = args.map(arg => arg.ty())

      let ty: Type = match (op, arg_tys, args) {
        (Add | Sub, [UInt(w1), UInt(w2)], _) => UInt(@utils.max(w1, w2) + 1)
        (Add | Sub, [SInt(w1), SInt(w2)], _) => SInt(@utils.max(w1, w2) + 1)
        (Mul, [UInt(w1), UInt(w2)], _) => UInt(w1 + w2)
        (Mul, [SInt(w1), SInt(w2)], _) => SInt(w1 + w2)
        (Div, [UInt(num), UInt(_)], _) => UInt(num)
        (Div, [SInt(num), SInt(_)], _) => SInt(num + 1)
        (Rem, [UInt(num), UInt(den)], _) => UInt(@utils.min(num, den))
        (Rem, [SInt(num), SInt(den)], _) => SInt(@utils.min(num, den))
        (Eq | Neq | Lt | Leq | Gt | Geq, [UInt(_), UInt(_)] | [SInt(_), SInt(_)], _) => UInt(1)
        (Pad, [UInt(w), _], [_, Literal(value~, ..)]) => UInt(@utils.max(w, value.as_int()))
        (Pad, [SInt(w), _], [_, Literal(value~, ..)]) => SInt(@utils.max(w, value.as_int()))
        (AsUInt, [UInt(w) | SInt(w)], _) => UInt(w)
        (AsUInt, [Clock | Reset | AsyncReset], _) => UInt(1)
        (AsSInt, [UInt(w) | SInt(w)], _) => SInt(w)
        (AsSInt, [Clock | Reset | AsyncReset], _) => SInt(1)
        (AsClock, [UInt(1) | SInt(1) | Clock | Reset | AsyncReset], _) => Clock
        (AsAsyncReset, [AsyncReset | UInt(1) | SInt(1) | Clock | Reset], _) => AsyncReset
        (Shl, [UInt(w), _], [_, Literal(value~, ..)]) => UInt(w + value.as_int())
        (Shl, [SInt(w), _], [_, Literal(value~, ..)]) => SInt(w + value.as_int())
        (Shr, [UInt(w), _], [_, Literal(value~, ..)]) => UInt(@utils.max(w - value.as_int(), 0))
        (Shr, [SInt(w), _], [_, Literal(value~, ..)]) => SInt(@utils.max(w - value.as_int(), 1))
        (Dshl, [UInt(w1), UInt(w2)], _) => UInt(w1 + @utils.pow2(w2).to_int() - 1)
        (Dshl, [SInt(w1), UInt(w2)], _) => SInt(w1 + @utils.pow2(w2).to_int() - 1)
        (Dshr, [UInt(w1), UInt(_)], _) => UInt(w1)
        (Dshr, [SInt(w1), UInt(_)], _) => SInt(w1)
        (Cvt, [UInt(w)], _) => SInt(w + 1)
        (Cvt, [SInt(w)], _) => SInt(w)
        (Neg, [UInt(w) | SInt(w)], _) => SInt(w + 1)
        (Not, [UInt(w) | SInt(w)], _) => UInt(w)
        (And | Or | Xor, [UInt(w1), UInt(w2)] | [SInt(w1), SInt(w2)], _) => UInt(@utils.max(w1, w2))
        (Andr | Orr | Xorr, [UInt(_) | SInt(_)], _) => UInt(1)
        (Cat, [UInt(w1), UInt(w2)] | [SInt(w1), SInt(w2)], _) => UInt(w1 + w2)
        (Bits, [UInt(w) | SInt(w), _, _], [_, Literal(value=hi, ..), Literal(value=lo, ..)]) => {
          let hi = hi.as_int()
          let lo = lo.as_int()

          if hi < lo || hi >= w || lo < 0 {
            raise Failure("Invalid bit range '\{hi}:\{lo}' for type of width '\{w}'")
          }

          UInt(hi - lo + 1)
        }
        (Head, [UInt(w) | SInt(w), _], [_, Literal(value~, ..)]) => {
          let n = value.as_int()

          if n < 0 || n > w {
            raise Failure("Invalid head width '\{n}' for type of width '\{w}'")
          }

          UInt(n)
        }
        (Tail, [UInt(w) | SInt(w), _], [_, Literal(value~, ..)]) => {
          let n = value.as_int()

          if n < 0 || n > w {
            raise Failure("Invalid tail width '\{n}' for type of width '\{w}'")
          }

          UInt(w - n)
        }
        _ => raise Failure("Unsupported primitive operation '\{op}' with argument types '\{arg_tys}'")
      }

      TypedExpr::PrimOp(op~, args~, ty~)
    }
  }
}

priv struct Typed[T] {
  value: T
  ty: Type
}

fn TypeEnv::check_ref(self: Self, r: Reference[Expr]) -> Typed[Reference[TypedExpr]] raise {
  match r {
    Id(id) => { value: Id(id), ty: self.resolve(id).or_error(Failure("Undefined identifier '\{id}'")) }
    StaticIndexing(lhs~, index~) => {
      let lhs = self.check_ref(lhs)

      if lhs.ty is Vec(elem_ty, size) {
        if index < 0 || index >= size {
          raise Failure("Index '\{index}' out of bounds for vector of size '\{size}'")
        }

        { value: StaticIndexing(lhs=lhs.value, index~), ty: elem_ty }
      } else {
        raise Failure("Cannot index non-vector type '\{lhs.ty}'")
      }
    }
    DynamicIndexing(lhs~, index~) => {
      let lhs = self.check_ref(lhs)
      let index = self.check_expr(index)

      if lhs.ty is Vec(elem_ty, _) {
        if !(index.ty() is UInt(_)) {
          raise Failure("Dynamic index must be of type UInt, got '\{index.ty()}'")
        }

        { value: DynamicIndexing(lhs=lhs.value, index~), ty: elem_ty }
      } else {
        raise Failure("Cannot index non-vector type '\{lhs.ty}'")
      }
    }
    FieldAccess(lhs~, field~) => {
      let lhs = self.check_ref(lhs)

      if lhs.ty is Bundle(fields) {
        match fields.search_by(f => f.id == field) {
          Some(idx) => { value: FieldAccess(lhs=lhs.value, field~), ty: fields[idx].ty }
          None => raise Failure("Field '\{field}' not found in bundle type '\{lhs.ty}'")
        }
      } else {
        raise Failure("Cannot access field '\{field}' of non-bundle type '\{lhs.ty}'")
      }
    }
  }
}


pub trait FIRRTLPass {
  run(self: Self, TypedCircuit) -> TypedCircuit raise
}

pub trait FIRRTLRewriter {
  rewrite_expr(self: Self, TypedExpr, stmts~: Array[TypedStmt]) -> TypedExpr raise = _
  rewrite_reference_expr(self: Self, reference: TypedRef, ty~: Type, stmts~: Array[TypedStmt]) -> TypedExpr raise = _
  rewrite_mux_expr(self: Self, cond~: TypedExpr, tval~: TypedExpr, fval~: TypedExpr, ty~: Type, stmts~: Array[TypedStmt]) -> TypedExpr raise = _
  rewrite_literal_expr(self: Self, value~: Literal, ty~: Type, stmts: Array[TypedStmt]) -> TypedExpr raise = _
  rewrite_primop_expr(self: Self, op~: PrimOp, args~: Array[TypedExpr], ty~: Type, stmts~: Array[TypedStmt]) -> TypedExpr raise = _

  rewrite_stmt(self: Self, stmt: TypedStmt, stmts~: Array[TypedStmt]) -> Unit raise = _
  rewrite_node_stmt(self: Self, id~: Id, expr~: TypedExpr, stmts~: Array[TypedStmt]) -> Unit raise = _
  rewrite_wire_stmt(self: Self, id~: Id, ty~: Type, stmts~: Array[TypedStmt]) -> Unit raise = _
  rewrite_inst_stmt(self: Self, id~: Id, of~: Id, sig~: ModuleSignature, stmts~: Array[TypedStmt]) -> Unit raise = _
  rewrite_reg_stmt(self: Self, id~: Id, ty~: Type, clock~: TypedExpr, stmts~: Array[TypedStmt]) -> Unit raise = _
  rewrite_regreset_stmt(self: Self, id~: Id, ty~: Type, clock~: TypedExpr, reset~: TypedExpr, init~: TypedExpr, stmts~: Array[TypedStmt]) -> Unit raise = _
  rewrite_connect_stmt(self: Self, lhs: TypedRef, rhs: TypedExpr, stmts~: Array[TypedStmt]) -> Unit raise = _
  rewrite_when_stmt(self: Self, when: TypedWhen, stmts~: Array[TypedStmt]) -> Unit raise = _
  rewrite_mem_stmt(self: Self, mem: Mem, stmts~: Array[TypedStmt]) -> Unit raise = _
  rewrite_flat_mem_stmt(self: Self, mem: FlatMem, stmts~: Array[TypedStmt]) -> Unit raise = _
  rewrite_command_stmt(self: Self, cmd: TypedCommand, stmts~: Array[TypedStmt]) -> Unit raise = _
  rewrite_skip_stmt(self: Self, stmts~: Array[TypedStmt]) -> Unit raise = _

  rewrite_ref(self: Self, r: TypedRef, stmts: Array[TypedStmt]) -> TypedRef raise = _
  rewrite_module(self: Self, mod: TypedModule) -> TypedModule raise = _
  rewrite_extmodule(self: Self, extmod: ExtModule) -> ExtModule raise = _
  rewrite_circuit(self: Self, circuit: TypedCircuit) -> TypedCircuit raise = _
}

impl FIRRTLRewriter with rewrite_circuit(self, circuit) -> TypedCircuit raise {
  {
    version: circuit.version,
    id: circuit.id,
    annotations: circuit.annotations,
    decls: circuit.decls.map(decl => match decl {
      ExtModule(extmod) => ExtModule(self.rewrite_extmodule(extmod))
      Module(mod) => Module(self.rewrite_module(mod))
    }),
  }
}

impl FIRRTLRewriter with rewrite_extmodule(_, extmod) -> ExtModule raise {
  extmod
}

pub fn rewrite_module_default_impl(rewriter: &FIRRTLRewriter, mod: TypedModule) -> TypedModule raise {
  let new_body = Array::new(capacity=mod.body.length())

  for stmt in mod.body {
    rewriter.rewrite_stmt(stmt, stmts=new_body)
  }

  {
    public: mod.public,
    id: mod.id,
    ports: mod.ports,
    body: new_body,
  }
}

impl FIRRTLRewriter with rewrite_module(self, mod) -> TypedModule raise {
  rewrite_module_default_impl(self, mod)
}

impl FIRRTLRewriter with rewrite_ref(_, r, _) -> TypedRef raise {
  r
}

impl FIRRTLRewriter with rewrite_reference_expr(self, reference, ty~, stmts~) -> TypedExpr raise {
  Reference(self.rewrite_ref(reference, stmts), ty~)
}

impl FIRRTLRewriter with rewrite_mux_expr(self, cond~, tval~, fval~, ty~, stmts~) -> TypedExpr raise {
  Mux(
    cond=self.rewrite_expr(cond, stmts~),
    tval=self.rewrite_expr(tval, stmts~),
    fval=self.rewrite_expr(fval, stmts~),
    ty~
  )
}

impl FIRRTLRewriter with rewrite_literal_expr(_, value~, ty~, _) -> TypedExpr raise {
  Literal(value, ty~)
}

impl FIRRTLRewriter with rewrite_primop_expr(self, op~, args~, ty~, stmts~) -> TypedExpr raise {
  PrimOp(op~, args=args.map(arg => self.rewrite_expr(arg, stmts~)), ty~)
}

impl FIRRTLRewriter with rewrite_expr(self, expr, stmts~) -> TypedExpr raise {
  match expr {
    Reference(reference, ty~) => self.rewrite_reference_expr(reference, ty~, stmts~)
    Mux(cond~, tval~, fval~, ty~) => self.rewrite_mux_expr(cond~, tval~, fval~, ty~, stmts~)
    Literal(value, ty~) => self.rewrite_literal_expr(value~, ty~, stmts)
    PrimOp(op~, args~, ty~) => self.rewrite_primop_expr(op~, args~, ty~, stmts~)
  }
}

impl FIRRTLRewriter with rewrite_node_stmt(self, id~, expr~, stmts~) -> Unit raise {
  stmts.push(Node(id~, expr=self.rewrite_expr(expr, stmts~)))
}

impl FIRRTLRewriter with rewrite_wire_stmt(_, id~, ty~, stmts~) -> Unit raise {
  stmts.push(Wire(id~, ty~))
}

impl FIRRTLRewriter with rewrite_inst_stmt(_, id~, of~, sig~, stmts~) -> Unit raise {
  stmts.push(Inst(id~, of~, sig~))
}
impl FIRRTLRewriter with rewrite_reg_stmt(self, id~, ty~, clock~, stmts~) -> Unit raise {
  stmts.push(Reg(id~, ty~, clock=self.rewrite_expr(clock, stmts~)))
}

impl FIRRTLRewriter with rewrite_regreset_stmt(self, id~, ty~, clock~, reset~, init~, stmts~) -> Unit raise {
  stmts.push(RegReset(
    id~,
    ty~,
    clock=self.rewrite_expr(clock, stmts~),
    reset=self.rewrite_expr(reset, stmts~),
    init=self.rewrite_expr(init, stmts~)
  ))
}

impl FIRRTLRewriter with rewrite_connect_stmt(self, lhs, rhs, stmts~) -> Unit raise {
  stmts.push(Connect(self.rewrite_ref(lhs, stmts), self.rewrite_expr(rhs, stmts~)))
}

impl FIRRTLRewriter with rewrite_when_stmt(self, when, stmts~) -> Unit raise {
  stmts.push(When({
    cond: self.rewrite_expr(when.cond, stmts~),
    body: {
      let new_body = Array::new(capacity=when.body.length())

      for stmt in when.body {
        self.rewrite_stmt(stmt, stmts=new_body)
      }

      new_body
    },
    otherwise: when.otherwise.map(else_body => {
      let new_else = Array::new(capacity=else_body.length())

      for stmt in else_body {
        self.rewrite_stmt(stmt, stmts=new_else)
      }

      new_else
    }),
  }))
}

impl FIRRTLRewriter with rewrite_mem_stmt(_, mem, stmts~) -> Unit raise {
  stmts.push(Mem(mem))
}

impl FIRRTLRewriter with rewrite_flat_mem_stmt(_, flat_mem, stmts~) -> Unit raise {
  stmts.push(FlatMem(flat_mem))
}

impl FIRRTLRewriter with rewrite_command_stmt(_, cmd, stmts~) -> Unit raise {
  stmts.push(Command(cmd))
}

impl FIRRTLRewriter with rewrite_skip_stmt(_, stmts~) -> Unit raise {
  stmts.push(Skip)
}

impl FIRRTLRewriter with rewrite_stmt(self, stmt, stmts~) -> Unit raise {
  match stmt {
    Node(id~, expr~) => self.rewrite_node_stmt(id~, expr~, stmts~)
    Wire(id~, ty~) => self.rewrite_wire_stmt(id~, ty~, stmts~)
    Inst(id~, of~, sig~) => self.rewrite_inst_stmt(id~, of~, sig~, stmts~)
    Reg(id~, ty~, clock~) => self.rewrite_reg_stmt(id~, ty~, clock~, stmts~)
    RegReset(id~, ty~, clock~, reset~, init~) => self.rewrite_regreset_stmt(id~, ty~, clock~, reset~, init~, stmts~)
    Connect(lhs, rhs) => self.rewrite_connect_stmt(lhs, rhs, stmts~)
    When(when) => self.rewrite_when_stmt(when, stmts~)
    Mem(mem) => self.rewrite_mem_stmt(mem, stmts~)
    FlatMem(mem) => self.rewrite_flat_mem_stmt(mem, stmts~)
    Command(cmd) => self.rewrite_command_stmt(cmd, stmts~)
    Skip => self.rewrite_skip_stmt(stmts~)
  }
}

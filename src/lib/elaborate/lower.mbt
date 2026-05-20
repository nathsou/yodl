using @firrtl { type Id, type Annotation, type AnnotationTarget }
using @parse { type Span, type Path, type ModuleDecl, type Param, type AstEmitter } 

type FExpr = @firrtl.UntypedExpr
type FStmt = @firrtl.UntypedStmt
type FModule = @firrtl.UntypedModule
type FRef = @firrtl.UntypedRef

using @firrtl {
  mk_ref,
  mk_lit,
  mk_prim,
  mk_id,
  mk_static_indexing,
  mk_field_access,
}

pub struct Elaborator {
  mut autoidx: Int
  circuit_name: String
  modules: Map[Path, FModule]
  extmodules: Map[Path, @firrtl.ExtModule]
  annotations: Array[Annotation]
  declared_modules: Map[Path, ModuleSignature]
  mut current_target: AnnotationTarget
  memories: Map[String, Id]
  mut current_clock: FExpr?
}

pub fn Elaborator::new(circuit_name: String) -> Elaborator {
  {
    circuit_name,
    autoidx: 0,
    modules: {},
    extmodules: {},
    annotations: [],
    declared_modules: {},
    current_target: { circuit: circuit_name, mod: Id::from("dummy_mod_id"), leaf: None },
    memories: {},
    current_clock: None
  }
}

fn Elaborator::next_idx(self: Elaborator) -> Int {
  let idx = self.autoidx
  self.autoidx += 1
  idx
}

priv enum Value {
  Expr(expr~: FExpr, ty~: @firrtl.Type, span~: Span)
  Vector(elems~: Array[Value], ty~: @firrtl.Type, span~: Span)
  Struct(fields~: Map[String, Value], ty~: @firrtl.Type, span~: Span)
  Empty(span~: Span)
}

impl Show for Value with output(self, logger) {
  match self {
    Expr(_) => logger.write_string("Expr()")
    Vector(elems~, ..) => {
      logger.write_string("Vector(")
      logger.write_iter(elems.iter(), sep=", ")
      logger.write_string(")")
    }
    Struct(fields~, ..) => {
      logger.write_string("Struct(")
      for name, value in fields {
        logger.write_string("\{name}: ")
        logger.write_object(value)
      }
      logger.write_string(")")
    }
    Empty(_) => logger.write_string("Empty()")
  }
}

impl Spanned for Value with span(self) {
  match self {
    Expr(span~, ..) | Vector(span~, ..) | Struct(span~, ..) | Empty(span~) => span
  }
}

type ElaboratorEnv = Scope[Path, Value]

pub suberror ElaborationError {
  ElaborationError(message~: String, span~: Span)
  UnresolvedIdentifier(path~: Path, span~: Span)
  Unreachable(message~: String, span~: Span)
  Unsupported(message~: String, span~: Span)
}

impl Spanned for ElaborationError with span(self) {
  match self {
    ElaborationError(span~, ..) => span
    UnresolvedIdentifier(span~, ..) => span
    Unreachable(span~, ..) => span
    Unsupported(span~, ..) => span
  }
}

impl Show for ElaborationError with output(self, logger) {
  logger.write_string("ElaborationError: ")

  match self {
    ElaborationError(message~, span~) => {
      logger.write_string("\{message} at \{span}")
    }
    UnresolvedIdentifier(path~, span~) => {
      logger.write_string("Unresolved identifier '\{path.to_string()}' at \{span}")
    }
    Unreachable(message~, span~) => {
      logger.write_string("ElaborationError: Unreachable: \{message} at \{span}")
    }
    Unsupported(message~, span~) => {
      logger.write_string("ElaborationError: Unsupported: \{message} at \{span}")
    }
  }

  logger.write_string(self.show_context(use_ansi_colors=false))
}

priv trait ScopeLike {
  add_stmt(Self, FStmt) -> Unit
}

impl ScopeLike for FModule with add_stmt(self, stmt) {
  self.body.push(stmt)
}

priv struct StmtContainer(Array[FStmt])

fn StmtContainer::new() -> StmtContainer {
  Array::new()
}

impl ScopeLike for StmtContainer with add_stmt(self, stmt) {
  self.0.push(stmt)
}

fn id_of_path(path: Path) -> Id {
  match path.packages {
    [] => Ident(path.elem)
    _ => Ident(path.packages.join("_") + "_" + path.elem)
  }
}

fn lower_type(ty: Type, span~: Span) -> @firrtl.Type raise {
  match ty {
    Nat({min_width}) => UInt(min_width)
    UInt(Lit(width)) => UInt(width)
    SInt(Lit(width)) => SInt(width)
    Clock => Clock
    Vector(ty~, len=Lit(len)) => Vec(lower_type(ty, span~), len)
    UInt(idx) | SInt(idx) => {
      raise ElaborationError(message="Integer parameter '\{idx}' must be a compile-time constant", span~)
    }
    Vector(ty=_, len=idx) => {
      raise ElaborationError(message="Vector length '\{idx}' must be a compile-time constant", span~)
    }
    MemoryMask(ty) => lower_type(ty.mask(span~), span~)
    Instance(sig~, params~, accessed_ports~) => {
      let fields: Array[@firrtl.BundleField] = Array::new(capacity=accessed_ports.ports.length())
      let resolved_params = keep_and_check_resolved(params, span~)

      for port, _ in accessed_ports.ports {
        let port_sig = sig.get_port(port).unwrap_or_error(ElaborationError::ElaborationError(
          message="Module '\{sig.path.to_string()}' does not declare a port named '\{port}'",
          span~,
        ))

        let field: @firrtl.BundleField = {
          id: Id::from(port),
          ty: lower_type(port_sig.ty.substitute(resolved_params, span~), span~),
          flip: port_sig.dir == Input,
        }

        fields.push(field)
      }

      Bundle(fields)
    }
    Name(path~, params=_) => {
      raise UnresolvedIdentifier(path~, span~)
    }
    Struct(fields) => {
      let fir_fields: Array[@firrtl.BundleField] = Array::new(capacity=fields.length())

      for field in fields {
        let (name, ty) = field
        let field: @firrtl.BundleField = {
          id: Id::from(name),
          ty: lower_type(ty, span~),
          flip: false,
        }

        fir_fields.push(field)
      }

      Bundle(fir_fields)
    }
    String(len~) => Vec(UInt(8), len)
  }
}

fn default_value(ty: @firrtl.Type, span~: Span) -> Value {
  match ty {
    Const(sub_ty) => default_value(sub_ty, span~)
    Clock | Reset | AsyncReset => Value::Expr(expr=mk_lit(UInt(width=1, radix=Some(2), value=0)), ty=UInt(1), span~)
    UInt(width) => {
      let value = BigInt::from_int(0)
      Value::Expr(expr=mk_lit(UInt(width~, radix=Some(2), value~)), ty=UInt(width), span~)
    }
    SInt(width) => {
      let value = BigInt::from_int(0)
      Value::Expr(expr=mk_lit(SInt(width~, radix=Some(2), value~)), ty=SInt(width), span~)
    }
    Vec(elem_ty, len) => {
      let elems = Array::new(capacity=len)

      for _ in 0..<len {
        elems.push(default_value(elem_ty, span~))
      }

      Vector(elems~, ty~, span~)
    }
    Bundle(fields) => {
      let values = Map([], capacity=fields.length())

      for field in fields {
        values[field.id.inner()] = default_value(field.ty, span~)
      }

      Struct(fields=values, ty~, span~)
    }
  }
}

fn _default_mask(ty: @firrtl.Type, span~: Span) -> Value {
  match ty {
    Const(ty) => _default_mask(ty, span~)
    Clock | Reset | AsyncReset | UInt(_) | SInt(_) => {
      Value::Expr(expr=mk_lit(UInt(width=1, radix=Some(2), value=1)), ty=UInt(1), span~)
    }
    Vec(elem_ty, len) => {
      Vector(elems=@utils.fill(len, _default_mask(elem_ty, span~)), ty~, span~)
    }
    Bundle(fields) => {
      let values = Map([], capacity=fields.length())

      for field in fields {
        values[field.id.inner()] = _default_mask(field.ty, span~)
      }

      Struct(fields=values, ty~, span~)
    }
  }
}

fn Elaborator::lower_module(self: Elaborator, mod: ModuleDecl) -> Unit raise {
  let env = ElaboratorEnv::new()
  let mod_id = id_of_path(mod.path)
  self.current_target = { circuit: self.current_target.circuit, mod: mod_id, leaf: None }
  self.current_clock = None

  let fir_mod: FModule = {
    public: true,
    id: mod_id,
    ports: {
      let ports = Array::new(capacity=mod.ports.length())

      for port in mod.ports {
        let fir_ty = lower_type(port.ty, span=port.span)
        let port_id = Id::from(port.name)

        // the first clock port is the module's default clock
        if fir_ty == Clock && self.current_clock is None {
          self.current_clock = Some(mk_ref(mk_id(port_id)))
        }

        let fir_port: @firrtl.Port = {
          dir: port.dir,
          id: port_id,
          ty: fir_ty,
        }
        
        ports.push(fir_port)
        env.declare_(Path::new([], port.name), Expr(expr=mk_ref(mk_id(port_id)), ty=fir_ty, span=port.span))
      }

      ports
    },
    body: [],
  }

  self.modules[mod.path] = fir_mod

  for attr in mod.attributes.values() {
    match attr {
      { name: "inline", args: [], .. } => {
        self.annotations.push(InlineAnnotation(target=self.current_target))
      }
      { name: "flatten", args: [], .. } => {
        self.annotations.push(FlattenAnnotation(target=self.current_target))
      }
      { name: "internal", args: [], .. } => ()
      { span, .. } => {
        raise ElaborationError(message="Invalid module attribute '\{attr.name}'", span~)
      }
    }
  }

  for stmt in mod.body {
    self.lower_stmt(stmt, scope=fir_mod, env~)
  }
}

fn Elaborator::lower_external_module(self: Elaborator, sig: ModuleSignature) -> Unit raise {
  guard sig.attributes.get("external") is Some({args: [String(defname), String(verilog_path)], ..})
  let id = id_of_path(sig.path)
  let ports = Array::new(capacity=sig.ports.length())
  let parameters = []

  for port in sig.ports {
    let fir_ty = lower_type(port.ty, span=port.span)
    let port_id = Id::from(port.name)

    if fir_ty == Clock && self.current_clock is None {
      self.current_clock = Some(mk_ref(mk_id(port_id)))
    }

    let fir_port: @firrtl.Port = {
      dir: port.dir,
      id: port_id,
      ty: fir_ty,
    }

    ports.push(fir_port)
  }

  if sig.attributes.get("parameters") is Some({ args: [Dict(params)], .. }) {
    for key, val in params {
      let param_value: @firrtl.ParameterLiteral = match val {
        String(value) => StringLiteral(value)
        Int(value) => IntLiteral(BigInt::from_int(value))
        Dict(_) => raise ElaborationError::Unsupported(message="Nested dictionaries in parameters are not supported", span=sig.span)
      }

      parameters.push((key, param_value))
    }
  }

  let ext_mod: @firrtl.ExtModule = {
    id,
    ports,
    defname: Some(defname),
    parameters,
  }

  self.extmodules[sig.path] = ext_mod

  self.annotations.push(BlackBoxPathAnnotation(
    target={ circuit: self.current_target.circuit, mod: id, leaf: None },
    path=verilog_path,
  ))
}

fn unwrap_type(ty: Ref[Type?], span~: Span) -> Type raise ElaborationError {
  ty.val.unwrap_or_error(ElaborationError::ElaborationError(
    message="Value requires a resolved type before lowering",
    span~,
  ))
}

fn Elaborator::next_id(self: Elaborator) -> Int {
  let idx = self.autoidx
  self.autoidx += 1
  idx
}

fn Elaborator::gen_id(self: Elaborator, prefix: String) -> Id {
  Ident("\{prefix}_\{self.next_id()}$")
}

fn Elaborator::binding_name(self: Elaborator, binding: FRef?, default_prefix: String) -> Id {
  binding.map(FRef::as_id).bind(x => x).unwrap_or(self.gen_id(default_prefix))
}

fn Elaborator::expr_as_ref(self: Elaborator, expr: FExpr, scope~: &ScopeLike, binding~: FRef? = None) -> FRef {
  match expr {
    Reference(value, ty=_) => value
    _ => {
      let rhs_id = self.binding_name(binding, "tmp")
      scope.add_stmt(Node(id=rhs_id, expr~))
      mk_id(rhs_id)
    }
  }
}

fn Value::as_ref(self: Value, elaborator: Elaborator, scope~: &ScopeLike, binding~: FRef? = None) -> FRef raise {
  let expr = self.as_expr(elaborator, scope~, binding~)
  elaborator.expr_as_ref(expr, scope~, binding~)
}

fn Elaborator::connect(self: Elaborator, lhs~: FRef, value~: Value, scope~: &ScopeLike) -> Unit raise {
  if !(lhs is Id(lhs_id, ..) && value is Expr(expr=Reference(Id(rhs_id, ..), ty=_), ..) && lhs_id.inner() == rhs_id.inner()) {
    scope.add_stmt(Connect(lhs, value.as_expr(self, scope~)))
  }
}

fn Elaborator::get_clock(self: Elaborator, source~: String, span~: Span) -> FExpr raise {
  self.current_clock.unwrap_or_error(ElaborationError::ElaborationError(
    message="No clock found in current module for \{source}",
    span~,
  ))
}

fn Value::ty(self: Value) -> @firrtl.Type {
  match self {
    Expr(ty~, ..) => ty
    Vector(ty~, ..) => ty
    Struct(ty~, ..) => ty
    Empty(_) => UInt(0)
  }
}

fn Value::as_expr(self: Value, elaborator: Elaborator, scope~: &ScopeLike, binding~: FRef? = None) -> FExpr raise {
  match self {
    Expr(expr~, ..) => expr
    Vector(elems~, ty~, span=_) => {
      let id = elaborator.gen_id("vec")
      scope.add_stmt(Wire(id~, ty~))
      
      for i, elem in elems {
        elaborator.connect(lhs=mk_static_indexing(lhs=mk_id(id), index=i), value=elem, scope~)
      }

      mk_ref(mk_id(id))
    }
    Struct(fields~, ty~, span=_) => {
      let id = elaborator.binding_name(binding, "struct")

      if binding is None {
        scope.add_stmt(Wire(id~, ty~))
      }

      for field in fields {
        elaborator.connect(lhs=mk_field_access(lhs=mk_id(id), field=Id::from(field.0)), value=field.1, scope~)
      }

      mk_ref(mk_id(id))
    }
    Empty(span=_) => mk_lit(UInt(width=0, radix=Some(2), value=BigInt::from_int(0)))
  }
}

fn Value::as_int(self: Value) -> BigInt raise {
  match self {
    Expr(expr=Literal(UInt(value~, ..) | SInt(value~, ..), ty=_), ..) => value
    _ => raise ElaborationError(message="Expected integer literal", span=self.span())
  }
}

fn concat_rev(exprs: Array[FExpr]) -> FExpr raise {
    if exprs.is_empty() {
      return mk_lit(UInt(width=0, radix=Some(2), value=BigInt::from_int(0)))
    }

    let list = @list.from_array(exprs)

    fn go(lst: @list.List[FExpr], acc: FExpr) -> FExpr raise {
      match lst.head() {
        Some(expr) => {
          go(lst.unsafe_tail(), mk_prim(Cat, [expr, acc]))
        }
        None => acc
      }
    }

    go(list.unsafe_tail(), exprs[0])
}

fn flatten_int(reference: FRef, ty: @firrtl.Type, span~: Span) -> FExpr raise {
  match ty {
    Const(inner_ty) => flatten_int(reference, inner_ty, span~)
    Vec(elem_ty, len) => {
      let refs = Array::new(capacity=len)

      for i in 0..<len {
        let r = mk_static_indexing(lhs=reference, index=i)
        refs.push(flatten_int(r, elem_ty, span~))
      }

      concat_rev(refs)
    }
    Bundle(fields) => {
      let refs = Array::new(capacity=fields.length())

      for field in fields {
        let r = mk_field_access(lhs=reference, field=field.id)
        refs.push(flatten_int(r, field.ty, span~))
      }

      concat_rev(refs)
    }
    UInt(_) => mk_ref(reference)
    SInt(_) => mk_ref(reference)
    _ => raise ElaborationError::Unsupported(message="Cannot flatten value of type \{ty}", span~)
  }
}

fn Elaborator::lower_stmt(self: Elaborator, stmt: Stmt, scope~: &ScopeLike, env~: ElaboratorEnv) -> Unit raise {
  match stmt {
    Expr(expr~, span=_) => {
      let _ = self.lower_expr(expr, scope~, env~, binding=None)
    }
    Let(name~, ty~, expr~, span~) => {
      let path = Path::new([], name)
      let ty = lower_type(unwrap_type(ty, span~), span~)
      let id = Id::from(name)
      scope.add_stmt(Wire(id~, ty~))
      let variable = mk_id(id)
      let val = match expr {
        Some(expr) => Some(self.lower_expr(expr, scope~, env~, binding=Some(variable)))
        None => None
      }

      match val {
        Some(val) => {
          self.connect(lhs=variable, value=val, scope~)
        }
        None => ()
      }

      env.declare_(path, Expr(expr=mk_ref(variable), ty~, span~))
    }
    Assign(lhs~, rhs~, span=_) => {
      let fir_lhs = self.lower_expr(lhs, scope~, env~, binding=None).as_ref(self, scope~, binding=None)
      let fir_rhs = self.lower_expr(rhs, scope~, env~, binding=None)
      self.connect(lhs=fir_lhs, value=fir_rhs, scope~)
    }
    Const(_) | For(_) | Scope(_) => {
      raise ElaborationError(message="Unexpected statement encountered during elaboration", span=stmt.span())
    }
  }
}

fn Elaborator::lower_expr(self: Elaborator, expr: Expr, scope~: &ScopeLike, env~: ElaboratorEnv, binding~: FRef? = None) -> Value raise {
  let expr_span = expr.span()
  let ty = lower_type(unwrap_type(expr.ty(), span=expr_span), span=expr_span)
  
  match expr {
    Natural(value~, width~, base~, span~, ty=_) => {
      let width = match width {
        Some(width) => width
        None => @utils.significant_bits(value, is_signed=false)
      }
      
      Expr(expr=mk_lit(UInt(width~, radix=Some(base), value~)), ty~, span~)
    }
    Identifier(path~, span~, ..) => {
      match env.resolve(path) {
        Some(val) => val
        None => raise UnresolvedIdentifier(path~, span~)
      }
    }
    Unary(op~, expr~, span~, ty=_) => {
      let fir_expr = self.lower_expr(expr, scope~, env~).as_expr(self, scope~)
      let primop: @firrtl.PrimOp = match op {
        Not => Not
        Neg => Neg
        Andr => Andr
        Orr => Orr
        Xorr => Xorr
      }

      Expr(expr=mk_prim(primop, [fir_expr]), ty~, span~)
    }
    Binary(op~, lhs~, rhs~, output_width~, span~, ty=bin_ty) => {
      let fir_lhs = self.lower_expr(lhs, scope~, env~).as_expr(self, scope~)
      let fir_rhs = self.lower_expr(rhs, scope~, env~).as_expr(self, scope~)
      let is_rhs_int = (try? rhs.as_int()) is Ok(_)
      let mut negate = false
      let primop: @firrtl.PrimOp = match op {
        Add => Add
        Sub => Sub
        Mul => Mul
        Div => Div
        Mod => Rem
        Equ => Eq
        Neq => Neq
        Lss => Lt
        Leq => Leq
        Gtr => Gt
        Geq => Geq
        And => And
        Or => Or
        Xor => Xor
        Nor => { negate = true; Or }
        Nand => { negate = true; And }
        Xnor => { negate = true; Xor }
        Shl => if is_rhs_int { Shl } else { Dshl }
        Shr => if is_rhs_int { Shr } else { Dshr }
        Ternary(_) => raise Unreachable(message="ternary operator", span~)
      }

      let mut res = mk_prim(primop, [fir_lhs, fir_rhs])

      if negate { 
        res = mk_prim(Not, [res])
      }

      if output_width.val is Some(output_width) {
        let width = unwrap_type(bin_ty, span~).width(span)
        if width < output_width {
          res = mk_prim(Bits, [res, FExpr::uint(width - 1), FExpr::uint(0)])
        }
      }

      Expr(expr=res, ty~, span~) 
    }
    Vector(elems~, span~, ty=_) => {
      let values = Array::new(capacity=elems.length())

      for elem in elems {
        match elem {
          Spread(expr~, ..) => {
            let val = self.lower_expr(expr, scope~, env~)

            match val.ty() {
              Vec(elem_ty, len) => {
                let reference = val.as_ref(self, scope~, binding=None)
                for i in 0..<len {
                  values.push(Expr(expr=mk_ref(mk_static_indexing(lhs=reference, index=i)), ty=elem_ty, span=elem.span()))
                }
              }
              UInt(len) | SInt(len) => {
                let reference = val.as_ref(self, scope~, binding=None)
                for i in 0..<len {
                  let index = FExpr::uint(i)
                  values.push(Expr(expr=mk_prim(Bits, [mk_ref(reference), index, index]), ty=UInt(1), span=elem.span()))
                }
              }
              _ => {
                values.push(val)
              }
            }
          }
          _ => {
            values.push(self.lower_expr(elem, scope~, env~))
          }
        }
      }

      Vector(elems=values, ty~, span~)
    }
    Concat(elems~, span~, ..) => {
      let refs = Array::new(capacity=elems.length())

      fn flatten(value: Value) -> Unit raise {
        match value.ty() {
          UInt(_) | SInt(_) => {
            refs.push(value.as_expr(self, scope~, binding=None))
          }
          Vec(elem_ty, len) => {
            let vec_ref = value.as_ref(self, scope~, binding=None)
            
            for i in 0..<len {
              flatten(Expr(expr=mk_ref(mk_static_indexing(lhs=vec_ref, index=i)), ty=elem_ty, span=value.span()))
            }
          }
          _ => raise ElaborationError::Unreachable(message="Cannot flatten value of type \{value.ty()}", span=value.span())
        }
      }

      for elem in elems {
        flatten(self.lower_expr(elem, scope~, env~))
      }

      Expr(expr=concat_rev(refs.rev()), ty~, span~)
    }
    Match(subject~, cases~, default~, span~, ty=match_ty) => {
      let has_value = unwrap_type(match_ty, span~).width(span) > 0

      if
        has_value &&
        subject.ty().val is Some(UInt(Lit(1))) &&
        cases.length() == 2 &&
        // Require both cases to be simple expressions without statements
        !cases.iter().any(case => case.1.contains_statements()) {
        // Rewrite 1-bit match with two cases as a mux
        let cases_map: Map[Int, FExpr] = {}

        for case in cases {
          let int_val = case.0.as_int()
          cases_map[int_val] = self.lower_expr(case.1, scope~, env~).as_expr(self, scope~)
        }

        let tval = cases_map.get(1).unwrap_or_error(ElaborationError::Unreachable(message="Missing true case in 1-bit match", span~))
        let fval = cases_map.get(0).unwrap_or_error(ElaborationError::Unreachable(message="Missing false case in 1-bit match", span~))
        let cond = self.lower_expr(subject, scope~, env~).as_expr(self, scope~)

        Expr(expr=Mux(cond~, tval~, fval~, ty=()), ty~, span~)
      } else {
        let res_id = if has_value {
          let res_id = self.binding_name(binding, "match")

          if binding is None {
            scope.add_stmt(Wire(id=res_id, ty~))
          }

          Some(res_id)
        } else {
          None
        }
        
        let subject_binding = self.gen_id("subject")
        let fir_subject = mk_ref(self.lower_expr(subject, scope~, env~).as_ref(self, scope~, binding=Some(mk_id(subject_binding))))
        let is_complete = default is None && cases.length() == @utils.pow2(unwrap_type(subject.ty(), span~).width(span)).to_int()
        let mut last_when: @firrtl.UntypedWhen? = None

        for idx, case in cases {
          let (lhs, rhs) = case
          let fir_lhs = self.lower_expr(lhs, scope~, env~).as_expr(self, scope~)
          let body = {
            let case_scope = StmtContainer::new()
            let fir_rhs = self.lower_expr(rhs, scope=case_scope, env~).as_expr(self, scope=case_scope)
            if has_value {
              case_scope.add_stmt(Connect(mk_id(res_id.unwrap()), fir_rhs))
            }

            case_scope.0
          }

          let when: @firrtl.UntypedWhen = {
            cond: mk_prim(Eq, [fir_subject, fir_lhs]),
            body,
            otherwise: None,
          }

          match last_when {
            Some(last_when) => {
              if is_complete && idx == cases.length() - 1 {
                last_when.otherwise = Some(when.body)
              } else {
                last_when.otherwise = Some([When(when)])
              }
            }
            None => {
              scope.add_stmt(When(when))
            }
          }

          last_when = Some(when)
        }
        
        match default {
          Some(expr) => match last_when {
            Some(last_when) => {
              let case_scope = StmtContainer::new()
              let fir_rhs = self.lower_expr(expr, scope=case_scope, env~).as_expr(self, scope=case_scope)
              if has_value {
                case_scope.add_stmt(Connect(mk_id(res_id.unwrap()), fir_rhs))
              }

              last_when.otherwise = Some(case_scope.0)
            }
            None => {
              raise ElaborationError::Unreachable(message="Unexpected default case", span~)
            }
          }
          None => ()
        }

        if has_value {
          Expr(expr=mk_ref(mk_id(res_id.unwrap())), ty~, span~)
        } else {
          Empty(span~)
        }
      }
    }
    Tuple(elems~, span~, ty=_) => {
      let values = Array::new(capacity=elems.length())

      for elem in elems {
        values.push(self.lower_expr(elem, scope~, env~))
      }

      Vector(elems=values, ty~, span~)
    }
    Struct(fields~, span~, ty=_) => {
      let val = Map([], capacity=fields.length())
      let sorted_keys = { let keys = fields.keys().collect(); keys.sort(); keys }

      for field in sorted_keys {
        let field_expr = fields[field]
        let field_name = binding.map(FRef::as_id).bind(x => x).map(id => mk_id(id.join("$\{field}")))
        val[field] = self.lower_expr(field_expr, scope~, env~, binding=field_name)
      }

      Value::Struct(fields=val, ty~, span~)
    }
    Instance(path~, params~, ports~, span~, ty=inst_ty) => {
      if params.params.length() > 0 && !self.declared_modules.contains(path) {
        raise ElaborationError(message="Cannot elaborate parametric instance of module '\{path.to_string()}'", span~)
      }

      let (ports_sig, params_map, attributes) = match self.modules.get(path) {
        Some(inst_mod) => {
          let ports_sig: Map[String, @firrtl.PortSignature] = {}

          for port in inst_mod.ports {
            ports_sig[port.id.inner()] = {
              ty: port.ty,
              dir: port.dir,
            }
          }

          (ports_sig, {}, {})
        }
        None => match self.declared_modules.get(path) {
          Some(sig) => {
            let ports_sig = Map([], capacity=sig.ports.length())
            let params_map = params.as_map(names=sig.params.map(fn(p) { p.name }))
            let resolved_params = keep_and_check_resolved(params_map, span~)

            for port in sig.ports {
              let ty = lower_type(port.ty.substitute(resolved_params, span~), span~)
              let port_sig: @firrtl.PortSignature = {
                dir: port.dir,
                ty,
              }
              
              ports_sig[port.name] = port_sig
            }

            (ports_sig, params_map, sig.attributes)
          }
          None => raise ElaborationError(message="Module '\{path.to_string()}' is not declared", span~)
        }
      }

      let inline_connections: Map[String, FExpr] = {}
      let connections: Map[String, FExpr] = {}
      let accessed_ports = match inst_ty.val {
        Some(Instance(sig=_, params=_, accessed_ports~)) => accessed_ports
        _ => raise ElaborationError::Unreachable(message="Untyped instance", span~)
      }

      let extra_ports: Array[String] = []

      fn uses_port(port_name: String) -> Bool {
        ports.contains(port_name) || accessed_ports.contains(port_name)
      }

      let inst_ref = match binding {
        Some(reference) => reference
        _ => {
          let inst_ty = lower_type(unwrap_type(inst_ty, span~), span~)
          let inst_id = id_of_path(path).join("_\{self.next_id()}")
          scope.add_stmt(Wire(id=inst_id, ty=inst_ty))
          mk_id(inst_id)
        }
      }

      for port_name, expr in ports {
        if !ports_sig.contains(port_name) {
          extra_ports.push(port_name)
        }

        inline_connections[port_name] = self.lower_expr(expr, scope~, env~).as_expr(self, scope~)
      }
      
      if !extra_ports.is_empty() {
        let extras = extra_ports.join(", ")
        raise ElaborationError(message="Instance references undefined ports: \{extras}", span~)
      }

      for port_name, port_sig in ports_sig {
        match inline_connections.get(port_name) {
          Some(expr) if !(accessed_ports.is_written_to(port_name)) => {
            connections[port_name] = expr
          }
          _ => {
            if uses_port(port_name) && !accessed_ports.contains(port_name) {
              let port_id = self.gen_id(port_name)
              scope.add_stmt(Wire(id=port_id, ty=port_sig.ty))
              connections[port_name] = mk_ref(mk_id(port_id))
            }
          }
        }
      }

      fn get_port(port_name: String) -> FExpr {
        match connections.get(port_name) {
          Some(expr) => expr
          None => {
            mk_ref(mk_field_access(lhs=inst_ref, field=Id::from(port_name)))
          }
        }
      }
 
      // connect ports with inline expressions which are written to afterwards
      for port_name, access in accessed_ports.ports {
        if access == Write && inline_connections.get(port_name) is Some(inline_expr) {
          scope.add_stmt(Connect(
            mk_field_access(lhs=inst_ref, field=Id::from(port_name)),
            inline_expr
          ))
        }
      }

      if attributes.contains("internal") {
        fn get_param(name: String) -> Param raise {
          match params_map.get(name) {
            Some(param) => param
            None => raise ElaborationError(message="Unknown module parameter '\{name}'", span~)
          }
        }

        match path {
          { packages: [], elem: "Reg" | "RegAsyncReset" as internal_module_name } => {
            let reg_ty = match get_param("T") {
              Resolved(TypeParam(ty~, ..)) => lower_type(ty, span~)
              _ => raise ElaborationError::Unreachable(message="non-type parameter in Reg instance", span~)
            }

            let sync_reset = internal_module_name == "Reg"
            let uses_rst = uses_port("rst")
            let uses_en = uses_port("en")
            let reg_id = Id::from("reg_\{self.next_idx()}")
            let clk = get_port("clk")

            let reg_stmt = if uses_rst {
              let init = default_value(reg_ty, span~).as_expr(self, scope~)

              FStmt::RegReset(
                id=reg_id,
                ty=reg_ty,
                clock=clk,
                reset={
                  let rst = get_port("rst")
                  
                  if sync_reset {
                    rst
                  } else {
                    mk_prim(AsAsyncReset, [rst])
                  }
                },
                init~,
              )
            } else {
              FStmt::Reg(
                id=reg_id,
                ty=reg_ty,
                clock=clk,
              )
            }

            scope.add_stmt(reg_stmt)

            let d_ref = Value::Expr(expr=get_port("d"), ty=reg_ty, span~).as_ref(self, scope~)

            if uses_port("q") {
              match connections.get("q") {
                Some(expr) => {
                  let q_ref = Value::Expr(expr~, ty=reg_ty, span~).as_ref(self, scope~)
                  scope.add_stmt(Connect(q_ref, mk_ref(mk_id(reg_id))))
                }
                None => ()
              }

              if accessed_ports.contains("q") {
                scope.add_stmt(Connect(mk_field_access(lhs=inst_ref, field=Id::from("q")), mk_ref(mk_id(reg_id))))
              }
            }

            if uses_port("d") {
              let en_stmt: FStmt = if uses_en {
                FStmt::When({
                  cond: get_port("en"),
                  body: [Connect(mk_id(reg_id), mk_ref(d_ref))],
                  otherwise: None,
                })
              } else {
                Connect(mk_id(reg_id), mk_ref(d_ref))
              }

              scope.add_stmt(en_stmt)

              if uses_port("q") {
                // connect d to q by default
                scope.add_stmt(Connect(
                  mk_field_access(lhs=inst_ref, field=Id::from("d")),
                  mk_ref(mk_field_access(lhs=inst_ref, field=Id::from("q")))
                ))
              }
            }
          }
          { packages: [], elem: "Memory" } => {
            let data_type = lower_type(get_param("T").as_type(), span~)
            let depth = get_param("Depth").as_int()
            let read_ports = get_param("ReadPorts").as_int()
            let write_ports = get_param("WritePorts").as_int()
            let mem_id = self.gen_id("mem")
            
            if binding is Some(Id(id, ..)) {
              self.memories[id.value()] = mem_id
            }

            let readers = {
              let readers = Array::new(capacity=read_ports)

              for i in 0..<read_ports {
                readers.push(Id::from(mem_id.inner() + "_reader\{i}"))
              }

              readers
            }

            let writers = {
              let writers = Array::new(capacity=write_ports)

              for i in 0..<write_ports {
                writers.push(Id::from(mem_id.inner() + "_writer\{i}"))
              }

              writers
            }

            let read_latency = if params_map.contains("ReadLatency") {
              get_param("ReadLatency").as_int()
            } else {
              1
            }

            let write_latency = if params_map.contains("WriteLatency") {
              get_param("WriteLatency").as_int()
            } else {
              1
            }

            let mem_stmt = @firrtl.Mem({
              is_flat: false,
              mask_ty: data_type.mem_mask(),
              id: mem_id,
              data_type,
              depth,
              read_latency,
              write_latency,
              read_under_write: Undefined,
              readers,
              writers,
              readwriters: [],
            })

            scope.add_stmt(mem_stmt)

            let data_out = Array::new(capacity=read_ports)

            {
              let ports = self.expr_as_ref(get_port("read"), scope~)

              for i in 0..<read_ports {
                let reader = mk_static_indexing(lhs=ports, index=i)
                let reader_id = mk_field_access(lhs=mk_id(mem_id), field=readers[i])
                scope.add_stmt(Connect(mk_field_access(lhs=reader_id, field=Id::from("addr")), mk_ref(mk_field_access(lhs=reader, field=Id::from("addr")))))
                scope.add_stmt(Connect(mk_field_access(lhs=reader_id, field=Id::from("en")), mk_ref(mk_field_access(lhs=reader, field=Id::from("en")))))
                scope.add_stmt(Connect(mk_field_access(lhs=reader_id, field=Id::from("clk")), mk_ref(mk_field_access(lhs=reader, field=Id::from("clk")))))
                data_out.push(mk_field_access(lhs=reader_id, field=Id::from("data")))
              }
            }

            {
              let ports = self.expr_as_ref(get_port("write"), scope~)

              for i in 0..<write_ports {
                let writer = mk_static_indexing(lhs=ports, index=i)
                let writer_id = mk_field_access(lhs=mk_id(mem_id), field=writers[i])
                scope.add_stmt(Connect(mk_field_access(lhs=writer_id, field=Id::from("addr")), mk_ref(mk_field_access(lhs=writer, field=Id::from("addr")))))
                scope.add_stmt(Connect(mk_field_access(lhs=writer_id, field=Id::from("en")), mk_ref(mk_field_access(lhs=writer, field=Id::from("en")))))
                scope.add_stmt(Connect(mk_field_access(lhs=writer_id, field=Id::from("clk")), mk_ref(mk_field_access(lhs=writer, field=Id::from("clk")))))
                scope.add_stmt(Connect(mk_field_access(lhs=writer_id, field=Id::from("data")), mk_ref(mk_field_access(lhs=writer, field=Id::from("data")))))
                scope.add_stmt(Connect(mk_field_access(lhs=writer_id, field=Id::from("mask")), mk_ref(mk_field_access(lhs=writer, field=Id::from("mask")))))
              }
            }

            let q = self.expr_as_ref(get_port("q"), scope~)

            for i, data in data_out {
              scope.add_stmt(Connect(mk_static_indexing(lhs=q, index=i), mk_ref(data)))
            }
          }
          _ => raise ElaborationError(message="Module '\{path.to_string()}' is marked as internal but has no elaboration handler", span~)
        }
      } else {
        let inst_id = Id::from("inst_\{self.next_idx()}$")
        scope.add_stmt(Inst(id=inst_id, of=id_of_path(path), sig={ ports: ports_sig }))

        for port_name, sig in ports_sig {
          if uses_port(port_name) {
            let lhs = Expr(expr=mk_ref(mk_field_access(lhs=mk_id(inst_id), field=Id::from(port_name))), ty=sig.ty, span~)
            let rhss = Array::new(capacity=2)

            if accessed_ports.contains(port_name) {
              rhss.push(Expr(expr=mk_ref(mk_field_access(lhs=inst_ref, field=Id::from(port_name))), ty=sig.ty, span~))
            }
            
            if inline_connections.contains(port_name) {
              rhss.push(Expr(expr=get_port(port_name), ty=sig.ty, span~))
            }

            for rhs in rhss {
              match sig.dir {
                Input => {
                  self.connect(lhs=lhs.as_ref(self, scope~), value=rhs, scope~)
                }
                Output | InOut => {
                  self.connect(lhs=rhs.as_ref(self, scope~), value=lhs, scope~)
                }
              }
            }
          }
        }
      }

      Expr(expr=mk_ref(inst_ref), ty~, span~)
    }
    Indexing(expr~, index~, span~, ty=_) => {
      let val = self.lower_expr(expr, scope~, env~)
      let index = self.lower_expr(index, scope~, env~)
      let idx_int = try index.as_int() catch {
        _ => None
      } noraise {
        idx => Some(idx.to_int())
      }

      match (val, idx_int) {
        (Vector(elems~, ty=_, span~), Some(idx)) => {
          let len = elems.length()

          if idx >= len {
            raise ElaborationError::Unreachable(message="Index out of bounds, len: \{len}, index: \{idx}", span~)
          }
          
          elems[idx]
        }
        _ => {
          let index_expr = match idx_int {
            Some(idx) => FExpr::uint(idx)
            None => index.as_expr(self, scope~)
          }

          match expr.ty().val {
            Some(UInt(_)) => {
              if idx_int is None {
                raise ElaborationError::Unsupported(message="Indexing UInt with a dynamic index is unsupported, consider using the decomposition operator: [...value][index]", span~)
              }

              Expr(expr=mk_prim(Bits, [val.as_expr(self, scope~), index_expr, index_expr]), ty=UInt(1), span~)
            }
            _ => {
              Expr(expr=mk_ref(FRef::indexing_from(lhs=val.as_ref(self, scope~), index=index_expr, ty=())), ty~, span~)
            }
          }
        }
      }
    }
    Slicing(expr~, hi~, lo~, span~, ..) => {
      let val = self.lower_expr(expr, scope~, env~)
      let hi = self.lower_expr(hi, scope~, env~).as_int().to_int()
      let lo = self.lower_expr(lo, scope~, env~).as_int().to_int()

      match val.ty() {
        UInt(_) | SInt(_) => {
          let expr = val.as_expr(self, scope~)
          Expr(expr=mk_prim(Bits, [expr, FExpr::uint(hi), FExpr::uint(lo)]), ty~, span~)
        }
        Vec(elem_ty, _) => {
          let slice_len = hi + 1 - lo
          let elems = Array::new(capacity=slice_len)
          let lhs = val.as_ref(self, scope~)

          for i in lo..=hi {
            elems.push(Expr(expr=mk_ref(mk_static_indexing(lhs~, index=i)), ty=elem_ty, span~))
          }

          Vector(elems~, ty=Vec(elem_ty, slice_len), span~)
        }
        ty => raise ElaborationError::Unsupported(message="Slicing is not support on value of type '\{ty}'", span~)
      }
    }
    FieldAccess(expr=accessed_expr, field~, span~, ty=_) => {
      let val = self.lower_expr(accessed_expr, scope~, env~)
      Expr(expr=mk_ref(mk_field_access(lhs=val.as_ref(self, scope~), field=Id::from(field))), ty~, span~)
    }
    Block(body~, last~, span~, ..) => {
      let block_env = env.child()
      let block_scope = StmtContainer::new()

      for stmt in body {
        self.lower_stmt(stmt, scope=block_scope, env=block_env)
      }

      let last_val = match last {
        Some(expr) => Some(self.lower_expr(expr, scope=block_scope, env=block_env))
        None => None
      }

      for stmt in block_scope.0 {
        scope.add_stmt(stmt)
      }

      match last_val {
        Some(val) => val
        None => Empty(span~)
      }
    }
    String(value=str, span~, ty~) => {
      let chars: Array[Expr] = Array::new(capacity=str.length())

      for char in str {
        let char_latin1 = char.to_int()

        if char_latin1 < 0 || char_latin1 > 255 {
          raise ElaborationError(message="String literal contains unsupported character '\{char}' (expected Latin-1)", span~)
        }

        chars.push(Expr::nat(char_latin1, width=Some(8), span~))
      }

      self.lower_expr(Vector(elems=chars, span~, ty~), scope~, env~)
    }
    FunCall(name="uint" | "sint" as name, args=[arg], ty~, span~) => {
      let arg = self.lower_expr(arg, scope~, env~)
      let ty = unwrap_type(ty, span~)
      let fir_ty = lower_type(ty, span~)

      match (name, arg.ty()) {
        ("uint", Vec(_)) => Expr(expr=flatten_int(arg.as_ref(self, scope~), arg.ty(), span~), ty=fir_ty, span~)
        ("sint", Vec(_)) => {
          let flattened = flatten_int(arg.as_ref(self, scope~), arg.ty(), span~)
          Expr(expr=mk_prim(AsSInt, [flattened]), ty=fir_ty, span~)
        }
        ("uint", UInt(_) | AsyncReset | Reset) | ("sint", SInt(_)) => arg
        ("uint", SInt(_)) => Expr(expr=mk_prim(AsUInt, [arg.as_expr(self, scope~)]), ty=fir_ty, span~)
        ("uint", Clock) => Expr(expr=mk_prim(AsUInt, [arg.as_expr(self, scope~)]), ty=fir_ty, span~)
        ("sint", UInt(_)) => Expr(expr=mk_prim(AsSInt, [arg.as_expr(self, scope~)]), ty=fir_ty, span~)
        _ => raise ElaborationError::Unsupported(message="Cannot convert type '\{arg.ty()}' to UInt or SInt with '\{name}'", span~)
      }
    }
    FunCall(name="clock", args=[clk], span~, ..) => {
      let clk = self.lower_expr(clk, scope~, env~)
      let clk_ref = clk.as_ref(self, scope~)

      Expr(expr=mk_prim(AsClock, [mk_ref(clk_ref)]), ty=Clock, span~)
    }
    FunCall(name="pad", args=[arg, width_arg], span~, ty~) => {
      let arg = self.lower_expr(arg, scope~, env~)
      let width = self.lower_expr(width_arg, scope~, env~).as_int().to_int()
      let ty = lower_type(unwrap_type(ty, span~), span~)
      Expr(expr=mk_prim(Pad, [arg.as_expr(self, scope~), FExpr::uint(width)]), ty~, span~)
    }
    FunCall(name="readmemb" | "readmemh" as name, args=[path, mem], span~, ..) => {
      let path = path.as_string()
      let mem_ref = self.lower_expr(mem, scope~, env~).as_ref(self, scope~)
      let mem_name = match mem_ref {
        Id(id, ..) => id.inner()
        _ => raise ElaborationError::Unsupported(message="Cannot reference indirect memory inside \{name}", span~)
      }

      let mem_id = match self.memories.get(mem_name) {
        Some(id) => id
        None => raise ElaborationError(message="Unknown memory '\{mem_name}' referenced in \{name}", span~)
      }

      self.annotations.push(MemoryFileInlineAnnotation(
        target={ ..self.current_target, leaf: Some(mem_id) },
        filename=path,
        is_hex=name == "readmemh",
      ))

      Empty(span~)
    }
    FunCall(name="printf", args=[fmt, ..args], span~, ..) => {
      let fmt = fmt.as_string()
      let new_args = Array::new(capacity=args.length())

      for arg in args {
        new_args.push(self.lower_expr(arg, scope~, env~).as_expr(self, scope~))
      }

      let clk = self.get_clock(source="printf", span~)
      let en = mk_lit(UInt(width=1, radix=Some(2), value=BigInt::from_int(1)))

      scope.add_stmt(Command(Printf(clk~, en~, fmt~, args=new_args)))
      Empty(span~)
    }
    FunCall(name="assert", args=[pred, ..rest], span~, ..) => {
      let pred_val = self.lower_expr(pred, scope~, env~)
      let clk = self.get_clock(source="assert", span~)
      let en = mk_lit(UInt(width=1, radix=Some(2), value=BigInt::from_int(1)))

      let (fmt, args) = if rest is [format_str, ..args] {
        let fmt = format_str.as_string()
        let new_args = Array::new(capacity=args.length())

        for arg in args {
          new_args.push(self.lower_expr(arg, scope~, env~).as_expr(self, scope~))
        }

        (fmt, new_args)
      } else {
        let pred_fmt = {
          let emitter = AstEmitter::new()
          emitter.emit_expr(pred)
          
        }

        ("assertion failed: \{pred_fmt}", [])
      }

      scope.add_stmt(Command(Assert(clk~, en~, pred=pred_val.as_expr(self, scope~), fmt~, args~)))

      Empty(span~)
    }
    FunCall(name="stop", args~, span~, ..) => {
      let clk = self.get_clock(source="stop", span~)
      let en = mk_lit(UInt(width=1, radix=Some(2), value=BigInt::from_int(1)))
      let code = match args {
        [] => 0
        [code] => self.lower_expr(code, scope~, env~).as_int().to_int()
        _ => raise fail("Unexpected number of arguments to stop!")
      }

      scope.add_stmt(Command(Stop(clk~, en~, code~)))
      Empty(span~)
    }
    FunCall(name="rev", args=[arg], span~, ty={val: Some(Vector(len=Lit(len), ..) | String(len~) as ty)}) => {
      let arg = self.lower_expr(arg, scope~, env~)
      let arg_ref = arg.as_ref(self, scope~)
      let elems = Array::new(capacity=len)
      let elem_ty = if ty is Vector(ty~, ..) { ty } else { UInt(Lit(@parse.BITS_PER_CHAR)) }
      let fir_elem_ty = lower_type(elem_ty, span~)

      for i in 0..<len {
        let elem = mk_static_indexing(lhs=arg_ref, index=len - 1 - i)
        let val = Value::Expr(expr=mk_ref(elem), ty=fir_elem_ty, span~)
        elems.push(val)
      }

      Value::Vector(elems~, ty=@firrtl.Type::Vec(fir_elem_ty, len), span~)
    }
    FunCall(name="flip", args=[arg], span~, ty~) => {
      let arg = self.lower_expr(arg, scope~, env~)
      let arg_ref = arg.as_ref(self, scope~)
      let width = unwrap_type(ty, span~).width(span)
      let bits = Array::new(capacity=width)

      for i in 0..<width {
        let index = FExpr::uint(width - 1 - i)
        bits.push(mk_prim(Bits, [mk_ref(arg_ref), index, index]))
      }

       Value::Expr(expr=concat_rev(bits), ty=UInt(width), span~)
    }
    Spread(_) | Ternary(_) | Replicate(_) | FunCall(_) | If(_) => {
      raise ElaborationError(message="Unexpected expression encountered during elaboration", span=expr.span())
    }
  }
}

pub fn Elaborator::lower(self: Elaborator, decls: Iter[Decl]) -> Unit raise {
  for decl in decls {
    match decl {
      Module(mod) => {
        self.lower_module(mod)
      }
      ModuleDeclaration(sig) => {
        self.declared_modules[sig.path] = sig

        if sig.attributes.contains("external") {
          self.lower_external_module(sig)
        }
      }
      Const(_) | Package(_) | Import(_) | TypeAlias(_) => ()
    }
  }
}
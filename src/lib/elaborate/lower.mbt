
typealias @firrtl.Expr as FExpr
typealias @firrtl.Stmt[FExpr] as FStmt
typealias @firrtl.Module[FExpr] as FModule
typealias @firrtl.Reference[FExpr] as FRef

pub struct Elaborator {
  mut autoidx: Int
  circuit_name: String
  modules: Map[@parse.Path, FModule]
  extmodules: Map[@parse.Path, @firrtl.ExtModule]
  annotations: Array[Json]
  declared_modules: Map[@parse.Path, @parse.ModuleSignature]
  current_target: Array[String]
  memories: Map[String, @firrtl.Id]
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
    current_target: [circuit_name],
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
  Expr(expr~: FExpr, ty~: @firrtl.Type, span~: @parse.Span)
  Vector(elems~: Array[Value], ty~: @firrtl.Type, span~: @parse.Span)
  Struct(fields~: Map[String, Value], ty~: @firrtl.Type, span~: @parse.Span)
  Empty(span~: @parse.Span)
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

impl @parse.Spanned for Value with span(self) {
  match self {
    Expr(span~, ..) | Vector(span~, ..) | Struct(span~, ..) | Empty(span~) => span
  }
}

typealias Scope[@parse.Path, Value] as ElaboratorEnv

pub suberror ElaborationError {
  ElaborationError(message~: String, span~: @parse.Span)
  UnresolvedIdentifier(path~: @parse.Path, span~: @parse.Span)
  Unreachable(message~: String, span~: @parse.Span)
  Unsupported(message~: String, span~: @parse.Span)
}

impl @parse.Spanned for ElaborationError with span(self) {
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
  self.inner().push(stmt)
}

fn id_of_path(path: @parse.Path) -> @firrtl.Id {
  match path.packages {
    [] => Ident(path.member)
    _ => Ident(path.packages.join("_") + "_" + path.member)
  }
}

fn lower_type(ty: @parse.Type, span~: @parse.Span) -> @firrtl.Type raise {
  match ty {
    Nat(min_width~) => UInt(min_width)
    UInt(Fixed(width)) => UInt(width)
    SInt(Fixed(width)) => SInt(width)
    Clock => Clock
    Vector(ty~, len=Fixed(len)) => Vec(lower_type(ty, span~), len)
    UInt(Dynamic(_)) | SInt(Dynamic(_)) | Vector(ty=_, len=Dynamic(_)) => {
      raise ElaborationError(message="Integer parameters must be compile-time constants", span~)
    }
    Instance(sig~, params~, accessed_ports~) => {
      let fields: Array[@firrtl.BundleField] = Array::new(capacity=accessed_ports.0.size())
      let resolved_params = @parse.keep_and_check_resolved(params, span~)

      for port, _ in accessed_ports.0 {
        let port_sig = sig.get_port(port).or_error(ElaborationError::ElaborationError(
          message="Module '\{sig.path.to_string()}' does not declare a port named '\{port}'",
          span~,
        ))

        let field: @firrtl.BundleField = {
          id: @firrtl.Id::from(port),
          ty: lower_type(port_sig.ty.substitute(resolved_params, span~), span~),
          flip: port_sig.flow == Input,
        }

        fields.push(field)
      }

      Bundle(fields)
    }
    Name(path~, params=_) => {
      raise UnresolvedIdentifier(path~, span~)
    }
    Struct(fields) => {
      let fir_fields: Array[@firrtl.BundleField] = Array::new(capacity=fields.size())

      for field in fields {
        let (name, ty) = field
        let field: @firrtl.BundleField = {
          id: @firrtl.Id::from(name),
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

fn default_value(ty: @firrtl.Type, span~: @parse.Span) -> Value raise {
  match ty {
    Const(sub_ty) => default_value(sub_ty, span~)
    Clock | Reset | AsyncReset => Value::Expr(expr=Literal(UInt(width=1, radix=Some(2), value=0)), ty=UInt(1), span~)
    UInt(width) => {
      let value = BigInt::from_int(0)
      Value::Expr(expr=Literal(UInt(width~, radix=Some(2), value~)), ty~, span~)
    }
    SInt(width) => {
      let value = BigInt::from_int(0)
      Value::Expr(expr=Literal(SInt(width~, radix=Some(2), value~)), ty~, span~)
    }
    Vec(elem_ty, len) => {
      let elems = Array::new(capacity=len)

      for _ in 0..<len {
        elems.push(default_value(elem_ty, span~))
      }

      Vector(elems~, ty~, span~)
    }
    Bundle(fields) => {
      let values = Map::new(capacity=fields.length())

      for field in fields {
        values[field.id.inner()] = default_value(field.ty, span~)
      }

      Struct(fields=values, ty~, span~)
    }
    UIntInferred | SIntInferred => raise ElaborationError::Unsupported(message="Cannot get init value of inferred integer type", span~)
  }
}

fn _default_mask(ty: @firrtl.Type, span~: @parse.Span) -> Value {
  match ty {
    Const(ty) => _default_mask(ty, span~)
    Clock | Reset | AsyncReset | UInt(_) | SInt(_) | UIntInferred | SIntInferred => {
      Value::Expr(expr=Literal(UInt(width=1, radix=Some(2), value=1)), ty=UInt(1), span~)
    }
    Vec(elem_ty, len) => {
      Vector(elems=@utils.fill(len, _default_mask(elem_ty, span~)), ty~, span~)
    }
    Bundle(fields) => {
      let values = Map::new(capacity=fields.length())

      for field in fields {
        values[field.id.inner()] = _default_mask(field.ty, span~)
      }

      Struct(fields=values, ty~, span~)
    }
  }
}

fn Elaborator::lower_module(self: Elaborator, mod: @parse.ModuleDecl) -> Unit raise {
  let env = ElaboratorEnv::new()
  self.current_target.push([..mod.path.packages, mod.path.member].join("_"))
  self.current_clock = None

  let fir_mod: FModule = {
    public: true,
    id: id_of_path(mod.path),
    ports: {
      let ports = Array::new(capacity=mod.ports.length())

      for port in mod.ports {
        let fir_ty = lower_type(port.ty, span=port.span)
        let port_id = @firrtl.Id::from(port.name)

        // the first clock port is the module's default clock
        if fir_ty == Clock && self.current_clock.is_empty() {
          self.current_clock = Some(Reference(Id(port_id)))
        }

        let fir_port: @firrtl.Port = {
          flow: port.flow,
          id: port_id,
          ty: fir_ty,
        }
        
        ports.push(fir_port)
        env.declare(@parse.Path::new([], port.name), Expr(expr=Reference(Id(port_id)), ty=fir_ty, span=port.span))
      }

      ports
    },
    body: [],
  }

  self.modules[mod.path] = fir_mod

  for attr in mod.attributes.values() {
    match attr {
      { name: "inline", args: [], .. } => {
        self.annotations.push({
          "class": "firrtl.passes.InlineAnnotation",
          "target": self.current_target.join(".").to_json(),
        })
      }
      { name: "flatten", args: [], .. } => {
        self.annotations.push({
          "class": "firrtl.transforms.FlattenAnnotation",
          "target": self.current_target.join(".").to_json(),
        })
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

  let _ = self.current_target.pop()
}

fn Elaborator::lower_external_module(self: Elaborator, sig: @parse.ModuleSignature) -> Unit raise {
  guard sig.attributes.get("external") is Some({args: [String(defname), String(verilog_path)], ..})
  let id = id_of_path(sig.path)
  let ports = Array::new(capacity=sig.ports.length())
  let parameters = []

  for port in sig.ports {
    let fir_ty = lower_type(port.ty, span=port.span)
    let port_id = @firrtl.Id::from(port.name)

    if fir_ty == Clock && self.current_clock.is_empty() {
      self.current_clock = Some(Reference(Id(port_id)))
    }

    let fir_port: @firrtl.Port = {
      flow: port.flow,
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

  let annotation = {
    "class": "firrtl.transforms.BlackBoxPathAnno",
    "target": [..self.current_target, sig.path.to_string()].join("."),
    "path": verilog_path,
  }

  self.annotations.push(annotation.to_json())
}

fn unwrap_type(ty: Ref[@parse.Type?], span~: @parse.Span) -> @parse.Type raise ElaborationError {
  ty.val.or_error(ElaborationError::ElaborationError(
    message="Value requires a resolved type before lowering",
    span~,
  ))
}

fn Elaborator::next_id(self: Elaborator) -> Int {
  let idx = self.autoidx
  self.autoidx += 1
  idx
}

fn Elaborator::gen_id(self: Elaborator, prefix: String) -> @firrtl.Id {
  Ident("\{prefix}_\{self.next_id()}$")
}

fn Elaborator::binding_name(self: Elaborator, binding: FRef?, default_prefix: String) -> @firrtl.Id {
  binding.map(FRef::as_id).flatten().unwrap_or(self.gen_id(default_prefix))
}

fn Elaborator::expr_as_ref(self: Elaborator, expr: FExpr, scope~: &ScopeLike, binding~: FRef? = None) -> FRef {
  match expr {
    Reference(value) => value
    _ => {
      let rhs_id = self.binding_name(binding, "tmp")
      scope.add_stmt(Node(id=rhs_id, expr~))
      Id(rhs_id)
    }
  }
}

fn Value::as_ref(self: Value, elaborator: Elaborator, scope~: &ScopeLike, binding~: FRef? = None) -> FRef raise {
  let expr = self.as_expr(elaborator, scope~, binding~)
  elaborator.expr_as_ref(expr, scope~, binding~)
}

fn Elaborator::connect(self: Elaborator, lhs~: FRef, value~: Value, scope~: &ScopeLike) -> Unit raise {
  if !(lhs is Id(lhs_id) && value is Expr(expr=Reference(Id(rhs_id)), ..) && lhs_id.inner() == rhs_id.inner()) {
    scope.add_stmt(Connect(lhs, value.as_expr(self, scope~)))
  }
}

fn Elaborator::get_clock(self: Elaborator, source~: String, span~: @parse.Span) -> FExpr raise {
  self.current_clock.or_error(ElaborationError::ElaborationError(
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
        elaborator.connect(lhs=StaticIndexing(lhs=Id(id), index=i), value=elem, scope~)
      }

      Reference(Id(id))
    }
    Struct(fields~, ty~, span=_) => {
      let id = elaborator.binding_name(binding, "struct")

      if binding.is_empty() {
        scope.add_stmt(Wire(id~, ty~))
      }

      for field in fields {
        elaborator.connect(lhs=FieldAccess(lhs=Id(id), field=@firrtl.Id::from(field.0)), value=field.1, scope~)
      }

      Reference(Id(id))
    }
    Empty(span=_) => Literal(UInt(width=0, radix=Some(2), value=BigInt::from_int(0)))
  }
}

fn Value::as_int(self: Value) -> BigInt raise {
  match self {
    Expr(expr=Literal(UInt(value~, ..) | SInt(value~, ..)), ..) => value
    _ => raise ElaborationError(message="Expected integer literal", span=self.span())
  }
}

fn concat_rev(exprs: Array[FExpr]) -> FExpr raise {
    if exprs.is_empty() {
      return Literal(UInt(width=0, radix=Some(2), value=BigInt::from_int(0)))
    }

    let list = @list.from_array(exprs)

    fn go(lst: @list.List[FExpr], acc: FExpr) -> FExpr raise {
      match lst.head() {
        Some(expr) => {
          go(lst.unsafe_tail(), PrimOp(op=Cat, args=[expr, acc]))
        }
        None => acc
      }
    }

    go(list.unsafe_tail(), exprs[0])
}

fn flatten_int(reference: FRef, ty: @firrtl.Type, span~: @parse.Span) -> FExpr raise {
  match ty {
    Const(inner_ty) => flatten_int(reference, inner_ty, span~)
    Vec(elem_ty, len) => {
      let refs = Array::new(capacity=len)

      for i in 0..<len {
        let r = FRef::StaticIndexing(lhs=reference, index=i)
        refs.push(flatten_int(r, elem_ty, span~))
      }

      concat_rev(refs)
    }
    Bundle(fields) => {
      let refs = Array::new(capacity=fields.length())

      for field in fields {
        let r = FRef::FieldAccess(lhs=reference, field=field.id)
        refs.push(flatten_int(r, field.ty, span~))
      }

      concat_rev(refs)
    }
    UInt(_) => Reference(reference)
    SInt(_) => Reference(reference)
    _ => raise ElaborationError::Unsupported(message="Cannot flatten value of type \{ty}", span~)
  }
}

fn Elaborator::lower_stmt(self: Elaborator, stmt: @parse.Stmt, scope~: &ScopeLike, env~: ElaboratorEnv) -> Unit raise {
  match stmt {
    Expr(expr~, span=_) => {
      let _ = self.lower_expr(expr, scope~, env~, binding=None)
    }
    Let(name~, ty~, expr~, span~) => {
      let path = @parse.Path::new([], name)
      let ty = lower_type(unwrap_type(ty, span~), span~)
      let id = @firrtl.Id::from(name)
      scope.add_stmt(Wire(id~, ty~))
      let var = FRef::Id(id)
      let val = match expr {
        Some(expr) => Some(self.lower_expr(expr, scope~, env~, binding=Some(var)))
        None => None
      }

      match val {
        Some(val) => {
          self.connect(lhs=var, value=val, scope~)
        }
        None => ()
      }

      env.declare(path, Expr(expr=Reference(var), ty~, span~))
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

fn Elaborator::lower_expr(self: Elaborator, expr: @parse.Expr, scope~: &ScopeLike, env~: ElaboratorEnv, binding~: FRef? = None) -> Value raise {
  let expr_span = expr.span()
  let ty = lower_type(unwrap_type(expr.ty(), span=expr_span), span=expr_span)
  
  match expr {
    Natural(value~, width~, base~, span~, ty=_) => {
      let width = match width {
        Some(width) => width
        None => @utils.significant_bits(value, is_signed=false)
      }
      
      Expr(expr=Literal(UInt(width~, radix=Some(base), value~)), ty~, span~)
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

      Expr(expr=PrimOp(op=primop, args=[fir_expr]), ty~, span~)
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

      let mut res = FExpr::PrimOp(op=primop, args=[fir_lhs, fir_rhs])

      if negate { 
        res = PrimOp(op=Not, args=[res])
      }

      if output_width.val is Some(output_width) {
        let width = unwrap_type(bin_ty, span~).width(span)
        if width < output_width {
          res = PrimOp(op=Bits, args=[res, FExpr::uint(width - 1), FExpr::uint(0)])
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
                  values.push(Expr(expr=Reference(StaticIndexing(lhs=reference, index=i)), ty=elem_ty, span=elem.span()))
                }
              }
              UInt(len) | SInt(len) => {
                let reference = val.as_ref(self, scope~, binding=None)
                for i in 0..<len {
                  let index = FExpr::uint(i)
                  values.push(Expr(expr=PrimOp(op=Bits, args=[Reference(reference), index, index]), ty=UInt(1), span=elem.span()))
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
          UInt(_) | SInt(_) | UIntInferred | SIntInferred => {
            refs.push(value.as_expr(self, scope~, binding=None))
          }
          Vec(elem_ty, len) => {
            let vec_ref = value.as_ref(self, scope~, binding=None)
            
            for i in 0..<len {
              flatten(Expr(expr=Reference(StaticIndexing(lhs=vec_ref, index=i)), ty=elem_ty, span=value.span()))
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
        subject.ty().val is Some(UInt(Fixed(1))) &&
        cases.length() == 2 &&
        // Require both cases to be simple expressions without statements
        !cases.iter().any(case => case.1.contains_statements()) {
        // Rewrite 1-bit match with two cases as a mux
        let cases_map: Map[Int, FExpr] = {}

        for case in cases {
          let int_val = case.0.as_int()
          cases_map[int_val] = self.lower_expr(case.1, scope~, env~).as_expr(self, scope~)
        }

        let tval = cases_map.get(1).or_error(ElaborationError::Unreachable(message="Missing true case in 1-bit match", span~))
        let fval = cases_map.get(0).or_error(ElaborationError::Unreachable(message="Missing false case in 1-bit match", span~))
        let cond = self.lower_expr(subject, scope~, env~).as_expr(self, scope~)

        Expr(expr=Mux(cond~, tval~, fval~), ty~, span~)
      } else {
        let res_id = if has_value {
          let res_id = self.binding_name(binding, "match")

          if binding.is_empty() {
            scope.add_stmt(Wire(id=res_id, ty~))
          }

          Some(res_id)
        } else {
          None
        }
        
        let subject_binding = self.binding_name(binding, "subject")
        let fir_subject = FExpr::Reference(self.lower_expr(subject, scope~, env~).as_ref(self, scope~, binding=Some(Id(subject_binding))))
        let is_complete = default.is_empty() && cases.length() == @utils.pow2(unwrap_type(subject.ty(), span~).width(span)).to_int()
        let mut last_when: @firrtl.When[FExpr]? = None

        for idx, case in cases {
          let (lhs, rhs) = case
          let fir_lhs = self.lower_expr(lhs, scope~, env~).as_expr(self, scope~)
          let body = {
            let case_scope = StmtContainer::new()
            let fir_rhs = self.lower_expr(rhs, scope=case_scope, env~).as_expr(self, scope=case_scope)
            if has_value {
              case_scope.add_stmt(Connect(Id(res_id.unwrap()), fir_rhs))
            }

            case_scope.inner()
          }

          let when: @firrtl.When[FExpr] = {
            cond: PrimOp(op=Eq, args=[fir_subject, fir_lhs]),
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
                case_scope.add_stmt(Connect(Id(res_id.unwrap()), fir_rhs))
              }

              last_when.otherwise = Some(case_scope.inner())
            }
            None => {
              raise ElaborationError::Unreachable(message="Unexpected default case", span~)
            }
          }
          None => ()
        }

        if has_value {
          Expr(expr=Reference(Id(res_id.unwrap())), ty~, span~)
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
      let val = Map::new(capacity=fields.size())
      let sorted_keys = { let keys = fields.keys().collect(); keys.sort(); keys }

      for field in sorted_keys {
        let field_expr = fields[field]
        let field_name = binding.map(FRef::as_id).flatten().map(id => @firrtl.Id(id.join("$\{field}")))
        val[field] = self.lower_expr(field_expr, scope~, env~, binding=field_name)
      }

      Value::Struct(fields=val, ty~, span~)
    }
    Instance(path~, params~, ports~, span~, ty=inst_ty) => {
      if params.params.length() > 0 && not(self.declared_modules.contains(path)) {
        raise ElaborationError(message="Cannot elaborate parametric instance of module '\{path.to_string()}'", span~)
      }

      let (ports_sig, params_map, attributes) = match self.modules.get(path) {
        Some(inst_mod) => {
          let ports_sig: Map[String, @firrtl.PortSignature] = {}

          for port in inst_mod.ports {
            ports_sig[port.id.inner()] = {
              ty: port.ty,
              flow: port.flow,
            }
          }

          (ports_sig, {}, {})
        }
        None => match self.declared_modules.get(path) {
          Some(sig) => {
            let ports_sig = Map::new(capacity=sig.ports.length())
            let params_map = params.as_map(names=sig.params.map(fn(p) { p.name }))
            let resolved_params = @parse.keep_and_check_resolved(params_map, span~)

            for port in sig.ports {
              let ty = lower_type(port.ty.substitute(resolved_params, span~), span~)
              let port_sig: @firrtl.PortSignature = {
                flow: port.flow,
                ty
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
        Some(ref) => ref
        _ => {
          let inst_ty = lower_type(unwrap_type(inst_ty, span~), span~)
          let inst_id = id_of_path(path).join("_\{self.next_id()}")
          scope.add_stmt(Wire(id=inst_id, ty=inst_ty))
          Id(inst_id)
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
              connections[port_name] = Reference(Id(port_id))
            }
          }
        }
      }

      fn get_port(port_name: String) -> FExpr {
        match connections.get(port_name) {
          Some(expr) => expr
          None => {
            FExpr::Reference(@firrtl.FieldAccess(lhs=inst_ref, field=@firrtl.Id::from(port_name)))
          }
        }
      }
 
      // connect ports with inline expressions which are written to afterwards
      for port_name, access in accessed_ports.0 {
        if access == Write && inline_connections.get(port_name) is Some(inline_expr) {
          scope.add_stmt(Connect(
            FieldAccess(lhs=inst_ref, field=@firrtl.Id::from(port_name)),
            inline_expr
          ))
        }
      }

      if attributes.contains("internal") {
        fn get_param(name: String) -> @parse.Param raise {
          match params_map.get(name) {
            Some(param) => param
            None => raise ElaborationError(message="Unknown module parameter '\{name}'", span~)
          }
        }

        match path {
          { packages: [], member: "Reg" | "RegAsyncReset" as internal_module_name } => {
            let reg_ty = match get_param("T") {
              Resolved(TypeParam(ty~, ..)) => lower_type(ty, span~)
              _ => raise ElaborationError::Unreachable(message="non-type parameter in Reg instance", span~)
            }

            let sync_reset = internal_module_name == "Reg"
            let uses_rst = uses_port("rst")
            let uses_en = uses_port("en")
            let reg_id = @firrtl.Id::from("reg_\{self.next_idx()}")
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
                    PrimOp(op=AsAsyncReset, args=[rst])
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
                  scope.add_stmt(Connect(q_ref, Reference(Id(reg_id))))
                }
                None => ()
              }

              if accessed_ports.contains("q") {
                scope.add_stmt(Connect(FieldAccess(lhs=inst_ref, field=@firrtl.Id::from("q")), Reference(Id(reg_id))))
              }
            }

            if uses_port("d") {
              let en_stmt: FStmt = if uses_en {
                FStmt::When({
                  cond: get_port("en"),
                  body: [Connect(Id(reg_id), Reference(d_ref))],
                  otherwise: None,
                })
              } else {
                Connect(Id(reg_id), Reference(d_ref))
              }

              scope.add_stmt(en_stmt)

              if uses_port("q") {
                // connect d to q by default
                scope.add_stmt(Connect(
                  FieldAccess(lhs=inst_ref, field=@firrtl.Id::from("d")),
                  Reference(FieldAccess(lhs=inst_ref, field=@firrtl.Id::from("q")))
                ))
              }
            }
          }
          { packages: [], member: "Memory" } => {
            let data_type = lower_type(get_param("T").as_type(), span~)
            let depth = get_param("Depth").as_int()
            let read_ports = get_param("ReadPorts").as_int()
            let write_ports = get_param("WritePorts").as_int()
            let mem_id = self.gen_id("mem")
            
            if binding is Some(Id(id)) {
              self.memories[id.value()] = mem_id
            }

            let readers = {
              let readers = Array::new(capacity=read_ports)

              for i in 0..<read_ports {
                readers.push(@firrtl.Id::from(mem_id.inner() + "_reader\{i}"))
              }

              readers
            }

            let writers = {
              let writers = Array::new(capacity=write_ports)

              for i in 0..<write_ports {
                writers.push(@firrtl.Id::from(mem_id.inner() + "_writer\{i}"))
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
                let reader = @firrtl.StaticIndexing(lhs=ports, index=i)
                let reader_id = @firrtl.FieldAccess(lhs=Id(mem_id), field=readers[i])
                scope.add_stmt(Connect(FieldAccess(lhs=reader_id, field=@firrtl.Id::from("addr")), Reference(FieldAccess(lhs=reader, field=@firrtl.Id::from("addr")))))
                scope.add_stmt(Connect(FieldAccess(lhs=reader_id, field=@firrtl.Id::from("en")), Reference(FieldAccess(lhs=reader, field=@firrtl.Id::from("en")))))
                scope.add_stmt(Connect(FieldAccess(lhs=reader_id, field=@firrtl.Id::from("clk")), Reference(FieldAccess(lhs=reader, field=@firrtl.Id::from("clk")))))
                data_out.push(@firrtl.FieldAccess(lhs=reader_id, field=@firrtl.Id::from("data")))
              }
            }

            {
              let ports = self.expr_as_ref(get_port("write"), scope~)

              for i in 0..<write_ports {
                let writer = @firrtl.StaticIndexing(lhs=ports, index=i)
                let writer_id = @firrtl.FieldAccess(lhs=Id(mem_id), field=writers[i])
                scope.add_stmt(Connect(FieldAccess(lhs=writer_id, field=@firrtl.Id::from("addr")), Reference(FieldAccess(lhs=writer, field=@firrtl.Id::from("addr")))))
                scope.add_stmt(Connect(FieldAccess(lhs=writer_id, field=@firrtl.Id::from("en")), Reference(FieldAccess(lhs=writer, field=@firrtl.Id::from("en")))))
                scope.add_stmt(Connect(FieldAccess(lhs=writer_id, field=@firrtl.Id::from("clk")), Reference(FieldAccess(lhs=writer, field=@firrtl.Id::from("clk")))))
                scope.add_stmt(Connect(FieldAccess(lhs=writer_id, field=@firrtl.Id::from("data")), Reference(FieldAccess(lhs=writer, field=@firrtl.Id::from("data")))))
                scope.add_stmt(Connect(FieldAccess(lhs=writer_id, field=@firrtl.Id::from("mask")), Reference(FieldAccess(lhs=writer, field=@firrtl.Id::from("mask")))))
              }
            }

            let q = self.expr_as_ref(get_port("q"), scope~)

            for i, data in data_out {
              scope.add_stmt(Connect(FRef::StaticIndexing(lhs=q, index=i), Reference(data)))
            }
          }
          _ => raise ElaborationError(message="Module '\{path.to_string()}' is marked as internal but has no elaboration handler", span~)
        }
      } else {
        let inst_id = @firrtl.Id::from("inst_\{self.next_idx()}")
        scope.add_stmt(Inst(id=inst_id, of=id_of_path(path), sig={ ports: ports_sig }))

        for port_name, sig in ports_sig {
          if uses_port(port_name) {
            let lhs = Expr(expr=Reference(FieldAccess(lhs=Id(inst_id), field=@firrtl.Id::from(port_name))), ty=sig.ty, span~)
            let rhss = Array::new(capacity=2)

            if accessed_ports.contains(port_name) {
              rhss.push(Expr(expr=Reference(FieldAccess(lhs=inst_ref, field=@firrtl.Id::from(port_name))), ty=sig.ty, span~))
            }
            
            if inline_connections.contains(port_name) {
              rhss.push(Expr(expr=get_port(port_name), ty=sig.ty, span~))
            }

            for rhs in rhss {
              match sig.flow {
                Input => {
                  self.connect(lhs=lhs.as_ref(self, scope~), value=rhs, scope~)
                }
                Output | Inout => {
                  self.connect(lhs=rhs.as_ref(self, scope~), value=lhs, scope~)
                }
              }
            }
          }
        }
      }

      Expr(expr=Reference(inst_ref), ty~, span~)
    }
    Indexing(expr~, index~, span~, ty=_) => {
      let val = self.lower_expr(expr, scope~, env~)
      let index = self.lower_expr(index, scope~, env~)
      let idx_int = match (try? index.as_int()) {
        Ok(idx) => Some(idx.to_int())
        _ => None
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
              Expr(expr=PrimOp(op=Bits, args=[val.as_expr(self, scope~), index_expr, index_expr]), ty=UInt(1), span~)
            }
            _ => {
              Expr(expr=Reference(FRef::indexing_from(lhs=val.as_ref(self, scope~), index=index_expr)), ty~, span~)
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
          Expr(expr=PrimOp(op=Bits, args=[expr, FExpr::uint(hi), FExpr::uint(lo)]), ty~, span~)
        }
        Vec(elem_ty, _) => {
          let slice_len = hi + 1 - lo
          let elems = Array::new(capacity=slice_len)
          let lhs = val.as_ref(self, scope~)

          for i in lo..=hi {
            elems.push(Expr(expr=Reference(StaticIndexing(lhs~, index=i)), ty=elem_ty, span~))
          }

          Vector(elems~, ty=Vec(elem_ty, slice_len), span~)
        }
        ty => raise ElaborationError::Unsupported(message="Slicing is not support on value of type '\{ty}'", span~)
      }
    }
    FieldAccess(expr=accessed_expr, field~, span~, ty=_) => {
      let val = self.lower_expr(accessed_expr, scope~, env~)
      Expr(expr=Reference(FieldAccess(lhs=val.as_ref(self, scope~), field=@firrtl.Id::from(field))), ty~, span~)
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

      for stmt in block_scope.inner() {
        scope.add_stmt(stmt)
      }

      match last_val {
        Some(val) => val
        None => Empty(span~)
      }
    }
    String(value=str, span~, ty~) => {
      let chars: Array[@parse.Expr] = Array::new(capacity=str.length())

      for char in str {
        let char_latin1 = char.to_int()

        if char_latin1 < 0 || char_latin1 > 255 {
          raise ElaborationError(message="String literal contains unsupported character '\{char}' (expected Latin-1)", span~)
        }

        chars.push(@parse.Expr::nat(char_latin1, width=Some(8), span~))
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
          Expr(expr=PrimOp(op=AsSInt, args=[flattened]), ty=fir_ty, span~)
        }
        ("uint", UInt(_) | UIntInferred | AsyncReset | Reset) | ("sint", SInt(_) | SIntInferred) => arg
        ("uint", SInt(_) | SIntInferred) => Expr(expr=PrimOp(op=AsUInt, args=[arg.as_expr(self, scope~)]), ty=fir_ty, span~)
        ("uint", Clock) => Expr(expr=PrimOp(op=AsUInt, args=[arg.as_expr(self, scope~)]), ty=fir_ty, span~)
        ("sint", UInt(_) | UIntInferred) => Expr(expr=PrimOp(op=AsSInt, args=[arg.as_expr(self, scope~)]), ty=fir_ty, span~)
        _ => raise ElaborationError::Unsupported(message="Cannot convert type '\{arg.ty()}' to UInt or SInt with '\{name}'", span~)
      }
    }
    FunCall(name="clock", args=[clk], span~, ..) => {
      let clk = self.lower_expr(clk, scope~, env~)
      let clk_ref = clk.as_ref(self, scope~)

      Expr(expr=PrimOp(op=AsClock, args=[Reference(clk_ref)]), ty=Clock, span~)
    }
    FunCall(name="pad", args=[arg, width_arg], span~, ty~) => {
      let arg = self.lower_expr(arg, scope~, env~)
      let width = self.lower_expr(width_arg, scope~, env~).as_int().to_int()
      let ty = lower_type(unwrap_type(ty, span~), span~)
      Expr(expr=PrimOp(op=Pad, args=[arg.as_expr(self, scope~), FExpr::uint(width)]), ty~, span~)
    }
    FunCall(name="readmemb" | "readmemh" as name, args=[path, mem], span~, ..) => {
      let path = path.expect_string()
      let mem_ref = self.lower_expr(mem, scope~, env~).as_ref(self, scope~)
      let mem_name = match mem_ref {
        Id(id) => id.inner()
        _ => raise ElaborationError::Unsupported(message="Cannot reference indirect memory inside \{name}", span~)
      }

      let mem_id = match self.memories.get(mem_name) {
        Some(id) => id.inner()
        None => raise ElaborationError(message="Unknown memory '\{mem_name}' referenced in \{name}", span~)
      }

      let annotation = {
        "class": "firrtl.annotations.MemoryFileInlineAnnotation",
        "target": [..self.current_target, mem_id].join("."),
        "filename": path,
        "hexOrBinary": if name == "readmemh" { "h" } else { "b" },
        "originalMemoryNameOpt": mem_id,
      }

      self.annotations.push(annotation.to_json())
      Empty(span~)
    }
    FunCall(name="printf", args=[fmt, ..args], span~, ..) => {
      let fmt = fmt.expect_string()
      let new_args = Array::new(capacity=args.length())

      for arg in args {
        new_args.push(self.lower_expr(arg, scope~, env~).as_expr(self, scope~))
      }

      let clk = self.get_clock(source="printf", span~)
      let en = FExpr::Literal(UInt(width=1, radix=Some(2), value=BigInt::from_int(1)))

      scope.add_stmt(Command(Printf(clk~, en~, fmt~, args=new_args)))
      Empty(span~)
    }
    FunCall(name="assert", args=[pred, ..rest], span~, ..) => {
      let pred_val = self.lower_expr(pred, scope~, env~)
      let clk = self.get_clock(source="assert", span~)
      let en = FExpr::Literal(UInt(width=1, radix=Some(2), value=BigInt::from_int(1)))

      let (fmt, args) = if rest is [format_str, ..args] {
        let fmt = format_str.expect_string()
        let new_args = Array::new(capacity=args.length())

        for arg in args {
          new_args.push(self.lower_expr(arg, scope~, env~).as_expr(self, scope~))
        }

        (fmt, new_args)
      } else {
        let pred_fmt = {
          let emitter = @parse.AstEmitter::new()
          emitter.emit_expr(pred)
          
        }

        ("assertion failed: \{pred_fmt}", [])
      }

      scope.add_stmt(Command(Assert(clk~, en~, pred=pred_val.as_expr(self, scope~), fmt~, args~)))

      Empty(span~)
    }
    FunCall(name="stop", args~, span~, ..) => {
      let clk = self.get_clock(source="stop", span~)
      let en = FExpr::Literal(UInt(width=1, radix=Some(2), value=BigInt::from_int(1)))
      let code = match args {
        [] => 0
        [code] => self.lower_expr(code, scope~, env~).as_int().to_int()
        _ => raise Failure("Unexpected number of arguments to stop!")
      }

      scope.add_stmt(Command(Stop(clk~, en~, code~)))
      Empty(span~)
    }
    FunCall(name="rev", args=[arg], span~, ty={val: Some(Vector(ty=elem_ty, len=Fixed(len)))}) => {
      let arg = self.lower_expr(arg, scope~, env~)
      let arg_ref = arg.as_ref(self, scope~)
      let elems = Array::new(capacity=len)
      let fir_elem_ty = lower_type(elem_ty, span~)

      for i in 0..<len {
        let elem = FRef::StaticIndexing(lhs=arg_ref, index=len - 1 - i)
        let val = Value::Expr(expr=Reference(elem), ty=fir_elem_ty, span~)
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
        bits.push(FExpr::PrimOp(op=Bits, args=[Reference(arg_ref), index, index]))
      }

       Value::Expr(expr=concat_rev(bits), ty=UInt(width), span~)
    }
    Spread(_) | Ternary(_) | Replicate(_) | FunCall(_) | If(_) => {
      raise ElaborationError(message="Unexpected expression encountered during elaboration", span=expr.span())
    }
  }
}

pub fn Elaborator::lower(self: Elaborator, decls: Iter[@parse.Decl]) -> Unit raise {
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

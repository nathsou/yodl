
pub struct Elaborator {
  mut autoidx: Int
  modules: Map[@parse.Path, @firrtl.Module]
  declared_modules: Map[@parse.Path, @parse.ModuleSignature]
}

pub fn Elaborator::new() -> Elaborator {
  { autoidx: 0, modules: {}, declared_modules: {} }
}

fn next_idx(self: Elaborator) -> Int {
  let idx = self.autoidx
  self.autoidx += 1
  idx
}

priv enum Value {
  Expr(expr~: @firrtl.Expr, ty~: @firrtl.Type, span~: @parse.Span)
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

typealias ElaboratorEnv = Scope[@parse.Path, Value]

pub type! ElaborationError {
  UnresolvedIdentifier(path~: @parse.Path, span~: @parse.Span)
  UnexpectedStmtDuringElaboration(span~: @parse.Span)
  UnexpectedExprDuringElaboration(span~: @parse.Span)
  UntypedValue(span~: @parse.Span)
  ParametricInstanceDuringElaboration(span~: @parse.Span)
  Unreachable(message~: String, span~: @parse.Span)
  ExtraPorts(extra_ports~: Array[String], span~: @parse.Span)
  UnknownModule(path~: @parse.Path, span~: @parse.Span)
  UnknownModulePort(module_path~: @parse.Path, port_name~: String, span~: @parse.Span)
  UnknownModuleParameter(name~: String, span~: @parse.Span)
  InvalidMemoryInitValue(span~: @parse.Span, expected_size~: Int, actual_size~: Int?)
  MissingConnectionsOnWriteableMemoryInstance(missing_connections~: Array[String], span~: @parse.Span)
  UnknownModuleMarkedAsInternal(path~: @parse.Path, span~: @parse.Span)
  Unsupported(message~: String, span~: @parse.Span)
  DynamicIntParam(span~: @parse.Span)
  InvalidCharacterInString(char~: Char, span~: @parse.Span)
  ExpctedIntLiteral(span~: @parse.Span)
} derive (Show)

trait ScopeLike {
  add_stmt(Self, @firrtl.Stmt) -> Unit
}

impl ScopeLike for @firrtl.Module with add_stmt(self, stmt) {
  self.body.push(stmt)
}

type StmtContainer Array[@firrtl.Stmt]

fn StmtContainer::new() -> StmtContainer {
  Array::new()
}

impl ScopeLike for StmtContainer with add_stmt(self, stmt) {
  self._.push(stmt)
}

fn id_of_path(path: @parse.Path) -> @firrtl.Id {
  match path.packages {
    [] => Ident(path.member)
    _ => Ident(String::concat(path.packages, separator="_") + "_" + path.member)
  }
}

fn id_of_str(name: String) -> @firrtl.Id {
  Ident(name)
}

fn lower_type(ty: @parse.Type, span~: @parse.Span) -> @firrtl.Type! {
  match ty {
    Nat => UIntInferred
    UInt(Fixed(width)) => UInt(width)
    SInt(Fixed(width)) => SInt(width)
    Vector(ty~, len=Fixed(len)) => Vec(lower_type!(ty, span~), len)
    UInt(Dynamic(_)) | SInt(Dynamic(_)) | Vector(ty=_, len=Dynamic(_)) => {
      raise DynamicIntParam(span~)
    }
    Instance(sig~, params~, accessed_ports~) => {
      let fields: Array[@firrtl.BundleField] = Array::new(capacity=accessed_ports.size())

      for port in accessed_ports {
        let port_sig = sig.get_port(port).or_error!(ElaborationError::UnknownModulePort(module_path=sig.path, port_name=port, span~))

        let field: @firrtl.BundleField = {
          id: id_of_str(port),
          ty: lower_type!(port_sig.ty.substitute(params), span~),
          flip: port_sig.direction == Input,
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
          id: id_of_str(name),
          ty: lower_type!(ty, span~),
          flip: false,
        }

        fir_fields.push(field)
      }

      Bundle(fir_fields)
    }
    String(len~) => Vec(UInt(8), len)
  }
}

fn lower_module(self: Elaborator, mod: @parse.ModuleDecl) -> Unit! {
  let env = ElaboratorEnv::new()

  let fir_mod: @firrtl.Module = {
    public: true,
    id: id_of_path(mod.path),
    ports: {
      let ports = Array::new(capacity=mod.ports.length())

      for port in mod.ports {
        let fir_ty = lower_type!(port.ty, span=port.span)

        let fir_port: @firrtl.Port = {
          direction: port.direction,
          id: id_of_str(port.name),
          ty: fir_ty,
        }
        
        ports.push(fir_port)
        env.declare!(@parse.Path::new([], port.name), Expr(expr=@firrtl.Reference(Id(id_of_str(port.name))), ty=fir_ty, span=port.span))
      }

      ports
    },
    body: [],
  }

  self.modules[mod.path] = fir_mod

  for stmt in mod.body {
    self.lower_stmt!(stmt, scope=fir_mod, env~)
  }
}

fn unwrap_type(ty: Ref[@parse.Type?], span~: @parse.Span) -> @parse.Type!ElaborationError {
  ty.val.or_error!(UntypedValue(span~))
}

fn next_id(self: Elaborator) -> Int {
  let idx = self.autoidx
  self.autoidx += 1
  idx
}

fn Value::as_ref(self: Value, elaborator: Elaborator, scope~: &ScopeLike, binding~: String? = None) -> @firrtl.Reference! {
  match self.as_expr!(elaborator, scope~, binding~) {
    Reference(value) => value
    expr => {
      let prefix = binding.or("temp")
      let rhs_id = id_of_str("\{prefix}_\{elaborator.next_id()}")
      scope.add_stmt(Node(id=rhs_id, expr~))
      Id(rhs_id)
    }
  }
}

fn connect(self: Elaborator, lhs~: @firrtl.Reference, value~: Value, scope~: &ScopeLike) -> Unit! {
  let rhs = value.as_ref!(self, scope~)
  let same = match (lhs, rhs) {
    (Id(a), Id(b)) => a.inner() == b.inner()
    _ => false
  }

  if not(same) {
    scope.add_stmt(Connect(lhs, Reference(rhs)))
  }
}

fn Value::ty(self: Value) -> @firrtl.Type {
  match self {
    Expr(ty~, ..) => ty
    Vector(ty~, ..) => ty
    Struct(ty~, ..) => ty
    Empty(_) => UInt(0)
  }
}

fn Value::as_expr(self: Value, elaborator: Elaborator, scope~: &ScopeLike, binding~: String? = None) -> @firrtl.Expr! {
  match self {
    Expr(expr~, ..) => expr
    Vector(elems~, ty~, span~) => {
      let id = id_of_str("vec_\{elaborator.next_id()}")
      scope.add_stmt(Wire(id~, ty~))
      for i, elem in elems {
        let index = @firrtl.Expr::Int(BigInt::from_int(elems.length() -  i - 1))
        elaborator.connect!(lhs=Indexing(lhs=Id(id), index~), value=elem, scope~)
      }

      Reference(Id(id))
    }
    Struct(fields~, ty~, span~) => {
      let id = id_of_str(binding.or_else(fn() {"struct_\{elaborator.next_id()}"}))

      if binding.is_empty() {
        scope.add_stmt(Wire(id~, ty~))
      }

      for field in fields {
        elaborator.connect!(lhs=FieldAccess(lhs=Id(id), field=id_of_str(field.0)), value=field.1, scope~)
      }

      Reference(Id(id))
    }
    Empty(span=_) => Literal(UInt(width=0, radix=Some(2), value=BigInt::from_int(0)))
  }
}

fn Value::as_int(self: Value) -> BigInt! {
  match self {
    Expr(expr=Literal(UInt(value~, ..)) | Int(value), ..) => value
    _ => raise ExpctedIntLiteral(span=self.span())
  }
}

fn concat(exprs: Array[@firrtl.Expr]) -> @firrtl.Expr! {
    if exprs.is_empty() {
      return Literal(UInt(width=0, radix=Some(2), value=BigInt::from_int(0)))
    }

    let list = @immut/list.from_array(exprs)

    fn go(lst: @immut/list.T[@firrtl.Expr], acc: @firrtl.Expr) -> @firrtl.Expr! {
      match lst.head() {
        Some(expr) => {
          go!(lst.tail(), @firrtl.primop(Cat, [expr, acc]))
        }
        None => acc
      }
    }

    go!(list.tail(), exprs[0])
}

fn flat_uint(reference: @firrtl.Reference, ty: @firrtl.Type, span~: @parse.Span) -> @firrtl.Expr! {
  match ty {
    Const(inner_ty) => flat_uint!(reference, inner_ty, span~)
    Vec(elem_ty, len) => {
      let refs = Array::new(capacity=len)

      for i in 0..<len {
        let index = @firrtl.Expr::Int(BigInt::from_int(i))
        let r = @firrtl.Reference::Indexing(lhs=reference, index=index)
        refs.push(flat_uint!(r, elem_ty, span~))
      }

      concat!(refs)
    }
    Bundle(fields) => {
      let refs = Array::new(capacity=fields.length())

      for field in fields {
        let r = @firrtl.Reference::FieldAccess(lhs=reference, field=field.id)
        refs.push(flat_uint!(r, field.ty, span~))
      }

      concat!(refs)
    }
    UInt(_) => Reference(reference)
    _ => raise ElaborationError::Unsupported(message="Cannot flatten value of type \{ty}", span~)
  }
}

fn lower_stmt(self: Elaborator, stmt: @parse.Stmt, scope~: &ScopeLike, env~: ElaboratorEnv) -> Unit! {
  match stmt {
    Expr(expr~, span=_) => {
      let _ = self.lower_expr!(expr, scope~, env~, binding=None)
    }
    Let(name~, ty~, expr~, span~) => {
      let path = @parse.Path::new([], name)
      let ty = lower_type!(unwrap_type!(ty, span~), span~)
      scope.add_stmt(Wire(id=id_of_str(name), ty~))

      let val = match expr {
        Some(expr) => Some(self.lower_expr!(expr, scope~, env~, binding=Some(name)))
        None => None
      }
      
      let var = @firrtl.Reference::Id(id_of_str(name))

      match val {
        Some(val) => {
          self.connect!(lhs=var, value=val, scope~)
        }
        None => ()
      }

      env.declare!(path, Expr(expr=Reference(var), ty~, span~))
    }
    Assign(lhs~, rhs~, span~) => {
      let fir_lhs = self.lower_expr!(lhs, scope~, env~, binding=None).as_ref!(self, scope~, binding=None)
      let fir_rhs = self.lower_expr!(rhs, scope~, env~, binding=None)
      self.connect!(lhs=fir_lhs, value=fir_rhs, scope~)
    }
    Const(_) | For(_) | Scope(_) => {
      raise UnexpectedStmtDuringElaboration(span=stmt.span())
    }
  }
}

fn lower_expr(self: Elaborator, expr: @parse.Expr, scope~: &ScopeLike, env~: ElaboratorEnv, binding~: String? = None) -> Value! {
  let expr_span = expr.span()
  let ty = lower_type!(unwrap_type!(expr.ty(), span=expr_span), span=expr_span)
  
  match expr {
    Natural(value~, width~, base~, span~, ty=_) => {
      let width = match width {
        Some(width) => width
        None => @utils.significant_bits(value)
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
      let fir_expr = self.lower_expr!(expr, scope~, env~).as_expr!(self, scope~)
      let primop: @firrtl.PrimOp = match op {
        Not => Not
      }

      Expr(expr=@firrtl.primop(primop, [fir_expr]), ty~, span~)
    }
    Binary(op~, lhs~, rhs~, span~, ty=_) => {
      let fir_lhs = self.lower_expr!(lhs, scope~, env~).as_expr!(self, scope~)
      let fir_rhs = self.lower_expr!(rhs, scope~, env~).as_expr!(self, scope~)
      let is_rhs_int = rhs.as_int?().is_ok()
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

      let mut res = @firrtl.primop(primop, [fir_lhs, fir_rhs])

      if negate { 
        res = @firrtl.primop(Not, [res])
      }

      Expr(expr=res, ty~, span~) 
    }
    Vector(elems~, span~, ty=_) => {
      let values = Array::new(capacity=elems.length())

      for elem in elems {
        match elem {
          Spread(expr~, ..) => {
            let val = self.lower_expr!(expr, scope~, env~)
            let reference = val.as_ref!(self, scope~, binding=None)

            match val.ty() {
              Vec(elem_ty, len) => {
                for i in 0..<len {
                  let index = @firrtl.Expr::Int(BigInt::from_int(len - i - 1))
                  values.push(Expr(expr=Reference(Indexing(lhs=reference, index~)), ty=elem_ty, span=elem.span()))
                }
              }
              UInt(len) | SInt(len) => {
                for i in 0..<len {
                  let index = @firrtl.Expr::Int(BigInt::from_int(len - i - 1))
                  values.push(Expr(expr=@firrtl.primop(Bits, [Reference(reference), index, index]), ty=UInt(1), span=elem.span()))
                }
              }
              _ => {
                values.push(val)
              }
            }
          }
          _ => {
            values.push(self.lower_expr!(elem, scope~, env~))
          }
        }
      }

      Vector(elems=values, ty~, span~)
    }
    Match(subject~, cases~, default~, span~, ty=match_ty) => {
      let has_value = unwrap_type!(match_ty, span~).width!(span) > 0
      let res_id = if has_value {
        let res_id = id_of_str(binding.or_else(fn() { "match_\{self.next_idx()}" }))

        if binding.is_empty() {
          scope.add_stmt(Wire(id=res_id, ty~))
        }

        Some(res_id)
      } else {
        None
      }
      
      let subject_binding = binding.map(fn(b) { "\{b}_subject" }).or("subject")
      let fir_subject = @firrtl.Reference(self.lower_expr!(subject, scope~, env~).as_ref!(self, scope~, binding=Some(subject_binding)))
      let is_complete = default.is_empty() && cases.length() == @utils.pow2(unwrap_type!(subject.ty(), span~).width!(span))
      let mut last_when: @firrtl.When? = None

      for idx, case in cases {
        let (lhs, rhs) = case
        let fir_lhs = self.lower_expr!(lhs, scope~, env~).as_expr!(self, scope~)
        let body = {
          let case_scope = StmtContainer::new()
          let fir_rhs = self.lower_expr!(rhs, scope=case_scope, env~).as_expr!(self, scope=case_scope)
          if has_value {
            case_scope.add_stmt(Connect(Id(res_id.unwrap()), fir_rhs))
          }

          case_scope._
        }

        let when: @firrtl.When = {
          cond: @firrtl.primop(Eq, [fir_subject, fir_lhs]),
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
            let fir_rhs = self.lower_expr!(expr, scope=case_scope, env~).as_expr!(self, scope=case_scope)
            if has_value {
              case_scope.add_stmt(Connect(Id(res_id.unwrap()), fir_rhs))
            }

            last_when.otherwise = Some(case_scope._)
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
    Tuple(elems~, span~, ty=_) => {
      let values = Array::new(capacity=elems.length())

      for elem in elems {
        values.push(self.lower_expr!(elem, scope~, env~))
      }

      Vector(elems=values, ty~, span~)
    }
    Struct(fields~, span~, ty=_) => {
      let val = Map::new(capacity=fields.size())
      let sorted_keys = { let keys = fields.keys().collect(); keys.sort(); keys }

      for field in sorted_keys {
        let field_expr = fields[field].unwrap()
        let field_name = binding.map(fn(name) { "\{name}_\{field}" })
        val[field] = self.lower_expr!(field_expr, scope~, env~, binding=field_name)
      }

      Value::Struct(fields=val, ty~, span~)
    }
    Instance(path~, params~, ports~, span~, ty=inst_ty) => {
      if params._.length() > 0 && not(self.declared_modules.contains(path)) {
        raise ParametricInstanceDuringElaboration(span~)
      }

      let (ports_sig, params_map, attributes) = match self.modules[path] {
        Some(inst_mod) => {
          let ports_sig = {}

          for port in inst_mod.ports {
            ports_sig[port.id.inner()] = {
              ty: port.ty,
              direction: port.direction,
            }
          }

          (ports_sig, {}, {})
        }
        None => match self.declared_modules[path] {
          Some(sig) => {
            let ports_sig = Map::new(capacity=sig.ports.length())
            let params_map = params.as_map!(names=sig.params)
            let params_env = Map::new(capacity=params_map.size())

            for name, param in params_map {
              params_env[name] = param.as_param!()
            }

            for port in sig.ports {
              let ty = lower_type!(port.ty.substitute(params_env), span~)
              ports_sig[port.name] = {
                ty,
                direction: port.direction,
              }
            }

            (ports_sig, params_map, sig.attributes)
          }
          None => raise ElaborationError::UnknownModule(path~, span~)
        }
      }

      let inline_connections: Map[String, @firrtl.Expr] = {}
      let connections: Map[String, @firrtl.Expr] = {}
      let accessed_ports = match inst_ty.val {
        Some(Instance(sig=_, params=_, accessed_ports~)) => accessed_ports
        _ => raise ElaborationError::Unreachable(message="Untyped instance", span~)
      }

      let extra_ports = []

      fn uses_port(port_name: String) -> Bool {
        ports.contains(port_name) || accessed_ports.contains(port_name)
      }

      let inst_name = match binding {
        Some(name) => id_of_str(name)
        None => {
          let inst_ty = lower_type!(unwrap_type!(inst_ty, span~), span~)
          let inst_id = id_of_path(path).join("_\{self.next_id()}")
          scope.add_stmt(Wire(id=inst_id, ty=inst_ty))
          inst_id
        }
      }

      for port_name, expr in ports {
        if not(ports_sig.contains(port_name)) {
          extra_ports.push(port_name)
        }

        inline_connections[port_name] = self.lower_expr!(expr, scope~, env~).as_expr!(self, scope~)
      }
      
      if not(extra_ports.is_empty()) {
        raise ExtraPorts(extra_ports~, span~)
      }

      for port_name, port_sig in ports_sig {
        match inline_connections[port_name] {
          Some(expr) => {
            connections[port_name] = expr
          }
          None => {
            if uses_port(port_name) && not(accessed_ports.contains(port_name)) {
              let port_id = id_of_str("\{inst_name.inner()}_\{port_name}")
              scope.add_stmt(Wire(id=port_id, ty=port_sig.ty))
              connections[port_name] = Reference(Id(port_id))
            }
          }
        }
      }

      fn get_port(port_name: String) -> @firrtl.Expr {
        match connections[port_name] {
          Some(expr) => expr
          None => {
            @firrtl.Expr::Reference(@firrtl.FieldAccess(lhs=Id(inst_name), field=id_of_str(port_name)))
          }
        }
      }

      if attributes.contains("internal") {
        fn get_param(name: String) -> @parse.Expr! {
          match params_map[name] {
            Some(param) => param
            None => raise UnknownModuleParameter(name~, span~)
          }
        }

        match path {
          { packages: [], member: "Reg" | "RegAsyncReset" as internal_module_name } => {
            let width = get_param!("Width").as_int!()
            let sync_reset = internal_module_name == "Reg"
            let uses_rst = uses_port("rst")
            let uses_en = uses_port("en")
            let reg_ty = @firrtl.Type::UInt(width)
            let reg_id = id_of_str("reg_\{self.next_idx()}")
            let clk = @firrtl.primop(AsClock, [get_port("clk")])

            let reg_stmt = if uses_rst {
              @firrtl.Stmt::RegReset(
                id=reg_id,
                ty=reg_ty,
                clock=clk,
                reset={
                  let rst = get_port("rst")
                  
                  if sync_reset {
                    rst
                  } else {
                    @firrtl.primop(AsAsyncReset, [rst])
                  }
                },
                init=Literal(UInt(width~, radix=Some(10), value=BigInt::from_int(0))),
              )
            } else {
              @firrtl.Stmt::Reg(
                id=reg_id,
                ty=reg_ty,
                clock=clk,
              )
            }

            scope.add_stmt(reg_stmt)

            let d_ref = Value::Expr(expr=get_port("d"), ty=UInt(width), span~).as_ref!(self, scope~)

            if uses_port("q") {
              let q_ref = Value::Expr(expr=get_port("q"), ty=UInt(width), span~).as_ref!(self, scope~)
              scope.add_stmt(Connect(q_ref, Reference(Id(reg_id))))

              if accessed_ports.contains("q") {
                scope.add_stmt(Connect(FieldAccess(lhs=Id(inst_name), field=id_of_str("q")), Reference(Id(reg_id))))
              }
            }

            if uses_port("d") {
              let en_stmt: @firrtl.Stmt = if uses_en {
                @firrtl.Stmt::When({
                  cond: get_port("en"),
                  body: [Connect(Id(reg_id), Reference(d_ref))],
                  otherwise: None,
                })
              } else {
                Connect(Id(reg_id), Reference(d_ref))
              }

              scope.add_stmt(en_stmt)
            }
          }
          { packages: [], member: "Memory" } => {
            raise ElaborationError::Unsupported(message="Memory instances are not supported yet", span~)
            // let width = get_param!("Width").as_int!()
            // let depth = get_param!("Depth").as_int!()
            // let read_ports = get_param!("ReadPorts").as_int!()
            // let write_ports = get_param!("WritePorts").as_int!()
            // let clamped_write_ports = @utils.max(write_ports, 1)
            // let abits = @utils.clog2(depth + 1)

            // let init = match params_map["Init"] {
            //   Some(Natural(bits~, width=Some(init_width), ..)) => {
            //     if init_width != depth * width {
            //       raise InvalidMemoryInitValue(
            //         span~,
            //         expected_size=depth * width,
            //         actual_size=Some(init_width),
            //       )
            //     }

            //     bits
            //   }
            //   _ => raise InvalidMemoryInitValue(
            //     span~,
            //     expected_size=depth * width,
            //     actual_size=None,
            //   )
            // }

            // let uses_data_in = uses_port("data_in")
            // let uses_write_enable = uses_port("write_enable")
            // let uses_write_addr = uses_port("write_addr")
            // let is_writeable = uses_data_in || uses_write_enable || uses_write_addr

            // if is_writeable && not(uses_data_in && uses_write_enable && uses_write_addr) {
            //   let missing_connections = []

            //   if not(uses_data_in) {
            //     missing_connections.push("data_in")
            //   }

            //   if not(uses_write_enable) {
            //     missing_connections.push("write_enable")
            //   }

            //   if not(uses_write_addr) {
            //     missing_connections.push("write_addr")
            //   }

            //   raise MissingConnectionsOnWriteableMemoryInstance(missing_connections~, span~)
            // }

            // let read_addrs = Array::new(capacity=read_ports)

            // for i in 0..<read_ports {
            //   read_addrs.push(select(
            //     expr=get_port("read_addr"),
            //     offset=(read_ports - i) * abits - 1,
            //     width=abits,
            //     span~,
            //   ))
            // }

            // let write_addrs = Array::new(capacity=clamped_write_ports)

            // for i in 0..<write_ports {
            //   write_addrs.push(select(
            //     expr=get_port("write_addr"),
            //     offset=(write_ports - i) * abits - 1,
            //     width=abits,
            //     span~,
            //   ))
            // }

            // let write_enables = if uses_write_enable {
            //   let write_enables = Array::new(capacity=write_ports)

            //   for i in 0..<write_ports {
            //     write_enables.push(select(
            //       expr=get_port("write_enable"),
            //       offset=i,
            //       width=1,
            //       span~,
            //     ))
            //   }

            //   Some(write_enables)
            // } else {
            //   None
            // }

            // let data_ins = Array::new(capacity=clamped_write_ports)

            // for i in 0..<clamped_write_ports {
            //   data_ins.push(select(
            //     expr=get_port("data_in"),
            //     offset=(clamped_write_ports - i) * width - 1,
            //     width=width,
            //     span~,
            //   ))
            // }

            // let data_out = Array::new(capacity=read_ports)
          
            // for i in 0..<read_ports {
            //   data_out.push(select(
            //     expr=get_port("data_out"),
            //     offset=(read_ports - i) * width - 1,
            //     width=width,
            //     span~,
            //   ))
            // }

            // @yir.Stmt::Memory(
            //   width~,
            //   depth~,
            //   init=Some(init),
            //   clk=get_port("clk"),
            //   read_addr=read_addrs,
            //   write_addr=write_addrs,
            //   write_enable=write_enables,
            //   data_in=data_ins,
            //   data_out=data_out,
            //   span~, 
            // )
          }
          _ => raise UnknownModuleMarkedAsInternal(path~, span~)
        }
      } else {
        let inst_id = id_of_str("inst_\{self.next_idx()}")
        scope.add_stmt(Inst(id=inst_id, of=id_of_path(path)))

        for port_name, sig in ports_sig {
          if uses_port(port_name) {
            let lhs = Expr(expr=Reference(FieldAccess(lhs=Id(inst_id), field=id_of_str(port_name))), ty=sig.ty, span~)
            let rhs = if accessed_ports.contains(port_name) {
              Expr(expr=Reference(FieldAccess(lhs=Id(inst_name), field=id_of_str(port_name))), ty=sig.ty, span~)
            } else {
              Expr(expr=get_port(port_name), ty=sig.ty, span~)
            }

            match sig.direction {
              Input => {
                self.connect!(lhs=lhs.as_ref!(self, scope~), value=rhs, scope~)
              }
              Output | Inout => {
                self.connect!(lhs=rhs.as_ref!(self, scope~), value=lhs, scope~)
              }
            }
          }
        }
      }

      Expr(expr=Reference(Id(inst_name)), ty~, span~)
    }
    Indexing(expr~, index~, span~, ty=_) => {
      let val = self.lower_expr!(expr, scope~, env~)
      let index = self.lower_expr!(index, scope~, env~)
      let idx_int = match index.as_int?() {
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
            Some(idx) => @firrtl.Expr::Int(BigInt::from_int(idx))
            None => index.as_expr!(self, scope~)
          }

          match expr.ty().val {
            Some(UInt(_)) => {
              Expr(expr=@firrtl.primop(Bits, [val.as_expr!(self, scope~), index_expr, index_expr]), ty=UInt(1), span~)
            }
            _ => {
              Expr(expr=@firrtl.Reference(Indexing(lhs=val.as_ref!(self, scope~), index=index_expr)), ty~, span~)
            }
          }
        }
      }
    }
    Slicing(expr~, hi~, lo~, span~, ..) => {
      let val = self.lower_expr!(expr, scope~, env~)
      let hi = self.lower_expr!(hi, scope~, env~).as_int!()
      let lo = self.lower_expr!(lo, scope~, env~).as_int!()

      match val.ty() {
        UInt(_) | SInt(_) => {
          let expr = val.as_expr!(self, scope~)
          Expr(expr=@firrtl.primop(Bits, [expr, Int(hi), Int(lo)]), ty~, span~)
        }
        _ => raise ElaborationError::Unsupported(message="Slicing is only supported on UInt, SInt types", span~)
      }
    }
    FieldAccess(expr=accessed_expr, field~, span~, ty=_) => {
      let val = self.lower_expr!(accessed_expr, scope~, env~)
      Expr(expr=Reference(FieldAccess(lhs=val.as_ref!(self, scope~), field=id_of_str(field))), ty~, span~)
    }
    Block(body~, last~, span~, ..) => {
      let block_env = env.child()
      let block_scope = StmtContainer::new()

      for stmt in body {
        self.lower_stmt!(stmt, scope=block_scope, env=block_env)
      }

      let last_val = match last {
        Some(expr) => Some(self.lower_expr!(expr, scope=block_scope, env=block_env))
        None => None
      }

      for stmt in block_scope._ {
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
          raise InvalidCharacterInString(char~, span~)
        }

        chars.push(@parse.Expr::nat(char_latin1, width=Some(8), span~))
      }

      self.lower_expr!(Vector(elems=chars, span~, ty~), scope~, env~)
    }
    FunCall(name="uint", args=[arg], ty~, span~, ..) => {
      let arg = self.lower_expr!(arg, scope~, env~)
      let arg_ref = arg.as_ref!(self, scope~)
      let width = unwrap_type!(ty, span~).width!(span)
      Expr(expr=flat_uint!(arg_ref, arg.ty(), span~), ty=UInt(width), span~)
    }
    Spread(_) | Ternary(_) | Replicate(_) | FunCall(_) | If(_) => {
      raise UnexpectedExprDuringElaboration(span=expr.span())
    }
  }
}

pub fn lower(self: Elaborator, decls: Iter[@parse.Decl]) -> Unit! {
  for decl in decls {
    match decl {
      Module(mod) => {
        self.lower_module!(mod)
      }
      ModuleDeclaration(sig) => {
        self.declared_modules[sig.path] = sig
      }
      Const(_) | Package(_) | Import(_) => ()
    }
  }
}

struct PortSignature {
  direction: @parse.PortDirection
  ty: @firrtl.Type
}

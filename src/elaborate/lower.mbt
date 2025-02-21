
pub struct Elaborator {
  mut autoidx: Int
  circuit_name: String
  modules: Map[@parse.Path, @firrtl.Module]
  annotations: Array[Json]
  declared_modules: Map[@parse.Path, @parse.ModuleSignature]
  current_target: Array[String]
  memories: Map[String, @firrtl.Id]
  mut current_clock: @firrtl.Expr?
}

pub fn Elaborator::new(circuit_name: String) -> Elaborator {
  {
    circuit_name,
    autoidx: 0,
    modules: {},
    annotations: [],
    declared_modules: {},
    current_target: [circuit_name],
    memories: {},
    current_clock: None
  }
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
  UnknownModuleMarkedAsInternal(path~: @parse.Path, span~: @parse.Span)
  Unsupported(message~: String, span~: @parse.Span)
  DynamicIntParam(span~: @parse.Span)
  InvalidCharacterInString(char~: Char, span~: @parse.Span)
  ExpctedIntLiteral(span~: @parse.Span)
  InvalidMemoryReferenceInLoadMemory(mem_name~: String, span~: @parse.Span)
  InvalidMaskType(expected~: @firrtl.Type, got~: @firrtl.Type, span~: @parse.Span)
  NoClockFound(message~: String, span~: @parse.Span)
  InvalidAttribute(name~: String, span~: @parse.Span)
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
    Nat(min_width=_) => UIntInferred
    UInt(Fixed(width)) => UInt(width)
    SInt(Fixed(width)) => SInt(width)
    Clock => Clock
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

fn default_value(ty: @firrtl.Type, span~: @parse.Span) -> Value! {
  match ty {
    Const(sub_ty) => default_value!(sub_ty, span~)
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
        elems.push(default_value!(elem_ty, span~))
      }

      Vector(elems~, ty~, span~)
    }
    Bundle(fields) => {
      let values = Map::new(capacity=fields.length())

      for field in fields {
        values[field.id.inner()] = default_value!(field.ty, span~)
      }

      Struct(fields=values, ty~, span~)
    }
    UIntInferred | SIntInferred => raise ElaborationError::Unsupported(message="Cannot get init value of inferred integer type", span~)
  }
}

fn default_mask(ty: @firrtl.Type, span~: @parse.Span) -> Value {
  match ty {
    Const(ty) => default_mask(ty, span~)
    Clock | Reset | AsyncReset | UInt(_) | SInt(_) | UIntInferred | SIntInferred => {
      Value::Expr(expr=Literal(UInt(width=1, radix=Some(2), value=1)), ty=UInt(1), span~)
    }
    Vec(elem_ty, len) => {
      Vector(elems=@utils.fill(len, default_mask(elem_ty, span~)), ty~, span~)
    }
    Bundle(fields) => {
      let values = Map::new(capacity=fields.length())

      for field in fields {
        values[field.id.inner()] = default_mask(field.ty, span~)
      }

      Struct(fields=values, ty~, span~)
    }
  }
}

fn lower_module(self: Elaborator, mod: @parse.ModuleDecl) -> Unit! {
  let env = ElaboratorEnv::new()
  self.current_target.push(String::concat([..mod.path.packages, mod.path.member], separator="_"))
  self.current_clock = None

  let fir_mod: @firrtl.Module = {
    public: true,
    id: id_of_path(mod.path),
    ports: {
      let ports = Array::new(capacity=mod.ports.length())

      for port in mod.ports {
        let fir_ty = lower_type!(port.ty, span=port.span)
        let port_id = id_of_str(port.name)

        // the first clock port is the module's default clock
        if fir_ty == Clock && self.current_clock.is_empty() {
          self.current_clock = Some(Reference(Id(port_id)))
        }

        let fir_port: @firrtl.Port = {
          direction: port.direction,
          id: port_id,
          ty: fir_ty,
        }
        
        ports.push(fir_port)
        env.declare!(@parse.Path::new([], port.name), Expr(expr=@firrtl.Reference(Id(port_id)), ty=fir_ty, span=port.span))
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
          "target": String::concat(self.current_target, separator=".").to_json(),
        })
      }
      { name: "flatten", args: [], .. } => {
        self.annotations.push({
          "class": "firrtl.transforms.FlattenAnnotation",
          "target": String::concat(self.current_target, separator=".").to_json(),
        })
      }
      { name: "internal", args: [], .. } => ()
      { span, .. } => {
        raise ElaborationError::InvalidAttribute(name=attr.name, span~)
      }
    }
  }

  for stmt in mod.body {
    self.lower_stmt!(stmt, scope=fir_mod, env~)
  }

  let _ = self.current_target.pop()
}

fn unwrap_type(ty: Ref[@parse.Type?], span~: @parse.Span) -> @parse.Type!ElaborationError {
  ty.val.or_error!(UntypedValue(span~))
}

fn next_id(self: Elaborator) -> Int {
  let idx = self.autoidx
  self.autoidx += 1
  idx
}

fn expr_as_ref(self: Elaborator, expr: @firrtl.Expr, scope~: &ScopeLike, binding~: String? = None) -> @firrtl.Reference {
  match expr {
    Reference(value) => value
    _ => {
      let prefix = binding.or("temp")
      let rhs_id = id_of_str("\{prefix}_\{self.next_id()}")
      scope.add_stmt(Node(id=rhs_id, expr~))
      Id(rhs_id)
    }
  }
}

fn expr_as_id(self: Elaborator, expr: @firrtl.Expr, scope~: &ScopeLike, binding~: String? = None) -> @firrtl.Id {
  match expr {
    Reference(Id(id)) => id
    _ => {
      let prefix = binding.or("temp")
      let rhs_id = id_of_str("\{prefix}_\{self.next_id()}")
      scope.add_stmt(Node(id=rhs_id, expr~))
      rhs_id
    }
  }
}

fn Value::as_ref(self: Value, elaborator: Elaborator, scope~: &ScopeLike, binding~: String? = None) -> @firrtl.Reference! {
  let expr = self.as_expr!(elaborator, scope~, binding~)
  elaborator.expr_as_ref(expr, scope~, binding~)
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

fn get_clock(self: Elaborator, source~: String, span~: @parse.Span) -> @firrtl.Expr! {
  self.current_clock.or_error!(NoClockFound(message="No clock found in current module for \{source}", span~))
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
    Vector(elems~, ty~, span=_) => {
      let id = id_of_str("vec_\{elaborator.next_id()}")
      scope.add_stmt(Wire(id~, ty~))
      for i, elem in elems {
        let index = @firrtl.Expr::Int(BigInt::from_int(i))
        elaborator.connect!(lhs=Indexing(lhs=Id(id), index~), value=elem, scope~)
      }

      Reference(Id(id))
    }
    Struct(fields~, ty~, span=_) => {
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

fn flatten_int(reference: @firrtl.Reference, ty: @firrtl.Type, span~: @parse.Span) -> @firrtl.Expr! {
  match ty {
    Const(inner_ty) => flatten_int!(reference, inner_ty, span~)
    Vec(elem_ty, len) => {
      let refs = Array::new(capacity=len)

      for i in 0..<len {
        // reverse the bits so that vec[0] becomes the most significant bit in a uint or sint
        let index = @firrtl.Expr::Int(BigInt::from_int(len - i - 1))
        let r = @firrtl.Reference::Indexing(lhs=reference, index~)
        refs.push(flatten_int!(r, elem_ty, span~))
      }

      concat!(refs)
    }
    Bundle(fields) => {
      let refs = Array::new(capacity=fields.length())

      for field in fields {
        let r = @firrtl.Reference::FieldAccess(lhs=reference, field=field.id)
        refs.push(flatten_int!(r, field.ty, span~))
      }

      concat!(refs)
    }
    UInt(_) => Reference(reference)
    SInt(_) => Reference(reference)
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
    Assign(lhs~, rhs~, span=_) => {
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
        Andr => Andr
        Orr => Orr
        Xorr => Xorr
      }

      Expr(expr=@firrtl.primop(primop, [fir_expr]), ty~, span~)
    }
    Binary(op~, lhs~, rhs~, output_width~, span~, ty=bin_ty) => {
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


      if output_width.val is Some(output_width) {
        let width = unwrap_type!(bin_ty, span~).width!(span)
        if width < output_width {
          res = @firrtl.primop(Bits, [res, @firrtl.Expr::Int(BigInt::from_int(output_width - 1)), @firrtl.Expr::Int(BigInt::from_int(0))])
        } else if width > output_width {
          raise Failure("Implicit widening is not allowed")
        }
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
                  let index = @firrtl.Expr::Int(BigInt::from_int(i))
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
      if params.params.length() > 0 && not(self.declared_modules.contains(path)) {
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
            let params_map = params.as_map!(names=sig.params.map(fn(p) { p.name }))
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
        fn get_param(name: String) -> @parse.InstanceParam! {
          match params_map[name] {
            Some(param) => param
            None => raise UnknownModuleParameter(name~, span~)
          }
        }

        match path {
          { packages: [], member: "Reg" | "RegAsyncReset" as internal_module_name } => {
            let reg_ty = match get_param!("T") {
              Type(value=ty, ..) => lower_type!(ty, span~)
              _ => raise ElaborationError::Unreachable(message="non-type parameter in Reg instance", span~)
            }

            let sync_reset = internal_module_name == "Reg"
            let uses_rst = uses_port("rst")
            let uses_en = uses_port("en")
            let reg_id = id_of_str("reg_\{self.next_idx()}")
            let clk = get_port("clk")

            let reg_stmt = if uses_rst {
              let init = default_value!(reg_ty, span~).as_expr!(self, scope~)

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
                init~,
              )
            } else {
              @firrtl.Stmt::Reg(
                id=reg_id,
                ty=reg_ty,
                clock=clk,
              )
            }

            scope.add_stmt(reg_stmt)

            let d_ref = Value::Expr(expr=get_port("d"), ty=reg_ty, span~).as_ref!(self, scope~)

            if uses_port("q") {
              match connections["q"] {
                Some(expr) => {
                  let q_ref = Value::Expr(expr~, ty=reg_ty, span~).as_ref!(self, scope~)
                  scope.add_stmt(Connect(q_ref, Reference(Id(reg_id))))
                }
                None => ()
              }

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

              if uses_port("q") {
                // connect d to q by default
                scope.add_stmt(Connect(
                  FieldAccess(lhs=Id(inst_name), field=id_of_str("d")),
                  Reference(FieldAccess(lhs=Id(inst_name), field=id_of_str("q")))
                ))
              }
            }
          }
          { packages: [], member: "Memory" } => {
            let data_type = lower_type!(get_param!("T").as_type!(), span~)
            let depth = get_param!("Depth").as_int!()
            let read_ports = get_param!("ReadPorts").as_int!()
            let write_ports = get_param!("WritePorts").as_int!()

            let mem_id = id_of_str("mem_\{self.next_idx()}")
            
            match binding {
              Some(name) => {
                self.memories[name] = mem_id
              }
              None => ()
            }

            let readers = {
              let readers = Array::new(capacity=read_ports)

              for i in 0..<read_ports {
                readers.push(id_of_str(mem_id.inner() + "_reader\{i}"))
              }

              readers
            }

            let writers = {
              let writers = Array::new(capacity=write_ports)

              for i in 0..<write_ports {
                writers.push(id_of_str(mem_id.inner() + "_writer\{i}"))
              }

              writers
            }

            let read_latency = if params_map.contains("ReadLatency") {
              get_param!("ReadLatency").as_int!()
            } else {
              1
            }

            let write_latency = if params_map.contains("WriteLatency") {
              get_param!("WriteLatency").as_int!()
            } else {
              1
            }

            let mem_stmt = @firrtl.Mem(
              id=mem_id,
              data_type~,
              depth~,
              read_latency~,
              write_latency~,
              read_under_write=Undefined,
              readers~,
              writers~,
              readwriters=[],
            )

            scope.add_stmt(mem_stmt)

            let data_out = Array::new(capacity=read_ports)

            {
              let ports = self.expr_as_ref(get_port("read"), scope~)

              for i in 0..<read_ports {
                let reader = @firrtl.Indexing(lhs=ports, index=Int(BigInt::from_int(i)))
                let reader_id = @firrtl.FieldAccess(lhs=Id(mem_id), field=readers[i])
                scope.add_stmt(Connect(FieldAccess(lhs=reader_id, field=id_of_str("addr")), Reference(FieldAccess(lhs=reader, field=id_of_str("addr")))))
                scope.add_stmt(Connect(FieldAccess(lhs=reader_id, field=id_of_str("en")), Reference(FieldAccess(lhs=reader, field=id_of_str("en")))))
                scope.add_stmt(Connect(FieldAccess(lhs=reader_id, field=id_of_str("clk")), Reference(FieldAccess(lhs=reader, field=id_of_str("clk")))))
                data_out.push(@firrtl.FieldAccess(lhs=reader_id, field=id_of_str("data")))
              }
            }

            {
              let ports = self.expr_as_ref(get_port("write"), scope~)

              for i in 0..<write_ports {
                let writer = @firrtl.Indexing(lhs=ports, index=Int(BigInt::from_int(i)))
                let writer_id = @firrtl.FieldAccess(lhs=Id(mem_id), field=writers[i])
                scope.add_stmt(Connect(FieldAccess(lhs=writer_id, field=id_of_str("addr")), Reference(FieldAccess(lhs=writer, field=id_of_str("addr")))))
                scope.add_stmt(Connect(FieldAccess(lhs=writer_id, field=id_of_str("en")), Reference(FieldAccess(lhs=writer, field=id_of_str("en")))))
                scope.add_stmt(Connect(FieldAccess(lhs=writer_id, field=id_of_str("clk")), Reference(FieldAccess(lhs=writer, field=id_of_str("clk")))))
                scope.add_stmt(Connect(FieldAccess(lhs=writer_id, field=id_of_str("data")), Reference(FieldAccess(lhs=writer, field=id_of_str("data")))))
                scope.add_stmt(Connect(FieldAccess(lhs=writer_id, field=id_of_str("mask")), Reference(FieldAccess(lhs=writer, field=id_of_str("mask")))))
                let mask_ty = lower_type!(get_param!("Mask").as_type!(), span~)

                if mask_ty != data_type.mask() {
                  raise InvalidMaskType(expected=data_type.mask(), got=mask_ty, span~)
                }
              }
            }

            let q = self.expr_as_ref(get_port("q"), scope~)

            for i, data in data_out {
              let index = @firrtl.Expr::Int(BigInt::from_int(i))
              scope.add_stmt(Connect(@firrtl.Reference::Indexing(lhs=q, index~), Reference(data)))
            }
          }
          _ => raise UnknownModuleMarkedAsInternal(path~, span~)
        }
      } else {
        let inst_id = id_of_str("inst_\{self.next_idx()}")
        scope.add_stmt(Inst(id=inst_id, of=id_of_path(path)))

        for port_name, sig in ports_sig {
          if uses_port(port_name) {
            let lhs = Expr(expr=Reference(FieldAccess(lhs=Id(inst_id), field=id_of_str(port_name))), ty=sig.ty, span~)
            let rhss = Array::new(capacity=2)

            if accessed_ports.contains(port_name) {
              rhss.push(Expr(expr=Reference(FieldAccess(lhs=Id(inst_name), field=id_of_str(port_name))), ty=sig.ty, span~))
            }
            
            if inline_connections.contains(port_name) {
              rhss.push(Expr(expr=get_port(port_name), ty=sig.ty, span~))
            }

            for rhs in rhss {
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
        Vec(elem_ty, _) => {
          let slice_len = (hi + 1 - lo).to_int()
          let elems = Array::new(capacity=slice_len)
          let lhs = val.as_ref!(self, scope~)

          for i in lo.to_int()..=hi.to_int() {
            let index = @firrtl.Expr::Int(BigInt::from_int(i))
            elems.push(Expr(expr=Reference(Indexing(lhs~, index~)), ty=elem_ty, span~))
          }

          Vector(elems~, ty=Vec(elem_ty, slice_len), span~)
        }
        ty => raise ElaborationError::Unsupported(message="Slicing is not support on value of type '\{ty}'", span~)
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
    FunCall(name="uint" | "sint" as name, args=[arg], ty~, span~, ..) => {
      let arg = self.lower_expr!(arg, scope~, env~)
      let arg_ref = arg.as_ref!(self, scope~)
      let ty = unwrap_type!(ty, span~)
      let fir_ty = lower_type!(ty, span~)

      match (name, arg.ty()) {
        ("uint", Vec(_)) => Expr(expr=flatten_int!(arg_ref, arg.ty(), span~), ty=fir_ty, span~)
        ("sint", Vec(_)) => {
          let flattened = flatten_int!(arg_ref, arg.ty(), span~)
          Expr(expr=@firrtl.primop(AsSInt, [flattened]), ty=fir_ty, span~)
        }
        ("uint", UInt(_) | AsyncReset | Reset) | ("sint", SInt(_)) => arg
        ("uint", SInt(_)) => Expr(expr=@firrtl.primop(AsUInt, [arg.as_expr!(self, scope~)]), ty=fir_ty, span~)
        ("uint", Clock) => Expr(expr=@firrtl.primop(AsUInt, [arg.as_expr!(self, scope~)]), ty=fir_ty, span~)
        ("sint", UInt(_)) => Expr(expr=@firrtl.primop(AsSInt, [arg.as_expr!(self, scope~)]), ty=fir_ty, span~)
        _ => raise ElaborationError::Unsupported(message="Cannot convert type '\{arg.ty()}' to UInt or SInt", span~)
      }
    }
    FunCall(name="clock", args=[clk], span~, ..) => {
      let clk = self.lower_expr!(clk, scope~, env~)
      let clk_ref = clk.as_ref!(self, scope~)

      Expr(expr=@firrtl.primop(AsClock, [Reference(clk_ref)]), ty=Clock, span~)
    }
    FunCall(name="$readmemb" | "$readmemh" as name, args=[path, mem], span~, ..) => {
      let path = path.expect_string!()
      let mem_ref = self.lower_expr!(mem, scope~, env~).as_ref!(self, scope~)
      let mem_name = match mem_ref {
        Id(id) => id.inner()
        _ => raise ElaborationError::Unsupported(message="Cannot reference indirect memory inside \{name}", span~)
      }

      let mem_id = match self.memories[mem_name] {
        Some(id) => id.inner()
        None => raise InvalidMemoryReferenceInLoadMemory(mem_name~, span~)
      }

      let annotation = {
        "class": "firrtl.annotations.MemoryFileInlineAnnotation",
        "target": String::concat([..self.current_target, mem_id], separator="."),
        "filename": path,
        "hexOrBinary": if name == "$readmemh" { "h" } else { "b" },
        "originalMemoryNameOpt": mem_id,
      }

      self.annotations.push(annotation.to_json())
      Empty(span~)
    }
    FunCall(name="$printf", args=[fmt, ..args], span~, ..) => {
      let fmt = fmt.expect_string!()
      let new_args = Array::new(capacity=args.length())

      for arg in args {
        new_args.push(self.lower_expr!(arg, scope~, env~).as_expr!(self, scope~))
      }

      let clk = self.get_clock!(source="$printf", span~)
      let cond = @firrtl.Expr::Literal(UInt(width=1, radix=Some(2), value=BigInt::from_int(1)))
 
      scope.add_stmt(Command(Printf(clk~, cond~, fmt~, args=new_args)))
      Empty(span~)
    }
    FunCall(name="$stop", args~, span~, ..) => {
      let clk = self.get_clock!(source="$stop", span~)
      let cond = @firrtl.Expr::Literal(UInt(width=1, radix=Some(2), value=BigInt::from_int(1)))
      let code = match args {
        [] => 0
        [code] => self.lower_expr!(code, scope~, env~).as_int!().to_int()
        _ => raise Failure("Unexpected number of arguments to $stop")
      }

      scope.add_stmt(Command(Stop(clk~, cond~, code~)))
      Empty(span~)
    }
    FunCall(name="$flip", args=[arg], span~, ty~, ..) => {
      let arg = self.lower_expr!(arg, scope~, env~)
      let arg_ref = arg.as_ref!(self, scope~)
      let width = unwrap_type!(ty, span~).width!(span)
      let bits = Array::new(capacity=width)

      for i in 0..<width {
        let index = @firrtl.Expr::Int(BigInt::from_int(width - 1 - i))
        bits.push(@firrtl.primop(Bits, [Reference(arg_ref), index, index]))
      }

       Value::Expr(expr=concat!(bits), ty=UInt(width), span~)
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

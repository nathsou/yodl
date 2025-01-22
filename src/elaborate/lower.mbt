
pub struct Lowerer {
  mut autoidx: Int
  modules: Map[@parse.Path, @yir.Module]
  declared_modules: Map[@parse.Path, @parse.ModuleSignature]
}

pub fn Lowerer::new() -> Lowerer {
  { autoidx: 0, modules: {}, declared_modules: {} }
}

fn next_idx(self: Lowerer) -> Int {
  let idx = self.autoidx
  self.autoidx += 1
  idx
}

priv enum Val {
  Expr(expr~: @yir.Expr, span~: @parse.Span)
  Vector(elems~: Array[Val], span~: @parse.Span)
  Struct(fields~: Map[String, Val], span~: @parse.Span)
}

impl @parse.Spanned for Val with span(self) {
  match self { 
    Expr(span~, ..) | Vector(span~, ..) | Struct(span~, ..) => span
  }
}

fn Val::width(self: Val) -> Int {
  match self {
    Expr(expr~, ..) => expr.width()
    Vector(elems~, ..) => @utils.sum(elems.iter().map(Val::width))
    Struct(fields~, ..) => @utils.sum(fields.values().map(Val::width))
  }
}

fn Val::ctor(self: Val) -> String {
  match self {
    Expr(..) => "Expr"
    Vector(..) => "Vector"
    Struct(..) => "Struct"
  }
}

fn Val::as_expr(self: Val) -> @yir.Expr {
  match self {
    Expr(expr~, ..) => expr
    Vector(elems~, span~) => Concat(elems=elems.map(Val::as_expr), width=self.width(), span~)
    Struct(fields~, span~) => {
      let elems = Array::new(capacity=fields.size())
      let sorted_keys = { let keys = fields.keys().collect(); keys.sort(); keys }

      for field in sorted_keys {
        elems.push(fields[field].unwrap().as_expr())
      }

      Concat(elems~, width=self.width(), span~)
    }
  }
}

fn Val::expect_const(self: Val) -> @yir.Const!LoweringError {
  match self {
    Expr(expr=Const(value~, ..), ..) => value
    _ => raise ExpectedConst(span=self.span())
  }
}

typealias LowerEnv = Scope[@parse.Path, Val]

pub type! LoweringError {
  UnexpectedStmtDuringElaboration(span~: @parse.Span)
  UnexpectedExprDuringElaboration(span~: @parse.Span)
  UntypedValue(span~: @parse.Span)
  ExpectedConst(span~: @parse.Span)
  ParametricInstanceDuringElaboration(span~: @parse.Span)
  Unreachable(message~: String, span~: @parse.Span)
} derive (Show)

trait ModuleLike {
  add_stmt(Self, @yir.Stmt) -> Unit
}

impl ModuleLike for @yir.Module with add_stmt(self, stmt) {
  self.body.push(stmt)
}

type StmtContainer Array[@yir.Stmt]

impl ModuleLike for StmtContainer with add_stmt(self, stmt) {
  self._.push(stmt)
}

fn lower_module(self: Lowerer, mod: @parse.ModuleDecl) -> Unit! {
  let env = LowerEnv::new()

  let yir_mod: @yir.Module = {
    name: mod.path.to_string(),
    ports: {
      let ports = Array::new(capacity=mod.ports.length())

      for port in mod.ports {
        let width = port.ty.width!(mod.span)
        let span = port.span

        let yir_port: @yir.Port = {
          name: port.name,
          width,
          direction: port.direction,
          span,
        }
        
        ports.push(yir_port)
        env.declare!(@parse.Path::new([], port.name), Expr(expr=Variable(name=port.name, width~, span~), span~))
      }

      ports
    },
    body: [],
    span: mod.span,
  }

  self.modules[mod.path] = yir_mod

  for stmt in mod.body {
    self.lower_stmt!(stmt, mod=yir_mod, env~)
  }
}

fn lower_stmt(self: Lowerer, stmt: @parse.Stmt, mod~: &ModuleLike, env~: LowerEnv) -> Unit! {
  match stmt {
    Expr(expr~, span~) => {
      let yir_expr = self.lower_expr!(expr, mod~, env~, binding=None).as_expr()
      mod.add_stmt(Expr(expr=yir_expr, span~))
    }
    Let(name~, ty~, expr~, span~) => {
      let path = @parse.Path::new([], name)
      let width = get_width!(ty, span~)
      let val = match expr {
        Some(expr) => Some(self.lower_expr!(expr, mod~, env~, binding=Some(name)))
        None => None
      }
      
      env.declare!(path, Expr(expr=Variable(name~, width~, span~), span~))
      mod.add_stmt(Wire(name~, width~, span~))

      match val {
        Some(val) => {
          match val {
            Expr(expr~, span~) => {
              mod.add_stmt(Wire(name~, width~, span~))
              mod.add_stmt(Assign(lhs=Variable(name~, width~, span~), rhs=expr, span~))
            }
            Vector(_) | Struct(_) as val => {
              env.declare!(path, val)
            }
          }
        }
        None => {
          let ty = ty.val.or_error!(UntypedLet(span~))
          let val = self.default_value!(ty~, mod~, env~, span~, name_binding=name)
          env.declare!(path, val)
        }
      }
    }
    Assign(lhs~, rhs~, span~) => {
      let yir_lhs = self.lower_expr!(lhs, mod~, env~, binding=None).as_expr()
      let yir_rhs = self.lower_expr!(rhs, mod~, env~, binding=None).as_expr()
      mod.add_stmt(Assign(lhs=yir_lhs, rhs=yir_rhs, span~))
    }
    Procedural(body~, span~) => {
      let yir_body: StmtContainer = []
      let process_env = env.child()

      for stmt in body {
        self.lower_stmt!(stmt, mod=yir_body, env=process_env)
      }

      mod.add_stmt(Process(triggers=All, body=yir_body._, span~))
    }
    Const(_) | For(_) | Scope(_) => {
      raise UnexpectedStmtDuringElaboration(span=stmt.span())
    }
  }
}

fn get_width(ty: Ref[@parse.Type?], span~: @parse.Span) -> Int! {
  ty.val.or_error!(UntypedValue(span~)).width!(span)
}

fn lower_expr(self: Lowerer, expr: @parse.Expr, mod~: &ModuleLike, env~: LowerEnv, binding~: String? = None) -> Val! {
  match expr {
    Natural(bits~, width~, base~, span~, ty=_) => {
      let width = match width {
        Some(width) => width
        None => 32
      }

      let yir_const: @yir.Const = {
        bits,
        width,
        base: match base {
          2 => Bin
          8 => Oct
          10 => Dec
          16 => Hex
          _ => raise Failure("invalid base")
        },
        span,
      }
      
      Expr(expr=Const(value=yir_const, span~), span~)
    }
    Identifier(path~, ..) => {
      match env.resolve(path) {
        Some(val) => val
        None => raise Failure("unresolved identifier '\{path}'")
      }
    }
    Unary(op~, expr~, span~, ty~) => {
      let yir_expr = self.lower_expr!(expr, mod~, env~).as_expr()
      let width = get_width!(ty, span~)
      Expr(expr=Unary(op~, expr=yir_expr, width~, span~), span~)
    }
    Binary(op~, lhs~, rhs~, span~, ty~) => {
      let yir_lhs = self.lower_expr!(lhs, mod~, env~).as_expr()
      let yir_rhs = self.lower_expr!(rhs, mod~, env~).as_expr()
      let width = get_width!(ty, span~)
      Expr(expr=Binary(op~, lhs=yir_lhs, rhs=yir_rhs, width~, span~), span~)
    }
    Vector(elems~, span~, ty=_) => {
      let values = Array::new(capacity=elems.length())

      for elem in elems {
        match elem {
          Spread(expr=spread_expr, ..) => {
            let val = self.lower_expr!(spread_expr, mod~, env~)

            match val {
              Vector(elems=values, ..) => {
                for value in values {
                  values.push(value)
                }
              }
              _ => values.push(val)
            }
          }
          _ => {
            values.push(self.lower_expr!(elem, mod~, env~))
          }
        }
      }

      Vector(elems=values, span~)
    }
    Match(subject~, cases~, default~, span~, ty~) => {
      let width = get_width!(ty, span~)
      let yir_subject = self.lower_expr!(subject, mod~, env~).as_expr()
      let yir_cases = Array::new(capacity=cases.length())

      for case in cases {
        let (lhs, rhs) = case
        let yir_lhs = self.lower_expr!(lhs, mod~, env~).expect_const!()
        let yir_rhs = self.lower_expr!(rhs, mod~, env~).as_expr()
        yir_cases.push((yir_lhs, yir_rhs))
      }
      
      let yir_default = match default {
        Some(expr) => Some(self.lower_expr!(expr, mod~, env~).as_expr())
        None => None
      }

      Expr(expr=Mux(subject=yir_subject, cases=yir_cases, default=yir_default, width~, span~), span~)
    }
    Tuple(elems~, span~, ty=_) => {
      let values = Array::new(capacity=elems.length())

      for elem in elems {
        values.push(self.lower_expr!(elem, mod~, env~))
      }

      Vector(elems=values, span~)
    }
    Struct(fields~, span~, ty=_) => {
      let val = Map::new(capacity=fields.size())
      let sorted_keys = { let keys = fields.keys().collect(); keys.sort(); keys }

      for field in sorted_keys {
        let field_expr = fields[field].unwrap()
        let field_name = binding.map(fn(name) { "\{name}.\{field}" })
        val[field] = self.lower_expr!(field_expr, mod~, env~, binding=field_name)
      }

      Val::Struct(fields=val, span~)
    }
    Instance(path~, params~, ports~, span~, ty=inst_ty) => {
      if params._.length() > 0 && not(self.declared_modules.contains(path)) {
        raise ParametricInstanceDuringElaboration(span~)
      }

      let (ports_sig, _params_map, _attributes) = match self.modules[path] {
        Some(inst_mod) => {
          let ports_sig = {}

          for wire in inst_mod.ports {
            ports_sig[wire.name] = (wire.width, wire.span, false)
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
              let width = port.ty.substitute(params_env).width!(port.span)
              ports_sig[port.name] = (width, port.span, port.optional)
            }

            (ports_sig, params_map, sig.attributes)
          }
          None => raise ElaboratorError::UnknownModule(path~, span~)
        }
      }

      let connections: Map[String, @yir.Expr] = {}
      let inline_connections: Map[String, @yir.Expr] = {}
      let accessed_ports = match inst_ty.val {
        Some(Instance(sig=_, params=_, accessed_ports~)) => accessed_ports
        _ => raise LoweringError::Unreachable(message="Untyped instance", span~)
      }

      let extra_ports = []
      let fields: Map[String, Val] = {}

      fn uses_port(port_name: String) -> Bool {
        ports.contains(port_name) || accessed_ports.contains(port_name)
      }

      let inst_name = binding.or_else(fn() { path.to_string() + "$\{self.next_idx()}" })

      for port_name, port_sig in ports_sig {
        let (width, span, optional) = port_sig
        let skip = optional && not(uses_port(port_name))

        if not(skip) {
          let wire_name = "\{inst_name}.\{port_name}"
          mod.add_stmt(Wire(name=wire_name, width~, span~))
          connections[port_name] = Variable(name=wire_name, width~, span~)

          if accessed_ports.contains(port_name) {
            fields[port_name] = Val::Expr(expr=Variable(name=wire_name, width~, span~), span~)
          }
        }
      }

      for port_name, expr in ports {
        if not(ports_sig.contains(port_name)) {
          extra_ports.push(port_name)
        }

        inline_connections[port_name] = self.lower_expr!(expr, mod~, env~).as_expr()
      }
      
      if not(extra_ports.is_empty()) {
        raise ExtraPorts(extra_ports~, span~)
      }

      let inst = @yir.Stmt::Instance(
        name=inst_name,
        module_name=path.to_string(),
        ports=connections,
        span=span,
      )

      mod.add_stmt(inst)

      Expr(expr=Variable(name=inst_name, width=get_width!(inst_ty, span~), span~), span~)
    }
    Indexing(expr~, index~, span=_, ty=_) => {
      let val = self.lower_expr!(expr, mod~, env~)
      let idx = self.lower_expr!(index, mod~, env~).expect_const!().bits.as_int!()

      match val {
        Expr(expr~, span~) => {
          let width = expr.width()
          if idx > width {
            raise LoweringError::Unreachable(message="Index out of bounds, width: \{width}, index: \{idx}", span~)
          }

          Expr(expr=Select(expr~, offset=idx, width=1, span~), span~)
        }
        Vector(elems~, span~) => {
          let len = elems.length()

          if idx >= len {
            raise LoweringError::Unreachable(message="Index out of bounds, len: \{len}, index: \{idx}", span~)
          }
          
          elems[idx]
        }
        _ => raise Unsupported(message="Indexing on non-vector data type", span=expr.span())
      }
    }
    Slicing(expr~, msb~, lsb~, ..) => {
      let val = self.lower_expr!(expr, mod~, env~)
      let msb = msb.as_int!()
      let lsb = lsb.as_int!()

      match val {
        Expr(expr~, span~) => {
          let width = expr.width()
          
          if msb >= width || lsb >= width || msb < lsb {
            raise LoweringError::Unreachable(message="Slice out of bounds, width: \{width}, msb: \{msb}, lsb: \{lsb}", span~)
          }

          Expr(expr=Select(expr~, offset=lsb, width=msb - lsb + 1, span~), span~)
        }
        _ => raise Unsupported(message="Slicing on non-vector data type", span=expr.span())
      }
    }
    String(_) | Spread(_) | Ternary(_) | Replicate(_) | FunCall(_) | Block(_) => {
      raise UnexpectedExprDuringElaboration(span=expr.span())
    }
    FieldAccess(expr=accessed_expr, field~, span~, ..) => {
      let val = self.lower_expr!(accessed_expr, mod~, env~)

      match val {
        Struct(fields~, ..) => {
          match fields[field] {
            Some(value) => value
            None => raise ElaboratorError::Unreachable(message="Unknown struct field", span~)
          }
        }
        Expr(expr~, ..) => {
          let ty = accessed_expr.ty().val.or_error!(LoweringError::Unreachable(message="Untyped signal field access", span=accessed_expr.span()))

          match ty {
            Struct(fields) => {
              let sorted_keys = { let keys = fields.keys().collect(); keys.sort(); keys }
              let mut offset = expr.width() - 1

              for name in sorted_keys {
                let width = fields[field].unwrap().width!(span)

                if name == field {
                  return Expr(expr=Select(expr~, offset~, width~, span~), span~)
                }

                offset -= width
              }

              raise ElaboratorError::Unreachable(message="Unknown struct field: \{field}", span~)
            }
            Instance(sig~, params~, accessed_ports~) => {
              let field_widths = {}
              let params_env = Map::from_iter(params.iter())

              for port in sig.ports {
                if accessed_ports.contains(port.name) {
                  let width = port.ty.substitute(params_env).width!(span)
                  field_widths[port.name] = width
                }
              }

              let sorted_keys = { let keys = field_widths.keys().collect(); keys.sort(); keys }
              let mut offset = @utils.sum(field_widths.values()) - 1

              for name in sorted_keys {
                let width = field_widths[field].unwrap()

                if name == field {
                  return Expr(expr=Select(expr~, offset~, width~, span~), span~)
                }

                offset -= width
              }

              raise ElaboratorError::Unreachable(message="Unknown instance field: \{field}", span~)
            }
            _ => raise Unsupported(message="Field access on non-struct type: \{ty}", span~)
          }
        }
        _ => {
          raise Unsupported(message="Invalid field access on value of type: \{val.ctor()}", span~)
        }
      }
    }
  }
}

pub fn lower(self: Lowerer, decls: Iter[@parse.Decl]) -> Unit! {
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

fn default_value(
  self: Lowerer,
  ty~: @parse.Type,
  mod~: &ModuleLike,
  env~: LowerEnv,
  span~: @parse.Span,
  name_binding~: String
) -> Val! {
  match ty {
    Nat => Val::Expr(expr=Const(value=@yir.Const::xs(32, span), span~), span~)
    Logic => Val::Expr(expr=Const(value=@yir.Const::xs(1, span), span~), span~) 
    Vector(ty~, len~) => match ty {
      Logic => {
        let width = len.expect_fixed!(span)
        mod.add_stmt(Wire(name=name_binding, width~, span~))
        Val::Expr(expr=Variable(name=name_binding, width~, span~), span~)
      }
      _ => {
        let len = len.expect_fixed!(span)
        let val = Array::new(capacity=len)

        for i in 0..<len {
          val.push(self.default_value!(ty~, mod~, env~, span~, name_binding=name_binding + "[\{i}]"))
        }

        Val::Vector(elems=val, span~)
      }
    }
    Instance(sig={ path, span, .. }, params~, accessed_ports=_) => {
      let inst = @parse.Expr::Instance(
        path~,
        params={
          let new_params: Array[@parse.InstanceParam] = Array::new(capacity=params.size())

          for name, param in params {
            new_params.push({ name: Some(name), value: param.as_expr!(span~) })
          }

          @parse.InstanceParams(new_params)
        },
        ports={},
        span~,
        ty={ val: Some(ty) },
      )

      self.lower_expr!(inst, mod~, env~, binding=Some(name_binding))
    }
    Name(_) => {
      raise UnresolvedType(span~)
    }
    Struct(fields) => {
      let val = Map::new(capacity=fields.size())

      for field, ty in fields {
        val[field] = self.default_value!(ty~, mod~, env~, span~, name_binding=name_binding + ".\{field}")
      }

      Val::Struct(fields=val, span~)
    }
    String(_) => {
      raise LoweringError::Unreachable(message="String type during elaboration", span~)
    }
  }
}

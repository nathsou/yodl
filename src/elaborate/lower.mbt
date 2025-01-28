
pub struct Elaborator {
  mut autoidx: Int
  modules: Map[@parse.Path, @yir.Module]
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
  Expr(expr~: @yir.Expr, span~: @parse.Span)
  Vector(elems~: Array[Value], span~: @parse.Span)
  Struct(fields~: Map[String, Value], span~: @parse.Span)
}

impl @parse.Spanned for Value with span(self) {
  match self { 
    Expr(span~, ..) | Vector(span~, ..) | Struct(span~, ..) => span
  }
}

fn Value::width(self: Value) -> Int {
  match self {
    Expr(expr~, ..) => expr.width()
    Vector(elems~, ..) => @utils.sum(elems.iter().map(Value::width))
    Struct(fields~, ..) => @utils.sum(fields.values().map(Value::width))
  }
}

fn Value::ctor(self: Value) -> String {
  match self {
    Expr(..) => "Expr"
    Vector(..) => "Vector"
    Struct(..) => "Struct"
  }
}

fn Value::as_expr(self: Value) -> @yir.Expr {
  match self {
    Expr(expr~, ..) => expr
    Vector(elems~, span~) => Concat(elems=elems.map(Value::as_expr), width=self.width(), span~)
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

fn Value::expect_const(self: Value) -> @yir.Const!ElaborationError {
  match self {
    Expr(expr=Const(value~, ..), ..) => value
    _ => raise ExpectedConst(span=self.span())
  }
}

typealias ElaboratorEnv = Scope[@parse.Path, Value]

pub type! ElaborationError {
  UnresolvedIdentifier(path~: @parse.Path, span~: @parse.Span)
  UnexpectedStmtDuringElaboration(span~: @parse.Span)
  UnexpectedExprDuringElaboration(span~: @parse.Span)
  UntypedValue(span~: @parse.Span)
  ExpectedConst(span~: @parse.Span)
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

fn lower_module(self: Elaborator, mod: @parse.ModuleDecl) -> Unit! {
  let env = ElaboratorEnv::new()

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

fn lower_stmt(self: Elaborator, stmt: @parse.Stmt, mod~: &ModuleLike, env~: ElaboratorEnv) -> Unit! {
  match stmt {
    Expr(expr~, span~) => {
      let yir_expr = self.lower_expr!(expr, mod~, env~, binding=None).as_expr()
      let is_empty_vec = match yir_expr {
        Concat(elems=[], ..) => true
        _ => false
      }

      if not(is_empty_vec) {
        mod.add_stmt(Expr(expr=yir_expr, span~))
      }
    }
    Let(name~, ty~, expr~, span~) => {
      let path = @parse.Path::new([], name)
      let width = get_width!(ty, span~)
      mod.add_stmt(Wire(name~, width~, span~))

      let val = match expr {
        Some(expr) => Some(self.lower_expr!(expr, mod~, env~, binding=Some(name)))
        None => None
      }
      
      let var = @yir.Expr::Variable(name~, width~, span~)

      match val {
        Some(val) => {
          mod.add_stmt(Assign(lhs=var, rhs=val.as_expr(), span~))

          match val {
            Struct(_) => {
              env.declare!(path, val)
            }
            _ => {
              env.declare!(path, Expr(expr=var, span~))
            }
          }
        }
        None => {
          env.declare!(path, Expr(expr=var, span~))
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

fn select(expr~: @yir.Expr, offset~: Int, width~: Int, span~: @parse.Span) -> @yir.Expr {
  if expr.width() == 1 {
    return expr
  }

  Select(expr~, offset~, width~, span~)
}

fn lower_expr(self: Elaborator, expr: @parse.Expr, mod~: &ModuleLike, env~: ElaboratorEnv, binding~: String? = None) -> Value! {
  match expr {
    Natural(bits~, width~, base~, span~, ty=_) => {
      let width = match width {
        Some(width) => width
        None => 32
      }

      let yir_const: @yir.Const = {
        bits,
        width,
        base,
      }
      
      Expr(expr=Const(value=yir_const, span~), span~)
    }
    Identifier(path~, span~, ..) => {
      match env.resolve(path) {
        Some(val) => val
        None => raise UnresolvedIdentifier(path~, span~)
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

      Value::Struct(fields=val, span~)
    }
    Instance(path~, params~, ports~, span~, ty=inst_ty) => {
      if params._.length() > 0 && not(self.declared_modules.contains(path)) {
        raise ParametricInstanceDuringElaboration(span~)
      }

      let (ports_sig, params_map, attributes) = match self.modules[path] {
        Some(inst_mod) => {
          let ports_sig = {}

          for wire in inst_mod.ports {
            ports_sig[wire.name] = {
              width: wire.width,
              direction: wire.direction,
              optional: false,
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
              let width = port.ty.substitute(params_env).width!(port.span)
              ports_sig[port.name] = {
                width,
                direction: port.direction,
                optional: false,
              }
            }

            (ports_sig, params_map, sig.attributes)
          }
          None => raise ElaborationError::UnknownModule(path~, span~)
        }
      }

      let connections: Map[String, @yir.Expr] = {}
      let inline_connections: Map[String, @yir.Expr] = {}
      let accessed_ports = match inst_ty.val {
        Some(Instance(sig=_, params=_, accessed_ports~)) => accessed_ports
        _ => raise ElaborationError::Unreachable(message="Untyped instance", span~)
      }

      let extra_ports = []
      let fields: Map[String, Value] = {}

      fn uses_port(port_name: String) -> Bool {
        ports.contains(port_name) || accessed_ports.contains(port_name)
      }

      let inst_name = binding.or_else(fn() { path.to_string() + "$\{self.next_idx()}" })

      for port_name, port_sig in ports_sig {
        let skip = port_sig.optional && not(uses_port(port_name))

        if not(skip) {
          let wire_name = "\{inst_name}.\{port_name}"
          mod.add_stmt(Wire(name=wire_name, width=port_sig.width, span~))
          connections[port_name] = Variable(name=wire_name, width=port_sig.width, span~)

          if accessed_ports.contains(port_name) {
            fields[port_name] = Value::Expr(expr=Variable(name=wire_name, width=port_sig.width, span~), span~)
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

      let inst = if attributes.contains("internal") {
        fn get_port(port_name: String) -> @yir.Expr! {
          match connections[port_name] {
            Some(expr) => expr
            None => raise ElaborationError::UnknownModulePort(module_path=path, port_name~, span~)
          }
        }

        fn get_param(name: String) -> @parse.Expr! {
          match params_map[name] {
            Some(param) => param
            None => raise UnknownModuleParameter(name~, span~)
          }
        }

        match path {
          { packages: [], member: "Reg" | "RegSyncReset" as internal_module_name } => {
            let width = get_param!("Width").as_int!()
            let sync_reset = internal_module_name == "RegSyncReset"
            let uses_rst = uses_port("rst")
            let uses_en = uses_port("en")
            
            @yir.Stmt::Reg(
              width~,
              async_reset=not(sync_reset),
              clk=get_port!("clk"),
              data_in=get_port!("d"),
              enable=if uses_en { Some(get_port!("en")) } else { None },
              reset=if uses_rst { Some(get_port!("rst")) } else { None },
              data_out=get_port!("q"),
              span~,
            )
          }
          { packages: [], member: "Memory" } => {
            let width = get_param!("Width").as_int!()
            let depth = get_param!("Depth").as_int!()
            let read_ports = get_param!("ReadPorts").as_int!()
            let write_ports = get_param!("WritePorts").as_int!()
            let clamped_write_ports = @utils.max(write_ports, 1)
            let abits = @utils.clog2(depth + 1)

            let init = match params_map["Init"] {
              Some(Natural(bits~, width=Some(init_width), ..)) => {
                if init_width != depth * width {
                  raise InvalidMemoryInitValue(
                    span~,
                    expected_size=depth * width,
                    actual_size=Some(init_width),
                  )
                }

                bits
              }
              _ => raise InvalidMemoryInitValue(
                span~,
                expected_size=depth * width,
                actual_size=None,
              )
            }

            let uses_data_in = uses_port("data_in")
            let uses_write_enable = uses_port("write_enable")
            let uses_write_addr = uses_port("write_addr")
            let is_writeable = uses_data_in || uses_write_enable || uses_write_addr

            if is_writeable && not(uses_data_in && uses_write_enable && uses_write_addr) {
              let missing_connections = []

              if not(uses_data_in) {
                missing_connections.push("data_in")
              }

              if not(uses_write_enable) {
                missing_connections.push("write_enable")
              }

              if not(uses_write_addr) {
                missing_connections.push("write_addr")
              }

              raise MissingConnectionsOnWriteableMemoryInstance(missing_connections~, span~)
            }

            let read_addrs = Array::new(capacity=read_ports)

            for i in 0..<read_ports {
              read_addrs.push(select(
                expr=get_port!("read_addr"),
                offset=(read_ports - i) * abits - 1,
                width=abits,
                span~,
              ))
            }

            let write_addrs = Array::new(capacity=clamped_write_ports)

            for i in 0..<write_ports {
              write_addrs.push(select(
                expr=get_port!("write_addr"),
                offset=(write_ports - i) * abits - 1,
                width=abits,
                span~,
              ))
            }

            let write_enables = if uses_write_enable {
              let write_enables = Array::new(capacity=write_ports)

              for i in 0..<write_ports {
                write_enables.push(select(
                  expr=get_port!("write_enable"),
                  offset=i,
                  width=1,
                  span~,
                ))
              }

              Some(write_enables)
            } else {
              None
            }

            let data_ins = Array::new(capacity=clamped_write_ports)

            for i in 0..<clamped_write_ports {
              data_ins.push(select(
                expr=get_port!("data_in"),
                offset=(clamped_write_ports - i) * width - 1,
                width=width,
                span~,
              ))
            }

            let data_out = Array::new(capacity=read_ports)
          
            for i in 0..<read_ports {
              data_out.push(select(
                expr=get_port!("data_out"),
                offset=(read_ports - i) * width - 1,
                width=width,
                span~,
              ))
            }

            @yir.Stmt::Memory(
              width~,
              depth~,
              init=Some(init),
              clk=get_port!("clk"),
              read_addr=read_addrs,
              write_addr=write_addrs,
              write_enable=write_enables,
              data_in=data_ins,
              data_out=data_out,
              span~, 
            )
          }
          _ => raise UnknownModuleMarkedAsInternal(path~, span~)
        }
      } else {
        @yir.Stmt::Instance(
          module_name=path.to_string(),
          ports=connections,
          span=span,
        )
      }

      mod.add_stmt(inst)

      for port_name, port_expr in inline_connections {
        let sig = ports_sig[port_name].unwrap()

        let lhs = connections[port_name].unwrap()
        let rhs = port_expr

        let assignment = match sig.direction {
          Input => @yir.Stmt::Assign(lhs~, rhs~, span~)
          Output | Inout => @yir.Stmt::Assign(rhs=lhs, lhs=rhs, span~)
        }

        mod.add_stmt(assignment)
      }

      match fields.size() {
        1 => Expr(expr=fields.values().map(Value::as_expr).collect()[0], span~)
        _ => Struct(fields~, span~)
      }
    }
    Indexing(expr~, index~, span~, ty=_) => {
      let val = self.lower_expr!(expr, mod~, env~)
      let idx = self.lower_expr!(index, mod~, env~).expect_const!().bits.as_int!()

      match val {
        Vector(elems~, span~) => {
          let len = elems.length()

          if idx >= len {
            raise ElaborationError::Unreachable(message="Index out of bounds, len: \{len}, index: \{idx}", span~)
          }
          
          elems[idx]
        }
        _ => {
          match expr.ty().val.unwrap() {
            Vector(ty=inner_ty, len=_) => {
              let bits_per_elem = inner_ty.width!(span)
              let lsb = idx * bits_per_elem
              let msb = lsb + bits_per_elem - 1

              Expr(expr=select(expr=val.as_expr(), offset=msb, width=bits_per_elem, span~), span~)
            }
            _ => {
              raise Unsupported(message="Indexing on non-vector data type'", span=expr.span())
            }
          }
        }
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
            raise ElaborationError::Unreachable(message="Slice out of bounds, width: \{width}, msb: \{msb}, lsb: \{lsb}", span~)
          }

          Expr(expr=select(expr~, offset=msb, width=msb - lsb + 1, span~), span~)
        }
        _ => raise Unsupported(message="Slicing on non-vector data type", span=expr.span())
      }
    }
    FieldAccess(expr=accessed_expr, field~, span~, ty=_) => {
      let mut val = self.lower_expr!(accessed_expr, mod~, env~)

      match val {
        Expr(expr=Variable(name~, ..), ..) => {
          let path = @parse.Path::new([], name)
          match env.resolve(path) {
            Some(resolved_val) => {
              val = resolved_val
            }
            _ => ()
          }
        }
        _ => ()
      }

      match val {
        Struct(fields~, ..) => {
          match fields[field] {
            Some(value) => value
            None => raise ElaborationError::Unreachable(message="Unknown struct field", span~)
          }
        }
        Expr(expr~, ..) => {
          let ty = accessed_expr.ty().val.or_error!(ElaborationError::Unreachable(message="Untyped signal field access", span=accessed_expr.span()))

          if expr.width() == 1 {
            return Value::Expr(expr~, span~)
          }

          match ty {
            Struct(fields) => {
              let sorted_keys = { let keys = fields.keys().collect(); keys.sort(); keys }
              let mut offset = expr.width() - 1

              for name in sorted_keys {
                let width = fields[field].unwrap().width!(span)

                if name == field {
                  return Expr(expr=select(expr~, offset~, width~, span~), span~)
                }

                offset -= width
              }

              raise ElaborationError::Unreachable(message="Unknown struct field: \{field}", span~)
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
                let width = field_widths[name].unwrap()

                if name == field {
                  return Expr(expr=select(expr~, offset~, width~, span~), span~)
                }

                offset -= width
              }

              raise ElaborationError::Unreachable(message="Unknown instance field: \{field}", span~)
            }
            _ => raise Unsupported(message="Field access on non-struct type: \{ty}", span~)
          }
        }
        _ => {
          raise Unsupported(message="Invalid field access on value of type: \{val.ctor()}", span~)
        }
      }
    }
    Block(body~, last~, span~, ..) as block_expr => {
      let block_env = env.child()
      let mut contains_assignments = false

      @parse.visit_expr!(block_expr, on_expr=fn(_) { true }, on_stmt=fn(stmt) {
        match stmt {
          Assign(..) => contains_assignments = true
          _ => ()
        }

        false
      })

      if contains_assignments {
        let stmts: StmtContainer = []
        for stmt in body {
          self.lower_stmt!(stmt, mod=stmts, env=block_env)
        }

        let (last, width) = match last {
          Some(last) => {
            let val = self.lower_expr!(last, mod~, env=block_env)
            (Some(val.as_expr()), val.width())
          }
          None => (None, 0)
        }

        let yir_block = @yir.Expr::Block(body=stmts._, last~, width~, span~)
        Value::Expr(expr=yir_block, span~)
      } else {
        for stmt in body {
          self.lower_stmt!(stmt, mod~, env=block_env)
        }

        match last {
          Some(last) => self.lower_expr!(last, mod~, env=block_env)
          None => Value::Expr(expr=@yir.Expr::Concat(elems=[], width=0, span~), span~)
        }
      }
    }
    FunCall(name="display" as name, args~, span~, ty~) => {
      let yir_args = Array::new(capacity=args.length())
      let width = get_width!(ty, span~)

      for arg in args {
        yir_args.push(self.lower_expr!(arg, mod~, env~).as_expr())
      }

      Value::Expr(expr=FunCall(name~, args=yir_args, span~, width~), span~)
    }
    String(value=str, span~, ty~) => {
      let width = get_width!(ty, span~)
      Value::Expr(expr=String(value=str, span~, width~), span~)
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
  width: Int
  direction: @parse.PortDirection
  optional: Bool
}

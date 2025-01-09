
pub struct Elaborator {
  mut autoidx: Int
  modules: Map[String, @rtlil.Module]
  declared_modules: Map[String, @parse.ModuleSignature]
}

typealias ElaboratorEnv = Map[String, Value]

pub fn Elaborator::new() -> Elaborator {
  { autoidx: 0, modules: {}, declared_modules: {} }
}

pub type! ElaboratorError {
  ModuleAlreadyDeclared(name~: String, span~: @parse.Span)
  UnknownIdentifier(name~: String, span~: @parse.Span)
  Unsupported(message~: String, span~: @parse.Span)
  NameConflict(name~: String, span~: @parse.Span)
  ExpectedSignal(span~: @parse.Span)
  UnknownModule(name~: String, span~: @parse.Span)
  ExtraPorts(extra_ports~: Array[String], span~: @parse.Span)
  UntypedLet(span~: @parse.Span)
  UnresolvedType(span~: @parse.Span)
  IndexOutOfBounds(index~: Int, len~: Int, span~: @parse.Span)
  Unreachable(message~: String, span~: @parse.Span)
  DuplicateMatchCase(index~: Int, span~: @parse.Span)
  MissingMatchCase(index~: Int, span~: @parse.Span)
  ReplicateExprAfterSimplification(span~: @parse.Span)
  FunctionCallAfterSimplification(span~: @parse.Span)
  ConstDeclAfterSimplification(span~: @parse.Span)
  UnknownModuleMarkedAsInternal(name~: String, span~: @parse.Span)
  InvalidMemoryInitValue(span~: @parse.Span, expected_size~: Int, actual_size~: Int?)
  StringAfterSimplification(span~: @parse.Span)
  MissingConnectionsOnWriteableMemoryInstance(missing_connections~: Array[String], span~: @parse.Span)
  UnknownModuleParameter(name~: String, span~: @parse.Span)
}

pub impl Show for ElaboratorError with output(self, logger) -> Unit {
  match self {
    ModuleAlreadyDeclared(name~, ..) => {
      logger.write_string("Module '\{name}' already declared")
    }
    UnknownIdentifier(name~, ..) => {
      logger.write_string("Unknown identifier '\{name}'")
    }
    Unsupported(message~, ..) => {
      logger.write_string("Unsupported: \{message}")
    }
    NameConflict(name~, ..) => {
      logger.write_string("Name conflict: '\{name}'")
    }
    ExpectedSignal(..) => {
      logger.write_string("Expected signal")
    }
    UnknownModule(name~, ..) => {
      logger.write_string("Unknown module '\{name}'")
    }
    ExtraPorts(extra_ports~, ..) => {
      let extra_ports = String::concat(extra_ports, separator=", ")
      logger.write_string("Extra ports: \{extra_ports}")
    }
    UntypedLet(..) => {
      logger.write_string("Untyped let")
    }
    UnresolvedType(..) => {
      logger.write_string("Unresolved type")
    }
    IndexOutOfBounds(index~, len~, ..) => {
      logger.write_string("Index \{index} out of bounds (len=\{len})")
    }
    Unreachable(message~, ..) => {
      logger.write_string("Unreachable: \{message}")
    }
    DuplicateMatchCase(index~, ..) => {
      logger.write_string("Duplicate match case: \{index}")
    }
    MissingMatchCase(index~, ..) => {
      logger.write_string("Missing match case: \{index}")
    }
    ReplicateExprAfterSimplification(..) => {
      logger.write_string("Replicate expression after simplification")
    }
    FunctionCallAfterSimplification(..) => {
      logger.write_string("Function call after simplification")
    }
    ConstDeclAfterSimplification(..) => {
      logger.write_string("Const declaration after simplification")
    }
    UnknownModuleMarkedAsInternal(name~, ..) => {
      logger.write_string("Unknown module marked as internal: '\{name}'")
    }
    InvalidMemoryInitValue(expected_size~, actual_size~, ..) => {
      logger.write_string("Invalid memory init value: expected \{expected_size} bits, got \{actual_size}")
    }
    StringAfterSimplification(..) => {
      logger.write_string("String after simplification")
    }
    MissingConnectionsOnWriteableMemoryInstance(missing_connections~, ..) => {
      let list = String::concat(missing_connections, separator=", ")
      logger.write_string("Missing connections on writeable memory instance: '\{list}'")
    }
    UnknownModuleParameter(name~, ..) => {
      logger.write_string("Unknown module parameter: '\{name}'")
    }
  }

  logger.write_string(self.show_context())
}

pub impl @parse.Spanned for ElaboratorError with span(self) -> @parse.Span {
  match self {
    ModuleAlreadyDeclared(span~, ..) => span
    UnknownIdentifier(span~, ..) => span
    Unsupported(span~, ..) => span
    NameConflict(span~, ..) => span
    ExpectedSignal(span~, ..) => span
    UnknownModule(span~, ..) => span
    ExtraPorts(span~, ..) => span
    UntypedLet(span~, ..) => span
    UnresolvedType(span~, ..) => span
    IndexOutOfBounds(span~, ..) => span
    Unreachable(span~, ..) => span
    DuplicateMatchCase(span~, ..) => span
    MissingMatchCase(span~, ..) => span
    ReplicateExprAfterSimplification(span~, ..) => span
    FunctionCallAfterSimplification(span~, ..) => span
    ConstDeclAfterSimplification(span~, ..) => span
    UnknownModuleMarkedAsInternal(span~, ..) => span
    InvalidMemoryInitValue(span~, ..) => span
    StringAfterSimplification(span~, ..) => span
    MissingConnectionsOnWriteableMemoryInstance(span~, ..) => span
    UnknownModuleParameter(span~, ..) => span
  }
}

enum Value {
  Signal(@rtlil.Signal)
  Vector(Array[Value])
  Struct(Map[String, Value])
} derive(Show)

fn ctor(self: Value) -> String {
  match self {
    Signal(_) => "Signal"
    Vector(_) => "Vector"
    Struct(_) => "Struct"
  }
}

fn bits(bits: Array[@parse.BinaryDigit]) -> Value {
  Value::Signal(@rtlil.SigConst(ConstValue(width=bits.length(), bits~)))
}

fn bits_from_int(n: Int, width~: Int) -> @rtlil.Constant {
  let bits = @utils.fill(width, @parse.BinaryDigit::X)
  let mut n = n

  for i in 0..<width {
    bits[width - i - 1] = if (n & 1) == 1 {
      @parse.BinaryDigit::One
    } else {
      @parse.BinaryDigit::Zero
    }

    n /= 2
  }

  ConstValue(width~, bits~)
}

fn default_value(self: Elaborator, ty~: @parse.Type, mod~: @rtlil.Module, env~: ElaboratorEnv, span~: @parse.Span, name_binding~: @rtlil.Id) -> Value! {
  match ty {
    Nat => Value::Signal(@rtlil.SigConst(ConstValue(bits=[Z], width=32)))
    Logic => bits([X])
    Vector(ty~, len~) => match ty {
      Logic => {
        let wire = mod.add_wire!(
          name=name_binding,
          width=len.expect_fixed!(span),
          port=None,
          attributes=src_attribute(span),
          span~,
        )

        Value::Signal(SigWire(wire))
      }
      _ => {
        let len = len.expect_fixed!(span)
        let val = Array::new(capacity=len)

        for i in 0..<len {
          val.push(self.default_value!(ty~, mod~, env~, span~, name_binding=name_binding.join("[\{i}]")))
        }

        Value::Vector(val)
      }
    }
    Instance(sig={ name, span, .. }, params~, accessed_ports=_) => {
      let inst: @parse.Expr = @parse.Expr::Instance(
        name~,
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

      self.elaborate_expr!(inst, mod~, env~, name_binding=Some(name_binding))
    }
    Name(_) => {
      raise UnresolvedType(span~)
    }
    Struct(fields) => {
      let val = Map::new(capacity=fields.size())

      for field, ty in fields {
        val[field] = self.default_value!(ty~, mod~, env~, span~, name_binding=name_binding.join(".\{field}"))
      }

      Value::Struct(val)
    }
    String(_) => {
      raise StringAfterSimplification(span~)
    }
  }
}

fn as_signal(self: Value, span: @parse.Span) -> @rtlil.Signal!ElaboratorError {
  match self {
    Signal(sig) => sig
    Vector(elems) => {
      let signals = Array::new(capacity=elems.length())

      for elem in elems {
        signals.push(elem.as_signal!(span))
      }

      @rtlil.SigConcat(signals)
    }
    Struct(fields) => {
      let signals = Array::new(capacity=fields.size())
      let sorted_keys = { let keys = fields.keys().collect(); keys.sort(); keys }

      for field in sorted_keys {
        signals.push(fields[field].unwrap().as_signal!(span))
      }

      @rtlil.SigConcat(signals)
    }
  }
}

fn expect_integer(self: Value, span: @parse.Span) -> Int!ElaboratorError {
  match self {
    Signal(@rtlil.SigConst(ConstInteger(n))) => n
    _ => raise ExpectedSignal(span~)
  }
}

fn src_attribute(span: @parse.Span) -> Map[@rtlil.Id, @rtlil.Constant] {
  let attributes = {}
  attributes[@rtlil.PubId("src")] = @rtlil.ConstString(span.to_string())
  attributes
}

fn map_attributes(attributes: Map[String, @parse.AttributeValue]) -> Map[@rtlil.Id, @rtlil.Constant] {
  let mapped = Map::new(capacity=attributes.size())

  for name, value in attributes {
    match value {
      String(str) => {
        mapped[@rtlil.PubId(name)] = @rtlil.ConstString(str)
      }
      Int(n) => {
        mapped[@rtlil.PubId(name)] = @rtlil.ConstInteger(n)
      }
    }
  }

  mapped
}

fn map_signals(signals: Map[String, @rtlil.Signal]) -> Map[@rtlil.Id, @rtlil.Signal] {
  let mapped = Map::new(capacity=signals.size())

  for name, sig in signals {
    mapped[@rtlil.PubId(name)] = sig
  }

  mapped
}

fn map_parameters(parameters: Map[String, @rtlil.Constant]) -> Map[@rtlil.Id, @rtlil.Constant] {
  let mapped = Map::new(capacity=parameters.size())

  for name, value in parameters {
    mapped[@rtlil.PubId(name)] = value
  }

  mapped
}

fn elaborate_module(self: Elaborator, mod~: @parse.ModuleDecl, env~: ElaboratorEnv) -> Unit! {
  let mod_def = @rtlil.Module::new(PubId(mod.name))

  for port_id, port in mod.ports {
    let _ = mod_def.add_wire!(
      name=PubId(port.name),
      width=port.ty.width!(port.span),
      port=Some({ direction: port.dir, id: port_id, optional: port.optional }),
      attributes=src_attribute(port.span),
      span=port.span,
    )
  }

  for stmt in mod.body {
    let _ = self.elaborate_stmt!(stmt, mod=mod_def, env~)
  }

  // make sure that output ports are on the left side of connections
  // this seems to be necessary for the Lattice iCEcube2 flow
  let ports = Map::from_iter(mod.ports.iter().map(fn(p) { (p.name, p.dir) }))
  mod_def.connections.map_inplace(fn(connection) {
    let (lhs, rhs) = connection

    match rhs {
      SigWire({ name, .. }) => {
        match ports[name.inner()] {
          Some(Output | Inout) => (rhs, lhs)
          _ => connection
        }
      }
      _ => connection
    }
  })

  if self.modules.contains(mod.name) {
    raise ModuleAlreadyDeclared(name=mod.name, span=mod.span)
  }

  self.modules[mod.name] = mod_def
}

fn port_wire_id(cell_name: @rtlil.Id, port_name: String) -> @rtlil.Id {
  GenId("\{cell_name.inner()}.\{port_name}")
}

fn next_genidx(self: Elaborator) -> Int {
  let idx = self.autoidx
  self.autoidx += 1
  idx
}

fn declare(name: String, value: Value, env~: ElaboratorEnv, span~: @parse.Span) -> Unit!ElaboratorError {
  if env.contains(name) {
    raise NameConflict(name~, span~)
  }
  
  env[name] = value
}

fn expr_width(expr: @parse.Expr) -> Int! {
  match expr {
    Natural(width=Some(width), ..) => width
    _ => expr.ty().val.or_error!(Unreachable(message="Untyped expression", span=expr.span())).width!(expr.span())
  }
}

fn binary_op_cell(
  self: Elaborator,
  op~: @parse.BinaryOp,
  lhs~: @parse.Expr,
  rhs~: @parse.Expr,
  mod~: @rtlil.Module,
  env~: ElaboratorEnv,
  span~: @parse.Span,
  output_width~: Int? = None,
  attributes~: Map[@rtlil.Id, @rtlil.Constant] = {},
) -> Value! {
  let wa = expr_width!(lhs)
  let wb = expr_width!(rhs)

  let cell_type = match op {
    Add => "add"
    Sub => "sub"
    Mul => "mul"
    Div => "div"
    Mod => "mod"
    Equ => "eq"
    Neq => "ne"
    Gtr => "gt"
    Lss => "lt"
    Geq => "ge"
    Leq => "le"
    Shl => "shl"
    Shr => "shr"
    And => "and"
    Or => "or"
    Xor => "xor"
    Nand => raise Unsupported(message="Nand operator after simplification", span~)
    Nor => "nor"
    Xnor => "xnor"
    Ternary => raise Unsupported(message="Ternary operator is not a binop", span~)
  }

  let wy = match output_width {
    Some(output_width) => @utils.min(op.output_width(wa, wb), output_width)
    None => op.output_width(wa, wb)
  }

  let cell_name = "\{cell_type}_\{self.next_genidx()}"

  let output = mod.add_wire!(
    name=GenId("\{cell_name}.y"),
    width=wy,
    port=None,
    attributes=@utils.merge(src_attribute(span), attributes),
    span~
  )
  
  let _ = mod.add_cell!(
    type_=GenId(cell_type),
    name=GenId(cell_name),
    parameters=map_parameters({
      "A_SIGNED": @rtlil.ConstInteger(0),
      "A_WIDTH": @rtlil.ConstInteger(wa),
      "B_SIGNED": @rtlil.ConstInteger(0),
      "B_WIDTH": @rtlil.ConstInteger(wb),
      "Y_WIDTH": @rtlil.ConstInteger(wy),
    }),
    connections=map_signals({
      "A": self.elaborate_expr!(lhs, mod~, env~).as_signal!(lhs.span()),
      "B": self.elaborate_expr!(rhs, mod~, env~).as_signal!(rhs.span()),
      "Y": SigWire(output),
    }),
    attributes=src_attribute(span),
    span~,
  )

  Value::Signal(SigWire(output))
}

fn elaborate_expr(
  self: Elaborator,
  expr: @parse.Expr,
  mod~: @rtlil.Module,
  env~: ElaboratorEnv,
  name_binding~: @rtlil.Id? = None,
) -> Value! {
  match expr {
    Identifier(name~, span~, ..) => {
      match env[name] {
        Some(value) => value
        None => match mod.wires[PubId(name)] {
          Some(wire) => Value::Signal(SigWire(wire))
          None => raise UnknownIdentifier(name~, span~)
        }
      }
    }
    Natural(bits~, width~, ..) => {
      match width {
        Some(width) => Value::Signal(@rtlil.SigConst(@rtlil.Constant::ConstValue(width~, bits=bits.bits)))
        None => Value::Signal(@rtlil.SigConst(ConstInteger(bits.as_int!())))
      }
    }
    String(str=_, span~, ty=_) => {
      raise StringAfterSimplification(span~)
    }
    Unary(op~, expr~, span~, ..) => {
      let cell_type = match op {
        Not => "not"
      }

      let cell_name = "\{cell_type}_\{self.next_genidx()}"
      let width = expr_width!(expr)
      let output = mod.add_wire!(
        name=GenId("\{cell_name}.y"),
        width~,
        port=None,
        attributes=src_attribute(span),
        span~,
      )
      
      let _ = mod.add_cell!(
        type_=GenId(cell_type),
        name=GenId(cell_name),
        parameters=map_parameters({
          "A_SIGNED": @rtlil.ConstInteger(0),
          "A_WIDTH": @rtlil.ConstInteger(width),
          "Y_WIDTH": @rtlil.ConstInteger(width),
        }),
        connections=map_signals({
          "A": self.elaborate_expr!(expr, mod~, env~).as_signal!(expr.span()),
          "Y": SigWire(output),
        }),
        attributes=src_attribute(span),
        span~,
      )

      Value::Signal(SigWire(output))
    }
    Binary(
      op~,
      lhs~,
      rhs~,
      span~,
      ty~,
    ) => {
      let output_width = ty.val.unwrap().width!(span)
      self.binary_op_cell!(op~, lhs~, rhs~, mod~, env~, span~, output_width=Some(output_width))
    }
    Instance(name~, params~, ports~, span~, ty=inst_ty) => {
      if params._.length() > 0 && not(self.declared_modules.contains(name)) {
        raise Unreachable(message="Parameterized instance after simplification", span~)
      }

      let (ports_sig, params_map, attributes) = match self.modules[name] {
        Some(mod) => {
          let ports_sig = {}

          for wire in mod.wires.values() {
            match wire.port {
              Some({ optional, .. }) => {
                ports_sig[wire.name.inner()] = (wire.width, wire.span, optional)
              }
              _ => ()
            }
          }

          (ports_sig, {}, {})
        }
        None => match self.declared_modules[name] {
          Some(sig) => {
            let ports_sig = Map::new(capacity=sig.ports.length())
            let params_map = params.as_map!(names=sig.params)
            let params_env = Map::new(capacity=params_map.size())

            for name, param in params_map {
              params_env[name] = param.as_param!()
            }

            for port in sig.ports {
              let width = port.ty.substitute(params_env~).width!(port.span)
              ports_sig[port.name] = (width, port.span, port.optional)
            }

            (ports_sig, params_map, sig.attributes)
          }
          None => raise ElaboratorError::UnknownModule(name~, span~)
        }
      }

      let connections: Map[@rtlil.Id, @rtlil.Signal] = {}
      let inline_connections: Map[@rtlil.Id, @rtlil.Signal] = {}
      let accessed_ports = match inst_ty.val {
        Some(Instance(sig=_, params=_, accessed_ports~)) => accessed_ports
        _ => raise Unreachable(message="Untyped instance", span~)
      }
      let extra_ports = []
      let cell_name = name_binding.or(GenId("\{name}_\{self.next_genidx()}"))
      let fields: Map[String, Value] = {}

      fn uses_port(port_name: String) -> Bool {
        ports.contains(port_name) || accessed_ports.contains(port_name)
      }

      for port_name, port_sig in ports_sig {
        let (width, span, optional) = port_sig
        let skip = optional && not(uses_port(port_name))

        if not(skip) {
          let wire = mod.add_wire!(
            name=port_wire_id(cell_name, port_name),
            width~,
            port=None,
            attributes=src_attribute(span),
            span~,
          )

          connections[@rtlil.PubId(port_name)] = SigWire(wire)

          if accessed_ports.contains(port_name) {
            fields[port_name] = Value::Signal(SigWire(wire))
          }
        }
      }

      for port_name, expr in ports {
        if not(ports_sig.contains(port_name)) {
          extra_ports.push(port_name)
        }

        let sig = self.elaborate_expr!(expr, mod~, env~).as_signal!(expr.span())
        inline_connections[PubId(port_name)] = sig
      }
      
      if not(extra_ports.is_empty()) {
        raise ExtraPorts(extra_ports~, span~)
      }

      if attributes.contains("internal") {
        fn port_wire(port_name: String) -> @rtlil.Signal! {
          match connections[@rtlil.PubId(port_name)] {
            Some(sig) => sig
            None => raise UnknownModulePort(module_name=name, port_name~, span~)
          }
        }

        fn parameter(name: String) -> @parse.Expr! {
          match params_map[name] {
            Some(param) => param
            None => raise UnknownModuleParameter(name~, span~)
          }
        }

        match name {
          "Reg" | "RegSyncReset" => {
            let width = parameter!("Width").expect_int!()
            let sync_reset = name == "RegSyncReset"
            let uses_rst = uses_port("rst")
            let uses_en = uses_port("en")
            let cell_type = @rtlil.GenId(match (uses_en, uses_rst) {
              (false, false) => "dff"
              (false, true) => if sync_reset { "sdff" } else { "adff" }
              (true, false) => "dffe"
              (true, true) => if sync_reset { "sdffe" } else { "adffe" }
            })

            if not(uses_en) {
              mod.wires.remove(port_wire_id(cell_name, "en"))
            }

            if not(uses_rst) {
              mod.wires.remove(port_wire_id(cell_name, "rst"))
            }

            let _ = mod.add_cell!(
              type_=cell_type,
              name=cell_name,
              parameters={
                let params = {}
                params[@rtlil.PubId("CLK_POLARITY")] = @rtlil.ConstInteger(1)
                params[@rtlil.PubId("WIDTH")] = @rtlil.ConstInteger(width)

                if uses_en {
                  params[@rtlil.PubId("EN_POLARITY")] = @rtlil.ConstInteger(1)
                }

                if uses_rst {
                  if sync_reset {
                    params[@rtlil.PubId("SRST_POLARITY")] = @rtlil.ConstInteger(1)
                    params[@rtlil.PubId("SRST_VALUE")] = bits_from_int(0, width~)
                  } else {
                    params[@rtlil.PubId("ARST_POLARITY")] = @rtlil.ConstInteger(1)
                    params[@rtlil.PubId("ARST_VALUE")] = bits_from_int(0, width~)
                  }
                }

                params
              },
              connections={
                let connections = {}
                connections[@rtlil.PubId("CLK")] = port_wire!("clk")
                connections[@rtlil.PubId("D")] = port_wire!("d")
                connections[@rtlil.PubId("Q")] = port_wire!("q")
                
                if uses_en {
                  connections[@rtlil.PubId("EN")] = port_wire!("en")
                }

                if uses_rst {
                  if sync_reset {
                    connections[@rtlil.PubId("SRST")] = port_wire!("rst")
                  } else {
                    connections[@rtlil.PubId("ARST")] = port_wire!("rst")
                  }
                }

                connections
              },
              attributes=src_attribute(span),
              span~,
            )
          }
          "Memory" => {
            let width = parameter!("Width").expect_int!()
            let depth = parameter!("Depth").expect_int!()
            let read_ports = parameter!("ReadPorts").expect_int!()
            let write_ports = parameter!("WritePorts").expect_int!()
            let clamped_write_ports = @utils.max(read_ports, 1)
            let abits = @utils.clog2(depth + 1)
            let read_width = read_ports * width

            let init = match params_map["Init"] {
              Some(Natural(bits~, width=Some(init_width), ..)) => {
                if init_width != depth * width {
                  raise InvalidMemoryInitValue(
                    span~,
                    expected_size=depth * width,
                    actual_size=Some(init_width),
                  )
                }

                (bits, init_width)
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

            if not(is_writeable) {
              mod.wires.remove(port_wire_id(cell_name, "data_in"))
              mod.wires.remove(port_wire_id(cell_name, "write_enable"))
            }

            let data_reg_out_d = mod.add_wire!(
              name=port_wire_id(cell_name, "data_out_reg_d"),
              width=read_width,
              port=None,
              attributes=src_attribute(span),
              span~,
            )

            let _ = mod.add_cell!(
              type_=@rtlil.GenId(if is_writeable { "dffe" } else { "dff" }),
              name=GenId("\{cell_name.inner()}_data_out_reg"),
              parameters={
                let params = {}
                params[@rtlil.PubId("CLK_POLARITY")] = @rtlil.ConstInteger(1)
                params[@rtlil.PubId("WIDTH")] = @rtlil.ConstInteger(read_width)

                if is_writeable {
                  params[@rtlil.PubId("EN_POLARITY")] = @rtlil.ConstInteger(1)
                }

                params
              },
              connections={
                let connections = {}
                connections[@rtlil.PubId("CLK")] = port_wire!("clk")
                connections[@rtlil.PubId("D")] = SigWire(data_reg_out_d)
                connections[@rtlil.PubId("Q")] = port_wire!("data_out")

                if is_writeable {
                  // TODO: Check if this should be inverted to !write_enable
                  connections[@rtlil.PubId("EN")] = port_wire!("write_enable")
                }

                connections
              },
              span~,
            )

            let _ = mod.add_cell!(
              type_=GenId("mem_v2"),
              name=cell_name,
              parameters={
                let params = {}
                params[@rtlil.PubId("ABITS")] = @rtlil.ConstInteger(abits)
                params[@rtlil.PubId("INIT")] = @rtlil.ConstValue(width=init.1, bits=init.0.bits)
                params[@rtlil.PubId("MEMID")] = @rtlil.ConstString("$mem_\{cell_name.inner()}")
                params[@rtlil.PubId("OFFSET")] = @rtlil.ConstInteger(0)
                params[@rtlil.PubId("RD_ARST_VALUE")] = @rtlil.ConstValue(width=read_width, bits=@utils.fill(read_width, X))
                params[@rtlil.PubId("RD_CE_OVER_SRST")] = @rtlil.ConstValue(width=read_ports, bits=@utils.fill(read_ports, Zero))
                params[@rtlil.PubId("RD_CLK_ENABLE")] = @rtlil.ConstValue(width=read_ports, bits=@utils.fill(read_ports, Zero))
                params[@rtlil.PubId("RD_CLK_POLARITY")] = @rtlil.ConstValue(width=read_ports, bits=@utils.fill(read_ports, Zero))
                params[@rtlil.PubId("RD_COLLISION_X_MASK")] = @rtlil.ConstValue(width=read_ports * clamped_write_ports, bits=@utils.fill(read_ports * clamped_write_ports, Zero))
                params[@rtlil.PubId("RD_INIT_VALUE")] = @rtlil.ConstValue(width=read_width, bits=@utils.fill(read_width, X))
                params[@rtlil.PubId("RD_PORTS")] = @rtlil.ConstInteger(read_ports)
                params[@rtlil.PubId("RD_SRST_VALUE")] = @rtlil.ConstValue(width=read_width, bits=@utils.fill(read_width, X))
                params[@rtlil.PubId("RD_TRANSPARENCY_MASK")] = @rtlil.ConstValue(width=read_ports * clamped_write_ports, bits=@utils.fill(read_ports * clamped_write_ports, Zero))
                params[@rtlil.PubId("RD_WIDE_CONTINUATION")] = @rtlil.ConstValue(width=read_ports, bits=@utils.fill(read_ports, Zero))
                params[@rtlil.PubId("SIZE")] = @rtlil.ConstInteger(depth)
                params[@rtlil.PubId("WIDTH")] = @rtlil.ConstInteger(width)
                params[@rtlil.PubId("WR_CLK_ENABLE")] = @rtlil.ConstValue(width=clamped_write_ports, bits=@utils.fill(clamped_write_ports, One))
                params[@rtlil.PubId("WR_CLK_POLARITY")] = @rtlil.ConstValue(width=1, bits=[One])
                params[@rtlil.PubId("WR_PORTS")] = @rtlil.ConstInteger(if is_writeable { write_ports } else { 0 })
                params[@rtlil.PubId("WR_PRIORITY_MASK")] = @rtlil.ConstValue(width=clamped_write_ports * clamped_write_ports, bits={
                  let bits: Array[@parse.BinaryDigit] = Array::new(capacity=clamped_write_ports * clamped_write_ports)

                  for i in 0..<clamped_write_ports {
                    for bit in @utils.bin(clamped_write_ports - i - 1, width=clamped_write_ports) {
                      bits.push(match bit {
                        0 => Zero
                        _ => One
                      })
                    }
                  }

                  bits
                })
                params[@rtlil.PubId("WR_WIDE_CONTINUATION")] = @rtlil.ConstValue(width=clamped_write_ports, bits=@utils.fill(clamped_write_ports, Zero))
                params
              },
              connections={
                let connections = {}
                connections[@rtlil.PubId("RD_ADDR")] = port_wire!("read_addr")
                connections[@rtlil.PubId("RD_ARST")] = @rtlil.SigConst(@rtlil.ConstValue(width=read_ports, bits=@utils.fill(read_ports, Zero)))
                connections[@rtlil.PubId("RD_CLK")] = @rtlil.SigConst(@rtlil.ConstValue(width=read_ports, bits=@utils.fill(read_ports, X)))
                connections[@rtlil.PubId("RD_DATA")] = SigWire(data_reg_out_d)
                connections[@rtlil.PubId("RD_EN")] = @rtlil.SigConst(@rtlil.ConstValue(width=read_ports, bits=@utils.fill(read_ports, One)))
                connections[@rtlil.PubId("RD_SRST")] = @rtlil.SigConst(@rtlil.ConstValue(width=read_ports, bits=@utils.fill(read_ports, Zero)))

                if is_writeable {
                  connections[@rtlil.PubId("WR_ADDR")] = port_wire!("write_addr")
                  connections[@rtlil.PubId("WR_CLK")] = SigConcat(@utils.fill(write_ports, port_wire!("clk")))
                  connections[@rtlil.PubId("WR_DATA")] = port_wire!("data_in")
                  connections[@rtlil.PubId("WR_EN")] = SigConcat(@utils.fill(write_ports, port_wire!("write_enable")))
                } else {
                  connections[@rtlil.PubId("WR_ADDR")] = SigConcat([])
                  connections[@rtlil.PubId("WR_CLK")] = SigConcat([])
                  connections[@rtlil.PubId("WR_DATA")] = SigConcat([])
                  connections[@rtlil.PubId("WR_EN")] = SigConcat([])
                }

                connections
              },
              span~,
            )
          }
           _ => raise UnknownModuleMarkedAsInternal(name~, span~)
        }
      } else {
        let cell_type = match attributes["alias"] {
          Some({ args: [String(alias_name)], .. }) => {
            if alias_name.starts_with("$") {
              @rtlil.GenId(alias_name.substring(start=1))
            } else {
              @rtlil.PubId(alias_name)
            }
          }
          _ => @rtlil.PubId(name)
        }

        let _ = mod.add_cell!(
          name=cell_name,
          type_=cell_type,
          attributes=src_attribute(span),
          connections~,
          parameters={
            let parameters: Map[@rtlil.Id, @rtlil.Constant] = Map::new(capacity=params_map.size())

            for name, param in params_map {
              match param.expect_int?() {
                Ok(n) => {
                  parameters[@rtlil.PubId(name)] = @rtlil.ConstInteger(n)
                }
                _ => ()
              }
            }

            parameters
          },
          span~,
        )
      }

      for wire_name, sig in inline_connections {
        mod.connect!(connections[wire_name].unwrap(), sig, span~)
      }

      Value::Struct(fields)
    }
    FieldAccess(expr~, field~, span~, ..) => {
      let val = self.elaborate_expr!(expr, mod~, env~)

      match val {
        Struct(fields) => {
          match fields[field] {
            Some(value) => value
            None => raise Unreachable(message="Unknown struct field", span~)
          }
        }
        Signal(signal) => {
          let ty = expr.ty().val.or_error!(Unreachable(message="Untyped signal field access", span=expr.span()))

          match ty {
            Struct(fields) => {
              let sorted_keys = { let keys = fields.keys().collect(); keys.sort(); keys }
              let mut offset = signal.size() - 1

              for name in sorted_keys {
                let width = fields[field].unwrap().width!(span)

                if name == field {
                  return Value::Signal(@rtlil.SigChunk(signal~, offset~, width~))
                }

                offset -= width
              }

              raise Unreachable(message="Unknown struct field: \{field}", span~)
            }
            Instance(sig~, params~, accessed_ports~) => {
              let field_widths = {}
              let params_env = Map::from_iter(params.iter())

              for port in sig.ports {
                if accessed_ports.contains(port.name) {
                  let width = port.ty.substitute(params_env~).width!(span)
                  field_widths[port.name] = width
                }
              }

              let sorted_keys = { let keys = field_widths.keys().collect(); keys.sort(); keys }
              let mut offset = @utils.sum(field_widths.values()) - 1

              for name in sorted_keys {
                let width = field_widths[field].unwrap()

                if name == field {
                  return Value::Signal(@rtlil.SigChunk(signal~, offset~, width~))
                }

                offset -= width
              }

              raise Unreachable(message="Unknown instance field: \{field}", span~)
            }
            _ => raise Unsupported(message="Field access on non-struct type: \{ty}", span~)
          }
        }
        _ => {
          raise Unsupported(message="Invalid field access on value of type: \{val.ctor()}", span~)
        }
      }
    }
    Indexing(expr~, index~, ..) => {
      let idx = self.elaborate_expr!(index, mod~, env~).expect_integer!(index.span())
      let val = self.elaborate_expr!(expr, mod~, env~)

      match val {
        Signal(sig) => {
          if idx > sig.size() {
            raise IndexOutOfBounds(index=idx, len=sig.size(), span=expr.span())
          }

          Value::Signal(@rtlil.SigChunk(signal=sig, offset=idx, width=1))
        }
        Vector(values) => {
          let len = values.length()

          if idx >= len {
            raise IndexOutOfBounds(index=idx, len~, span=expr.span())
          }
          
          values[idx]
        }
        _ => raise Unsupported(message="Indexing on non-vector data type", span=expr.span())
      }
    }
    Slicing(expr~, msb~, lsb~, ..) => {
      let sig = self.elaborate_expr!(expr, mod~, env~).as_signal!(expr.span())
      let msb = self.elaborate_expr!(msb, mod~, env~).expect_integer!(msb.span())
      let lsb = self.elaborate_expr!(lsb, mod~, env~).expect_integer!(lsb.span())

      if msb < lsb {
        raise Unreachable(message="Invalid slicing range", span=expr.span())
      }

      Value::Signal(@rtlil.SigChunk(signal=sig, offset=msb, width=(msb - lsb) + 1))
    }
    Vector(elems~, ..) => {
      let values = Array::new(capacity=elems.length())

      for elem in elems {
        match elem {
          Spread(expr~, ..) => {
            let val = self.elaborate_expr!(expr, mod~, env~)

            match val {
              Vector(values) => {
                for value in values {
                  values.push(value)
                }
              }
              _ => values.push(val)
            }
          }
          _ => {
            values.push(self.elaborate_expr!(elem, mod~, env~))
          }
        }
      }

      Value::Vector(values)
    }
    Spread(span~, ..) => {
      raise Unreachable(message="Spread operator outside Vector", span~)
    }
    Ternary(cond~, then~, else_~, span~, ..) => {
      let cell_type = "mux"
      let cell_name = "\{cell_type}_\{self.next_genidx()}"

      let width = expr_width!(then)
      let output = mod.add_wire!(
        name=GenId("\{cell_name}.y"),
        width~,
        port=None,
        attributes=src_attribute(span),
        span~,
      )
      
      let _ = mod.add_cell!(
        type_=GenId(cell_type),
        name=GenId(cell_name),
        parameters=map_parameters({
          "WIDTH": @rtlil.ConstInteger(width)
        }),
        connections=map_signals({
          "A": self.elaborate_expr!(else_, mod~, env~).as_signal!(then.span()),
          "B": self.elaborate_expr!(then, mod~, env~).as_signal!(else_.span()),
          "S": self.elaborate_expr!(cond, mod~, env~).as_signal!(cond.span()),
          "Y": SigWire(output)
        }),
        attributes=src_attribute(span),
        span~,
      )

      Value::Signal(SigWire(output))
    }
    Match(subject~, cases~, default~, span~, ty~) => {
      let width = ty.val.unwrap().width!(span)
      let s_width = expr_width!(subject)
      let max_cases = @utils.pow2(s_width)
      let cell_type = "pmux"
      let cell_name = "\{cell_type}_\{self.next_genidx()}"
      
      let output = mod.add_wire!(
        name=GenId("\{cell_name}.y"),
        width~,
        port=None,
        attributes=src_attribute(span),
        span~,
      )

      let (default_sig, b_sig, s_sig) = {
        let sigs: Array[(@parse.Expr, @rtlil.Signal)?] = @utils.fill(max_cases, None)

        for case in cases {
          let (lhs, rhs) = case
          let index = lhs.expect_int!()

          if index >= max_cases {
            raise IndexOutOfBounds(index~, len=max_cases, span=lhs.span())
          }

          match sigs[index] {
            Some(_) => raise DuplicateMatchCase(index~, span=lhs.span())
            None => {
              let rhs_sig = self.elaborate_expr!(rhs, mod~, env~).as_signal!(rhs.span())
              sigs[index] = Some((lhs, rhs_sig))
            }
          }
        }

        let unwrapped_sigs: Array[@rtlil.Signal] = []
        let comparisons: Array[@rtlil.Signal] = []

        for idx, sig in sigs {
          match sig {
            Some((lhs, sig)) => {
              let eq_cell = self.binary_op_cell!(
                op=Equ,
                lhs~,
                rhs=subject,
                mod~,
                env~,
                span~,
                attributes=map_attributes({"full_case": Int(1)})
              )

              comparisons.push(eq_cell.as_signal!(lhs.span()))
              unwrapped_sigs.push(sig)
            }
            None => {
              if default.is_empty() {
                raise MissingMatchCase(index=idx, span=span)
              }
            }
          }
        }

        let default_sig = match default {
          Some(expr) => self.elaborate_expr!(expr, mod~, env~).as_signal!(expr.span())
          None => SigConst(ConstValue(width~, bits=@utils.fill(width, @parse.BinaryDigit::X)))
        }

        (default_sig, @rtlil.SigConcat(unwrapped_sigs), @rtlil.SigConcat(comparisons))
      }

      let _ = mod.add_cell!(
        type_=GenId(cell_type),
        name=GenId(cell_name),
        parameters=map_parameters({
          "S_WIDTH": @rtlil.ConstInteger(@utils.pow2(s_width)),
          "WIDTH": @rtlil.ConstInteger(width),
        }),
        connections=map_signals({
          "A": default_sig,
          "B": b_sig,
          "S": s_sig,
          "Y": SigWire(output),
        }),
        attributes=@utils.merge(
          src_attribute(span),
          map_attributes({"full_case": Int(1)}),
        ),
        span~,
      )

      Value::Signal(SigWire(output))
    }
    Tuple(elems~, ..) => {
      let values = Array::new(capacity=elems.length())

      for elem in elems {
        values.push(self.elaborate_expr!(elem, mod~, env~))
      }

      Value::Vector(values)
    }
    Replicate(span~, ..) => {
      raise ReplicateExprAfterSimplification(span~)
    }
    FunCall(span~, ..) => {
      raise FunctionCallAfterSimplification(span~)
    }
    Struct(fields~, span=_, ty=_) => {
      let val = Map::new(capacity=fields.size())
      let sorted_keys = { let keys = fields.keys().collect(); keys.sort(); keys }

      for field in sorted_keys {
        let field_expr = fields[field].unwrap()

        val[field] = self.elaborate_expr!(
          field_expr,
          mod~,
          env~,
          name_binding=Some(name_binding.map(fn(id) { id.join(".\{field}") }).or(GenId("\{field}\{self.next_genidx()}"))),
        )
      }

      Value::Struct(val)
    }
  }
}

fn elaborate_stmt(self: Elaborator, stmt: @parse.Stmt, mod~: @rtlil.Module, env~: ElaboratorEnv) -> Unit! {
  match stmt {
    Expr(expr~, ..) => {
      let _ = self.elaborate_expr!(expr, mod~, env~)
    }
    Let(name~, ty~, expr~, span~) => {
      match expr {
        Some(expr) => {
          match self.elaborate_expr!(expr, mod~, env~, name_binding=Some(PubId(name))) {
            Signal(sig) => {
              let wire = mod.add_wire!(
                name=PubId(name),
                width=sig.size(),
                port=None,
                attributes=src_attribute(span),
                span~,
              )

              declare!(name, Value::Signal(SigWire(wire)), env~, span=expr.span())
              mod.connect!(SigWire(wire), sig, span=expr.span())
            }
            Vector(_) as val => {
              declare!(name, val, env~, span=expr.span())
            }
            Struct(_) as val => {
              declare!(name, val, env~, span=expr.span())
            }
          }
        }
        None => {
          let ty = ty.val.or_error!(UntypedLet(span~))
          let val = self.default_value!(ty~, mod~, env~, span~, name_binding=PubId(name))
          declare!(name, val, env~, span~)
        }
      }
    }
    Assign(lhs~, rhs~, span~) => {
      let sig1 = self.elaborate_expr!(lhs, mod~, env~).as_signal!(lhs.span())
      let sig2 = self.elaborate_expr!(rhs, mod~, env~).as_signal!(rhs.span())
      mod.connect!(sig1, sig2, span~)
    }
    For(span~, ..) => {
      raise Unreachable(message="For loop after simplification", span~)
    }
    Scope(body~, ..) => {
      for stmt in body {
        self.elaborate_stmt!(stmt, mod~, env~)
      }
    }
    Const(span~, ..) => {
      raise ConstDeclAfterSimplification(span~)
    }
  }
}

pub fn elaborate_decl(self: Elaborator, decl: @parse.Decl) -> Unit! {
  match decl {
    Module(mod) => {
      self.elaborate_module!(mod~, env={})
    }
    ModuleDeclaration(sig) => {
      self.declared_modules[sig.name] = sig
    }
    Const(decl) => {
      raise ConstDeclAfterSimplification(span=decl.span)
    }
  }
}

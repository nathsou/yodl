priv struct FrontendPipeline {
  pkg: @parse.PackageDecl
  simplified_decls: Array[@parse.CoreDecl]
  source_text: String
  mono_text: String
  typed_text: String
  simplified_text: String
  top: String
  port_usage: @parse.PortUsage
  tests: Array[@parse.TestDecl]
  test_modules: Map[String, Array[@parse.Port]]
}

fn prepare_frontend(path: String, ext: @utils.Externals, top: String?, allow_test_top~: Bool = false) -> FrontendPipeline raise {
  if !path.has_suffix(".yodl") { raise Failure::Failure("Input file must have a .yodl extension") }
  let resolver = @simplify.Resolver::new(@utils.dir_name(path), fs=ext.fs)
  let pkg = try resolver.resolve(path~, is_top_package=true) catch { err => raise Failure::Failure("\{err}") }
  let source_emitter = @parse.AstEmitter::new()
  for decl in pkg.body { source_emitter.emit_decl(decl); source_emitter.emit("\n") }
  let source_text = source_emitter.to_string()
  let monomorphizer = @simplify.Monomorphizer::new()
  let mono_decls = try monomorphizer.monomorphize(decls=pkg.body, packages=[]) catch { err => raise Failure::Failure(err.to_string()) }
  let mono_emitter = @parse.AstEmitter::new()
  for decl in mono_decls { mono_emitter.emit_decl(decl); mono_emitter.emit("\n") }
  let mono_text = mono_emitter.to_string()
  let checker = @elaborate.TypeChecker::new()
  let resolved_decls = Array::new(capacity=mono_decls.length())
  for decl in mono_decls {
    let resolved = try checker.check_decl(decl) catch { err => raise Failure::Failure(err.to_string()) }
    resolved_decls.push(resolved)
  }
  try checker.finalize() catch { err => raise Failure::Failure(err.to_string()) }
  // Keep the post-check declarations as the source for test execution. The
  // dedicated test checker below validates the host-side actions after all
  // module signatures and concrete generic instances are known.
  let tests = resolved_decls.filter_map(fn(decl) {
    match decl { @parse.Decl::Test(td) => Some(td); _ => None }
  })
  let typed_emitter = @parse.AstEmitter::new(show_expr_types=true)
  for decl in resolved_decls { typed_emitter.emit_decl(decl); typed_emitter.emit("\n") }
  let typed_text = typed_emitter.to_string()
  let simplified_decls = @simplify.simplify_decls(resolved_decls)
  let simplified_emitter = @parse.AstEmitter::new()
  for decl in simplified_decls { simplified_emitter.emit_core_decl(decl); simplified_emitter.emit("\n") }
  let simplified_text = simplified_emitter.to_string()
  let configured_top = match top { Some(name) => Some(name); None => simulation_top_from_package(pkg) }
  let selected_top = match configured_top {
    Some(top) => top
    None => {
      let candidates = pkg.body.filter_map(decl => match decl {
        @parse.Decl::Module({ path, params: [], .. }) => Some(path)
        _ => None
      }).filter(path => !monomorphizer.instanciated_modules.contains(path))
      let candidates = if candidates.is_empty() {
        mono_decls.filter_map(decl => match decl {
          @parse.Decl::Module({ path, params: [], .. }) => Some(path)
          _ => None
        }).filter(path => allow_test_top || !monomorphizer.test_only_modules.contains(path))
      } else { candidates }
      match candidates {
        [] => raise Failure::Failure("No top-level module found")
        [top] => top.elem
        _ => if allow_test_top {
          candidates[0].elem
        } else if candidates.contains(@parse.Path::new([], "Top")) {
          "Top"
        } else {
          let names = candidates.iter().map(path => path.to_string()).join(", ")
          raise Failure::Failure("Multiple top-level modules found: [\{names}], remove extraneous uninstanciated modules or rename the top module to `Top`")
        }
      }
    }
  }
  let test_modules: Map[String, Array[@parse.Port]] = Map([])
  for decl in mono_decls {
    match decl {
      @parse.Decl::Module(mod) => test_modules[mod.path.elem] = mod.ports
      _ => ()
    }
  }
  validate_tests(tests, mono_decls)
  { pkg, simplified_decls, source_text, mono_text, typed_text, simplified_text, top: selected_top, port_usage: checker.port_usage(), tests, test_modules }
}

fn simulation_top_from_package(pkg: @parse.PackageDecl) -> String? {
  for decl in pkg.body {
    guard decl is @parse.Decl::Module({ attributes, .. }) else { continue }
    guard attributes.get("simulation") is Some({ args: [@parse.AttributeValue::Dict(values)], .. }) else { continue }
    if values.get("top") is Some(@parse.AttributeValue::String(name)) { return Some(name) }
  }
  None
}

pub fn run(
  path~ : String,
  commands~ : Array[Command],
  ext~ : @utils.Externals,
) -> Unit raise {
  let fs = ext.fs
  let only_tests = commands.length() > 0 && commands.iter().all(fn(cmd) {
    match cmd { RunTests(_) => true; _ => false }
  })
  let frontend = prepare_frontend(path, ext, None, allow_test_top=only_tests)

  for cmd in commands {
    if cmd is RunTests(filter~) {
      run_tests(frontend, filter, ext)
    }
  }
  if only_tests { return }

  for cmd in commands {
    if cmd is WriteSource(path~) {
      match path {
        Some(path) => (fs.write_string_to_file)(path, frontend.source_text)
        None => (ext.println)(frontend.source_text)
      }
    }
  }

  for cmd in commands {
    if cmd is WriteMono(path~) {
      match path {
        Some(path) => (fs.write_string_to_file)(path, frontend.mono_text)
        None => (ext.println)(frontend.mono_text)
      }
    }
  }

  for cmd in commands {
    if cmd is WriteTyped(path~) {
      match path {
        Some(path) => (fs.write_string_to_file)(path, frontend.typed_text)
        None => (ext.println)(frontend.typed_text)
      }
    }
  }

  let simplified_decls = frontend.simplified_decls

  for cmd in commands {
    if cmd is WriteSimplified(path~) {
      match path {
        Some(path) => (fs.write_string_to_file)(path, frontend.simplified_text)
        None => (ext.println)(frontend.simplified_text)
      }
    }
  }

  let top = frontend.top

  let firrtl = {
    let low = @elaborate.Elaborator::new(top, port_usage=frontend.port_usage)

    try low.lower(simplified_decls.iter()) catch {
      err => raise Failure::Failure(err.to_string())
    }

    low
  }

  for cmd in commands {
    match cmd {
      WriteFIRRTL(path~, passes~) => {
        let circuit = lower_firrtl(firrtl, passes~)
        let emitter = @firrtl.FIRRTLEmitter::new()
        emitter.emit_circuit(circuit)

        match path {
          Some(path) => (fs.write_string_to_file)(path, emitter.0.to_string())
          None => (ext.println)(emitter.0.to_string())
        }
      }
      WriteRTLIL(path~) => {
        let firrtl_circuit = lower_firrtl(firrtl, passes=[
          @firrtl.ExpandConnectsPass::new(),
          @firrtl.ExpandWhensPass::new(),
          @firrtl.FlattenMemoriesPass::new(),
          @firrtl.LowerAggregateTypesPass::new(split_memories=false),
        ])

        let rtlil_design = @rtlil.lower_circuit(firrtl_circuit, fs~)
        let emitter = @rtlil.Serializer::new(rtlil_design)

        match path {
          Some(path) => (fs.write_string_to_file)(path, emitter.to_string())
          None => (ext.println)(emitter.to_string())
        }
      }
      _ => ()
    }
  }
}

fn lower_firrtl(firrtl : @elaborate.Elaborator, passes~ : Array[&@firrtl.FIRRTLPass]) -> @firrtl.TypedCircuit raise {
  let circuit : @firrtl.UntypedCircuit = {
    version: @firrtl.min_version(),
    id: Ident(firrtl.circuit_name),
    annotations: firrtl.annotations,
    decls: {
      let extmodules = firrtl.extmodules
        .values()
        .map(mod => @firrtl.Decl::ExtModule(mod))
      let modules = firrtl.modules
        .values()
        .map(mod => @firrtl.Decl::Module(mod))
      (extmodules + modules).collect()
    },
  }

  let circuit : @firrtl.TypedCircuit = @firrtl.type_check_circuit(circuit)
  let mut circ = @firrtl.CleanupPass::new().run(circuit)

  for pass in passes {
    circ = pass.run(circ)
  }

  circ
}

priv struct TestDut {
  binding: String?
  ports: Map[String, @parse.Port]
  default_clock: String?
}

priv struct TestCheckContext {
  dut: TestDut
  locals: Map[String, Int]
}

priv struct TestRuntime {
  dut: TestDut
  tb: @simulator.Testbench
  locals: Map[String, TestValue]
}

/// Host-side test values retain their mathematical value until they are
/// fitted to a DUT port. An optional mask is present only for values read from
/// the simulator, where individual bits may be unknown.
priv struct TestValue {
  raw: BigInt
  width: Int?
  known_mask: BigInt?
}

fn test_target_expr(td: @parse.TestDecl) -> @parse.Expr? raise {
  match td.target {
    Some(target) => Some(target)
    None => {
      match test_instance_exprs(td.body) {
        [] => None
        [expr] => Some(expr)
        _ => raise Failure::Failure("An unbound test must declare exactly one DUT instance")
      }
    }
  }
}

fn test_instance_exprs(body: Array[@parse.Stmt]) -> Array[@parse.Expr] {
  let instances = []
  for stmt in body {
    match stmt {
      @parse.Stmt::Let(expr=Some(expr), ..) if expr is @parse.Expr::Instance(..) => instances.push(expr)
      @parse.Stmt::Scope(body~, ..) | @parse.Stmt::For(body~, ..) => instances.append(test_instance_exprs(body))
      _ => ()
    }
  }
  instances
}

fn test_target_name(expr: @parse.Expr) -> String? {
  match expr {
    @parse.Expr::Identifier(path~, ..) | @parse.Expr::Instance(path~, ..) => Some(path.elem)
    _ => None
  }
}

fn validate_test_instance(expr: @parse.Expr) -> Unit raise {
  match expr {
    @parse.Expr::Instance(ports~, span~, ..) if !ports.is_empty() => {
      raise Failure::Failure(
        "DUT connections in a test instance are not supported; use drive!() after the instance at \{span}",
      )
    }
    _ => ()
  }
}

fn test_binding_name(td: @parse.TestDecl) -> String? {
  if td.target is Some(_) { return None }
  test_instance_names(td.body).get(0)
}

fn test_instance_names(body: Array[@parse.Stmt]) -> Array[String] {
  let names = []
  for stmt in body {
    match stmt {
      @parse.Stmt::Let(name~, expr=Some(@parse.Expr::Instance(..)), ..) => names.push(name)
      @parse.Stmt::Scope(body~, ..) | @parse.Stmt::For(body~, ..) => names.append(test_instance_names(body))
      _ => ()
    }
  }
  names
}

fn test_signal_name(dut: TestDut, expr: @parse.Expr) -> String raise {
  match expr {
    @parse.Expr::Identifier(path~, ..) => {
      if !path.packages.is_empty() {
        raise Failure::Failure("Test signal references must name a DUT port directly")
      }
      if dut.binding is None {
        path.elem
      } else {
        raise Failure::Failure("Unbound tests must qualify DUT ports as `dut.port`")
      }
    }
    @parse.Expr::FieldAccess(expr=base, field~, ..) => {
      guard dut.binding is Some(binding) else {
        raise Failure::Failure("Bound tests use DUT ports directly; remove the DUT qualifier")
      }
      match base {
        @parse.Expr::Identifier(path~, ..) if path.packages.is_empty() && path.elem == binding => field
        _ => raise Failure::Failure("DUT port references must use the declared DUT binding")
      }
    }
    _ => raise Failure::Failure("test signal references must be ports or port fields")
  }
}

fn test_port(dut: TestDut, expr: @parse.Expr) -> @parse.Port raise {
  let signal = test_signal_name(dut, expr)
  dut.ports.get(signal).unwrap_or_error(
    Failure::Failure("Unknown DUT port '\{signal}' at \{expr.span()}")
  )
}

fn test_expr_width(ctx: TestCheckContext, expr: @parse.Expr) -> Int? raise {
  match expr {
    @parse.Expr::Natural(value~, width~, span~, ..) => {
      let required = @utils.significant_bits(value)
      match width {
        Some(width) if required > width => {
          raise Failure::Failure("Literal requires \{required} bits but declares \{width} at \{span}")
        }
        Some(width) => Some(width)
        None => Some(required)
      }
    }
    @parse.Expr::Identifier(path~, ..) => ctx.locals.get(path.elem)
    @parse.Expr::Unary(expr~, ..) => test_expr_width(ctx, expr)
    @parse.Expr::Binary(op~, lhs~, rhs~, ..) => {
      match (test_expr_width(ctx, lhs), test_expr_width(ctx, rhs)) {
        (Some(a), Some(b)) => Some(match op {
          @parse.BinaryOp::Add | @parse.BinaryOp::Sub => (if a > b { a } else { b }) + 1
          @parse.BinaryOp::Mul => a + b
          @parse.BinaryOp::Shl => a + b
          @parse.BinaryOp::Shr | @parse.BinaryOp::Div => a
          @parse.BinaryOp::Mod => if a < b { a } else { b }
          @parse.BinaryOp::Equ | @parse.BinaryOp::Neq | @parse.BinaryOp::Lss |
          @parse.BinaryOp::Gtr | @parse.BinaryOp::Leq | @parse.BinaryOp::Geq => 1
          @parse.BinaryOp::And | @parse.BinaryOp::Or | @parse.BinaryOp::Xor |
          @parse.BinaryOp::Nand | @parse.BinaryOp::Nor | @parse.BinaryOp::Xnor => if a > b { a } else { b }
          @parse.BinaryOp::Ternary => if a > b { a } else { b }
        })
        _ => None
      }
    }
    @parse.Expr::FunCall(name="peek", args~, ..) if args.length() == 1 => {
      let port = test_port(ctx.dut, args[0])
      Some(port.ty.width(args[0].span()))
    }
    _ => None
  }
}

fn check_test_value(ctx: TestCheckContext, expr: @parse.Expr, width: Int) -> Unit raise {
  match test_expr_width(ctx, expr) {
    Some(value_width) if value_width > width => {
      raise Failure::Failure("Test value is \{value_width} bits wide but port is only \{width} bits at \{expr.span()}")
    }
    Some(_) => ()
    None => raise Failure::Failure("Unsupported test value expression at \{expr.span()}")
  }
}

fn TestValue::from_sim(value: @simulator.SimValue) -> TestValue {
  { raw: value.raw, width: Some(value.width), known_mask: Some(value.known_mask) }
}

fn TestValue::from_typed_sim(value: @simulator.SimValue, ty: @parse.Type) -> TestValue {
  if value.width > 0 && value.is_known() {
    match ty {
      @parse.Type::SInt(_) if (value.raw & @utils.pow2(value.width - 1)) != 0 => {
        return TestValue::known(value.raw - @utils.pow2(value.width), width=Some(value.width))
      }
      _ => ()
    }
  }
  TestValue::from_sim(value)
}

fn TestValue::known(raw: BigInt, width~: Int? = None) -> TestValue {
  { raw, width, known_mask: None }
}

fn TestValue::is_known(self: TestValue) -> Bool {
  match (self.width, self.known_mask) {
    (Some(width), Some(mask)) => mask == (@utils.pow2(width) - 1)
    _ => true
  }
}

fn fit_test_value(value: TestValue, width: Int) -> @simulator.SimValue raise {
  if value.is_known() {
    let required = @utils.significant_bits(value.raw)
    if required > width {
      raise Failure::Failure("Test value requires \{required} bits but destination is only \{width} bits")
    }
    return @simulator.SimValue::new(width, value.raw)
  }
  match (value.width, value.known_mask) {
    (Some(source_width), Some(mask)) if width > source_width => {
      let added_known_bits = (@utils.pow2(width) - 1) ^ (@utils.pow2(source_width) - 1)
      @simulator.SimValue::with_mask(width, value.raw, mask | added_known_bits)
    }
    (_, Some(mask)) => @simulator.SimValue::with_mask(width, value.raw, mask)
    _ => @simulator.SimValue::new(width, value.raw)
  }
}

fn child_test_check_context(ctx: TestCheckContext) -> TestCheckContext {
  let locals: Map[String, Int] = Map([], capacity=ctx.locals.length())
  for name, width in ctx.locals { locals[name] = width }
  { dut: ctx.dut, locals }
}

fn child_test_runtime(ctx: TestRuntime) -> TestRuntime {
  let locals: Map[String, TestValue] = Map([], capacity=ctx.locals.length())
  for name, value in ctx.locals { locals[name] = value }
  { dut: ctx.dut, tb: ctx.tb, locals }
}

fn validate_test_local_width(
  ctx: TestCheckContext,
  name: String,
  expr: @parse.Expr,
  declared: @parse.Type?,
  span: @parse.Span,
) -> Int raise {
  let inferred = test_expr_width(ctx, expr).unwrap_or_error(
    Failure::Failure("Unsupported test value expression at \{expr.span()}"),
  )
  match declared {
    None => inferred
    Some(ty) => {
      if !ty.is_ground() {
        raise Failure::Failure("Test-local type '\{ty}' must be an integer type at \{span}")
      }
      let width = ty.width(span)
      if inferred > width {
        raise Failure::Failure(
          "Test value is \{inferred} bits wide but local '\{name}' is only \{width} bits at \{expr.span()}",
        )
      }
      width
    }
  }
}

fn validate_test_stmt(ctx: TestCheckContext, stmt: @parse.Stmt) -> Unit raise {
  match stmt {
    @parse.Stmt::Scope(body~, ..) => {
      let child = child_test_check_context(ctx)
      for nested in body { validate_test_stmt(child, nested) }
    }
    @parse.Stmt::For(variable~, range~, body~, ..) => {
      if test_expr_width(ctx, range.start) is None || test_expr_width(ctx, range.end) is None {
        raise Failure::Failure("Test loop bounds must be integer expressions")
      }
      let child = child_test_check_context(ctx)
      child.locals[variable] = 32
      for nested in body { validate_test_stmt(child, nested) }
    }
    @parse.Stmt::Let(name~, ty~, expr=Some(expr), span~) => {
      match expr {
        @parse.Expr::Instance(..) => validate_test_instance(expr)
        _ => {
          ctx.locals[name] = validate_test_local_width(ctx, name, expr, ty.val, span)
        }
      }
    }
    @parse.Stmt::Let(..) => raise Failure::Failure("Test let bindings require an initializer")
    @parse.Stmt::Const(decl~, ..) => {
      ctx.locals[decl.path.elem] = validate_test_local_width(
        ctx,
        decl.path.elem,
        decl.expr,
        decl.ty,
        decl.span,
      )
    }
    @parse.Stmt::Assign(..) => raise Failure::Failure("assignments are not allowed in a test; use drive!()")
    @parse.Stmt::Expr(expr=@parse.Expr::FunCall(name~, args~, ..), ..) => match name {
      "drive" => {
        if args.length() != 2 { raise Failure::Failure("drive! expects a signal and a value") }
        let port = test_port(ctx.dut, args[0])
        if port.dir is @parse.PortDir::Output {
          raise Failure::Failure("Cannot drive output port '\{port.name}'")
        }
        if port.ty is @parse.Type::Clock {
          raise Failure::Failure("Clock ports are driven by step!()")
        }
        check_test_value(ctx, args[1], port.ty.width(args[0].span()))
      }
      "expect" => {
        if args.length() != 2 { raise Failure::Failure("expect! expects a signal and a value") }
        let port = test_port(ctx.dut, args[0])
        check_test_value(ctx, args[1], port.ty.width(args[0].span()))
      }
      "step" => {
        let (_, count_expr) = match args {
          [count] => {
            guard ctx.dut.default_clock is Some(_) else {
              raise Failure::Failure("step! shorthand requires exactly one clock port; specify step!(clock, cycles)")
            }
            (ctx.dut.default_clock.unwrap(), count)
          }
          [clock, count] => {
            let clock_port = test_port(ctx.dut, clock)
            if !(clock_port.ty is @parse.Type::Clock) {
              raise Failure::Failure("step! clock argument must be a clock port")
            }
            (test_signal_name(ctx.dut, clock), count)
          }
          _ => raise Failure::Failure("step! expects a cycle count or a clock and cycle count")
        }
        if test_expr_width(ctx, count_expr) is None {
          raise Failure::Failure("step! cycle count must be an integer expression")
        }
      }
      "settle" => if args.length() != 0 { raise Failure::Failure("settle! takes no arguments") }
      "peek" => if args.length() != 1 { raise Failure::Failure("peek! expects one signal") } else { ignore(test_port(ctx.dut, args[0])) }
      _ => raise Failure::Failure("unknown test action '\{name}!' at \{stmt.span()}")
    }
    @parse.Stmt::Expr(..) => raise Failure::Failure("test expressions must be simulation actions")
  }
}

fn validate_tests(tests: Array[@parse.TestDecl], decls: Array[@parse.Decl]) -> Unit raise {
  let modules: Map[String, @parse.ModuleDecl] = Map([])
  for decl in decls {
    match decl {
      @parse.Decl::Module(mod) => modules[mod.path.elem] = mod
      _ => ()
    }
  }
  for td in tests {
    let target_expr = test_target_expr(td).unwrap_or_error(
      Failure::Failure("Test '\{td.name}' has no DUT; add `for Module` or `let dut = Module()`"),
    )
    validate_test_instance(target_expr)
    let target = test_target_name(target_expr).unwrap_or_error(
      Failure::Failure("Test DUT must be a module or module instance"),
    )
    let mod = modules.get(target).unwrap_or_error(
      Failure::Failure("Test '\{td.name}' targets unknown module '\{target}'"),
    )
    let ports: Map[String, @parse.Port] = Map([])
    for port in mod.ports { ports[port.name] = port }
    let clocks = mod.ports.filter(port => port.ty is @parse.Type::Clock)
    let dut = {
      binding: test_binding_name(td),
      ports,
      default_clock: if clocks.length() == 1 { Some(clocks[0].name) } else { None },
    }
    let ctx = { dut, locals: Map([]) }
    for stmt in td.body { validate_test_stmt(ctx, stmt) }
  }
}

fn test_value_width(value: TestValue) -> Int {
  value.width.unwrap_or(@utils.significant_bits(value.raw))
}

fn eval_test_expr(ctx: TestRuntime, expr: @parse.Expr) -> TestValue raise {
  match expr {
    @parse.Expr::Natural(value~, width~, ..) => {
      TestValue::known(value, width~)
    }
    @parse.Expr::Identifier(path~, ..) => ctx.locals.get(path.elem).unwrap_or_error(
      Failure::Failure("Unknown test-local value '\{path.elem}'")
    )
    @parse.Expr::Unary(op~, expr~, ..) => {
      let value = eval_test_expr(ctx, expr)
      if !value.is_known() {
        raise Failure::Failure("Unknown simulator values cannot be used in test arithmetic")
      }
      let width = test_value_width(value)
      match op {
        @parse.UnaryOp::Neg => TestValue::known(-value.raw)
        @parse.UnaryOp::Not => TestValue::known(@utils.bitwise_not(value.raw, width~), width=Some(width))
        @parse.UnaryOp::Andr => TestValue::known(BigInt::from_int(@utils.bits(value.raw).iter().all(@utils.identity).to_int()), width=Some(1))
        @parse.UnaryOp::Orr => TestValue::known(BigInt::from_int(@utils.bits(value.raw).iter().any(@utils.identity).to_int()), width=Some(1))
        @parse.UnaryOp::Xorr => TestValue::known(BigInt::from_int(@utils.bits(value.raw).fold(init=0, (acc, b) => acc ^ b.to_int())), width=Some(1))
      }
    }
    @parse.Expr::Binary(op~, lhs~, rhs~, ..) => {
      let a = eval_test_expr(ctx, lhs)
      let b = eval_test_expr(ctx, rhs)
      if !a.is_known() || !b.is_known() {
        raise Failure::Failure("Unknown simulator values cannot be used in test arithmetic")
      }
      if (op is @parse.BinaryOp::Div || op is @parse.BinaryOp::Mod) && b.raw == 0 {
        raise Failure::Failure("Division by zero in test expression at \{expr.span()}")
      }
      if (op is @parse.BinaryOp::Shl || op is @parse.BinaryOp::Shr) && b.raw < 0 {
        raise Failure::Failure("Negative shift count in test expression at \{expr.span()}")
      }
      let width = if test_value_width(a) > test_value_width(b) {
        test_value_width(a)
      } else {
        test_value_width(b)
      }
      let value = match op {
        @parse.BinaryOp::Add => a.raw + b.raw
        @parse.BinaryOp::Sub => a.raw - b.raw
        @parse.BinaryOp::Mul => a.raw * b.raw
        @parse.BinaryOp::Div => a.raw / b.raw
        @parse.BinaryOp::Mod => a.raw % b.raw
        @parse.BinaryOp::Shl => a.raw << b.raw.to_int()
        @parse.BinaryOp::Shr => a.raw >> b.raw.to_int()
        @parse.BinaryOp::And => a.raw & b.raw
        @parse.BinaryOp::Or => a.raw | b.raw
        @parse.BinaryOp::Xor => a.raw ^ b.raw
        @parse.BinaryOp::Nand => @utils.bitwise_not(a.raw & b.raw, width~)
        @parse.BinaryOp::Nor => @utils.bitwise_not(a.raw | b.raw, width~)
        @parse.BinaryOp::Xnor => @utils.bitwise_not(a.raw ^ b.raw, width~)
        @parse.BinaryOp::Equ => if a.raw == b.raw { 1 } else { 0 }
        @parse.BinaryOp::Neq => if a.raw != b.raw { 1 } else { 0 }
        @parse.BinaryOp::Lss => if a.raw < b.raw { 1 } else { 0 }
        @parse.BinaryOp::Gtr => if a.raw > b.raw { 1 } else { 0 }
        @parse.BinaryOp::Leq => if a.raw <= b.raw { 1 } else { 0 }
        @parse.BinaryOp::Geq => if a.raw >= b.raw { 1 } else { 0 }
        @parse.BinaryOp::Ternary => raise Failure::Failure("Invalid test expression")
      }
      let result_width = match op {
        @parse.BinaryOp::Equ | @parse.BinaryOp::Neq | @parse.BinaryOp::Lss |
        @parse.BinaryOp::Gtr | @parse.BinaryOp::Leq | @parse.BinaryOp::Geq => Some(1)
        @parse.BinaryOp::And | @parse.BinaryOp::Or | @parse.BinaryOp::Xor |
        @parse.BinaryOp::Nand | @parse.BinaryOp::Nor | @parse.BinaryOp::Xnor => Some(width)
        _ => None
      }
      TestValue::known(value, width=result_width)
    }
    @parse.Expr::FunCall(name="peek", args~, ..) if args.length() == 1 => {
      let port = test_port(ctx.dut, args[0])
      TestValue::from_typed_sim(ctx.tb.peek(port.name), port.ty)
    }
    _ => {
      let evaluated = expr.partial_eval() catch {
        _ => raise Failure::Failure("Test values must be integer expressions or peek!() values")
      }
      match evaluated {
        @parse.Expr::Natural(value~, width~, ..) => TestValue::known(value, width~)
        _ => raise Failure::Failure("Test values must be integer expressions or peek!() values")
      }
    }
  }
}

fn test_expect(ctx: TestRuntime, signal: String, expected: @simulator.SimValue, span: @parse.Span) -> Unit raise {
  let actual = ctx.tb.peek(signal)
  if actual.raw != expected.raw || actual.known_mask != expected.known_mask {
    raise Failure::Failure(
      "expectation failed for '\{signal}' at cycle \{ctx.tb.cycle()} (\{span}): expected \{expected}, got \{actual}",
    )
  }
}

fn ensure_test_simulation_active(tb: @simulator.Testbench) -> Unit raise {
  let status = tb.simulator().status()
  if status.failed {
    raise Failure::Failure("simulation assertion failed")
  }
  if status.exit_code is Some(code) && code != 0 {
    raise Failure::Failure("simulation stopped with exit code \{code}")
  }
  if status.halted {
    raise Failure::Failure("simulation stopped before the test completed")
  }
}

fn fit_test_local(value: TestValue, declared: @parse.Type?, span: @parse.Span) -> TestValue raise {
  match declared {
    Some(ty) => {
      let width = ty.width(span)
      let fitted = fit_test_value(value, width)
      match ty {
        @parse.Type::SInt(_) if width > 0 && fitted.is_known() && (fitted.raw & @utils.pow2(width - 1)) != 0 => {
          TestValue::known(fitted.raw - @utils.pow2(width), width=Some(width))
        }
        _ => TestValue::from_sim(fitted)
      }
    }
    None => value
  }
}

fn run_test_stmt(ctx: TestRuntime, stmt: @parse.Stmt) -> Unit raise {
  try run_test_stmt_inner(ctx, stmt) catch {
    err => raise Failure::Failure("\{stmt.span()}: \{err}")
  }
}

fn run_test_stmt_inner(ctx: TestRuntime, stmt: @parse.Stmt) -> Unit raise {
  match stmt {
    @parse.Stmt::Scope(body~, ..) => {
      let child = child_test_runtime(ctx)
      for nested in body { run_test_stmt(child, nested) }
    }
    @parse.Stmt::For(variable~, range~, body~, ..) => {
      let start = eval_test_expr(ctx, range.start).raw.to_int()
      let end = eval_test_expr(ctx, range.end).raw.to_int()
      if range.inclusive {
        for value in start..=end {
          let child = child_test_runtime(ctx)
          child.locals[variable] = TestValue::known(BigInt::from_int(value))
          for nested in body { run_test_stmt(child, nested) }
        }
      } else {
        for value in start..<end {
          let child = child_test_runtime(ctx)
          child.locals[variable] = TestValue::known(BigInt::from_int(value))
          for nested in body { run_test_stmt(child, nested) }
        }
      }
    }
    @parse.Stmt::Let(name~, ty~, expr=Some(expr), span~) => {
      match expr {
        @parse.Expr::Instance(..) => ()
        _ => {
          ctx.locals[name] = fit_test_local(eval_test_expr(ctx, expr), ty.val, span)
        }
      }
    }
    @parse.Stmt::Let(..) => raise Failure::Failure("Test let bindings require an initializer")
    @parse.Stmt::Const(decl~, ..) => {
      ctx.locals[decl.path.elem] = fit_test_local(eval_test_expr(ctx, decl.expr), decl.ty, decl.span)
    }
    @parse.Stmt::Assign(..) => raise Failure::Failure("assignments are not allowed in a test; use drive!()")
    @parse.Stmt::Expr(expr=@parse.Expr::FunCall(name~, args~, span~, ..), ..) => match name {
      "drive" => {
        if args.length() != 2 { raise Failure::Failure("drive! expects a signal and a value") }
        let signal = test_signal_name(ctx.dut, args[0])
        let current = ctx.tb.peek(signal)
        ctx.tb.poke(signal, fit_test_value(eval_test_expr(ctx, args[1]), current.width))
        ctx.tb.settle()
      }
      "expect" => {
        if args.length() != 2 { raise Failure::Failure("expect! expects a signal and a value") }
        let signal = test_signal_name(ctx.dut, args[0])
        let expected = fit_test_value(eval_test_expr(ctx, args[1]), ctx.tb.peek(signal).width)
        test_expect(ctx, signal, expected, span)
      }
      "step" => {
        let (clock, count_expr) = match args {
          [count] => (ctx.dut.default_clock.unwrap_or_error(Failure::Failure("step! shorthand requires exactly one clock port; specify step!(clock, cycles)")), count)
          [clock, count] => (test_signal_name(ctx.dut, clock), count)
          _ => raise Failure::Failure("step! expects a cycle count or a clock and cycle count")
        }
        let count_value = eval_test_expr(ctx, count_expr)
        if count_value.raw < 0 {
          raise Failure::Failure("step! cycle count must be non-negative")
        }
        let count = count_value.raw.to_int()
        ctx.tb.run(clock, count)
        ensure_test_simulation_active(ctx.tb)
      }
      "settle" => {
        if args.length() != 0 { raise Failure::Failure("settle! takes no arguments") }
        ctx.tb.settle()
      }
      "peek" => {
        if args.length() != 1 { raise Failure::Failure("peek! expects one signal") }
        let _ = ctx.tb.peek(test_signal_name(ctx.dut, args[0]))
      }
      _ => raise Failure::Failure("unknown test action '\{name}!'")
    }
    @parse.Stmt::Expr(..) => raise Failure::Failure("test expressions must be simulation actions")
  }
}

fn run_tests(frontend: FrontendPipeline, filter: String?, ext: @utils.Externals) -> Unit raise {
  let mut count = 0
  for td in frontend.tests {
    if filter is Some(name) && name != td.name { continue }
    count += 1
    let target_expr = test_target_expr(td).unwrap_or_error(
      Failure::Failure("Test '\{td.name}' has no DUT; add `for Module` or `let dut = Module()`"),
    )
    let target = test_target_name(target_expr).unwrap_or_error(
      Failure::Failure("Test DUT must be a module or module instance"),
    )
    let circuit = compile_simulation_frontend_with_top(frontend, displays=[], stream=None, top_override=Some(target))
    let sim = try @simulator.Simulator::from_circuit(circuit, target) catch {
      err => raise Failure::Failure("Could not prepare test '\{td.name}': \{@debug.to_string(err)}")
    }
    let tb = sim.testbench()
    let clocks = @simulator.simulator_clocks(sim)
    let default_clock = if clocks.length() == 1 { Some(clocks[0]) } else { None }
    let ports: Map[String, @parse.Port] = Map([])
    for port in frontend.test_modules.get(target).unwrap_or([]) { ports[port.name] = port }
    let dut = {
      binding: test_binding_name(td),
      ports,
      default_clock,
    }
    let ctx = { dut, tb, locals: Map([]) }
    try {
      for stmt in td.body { run_test_stmt(ctx, stmt) }
      ensure_test_simulation_active(tb)
    } catch {
      err => raise Failure::Failure("Test '\{td.name}' failed at \{td.span}: \{err}")
    }
    (ext.println)("PASS \{td.name}")
  }
  if count == 0 {
    raise Failure::Failure(match filter {
      Some(name) => "No test named '\{name}' was found"
      None => "No tests found"
    })
  }
}

/// Compile a Yodl source file to the normalized FIRRTL consumed by the
/// simulator.  This intentionally returns the in-memory typed circuit instead
/// of serializing and reparsing FIRRTL, so source tools and testbenches share
/// exactly the same elaboration and lowering semantics as the CLI.
pub fn compile_simulation(
  path~: String,
  ext~: @utils.Externals,
  top~: String? = None,
  displays~: Array[SimulationDisplay] = [],
  stream~: String? = None,
) -> @firrtl.TypedCircuit raise {
  let frontend = prepare_frontend(path, ext, top)
  compile_simulation_frontend(frontend, displays~, stream~)
}

fn compile_simulation_frontend(
  frontend: FrontendPipeline,
  displays~: Array[SimulationDisplay],
  stream~: String?,
) -> @firrtl.TypedCircuit raise {
  compile_simulation_frontend_with_top(frontend, displays~, stream~, top_override=None)
}

fn compile_simulation_frontend_with_top(
  frontend: FrontendPipeline,
  displays~: Array[SimulationDisplay],
  stream~: String?,
  top_override~: String?,
) -> @firrtl.TypedCircuit raise {
  let top = top_override.unwrap_or(frontend.top)
  let elaborator = @elaborate.Elaborator::new(top, port_usage=frontend.port_usage)
  try elaborator.lower(frontend.simplified_decls.iter()) catch {
    err => raise Failure::Failure(err.to_string())
  }
  let circuit = lower_firrtl(elaborator, passes=[])
  let pass = @firrtl.LowerAggregateTypesPass::new(split_memories=false, packed_bool_rows=true)
  let lowered = pass.prepare_simulation(circuit)
  let candidates = circuit.decls.filter_map(decl => match decl {
    @firrtl.Decl::Module(mod) if mod.id.inner() == top || mod.id.inner().has_suffix("_" + top) => Some(mod)
    _ => None
  })
  let mut selected = if candidates.length() == 1 { Some(candidates[0]) } else { None }
  for mod in candidates {
    if mod.id.inner() == top { selected = Some(mod) }
  }
  if selected is Some(mod) {
    for port in mod.ports {
      if port.dir is @parse.PortDir::Output &&
        port.ty is @firrtl.Type::Vec(@firrtl.Type::Vec(@firrtl.Type::UInt(bits), width), height) {
        let ports = []
        for row in 0..<height {
          let row_ref = @firrtl.Reference::StaticIndexing(lhs=@firrtl.Reference::Id(port.id, ty=port.ty), index=row, ty=@firrtl.Type::Vec(@firrtl.Type::UInt(bits), width))
          if bits == 1 {
            ports.push(pass.lowered_name(mod.id.inner(), row_ref).unwrap_or_error(Failure::Failure("Missing packed display row")))
          } else {
            for col in 0..<width {
              let reference = @firrtl.Reference::StaticIndexing(lhs=row_ref, index=col, ty=@firrtl.Type::UInt(bits))
              ports.push(pass.lowered_name(mod.id.inner(), reference).unwrap_or_error(Failure::Failure("Missing display element")))
            }
          }
        }
        displays.push({ buffer: port.id.inner(), stream: false, width, height, bits, ports })
      } else if stream == Some(port.id.inner()) && port.dir is @parse.PortDir::Output &&
        port.ty is @firrtl.Type::Bundle(fields) {
        let ports = []
        for required in ["x", "y", "valid", "r", "g", "b"] {
          let mut matched: @firrtl.BundleField? = None
          for field in fields {
            if field.id.inner() == required { matched = Some(field) }
          }
          let field = matched.unwrap_or_error(Failure::Failure("Stream '\{port.id.inner()}' is missing '\{required}'"))
          if !(field.ty is @firrtl.Type::UInt(_)) || (required == "valid" && !(field.ty is @firrtl.Type::UInt(1))) {
            raise Failure::Failure("Stream '\{port.id.inner()}'.\{required} has an unsupported type")
          }
          let reference = @firrtl.Reference::FieldAccess(
            lhs=@firrtl.Reference::Id(port.id, ty=port.ty),
            field=field.id,
            ty=field.ty,
          )
          ports.push(pass.lowered_name(mod.id.inner(), reference).unwrap_or_error(Failure::Failure("Missing lowered stream field '\{required}'")))
        }
        displays.push({ buffer: port.id.inner(), stream: true, width: 0, height: 0, bits: 0, ports })
      }
    }
  }
  lowered
}

pub(all) struct SimulationDisplay {
  buffer: String
  stream: Bool
  width: Int
  height: Int
  bits: Int
  ports: Array[String]
}

pub(all) struct SimulationResetConfiguration {
  signal: String
  cycles: Int
}

pub(all) struct SimulationDisplayConfiguration {
  buffer: String?
  stream: String?
  width: Int?
  height: Int?
  mode: String?
  packing: String?
  pixel_scale: Int?
  on_color: Int?
  off_color: Int?
}

pub(all) struct SimulationConfiguration {
  top: String
  clock: String?
  reset: SimulationResetConfiguration?
  display: SimulationDisplayConfiguration?
  cycles_per_frame: Int?
  clock_hz: Int?
}

pub(all) struct SimulationDesign {
  circuit: @firrtl.TypedCircuit
  compiled: @simulator.CompiledSimulation
  configuration: SimulationConfiguration
  top: String
  displays: Array[SimulationDisplay]
  clock: String?
  reset: String?
  reset_cycles: Int
}

pub fn compile_simulation_design(path~: String, ext~: @utils.Externals, top~: String? = None) -> SimulationDesign raise {
  let frontend = prepare_frontend(path, ext, top)
  let displays = []
  let metadata = simulation_metadata_from_package(frontend.pkg, top)
  let mut stream: String? = None
  for item in metadata {
    let (key, value) = item
    if key == "display.stream" { stream = Some(value) }
  }
  let circuit = compile_simulation_frontend(frontend, displays~, stream~)
  let mut selected_top = frontend.top
  let mut clock: String? = None
  let mut reset: String? = None
  let reset_cycles = 1
  for item in metadata {
    let (key, value) = item
    if key == "top" && top is None { selected_top = value }
    if key == "clock" { clock = Some(value) }
    if key == "reset" { reset = Some(value) }
  }
  let compiled = @simulator.compile_prepared_simulation(circuit, selected_top)
  let configuration = typed_simulation_configuration(metadata, selected_top)
  { circuit, compiled, configuration, top: selected_top, displays, clock, reset, reset_cycles }
}

fn metadata_string(metadata: Array[(String, String)], key: String) -> String? {
  for item in metadata { let (item_key, value) = item; if item_key == key { return Some(value) } }
  None
}

fn metadata_int(metadata: Array[(String, String)], key: String) -> Int? raise {
  guard metadata_string(metadata, key) is Some(value) else { return None }
  let mut result = 0
  if value.is_empty() { raise Failure::Failure("@simulation option '\{key}' must be an integer") }
  for char in value {
    if char < '0' || char > '9' { raise Failure::Failure("@simulation option '\{key}' must be a non-negative integer") }
    result = result * 10 + char.to_int() - '0'.to_int()
  }
  Some(result)
}

fn typed_simulation_configuration(metadata: Array[(String, String)], fallback_top: String) -> SimulationConfiguration raise {
  let location = metadata_string(metadata, "location").unwrap_or("@simulation")
  let buffer = metadata_string(metadata, "display.buffer")
  let stream = metadata_string(metadata, "display.stream")
  if buffer is Some(_) && stream is Some(_) { raise Failure::Failure("Choose either display.buffer or display.stream at \{location}") }
  let display_width = metadata_int(metadata, "display.width")
  let display_height = metadata_int(metadata, "display.height")
  let pixel_scale = metadata_int(metadata, "display.pixel_scale")
  for item in [("display.width", display_width), ("display.height", display_height), ("display.pixel_scale", pixel_scale)] {
    let (name, value) = item
    if value is Some(value) && value <= 0 { raise Failure::Failure("@simulation option '\{name}' must be positive at \{location}") }
  }
  let mode = metadata_string(metadata, "display.mode")
  if mode is Some(value) && !["binary", "gray", "rgb"].contains(value) { raise Failure::Failure("display.mode must be binary, gray, or rgb at \{location}") }
  let packing = metadata_string(metadata, "display.packing")
  if packing is Some(value) && !["bits", "bits32", "rgb332x4"].contains(value) { raise Failure::Failure("unsupported display.packing at \{location}") }
  if packing is Some(_) && (display_width is None || display_height is None) { raise Failure::Failure("explicit display packing requires width and height at \{location}") }
  let display = if buffer is Some(_) || stream is Some(_) {
    Some({
      buffer,
      stream,
      width: display_width,
      height: display_height,
      mode,
      packing,
      pixel_scale,
      on_color: metadata_int(metadata, "display.on_color"),
      off_color: metadata_int(metadata, "display.off_color"),
    })
  } else { None }
  let reset_signal = match metadata_string(metadata, "reset.signal") {
    Some(signal) => Some(signal)
    None => metadata_string(metadata, "reset")
  }
  let reset = reset_signal.map(signal => ({ signal, cycles: metadata_int(metadata, "reset.cycles").unwrap_or(1) } : SimulationResetConfiguration))
  let cycles_per_frame = metadata_int(metadata, "cycles_per_frame")
  let clock_hz = metadata_int(metadata, "clock_hz")
  if cycles_per_frame is Some(value) && value <= 0 { raise Failure::Failure("cycles_per_frame must be positive at \{location}") }
  if clock_hz is Some(value) && value <= 0 { raise Failure::Failure("clock_hz must be positive at \{location}") }
  {
    top: metadata_string(metadata, "top").unwrap_or(metadata_string(metadata, "module").unwrap_or(fallback_top)),
    clock: metadata_string(metadata, "clock"),
    reset,
    display,
    cycles_per_frame,
    clock_hz,
  }
}

/// Construct a browser simulator in the same linked module that prepared the
/// opaque design. Separate JavaScript bundles must not exchange MoonBit maps,
/// whose runtime representation is bundle-local.
pub fn new_compiled_simulation(design: SimulationDesign) -> @simulator.Simulator raise {
  @simulator.Simulator::from_compiled(design.compiled)
}

// Browser host operations live in this linked package so opaque simulator
// values never cross between independently generated MoonBit JavaScript
// runtimes.
pub fn host_simulator_poke(sim: @simulator.Simulator, name: String, width: Int, value: Int) -> Unit raise { @simulator.simulator_poke_int(sim, name, width, value) }
pub fn host_simulator_step(sim: @simulator.Simulator, clock: String) -> Unit raise { @simulator.simulator_step(sim, clock) }
pub fn host_simulator_settle(sim: @simulator.Simulator) -> Unit raise { @simulator.simulator_settle(sim) }
pub fn host_simulator_clocks(sim: @simulator.Simulator) -> Array[String] { @simulator.simulator_clocks(sim) }
pub fn host_simulator_drain_events(sim: @simulator.Simulator) -> Array[@simulator.SimMessage] { @simulator.simulator_drain_events(sim) }
pub fn host_simulator_status(sim: @simulator.Simulator) -> @simulator.SimulationStatus { @simulator.simulator_status(sim) }
pub fn host_simulator_exit_code(sim: @simulator.Simulator) -> Int { @simulator.simulator_exit_code(sim) }
pub fn host_simulator_exit_codes(sim: @simulator.Simulator) -> Array[Int] { @simulator.simulator_exit_codes(sim) }
pub fn host_simulator_set_history_retention(sim: @simulator.Simulator, retain: Bool) -> Unit { @simulator.simulator_set_history_retention(sim, retain) }
pub fn host_simulator_output_signals(sim: @simulator.Simulator) -> Array[@simulator.SimulatorSignal] { @simulator.simulator_output_signals(sim) }
pub fn host_simulator_inputs(sim: @simulator.Simulator) -> Array[@simulator.SimulatorSignal] { @simulator.simulator_inputs(sim) }
pub fn host_simulator_frame(sim: @simulator.Simulator, hidden: Array[String], width: Int, height: Int, packed_rows: Bool, binary: Bool) -> @simulator.SimulatorFrame raise { @simulator.simulator_frame_with_layout(sim, hidden, width, height, packed_rows~, binary~) }
pub fn host_simulator_halted(sim: @simulator.Simulator) -> Bool { @simulator.simulator_halted(sim) }
pub fn host_simulator_visible_outputs(sim: @simulator.Simulator, hidden: Array[String]) -> Array[@simulator.SimulatorSignal] { @simulator.simulator_visible_outputs(sim, hidden) }
pub fn host_simulator_raster_new(sim: @simulator.Simulator, stream: String, ports: Array[String], width: Int, height: Int) -> @simulator.SimulatorRaster raise { @simulator.simulator_raster_new_with_ports(sim, stream, ports, width, height) }
pub fn host_simulator_raster_step(sim: @simulator.Simulator, raster: @simulator.SimulatorRaster, clock: String, cycles: Int, until_frame: Bool) -> Int raise { @simulator.simulator_raster_step(sim, raster, clock, cycles, until_frame) }

/// Return the `@simulation` attribute attached to a source module as flat
/// key/value pairs. Hosts use this descriptor instead of trying to reparse
/// Yodl syntax in another language.
pub fn simulation_metadata(
  path~: String,
  ext~: @utils.Externals,
  top~: String? = None,
) -> Array[(String, String)] raise {
  let resolver = @simplify.Resolver::new(@utils.dir_name(path), fs=ext.fs)
  let pkg = try resolver.resolve(path~, is_top_package=true) catch {
    err => raise Failure::Failure(err.to_string())
  }
  simulation_metadata_from_package(pkg, top)
}

fn simulation_metadata_from_package(
  pkg: @parse.PackageDecl,
  top: String?,
) -> Array[(String, String)] raise {
  let result : Array[(String, String)] = []
  for decl in pkg.body {
    match decl {
      @parse.Decl::Module({ path, attributes, .. }) => {
        match attributes.get("simulation") {
          Some({ args: [@parse.AttributeValue::Dict(values)], span, .. }) => {
            let mut metadata_top = path.elem
            match values.get("top") {
              Some(@parse.AttributeValue::String(name)) => metadata_top = name
              _ => ()
            }
            if top.map(name => name != metadata_top).unwrap_or(false) {
              continue
            }
            result.push(("module", path.elem))
            result.push(("location", span.to_string()))
            for key, value in values {
              if !["top", "clock", "reset", "display", "cycles_per_frame", "clock_hz"].contains(key) {
                raise Failure::Failure("Unknown @simulation option '\{key}' at \{span}")
              }
              if key == "display" {
                match value {
                  @parse.AttributeValue::Dict(fields) => {
                    if !fields.contains("buffer") && !fields.contains("stream") {
                      raise Failure::Failure("display requires a buffer or stream at \{span}")
                    }
                  }
                  _ => raise Failure::Failure("display must be an object at \{span}")
                }
              }
              flatten_simulation_metadata(value, key, result~)
            }
            return result
          }
          _ => ()
        }
      }
      _ => ()
    }
  }
  result
}

fn flatten_simulation_metadata(
  value: @parse.AttributeValue,
  prefix: String,
  result~: Array[(String, String)],
) -> Unit {
  match value {
    @parse.AttributeValue::String(value) => result.push((prefix, value))
    @parse.AttributeValue::Int(value) => result.push((prefix, value.to_string()))
    @parse.AttributeValue::Dict(values) => {
      for key, value in values {
        flatten_simulation_metadata(value, prefix + "." + key, result~)
      }
    }
  }
}


const VERSION: String = "0.3.1"

pub fn cli(ext: @utils.Externals) -> Unit {
  match (ext.get_args)() {
    [_, path] => {
      try run(path~, commands=[WriteFIRRTL(path=Some(path.replace(old=".yodl", new=".fir")), passes=[])], ext~) catch {
        Failure::Failure(error) => {
          (ext.println)("\{error}")
          (ext.exit)(1)
        }
        error => {
          (ext.println)("\{error}")
          (ext.exit)(1)
        }
      }
    }
    [_, path, cmds] => {
      try parse_commands(cmds) catch {
        error => {
          (ext.println)(@debug.to_string(error))
          (ext.exit)(1)
        }
      } noraise {
        commands => {
          try run(path~, commands~, ext~) catch {
            error => {
              (ext.println)("\{error}")
              (ext.exit)(1)
            }
          }
        }
      }
    }
    _ => {
      (ext.println)("Yodl - Yet another hardware description language v\{VERSION}")
      (ext.println)("Usage: yodl <file> [commands]")
      (ext.println)("\nCommands are separated by semicolons ';'. Each command can optionally take a file path argument.")
      (ext.println)("Available commands:")
      (ext.println)("  write_source [path]     - Write the source code after parsing.")
      (ext.println)("  write_mono [path]       - Write the monomorphized code.")
      (ext.println)("  write_typed [path]      - Write the typed code.")
      (ext.println)("  write_simplified [path] - Write the simplified code.")
      (ext.println)("  write_firrtl [path]     - Write the FIRRTL output (alias: write_fir).")
      (ext.println)("  write_low_firrtl [path] - Write the low FIRRTL output (alias: write_lofir).")
      (ext.println)("  write_rtlil [path]      - Write the RTLIL output.")
      (ext.println)("  test [name]             - Run procedural testbenches, optionally filtered by name.")
      (ext.println)("\nExample: yodl my_design.yodl \"write_firrtl my_design.fir; write_typed my_design.typed.txt\"")
    }
  }
}

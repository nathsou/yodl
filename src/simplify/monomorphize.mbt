
pub struct Monomorphizer {
  modules: Map[String, @parse.ModuleDecl]
  parameterized: Map[String, @parse.ModuleDecl]
  monomorphized: Map[String, Array[MonomorphizedModule]]
  declared_modules: Map[String, @parse.ModuleSignature]
  top_env: MonoEnv
}

pub struct MonomorphizedModule {
  params: Array[Int]
  mod: @parse.ModuleDecl
}

pub fn Monomorphizer::new() -> Monomorphizer {
  {
    modules: {},
    parameterized: {},
    monomorphized: {},
    declared_modules: {},
    top_env: @elaborate.Scope::new(),
  }
}

pub type! MonomorphizerError {
  ModuleNotFound(name~: String, span~: @parse.Span)
  InvalidModuleParameterCount(name~: String, expected~: Int, actual~: Int, span~: @parse.Span)
  InvalidFunCallArity(name~: String, expected~: Int, actual~: Int, span~: @parse.Span)
}

pub impl Show for MonomorphizerError with output(self, logger) -> Unit {
  match self {
    ModuleNotFound(name~, ..) => {
      logger.write_string("Module '\{name}' not found")
    }
    InvalidModuleParameterCount(name~, expected~, actual~, ..) => {
      logger.write_string("Module '\{name}' expected \{expected} parameter(s), but got \{actual}")
    }
    InvalidFunCallArity(name~, expected~, actual~, ..) => {
      logger.write_string("Function '\{name}' expected \{expected} argument(s), but got \{actual}")
    }
  }

  logger.write_string(self.show_context())
}

pub impl @parse.Spanned for MonomorphizerError with span(self) -> @parse.Span {
  match self {
    ModuleNotFound(span~, ..) => span
    InvalidModuleParameterCount(span~, ..) => span
    InvalidFunCallArity(span~, ..) => span
  }
}

enum MonoEnvEntry {
  Param(Int)
  Const(@parse.ConstDecl)
}

typealias MonoEnv = @elaborate.Scope[MonoEnvEntry]

fn monomorphize_type(self: Monomorphizer, ty: @parse.Type, env~: MonoEnv) -> @parse.Type! {
  match ty {
    Vector(ty~, len~) => {
      let mono_ty = self.monomorphize_type!(ty, env~)
      let len = match len {
        Fixed(len) => @parse.VectorLen::Fixed(len)
        Dynamic(expr) => match self.monomorphize_expr!(expr, env~) {
          Natural(bits~, ..) => @parse.VectorLen::Fixed(bits.as_int!())
          expr => @parse.VectorLen::Dynamic(expr)
        }
      }

      @parse.Type::Vector(ty=mono_ty, len~)
    }
    _ => ty
  }
}

fn register_monomorphized_module(
  self: Monomorphizer,
  name~: String,
  params~: Array[Int],
  span~: @parse.Span,
) -> @parse.ModuleDecl! {
    let mod_decl = match self.parameterized[name] {
      Some(mod_decl) => mod_decl
      None => match self.modules[name] {
        Some(mod_decl) => mod_decl
        None => raise MonomorphizerError::ModuleNotFound(name~, span~)
      }
    }

    if mod_decl.params.length() != params.length() {
      raise InvalidModuleParameterCount(name~, expected=mod_decl.params.length(), actual=params.length(), span~)
    }

  let monomorphized = match self.monomorphized[name] {
    Some(monomorphized) => monomorphized
    None => []
  }

  for inst in monomorphized {
    if inst.params == params {
      return inst.mod
    }
  }

  let mono_mod = self.monomorphize_module!(mod=mod_decl, params~)
  monomorphized.push({ params, mod: mono_mod })
  self.monomorphized[name] = monomorphized
  self.modules[mono_mod.name] = mono_mod

  mono_mod
}

fn monomorphize_expr(self: Monomorphizer, expr: @parse.Expr, env~: MonoEnv) -> @parse.Expr! {
  @parse.rewrite_expr!(expr, fn(expr) {
    (match expr {
      Identifier(name~, span~, ty=_) => {
        match env.resolve(name) {
          Some(Param(n)) => @parse.Expr::nat!(n, width=None, base=10, span~)
          Some(Const(decl)) => decl.expr
          None => expr
        }
      }
      Instance(name~, params~, ports~, span~, ty~) => {
        let mono_params = []

        for param in params {
          mono_params.push(self.monomorphize_expr!(param, env~))
        }

        let (mono_name, mono_params) = if params.length() > 0 && not(self.declared_modules.contains(name)) {
          let mod = self.register_monomorphized_module!(
            name~,
            params={
              let params = []

              for param in mono_params {
                params.push(param.expect_int!())
              }

              params
            },
            span~,
          )

          (mod.name, [])
        } else {
          (name, mono_params)
        }

        let mono_ports = {}

        for port_name, port_expr in ports {
          mono_ports[port_name] = self.monomorphize_expr!(port_expr, env~)
        }

        @parse.Expr::Instance(name=mono_name, params=mono_params, ports=mono_ports, span~, ty~)
      }
      FunCall(name~, args~, span~, ty=_) => {
        let fun = match builtin_functions[name] {
          Some(fun) => fun
          None => return expr
        }

        if args.length() != fun.arity {
          raise InvalidFunCallArity(name~, expected=fun.arity, actual=args.length(), span~)
        }

        (fun.apply)!(args, span)
      }
      _ => expr
    }).partial_eval!()
  })
}

fn monomorphize_stmt(self: Monomorphizer, stmt: @parse.Stmt, env~: MonoEnv) -> @parse.Stmt! {
  match stmt {
    Expr(expr~, span~) => {
      let mono_expr = self.monomorphize_expr!(expr, env~)
      @parse.Stmt::Expr(expr=mono_expr, span~)
    }
    Let(name~, ty~, expr~, span~) => {
      let mono_expr = match expr {
        Some(expr) => Some(self.monomorphize_expr!(expr, env~))
        None => None
      }

      let mono_ty = match ty.val {
        Some(ty) => Some(self.monomorphize_type!(ty, env~))
        None => None
      }

      match ty.val {
        Some(Name(name~, params~)) => {
          if params.length() > 0 {
            let _ = self.register_monomorphized_module!(
              name~,
              params~,
              span~,
            )
          }
        }
        _ => ()
      }

      @parse.Stmt::Let(name=name, ty={ val: mono_ty }, expr=mono_expr, span~)
    }
    Assign(lhs~, rhs~, span~) => {
      let mono_lhs = self.monomorphize_expr!(lhs, env~)
      let mono_rhs = self.monomorphize_expr!(rhs, env~)
      @parse.Stmt::Assign(lhs=mono_lhs, rhs=mono_rhs, span~)
    }
    For(var~, range~, body~, span~) => {
      let mono_range: @parse.ForRange = {
        start: self.monomorphize_expr!(range.start, env~),
        end: self.monomorphize_expr!(range.end, env~),
        inclusive: range.inclusive,
      }

      let mono_body = []

      for stmt in body {
        mono_body.push(self.monomorphize_stmt!(stmt, env~))
      }

      @parse.Stmt::For(var~, range=mono_range, body=mono_body, span~)
    }
    Scope(body~, span~) => {
      let mono_body = []

      for stmt in body {
        mono_body.push(self.monomorphize_stmt!(stmt, env~))
      }

      @parse.Stmt::Scope(body=mono_body, span~)
    }
    Const(decl~, span~) => {
      let mono_expr = self.monomorphize_expr!(decl.expr, env~)
      let mono_ty = match decl.ty {
        Some(ty) => Some(self.monomorphize_type!(ty, env~))
        None => None
      }

      let mono_decl: @parse.ConstDecl = { name: decl.name, expr: mono_expr, ty: mono_ty, span: decl.span }
      env.declare!(decl.name, Const(mono_decl))
      @parse.Stmt::Const(decl=mono_decl, span~)
    }
  }
}

fn monomorphize_module(self: Monomorphizer, mod~: @parse.ModuleDecl, params~: Array[Int]) -> @parse.ModuleDecl! {
  let child_env = self.top_env.child()

  for name, param in @utils.zip2(mod.params, params) {
    child_env.declare!(name, Param(param))
  }

  let mono_ports: Array[@parse.Port] = []

  for port in mod.ports {
    mono_ports.push({
      name: port.name,
      ty: self.monomorphize_type!(port.ty, env=child_env),
      dir: port.dir,
      optional: port.optional,
      span: port.span,
      attributes: port.attributes,
    })
  }

  let mono_body = []

  for stmt in mod.body {
    mono_body.push(self.monomorphize_stmt!(stmt, env=child_env))
  }

  {
    name: {
      if params.is_empty() {
        mod.name
      } else {
        let builder = StringBuilder::new()
        builder.write_string(mod.name)
        if params.length() > 0 {
          builder.write_char('_')
          builder.write_string(String::concat(params.map(fn(n) { n.to_string() }), separator="_"))
        }
        builder.to_string()
      }
    },
    params: [],
    attributes: mod.attributes,
    ports: mono_ports,
    body: mono_body,
    span: mod.span,
  }
}

pub fn monomorphize(self: Monomorphizer, decls: Array[@parse.Decl]) -> Array[@parse.Decl]! {
  let monomorphized: Array[@parse.Decl] = []

  for decl in decls {
    match decl {
      Module(mod) => {
        if mod.params.is_empty() {
          let mono_mod = self.monomorphize_module!(mod~, params=[])
          self.modules[mod.name] = mono_mod
        } else {
          self.parameterized[mod.name] = mod
        }
      }
      ModuleDeclaration(sig) => {
        self.declared_modules[sig.name] = sig
      }
      Const(decl) => {
        let mono_expr = self.monomorphize_expr!(decl.expr, env=self.top_env)
        let mono_ty = match decl.ty {
          Some(ty) => Some(self.monomorphize_type!(ty, env=self.top_env))
          None => None
        }

        let mono_decl: @parse.ConstDecl = { name: decl.name, expr: mono_expr, ty: mono_ty, span: decl.span }
        monomorphized.push(@parse.Decl::Const(mono_decl))
        self.top_env.declare!(decl.name, Const(mono_decl))
      }
    }
  }

  for decl in self.declared_modules.values() {
    monomorphized.push(@parse.Decl::ModuleDeclaration(decl))
  }

  for mod in self.modules.values() {
    monomorphized.push(@parse.Decl::Module(mod))
  }

  monomorphized
}

struct BuiltinFunction {
  arity: Int
  apply: (Array[@parse.Expr], @parse.Span) -> @parse.Expr!
}

let builtin_functions: Map[String, BuiltinFunction] = {
  "$clog2": {
    arity: 1,
    apply: fn(args, span) {
      let arg = args[0].expect_int!()
      let value = @utils.clog2(arg)
      @parse.Expr::nat!(value, span~)
    }
  },
  "$pow": {
    arity: 2,
    apply: fn(args, span) {
      let base = args[0].expect_int!()
      let exp = args[1].expect_int!()
      @parse.Expr::nat!(@utils.pow(base, exp), span~)
    }
  },
  "$cdiv": {
    arity: 2,
    apply: fn(args, span) {
      let dividend = args[0].expect_int!()
      let divisor = args[1].expect_int!()
      @parse.Expr::nat!(@utils.cdiv(dividend, divisor), span~)
    }
  },
}

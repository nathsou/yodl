
typealias ParamsHash = UInt

pub struct Monomorphizer {
  modules: Map[@parse.Path, @parse.ModuleDecl]
  parameterized: Map[@parse.Path, @parse.ModuleDecl]
  monomorphized: Map[@parse.Path, Map[ParamsHash, @parse.ModuleDecl]]
  declared_modules: Map[@parse.Path, @parse.ModuleSignature]
  constants: Map[@parse.Path, @parse.ConstDecl]
  top_env: MonoEnv
}

pub fn Monomorphizer::new() -> Monomorphizer {
  {
    modules: {},
    parameterized: {},
    monomorphized: {},
    declared_modules: {},
    constants: {},
    top_env: @elaborate.Scope::new(),
  }
}

pub type! MonomorphizerError {
  ModuleNotFound(path~: @parse.Path, span~: @parse.Span)
  InvalidModuleParameterCount(path~: @parse.Path, expected~: Int, actual~: Int, span~: @parse.Span)
}

pub impl Show for MonomorphizerError with output(self, logger) -> Unit {
  match self {
    ModuleNotFound(path~, ..) => {
      logger.write_string("Module '\{path}' not found")
    }
    InvalidModuleParameterCount(path~, expected~, actual~, ..) => {
      logger.write_string("Module '\{path}' expected \{expected} parameter(s), but got \{actual}")
    }
  }

  logger.write_string(self.show_context())
}

pub impl @parse.Spanned for MonomorphizerError with span(self) -> @parse.Span {
  match self {
    ModuleNotFound(span~, ..) => span
    InvalidModuleParameterCount(span~, ..) => span
  }
}

enum MonoEnvEntry {
  Param(@parse.Param)
  Const(@parse.ConstDecl)
}

typealias MonoEnv = @elaborate.Scope[@parse.Path, MonoEnvEntry]

fn monomorphize_type(self: Monomorphizer, ty: @parse.Type, env~: MonoEnv, packages~: Array[String]) -> @parse.Type! {
  match ty {
    Vector(ty~, len~) => {
      let mono_ty = self.monomorphize_type!(ty, env~, packages~)
      let len = match len {
        Fixed(len) => @parse.VectorLen::Fixed(len)
        Dynamic(expr) => match self.monomorphize_expr!(expr, env~, packages~) {
          Natural(bits~, ..) => @parse.VectorLen::Fixed(bits.as_int!())
          expr => @parse.VectorLen::Dynamic(expr)
        }
      }

      @parse.Type::Vector(ty=mono_ty, len~)
    }
    _ => ty
  }
}

fn hash_params(params: Iter[@parse.Param]) -> UInt {
  let hasher = Hasher::new()

  for param in params {
    hasher.combine(param)
  }

  hasher.finalize().reinterpret_as_uint()
}

fn register_monomorphized_module(
  self: Monomorphizer,
  path~: @parse.Path,
  params~: @parse.InstanceParams,
  span~: @parse.Span,
  packages~: Array[String],
) -> @parse.ModuleDecl! {
  let mod_decl = match self.parameterized[path] {
    Some(mod_decl) => mod_decl
    None => match self.modules[path] {
      Some(mod_decl) => mod_decl
      None => raise MonomorphizerError::ModuleNotFound(path~, span~)
    }
  }

  if mod_decl.params.length() != params._.length() {
    raise InvalidModuleParameterCount(path~, expected=mod_decl.params.length(), actual=params._.length(), span~)
  }

  let params_map = {
    let map = Map::new(capacity=params._.length())

    for name, expr in params.as_map!(names=mod_decl.params) {
      map[name] = expr.as_param!()
    } 

    map
  }

  let hash = hash_params(params_map.values())
  let monomorphized = match self.monomorphized[path] {
    Some(modules) => modules
    None => {
      let modules = {}
      self.monomorphized[path] = modules
      modules
    }
  }

  match monomorphized[hash] {
    Some(mono_mod) => return mono_mod
    None => ()
  }

  let mono_path = @parse.Path::new(path.packages, "\{path.member}$\{monomorphized.size()}")
  let mono_mod = self.monomorphize_module!(mod=mod_decl, params=params_map, path=mono_path, packages~)
  monomorphized[hash] = mono_mod
  self.modules[mono_path] = mono_mod

  mono_mod
}

fn monomorphize_expr(self: Monomorphizer, expr: @parse.Expr, env~: MonoEnv, packages~: Array[String]) -> @parse.Expr! {
  @parse.rewrite_expr!(expr, fn(expr) {
    (match expr {
      Identifier(path~, span~, ty=_) => {
        // attempt to resolve the identifier in all the subpackages top-down
        let resolved = {
          if path.packages.is_empty() && packages.is_empty() {
            match env.resolve(path) {
              Some(entry) => Some(entry)
              None => None
            }
          } else {
            let subpackages = packages + path.packages

            while true {
              let subpath = @parse.Path::new(subpackages, path.member)

              match env.resolve(subpath) {
                Some(entry) => {
                  break Some(entry)
                }
                None => ()
              }

              if subpackages.is_empty() {
                break None
              } else {
                let _ = subpackages.pop()
              }
            } else {
              None
            }
          }
        }

        match resolved {
          Some(Param(Int(n))) => @parse.Expr::nat!(n, width=None, base=10, span~)
          Some(Param(Val(bits~, width~))) => @parse.Expr::Natural(bits~, width=Some(width), base=2, span~, ty={ val: None })
          Some(Const(decl)) => decl.expr
          None => Identifier(path~, span~, ty={ val: None })
        }
      }
      Instance(path~, params~, ports~, span~, ty=_) => {
        let full_path = path.prepend(packages)

        let (mono_path, mono_params) = if params._.length() > 0 && not(self.declared_modules.contains(path)) {
          let mod = self.register_monomorphized_module!(
            path=full_path,
            params~,
            span~,
            packages~,
          )

          (mod.path, @parse.InstanceParams([]))
        } else {
          let mono_params = params.map!(fn(expr) { self.monomorphize_expr!(expr, env~, packages~) })
          (path, mono_params)
        }

        let mono_ports = Map::new(capacity=ports.size())

        for port_name, port_expr in ports {
          mono_ports[port_name] = self.monomorphize_expr!(port_expr, env~, packages~)
        }

        @parse.Expr::Instance(
          path=mono_path,
          params=mono_params,
          ports=mono_ports,
          span~,
          ty={ val: None },
        )
      }
      _ => expr
    }).partial_eval!()
  })
}

fn monomorphize_stmt(self: Monomorphizer, stmt: @parse.Stmt, env~: MonoEnv, packages~: Array[String]) -> @parse.Stmt! {
  match stmt {
    Expr(expr~, span~) => {
      let mono_expr = self.monomorphize_expr!(expr, env~, packages~)
      @parse.Stmt::Expr(expr=mono_expr, span~)
    }
    Let(name~, ty~, expr~, span~) => {

      let mono_expr = match expr {
        Some(expr) => Some(self.monomorphize_expr!(expr, env~, packages~))
        None => None
      }

      let mono_ty = match ty.val {
        Some(ty) => Some(self.monomorphize_type!(ty, env~, packages~))
        None => None
      }

      match ty.val {
        Some(Name(path~, params~)) => {
          if params.length() > 0 {
            let _ = self.register_monomorphized_module!(
              path~,
              params=@parse.InstanceParams(
                @utils.map!(params, fn(param) { { name: None, value: param.as_expr!(span~) } })
              ),
              span~,
              packages~,
            )
          }
        }
        _ => ()
      }

      @parse.Stmt::Let(name~, ty={ val: mono_ty }, expr=mono_expr, span~)
    }
    Assign(lhs~, rhs~, span~) => {
      let mono_lhs = self.monomorphize_expr!(lhs, env~, packages~)
      let mono_rhs = self.monomorphize_expr!(rhs, env~, packages~)
      @parse.Stmt::Assign(lhs=mono_lhs, rhs=mono_rhs, span~)
    }
    For(var~, range~, body~, span~) => {
      let mono_range: @parse.ForRange = {
        start: self.monomorphize_expr!(range.start, env~, packages~),
        end: self.monomorphize_expr!(range.end, env~, packages~),
        inclusive: range.inclusive,
      }

      let mono_body = []

      for stmt in body {
        mono_body.push(self.monomorphize_stmt!(stmt, env~, packages~))
      }

      @parse.Stmt::For(var~, range=mono_range, body=mono_body, span~)
    }
    Scope(body~, span~) => {
      let mono_body = []

      for stmt in body {
        mono_body.push(self.monomorphize_stmt!(stmt, env~, packages~))
      }

      @parse.Stmt::Scope(body=mono_body, span~)
    }
    Const(decl~, span~) => {
      let mono_expr = self.monomorphize_expr!(decl.expr, env~, packages~)
      let mono_ty = match decl.ty {
        Some(ty) => Some(self.monomorphize_type!(ty, env~, packages~))
        None => None
      }

      let mono_decl: @parse.ConstDecl = { path: decl.path, expr: mono_expr, ty: mono_ty, span: decl.span }
      env.declare!(decl.path, Const(mono_decl))
      @parse.Stmt::Const(decl=mono_decl, span~)
    }
  }
}

fn monomorphize_module(
  self: Monomorphizer,
  mod~: @parse.ModuleDecl,
  params~: Map[String, @parse.Param],
  path~: @parse.Path,
  packages~: Array[String],
) -> @parse.ModuleDecl! {
  let child_env = self.top_env.child()
  let full_path = path.prepend(packages)

  for name, param in params {
    child_env.declare!(@parse.Path::new(full_path.packages, name), Param(param))
  }

  let mono_ports: Array[@parse.Port] = []

  for port in mod.ports {
    mono_ports.push({
      name: port.name,
      ty: self.monomorphize_type!(port.ty, env=child_env, packages~),
      dir: port.dir,
      optional: port.optional,
      span: port.span,
      attributes: port.attributes,
    })
  }

  let mono_body = []

  for stmt in mod.body {
    mono_body.push(self.monomorphize_stmt!(stmt, env=child_env, packages~))
  }

  {
    path: full_path,
    params: [],
    attributes: mod.attributes,
    ports: mono_ports,
    body: mono_body,
    span: mod.span,
  }
}

pub fn monomorphize(self: Monomorphizer, decls~: Array[@parse.Decl], packages~: Array[String]) -> Array[@parse.Decl]! {
  let monomorphized: Array[@parse.Decl] = []

  for decl in decls {
    match decl {
      Module(mod) => {
        if mod.params.is_empty() {
          let mono_mod = self.monomorphize_module!(mod~, params={}, path=mod.path, packages~)
          self.modules[mono_mod.path] = mono_mod
        } else {
          let mod_path = @parse.Path::new(packages + mod.path.packages, mod.path.member)
          self.parameterized[mod_path] = mod
        }
      }
      ModuleDeclaration(sig) => {
        let mod_path = @parse.Path::new(packages + sig.path.packages, sig.path.member)
        self.declared_modules[mod_path] = sig
      }
      Const(decl) => {
        let mono_expr = self.monomorphize_expr!(decl.expr, env=self.top_env, packages~)
        let mono_ty = match decl.ty {
          Some(ty) => Some(self.monomorphize_type!(ty, env=self.top_env, packages~))
          None => None
        }

        let mono_path = decl.path.prepend(packages)
        let mono_decl: @parse.ConstDecl = { path: mono_path, expr: mono_expr, ty: mono_ty, span: decl.span }
        self.top_env.declare!(mono_path, Const(mono_decl))
        self.constants[mono_path] = mono_decl
      }
      Package({ name, body, span: _ }) => {
        let _ = self.monomorphize!(decls=body, packages=packages + [name])
      }
    }
  }

  for cnst in self.constants.values() {
    monomorphized.push(@parse.Decl::Const(cnst))
  }

  for decl in self.declared_modules.values() {
    monomorphized.push(@parse.Decl::ModuleDeclaration(decl))
  }

  for mod in self.modules.values() {
    monomorphized.push(@parse.Decl::Module(mod))
  }

  monomorphized
}


typealias UInt as ParamsHash
typealias @utils.Scope as Scope

pub struct Monomorphizer {
  modules: Map[@parse.Path, @parse.ModuleDecl]
  parameterized: Map[@parse.Path, @parse.ModuleDecl]
  monomorphized: Map[@parse.Path, Map[ParamsHash, @parse.ModuleDecl]]
  declared_modules: Map[@parse.Path, @parse.ModuleSignature]
  instanciated_modules: Set[@parse.Path]
  constants: Map[@parse.Path, @parse.ConstDecl]
  type_aliases: Map[@parse.Path, @parse.TypeAliasDecl]
  top_env: MonoEnv
}

pub fn Monomorphizer::new() -> Monomorphizer {
  {
    modules: {},
    parameterized: {},
    monomorphized: {},
    declared_modules: {},
    instanciated_modules: Set::new(),
    constants: {},
    type_aliases: {},
    top_env: Scope::new(),
  }
}

pub suberror MonomorphizerError {
  ModuleNotFound(path~: @parse.Path, span~: @parse.Span)
  InvalidModuleParameterCount(path~: @parse.Path, expected~: Int, actual~: Int, span~: @parse.Span)
  ReceivedTypeParameterInsteadOfExpr(span~: @parse.Span)
  ReceivedTypeAliasInsteadOfExpr(span~: @parse.Span)
  InvalidParameterInstantiation(path~: @parse.Path, param~: String, span~: @parse.Span, param_span~: @parse.Span)
  InvalidTypeAliasParameters(path~: @parse.Path, exptected~: Int, actual~: Int, span~: @parse.Span)
  UnresolvedNamedType(path~: @parse.Path, span~: @parse.Span)
}

pub impl Show for MonomorphizerError with output(self, logger) -> Unit {
  match self {
    ModuleNotFound(path~, ..) => {
      logger.write_string("Module '\{path}' not found")
    }
    InvalidModuleParameterCount(path~, expected~, actual~, ..) => {
      logger.write_string("Module '\{path}' expected \{expected} parameter(s), but got \{actual}")
    }
    ReceivedTypeParameterInsteadOfExpr(..) => {
      logger.write_string("Received type parameter instead of expression")
    }
    InvalidParameterInstantiation(path~, param~, param_span~, ..) => {
      logger.write_string("Invalid instantiation of parameter '\{param}' in module '\{path}', declared at \{param_span}")
    }
    InvalidTypeAliasParameters(path~, exptected~, actual~, span~) => {
      logger.write_string("Invalid number of parameters for type alias '\{path}', expected \{exptected}, received \{actual} at \{span}")
    }
    UnresolvedNamedType(path~, span~) => {
      logger.write_string("Unresolved module name, constant or type alias '\{path}' at \{span}")
    }
    ReceivedTypeAliasInsteadOfExpr(..) => {
      logger.write_string("Received type alias instead of expression")
    }
  }

  logger.write_string(self.show_context(use_ansi_colors=false))
}

pub impl @parse.Spanned for MonomorphizerError with span(self) -> @parse.Span {
  match self {
    ModuleNotFound(span~, ..) => span
    InvalidModuleParameterCount(span~, ..) => span
    ReceivedTypeParameterInsteadOfExpr(span~) => span
    InvalidParameterInstantiation(span~, ..) => span
    InvalidTypeAliasParameters(span~, ..) => span
    UnresolvedNamedType(span~, ..) => span
    ReceivedTypeAliasInsteadOfExpr(span~) => span
  }
}

pub enum MonoEnvEntry {
  Param(@parse.ResolvedParam)
  Const(@parse.ConstDecl)
  Type(@parse.TypeAliasDecl)
  Name(packages~: Array[String])
  GenVar(Int)
}

typealias Scope[@parse.Path, MonoEnvEntry] as MonoEnv

fn monomorphize_int_param(self: Monomorphizer, param: @parse.IntParam, env~: MonoEnv, packages~: Array[String]) -> @parse.IntParam raise {
  match param {
    Fixed(value) => Fixed(value)
    Dynamic(expr) => match self.monomorphize_expr(expr, env~, packages~) {
      Natural(value~, ..) => Fixed(value.to_int())
      expr => Dynamic(expr)
    }
  }
}

priv struct TypeInfo {
  ty: @parse.Type
  is_type_alias: Bool 
}

fn resolve_param(self: Monomorphizer, param~: @parse.Param, env~: MonoEnv, packages~: Array[String]) -> @parse.ResolvedParam raise {
  match param {
    Unresolved(unresolved) => match unresolved {
      PathParam(path~, span~) => {
        match resolve_member(env, path~, packages~) {
          Some((Param(param), _)) => param
          Some((Const(decl), _)) => {
            match @parse.ConstValue::from(decl.expr.partial_eval()) {
              Some(value) => ConstParam(value~, span~)
              None => raise Failure("Non-constant expression in parameter")
            }
          }
          Some((Type(decl), _)) => TypeParam(ty=decl.ty, span~)
          Some((Name(_), _)) => raise Failure("Name parameters are not supported")
          Some((GenVar(_), _)) => raise Failure("GenVar parameters are not supported")
          None => {
            raise UnresolvedNamedType(path~, span~)
          }
        }
      }
      ExprParam(expr) => {
        let cnst = @parse.ConstValue::from(expr.partial_eval())
        
        if cnst is Some(value) {
          ConstParam(value~, span=expr.span())
        } else {
          raise Failure("Non-constant expression in parameter")
        }
      }
      TypeParam(ty~, span~) => @parse.ResolvedParam::TypeParam(ty=self.monomorphize_type(ty, env~, packages~, span~).ty, span~)
    }
    Resolved(param) => param
  }
}

fn monomorphize_type(self: Monomorphizer, ty: @parse.Type, env~: MonoEnv, packages~: Array[String], span~: @parse.Span) -> TypeInfo raise {
  let mono_ty: @parse.Type = match ty {
    UInt(width) => UInt(self.monomorphize_int_param(width, env~, packages~))
    SInt(width) => SInt(self.monomorphize_int_param(width, env~, packages~))
    Vector(ty~, len~) => {
      let mono_ty = self.monomorphize_type(ty, env~, packages~, span~).ty
      let len = self.monomorphize_int_param(len, env~, packages~)

      @parse.Type::Vector(ty=mono_ty, len~)
    }
    Struct(fields) => {
      let mono_fields = {}

      for name, ty in fields {
        mono_fields[name] = self.monomorphize_type(ty, env~, packages~, span~).ty
      }

      @parse.Type::Struct(mono_fields)
    }
    Name(path~, params~) => {
      fn substitute(type_alias: @parse.TypeAliasDecl) -> TypeInfo raise {
        if type_alias.parameters.length() != params.length() {
          raise InvalidTypeAliasParameters(
            path~,
            exptected=type_alias.parameters.length(),
            actual=params.length(),
            span=type_alias.span,
          )
        }

        let subst: Map[String, @parse.ResolvedParam] = {}

        for name, param in @utils.zip2(type_alias.parameters, params) {
          match param {
            Resolved(param) => subst[name] = param
            Unresolved(_) => subst[name] = self.resolve_param(param~, env~, packages~)
          }
        }
        
        { ty: type_alias.ty.substitute(subst, span~), is_type_alias: true }
      }

      if resolve_member(env, path~, packages~) is Some((Type(type_alias), _)) {
        return substitute(type_alias)
      }

      ty
    }
    Clock | Nat(_) | Instance(_) | String(_) => ty
  }

  { ty: mono_ty, is_type_alias: false }
}

fn hash_params(params: Iter[@parse.ResolvedParam]) -> UInt {
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
  env~: MonoEnv,
  span~: @parse.Span,
  packages~: Array[String],
) -> @parse.ModuleDecl raise {
  let mod_decl = match self.parameterized.get(path) {
    Some(mod_decl) => mod_decl
    None => match self.modules.get(path) {
      Some(mod_decl) => mod_decl
      None => raise UnresolvedNamedType(path~, span~)
    }
  }

  if mod_decl.params.length() != params.params.length() {
    raise InvalidModuleParameterCount(path~, expected=mod_decl.params.length(), actual=params.params.length(), span~)
  }

  let mod_sig = mod_decl.signature()

  let params_map = {
    let map: Map[String, @parse.ResolvedParam] = Map::new(capacity=params.params.length())

    for name, param in params.as_map(names=mod_decl.params.map(fn(param) { param.name })) {
      let param_sig = mod_sig.get_param(name).unwrap()
      let resolved_param = self.resolve_param(param~, env~, packages~)
      map[name] = resolved_param

      match (resolved_param, param_sig.ty) {
        (ConstParam(value~, span~), Type(ty)) => {
          params.instantiated.push((value.as_expr(), ty, span))
        }
        (TypeParam(_), AnyType) => ()
        _ => raise InvalidParameterInstantiation(path~, param=name, span=param.span(), param_span=param_sig.span)
      }
    }

    map
  }

  let hash = hash_params(params_map.values())
  let monomorphized = match self.monomorphized.get(path) {
    Some(modules) => modules
    None => {
      let modules = {}
      self.monomorphized[path] = modules
      modules
    }
  }

  if monomorphized.get(hash) is Some(mono_mod) {
    return mono_mod
  }

  let mono_path = @parse.Path::new(path.packages, "\{path.member}$\{monomorphized.size()}")
  let mono_mod = self.monomorphize_module(mod=mod_decl, params=params_map, path=mono_path, packages~)
  monomorphized[hash] = mono_mod
  self.modules[mono_path] = mono_mod

  mono_mod
}

fn[T] resolve_member(env: Scope[@parse.Path, T], path~: @parse.Path, packages~: Array[String]) -> (T, @parse.Path)? {
  // attempt to resolve the identifier in all the subpackages top-down
  match env.resolve(path) {
    Some(entry) => Some((entry, path))
    None => {
      let subpackages = Array::copy(packages)

      while true {
        let subpath = path.prepend(subpackages)

        if env.resolve(subpath) is Some(entry) {
          break Some((entry, subpath))
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
}

fn monomorphize_expr(self: Monomorphizer, expr: @parse.Expr, env~: MonoEnv, packages~: Array[String]) -> @parse.Expr raise {
  let rewr_stmt = fn(stmt) raise { Iter::singleton(self.monomorphize_stmt(stmt, env~, packages~)) }

  let res = @parse.rewrite_expr(expr, rewr_stmt~, rewr_expr=fn(expr) {
    (match expr {
      Identifier(path~, span~, ty=_) => Some({
        match resolve_member(env, path~, packages~) {
          Some((GenVar(n), _)) => @parse.Expr::nat(n, width=None, base=10, span~)
          Some((Param(ConstParam(value~, span=_)), _)) => value.as_expr()
          Some((Param(TypeParam(_)), _)) => raise ReceivedTypeParameterInsteadOfExpr(span~)
          Some((Const(decl), _)) => decl.expr
          Some((Type(_), _)) => raise ReceivedTypeAliasInsteadOfExpr(span~)
          Some((Name(_), resolved_path)) => @parse.Expr::Identifier(path=resolved_path, span~, ty={ val: None })
          None => Identifier(path~, span~, ty={ val: None })
        }
      })
      Instance(path~, params~, ports~, span~, ty=_) as inst => {
        let resolved_path = match resolve_member(env, path~, packages~) {
          Some((Name(packages~), resolved_path)) => resolved_path.prepend(packages)
          _ => {
            // check if this module has already been monomorphized
            for mods in self.monomorphized.values() {
              for mod in mods.values() {
                if mod.path == path {
                  return Some(inst)
                }
              }
            }

            raise ModuleNotFound(path~, span~)
          }
        }

        self.instanciated_modules.add(resolved_path)

        let (mono_path, mono_params) = if params.params.length() > 0 && not(self.declared_modules.contains(path)) {
          let mod = self.register_monomorphized_module(
            path=resolved_path,
            params~,
            env~,
            span~,
            packages~,
          )

          let inst_params: @parse.InstanceParams = {
            params: [],
            instantiated: params.instantiated,
          }

          (mod.path, inst_params)
        } else {
          let mono_params = params.map(
            map_expr=fn(expr) { self.monomorphize_expr(expr, env~, packages~) },
            map_type=fn(ty) { self.monomorphize_type(ty, env~, packages~, span~).ty },
          )

          let resolved_params = []

          for entry in mono_params.params {
            let (name, param) = entry
            resolved_params.push((name, @parse.Resolved(self.resolve_param(param~, env~, packages~))))
          }

          (resolved_path, { params: resolved_params, instantiated: params.instantiated })
        }

        Some(@parse.Expr::Instance(
          path=mono_path,
          params=mono_params,
          ports~,
          span~,
          ty={ val: None },
        ))
      }
      _ => None
    })
  })

  res.partial_eval()
}

fn monomorphize_stmt(self: Monomorphizer, stmt: @parse.Stmt, env~: MonoEnv, packages~: Array[String]) -> @parse.Stmt raise {
  match stmt {
    Expr(expr~, span~) => {
      let mono_expr = self.monomorphize_expr(expr, env~, packages~)
      @parse.Stmt::Expr(expr=mono_expr, span~)
    }
    Let(name~, ty~, expr~, span~) => {
      let mono_expr = match expr {
        Some(expr) => Some(self.monomorphize_expr(expr, env~, packages~))
        None => None
      }

      let mut is_type_alias = false

      let mono_ty = match ty.val {
        Some(ty) => {
          let ty_info = self.monomorphize_type(ty, env~, packages~, span~)
          is_type_alias = ty_info.is_type_alias
          Some(ty_info.ty)
        }
        None => None
      }

      match mono_ty {
        Some(Name(path~, params~)) => {
          if not(is_type_alias) && params.length() > 0 {
            let _ = self.register_monomorphized_module(
              path~,
              params=@parse.InstanceParams::new(@utils.map(params, fn(param) { (None, param) })),
              env~,
              span~,
              packages~,
            )
          }
        }
        _ => ()
      }

      // ignore duplicate declarations as these will be caught by the type checker
      env.declare_shadowing(@parse.Path::new([], name), Name(packages=[]))

      @parse.Stmt::Let(name~, ty={ val: mono_ty }, expr=mono_expr, span~)
    }
    Assign(lhs~, rhs~, span~) => {
      let mono_lhs = self.monomorphize_expr(lhs, env~, packages~)
      let mono_rhs = self.monomorphize_expr(rhs, env~, packages~)
      @parse.Stmt::Assign(lhs=mono_lhs, rhs=mono_rhs, span~)
    }
    For(var~, range~, body~, span~) => {
      let start = self.monomorphize_expr(range.start, env~, packages~).as_int()
      let mut end = self.monomorphize_expr(range.end, env~, packages~).as_int()
      let unrolled_stmts = []

      if range.inclusive {
        end += 1
      }

      let var_path = @parse.Path::new([], var)

      for i in start..<end {
        env.declare(var_path, GenVar(i))
        let scope = []
        let scope_env = env.child()

        for stmt in body {
          scope.push(self.monomorphize_stmt(stmt, env=scope_env, packages~))
        }

        unrolled_stmts.push(@parse.Stmt::Scope(body=scope, span~))

        env.remove(var_path)
      }

      Scope(body=unrolled_stmts, span~)
    }
    Scope(body~, span~) => {
      let mono_body = []
      let scope_env = env.child()

      for stmt in body {
        mono_body.push(self.monomorphize_stmt(stmt, env=scope_env, packages~))
      }

      @parse.Stmt::Scope(body=mono_body, span~)
    }
    Const(decl~, span~) => {
      let mono_expr = self.monomorphize_expr(decl.expr, env~, packages~)
      let mono_ty = match decl.ty {
        Some(ty) => Some(self.monomorphize_type(ty, env~, packages~, span~).ty)
        None => None
      }

      let mono_decl: @parse.ConstDecl = { path: decl.path, expr: mono_expr, ty: mono_ty, span: decl.span }
      env.declare(decl.path, Const(mono_decl))
      @parse.Stmt::Const(decl=mono_decl, span~)
    }
  }
}

fn monomorphize_module(
  self: Monomorphizer,
  mod~: @parse.ModuleDecl,
  params~: Map[String, @parse.ResolvedParam],
  path~: @parse.Path,
  packages~: Array[String],
) -> @parse.ModuleDecl raise {
  let child_env = self.top_env.child()
  let full_path = path.prepend(packages)

  for name, param in params {
    child_env.declare(@parse.Path::new([], name), Param(param))
  }

  let mono_ports: Array[@parse.Port] = []

  for port in mod.ports {
    mono_ports.push({
      name: port.name,
      ty: self.monomorphize_type(port.ty, env=child_env, packages=full_path.packages, span=mod.span).ty,
      flow: port.flow,
      optional: port.optional,
      span: port.span,
      attributes: port.attributes,
    })
  }

  let mono_body = []

  for stmt in mod.body {
    mono_body.push(self.monomorphize_stmt(stmt, env=child_env, packages=full_path.packages))
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

pub fn monomorphize(self: Monomorphizer, decls~: Array[@parse.Decl], packages~: Array[String]) -> Array[@parse.Decl] raise {
  let monomorphized = Array::new(capacity=decls.length())

  for decl in decls {
    match decl {
      Module(mod) => {
        if mod.params.is_empty() {
          let mono_mod = self.monomorphize_module(mod~, params={}, path=mod.path, packages~)
          self.modules[mono_mod.path] = mono_mod
          self.top_env.declare(mono_mod.path, Name(packages~))
        } else {
          let mod_path = mod.path.prepend(packages)
          self.parameterized[mod_path] = mod
          self.top_env.declare(mod_path, Name(packages~))
        }
      }
      ModuleDeclaration(sig) => {
        let mod_path = sig.path.prepend(packages)
        self.declared_modules[mod_path] = sig
        self.top_env.declare(mod_path, Name(packages~))
      }
      Const(decl) => {
        let mono_expr = self.monomorphize_expr(decl.expr, env=self.top_env, packages~)
        let mono_ty = match decl.ty {
          Some(ty) => Some(self.monomorphize_type(ty, env=self.top_env, packages~, span=decl.span).ty)
          None => None
        }

        let mono_path = decl.path.prepend(packages)
        let mono_decl: @parse.ConstDecl = { path: mono_path, expr: mono_expr, ty: mono_ty, span: decl.span }
        self.top_env.declare(mono_path, Const(mono_decl))
        self.constants[mono_path] = mono_decl
      }
      Package({ name, body, span: _ }) => {
        let _ = self.monomorphize(decls=body, packages=packages + [name])
      }
      Import(_) => ()
      TypeAlias({ name, parameters, ty, span } as decl) => {
        let path = @parse.Path::new(packages, name)
        let mono_ty = self.monomorphize_type(ty, env=self.top_env, packages~, span~).ty
        self.top_env.declare(path, Type(decl))
        self.type_aliases[path] = {
          name,
          parameters,
          ty: mono_ty,
          span,
        }
      }
    }
  }

  for constant in self.constants.values() {
    monomorphized.push(@parse.Decl::Const(constant))
  }

  for decl in self.declared_modules.values() {
    monomorphized.push(@parse.Decl::ModuleDeclaration(decl))
  }

  for mod in self.modules.values() {
    monomorphized.push(@parse.Decl::Module(mod))
  }

  monomorphized
}

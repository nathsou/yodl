using @utils { type Scope }

type ParamsHash = UInt

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
    instanciated_modules: Set([]),
    constants: {},
    type_aliases: {},
    top_env: Scope::new(),
  }
}

pub suberror MonomorphizerError {
  ModuleNotFound(path~: @parse.Path, span~: @parse.Span)
  InvalidModuleParameterCount(path~: @parse.Path, expected~: Int, actual~: Int, span~: @parse.Span)
  ReceivedTypeParameterInsteadOfExpr(span~: @parse.Span)
  InvalidParameter(sort~: @parse.ParamSort, span~: @parse.Span)
  InvalidSizeFunctionDomain(message~: String, span~: @parse.Span)
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
      logger.write_string("Type parameter used where a value (Nat) is expected: consider changing the sort from 'Type' to 'Nat'")
    }
    InvalidParameter(sort~, span~) => {
      logger.write_string("Invalid parameter of sort '\{sort}' at \{span}")
    }
    InvalidSizeFunctionDomain(message~, ..) => {
      logger.write_string(message)
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

  logger.write_string(@parse.Spanned::show_context(self, use_ansi_colors=false))
}

pub impl @parse.Spanned for MonomorphizerError with span(self) -> @parse.Span {
  match self {
    ModuleNotFound(span~, ..) => span
    InvalidModuleParameterCount(span~, ..) => span
    ReceivedTypeParameterInsteadOfExpr(span~) => span
    InvalidParameter(span~, ..) => span
    InvalidSizeFunctionDomain(span~, ..) => span
    InvalidParameterInstantiation(span~, ..) => span
    InvalidTypeAliasParameters(span~, ..) => span
    UnresolvedNamedType(span~, ..) => span
    ReceivedTypeAliasInsteadOfExpr(span~) => span
  }
}

pub enum MonoEnvEntry {
  Param(@parse.StaticArg)
  Const(@parse.ConstDecl)
  Type(@parse.TypeAliasDecl)
  Name(packages~: Array[String])
  GenVar(Int)
}

type MonoEnv = Scope[@parse.Path, MonoEnvEntry]

fn Monomorphizer::monomorphize_index_expr(_ : Self, idx : @parse.IndexExpr, env~ : MonoEnv, packages~ : Array[String]) -> @parse.IndexExpr raise {
  idx.map_vars(fn(name) raise {
    let path = @parse.Path::new([], name)
    match resolve_member(env, path~, packages~) {
      Some((Param(NatParam(value=Natural(value~, ..), ..)), _)) =>
        @parse.IndexExpr::Lit(value.to_int())
      Some((Const(decl), _)) =>
        match @parse.ConstValue::from(decl.expr.partial_eval()) {
          Some(Natural(value~, ..)) => @parse.IndexExpr::Lit(value.to_int())
          _ => @parse.IndexExpr::Var(name)
        }
      Some((GenVar(n), _)) => @parse.IndexExpr::Lit(n)
      _ => @parse.IndexExpr::Var(name)
    }
  })
}

priv struct TypeInfo {
  ty: @parse.Type
  is_type_alias: Bool 
}

fn Monomorphizer::resolve_param(self: Self, param~: @parse.Param, sort~: @parse.ParamSort, env~: MonoEnv, packages~: Array[String]) -> @parse.StaticArg raise {
  match param {
    Unresolved(unresolved) => match unresolved.parse(sort) {
      ExprParam(expr~, span~) => {
        let mono_expr = try self.monomorphize_expr(expr, env~, packages~) catch {
          @parse.InvalidSizeFunctionDomain(message~, ..) =>
            raise InvalidSizeFunctionDomain(message~, span~)
          err => raise err
        }
        let value = match @parse.ConstValue::from(mono_expr) {
          Some(val) => val
          _ => raise InvalidParameter(sort~, span~)
        }
        @parse.NatParam(value~, span~)
      }
      TypeParam(ty~, span~) => {
        let mono_ty_info = self.monomorphize_type(ty, env~, packages~, span~)
        @parse.TypeParam(ty=mono_ty_info.ty, span~)
      }
    }
    Resolved(param) => param
  }
}

fn Monomorphizer::monomorphize_type(self: Self, ty: @parse.Type, env~: MonoEnv, packages~: Array[String], span~: @parse.Span) -> TypeInfo raise {
  let mono_ty: @parse.Type = match ty {
    UInt(idx) => UInt(self.monomorphize_index_expr(idx, env~, packages~))
    SInt(idx) => SInt(self.monomorphize_index_expr(idx, env~, packages~))
    Vector(ty~, len~) => {
      let mono_ty = self.monomorphize_type(ty, env~, packages~, span~).ty
      let len = self.monomorphize_index_expr(len, env~, packages~)

      @parse.Type::Vector(ty=mono_ty, len~)
    }
    Struct(fields) => {
      let mono_fields = Map([])

      for name, ty in fields {
        mono_fields[name] = self.monomorphize_type(ty, env~, packages~, span~).ty
      }

      @parse.Type::Struct(mono_fields)
    }
    Name(path~, params~) => {
      if params.is_empty() && resolve_member(env, path~, packages~) is Some((Param(TypeParam(ty~, ..)), _)) {
        return { ty, is_type_alias: false }
      }

      fn substitute(type_alias: @parse.TypeAliasDecl) -> TypeInfo raise {
        if type_alias.parameters.length() != params.length() {
          raise InvalidTypeAliasParameters(
            path~,
            exptected=type_alias.parameters.length(),
            actual=params.length(),
            span=type_alias.span,
          )
        }

        let subst: Map[String, @parse.StaticArg] = Map([])

        for static_param, ty in @utils.zip2(type_alias.parameters, params) {
          let mono_ty = self.monomorphize_type(ty, env~, packages~, span~).ty
          subst[static_param.name] = @parse.TypeParam(ty=mono_ty, span~)
        }
        
        { ty: type_alias.ty.substitute(subst, span~), is_type_alias: true }
      }

      if resolve_member(env, path~, packages~) is Some((Type(type_alias), _)) {
        return substitute(type_alias)
      }

      ty
    }
    Clock | Instance(_) | String(_) | Unit => ty
    MemoryMask(ty) => @parse.Type::MemoryMask(self.monomorphize_type(ty, env~, packages~, span~).ty)
  }

  { ty: mono_ty, is_type_alias: false }
}

fn hash_params(params: Iter[@parse.StaticArg]) -> UInt {
  let hasher = Hasher()

  for param in params {
    hasher.combine(param)
  }

  hasher.finalize().reinterpret_as_uint()
}

fn Monomorphizer::register_monomorphized_module(
  self: Self,
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
    let map: Map[String, @parse.StaticArg] = Map([], capacity=params.params.length())

    for name, param in params.as_map(names=mod_decl.params.map(fn(param) { param.name })) {
      let param_sig = mod_sig.get_param(name).unwrap()
      let resolved_param = self.resolve_param(param~, env~, packages~, sort=param_sig.sort)
      map[name] = resolved_param

      match (resolved_param, param_sig.sort) {
        (NatParam(value~, ..), NatSort) => {
          match value {
            Natural(value~, ..) => {
              if value < 0 {
                raise InvalidParameter(sort=NatSort, span=param.span())
              }
            }
            _ => raise InvalidParameter(sort=NatSort, span=param.span())
          }
        }
        (TypeParam(_), TypeSort) => ()
        _ => raise InvalidParameterInstantiation(path~, param=name, span=param.span(), param_span=param_sig.span)
      }
    }

    map
  }

  let hash = hash_params(params_map.values())
  let monomorphized = match self.monomorphized.get(path) {
    Some(modules) => modules
    None => {
      let modules = Map([])
      self.monomorphized[path] = modules
      modules
    }
  }

  if monomorphized.get(hash) is Some(mono_mod) {
    return mono_mod
  }

  let mono_path = @parse.Path::new(path.packages, "\{path.elem}$\{monomorphized.length()}")
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
      } nobreak {
        None
      }
    }
  }
}

fn Monomorphizer::monomorphize_expr(self: Self, expr: @parse.Expr, env~: MonoEnv, packages~: Array[String]) -> @parse.Expr raise {
  let rewr_stmt = fn(stmt) raise { Iter::singleton(self.monomorphize_stmt(stmt, env~, packages~)) }

  let res = @parse.rewrite_expr(expr, { rewr_stmt, rewr_expr: expr => {
    (match expr {
      Identifier(path~, span~, ty=_) => Some({
        match resolve_member(env, path~, packages~) {
          Some((GenVar(n), _)) => @parse.Expr::nat(n, width=None, base=10, span~)
          Some((Param(NatParam(value~, span=_)), _)) => value.as_expr()
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

        let (mono_path, mono_params) = if params.params.length() > 0 && !self.declared_modules.contains(path) {
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
          let mod_sig = match self.declared_modules.get(resolved_path) {
            Some(sig) => sig
            None => match self.modules.get(resolved_path) {
              Some(mod) => mod.signature()
              None => match self.parameterized.get(resolved_path) {
                Some(mod) => mod.signature()
                None => raise ModuleNotFound(path~, span~)
              }
            }
          }
          let mono_params = params.map_raw(
            map_type=ty => { self.monomorphize_type(ty, env~, packages~, span~).ty },
          )

          let resolved_params = []

          for entry in mono_params.params.zip_to_iter2(mod_sig.params) {
            let ((name, param), param_sig) = entry
            resolved_params.push((name, @parse.Resolved(self.resolve_param(param~, env~, packages~, sort=param_sig.sort))))
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
  }})

  res.partial_eval()
}

fn Monomorphizer::monomorphize_stmt(self: Self, stmt: @parse.Stmt, env~: MonoEnv, packages~: Array[String]) -> @parse.Stmt raise {
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

      let mono_ty = match mono_ty {
        Some(Name(path~, params~)) if !is_type_alias && params.length() > 0 => {
          let resolved_path = match resolve_member(env, path~, packages~) {
            Some((MonoEnvEntry::Name(packages=member_packages), resolved_path)) => resolved_path.prepend(member_packages)
            _ => raise UnresolvedNamedType(path~, span~)
          }
          if self.declared_modules.contains(resolved_path) {
            Some(@parse.Type::Name(path=resolved_path, params~))
          } else {
            let mod = self.register_monomorphized_module(
              path=resolved_path,
              params=@parse.InstanceParams::new(@utils.map(params, fn(ty) {
                (None, @parse.Resolved(@parse.TypeParam(ty~, span~)))
              })),
              env~,
              span~,
              packages~,
            )
            Some(@parse.Type::Name(path=mod.path, params=[]))
          }
        }
        other => other
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
    For(variable~, range~, body~, span~) => {
      let start = self.monomorphize_expr(range.start, env~, packages~).as_int()
      let mut end = self.monomorphize_expr(range.end, env~, packages~).as_int()
      let unrolled_stmts = []

      if range.inclusive {
        end += 1
      }

      let var_path = @parse.Path::new([], variable)

      for i in start..<end {
        env.declare_(var_path, GenVar(i))
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
      env.declare_(decl.path, Const(mono_decl))
      @parse.Stmt::Const(decl=mono_decl, span~)
    }
  }
}

fn Monomorphizer::monomorphize_module(
  self: Self,
  mod~: @parse.ModuleDecl,
  params~: Map[String, @parse.StaticArg],
  path~: @parse.Path,
  packages~: Array[String],
) -> @parse.ModuleDecl raise {
  let child_env = self.top_env.child()
  let full_path = path.prepend(packages)

  for name, param in params {
    child_env.declare_(@parse.Path::new([], name), Param(param))
  }

  let mono_ports: Array[@parse.Port] = []

  for port in mod.ports {
    mono_ports.push({
      name: port.name,
      ty: self.monomorphize_type(port.ty, env=child_env, packages=full_path.packages, span=mod.span).ty,
      dir: port.dir,
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

pub fn Monomorphizer::monomorphize(self: Self, decls~: Array[@parse.Decl], packages~: Array[String]) -> Array[@parse.Decl] raise {
  let monomorphized = Array::new(capacity=decls.length())

  for decl in decls {
    match decl {
      Module(mod) => {
        if mod.params.is_empty() {
          let mono_mod = self.monomorphize_module(mod~, params={}, path=mod.path, packages~)
          self.modules[mono_mod.path] = mono_mod
          self.top_env.declare_(mono_mod.path, Name(packages~))
        } else {
          let mod_path = mod.path.prepend(packages)
          self.parameterized[mod_path] = mod
          self.top_env.declare_(mod_path, Name(packages~))
        }
      }
      ModuleDeclaration(sig) => {
        let mod_path = sig.path.prepend(packages)
        self.declared_modules[mod_path] = sig
        self.top_env.declare_(mod_path, Name(packages~))
      }
      Const(decl) => {
        let mono_expr = self.monomorphize_expr(decl.expr, env=self.top_env, packages~)
        let mono_ty = match decl.ty {
          Some(ty) => Some(self.monomorphize_type(ty, env=self.top_env, packages~, span=decl.span).ty)
          None => None
        }

        let mono_path = decl.path.prepend(packages)
        let mono_decl: @parse.ConstDecl = { path: mono_path, expr: mono_expr, ty: mono_ty, span: decl.span }
        self.top_env.declare_(mono_path, Const(mono_decl))
        self.constants[mono_path] = mono_decl
      }
      Package({ name, body, span: _ }) => {
        let _ = self.monomorphize(decls=body, packages=packages + [name])
      }
      Import(_) => ()
      TypeAlias({ name, parameters, ty, span } as decl) => {
        let path = @parse.Path::new(packages, name)
        let mono_ty = self.monomorphize_type(ty, env=self.top_env, packages~, span~).ty
        self.top_env.declare_(path, Type(decl))
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

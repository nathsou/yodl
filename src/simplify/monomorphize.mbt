
pub(readonly) struct Monomorphizer {
  modules: Map[String, @parse.ModuleDecl]
  parameterized: Map[String, @parse.ModuleDecl]
  monomorphized: Map[String, Array[MonomorphizedModule]]
  declared_modules: Map[String, @parse.ModuleSignature]
}

pub(readonly) struct MonomorphizedModule {
  params: Array[Int]
  mod: @parse.ModuleDecl
}

pub fn Monomorphizer::new() -> Monomorphizer {
  {
    modules: {},
    parameterized: {},
    monomorphized: {},
    declared_modules: {},
  }
}

pub(readonly) type! MonomorphizerError {
  ModuleNotFound(name~: String, span~: @parse.Span)
  InvalidModuleParameterCount(name~: String, expected~: Int, actual~: Int, span~: @parse.Span)
} derive(Show)

fn monomorphize_type(self: Monomorphizer, ty: @parse.Type, params_env~: @elaborate.Scope[Int]) -> @parse.Type!Error {
  match ty {
    Vector(ty~, len~) => {
      let mono_ty = self.monomorphize_type!(ty, params_env~)
      let len = match len {
        Fixed(len) => @parse.VectorLen::Fixed(len)
        Dynamic(expr) => match self.monomorphize_expr!(expr, params_env~) {
          Natural(value~, ..) => @parse.VectorLen::Fixed(value)
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
) -> @parse.ModuleDecl!Error {
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

fn monomorphize_expr(self: Monomorphizer, expr: @parse.Expr, params_env~: @elaborate.Scope[Int]) -> @parse.Expr!Error {
  let res = match expr {
    Natural(_) => expr
    Identifier(name~, span~, ty~) => {
      match params_env.resolve(name) {
        Some(value) => @parse.Expr::Natural(value=value, width=None, span~, ty~)
        None => expr
      }
    }
    Unary(op~, expr~, span~, ty~) => {
      let mono_expr = self.monomorphize_expr!(expr, params_env~)
      @parse.Expr::Unary(op~, expr=mono_expr, span~, ty~)
    }
    Binary(op~, lhs~, rhs~, span~, ty~) => {
      let mono_lhs = self.monomorphize_expr!(lhs, params_env~)
      let mono_rhs = self.monomorphize_expr!(rhs, params_env~)
      @parse.Expr::Binary(op~, lhs=mono_lhs, rhs=mono_rhs, span~, ty~)
    }
    Indexing(expr~, index~, span~, ty~) => {
      let mono_expr = self.monomorphize_expr!(expr, params_env~)
      let mono_index = self.monomorphize_expr!(index, params_env~)
      @parse.Expr::Indexing(expr=mono_expr, index=mono_index, span~, ty~)
    }
    Slicing(expr~, msb~, lsb~, span~, ty~) => {
      let mono_expr = self.monomorphize_expr!(expr, params_env~)
      let mono_msb = self.monomorphize_expr!(msb, params_env~)
      let mono_lsb = self.monomorphize_expr!(lsb, params_env~)
      @parse.Expr::Slicing(expr=mono_expr, msb=mono_msb, lsb=mono_lsb, span~, ty~)
    }
    PortAccess(expr~, port~, span~, ty~) => {
      let mono_expr = self.monomorphize_expr!(expr, params_env~)
      @parse.Expr::PortAccess(expr=mono_expr, port=port, span~, ty~)
    }
    Instance(name~, params~, ports~, span~, ty~) => {
      let mono_params = []

      for param in params {
        mono_params.push(self.monomorphize_expr!(param, params_env~))
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
        mono_ports[port_name] = self.monomorphize_expr!(port_expr, params_env~)
      }

      @parse.Expr::Instance(name=mono_name, params=mono_params, ports=mono_ports, span~, ty~)
    }
    Vector(elems~, span~, ty~) => {
      let mono_elems = []

      for elem in elems {
        mono_elems.push(self.monomorphize_expr!(elem, params_env~))
      }

      @parse.Expr::Vector(elems=mono_elems, span~, ty~)
    }
    Spread(expr~, span~, ty~) => {
      let mono_expr = self.monomorphize_expr!(expr, params_env~)
      @parse.Expr::Spread(expr=mono_expr, span~, ty~)
    }
    Ternary(cond~, then~, else_~, span~, ty~) => {
      let mono_cond = self.monomorphize_expr!(cond, params_env~)
      let mono_then = self.monomorphize_expr!(then, params_env~)
      let mono_else = self.monomorphize_expr!(else_, params_env~)
      @parse.Expr::Ternary(cond=mono_cond, then=mono_then, else_=mono_else, span~, ty~)
    }
    Match(subject~, cases~, span~, ty~) => {
      let mono_subject = self.monomorphize_expr!(subject, params_env~)
      let mono_cases = []

      for case in cases {
        let (pat, expr) = case
        let mono_pat = self.monomorphize_expr!(pat, params_env~)
        let mono_expr = self.monomorphize_expr!(expr, params_env~)
        mono_cases.push((mono_pat, mono_expr))
      }

      @parse.Expr::Match(subject=mono_subject, cases=mono_cases, span~, ty~)
    }
  }

  res.constant_folding!()
}

fn monomorphize_stmt(self: Monomorphizer, stmt: @parse.Stmt, params_env~: @elaborate.Scope[Int]) -> @parse.Stmt!Error {
  match stmt {
    Expr(expr~, span~) => {
      let mono_expr = self.monomorphize_expr!(expr, params_env~)
      @parse.Stmt::Expr(expr=mono_expr, span~)
    }
    Let(name~, ty~, expr~, span~) => {
      let mono_expr = match expr {
        Some(expr) => Some(self.monomorphize_expr!(expr, params_env~))
        None => None
      }

      let mono_ty = match ty.val {
        Some(ty) => Some(self.monomorphize_type!(ty, params_env~))
        None => None
      }

      @parse.Stmt::Let(name=name, ty={ val: mono_ty }, expr=mono_expr, span~)
    }
    Assign(lhs~, rhs~, span~) => {
      let mono_lhs = self.monomorphize_expr!(lhs, params_env~)
      let mono_rhs = self.monomorphize_expr!(rhs, params_env~)
      @parse.Stmt::Assign(lhs=mono_lhs, rhs=mono_rhs, span~)
    }
    For(var~, range~, body~, span~) => {
      let mono_range: @parse.ForRange = {
        start: self.monomorphize_expr!(range.start, params_env~),
        end: self.monomorphize_expr!(range.end, params_env~),
        inclusive: range.inclusive,
      }

      let mono_body = []

      for stmt in body {
        mono_body.push(self.monomorphize_stmt!(stmt, params_env~))
      }

      @parse.Stmt::For(var~, range=mono_range, body=mono_body, span~)
    }
    Scope(body~, span~) => {
      let mono_body = []

      for stmt in body {
        mono_body.push(self.monomorphize_stmt!(stmt, params_env~))
      }

      @parse.Stmt::Scope(body=mono_body, span~)
    }
  }
}

fn monomorphize_module(self: Monomorphizer, mod~: @parse.ModuleDecl, params~: Array[Int]) -> @parse.ModuleDecl!Error {
  let params_env = @elaborate.Scope::new()

  for i, param in params {
    params_env.declare!(mod.params[i], param)
  }

  let mono_ports: Array[@parse.Port] = []

  for port in mod.ports {
    mono_ports.push({
      name: port.name,
      ty: self.monomorphize_type!(port.ty, params_env~),
      dir: port.dir,
      optional: port.optional,
      span: port.span,
    })
  }

  let mono_body = []

  for stmt in mod.body {
    mono_body.push(self.monomorphize_stmt!(stmt, params_env~))
  }

  {
    name: {
      if params.is_empty() {
        mod.name
      } else {
        let builder = StringBuilder::new()
        builder.write_char('%')
        builder.write_string(mod.name)
        builder.write_string(String::concat(params.map(fn(n) { n.to_string() }), separator="_"))
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

fn collect_instances(self: Monomorphizer, decl: @parse.Decl) -> Unit!Error {
  match decl {
    Module(mod) => {
      if mod.params.is_empty() {
        self.modules[mod.name] = self.monomorphize_module!(mod~, params=[])
      } else {
        self.parameterized[mod.name] = mod
      }
    }
    ModuleDeclaration(sig) => {
      self.declared_modules[sig.name] = sig
    }
  }
}

pub fn monomorphize(self: Monomorphizer, decls: Array[@parse.Decl]) -> Array[@parse.Decl]!Error {
  for decl in decls {
    self.collect_instances!(decl)
  }

  let monomorphized = []

  for decl in self.declared_modules.values() {
    monomorphized.push(@parse.Decl::ModuleDeclaration(decl))
  }

  for mod in self.modules.values() {
    monomorphized.push(@parse.Decl::Module(mod))
  }

  monomorphized
}

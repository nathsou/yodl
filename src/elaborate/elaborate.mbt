
pub(readonly) struct Elaborator {
  mut node_offset: UInt
  mut instance_offset: UInt
  modules: Map[String, ModuleDef]
  mut current_module: ModuleDef?
}

pub fn Elaborator::new() -> Elaborator {
  { node_offset: 0, instance_offset: 0, modules: {}, current_module: None }
}

type! ElaboratorError {
  ModuleAlreadyDeclared(name~: String, span~: @parse.Span)
  NodeAlreadyDeclared(name~: String, span~: @parse.Span)
  UntypedExpression(span~: @parse.Span)
  UnknownIdentifier(name~: String, span~: @parse.Span)
  Unsupported(message~: String, span~: @parse.Span)
} derive(Show)

fn declare_node(self: Elaborator, scope: Scope[Node], node: Node) -> Node!ElaboratorError {
  self.node_offset += 1

  match scope.declare?(node.name, node) {
    Ok(_) => ()
    Err(_) => raise NodeAlreadyDeclared(name=node.name, span=node.span)
  }

  match self.current_module {
    Some(mod) => mod.nodes.push(node)
    None => ()
  }

  node
}

fn elaborate_module(self: Elaborator, mod: @parse.ModuleDecl) -> Unit!ElaboratorError {
  let def: ModuleDef = {
    name: mod.name,
    submodules: [],
    nodes: [],
    span: mod.span,
  }

  self.current_module = Some(def)

  let scope = Scope::new()

  for input in mod.inputs {
    let _ = self.declare_node!(scope, {
      local_id: self.node_offset,
      ty: input.ty,
      span: input.span,
      name: input.name,
      is_port: true,
      width: 1,
      inputs: [],
      outputs: [],
    })
  }

  for output in mod.outputs {
    let _ = self.declare_node!(scope, {
      local_id: self.node_offset,
      ty: output.ty,
      span: output.span,
      name: output.name,
      is_port: true,
      width: 1,
      inputs: [],
      outputs: [],
    })
  }

  for stmt in mod.body {
    let _ = self.elaborate_stmt!(stmt, scope)
  }

  if self.modules.contains(mod.name) {
    raise ModuleAlreadyDeclared(name=mod.name, span=mod.span)
  }

  self.modules[mod.name] = def
}

fn declare_instance(
  self: Elaborator,
  mod_name: String,
  inputs: Map[String, Node],
  outputs: Map[String, Node],
  span: @parse.Span,
) -> Instance {
  let def: Instance = {
    module_name: mod_name,
    local_id: self.instance_offset,
    inputs,
    outputs,
    span,
  }

  self.instance_offset += 1

  match self.current_module {
    Some(mod) => mod.submodules.push(def)
    None => ()
  }

  def
}

fn elaborate_expr(self: Elaborator, expr: @parse.Expr, scope: Scope[Node]) -> Node!ElaboratorError {
  match expr {
    Identifier(name~, span~, ..) => {
      match scope.resolve(name) {
        Some(node) => node
        None => raise UnknownIdentifier(name~, span~)
      }
    }
    Natural(span~, ..) => {
      raise Unsupported(message="Natural literals are not supported yet", span~)
    }
    Unary(span~, ..) => {
      raise Unsupported(message="Unary operators are not supported yet", span~)
    }
    Binary(op~, lhs~, rhs~, span~, ty~, ..) => {
      let mod_name = match op {
        And => "<and>"
        Or => "<or>"
        Xor => "<xor>"
        Nand => "<nand>"
        Nor => "<nor>"
        Xnor => "<xnor>"
      }

      let a = self.declare_node!(scope, {
        local_id: self.node_offset,
        ty: ty.val.or_error!(UntypedExpression(span~)),
        span,
        name: "\{mod_name}_\{self.node_offset}_a",
        is_port: false,
        width: 1,
        inputs: [],
        outputs: [],
      })

      let b = self.declare_node!(scope, {
        local_id: self.node_offset,
        ty: ty.val.or_error!(UntypedExpression(span~)),
        span,
        name: "\{mod_name}_\{self.node_offset}_b",
        is_port: false,
        width: 1,
        inputs: [],
        outputs: [],
      })

      let inputs = {
        "a": a,
        "b": b,
      }

      let q = self.declare_node!(scope, {
        local_id: self.node_offset,
        ty: ty.val.or_error!(UntypedExpression(span~)),
        span,
        name: "\{mod_name}_\{self.node_offset}_q",
        is_port: false,
        width: 1,
        inputs: [],
        outputs: [],
      })

      let outputs = { "q": q }

      self.elaborate_expr!(lhs, scope).connect(a)
      self.elaborate_expr!(rhs, scope).connect(b)

      let _ = self.declare_instance(mod_name, inputs, outputs, span)

      q
    }
  }
}

fn connect(self: Node, to: Node) -> Unit {
  self.outputs.push(to)
  to.inputs.push(self)
}

fn elaborate_stmt(self: Elaborator, stmt: @parse.Stmt, scope: Scope[Node]) -> Unit!ElaboratorError {
  match stmt {
    Let(name~, expr~, span~, ..) => {
      let node1 = self.declare_node!(scope, {
        local_id: self.node_offset,
        ty: expr.ty().val.or_error!(UntypedExpression(span~)),
        span,
        name,
        is_port: false,
        width: 1,
        inputs: [],
        outputs: [],
      })

      let node2 = self.elaborate_expr!(expr, scope)

      node2.connect(node1)
    }
    Assign(lhs~, rhs~, ..) => {
      let node1 = self.elaborate_expr!(lhs, scope)
      let node2 = self.elaborate_expr!(rhs, scope)
      node2.connect(node1)
    }
  }
}

pub fn elaborate_decl(self: Elaborator, decl: @parse.Decl) -> Unit!ElaboratorError {
  match decl {
    Module(mod) => {
      self.elaborate_module!(mod)
    }
  }
}

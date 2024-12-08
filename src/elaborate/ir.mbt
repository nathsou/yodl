
pub(readonly) struct Node {
    local_id: UInt
    ty: @parse.Type
    span: @parse.Span
    name: String
    is_port: Bool
    width: UInt
    inputs: Array[Node]
    outputs: Array[Node]
}

pub(readonly) struct Instance {
    module_name: String
    local_id: UInt
    inputs: Map[String, Node]
    outputs: Map[String, Node]
    span: @parse.Span
}

pub(readonly) struct ModuleDef {
    name: String
    submodules: Array[Instance]
    nodes: Array[Node]
    span: @parse.Span
}

pub fn to_dotfile(def: ModuleDef) -> String {
  let emitter = @parse.Emitter::new()

  emitter.write("digraph \{def.name} {\n")
  emitter.indent += 1

  for node in def.nodes {
    emitter.write_indent()
    if node.is_port {
      emitter.write("node\{node.local_id} [label=\"\{node.name}\", shape=\"diamond\"]\n")
    } else {
      emitter.write("node\{node.local_id} [label=\"\{node.name}\"]\n")
    }
  }

  for instance in def.submodules {
    emitter.emit("subgraph cluster\{instance.local_id} {")
    emitter.indent += 1

    emitter.emit("label=\"\{instance.module_name}_\{instance.local_id}\"")

    for name, node in instance.inputs {
      emitter.emit("node\{node.local_id} [label=\"\{name}\"]")
    }

    for name, node in instance.outputs {
      emitter.emit("node\{node.local_id} [label=\"\{name}\"]")
    }

    emitter.indent -= 1
    emitter.write_indent()
    emitter.write("}\n")
  }

  let stack = def.nodes.copy()
  let visited = Set::new()

  while not(stack.is_empty()) {
    let node = stack.pop().unwrap()

    if visited.contains(node.local_id) {
      continue
    }

    visited.add(node.local_id)

    for node2 in node.outputs {
      emitter.write_indent()
      emitter.write("node\{node.local_id} -> node\{node2.local_id}\n")
      stack.push(node2)
    }
  }

  emitter.indent -= 1
  emitter.write("}\n")

  emitter.to_string()
}

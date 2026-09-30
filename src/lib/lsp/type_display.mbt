/// Language feedback uses source syntax, including symbolic integer widths.
/// Compiler dumps have their own display convention; editor labels must be Yodl.
fn type_label(ty: Type) -> String {
  match ty {
    UInt(width) => match width { Lit(_) => ty.to_string(); _ => "uint[\{width}]" }
    SInt(width) => match width { Lit(_) => ty.to_string(); _ => "sint[\{width}]" }
    Vector(ty~, len~) => "[\{len}]\{type_label(ty)}"
    Name(path~, params~) => "\{path}" + (if params.is_empty() { "" } else { "[\{params.map(type_label).join(", ")}]" })
    Instance(sig={ path, .. }, params~, ..) => {
      let values = params.values().map(arg => match arg {
        @parse.StaticArg::TypeParam(ty~, ..) => type_label(ty)
        @parse.StaticArg::NatParam(value~, ..) => value.to_string()
      }).to_array()
      "\{path}" + (if values.is_empty() { "" } else { "[\{values.join(", ")}]" })
    }
    Struct(fields) => {
      let n = fields.length()
      if n == 0 { return "()" }
      let mut positional = true
      for i in 0..<n { if !fields.contains(i.to_string()) { positional = false } }
      if positional {
        let items = []
        for i in 0..<n { items.push(type_label(fields[i.to_string()])) }
        "(\{items.join(", ")}\{if n == 1 { "," } else { "" }})"
      } else {
        let names = fields.keys().to_array()
        names.sort()
        "(\{names.map(name => "\{name}: \{type_label(fields[name])}").join(", ")})"
      }
    }
    MemoryMask(ty) => "MemoryMask[\{type_label(ty)}]"
    Clock | String(..) | Unit => ty.to_string()
  }
}

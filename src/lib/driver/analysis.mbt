pub(all) struct Analysis {
  source_decls: Array[@parse.Decl]
  typed_decls: Array[@parse.Decl]
  diagnostics: Array[@parse.Diagnostic]
}

pub fn diagnostic(error: Error) -> @parse.Diagnostic {
  match (@elaborate.diagnostic(error), @simplify.diagnostic(error)) {
    (Some(result), _) | (_, Some(result)) => result
    _ => {
    match error {
      Failure::Failure(message) => @parse.Diagnostic::new("Y0000", message)
      _ => @parse.Diagnostic::new("Y0000", error.to_string())
    }
    }
  }
}

/// Stable host boundary: consumers never inspect MoonBit's generated error layout.
pub fn diagnostic_json(error: Error) -> String {
  diagnostic(error).to_json().stringify()
}

/// Frontend analysis deliberately has no top selection, Core construction or backend IO.
/// Each call owns fresh mutable compiler trees; an editor snapshot is never rechecked in place.
pub fn analyze(path: String, ext: @utils.Externals) -> Analysis {
  let diagnostics = []
  let pkg = try {
    let resolver = @simplify.Resolver::new(@utils.dir_name(path), fs=ext.fs, recovering=true, diagnostics~)
    resolver.resolve(path~, is_top_package=true)
  } catch {
    error => {
      diagnostics.push(diagnostic(error))
      return { source_decls: [], typed_decls: [], diagnostics }
    }
  }
  let source_decls = pkg.body
  // Invalid recovered source is useful for navigation, but must not enter monomorphisation.
  if !diagnostics.is_empty() { return { source_decls, typed_decls: [], diagnostics } }
  let mono_decls = try @simplify.Monomorphizer::new().monomorphize(decls=pkg.body, packages=[]) catch {
    error => {
      diagnostics.push(diagnostic(error))
      return { source_decls, typed_decls: [], diagnostics }
    }
  }
  let checker = @elaborate.TypeChecker::new()
  let typed_decls = []
  for decl in mono_decls {
    try checker.check_decl(decl, diagnostics=Some(diagnostics)) catch {
      error => diagnostics.push(diagnostic(error))
    } noraise {
      decl => typed_decls.push(decl)
    }
  }
  try checker.finalize() catch { error => diagnostics.push(diagnostic(error)) }
  { source_decls, typed_decls, diagnostics }
}

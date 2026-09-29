
pub fn diagnostic(error: Error) -> @parse.Diagnostic? {
  match error {
    ResolutionError::PackageNotFound(name~, span~) => Some(@parse.Diagnostic::new("Y0701", "Package '\{name}' not found", span=Some(span)))
    ResolutionError::MultiLevelImportNotSupportedYet(packages~, span~) => Some(@parse.Diagnostic::new("Y0702", "Multi-level imports are not yet supported: [\{packages.join(", ")}]", span=Some(span)))
    ResolutionError::ImportError(error~, span~) => {
      let result = diagnostic(error).unwrap_or(@parse.Diagnostic::new("Y0703", error.to_string(), span=Some(span)))
      if result.span is None { Some({ ..result, span: Some(span) }) } else {
        result.related.push({ span, message: "Imported here" })
        Some(result)
      }
    }
    ResolutionError::ImportCycle(path~) => Some(@parse.Diagnostic::new("Y0704", "Import cycle involving '\{path}'"))
    ResolutionError::LexerError(error) | ResolutionError::ParseError(error) => diagnostic(error)
    ResolutionError::IOError(error) => Some(@parse.Diagnostic::new("Y0705", "Could not read source: \{error}"))
    ResolutionError::CouldNotExtractPackageName(path) => Some(@parse.Diagnostic::new("Y0706", "Could not extract package name from '\{path}'"))
    ResolutionError::PackageNameConflict(name~, path1~, path2~) => {
      let result = @parse.Diagnostic::new("Y0707", "Package name conflict for '\{name}'")
      result.notes.push("Both '\{path1}' and '\{path2}' provide this package")
      Some(result)
    }
    MonomorphizerError::ModuleNotFound(path~, span~) => Some(@parse.Diagnosed::diagnostic(MonomorphizerError::ModuleNotFound(path~, span~)))
    MonomorphizerError::InvalidModuleParameterCount(path~, expected~, actual~, span~) => Some(@parse.Diagnosed::diagnostic(MonomorphizerError::InvalidModuleParameterCount(path~, expected~, actual~, span~)))
    MonomorphizerError::ReceivedTypeParameterInsteadOfExpr(span~) => Some(@parse.Diagnosed::diagnostic(MonomorphizerError::ReceivedTypeParameterInsteadOfExpr(span~)))
    MonomorphizerError::InvalidParameter(sort~, span~) => Some(@parse.Diagnosed::diagnostic(MonomorphizerError::InvalidParameter(sort~, span~)))
    MonomorphizerError::InvalidSizeFunctionDomain(message~, span~) => Some(@parse.Diagnosed::diagnostic(MonomorphizerError::InvalidSizeFunctionDomain(message~, span~)))
    MonomorphizerError::ReceivedTypeAliasInsteadOfExpr(span~) => Some(@parse.Diagnosed::diagnostic(MonomorphizerError::ReceivedTypeAliasInsteadOfExpr(span~)))
    MonomorphizerError::InvalidParameterInstantiation(path~, param~, span~, param_span~) => Some(@parse.Diagnosed::diagnostic(MonomorphizerError::InvalidParameterInstantiation(path~, param~, span~, param_span~)))
    MonomorphizerError::InvalidTypeAliasParameters(path~, exptected~, actual~, span~) => Some(@parse.Diagnosed::diagnostic(MonomorphizerError::InvalidTypeAliasParameters(path~, exptected~, actual~, span~)))
    MonomorphizerError::UnresolvedNamedType(path~, span~) => Some(@parse.Diagnosed::diagnostic(MonomorphizerError::UnresolvedNamedType(path~, span~)))
    SimplifierError::AssertionAlwaysFails(span~) => Some(@parse.Diagnosed::diagnostic(SimplifierError::AssertionAlwaysFails(span~)))
    _ => @parse.diagnostic(error)
  }
}


pub fn diagnostic(error: Error) -> @parse.Diagnostic? {
  match error {
    TypeCheckerError::TypeCheckerError(message~, span~) => Some(@parse.Diagnosed::diagnostic(TypeCheckerError::TypeCheckerError(message~, span~)))
    TypeCheckerError::IncompatibleTypes(ty1~, ty2~, span~) => Some(@parse.Diagnosed::diagnostic(TypeCheckerError::IncompatibleTypes(ty1~, ty2~, span~)))
    TypeCheckerError::InvalidAssignmentTarget(span~) => Some(@parse.Diagnosed::diagnostic(TypeCheckerError::InvalidAssignmentTarget(span~)))
    TypeCheckerError::IndexedExpressionMustBeVector(span~) => Some(@parse.Diagnosed::diagnostic(TypeCheckerError::IndexedExpressionMustBeVector(span~)))
    TypeCheckerError::UnknownModule(path~, span~) => Some(@parse.Diagnosed::diagnostic(TypeCheckerError::UnknownModule(path~, span~)))
    TypeCheckerError::UnknownModulePort(module_path~, port_name~, span~) => Some(@parse.Diagnosed::diagnostic(TypeCheckerError::UnknownModulePort(module_path~, port_name~, span~)))
    TypeCheckerError::InvalidSlicingRange(reason~, span~) => Some(@parse.Diagnosed::diagnostic(TypeCheckerError::InvalidSlicingRange(reason~, span~)))
    TypeCheckerError::ExpectedConstantExpr(span~) => Some(@parse.Diagnosed::diagnostic(TypeCheckerError::ExpectedConstantExpr(span~)))
    TypeCheckerError::InvalidAttributeArgs(name~, args~, expected~, span~) => Some(@parse.Diagnosed::diagnostic(TypeCheckerError::InvalidAttributeArgs(name~, args~, expected~, span~)))
    ElaborationError::ElaborationError(message~, span~) => Some(@parse.Diagnosed::diagnostic(ElaborationError::ElaborationError(message~, span~)))
    ElaborationError::UnresolvedIdentifier(path~, span~) => Some(@parse.Diagnosed::diagnostic(ElaborationError::UnresolvedIdentifier(path~, span~)))
    ElaborationError::Unreachable(message~, span~) => Some(@parse.Diagnosed::diagnostic(ElaborationError::Unreachable(message~, span~)))
    ElaborationError::Unsupported(message~, span~) => Some(@parse.Diagnosed::diagnostic(ElaborationError::Unsupported(message~, span~)))
    _ => @parse.diagnostic(error)
  }
}

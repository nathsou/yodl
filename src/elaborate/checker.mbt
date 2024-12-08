
struct TypeChecker {
    modules: Map[String, @parse.ModuleSignature]
}

pub fn TypeChecker::new() -> TypeChecker {
    {
        modules: {},
    }
}

type! TypeCheckerError {
    UnboundVariable(name~: String, span~: @parse.Span)
    IncompatibleTypes(ty1~: @parse.Type, ty2~: @parse.Type, span~: @parse.Span)
    VariableRedeclared(name~: String, span~: @parse.Span)
    InvalidAssignmentTarget(span~: @parse.Span)
    IndexMustBeInteger(span~: @parse.Span)
    IndexMustBeConstantExpr(span~: @parse.Span)
    IndexedExpressionMustBeVector(span~: @parse.Span)
    UnknownModule(name~: String, span~: @parse.Span)
    UnknownModulePort(module_name~: String, port_name~: String, span~: @parse.Span)
    PortAccessOnNonInstance(span~: @parse.Span)
    InvalidSlicingRange(span~: @parse.Span)
    ExpectedConstantExpr(span~: @parse.Span)
} derive(Show)

fn declare_name(env~: Scope[@parse.Type], name~: String, ty~: @parse.Type, span~: @parse.Span) -> Unit!TypeCheckerError {
    match env.declare?(name, ty) {
        Ok(_) => ()
        Err(_) => raise VariableRedeclared(name~, span~)
    }
}

fn eval_const_expr(expr: @parse.Expr) -> UInt!TypeCheckerError {
    match expr {
        Natural(value~, ..) => value
        _ => raise ExpectedConstantExpr(span=expr.span())
    }
}

fn check_expr(self: TypeChecker, expr: @parse.Expr, env: Scope[@parse.Type]) -> @parse.Type!TypeCheckerError {
    let ty = match expr {
        Identifier(name~, span~, ..) => {
            match env.resolve(name) {
                Some(ty) => ty
                None => raise UnboundVariable(name~, span~)
            }
        }
        Natural(width~, ..) => match width {
            Some(0) => @parse.Logic
            Some(width) => @parse.Vector(ty=@parse.Logic, len=width)
            None => Nat
        }
        Unary(expr~, ..) => {
            self.check_expr!(expr, env) 
        }
        Binary(lhs~, rhs~, span~, ..) => {
            let ty_lhs = self.check_expr!(lhs, env)
            let ty_rhs = self.check_expr!(rhs, env)

            if ty_lhs != ty_rhs {
                raise IncompatibleTypes(ty1=ty_lhs, ty2=ty_rhs, span~)
            }

            ty_lhs
        }
        Indexing(expr~, index~, span~, ..) => {
            let ty = self.check_expr!(expr, env)
            let index_ty = self.check_expr!(index, env)

            if index_ty != @parse.Nat {
                raise IndexMustBeInteger(span~)
            }

            if not(index.is_constant_expr()) {
                raise IndexMustBeConstantExpr(span~)
            }

            match ty {
                Vector(ty=inner_ty, ..) => inner_ty
                _ => raise IndexedExpressionMustBeVector(span~)
            }
        }
        Slicing(expr~, start~, end~, span~, ..) => {
            let ty = self.check_expr!(expr, env)
            let start_ty = self.check_expr!(start, env)
            let end_ty = self.check_expr!(end, env)

            if start_ty != @parse.Nat || end_ty != @parse.Nat {
                raise InvalidSlicingRange(span~)
            }

            let start = eval_const_expr!(start)
            let end = eval_const_expr!(end)

            match ty {
                Vector(ty=inner_ty, len~) => {
                    if end >= len {
                        raise InvalidSlicingRange(span~)
                    }

                    if start >= end {
                        raise InvalidSlicingRange(span~)
                    }

                    @parse.Type::Vector(ty=inner_ty, len=(end - start) + 1)
                }
                _ => raise IndexedExpressionMustBeVector(span~)
            }
        }
        PortAccess(expr~, port~, span~, ..) => {
            match self.check_expr!(expr, env) {
                Instance(mod) => {
                    match mod.get_port(port) {
                        Some(port_def) => port_def.ty
                        None => raise UnknownModulePort(module_name=mod.name, port_name=port, span~)
                    }
                }
                _ => raise PortAccessOnNonInstance(span~)
            }
        }
        Instance(name~, ports~, span~, ..) => {
            match self.modules[name] {
                Some(mod) => {
                    for port_name, expr in ports {
                        match mod.get_port(port_name) {
                            Some(port_def) => {
                                let expr_ty = self.check_expr!(expr, env)

                                if expr_ty != port_def.ty {
                                    raise IncompatibleTypes(ty1=expr_ty, ty2=port_def.ty, span~)
                                }
                            }
                            None => raise UnknownModulePort(module_name=name, port_name=port_name, span~)
                        }
                    }

                    @parse.Type::Instance(mod)
                }
                None => raise UnknownModule(name~, span~)
            }
        }
    }

    expr.set_ty(ty)

    ty
}

fn check_stmt(self: TypeChecker, stmt: @parse.Stmt, env: Scope[@parse.Type]) -> Unit!TypeCheckerError {
    match stmt {
        Let(name~, expr~, span~, ..) => {
            let ty = self.check_expr!(expr, env)
            declare_name!(env~, name~, ty~, span~)
        }
        Assign(lhs~, rhs~, span~, ..) => {
            let is_valid_assignment_target = match lhs {
                Identifier(..) | Indexing(..) | Slicing(..) | PortAccess(..) => true
                _ => false
            };

            if not(is_valid_assignment_target) {
                raise InvalidAssignmentTarget(span~)
            }

            let lhs_ty = self.check_expr!(lhs, env)
            let rhs_ty = self.check_expr!(rhs, env)

            if lhs_ty != rhs_ty {
                raise IncompatibleTypes(ty1=lhs_ty, ty2=rhs_ty, span~)
            }
        }
    }
}

pub fn check_decl(self: TypeChecker, decl: @parse.Decl) -> Unit!TypeCheckerError {
    match decl {
        Module({ name, inputs, outputs, body, span }) => {
            let env = Scope::new()

            for input in inputs {
                declare_name!(env~, name=input.name, ty=input.ty, span~)
            }

            for output in outputs {
                declare_name!(env~, name=output.name, ty=output.ty, span~)
            }

            for stmt in body {
                self.check_stmt!(stmt, env)
            }

            self.modules[name] = {
                name,
                inputs,
                outputs,
                span,
            }
        }
    }
}

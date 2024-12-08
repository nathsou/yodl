
struct TypeChecker {
    top_env: Scope[@parse.Type]
}

pub fn TypeChecker::new() -> TypeChecker {
    {
        top_env: Scope::new()
    }
}

type! TypeCheckerError {
    UnspecifiedIntegerWidth(span~: @parse.Span)
    UnboundVariable(name~: String, span~: @parse.Span)
    IncompatibleTypes(ty1~: @parse.Type, ty2~: @parse.Type, span~: @parse.Span)
    VariableRedeclared(name~: String, span~: @parse.Span)
}

fn declare_name(env~: Scope[@parse.Type], name~: String, ty~: @parse.Type, span~: @parse.Span) -> Unit!TypeCheckerError {
    match env.declare?(name, ty) {
        Ok(_) => ()
        Err(_) => raise VariableRedeclared(name~, span~)
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
        Natural(width~, span~, ..) => match width {
            Some(width) => @parse.Vector(ty=@parse.Logic, len=width)
            None => raise UnspecifiedIntegerWidth(span~)
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
        Assign(name~, expr~, span~, ..) => {
            let ty = self.check_expr!(expr, env)
            match env.resolve(name) {
                Some(ty_decl) => {
                    if ty != ty_decl {
                        raise IncompatibleTypes(ty1=ty, ty2=ty_decl, span~)
                    }
                }
                None => raise UnboundVariable(name~, span~)
            }
        }
    }
}

pub fn check_decl(self: TypeChecker, decl: @parse.Decl) -> Unit!TypeCheckerError {
    match decl {
        Module({ name: _, inputs, outputs, body, span }) => {
            for input in inputs {
                declare_name!(env=self.top_env, name=input.name, ty=input.ty, span~)
            }

            for output in outputs {
                declare_name!(env=self.top_env, name=output.name, ty=output.ty, span~)
            }

            for stmt in body {
                self.check_stmt!(stmt, self.top_env)
            }
        }
    }
}

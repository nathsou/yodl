
struct TypeChecker {
    modules: Map[String, @parse.ModuleSignature]
    top_env: Scope[@parse.Type]
}

pub fn TypeChecker::new() -> TypeChecker {
    {
        modules: {},
        top_env: Scope::new(),
    }
}

type! TypeCheckerError {
    UnboundVariable(name~: String, span~: @parse.Span)
    IncompatibleTypes(ty1~: @parse.Type, ty2~: @parse.Type, span~: @parse.Span)
    VariableRedeclared(name~: String, span~: @parse.Span)
    InvalidAssignmentTarget(span~: @parse.Span)
    IndexMustBeInteger(span~: @parse.Span)
    IndexedExpressionMustBeVector(span~: @parse.Span)
    UnknownModule(name~: String, span~: @parse.Span)
    UnknownModulePort(module_name~: String, port_name~: String, span~: @parse.Span)
    InvalidFieldAccess(field~: String, span~: @parse.Span)
    InvalidSlicingRange(span~: @parse.Span)
    ExpectedConstantExpr(span~: @parse.Span)
    InvalidPortType(ty~: @parse.Type, span~: @parse.Span)
    LetStmtMustHaveTypeOrValue(span~: @parse.Span)
    EmptyVector(span~: @parse.Span)
    SpreadOnNonVector(span~: @parse.Span)
    SpreadOutsideVector(span~: @parse.Span)
    InvalidAttribute(name~: String, span~: @parse.Span)
    InvalidAttributeArgs(name~: String, args~: Array[@parse.AttributeValue], span~: @parse.Span)
    EmptyMatch(span~: @parse.Span)
    InvalidInstanceTypeParameterCount(module_name~: String, expected~: Int, actual~: Int, span~: @parse.Span)
    FunCallAfterMonomorphization(span~: @parse.Span)
    InvalidStructField(name~: String, span~: @parse.Span)
    InvalidUnaryOpOperand(op~: @parse.UnaryOp, ty~: @parse.Type, span~: @parse.Span)
    InvalidBinaryOpOperand(op~: @parse.BinaryOp, ty~: @parse.Type, span~: @parse.Span)
    StringContainsNonAsciiChar(char~: Char, span~: @parse.Span)
}

pub impl Show for TypeCheckerError with output(self, logger) {
    match self {
        UnboundVariable(name~, ..) => {
            logger.write_string("Unbound variable '\{name}'")
        }
        IncompatibleTypes(ty1~, ty2~, ..) => {
            logger.write_string("Incompatible types '\{ty1}' and '\{ty2}'")
        }
        VariableRedeclared(name~, ..) => {
            logger.write_string("Variable '\{name}' redeclared")
        }
        InvalidAssignmentTarget(..) => {
            logger.write_string("Invalid assignment target")
        }
        IndexMustBeInteger(..) => {
            logger.write_string("Index must be an integer")
        }
        IndexedExpressionMustBeVector(..) => {
            logger.write_string("Indexed expression must be a vector")
        }
        UnknownModule(name~, ..) => {
            logger.write_string("Unknown module '\{name}'")
        }
        UnknownModulePort(module_name~, port_name~, ..) => {
            logger.write_string("Unknown port '\{port_name}' in module '\{module_name}'")
        }
        InvalidFieldAccess(field~, ..) => {
            logger.write_string("Invalid field access '\{field}'")
        }
        InvalidSlicingRange(..) => {
            logger.write_string("Invalid slicing range")
        }
        ExpectedConstantExpr(..) => {
            logger.write_string("Expected constant expression")
        }
        InvalidPortType(ty~, ..) => {
            logger.write_string("Invalid port type '\{ty}'")
        }
        LetStmtMustHaveTypeOrValue(..) => {
            logger.write_string("Let statement must have a type or value")
        }
        EmptyVector(..) => {
            logger.write_string("Empty vector")
        }
        SpreadOnNonVector(..) => {
            logger.write_string("Spread on non-vector")
        }
        SpreadOutsideVector(..) => {
            logger.write_string("Spread outside vector")
        }
        InvalidAttribute(name~, ..) => {
            logger.write_string("Invalid attribute '\{name}'")
        }
        InvalidAttributeArgs(name~, args~, ..) => {
            logger.write_string("Invalid arguments '\{args}' for attribute '\{name}'")
        }
        EmptyMatch(..) => {
            logger.write_string("Empty match expression")
        }
        InvalidInstanceTypeParameterCount(module_name~, expected~, actual~, ..) => {
            logger.write_string("Module '\{module_name}' expected \{expected} type parameters, got \{actual}")
        }
        FunCallAfterMonomorphization(..) => {
            logger.write_string("Function call after monomorphization")
        }
        InvalidStructField(name~, ..) => {
            logger.write_string("Invalid struct field '\{name}'")
        }
        InvalidUnaryOpOperand(op~, ty~, ..) => {
            logger.write_string("Invalid operand '\{ty}' for unary operator '\{op}'")
        }
        InvalidBinaryOpOperand(op~, ty~, ..) => {
            logger.write_string("Invalid operand '\{ty}' for binary operator '\{op}'")
        }
        StringContainsNonAsciiChar(char~, ..) => {
            logger.write_string("String contains non-ASCII character '\{char}'")
        }
    }

    logger.write_string(self.show_context())
}

pub impl @parse.Spanned for TypeCheckerError with span(self) -> @parse.Span {
    match self {
        UnboundVariable(span~, ..) => span
        IncompatibleTypes(span~, ..) => span
        VariableRedeclared(span~, ..) => span
        InvalidAssignmentTarget(span~, ..) => span
        IndexMustBeInteger(span~, ..) => span
        IndexedExpressionMustBeVector(span~, ..) => span
        UnknownModule(span~, ..) => span
        UnknownModulePort(span~, ..) => span
        InvalidFieldAccess(span~, ..) => span
        InvalidSlicingRange(span~, ..) => span
        ExpectedConstantExpr(span~, ..) => span
        InvalidPortType(span~, ..) => span
        LetStmtMustHaveTypeOrValue(span~, ..) => span
        EmptyVector(span~, ..) => span
        SpreadOnNonVector(span~, ..) => span
        SpreadOutsideVector(span~, ..) => span
        InvalidAttribute(span~, ..) => span
        InvalidAttributeArgs(span~, ..) => span
        EmptyMatch(span~, ..) => span
        InvalidInstanceTypeParameterCount(span~, ..) => span
        FunCallAfterMonomorphization(span~, ..) => span
        InvalidStructField(span~, ..) => span
        InvalidUnaryOpOperand(span~, ..) => span
        InvalidBinaryOpOperand(span~, ..) => span
        StringContainsNonAsciiChar(span~, ..) => span
    }
}

fn unify_aux(eqs: Array[(@parse.Type, @parse.Type)], span~: @parse.Span, subst~: Map[String, Int] = {}) -> Map[String, Int]!TypeCheckerError {
    while not(eqs.is_empty()) {
        let (ty1, ty2) = eqs.pop().unwrap()

        if ty1 == ty2 {
            continue
        }

        match (ty1, ty2) {
            (Vector(ty=ty1_inner, len=Fixed(len)), Vector(ty=ty2_inner, len=Dynamic(Identifier(name~, ..)))) => {
                match subst[name] {
                    Some(len2) => {
                        if len != len2 {
                            raise IncompatibleTypes(ty1~, ty2~, span~)
                        }
                    }
                    None => {
                        subst[name] = len
                    }
                }

                eqs.push((ty1_inner, ty2_inner))
            }
            (Vector(ty=_, len=Dynamic(Identifier(_))), Vector(ty=_, len=Fixed(_))) => {
                eqs.push((ty2, ty1))
            }
            (Instance(sig=_, params=params1, accessed_ports=accessed_ports1), Instance(sig=_, params=params2, accessed_ports=accessed_ports2)) => {
                if params1 == params2 {
                    // merge accessed ports
                    for port in accessed_ports1 {
                        accessed_ports2.add(port)
                    }

                    for port in accessed_ports2 {
                        accessed_ports1.add(port)
                    }
                } else {
                    raise IncompatibleTypes(ty1~, ty2~, span~)
                }
            }
            _ => {
                raise IncompatibleTypes(ty1~, ty2~, span~)
            }
        }
    }

    subst
}

fn unify(ty1: @parse.Type, ty2: @parse.Type, span~: @parse.Span, subst~: Map[String, Int] = {}) -> Map[String, Int]!TypeCheckerError {
    unify_aux!([(ty1, ty2)], span~, subst~)
}

fn declare_name(env~: Scope[@parse.Type], name~: String, ty~: @parse.Type, span~: @parse.Span) -> Unit!TypeCheckerError {
    match env.declare?(name, ty) {
        Ok(_) => ()
        Err(MemberAlreadyDeclared) => raise VariableRedeclared(name~, span~)
    }
}

// expr should already have been partially evaluated using `Expr::partial_eval`
// during the monomorphization pass
fn eval_const_expr(expr: @parse.Expr) -> Int! {
    match expr {
        Natural(bits~, ..) => bits.as_int!()
        _ => raise ExpectedConstantExpr(span=expr.span())
    }
}

fn resolve_ty(self: TypeChecker, ty: @parse.Type, span~: @parse.Span) -> @parse.Type! {
    match ty {
        Logic => Logic
        Nat => Nat
        Vector(ty=inner_ty, len~) => Vector(ty=self.resolve_ty!(inner_ty, span~), len~)
        Instance(_) => ty
        Name(name~, params~) => {
            match self.modules[name] {
                Some(sig) => {
                    if sig.params.length() != params.length() {
                        raise InvalidInstanceTypeParameterCount(module_name=name, expected=sig.params.length(), actual=params.length(), span~)
                    }

                    Instance(sig~, params=Map::from_iter(@utils.zip(sig.params, params)), accessed_ports=Set::new())
                }
                None => raise TypeCheckerError::UnknownModule(name~, span~)
            }
        }
        Struct(fields) => {
            let field_tys = Map::new(capacity=fields.size())

            for name, ty in fields {
                field_tys[name] = self.resolve_ty!(ty, span~)
            }

            Struct(field_tys)
        }
        String(len~) => String(len~)
    }
}

fn check_expr(self: TypeChecker, expr: @parse.Expr, env: Scope[@parse.Type], expected_ty~: @parse.Type? = None) -> @parse.Type! {
    let ty = match expr {
        Identifier(name~, span~, ..) => {
            match env.resolve(name) {
                Some(ty) => ty
                None => raise UnboundVariable(name~, span~)
            }
        }
        Natural(width~, ..) => match width {
            Some(1) => @parse.Logic
            Some(width) => @parse.Type::Vector(ty=@parse.Logic, len=Fixed(width))
            None => Nat
        }
        String(str~,  span~, ..) => {
            for char in str {
                if not(@utils.is_ascii(char)) {
                    raise StringContainsNonAsciiChar(char~, span~)
                }
            }

            @parse.Type::String(len=str.length())
        }
        Unary(op~, expr~, span~, ..) => {
            let ty = self.check_expr!(expr, env, expected_ty~)

            if not(ty.is_numerical()) {
                raise InvalidUnaryOpOperand(op~, ty~, span~)
            }
            
            ty
        }
        Binary(op~, lhs~, rhs~, span~, ..) => {
            let lhs_ty = self.check_expr!(lhs, env, expected_ty~)
            let rhs_ty = self.check_expr!(rhs, env, expected_ty~)
            let wa = lhs_ty.width!(lhs.span())
            let wb = rhs_ty.width!(rhs.span())

            if not(lhs_ty.is_numerical()) {
                raise InvalidBinaryOpOperand(op~, ty=lhs_ty, span~)   
            }

            let wy = match expected_ty {
                Some(expected_ty) => expected_ty.width!(span)
                None => op.output_width(wa, wb)
            }

            match wy {
                1 => Logic
                width => Vector(ty=Logic, len=Fixed(width))
            }
        }
        Indexing(expr~, index~, span~, ..) => {
            let ty = self.check_expr!(expr, env)
            let index_ty = self.check_expr!(index, env)

            if not(index_ty.is_numerical()) {
                raise IndexMustBeInteger(span=index.span())
            }

            match ty {
                Vector(ty=inner_ty, ..) => inner_ty
                _ => raise IndexedExpressionMustBeVector(span~)
            }
        }
        Slicing(expr~, msb~, lsb~, span~, ..) => {
            let ty = self.check_expr!(expr, env)
            let start_ty = self.check_expr!(msb, env)
            let end_ty = self.check_expr!(lsb, env)

            if start_ty != @parse.Nat || end_ty != @parse.Nat {
                raise InvalidSlicingRange(span~)
            }

            let msb = eval_const_expr!(msb)
            let lsb = eval_const_expr!(lsb)

            match ty {
                Vector(ty=inner_ty, len~) => {
                    if msb >= len.expect_fixed!(span) {
                        raise InvalidSlicingRange(span~)
                    }

                    if lsb >= msb {
                        raise InvalidSlicingRange(span~)
                    }

                    @parse.Type::Vector(ty=inner_ty, len=Fixed((msb - lsb) + 1))
                }
                _ => raise IndexedExpressionMustBeVector(span~)
            }
        }
        FieldAccess(expr~, field=port, span~, ..) => {
            match self.check_expr!(expr, env) {
                Instance(sig~, params~, accessed_ports~) => {
                    match sig.get_port(port) {
                        Some(port_def) => {
                            accessed_ports.add(port)
                            port_def.ty.substitute(params_env=params)
                        }
                        None => raise UnknownModulePort(module_name=sig.name, port_name=port, span~)
                    }
                }
                Struct(fields) => {
                    match fields[port] {
                        Some(ty) => ty
                        None => raise InvalidStructField(name=port, span~)
                    }
                }
                _ => raise InvalidFieldAccess(field=port, span~)
            }
        }
        Instance(name~, params~, ports~, span~, ..) => {
            match self.modules[name] {
                Some(sig) => {
                    let subst = {}
                    let params_env = {}
                    let accessed_ports = Set::new()
                    let params_map = @parse.instance_params_to_map!(params, names=sig.params)

                    for name, param in params_map {
                        match param.expect_int?() {
                            Ok(n) => {
                                subst[name] = n
                            }
                            _ => ()
                        }

                        params_env[name] = param.as_param!()
                    }

                    for port_name, expr in ports {
                        match sig.get_port(port_name) {
                            Some(port_def) => {
                                let expr_ty = self.check_expr!(expr, env).substitute(params_env~)
                                let _ = unify!(port_def.ty.substitute(params_env~), expr_ty, span=expr.span(), subst~)
                            }
                            None => raise UnknownModulePort(module_name=name, port_name=port_name, span~)
                        }
                    }

                    @parse.Type::Instance(sig~, params=params_env, accessed_ports~)
                }
                None => raise TypeCheckerError::UnknownModule(name~, span~)
            }
        }
        Vector(elems~, span~, ..) => {
            if elems.is_empty() {
                raise EmptyVector(span~)
            }

            let mut elem_ty = None
            let mut len = 0
            let subst = {}

            fn check_elem_ty(ty: @parse.Type) -> Unit!TypeCheckerError {
                match elem_ty {
                    Some(ty2) => {
                        let _ = unify!(ty, ty2, span~, subst~)
                    }
                    None => {
                        elem_ty = Some(ty)
                    }
                }
            }

            for elem in elems {
                match elem {
                    Spread(expr~, ..) => {
                        match self.check_expr!(expr, env) {
                            Vector(ty=inner_ty, len=spread_len) => {
                                check_elem_ty!(inner_ty)
                                len += spread_len.expect_fixed!(expr.span())
                            }
                            Logic => {
                                check_elem_ty!(Logic)
                                len += 1
                            }
                            _ => raise SpreadOnNonVector(span~)
                        }
                    }
                    _ => {
                        check_elem_ty!(self.check_expr!(elem, env))
                        len += 1
                    }
                }
            }

            @parse.Type::Vector(ty=elem_ty.unwrap(), len=Fixed(len))
        }
        Spread(span~, ..) => {
            raise SpreadOutsideVector(span~)
        }
        Ternary(cond~, then~, else_~, span~, ..) => {
            let cond_ty = self.check_expr!(cond, env)
            let then_ty = self.check_expr!(then, env, expected_ty~)
            let else_ty = self.check_expr!(else_, env, expected_ty~)

            let _ = unify!(cond_ty, @parse.Logic, span~)
            let ty = self.resolve_ty!(then_ty, span~)
            let _ = unify!(ty, else_ty, span~)

            ty
        }
        Match(subject~, cases~, default~, span~, ..) => {
            let subject_ty = self.check_expr!(subject, env)
            
            if cases.is_empty() && default.is_empty() {
                raise EmptyMatch(span~)
            }

            let mut ret_ty = None
            let subst = {}

            fn check_ret_ty(ty: @parse.Type) -> Unit!TypeCheckerError {
                match ret_ty {
                    Some(ty2) => {
                        let _ = unify!(ty, ty2, span~, subst~)
                    }
                    None => {
                        ret_ty = Some(ty)
                    }
                }
            }

            for case in cases {
                let (pat, expr) = case
                let pat_ty = self.check_expr!(pat, env)
                let expr_ty = self.check_expr!(expr, env, expected_ty~)
                let _ = unify!(subject_ty, pat_ty, subst~, span~)
                check_ret_ty!(expr_ty)
            }

            match default {
                Some(expr) => {
                    let expr_ty = self.check_expr!(expr, env, expected_ty~)
                    check_ret_ty!(expr_ty)
                }
                None => ()
            }

            ret_ty.unwrap()
        }
        Tuple(elems~, ..) => {
            let fields = Map::new(capacity=elems.length())

            for idx, elem in elems {
                fields[idx.to_string()] = self.check_expr!(elem, env)
            }

            @parse.Type::Struct(fields)
        }
        Replicate(expr~, count~, concat~, span~, ..) => {
            let count_ty = self.check_expr!(count, env)
            let _ = unify!(count_ty, @parse.Nat, span~)
            let expr_ty = self.check_expr!(expr, env)
            let count = eval_const_expr!(count)
            
            let (elem_ty, len) = match concat {
                true => {
                    let expr_width = expr_ty.width!(expr.span())
                    (@parse.Type::Logic, count * expr_width)
                }
                false => (expr_ty, count)
            }

            Vector(ty=elem_ty, len=Fixed(len))
        }
        FunCall(span~, ..) => {
            raise FunCallAfterMonomorphization(span~)
        }
        Struct(fields~, ..) => {
            let field_tys = Map::new(capacity=fields.size())

            for name, ty in fields {
                field_tys[name] = self.check_expr!(ty, env)
            }

            @parse.Type::Struct(field_tys)
        }
    }

    expr.set_ty(ty)

    ty
}

fn check_stmt(self: TypeChecker, stmt: @parse.Stmt, env: Scope[@parse.Type]) -> Unit! {
    match stmt {
        Expr(expr~, ..) => {
            let _ = self.check_expr!(expr, env)
        }
        Let(name~, ty~, expr~, span~, ..) => {
            ty.val = Some(match (ty.val, expr) {
                (Some(ty), Some(expr)) => {
                    let ty = self.resolve_ty!(ty, span~)
                    declare_name!(env~, name~, ty~, span~)
                    let expr_ty = self.check_expr!(expr, env, expected_ty=Some(ty))
                    let _ = unify!(ty, expr_ty, span~)

                    ty
                }
                (Some(ty), None) => {
                    let ty = self.resolve_ty!(ty, span~)
                    declare_name!(env~, name~, ty~, span~)
                    ty
                }
                (None, Some(expr)) => {
                    let ty = self.check_expr!(expr, env)
                    declare_name!(env~, name~, ty~, span~)

                    ty
                }
                (None, None) => {
                    raise LetStmtMustHaveTypeOrValue(span~)
                }
            })
        }
        Assign(lhs~, rhs~, span~, ..) => {
            let is_valid_assignment_target = match lhs {
                Identifier(..) | Indexing(..) | Slicing(..) | FieldAccess(..) => true
                _ => false
            };

            if not(is_valid_assignment_target) {
                raise InvalidAssignmentTarget(span~)
            }

            let lhs_ty = self.check_expr!(lhs, env)
            let rhs_ty = self.check_expr!(rhs, env, expected_ty=Some(lhs_ty))
            let _ = unify!(lhs_ty, rhs_ty, span~)
        }
        Scope(body~, ..) => {
            let new_env = env.child()

            for stmt in body {
                self.check_stmt!(stmt, new_env)
            }
        }
        For(var~, range~, body~, span~, ..) => {
            let start_ty = self.check_expr!(range.start, env)
            let end_ty = self.check_expr!(range.end, env)

            match (start_ty, end_ty) {
                (Nat(_), Nat(_)) => ()
                _ => raise ExpectedConstantExpr(span~)
            }

            let body_env = env.child()
            body_env.declare!(var, end_ty)

            for stmt in body {
                self.check_stmt!(stmt, body_env)
            }
        }
        Const(decl~, span=_) => {
            self.check_const_decl!(decl, env)
        }
    }
}

fn ensure_valid_port_type(ty: @parse.Type, span: @parse.Span) -> Unit!TypeCheckerError {
    match ty {
        Logic | Vector(ty=Logic, len=_) => ()
        _ => raise InvalidPortType(ty=ty, span~)
    }
}

enum AttributeValueType {
    Str
    // Int
}

let module_attribute_signatures: Map[String, Array[AttributeValueType]] = {
    "internal": [],
    "alias": [Str],
}

let port_attribute_signatures: Map[String, Array[AttributeValueType]] = {
    "inout": [],
}

fn check_attribute(attr: @parse.Attribute, signatures~: Map[String, Array[AttributeValueType]]) -> Unit!TypeCheckerError {
    match signatures[attr.name] {
        Some(expected) => {
            if expected.length() != attr.args.length() {
                raise InvalidAttributeArgs(name=attr.name, args=attr.args, span=attr.span)
            }

            for arg, expected in @utils.zip2(attr.args, expected) {
                match (arg, expected) {
                    // (Int(_), Int) => ()
                    (String(_), Str) => ()
                    _ => raise InvalidAttributeArgs(name=attr.name, args=attr.args, span=attr.span)
                }
            }
        }
        None => raise InvalidAttribute(name=attr.name, span=attr.span)
    }
}

fn check_attributes(attrs: Map[String, @parse.Attribute], signatures~: Map[String, Array[AttributeValueType]]) -> Unit!TypeCheckerError {
    for attr in attrs.values() {
        check_attribute!(attr, signatures~)
    }
}

fn check_const_decl(self: TypeChecker, decl: @parse.ConstDecl, env: Scope[@parse.Type]) -> Unit! {
    if not(decl.expr.is_constant_expr()) {
        raise ExpectedConstantExpr(span=decl.expr.span())
    }

    let ty = self.check_expr!(decl.expr, env)

    match decl.ty {
        Some(expected_ty) => {
            let expected_ty = self.resolve_ty!(expected_ty, span=decl.expr.span())
            let _ = unify!(expected_ty, ty, span=decl.expr.span())
        }
        None => ()
    }

    declare_name!(env~, name=decl.name, ty~, span=decl.span)
}

pub fn check_decl(self: TypeChecker, decl: @parse.Decl) -> Unit! {
    match decl {
        Module({ name, params: _, attributes, ports, body, span: _ } as mod) => {
            let env = self.top_env.child()

            check_attributes!(attributes, signatures=module_attribute_signatures)

            for port in ports {
                ensure_valid_port_type!(port.ty, port.span)
                check_attributes!(port.attributes, signatures=port_attribute_signatures)
                declare_name!(env~, name=port.name, ty=port.ty, span=port.span)
            }

            for stmt in body {
                self.check_stmt!(stmt, env)
            }

            self.modules[name] = mod.signature()
        }
        ModuleDeclaration(sig) => {
            check_attributes!(sig.attributes, signatures=module_attribute_signatures)
            
            for port in sig.ports {
                ensure_valid_port_type!(port.ty, port.span)
                check_attributes!(port.attributes, signatures=port_attribute_signatures)
            }

            self.modules[sig.name] = sig
        }
        Const(decl) => {
            self.check_const_decl!(decl, self.top_env)
        }
    }
}

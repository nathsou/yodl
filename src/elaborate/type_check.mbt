
struct TypeChecker {
    modules: Map[@parse.Path, @parse.ModuleSignature]
    top_env: Scope[@parse.Path, @parse.Type]
}

pub fn TypeChecker::new() -> TypeChecker {
    {
        modules: {},
        top_env: Scope::new(),
    }
}

type! TypeCheckerError {
    UnboundVariable(path~: @parse.Path, span~: @parse.Span)
    IncompatibleTypes(ty1~: @parse.Type, ty2~: @parse.Type, span~: @parse.Span)
    VariableRedeclared(path~: @parse.Path, span~: @parse.Span)
    InvalidAssignmentTarget(span~: @parse.Span)
    IndexMustBeInteger(span~: @parse.Span)
    IndexedExpressionMustBeVector(span~: @parse.Span)
    UnknownModule(path~: @parse.Path, span~: @parse.Span)
    UnknownModulePort(module_path~: @parse.Path, port_name~: String, span~: @parse.Span)
    InvalidFieldAccess(field~: String, span~: @parse.Span)
    InvalidSlicingRange(reason~: String, span~: @parse.Span)
    ExpectedConstantExpr(span~: @parse.Span)
    LetStmtMustHaveTypeOrValue(span~: @parse.Span)
    InvalidAttribute(name~: String, span~: @parse.Span)
    InvalidAttributeArgs(name~: String, args~: Array[@parse.AttributeValue], span~: @parse.Span)
    EmptyMatch(span~: @parse.Span)
    InvalidInstanceTypeParameterCount(module_path~: @parse.Path, expected~: Int, actual~: Int, span~: @parse.Span)
    FunCallAfterMonomorphization(span~: @parse.Span)
    InvalidStructField(name~: String, span~: @parse.Span)
    InvalidUnaryOpOperand(op~: @parse.UnaryOp, ty~: @parse.Type, span~: @parse.Span)
    InvalidBinaryOpOperand(op~: @parse.BinaryOp, ty~: @parse.Type, span~: @parse.Span)
    StringContainsNonAsciiChar(char~: Char, span~: @parse.Span)
    SpreadOutsideVector(span~: @parse.Span)
}

pub impl Show for TypeCheckerError with output(self, logger) {
    match self {
        UnboundVariable(path~, ..) => {
            logger.write_string("Unbound variable '\{path}'")
        }
        IncompatibleTypes(ty1~, ty2~, ..) => {
            logger.write_string("Incompatible types '\{ty1}' and '\{ty2}'")
        }
        VariableRedeclared(path~, ..) => {
            logger.write_string("Variable '\{path}' redeclared")
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
        UnknownModule(path~, ..) => {
            logger.write_string("Unknown module '\{path}'")
        }
        UnknownModulePort(module_path~, port_name~, ..) => {
            logger.write_string("Unknown port '\{port_name}' in module '\{module_path}'")
        }
        InvalidFieldAccess(field~, ..) => {
            logger.write_string("Invalid field access '\{field}'")
        }
        InvalidSlicingRange(reason~, ..) => {
            logger.write_string("Invalid slicing range: \{reason}")
        }
        ExpectedConstantExpr(..) => {
            logger.write_string("Expected constant expression")
        }
        LetStmtMustHaveTypeOrValue(..) => {
            logger.write_string("Let statement must have a type or value")
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
        InvalidInstanceTypeParameterCount(module_path~, expected~, actual~, ..) => {
            logger.write_string("Module '\{module_path}' expected \{expected} type parameters, got \{actual}")
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
        SpreadOutsideVector(..) => {
            logger.write_string("Spread outside vector")
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
        LetStmtMustHaveTypeOrValue(span~, ..) => span
        InvalidAttribute(span~, ..) => span
        InvalidAttributeArgs(span~, ..) => span
        EmptyMatch(span~, ..) => span
        InvalidInstanceTypeParameterCount(span~, ..) => span
        FunCallAfterMonomorphization(span~, ..) => span
        InvalidStructField(span~, ..) => span
        InvalidUnaryOpOperand(span~, ..) => span
        InvalidBinaryOpOperand(span~, ..) => span
        StringContainsNonAsciiChar(span~, ..) => span
        SpreadOutsideVector(span~, ..) => span
    }
}

fn unify_aux(eqs: Array[(@parse.Type, @parse.Type)], span~: @parse.Span, subst~: Map[String, Int] = {}) -> Map[String, Int]!TypeCheckerError {
    while not(eqs.is_empty()) {
        let (ty1, ty2) = eqs.pop().unwrap()

        if ty1 == ty2 {
            continue
        }

        match (ty1, ty2) {
            (Vector(ty=ty1_inner, len=Fixed(len)), Vector(ty=ty2_inner, len=Dynamic(Identifier(path={ packages: [], member }, ..)))) => {
                match subst[member] {
                    Some(len2) => {
                        if len != len2 {
                            raise IncompatibleTypes(ty1~, ty2~, span~)
                        }
                    }
                    None => {
                        subst[member] = len
                    }
                }

                eqs.push((ty1_inner, ty2_inner))
            }
            (UInt(_), Nat) | (Nat, UInt(_)) => ()
            (Vector(ty=_, len=Dynamic(Identifier(_))), Vector(ty=_, len=Fixed(_))) => {
                eqs.push((ty2, ty1))
            }
            (Instance(sig=sig1, params=params1, accessed_ports=accessed_ports1), Instance(sig=sig2, params=params2, accessed_ports=accessed_ports2)) => {
                if sig1.path != sig2.path {
                    raise IncompatibleTypes(ty1~, ty2~, span~)
                } else if params1 == params2 {
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
            (String(len~), ty2) | (ty2, String(len~)) => {
                eqs.push((Vector(ty=@parse.Type::uint(@parse.BITS_PER_CHAR), len=Fixed(len)), ty2))
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

fn declare_name(env~: Scope[@parse.Path, @parse.Type], path~: @parse.Path, ty~: @parse.Type, span~: @parse.Span) -> Unit!TypeCheckerError {
    match env.declare?(path, ty) {
        Ok(_) => ()
        Err(MemberAlreadyDeclared(_)) => raise VariableRedeclared(path~, span~)
    }
}

// expr should already have been partially evaluated using `Expr::partial_eval`
// during the monomorphization pass
fn eval_const_expr(expr: @parse.Expr) -> Int! {
    match expr {
        Natural(value~, ..) => value.to_int()
        _ => raise ExpectedConstantExpr(span=expr.span())
    }
}

fn resolve_ty(self: TypeChecker, ty: @parse.Type, span~: @parse.Span) -> @parse.Type! {
    match ty {
        UInt(width) => UInt(width)
        SInt(width) => SInt(width)
        Nat => Nat
        Vector(ty=inner_ty, len~) => Vector(ty=self.resolve_ty!(inner_ty, span~), len~)
        Instance(_) => ty
        Name(path~, params~) => {
            match self.modules[path] {
                Some(sig) => {
                    if sig.params.length() != params.length() {
                        raise InvalidInstanceTypeParameterCount(module_path=path, expected=sig.params.length(), actual=params.length(), span~)
                    }

                    Instance(sig~, params=Map::from_iter(@utils.zip(sig.params, params)), accessed_ports=Set::new())
                }
                None => raise TypeCheckerError::UnknownModule(path~, span~)
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

fn check_expr(self: TypeChecker, expr: @parse.Expr, env: Scope[@parse.Path, @parse.Type], expected_ty~: @parse.Type? = None) -> @parse.Type! {
    let ty = match expr {
        Identifier(path~, span~, ..) => {
            match env.resolve(path) {
                Some(ty) => ty
                None => {
                    raise UnboundVariable(path~, span~)
                }
            }
        }
        Natural(width~, ..) => match width {
            Some(width) => @parse.Type::uint(width)
            None => Nat
        }
        String(value=str,  span~, ..) => {
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

            @parse.Type::uint(wy)
        }
        Indexing(expr~, index~, span~, ..) => {
            let ty = self.check_expr!(expr, env)
            let index_ty = self.check_expr!(index, env)

            if not(index_ty.is_numerical()) {
                raise IndexMustBeInteger(span=index.span())
            }

            match ty {
                Vector(ty=inner_ty, ..) => inner_ty
                UInt(_) | SInt(_) => @parse.Type::uint(1)
                String(_) => @parse.Type::uint(@parse.BITS_PER_CHAR)
                _ => raise IndexedExpressionMustBeVector(span~)
            }
        }
        Slicing(expr~, hi~, lo~, kind~, span~, ..) => {
            let ty = self.check_expr!(expr, env)
            let start_ty = self.check_expr!(hi, env)
            let end_ty = self.check_expr!(lo, env)

            if start_ty != @parse.Nat || end_ty != @parse.Nat {
                raise InvalidSlicingRange(reason="start and end must be natural numbers", span~)
            }

            let hi = eval_const_expr!(hi)
            let lo = match (kind, eval_const_expr!(lo)) {
                (Absolute, lsb) => lsb
                (Width, width) => hi + 1 - width
            }

            let width = hi + 1 - lo

            match ty {
                UInt(_) | SInt(_) => @parse.Type::uint(width)
                String(_) => @parse.Type::Vector(ty=@parse.Type::uint(@parse.BITS_PER_CHAR), len=Fixed(width))
                Vector(ty=inner_ty, len~) => {
                    let len = len.expect_fixed!(expr.span())
                    if hi >= len {
                        raise InvalidSlicingRange(reason="start index out of bounds: lsb: \{hi}, len: \{len}", span~)
                    }

                    if lo >= hi {
                        raise InvalidSlicingRange(reason="end index must be less than start index", span~)
                    }

                    @parse.Type::Vector(ty=inner_ty, len=Fixed(width))
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
                            port_def.ty.substitute(params)
                        }
                        None => raise TypeCheckerError::UnknownModulePort(module_path=sig.path, port_name=port, span~)
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
        Instance(path~, params~, ports~, span~, ..) => {
            match self.modules[path] {
                Some(sig) => {
                    let subst = {}
                    let params_env = {}
                    let accessed_ports = Set::new()
                    let params_map = params.as_map!(names=sig.params)

                    for name, param in params_map {
                        match param.as_int?() {
                            Ok(n) => {
                                subst[name] = n
                            }
                            _ => ()
                        }

                        params_env[name] = param.as_param!()
                    }

                    for port_name, port_expr in ports {
                        match sig.get_port(port_name) {
                            Some(port_def) => {
                                let expr_ty = self.check_expr!(port_expr, env).substitute(params_env)
                                let _ = unify!(port_def.ty.substitute(params_env), expr_ty, span=port_expr.span(), subst~)

                                if port_def.direction != Input && not(is_valid_assignment_target(port_expr)) {
                                    raise InvalidAssignmentTarget(span=port_expr.span())
                                }
                            }
                            None => raise TypeCheckerError::UnknownModulePort(module_path=path, port_name=port_name, span~)
                        }
                    }

                    @parse.Type::Instance(sig~, params=params_env, accessed_ports~)
                }
                None => raise TypeCheckerError::UnknownModule(path~, span~)
            }
        }
        Vector(elems~, span~, ..) => {
            if elems.is_empty() {
                return @parse.Type::empty()
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
                    Spread(expr=spread_expr, ..) => {
                        let spread_ty = self.check_expr!(spread_expr, env)
                        match spread_ty {
                            Vector(ty=spread_ty_inner, len=Fixed(spread_len)) => {
                                check_elem_ty!(spread_ty_inner)
                                len += spread_len
                            }
                            UInt(Fixed(int_len)) | SInt(Fixed(int_len)) => {
                                check_elem_ty!(UInt(Fixed(1)))
                                len += int_len
                            }
                            String(len=str_len) => {
                                check_elem_ty!(UInt(Fixed(@parse.BITS_PER_CHAR)))
                                len += str_len
                            }
                            _ => {
                                check_elem_ty!(spread_ty)
                                len += 1
                            }
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
            let cond_ty = self.check_expr!(cond, env, expected_ty=Some(@parse.Type::uint(1)))
            let then_ty = self.check_expr!(then, env, expected_ty~)
            let else_ty = self.check_expr!(else_, env, expected_ty~)

            let _ = unify!(cond_ty, @parse.Type::uint(1), span~)
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
                    (@parse.Type::uint(1), count * expr_width)
                }
                false => (expr_ty, count)
            }

            Vector(ty=elem_ty, len=Fixed(len))
        }
        FunCall(name="uint", args=[arg], ..) => {
            let arg_ty = self.check_expr!(arg, env)
            let width = arg_ty.width!(arg.span())
            @parse.Type::uint(width)
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
        Block(body~, last~, span=_, ty=_) => {
            let new_env = env.child()

            for stmt in body {
                self.check_stmt!(stmt, new_env)
            }

            match last {
                Some(last) => {
                    self.check_expr!(last, new_env, expected_ty~)
                }
                _ => @parse.Type::empty()
            }
        }
        If(cond~, then~, else_~, span~, ..) => {
            let _ = self.check_expr!(cond, env, expected_ty=Some(@parse.Type::uint(1)))
            let then_ty = self.check_expr!(then, env, expected_ty~)
            let if_ty = match else_ {
                Some(else_) => {
                    let else_ty = self.check_expr!(else_, env, expected_ty~)
                    let _ = unify!(then_ty, else_ty, span~)
                    then_ty
                }
                None => {
                    let _ = unify!(then_ty, @parse.Type::empty(), span~)
                    then_ty
                }
            }

            if_ty
        }
    }

    expr.set_ty(ty)

    ty
}

fn check_stmt(self: TypeChecker, stmt: @parse.Stmt, env: Scope[@parse.Path, @parse.Type]) -> Unit! {
    match stmt {
        Expr(expr~, ..) => {
            let _ = self.check_expr!(expr, env)
        }
        Let(name~, ty~, expr~, span~, ..) => {
            let path = @parse.Path::new([], name)

            ty.val = Some(match (ty.val, expr) {
                (Some(ty), Some(expr)) => {
                    let ty = self.resolve_ty!(ty, span~)
                    declare_name!(env~, path~, ty~, span~)
                    let expr_ty = self.check_expr!(expr, env, expected_ty=Some(ty))
                    let _ = unify!(ty, expr_ty, span~)

                    ty
                }
                (Some(ty), None) => {
                    let ty = self.resolve_ty!(ty, span~)
                    declare_name!(env~, path~, ty~, span~)
                    ty
                }
                (None, Some(expr)) => {
                    let ty = self.check_expr!(expr, env)
                    declare_name!(env~, path~, ty~, span~)

                    ty
                }
                (None, None) => {
                    raise LetStmtMustHaveTypeOrValue(span~)
                }
            })
        }
        Assign(lhs~, rhs~, span~, ..) => {
            let lhs_ty = self.check_expr!(lhs, env)
            let valid_lhs = is_valid_assignment_target(lhs)

            if not(valid_lhs) {
                raise InvalidAssignmentTarget(span~)
            }

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
            body_env.declare!(@parse.Path::new([], var), end_ty)

            for stmt in body {
                self.check_stmt!(stmt, body_env)
            }
        }
        Const(decl~, span=_) => {
            self.check_const_decl!(decl, env)
        }
    }
}

fn is_valid_assignment_target(expr: @parse.Expr) -> Bool {
    match expr {
        Identifier(..) | FieldAccess(..) => true
        Indexing(expr~, ..) | Slicing(expr~, ..) => match expr.ty().val {
            Some(Vector(_)) => true
            _ => false
        }
        _ => false
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

fn check_const_decl(self: TypeChecker, decl: @parse.ConstDecl, env: Scope[@parse.Path, @parse.Type]) -> Unit! {
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

    declare_name!(env~, path=decl.path, ty~, span=decl.span)
}

pub fn check_decl(self: TypeChecker, decl: @parse.Decl) -> Unit! {
    match decl {
        Module({ path, params: _, attributes, ports, body, span: _ } as mod) => {
            let env = self.top_env.child()
            check_attributes!(attributes, signatures=module_attribute_signatures)

            for port in ports {
                check_attributes!(port.attributes, signatures=port_attribute_signatures)
                declare_name!(env~, path=@parse.Path::new([], port.name), ty=port.ty, span=port.span)
            }

            for stmt in body {
                self.check_stmt!(stmt, env)
            }

            self.modules[path] = mod.signature()
        }
        ModuleDeclaration(sig) => {
            check_attributes!(sig.attributes, signatures=module_attribute_signatures)
            
            for port in sig.ports {
                check_attributes!(port.attributes, signatures=port_attribute_signatures)
            }

            self.modules[sig.path] = sig
        }
        Const(decl) => {
            self.check_const_decl!(decl, self.top_env)
        }
        Package(_) => ()
        Import(_) => ()
    }
}

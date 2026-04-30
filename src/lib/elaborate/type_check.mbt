using @utils { type Scope, min, max, pow2, zip, zip2, is_ascii, significant_bits, unreachable_code }
using @parse {
    type Type, type ModuleSignature, trait Spanned,
    type Expr, type Decl, type Stmt, type Attribute, type AttributeValue,
    type AccessedPorts, type ConstDecl, type ResolvedParam, keep_and_check_resolved,
}

struct TypeChecker {
    modules: Map[Path, ModuleSignature]
    top_env: Scope[Path, Type]
}

pub fn TypeChecker::new() -> TypeChecker {
    {
        modules: {},
        top_env: Scope::new(),
    }
}

priv suberror TypeCheckerError {
    TypeCheckerError(message~: String, span~: Span)
    IncompatibleTypes(ty1~: Type, ty2~: Type, span~: Span)
    InvalidAssignmentTarget(span~: Span)
    IndexedExpressionMustBeVector(span~: Span)
    UnknownModule(path~: Path, span~: Span)
    UnknownModulePort(module_path~: Path, port_name~: String, span~: Span)
    InvalidSlicingRange(reason~: String, span~: Span)
    ExpectedConstantExpr(span~: Span)
    InvalidAttributeArgs(name~: String, args~: Array[AttributeValue], expected~: Array[AttributeValueType], span~: Span)
}

impl Spanned for TypeCheckerError with span(self) -> Span {
    match self {
        TypeCheckerError(span~, ..) => span
        IncompatibleTypes(span~, ..) => span
        InvalidAssignmentTarget(span~) => span
        IndexedExpressionMustBeVector(span~) => span
        UnknownModule(span~, ..) => span
        UnknownModulePort(span~, ..) => span
        InvalidSlicingRange(span~, ..) => span
        ExpectedConstantExpr(span~) => span
        InvalidAttributeArgs(span~, ..) => span
    }
}

impl Show for TypeCheckerError with output(self, logger) {
    match self {
        TypeCheckerError(message~, ..) => {
            logger.write_string(message)
        }
        IncompatibleTypes(ty1~, ty2~, ..) => {
            logger.write_string("Incompatible types '\{ty1}' and '\{ty2}'")
        }
        InvalidAssignmentTarget(..) => {
            logger.write_string("Invalid assignment target")
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
        InvalidSlicingRange(reason~, ..) => {
            logger.write_string("Invalid slicing range: \{reason}")
        }
        ExpectedConstantExpr(..) => {
            logger.write_string("Expected constant expression")
        }
        InvalidAttributeArgs(name~, args~, expected~, ..) => {
            let expected_str = "[" + expected.iter().map(value => {
                match value {
                    Str => "str"
                    Dict => "dict"
                }
            }).join(", ") + "]"
            logger.write_string("Invalid arguments '\{args}' for attribute '\{name}', expected \{expected_str}")
        }
    }

    logger.write_string(self.show_context(use_ansi_colors=false))
}

fn type_error(message: String, span: Span) -> TypeCheckerError {
    TypeCheckerError(message~, span~)
}

priv enum UnificationParam {
    Int(Int)
    Type(Type)
}

fn unify_aux(eqs: Array[(Type, Type)], span~: Span, subst~: Map[String, UnificationParam] = {}) -> Map[String, UnificationParam] raise TypeCheckerError {
    while eqs.pop() is Some((ty1, ty2)) {
        let identical_instances = if (ty1, ty2) is (
            Instance(sig=sig1, params=params1, accessed_ports=ports1),
            Instance(sig=sig2, params=params2, accessed_ports=ports2)
        ) && sig1.path == sig2.path && params1 == params2 {
            // merge accessed ports
            ports1.merge_inplace(ports2)
            ports2.mutate(ports1)
            true
        } else {
            false
        }

        if ty1 == ty2 {
            continue
        }

        match (ty1, ty2) {
            (Vector(ty=ty1_inner, len=Fixed(len)), Vector(ty=ty2_inner, len=Dynamic(Identifier(path={ packages: [], elem }, ..)))) => {
                match subst.get(elem) {
                    Some(Int(len2)) => {
                        if len != len2 {
                            raise IncompatibleTypes(ty1~, ty2~, span~)
                        }
                    }
                    Some(Type(ty)) => {
                        raise type_error("Expected length '\{len}', got type '\{ty}'", span)
                    }
                    None => {
                        subst[elem] = Int(len)
                    }
                }

                eqs.push((ty1_inner, ty2_inner))
            }
            (Vector(ty=_, len=Dynamic(Identifier(_))), Vector(ty=_, len=Fixed(_))) => {
                eqs.push((ty2, ty1))
            }
            (UInt(Fixed(width)) | SInt(Fixed(width)), Nat(min_width)) | (Nat(min_width), UInt(Fixed(width)) | SInt(Fixed(width))) => {
                min_width.update(width)
            }
            (UInt(_) | SInt(_), Nat(_)) | (Nat(_), UInt(_) | SInt(_)) => ()
            (Nat(mw1), Nat(mw2)) if mw1.min_width != mw2.min_width => {
                mw1.update(mw2.min_width)
                mw2.update(mw1.min_width)
            }
            (Instance(..), Instance(..)) if identical_instances => ()
            (String(len~), ty2) | (ty2, String(len~)) => {
                eqs.push((Vector(ty=Type::uint(@parse.BITS_PER_CHAR), len=Fixed(len)), ty2))
            }
            _ => {
                raise IncompatibleTypes(ty1~, ty2~, span~)
            }
        }
    }

    subst
}

fn unify(ty1: Type, ty2: Type, span~: Span, subst~: Map[String, UnificationParam] = {}) -> Map[String, UnificationParam] raise TypeCheckerError {
    unify_aux([(ty1, ty2)], span~, subst~)
}

fn declare_name(env~: Scope[Path, Type], path~: Path, ty~: Type, span~: Span) -> Unit raise TypeCheckerError {
    try env.declare_(path, ty) catch {
        MemberAlreadyDeclared(_) => {
            raise type_error("Variable '\{path}' redeclared", span)
        }
    }
}

// expr should already have been partially evaluated using `Expr::partial_eval`
// during the monomorphization pass
fn eval_const_expr(expr: Expr) -> Int raise {
    match expr {
        Natural(value~, ..) => value.to_int()
        _ => raise ExpectedConstantExpr(span=expr.span())
    }
}

fn TypeChecker::resolve_ty(self: Self, ty: Type, span~: Span) -> Type raise {
    match ty {
        UInt(width) => UInt(width)
        SInt(width) => SInt(width)
        Nat(mw) => Nat(mw)
        Clock => Clock
        Vector(ty=inner_ty, len~) => Vector(ty=self.resolve_ty(inner_ty, span~), len~)
        Instance(_) => ty
        Name(path~, params~) => {
            match self.modules.get(path) {
                Some(sig) => {
                    if sig.params.length() != params.length() {
                        raise type_error("Module '\{path}' expected \{sig.params.length()} type parameters, got \{params.length()}", span)
                    }

                    Instance(sig~, params=Map::from_iter(zip(sig.params.map(p => p.name), params)), accessed_ports=AccessedPorts::new())
                }
                None => raise UnknownModule(path~, span~)
            }
        }
        Struct(fields) => {
            let field_tys = Map::new(capacity=fields.length())

            for name, ty in fields {
                field_tys[name] = self.resolve_ty(ty, span~)
            }

            Struct(field_tys)
        }
        String(len~) => String(len~)
    }
}

fn TypeChecker::check_expr(self: Self, expr: Expr, env: Scope[Path, Type], expected_ty~: Type? = None) -> Type raise {
    let ty = match expr {
        Identifier(path~, span~, ..) => {
            match env.resolve(path) {
                Some(ty) => ty
                None => {
                    raise type_error("Unbound variable '\{path}'", span)
                }
            }
        }
        Natural(value~, width~, ..) => match width {
            Some(width) => Type::uint(width)
            None => Nat({min_width: significant_bits(value, is_signed=false)})
        }
        String(value=str,  span~, ..) => {
            for char in str {
                if !is_ascii(char) {
                    raise type_error("String contains non-ASCII character '\{char}'", span)
                }
            }

            Type::String(len=str.length())
        }
        Unary(op~, expr~, span~, ..) => {
            let ty = self.check_expr(expr, env, expected_ty~)
 
            if !ty.is_numerical() {
                raise type_error("Invalid operand type '\{ty}' for unary operator '\{op}, expected uint or sint", span)
            }

            match op {
                Not => ty
                Neg => SInt(Fixed(ty.width(span) + 1))
                Andr | Orr | Xorr => Type::uint(1)
            }
        }
        Binary(op~, lhs~, rhs~, output_width~, span~, ..) => {
            let lhs_ty = self.check_expr(lhs, env)
            let rhs_ty = self.check_expr(rhs, env)
            let wa = lhs_ty.width(lhs.span())
            let wb = rhs_ty.width(rhs.span())

            if !lhs_ty.is_numerical() {
                raise type_error("Invalid operand type '\{lhs_ty}' for binary operator '\{op}'", span)
            }

            let shift_amount = match op {
                Shl | Shr => match rhs {
                    Natural(value~, ..) => Some(value.to_int())
                    _ => None
                }
                _ => None
            }

            let lhs_ty = match lhs_ty {
                Nat({min_width}) => Type::UInt(Fixed(min_width))
                _ => lhs_ty
            }

            let rhs_ty = match rhs_ty {
                Nat({min_width}) => Type::UInt(Fixed(min_width))
                _ => rhs_ty
            }

            let out_ty = match (op, lhs_ty, rhs_ty) {
                (Add | Sub, UInt(_), UInt(_)) => Type::uint(max(wa, wb) + 1)
                (Add | Sub, SInt(_), SInt(_)) => Type::sint(max(wa, wb) + 1)
                (Mul, UInt(_), UInt(_)) => Type::uint(wa + wb)
                (Mul, SInt(_), SInt(_)) => Type::sint(wa + wb)
                (Div, UInt(_), UInt(_)) => Type::uint(wa)
                (Div, SInt(_), SInt(_)) => Type::sint(wa + 1)
                (Mod, UInt(_), UInt(_)) => Type::uint(min(wa, wb))
                (Mod, SInt(_), SInt(_)) => Type::sint(min(wa, wb))
                (Equ | Neq | Gtr | Lss | Geq | Leq, UInt(_), UInt(_)) => Type::uint(1)
                (Equ | Neq | Gtr | Lss | Geq | Leq, SInt(_), SInt(_)) => Type::uint(1)
                (Shl, UInt(_), UInt(_)) => match shift_amount {
                    Some(amount) => Type::uint(wa + amount)
                    None => Type::uint(wa + pow2(wb).to_int() - 1)
                }
                (Shl, SInt(_), UInt(_)) => match shift_amount {
                    Some(amount) => Type::sint(wa + amount)
                    None => Type::sint(wa + pow2(wb).to_int() - 1)
                }
                (Shr, UInt(_), UInt(_)) => match shift_amount {
                    Some(amount) => Type::uint(max(wa - amount, 0))
                    None => Type::uint(wa)
                }
                (Shr, SInt(_), UInt(_)) => {
                    match shift_amount {
                        Some(amount) => Type::sint(max(wa - amount, 1))
                        None => Type::sint(wa)
                    }
                }
                (And | Or | Xor | Nand | Nor | Xnor | Ternary, UInt(_), UInt(_)) => Type::uint(max(wa, wb))
                (And | Or | Xor | Nand | Nor | Xnor | Ternary, SInt(_), SInt(_)) => Type::uint(max(wa, wb))
                _ => raise type_error("Invalid operands '\{lhs_ty}' and '\{rhs_ty}' for binary operator '\{op}'", span)
            }

            let wy = out_ty.width(span)
            output_width.val = Some(wy)

            match expected_ty {
                Some(expected_ty) => expected_ty
                None => out_ty
            }
        }
        Indexing(expr~, index~, span~, ..) => {
            let ty = self.check_expr(expr, env)
            let index_ty = self.check_expr(index, env)

            if !index_ty.is_numerical() {
                raise type_error("Index must be an integer", index.span())
            }

            match ty {
                Vector(ty=inner_ty, ..) => inner_ty
                UInt(_) | SInt(_) => Type::uint(1)
                String(_) => Type::uint(@parse.BITS_PER_CHAR)
                _ => raise IndexedExpressionMustBeVector(span~)
            }
        }
        Slicing(expr~, hi~, lo~, kind~, span~, ..) => {
            let ty = self.check_expr(expr, env)
            let start_ty = self.check_expr(hi, env)
            let end_ty = self.check_expr(lo, env)

            match (start_ty, end_ty) {
                (Nat(_), Nat(_)) => ()
                _ => raise InvalidSlicingRange(reason="start and end must be natural numbers", span~)
            }

            let hi = eval_const_expr(hi)
            let lo = match (kind, eval_const_expr(lo)) {
                (Absolute, lsb) => lsb
                (Width, width) => hi + 1 - width
            }

            let width = hi + 1 - lo

            match ty {
                UInt(_) | SInt(_) => Type::uint(width)
                String(_) => Type::Vector(ty=Type::uint(@parse.BITS_PER_CHAR), len=Fixed(width))
                Vector(ty=inner_ty, len~) => {
                    let len = len.expect_fixed(expr.span())
                    if hi >= len {
                        raise InvalidSlicingRange(reason="start index out of bounds: lsb: \{hi}, len: \{len}", span~)
                    }

                    if lo >= hi {
                        raise InvalidSlicingRange(reason="end index must be less than start index", span~)
                    }

                    Type::Vector(ty=inner_ty, len=Fixed(width))
                }
                _ => raise IndexedExpressionMustBeVector(span~)
            }
        }
        FieldAccess(expr~, field=port, span~, ..) => {
            match self.check_expr(expr, env) {
                Instance(sig~, params~, accessed_ports~) => {
                    let resolved_params = keep_and_check_resolved(params, span~)

                    match sig.get_port(port) {
                        Some(port_def) => {
                            accessed_ports.set(port, Read)
                            port_def.ty.substitute(resolved_params, span~)
                        }
                        None => raise UnknownModulePort(module_path=sig.path, port_name=port, span~)
                    }
                }
                Struct(fields) => {
                    match fields.get(port) {
                        Some(ty) => ty
                        None => raise type_error("Invalid struct field '\{port}'", span)
                    }
                }
                ty => raise type_error("Invalid field access '\{port}' on type '\{ty}'", span)
            }
        }
        Instance(path~, params~, ports~, span~, ..) => {
            match self.modules.get(path) {
                Some(sig) => {
                    let subst: Map[String, UnificationParam] = {}
                    let params_env: Map[String, ResolvedParam] = {}
                    let accessed_ports = AccessedPorts::new()
                    let params_map = params.as_map(names=sig.params.map(fn(p) { p.name }))

                    // check monomorphized (erased) parameters
                    for param in params.instantiated {
                        let (expr, ann, span) = param
                        let expr_ty = self.check_expr(expr, env)
                        let expr_ty = self.resolve_ty(expr_ty, span~)
                        let _ = unify(expr_ty, ann, span=span, subst~)
                    }

                    for name, param in params_map {
                        let param_sig = sig.get_param(name)

                        match (param, param_sig) {
                            (Resolved(ConstParam(value~, ..) as cnst_param), Some({ ty: Type(param_ty), span: param_span, .. })) => {
                                let value_ty = self.check_expr(value.as_expr(), env)
                                let _ = unify(param_ty, value_ty, span=param_span, subst~)

                                match value {
                                    Natural(value=n, ..) => {
                                        subst[name] = Int(n.to_int())
                                    }
                                    _ => ()
                                }

                                params_env[name] = cnst_param
                            }
                            (Resolved(TypeParam(ty~, span~)) | Unresolved(TypeParam(ty~, span~)), Some({ ty: AnyType, .. })) => {
                                let ty = self.resolve_ty(ty, span~)
                                subst[name] = Type(ty)
                                params_env[name] = TypeParam(ty~, span~)
                            }
                            (Unresolved(_), _) => raise type_error("Unresolved parameter '\{name}'", span)
                            _ => {
                                let ty = match param {
                                    Unresolved(_) => unreachable_code()
                                    Resolved(ConstParam(value~, ..)) => self.check_expr(value.as_expr(), env)
                                    Resolved(TypeParam(ty~, span~)) => self.resolve_ty(ty, span~)
                                }

                                let expected_ty = "[" + param_sig.iter().map(p => p.ty.to_string()).join(", ") + "]"
                                raise type_error(
                                    "Invalid instantiation of parameter '\{name}' with type '\{ty}', expected '\{expected_ty}'",
                                    param.span(),
                                )
                            }
                        }
                    }

                    for port_name, port_expr in ports {
                        match sig.get_port(port_name) {
                            Some(port_def) => {
                                let expr_ty = self.check_expr(port_expr, env).substitute(params_env, span~)
                                let _ = unify(port_def.ty.substitute(params_env, span~), expr_ty, span=port_expr.span(), subst~)

                                if port_def.dir != Input && !is_valid_assignment_target(port_expr) {
                                    raise InvalidAssignmentTarget(span=port_expr.span())
                                }
                            }
                            None => raise UnknownModulePort(module_path=path, port_name=port_name, span~)
                        }
                    }

                    if (path.elem == "Reg" || path.elem == "RegAsyncReset") && path.packages.is_empty() {
                        accessed_ports.register_access("d")
                        accessed_ports.register_access("q")
                    }

                    Type::Instance(sig~, params=params_map, accessed_ports~)
                }
                None => raise UnknownModule(path~, span~)
            }
        }
        Vector(elems~, span~, ..) => {
            if elems.is_empty() {
                return Type::empty()
            }

            let mut elem_ty = None
            let mut len = 0
            let subst = {}

            fn check_elem_ty(ty: Type) -> Unit raise TypeCheckerError {
                match elem_ty {
                    Some(ty2) => {
                        let _ = unify(ty, ty2, span~, subst~)
                    }
                    None => {
                        elem_ty = Some(ty)
                    }
                }
            }

            for elem in elems {
                match elem {
                    Spread(expr=spread_expr, ..) => {
                        let spread_ty = self.check_expr(spread_expr, env)
                        match spread_ty {
                            Vector(ty=spread_ty_inner, len=Fixed(spread_len)) => {
                                check_elem_ty(spread_ty_inner)
                                len += spread_len
                            }
                            UInt(Fixed(int_len)) | SInt(Fixed(int_len)) => {
                                check_elem_ty(UInt(Fixed(1)))
                                len += int_len
                            }
                            String(len=str_len) => {
                                check_elem_ty(UInt(Fixed(@parse.BITS_PER_CHAR)))
                                len += str_len
                            }
                            _ => {
                                check_elem_ty(spread_ty)
                                len += 1
                            }
                        }
                    }
                    _ => {
                        check_elem_ty(self.check_expr(elem, env))
                        len += 1
                    }
                }
            }

            Type::Vector(ty=elem_ty.unwrap(), len=Fixed(len))
        }
        Spread(span~, ..) => {
            raise type_error("Spread outside vector", span)
        }
        Concat(elems~, ..) => {
            let mut len = 0
            let mut is_signed: Bool? = None
            let stack = @stack.new()

            for elem in elems {
                let ty = self.check_expr(elem, env)
                let span = elem.span()
                len += ty.width(span)
                stack.push((ty, span))
            }

            while !stack.is_empty() {
                let (ty, span) = stack.unsafe_pop()

                match ty {
                    UInt(_) | SInt(_) | Nat(_) => {
                        let is_elem_signed = ty is SInt(_)

                        match is_signed {
                            Some(is_signed) => {
                                if is_signed != is_elem_signed {
                                    raise type_error("Cannot mix unsigned and signed integers in a concatenation expression", span)
                                }
                            }
                            None => {
                                is_signed = Some(is_elem_signed)
                            }
                        }
                    }
                    Vector(ty=elem_ty, len=_) => {
                        stack.push((elem_ty, span))
                    }
                    _ => raise type_error("Invalid element of type '\{ty}' in concatenation expression", span)
                }
            }

            if is_signed is Some(true) {
                Type::sint(len)
            } else {
                Type::uint(len)
            }
        }
        Ternary(cond~, then~, else_~, span~, ..) => {
            let cond_ty = self.check_expr(cond, env, expected_ty=Some(Type::uint(1)))
            let then_ty = self.check_expr(then, env, expected_ty~)
            let else_ty = self.check_expr(else_, env, expected_ty~)

            let _ = unify(cond_ty, Type::uint(1), span~)
            let ty = self.resolve_ty(then_ty, span~)
            let _ = unify(ty, else_ty, span~)

            ty
        }
        Match(subject~, cases~, default~, span~, ..) => {
            let subject_ty = self.check_expr(subject, env)
            
            if cases.is_empty() && default is None {
                raise type_error("Empty match expression", span)
            }

            let mut ret_ty = None
            let subst = {}

            fn check_ret_ty(ty: Type) -> Unit raise TypeCheckerError {
                match ret_ty {
                    Some(ty2) => {
                        let _ = unify(ty, ty2, span~, subst~)
                    }
                    None => {
                        ret_ty = Some(ty)
                    }
                }
            }

            for case in cases {
                let (pat, expr) = case
                let pat_ty = self.check_expr(pat, env)
                let expr_ty = self.check_expr(expr, env, expected_ty~)
                let _ = unify(subject_ty, pat_ty, subst~, span~)
                check_ret_ty(expr_ty)
            }

            match default {
                Some(expr) => {
                    let expr_ty = self.check_expr(expr, env, expected_ty~)
                    check_ret_ty(expr_ty)
                }
                None => ()
            }

            ret_ty.unwrap()
        }
        Tuple(elems~, ..) => {
            let fields = Map::new(capacity=elems.length())

            for idx, elem in elems {
                fields[idx.to_string()] = self.check_expr(elem, env)
            }

            Type::Struct(fields)
        }
        Replicate(expr~, count~, concat~, span~, ..) => {
            let count_ty = self.check_expr(count, env)
            let _ = unify(count_ty, Nat({min_width: 0}), span~)
            let expr_ty = self.check_expr(expr, env)
            let count = eval_const_expr(count)
            
            let (elem_ty, len) = match concat {
                true => {
                    let expr_width = expr_ty.width(expr.span())
                    (Type::uint(1), count * expr_width)
                }
                false => (expr_ty, count)
            }

            match expr_ty {
                UInt(_) if concat => Type::uint(len)
                SInt(_) if concat => Type::sint(len)
                _ => Vector(ty=elem_ty, len=Fixed(len))
            }
        }
        FunCall(name="uint", args=[arg], ..) => {
            let arg_ty = self.check_expr(arg, env)
            let width = arg_ty.width(arg.span())
            Type::uint(width)
        }
        FunCall(name="sint", args=[arg], ..) => {
            let arg_ty = self.check_expr(arg, env)
            let width = arg_ty.width(arg.span())
            Type::sint(width)
        }
        FunCall(name="clock", args=[arg], ..) => {
            let _ = self.check_expr(arg, env, expected_ty=Some(Type::uint(1)))
            Type::Clock
        }
        FunCall(name="pad", args=[arg, width], span~, ..) => {
            let arg_ty = self.check_expr(arg, env)
            let width_ty = self.check_expr(width, env)
            let _ = unify(width_ty, Nat({min_width: 0}), span=width.span())
            let width = eval_const_expr(width)
            let required_width = arg_ty.width(arg.span())

            if width < required_width {
                raise type_error(
                    "Pad width too small: given \{width}, minimum required is \{required_width}",
                    span,
                )
            }

            match arg_ty {
                UInt(_) => Type::uint(width)
                SInt(_) => Type::sint(width)
                _ => raise Unreachable(message="", span~)
            }
        }
        FunCall(name="readmemb" | "readmemh", args=[path, mem], span~, ..) => {
            let _ = self.check_expr(path, env)
            let mem_ty = self.check_expr(mem, env)

            match mem_ty {
                Instance(sig={
                    path: { packages: [], elem: "Memory" },
                    span: { file: "builtin.yodl", .. },
                    ..
                }, ..) => ()
                _ => {
                    raise type_error("Invalid memory argument of type '\{mem_ty}' in readmem call", span)
                }
            }

            Type::empty()
        }
        FunCall(name="printf", args=[format_str, ..args], span~, ..) => {
            self.check_format_string(format_str~, args~, env~, span~)
            Type::empty()
        }
        FunCall(name="assert", args=[pred,..rest], span~, ..) => {
            let _ = self.check_expr(pred, env, expected_ty=Some(Type::bool()))

            if rest is [format_str, ..args] {
                self.check_format_string(format_str~, args~, env~, span~)
            }

            Type::empty()
        }
        FunCall(name="stop", args~, span~, ..) => {
            match args {
                [] => ()
                [exit_code] => {
                    let exit_code_ty = self.check_expr(exit_code, env)

                    if !exit_code_ty.is_numerical() {
                        raise type_error(
                            "Invalid exit code type '\{exit_code_ty}' in stop statement, expected an integer",
                            span,
                        )
                    }
                }
                _ => {
                    raise Failure::Failure("Invalid number of arguments for $stop")
                }
            }

            Type::empty()
        }
        FunCall(name="rev", args=[arg], span~, ..) => {
            let arg_ty = self.check_expr(arg, env)

            match arg_ty {
                Vector(_) => arg_ty
                _ => {
                    raise type_error("Invalid operand '\{arg_ty}' for $rev operator, expected a vector", span)
                }
            }
        }
        FunCall(name="flip", args=[arg], span~, ..) => {
            let arg_ty = self.check_expr(arg, env)

            match arg_ty {
                UInt(_) => ()
                _ => {
                    raise type_error("Invalid operand '\{arg_ty}' for $flip operator", span)
                }
            }

            arg_ty
        }
        FunCall(span~, ..) => {
            raise type_error("Function call after monomorphization", span)
        }
        Struct(fields~, ..) => {
            let field_tys = Map::new(capacity=fields.length())

            for name, ty in fields {
                field_tys[name] = self.check_expr(ty, env)
            }

            Type::Struct(field_tys)
        }
        Block(body~, last~, span=_, ty=_) => {
            let new_env = env.child()

            for stmt in body {
                self.check_stmt(stmt, new_env)
            }

            match last {
                Some(last) => {
                    self.check_expr(last, new_env, expected_ty~)
                }
                _ => Type::empty()
            }
        }
        If(cond~, then~, else_~, span~, ..) => {
            let _ = self.check_expr(cond, env, expected_ty=Some(Type::uint(1)))
            let then_ty = self.check_expr(then, env, expected_ty~)
            let if_ty = match else_ {
                Some(else_) => {
                    let else_ty = self.check_expr(else_, env, expected_ty~)
                    let _ = unify(then_ty, else_ty, span~)
                    then_ty
                }
                None => {
                    let _ = unify(then_ty, Type::empty(), span~)
                    then_ty
                }
            }

            if_ty
        }
    }

    expr.set_ty(ty)

    ty
}

fn TypeChecker::check_stmt(self: Self, stmt: Stmt, env: Scope[Path, Type]) -> Unit raise {
    match stmt {
        Expr(expr~, ..) => {
            let _ = self.check_expr(expr, env)
        }
        Let(name~, ty~, expr~, span~) => {
            let path = Path::new([], name)

            ty.val = Some(match (ty.val, expr) {
                (Some(ty), Some(expr)) => {
                    let ty = self.resolve_ty(ty, span~)
                    declare_name(env~, path~, ty~, span~)
                    let expr_ty = self.check_expr(expr, env, expected_ty=Some(ty))
                    let _ = unify(ty, expr_ty, span~)

                    ty
                }
                (Some(ty), None) => {
                    let ty = self.resolve_ty(ty, span~)
                    declare_name(env~, path~, ty~, span~)
                    ty
                }
                (None, Some(expr)) => {
                    let ty = self.check_expr(expr, env)
                    declare_name(env~, path~, ty~, span~)

                    ty
                }
                (None, None) => {
                    raise type_error("Let statement must have a type or value", span)
                }
            })
        }
        Assign(lhs~, rhs~, span~) => {
            let lhs_ty = self.check_expr(lhs, env)
            let valid_lhs = is_valid_assignment_target(lhs)

            if !valid_lhs {
                raise InvalidAssignmentTarget(span~)
            }

            // mark instance port as being written to
            if lhs is FieldAccess(expr~, field~, ..) && expr.ty().val is Some(Type::Instance(sig~, accessed_ports~, ..)) {
                if sig.get_port(field) is Some({ dir: Output, .. }) {
                    raise type_error("Cannot assign to output port '\{field}' of module '\{sig.path}'", span)
                }

                accessed_ports.register_write(field)
            }

            let rhs_ty = self.check_expr(rhs, env, expected_ty=Some(lhs_ty))
            let _ = unify(lhs_ty, rhs_ty, span~)
        }
        Scope(body~, ..) => {
            let new_env = env.child()

            for stmt in body {
                self.check_stmt(stmt, new_env)
            }
        }
        For(variable~, range~, body~, span~) => {
            let start_ty = self.check_expr(range.start, env)
            let end_ty = self.check_expr(range.end, env)

            match (start_ty, end_ty) {
                (Nat(_), Nat(_)) => ()
                _ => raise ExpectedConstantExpr(span~)
            }

            let body_env = env.child()
            body_env.declare_(Path::new([], variable), end_ty)

            for stmt in body {
                self.check_stmt(stmt, body_env)
            }
        }
        Const(decl~, span=_) => {
            self.check_const_decl(decl, env)
        }
    }
}

fn TypeChecker::check_format_string(
    self: Self,
    format_str~: Expr,
    args~: ArrayView[Expr],
    env~: Scope[Path, Type],
    span~: Span,
) -> Unit raise {
    let format_str_ty = self.check_expr(format_str, env)

    if !format_str_ty.is_string() {
        raise type_error("Invalid format string", span)
    }

    for index, arg in args {
        let arg_ty = self.check_expr(arg, env)

        if !arg_ty.is_ground() {
            raise type_error("Invalid format string argument at index \{index + 1}", span)
        }
    }
}

fn is_valid_assignment_target(expr: Expr) -> Bool {
    match expr {
        Identifier(..) | FieldAccess(..) => true
        Indexing(expr~, ..) | Slicing(expr~, ..) => match expr.ty().val {
            Some(Vector(_)) => true
            _ => false
        }
        _ => false
    }
}

priv enum AttributeValueType {
    Str
    Dict
    // Int
}

let module_attribute_signatures: Map[String, Array[AttributeValueType]] = {
    "internal": [],
    "inline": [],
    "flatten": [],
    "external": [Str, Str],
    "parameters": [Dict],
    // "alias": [Str],
}

let port_attribute_signatures: Map[String, Array[AttributeValueType]] = {}

fn check_attribute(attr: Attribute, signatures~: Map[String, Array[AttributeValueType]]) -> Unit raise TypeCheckerError {
    match signatures.get(attr.name) {
        Some(expected) => {
            if expected.length() != attr.args.length() {
                raise InvalidAttributeArgs(name=attr.name, args=attr.args, expected=expected, span=attr.span)
            }

            for arg, exp in zip2(attr.args, expected) {
                match (arg, exp) {
                    // (Int(_), Int) => ()
                    (String(_), Str) => ()
                    (Dict(_), Dict) => ()
                    _ => raise InvalidAttributeArgs(name=attr.name, args=attr.args, expected~, span=attr.span)
                }
            }
        }
    None => raise type_error("Invalid attribute '\{attr.name}'", attr.span)
    }
}

fn check_attributes(attrs: Map[String, Attribute], signatures~: Map[String, Array[AttributeValueType]]) -> Unit raise TypeCheckerError {
    for attr in attrs.values() {
        check_attribute(attr, signatures~)
    }
}

fn TypeChecker::check_const_decl(self: Self, decl: ConstDecl, env: Scope[Path, Type]) -> Unit raise {
    if !decl.expr.is_constant_expr() {
        raise ExpectedConstantExpr(span=decl.expr.span())
    }

    let ty = self.check_expr(decl.expr, env)

    match decl.ty {
        Some(expected_ty) => {
            let expected_ty = self.resolve_ty(expected_ty, span=decl.expr.span())
            let _ = unify(expected_ty, ty, span=decl.expr.span())
        }
        None => ()
    }

    declare_name(env~, path=decl.path, ty~, span=decl.span)
}

pub fn TypeChecker::check_decl(self: Self, decl: Decl) -> Unit raise {
    match decl {
        Module({ path, params: _, attributes, ports, body, span: _ } as mod) => {
            let env = self.top_env.child()
            check_attributes(attributes, signatures=module_attribute_signatures)

            for port in ports {
                check_attributes(port.attributes, signatures=port_attribute_signatures)
                declare_name(env~, path=Path::new([], port.name), ty=port.ty, span=port.span)
            }

            for stmt in body {
                self.check_stmt(stmt, env)
            }

            self.modules[path] = mod.signature()
        }
        ModuleDeclaration(sig) => {
            check_attributes(sig.attributes, signatures=module_attribute_signatures)
            
            for port in sig.ports {
                check_attributes(port.attributes, signatures=port_attribute_signatures)
            }

            self.modules[sig.path] = sig
        }
        Const(decl) => {
            self.check_const_decl(decl, self.top_env)
        }
        Package(_) => ()
        Import(_) => ()
        TypeAlias(_) => ()
    }
}
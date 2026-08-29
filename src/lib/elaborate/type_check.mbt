using @utils { type Scope, min, max, pow2, zip2, is_ascii, significant_bits }
using @parse {
    type Type, type ModuleSignature, trait Spanned,
    type Expr, type Decl, type Stmt, type Attribute, type AttributeValue,
    type ConstDecl, type StaticArg, type PortUsage, type InstanceId,
}

struct TypeChecker {
    modules: Map[Path, ModuleSignature]
    top_env: Scope[Path, Ref[Type?]]
    port_usage: PortUsage
    mut next_instance_id: Int
}

pub fn TypeChecker::new() -> TypeChecker {
    {
        modules: {},
        top_env: Scope::new(),
        port_usage: PortUsage::new(),
        next_instance_id: 0,
    }
}

pub fn TypeChecker::port_usage(self: Self) -> PortUsage {
    self.port_usage
}

fn TypeChecker::fresh_instance_id(self: Self) -> InstanceId {
    let id = InstanceId::new(self.next_instance_id)
    self.next_instance_id += 1
    id
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
            let args_str = args.iter().map(a => a.to_string()).join(", ")
            logger.write_string("Invalid arguments '[\{args_str}]' for attribute '\{name}', expected \{expected_str}")
        }
    }

    logger.write_string(Spanned::show_context(self, use_ansi_colors=false))
}

fn type_error(message: String, span: Span) -> TypeCheckerError {
    TypeCheckerError(message~, span~)
}

fn negative_unsigned_literal_error(width: Int, span: Span) -> TypeCheckerError {
    type_error("Negative literal cannot be represented as unsigned type u\{width}", span)
}

priv enum UnificationParam {
    Int(Int)
    Type(Type)
}

fn unify_aux(eqs: Array[(Type, Type)], span~: Span, subst~: Map[String, UnificationParam] = {}) -> Map[String, UnificationParam] raise TypeCheckerError {
    while eqs.pop() is Some((ty1, ty2)) {
        if ty1 == ty2 {
            continue
        }

        match (ty1, ty2) {
            (Vector(ty=ty1_inner, len=Lit(len)), Vector(ty=ty2_inner, len=Var(elem))) => {
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
            (Vector(ty=_, len=Var(_)), Vector(ty=_, len=Lit(_))) => {
                eqs.push((ty2, ty1))
            }
            (String(len~), ty2) | (ty2, String(len~)) => {
                eqs.push((Vector(ty=Type::uint(@parse.BITS_PER_CHAR), len=Lit(len)), ty2))
            }
            _ => {
                raise IncompatibleTypes(ty1~, ty2~, span~)
            }
        }
    }

    subst
}

fn merge_inferred_types(lhs: Type, rhs: Type) -> Type {
    match (lhs, rhs) {
        (Vector(ty=lhs_ty, len~), Vector(ty=rhs_ty, len=rhs_len)) if len == rhs_len => {
            Vector(ty=merge_inferred_types(lhs_ty, rhs_ty), len~)
        }
        (Struct(lhs_fields), Struct(rhs_fields)) if lhs_fields.length() == rhs_fields.length() &&
            lhs_fields.keys().all(name => rhs_fields.contains(name)) => {
            let fields = Map([], capacity=lhs_fields.length())
            for name, lhs_ty in lhs_fields {
                fields[name] = merge_inferred_types(lhs_ty, rhs_fields.get(name).unwrap())
            }
            Struct(fields)
        }
        (
            Instance(sig~, params~, ids=lhs_ids),
            Instance(sig=rhs_sig, params=rhs_params, ids=rhs_ids),
        ) if sig.path == rhs_sig.path && sig.span.file == rhs_sig.span.file && params == rhs_params => {
            let ids = Array::copy(lhs_ids)
            for id in rhs_ids {
                if !ids.contains(id) {
                    ids.push(id)
                }
            }
            Instance(sig~, params~, ids~)
        }
        _ => lhs
    }
}

fn merge_expression_types(lhs: Type, rhs: Type, span~: Span) -> Type raise TypeCheckerError {
    match (lhs, rhs) {
        (UInt(Lit(lhs_width)), UInt(Lit(rhs_width))) => Type::uint(max(lhs_width, rhs_width))
        (SInt(Lit(lhs_width)), SInt(Lit(rhs_width))) => Type::sint(max(lhs_width, rhs_width))
        (Vector(ty=lhs_ty, len~), Vector(ty=rhs_ty, len=rhs_len)) if len == rhs_len =>
            Vector(ty=merge_expression_types(lhs_ty, rhs_ty, span~), len~)
        (Struct(lhs_fields), Struct(rhs_fields)) if lhs_fields.length() == rhs_fields.length() &&
            lhs_fields.keys().all(name => rhs_fields.contains(name)) => {
            let fields = Map([], capacity=lhs_fields.length())
            for name, lhs_ty in lhs_fields {
                fields[name] = merge_expression_types(lhs_ty, rhs_fields.get(name).unwrap(), span~)
            }
            Struct(fields)
        }
        _ => {
            let _ = unify(lhs, rhs, span~)
            merge_inferred_types(lhs, rhs)
        }
    }
}

fn TypeChecker::recheck_inferred_expr(
    self: Self,
    expr: Expr,
    ty: Type,
    expected_ty: Type,
    env: Scope[Path, Ref[Type?]],
) -> Unit raise {
    match (ty, expected_ty, expr) {
        (_, (UInt(_) | SInt(_)) as expected, Natural(width=None, ..)) => {
            let _ = self.check_expr(expr, env, expected_ty=expected)
        }
        (Vector(ty=_, len~), Vector(ty=expected_elem, len=expected_len), Vector(elems~, ..)) if len == expected_len => {
            for elem in elems {
                match elem {
                    Spread(_) => ()
                    _ => match elem.ty().val {
                        Some(elem_ty) => self.recheck_inferred_expr(elem, elem_ty, expected_elem, env)
                        None => ()
                    }
                }
            }
            expr.set_ty(expected_ty)
        }
        (Struct(actual_fields), Struct(expected_fields), Struct(fields~, ..)) if actual_fields.length() == expected_fields.length() => {
            for name, field in fields {
                if !name.has_prefix("..") && expected_fields.get(name) is Some(field_expected) {
                    match field.ty().val {
                        Some(field_ty) => self.recheck_inferred_expr(field, field_ty, field_expected, env)
                        None => ()
                    }
                }
            }
            expr.set_ty(expected_ty)
        }
        _ => ()
    }
}

fn merge_assignment_target(
    lhs: Expr,
    rhs_ty: Type,
    env: Scope[Path, Ref[Type?]],
) -> Unit {
    let lhs_ty = lhs.ty().val.unwrap()
    let merged_ty = merge_inferred_types(lhs_ty, rhs_ty)
    lhs.set_ty(merged_ty)

    match lhs {
        Identifier(path~, ..) => {
            match env.resolve(path) {
                Some(binding) => binding.val = Some(merged_ty)
                None => ()
            }
        }
        FieldAccess(expr~, field~, ..) => {
            match expr.ty().val {
                Some(Struct(fields)) => {
                    let merged_fields = Map([], capacity=fields.length())
                    for name, ty in fields {
                        merged_fields[name] = if name == field { merged_ty } else { ty }
                    }
                    merge_assignment_target(expr, Struct(merged_fields), env)
                }
                _ => ()
            }
        }
        Indexing(expr~, ..) => {
            match expr.ty().val {
                Some(Vector(len~, ..)) => {
                    merge_assignment_target(expr, Vector(ty=merged_ty, len~), env)
                }
                _ => ()
            }
        }
        Slicing(expr~, ..) => {
            match (expr.ty().val, merged_ty) {
                (Some(Vector(ty=elem_ty, len~)), Vector(ty=rhs_elem_ty, ..)) => {
                    merge_assignment_target(
                        expr,
                        Vector(ty=merge_inferred_types(elem_ty, rhs_elem_ty), len~),
                        env,
                    )
                }
                _ => ()
            }
        }
        _ => ()
    }
}

fn assigned_instance_port(lhs: Expr) -> (ModuleSignature, Array[InstanceId], String)? {
    match lhs {
        FieldAccess(expr~, field~, ..) => {
            match expr.ty().val {
                Some(Type::Instance(sig~, ids~, ..)) => Some((sig, ids, field))
                _ => assigned_instance_port(expr)
            }
        }
        Indexing(expr~, ..) | Slicing(expr~, ..) => assigned_instance_port(expr)
        _ => None
    }
}

fn unify(ty1: Type, ty2: Type, span~: Span, subst~: Map[String, UnificationParam] = {}) -> Map[String, UnificationParam] raise TypeCheckerError {
    unify_aux([(ty1, ty2)], span~, subst~)
}

/// Directional compatibility for expression contexts. Unlike equality and
/// unification, this permits an integer value to be resized only when its
/// signedness is unchanged. The simplifier records every such resize as an
/// explicit Core coercion before lowering.
fn check_assignment_compatibility(expected: Type, actual: Type, span~: Span) -> Unit raise TypeCheckerError {
    if expected == actual {
        return
    }

    match (expected, actual) {
        (UInt(Lit(_)), UInt(Lit(_))) | (SInt(Lit(_)), SInt(Lit(_))) => ()
        _ => raise IncompatibleTypes(ty1=expected, ty2=actual, span~)
    }
}

fn declare_name(
    env~: Scope[Path, Ref[Type?]],
    path~: Path,
    ty~: Type,
    span~: Span,
    binding~: Ref[Type?]? = None,
) -> Unit raise TypeCheckerError {
    let binding = binding.unwrap_or({ val: Some(ty) })
    binding.val = Some(ty)
    try env.declare_(path, binding) catch {
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
        Unary(op=Neg, expr=Natural(value~, ..), ..) => -value.to_int()
        _ => raise ExpectedConstantExpr(span=expr.span())
    }
}

fn TypeChecker::check_static_nat(
    self: Self,
    expr: Expr,
    env: Scope[Path, Ref[Type?]],
) -> Int raise {
    match self.synth_expr(expr, env) {
        UInt(_) | SInt(_) => {
            let value = eval_const_expr(expr)
            if value < 0 {
                raise type_error("Expected a nonnegative constant expression", expr.span())
            }
            value
        }
        _ => raise ExpectedConstantExpr(span=expr.span())
    }
}

fn TypeChecker::resolve_ty(self: Self, ty: Type, span~: Span, type_params~: Set[String] = Set([])) -> Type raise {
    match ty {
        UInt(width) => UInt(width)
        SInt(width) => SInt(width)
        Clock => Clock
        Vector(ty=inner_ty, len~) => Vector(ty=self.resolve_ty(inner_ty, span~, type_params~), len~)
        Instance(_) => ty
        Name(path~, params~) => {
            if path.packages.is_empty() && type_params.contains(path.elem) {
                return Name(path~, params~)
            }
            match self.modules.get(path) {
                Some(sig) => {
                    if sig.params.length() != params.length() {
                        raise type_error("Module '\{path}' expected \{sig.params.length()} type parameters, got \{params.length()}", span)
                    }

                    let resolved_params: Map[String, StaticArg] = Map([])
                    for index, param in sig.params {
                        let arg = params[index]
                        match param.sort {
                            TypeSort => {
                                let resolved = self.resolve_ty(arg, span~, type_params~)
                                resolved_params[param.name] = @parse.TypeParam(ty=resolved, span~)
                            }
                            NatSort => {
                                raise type_error(
                                    "Module type '\{path}' parameter '\{param.name}' expects a Nat argument, which cannot be written in a type annotation",
                                    span,
                                )
                            }
                        }
                    }

                    Instance(sig~, params=resolved_params, ids=[])
                }
                None => raise UnknownModule(path~, span~)
            }
        }
        Struct(fields) => {
            let field_tys = Map([], capacity=fields.length())

            for name, ty in fields {
                field_tys[name] = self.resolve_ty(ty, span~, type_params~)
            }

            Struct(field_tys)
        }
        String(len~) => Vector(ty=Type::uint(@parse.BITS_PER_CHAR), len=Lit(len))
        MemoryMask(ty) => {
            let inner = self.resolve_ty(ty, span~, type_params~)
            try inner.mask(span~) catch {
                NonStorableType(
                    ty=Name(path={ packages: [], elem }, ..),
                    ..
                ) if type_params.contains(elem) => MemoryMask(inner)
                err => raise err
            }
        }
        Unit => Unit
    }
}

fn TypeChecker::synth_expr(
    self: Self,
    expr: Expr,
    env: Scope[Path, Ref[Type?]],
    record_port_reads~: Bool = true,
) -> Type raise {
    self.check_expr_in_context(expr, env, record_port_reads~)
}

fn TypeChecker::check_expr(
    self: Self,
    expr: Expr,
    env: Scope[Path, Ref[Type?]],
    expected_ty~: Type,
    record_port_reads~: Bool = true,
) -> Type raise {
    self.check_expr_in_context(expr, env, expected_ty=Some(expected_ty), record_port_reads~)
}

fn TypeChecker::check_expr_in_context(
    self: Self,
    expr: Expr,
    env: Scope[Path, Ref[Type?]],
    expected_ty~: Type? = None,
    record_port_reads~: Bool = true,
) -> Type raise {
    let ty = match expr {
        Identifier(path~, span~, ..) => {
            match env.resolve(path) {
                Some({ val: Some(ty) }) => ty
                Some(_) => raise type_error("Binding '\{path}' has no resolved type", span)
                None => {
                    raise type_error("Unbound variable '\{path}'", span)
                }
            }
        }
        Natural(value~, width~, span~, ..) => match width {
            Some(width) => {
                if value < 0 {
                    raise negative_unsigned_literal_error(width, span)
                }
                Type::uint(width)
            }
            None => match expected_ty {
                Some(UInt(Lit(width))) => {
                    if value < 0 {
                        raise negative_unsigned_literal_error(width, span)
                    }
                    let required = significant_bits(value, is_signed=false)
                    if required > width {
                        raise type_error("Literal requires \{required} bits but context provides u\{width}", span)
                    }
                    Type::uint(width)
                }
                Some(SInt(Lit(width))) => {
                    let required = significant_bits(value, is_signed=true)
                    if required > width {
                        raise type_error("Literal requires \{required} signed bits but context provides s\{width}", span)
                    }
                    Type::sint(width)
                }
                _ => if value < 0 {
                    Type::sint(significant_bits(value, is_signed=true))
                } else {
                    Type::uint(significant_bits(value, is_signed=false))
                }
            }
        }
        String(value=str,  span~, ..) => {
            for char in str {
                if !is_ascii(char) {
                    raise type_error("String contains non-ASCII character '\{char}'", span)
                }
            }

            Type::Vector(ty=Type::uint(@parse.BITS_PER_CHAR), len=Lit(str.length()))
        }
        Unary(op~, expr~, span~, ..) => {
            match (op, expr, expected_ty) {
                (Neg, (Natural(value~, width=None, ..) as operand), Some(SInt(Lit(width)))) => {
                    if width <= 0 || value > pow2(width - 1) {
                        raise type_error("Negative literal does not fit in contextual type s\{width}", span)
                    }
                    let _ = self.synth_expr(operand, env)
                    Type::sint(width)
                }
                _ => {
                    let ty = self.synth_expr(expr, env)
 
                    if !ty.is_numerical() {
                        raise type_error("Invalid operand type '\{ty}' for unary operator '\{op}, expected uint or sint", span)
                    }

                    match op {
                        Not => ty
                        Neg => SInt(Lit(ty.width(span) + 1))
                        Andr | Orr | Xorr => Type::uint(1)
                    }
                }
            }
        }
        Binary(op~, lhs~, rhs~, span~, ..) => {
            let lhs_ty = self.synth_expr(lhs, env)
            let rhs_ty = self.synth_expr(rhs, env)
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

            out_ty
        }
        Indexing(expr~, index~, span~, ..) => {
            let ty = self.synth_expr(expr, env, record_port_reads~)
            let index_ty = self.synth_expr(index, env)

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
            let ty = self.synth_expr(expr, env, record_port_reads~)
            let hi_val = self.check_static_nat(hi, env)
            let (msb, lsb) = match kind {
                Absolute => (hi_val, self.check_static_nat(lo, env))
                WidthDescending => {
                    // [base -: w] selects bits [base : base - w + 1]
                    let width = self.check_static_nat(lo, env)
                    (hi_val, hi_val + 1 - width)
                }
                WidthAscending => {
                    // [base +: w] selects bits [base + w - 1 : base]
                    let width = self.check_static_nat(lo, env)
                    (hi_val + width - 1, hi_val)
                }
            }

            let width = msb + 1 - lsb

            match ty {
                UInt(_) | SInt(_) => Type::uint(width)
                String(_) => Type::Vector(ty=Type::uint(@parse.BITS_PER_CHAR), len=Lit(width))
                Vector(ty=inner_ty, len~) => {
                    let len = len.expect_lit(expr.span())
                    if msb >= len {
                        raise InvalidSlicingRange(reason="start index out of bounds: lsb: \{msb}, len: \{len}", span~)
                    }

                    if lsb >= msb {
                        raise InvalidSlicingRange(reason="end index must be less than start index", span~)
                    }

                    Type::Vector(ty=inner_ty, len=Lit(width))
                }
                _ => raise IndexedExpressionMustBeVector(span~)
            }
        }
        FieldAccess(expr~, field=port, span~, ..) => {
            match self.synth_expr(expr, env, record_port_reads~) {
                Instance(sig~, params~, ids~) => {
                    match sig.get_port(port) {
                        Some(port_def) => {
                            if record_port_reads {
                                self.port_usage.record_read(ids, port)
                            }
                            port_def.ty.substitute(params, span~)
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
                    let subst: Map[String, UnificationParam] = Map([])
                    let params_env: Map[String, StaticArg] = Map([])
                    let instance_id = self.fresh_instance_id()
                    let params_map = params.as_resolved_map(names=sig.params.map(p => p.name))

                    // check monomorphized (erased) parameters
                    for param in params.instantiated {
                        let (expr, ann, span) = param
                        let expr_ty = self.synth_expr(expr, env)
                        let expr_ty = self.resolve_ty(expr_ty, span~)
                        let _ = unify(expr_ty, ann, span=span, subst~)
                    }

                    for name, param in params_map {
                        let param_sig = sig.get_param(name)

                        match (param, param_sig) {
                            (NatParam(value~, ..) as cnst_param, Some({ sort: NatSort, .. })) => {
                                subst[name] = Int(self.check_static_nat(value.as_expr(), env))

                                params_env[name] = cnst_param
                            }
                            (TypeParam(ty~, span~), Some({ sort: TypeSort, .. })) => {
                                let resolved_ty = self.resolve_ty(ty, span~)
                                subst[name] = Type(resolved_ty)
                                params_env[name] = TypeParam(ty=resolved_ty, span~)
                            }
                            _ => {
                                let ty = match param {
                                    NatParam(value~, ..) => self.synth_expr(value.as_expr(), env)
                                    TypeParam(ty~, span~) => self.resolve_ty(ty, span~)
                                }

                                let expected_ty = "[" + param_sig.iter().map(p => p.sort.to_string()).join(", ") + "]"
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
                                let port_ty = port_def.ty.substitute(params_env, span~)
                                if port_def.dir == Input {
                                    let _ = self.check_expr(port_expr, env, expected_ty=port_ty)
                                } else {
                                    let expr_ty = self.synth_expr(port_expr, env)
                                    let _ = unify(port_ty, expr_ty, span=port_expr.span())
                                    if !is_valid_assignment_target(port_expr) {
                                        raise InvalidAssignmentTarget(span=port_expr.span())
                                    }
                                }
                            }
                            None => raise UnknownModulePort(module_path=path, port_name=port_name, span~)
                        }
                    }

                    if (path.elem == "Reg" || path.elem == "RegAsyncReset") && path.packages.is_empty() {
                        self.port_usage.record_read([instance_id], "d")
                        self.port_usage.record_read([instance_id], "q")
                    }

                    Type::Instance(sig~, params=params_env, ids=[instance_id])
                }
                None => raise UnknownModule(path~, span~)
            }
        }
        Vector(elems~, span~, ..) => {
            if elems.is_empty() {
                match expected_ty {
                    Some(Vector(ty~, len=Lit(0))) => Vector(ty~, len=Lit(0))
                    Some(expected) => {
                        raise type_error("Empty vector literal is incompatible with contextual type '\{expected}'", span)
                    }
                    None => {
                        raise type_error("Empty vector literal requires a contextual [0]T type", span)
                    }
                }
            } else {
                let mut elem_ty = None
                let mut len = 0
                let expected_elem_ty = match expected_ty {
                    Some(Vector(ty~, ..)) => Some(ty)
                    _ => None
                }

            fn check_elem_ty(ty: Type) -> Unit raise TypeCheckerError {
                match elem_ty {
                    Some(ty2) => {
                        elem_ty = Some(merge_expression_types(ty2, ty, span~))
                    }
                    None => {
                        elem_ty = Some(ty)
                    }
                }
            }

            for elem in elems {
                match elem {
                    Spread(expr=spread_expr, ..) => {
                        let spread_ty = self.synth_expr(spread_expr, env)
                        elem.set_ty(spread_ty)
                        match spread_ty {
                            Vector(ty=spread_ty_inner, len=Lit(spread_len)) => {
                                check_elem_ty(spread_ty_inner)
                                len += spread_len
                            }
                            UInt(Lit(int_len)) | SInt(Lit(int_len)) => {
                                check_elem_ty(UInt(Lit(1)))
                                len += int_len
                            }
                            String(len=str_len) => {
                                check_elem_ty(UInt(Lit(@parse.BITS_PER_CHAR)))
                                len += str_len
                            }
                            _ => {
                                check_elem_ty(spread_ty)
                                len += 1
                            }
                        }
                    }
                    _ => {
                        check_elem_ty(self.check_expr_in_context(elem, env, expected_ty=expected_elem_ty))
                        len += 1
                    }
                }
            }

                let vector_ty = Type::Vector(ty=elem_ty.unwrap(), len=Lit(len))
                for elem in elems {
                    match elem.ty().val {
                        Some(ty) => self.recheck_inferred_expr(elem, ty, elem_ty.unwrap(), env)
                        _ => ()
                    }
                }
                vector_ty
            }
        }
        Spread(span~, ..) => {
            raise type_error("Spread outside vector", span)
        }
        Ternary(cond~, then~, else_~, span~, ..) => {
            let _ = self.check_expr(cond, env, expected_ty=Type::uint(1))
            let then_ty = self.check_expr_in_context(then, env, expected_ty~)
            let else_ty = self.check_expr_in_context(else_, env, expected_ty~)

            let ty = merge_expression_types(self.resolve_ty(then_ty, span~), else_ty, span~)
            self.recheck_inferred_expr(then, then_ty, ty, env)
            self.recheck_inferred_expr(else_, else_ty, ty, env)
            ty
        }
        Match(subject~, cases~, default~, span~, ..) => {
            let subject_ty = self.synth_expr(subject, env)
            let pattern_ty = subject_ty
            
            if cases.is_empty() && default is None {
                raise type_error("Empty match expression", span)
            }

            let mut ret_ty = None
            let subst = Map([])

            fn check_ret_ty(ty: Type) -> Unit raise TypeCheckerError {
                match ret_ty {
                    Some(ty2) => {
                        ret_ty = Some(merge_expression_types(ty2, ty, span~))
                    }
                    None => {
                        ret_ty = Some(ty)
                    }
                }
            }

            for case in cases {
                let (pat, expr) = case
                let pat_ty = self.check_expr(pat, env, expected_ty=pattern_ty)
                let expr_ty = self.check_expr_in_context(expr, env, expected_ty~)
                let _ = unify(subject_ty, pat_ty, subst~, span~)
                check_ret_ty(expr_ty)
            }

            match default {
                Some(expr) => {
                    let expr_ty = self.check_expr_in_context(expr, env, expected_ty~)
                    check_ret_ty(expr_ty)
                }
                None => ()
            }

            let ty = ret_ty.unwrap()
            for case in cases {
                let (_, expr) = case
                match expr.ty().val {
                    Some(expr_ty) => self.recheck_inferred_expr(expr, expr_ty, ty, env)
                    _ => ()
                }
            }
            match default {
                Some(expr) => match expr.ty().val {
                    Some(expr_ty) => self.recheck_inferred_expr(expr, expr_ty, ty, env)
                    _ => ()
                }
                None => ()
            }
            ty
        }
        FunCall(name="uint", args=[arg], ..) => {
            let arg_ty = self.synth_expr(arg, env)
            let width = arg_ty.width(arg.span())
            Type::uint(width)
        }
        FunCall(name="sint", args=[arg], ..) => {
            let arg_ty = self.synth_expr(arg, env)
            let width = arg_ty.width(arg.span())
            Type::sint(width)
        }
        FunCall(name="clock", args=[arg], ..) => {
            let _ = self.check_expr(arg, env, expected_ty=Type::uint(1))
            Type::Clock
        }
        FunCall(name="pad", args=[arg, width], span~, ..) => {
            let arg_ty = self.synth_expr(arg, env)
            let width = self.check_static_nat(width, env)
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
            let _ = self.synth_expr(path, env)
            let mem_ty = self.synth_expr(mem, env)

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
            let _ = self.check_expr(pred, env, expected_ty=Type::bool())

            if rest is [format_str, ..args] {
                self.check_format_string(format_str~, args~, env~, span~)
            }

            Type::empty()
        }
        FunCall(name="stop", args~, span~, ..) => {
            match args {
                [] => ()
                [exit_code] => {
                    let exit_code_ty = self.synth_expr(exit_code, env)

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
            let arg_ty = self.synth_expr(arg, env)

            match arg_ty {
                Vector(_) => arg_ty
                _ => {
                    raise type_error("Invalid operand '\{arg_ty}' for $rev operator, expected a vector", span)
                }
            }
        }
        FunCall(name="cat", args~, span~, ..) => {
            if args.is_empty() {
                raise type_error("cat! requires at least one argument", span)
            }

            let mut len = 0
            let mut is_signed: Bool? = None
            let stack = @stack.new()

            for elem in args {
                let ty = self.synth_expr(elem, env)
                let elem_span = elem.span()
                len += ty.width(elem_span)
                stack.push((ty, elem_span))
            }

            while !stack.is_empty() {
                let (ty, elem_span) = stack.unsafe_pop()

                match ty {
                    UInt(_) | SInt(_) => {
                        let is_elem_signed = ty is SInt(_)

                        match is_signed {
                            Some(is_signed) => {
                                if is_signed != is_elem_signed {
                                    raise type_error("Cannot mix unsigned and signed integers in cat!", elem_span)
                                }
                            }
                            None => {
                                is_signed = Some(is_elem_signed)
                            }
                        }
                    }
                    Vector(ty=elem_ty, len=_) => {
                        stack.push((elem_ty, elem_span))
                    }
                    _ => raise type_error("Invalid element of type '\{ty}' in cat!", elem_span)
                }
            }

            if is_signed is Some(true) {
                Type::sint(len)
            } else {
                Type::uint(len)
            }
        }
        FunCall(name="fill", args=[count, elem], ..) => {
            let count_val = self.check_static_nat(count, env)
            let elem_ty = self.synth_expr(elem, env)

            Vector(ty=elem_ty, len=Lit(count_val))
        }
        FunCall(name="flip", args=[arg], span~, ..) => {
            let arg_ty = self.synth_expr(arg, env)

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
        Struct(fields~, span~, ty=_) => {
            let field_tys = Map([], capacity=fields.length())
            let expected_fields = match expected_ty {
                Some(Type::Struct(fields)) => Some(fields)
                _ => None
            }
            // First pass: expand spreads (fields with key prefixed by "..").
            // A spread's expression must have a Struct type; its fields are added
            // first, so later explicit fields can override.
            for name, ty in fields {
                if name.has_prefix("..") {
                    let inner = match ty {
                        Spread(expr~, ..) => expr
                        _ => raise type_error("Internal: spread field is not a Spread expression", span)
                    }
                    let inner_ty = self.synth_expr(inner, env)
                    match inner_ty {
                        Type::Struct(spread_fields) => {
                            for spread_name, spread_ty in spread_fields {
                                field_tys[spread_name] = spread_ty
                            }
                        }
                        _ => raise type_error("Spread inside a record must have a record type, got '\{inner_ty}'", inner.span())
                    }
                }
            }

            for name, ty in fields {
                if !name.has_prefix("..") {
                    let field_expected = expected_fields.bind(fields => fields.get(name))
                    field_tys[name] = self.check_expr_in_context(ty, env, expected_ty=field_expected)
                }
            }

            let struct_ty = Type::Struct(field_tys)
            struct_ty
        }
        Block(body~, last~, span=_, ty=_) => {
            let new_env = env.child()

            for stmt in body {
                self.check_stmt(stmt, new_env)
            }

            match last {
                Some(last) => {
                    self.check_expr_in_context(last, new_env, expected_ty~)
                }
                _ => Type::empty()
            }
        }
        If(cond~, then~, else_~, span~, ..) => {
            let _ = self.check_expr(cond, env, expected_ty=Type::uint(1))
            let then_ty = self.check_expr_in_context(then, env, expected_ty~)
            let if_ty = match else_ {
                Some(else_) => {
                    let else_ty = self.check_expr_in_context(else_, env, expected_ty~)
                    let ty = merge_expression_types(then_ty, else_ty, span~)
                    self.recheck_inferred_expr(then, then_ty, ty, env)
                    self.recheck_inferred_expr(else_, else_ty, ty, env)
                    ty
                }
                None => {
                    let _ = unify(then_ty, Type::empty(), span~)
                    then_ty
                }
            }

            if_ty
        }
    }

    match expected_ty {
        Some(expected) => check_assignment_compatibility(expected, ty, span=expr.span())
        None => ()
    }

    expr.set_ty(ty)

    ty
}

fn TypeChecker::check_stmt(self: Self, stmt: Stmt, env: Scope[Path, Ref[Type?]]) -> Unit raise {
    match stmt {
        Expr(expr~, ..) => {
            let _ = self.synth_expr(expr, env)
        }
        Let(name~, ty~, expr~, span~) => {
            let path = Path::new([], name)
            let binding = ty

            binding.val = Some(match (binding.val, expr) {
                (Some(ty), Some(expr)) => {
                    let ty = self.resolve_ty(ty, span~)
                    declare_name(env~, path~, ty~, span~, binding=Some(binding))
                    let expr_ty = self.check_expr(expr, env, expected_ty=ty)
                    let ty = merge_inferred_types(ty, expr_ty)
                    ty
                }
                (Some(ty), None) => {
                    let ty = self.resolve_ty(ty, span~)
                    declare_name(env~, path~, ty~, span~, binding=Some(binding))
                    ty
                }
                (None, Some(expr)) => {
                    let ty = self.synth_expr(expr, env)
                    declare_name(env~, path~, ty~, span~, binding=Some(binding))

                    ty
                }
                (None, None) => {
                    raise type_error("Let statement must have a type or value", span)
                }
            })
        }
        Assign(lhs~, rhs~, span~) => {
            let lhs_ty = self.synth_expr(lhs, env, record_port_reads=false)
            let valid_lhs = is_valid_assignment_target(lhs)

            if !valid_lhs {
                raise InvalidAssignmentTarget(span~)
            }

            // Mark the root instance port as written even when the assignment targets
            // a nested aggregate field or element of that port.
            if assigned_instance_port(lhs) is Some((sig, ids, field)) {
                if sig.get_port(field) is Some({ dir: Output, .. }) {
                    raise type_error("Cannot assign to output port '\{field}' of module '\{sig.path}'", span)
                }

                self.port_usage.record_write(ids, field)
            }

            let rhs_ty = self.check_expr(rhs, env, expected_ty=lhs_ty)
            merge_assignment_target(lhs, rhs_ty, env)
        }
        Scope(body~, ..) => {
            let new_env = env.child()

            for stmt in body {
                self.check_stmt(stmt, new_env)
            }
        }
        For(variable~, range~, body~, ..) => {
            let start_val = self.check_static_nat(range.start, env)
            let end_val = self.check_static_nat(range.end, env)
            let last_value = if range.inclusive { end_val } else { max(end_val - 1, 0) }
            let max_value = max(start_val, last_value)
            let end_ty = Type::uint(significant_bits(BigInt::from_int(max_value), is_signed=false))

            let body_env = env.child()
            body_env.declare_(Path::new([], variable), { val: Some(end_ty) })

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
    env~: Scope[Path, Ref[Type?]],
    span~: Span,
) -> Unit raise {
    let format_str_ty = self.synth_expr(format_str, env)

    if !format_str_ty.is_string() {
        raise type_error("Invalid format string", span)
    }

    for index, arg in args {
        let arg_ty = self.synth_expr(arg, env)

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

let port_attribute_signatures: Map[String, Array[AttributeValueType]] = Map([])

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

fn TypeChecker::check_const_decl(self: Self, decl: ConstDecl, env: Scope[Path, Ref[Type?]]) -> Unit raise {
    if !decl.expr.is_constant_expr() {
        raise ExpectedConstantExpr(span=decl.expr.span())
    }

    let ty = match decl.ty {
        Some(expected_ty) => {
            let expected_ty = self.resolve_ty(expected_ty, span=decl.expr.span())
            let _ = self.check_expr(decl.expr, env, expected_ty=expected_ty)
            expected_ty
        }
        None => self.synth_expr(decl.expr, env)
    }

    declare_name(env~, path=decl.path, ty~, span=decl.span)
}

fn TypeChecker::resolve_port(self: Self, port: @parse.Port, type_params~: Set[String]) -> @parse.Port raise {
    {
        name: port.name,
        ty: self.resolve_ty(port.ty, span=port.span, type_params~),
        dir: port.dir,
        span: port.span,
        optional: port.optional,
        attributes: port.attributes,
    }
}

pub fn TypeChecker::check_decl(self: Self, decl: Decl) -> Decl raise {
    match decl {
        Module({ path, params, attributes, ports, body, span }) => {
            let type_params = Set::from_iter(params.iter().filter_map(param => if param.sort == TypeSort { Some(param.name) } else { None }))
            let ports = ports.map(port => self.resolve_port(port, type_params~))
            let mod: @parse.ModuleDecl = { path, params, attributes, ports, body, span }
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
            Module(mod)
        }
        ModuleDeclaration(sig) => {
            let type_params = Set::from_iter(sig.params.iter().filter_map(param => if param.sort == TypeSort { Some(param.name) } else { None }))
            let sig: ModuleSignature = {
                path: sig.path,
                params: sig.params,
                attributes: sig.attributes,
                ports: sig.ports.map(port => self.resolve_port(port, type_params~)),
                span: sig.span,
            }
            check_attributes(sig.attributes, signatures=module_attribute_signatures)
            
            for port in sig.ports {
                check_attributes(port.attributes, signatures=port_attribute_signatures)
            }

            self.modules[sig.path] = sig
            ModuleDeclaration(sig)
        }
        Const(decl) => {
            self.check_const_decl(decl, self.top_env)
            Const(decl)
        }
        Package(pkg) => Package(pkg)
        Import(import_decl) => Import(import_decl)
        TypeAlias(alias) => TypeAlias(alias)
    }
}

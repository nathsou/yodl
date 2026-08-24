pub(all) struct UnresolvedParam {
  tokens: Array[Token]
  file: String
  text: StringView
  span: Span
}

pub(all) enum ParsedParam {
  ExprParam(expr~: Expr, span~: Span)
  TypeParam(ty~: Type, span~: Span)
}

pub fn UnresolvedParam::parse(self: UnresolvedParam, sort: ParamSort) -> ParsedParam raise {
  let parser = Parser::new(self.tokens, file=self.file, file_content=self.text)
  let param = match sort {
    NatSort => ParsedParam::ExprParam(expr=parser.parse_expr(), span=self.span)
    TypeSort => ParsedParam::TypeParam(ty=parser.parse_type(), span=self.span)
  }
  while parser.consumes(Semicolon) {}
  parser.expect_end()
  param
}

/// A resolved static argument whose constructor records its `Nat`/`Type` sort.
pub(all) enum StaticArg {
  NatParam(value~: ConstValue, span~: Span)
  TypeParam(ty~: Type, span~: Span)
}

pub(all) enum ConstValue {
  Natural(value~: BigInt, width~: Int?, base~: Int, span~: Span)
  String(value~: String, span~: Span)
} derive(Eq)

pub fn ConstValue::from(expr: Expr) -> ConstValue? {
  match expr {
    Natural(value~, width~, base~, span~, ty=_) => Some(Natural(value~, width~, base~, span~))
    String(value~, span~, ty=_) => Some(String(value~, span~))
    _ => None
  }
}

pub(all) enum Param {
  Unresolved(UnresolvedParam)
  Resolved(StaticArg)
} derive(Eq)

pub impl Eq for StaticArg with equal(self, other) {
  match (self, other) {
    (NatParam(value=a, ..), NatParam(value=b, ..)) => a == b
    (TypeParam(ty=a, ..), TypeParam(ty=b, ..)) => a == b
    _ => false
  }
}

pub impl Eq for UnresolvedParam with equal(self, other) {
  self.span == other.span
}

pub impl Hash for StaticArg with hash_combine(self, hasher) {
  match self {
    NatParam(value~, ..) => {
      match value {
        Natural(value~, width~, base=_, span=_) => {
          for byte in value.to_octets() {
            hasher.combine(byte)
          }

          hasher.combine(width)
        }
        String(value~, span=_) => hasher.combine(value)
      }
    }
    TypeParam(ty~, ..) => hasher.combine(Show::to_string(ty))
  }
}

pub impl Spanned for Param with span(self) -> Span {
  match self {
    Unresolved(param) => param.span
    Resolved(param) => Spanned::span(param)
  }
}

pub impl Spanned for StaticArg with span(self) -> Span {
  match self {
    NatParam(span~, ..) => span
    TypeParam(span~, ..) => span
  }
}

pub fn Param::as_type(self: Param) -> Type raise {
  match self {
    Resolved(TypeParam(ty~, ..)) => ty
    _ => raise ExpectedTypeParameter(span=Spanned::span(self))
  }
}

pub fn Param::as_int(self: Param) -> Int raise {
  match self {
    Resolved(NatParam(value=Natural(value~, ..), span=_)) => value.to_int()
    _ => raise ExpectedIntParameter(span=Spanned::span(self))
  }
}

pub fn StaticArg::as_type(self: StaticArg) -> Type raise {
  match self {
    TypeParam(ty~, ..) => ty
    NatParam(span~, ..) => raise ExpectedTypeParameter(span~)
  }
}

pub fn StaticArg::as_int(self: StaticArg) -> Int raise {
  match self {
    NatParam(value=Natural(value~, ..), span=_) => value.to_int()
    NatParam(span~, ..) | TypeParam(span~, ..) => raise ExpectedIntParameter(span~)
  }
}

pub fn ConstValue::as_expr(self: ConstValue) -> Expr {
  match self {
    Natural(value~, width~, base~, span~) => Natural(value~, width~, base~, span~, ty={ val: None })
    String(value~, span~) => String(value~, span~, ty={ val: None })
  }
}

pub fn StaticArg::as_expr(self: StaticArg) -> Expr raise {
  match self {
    NatParam(value~, span=_) => value.as_expr()
    TypeParam(span~, ..) => raise TypeParamInsteadOfExpr(span~)
  }
}

// perform partial evaluation on the expression
pub fn Expr::partial_eval(self: Expr, params~: Map[String, StaticArg] = {}) -> Expr raise {
  fn rewr_expr(expr: Expr) -> Expr? raise {
    match expr {
      Identifier(path={ packages: [], elem }, ..) => {
        match params.get(elem) {
          Some(NatParam(value~, span=_)) => {
            Some(value.as_expr())
          }
          Some(TypeParam(_)) => {
            raise TypeParamInsteadOfExpr(span=Spanned::span(expr))
          }
          None => None
        }
      }
      Unary(op=Neg, ..) => None
      Unary(op~, expr~, span~, ty~) => {
        try expr.as_bigint() catch {
          _ => None
        } noraise {
          value => {
            let value = match op {
              Not => {
                if expr.ty().val is Some(ty) && ty.width(span) is width {
                  @utils.bitwise_not(value, width~)
                } else {
                  return None
                }
              }
              Andr => BigInt::from_int(@utils.bits(value).iter().all(@utils.identity).to_int())
              Orr => BigInt::from_int(@utils.bits(value).iter().any(@utils.identity).to_int())
              Xorr => BigInt::from_int(@utils.bits(value).fold(init=0, (acc, b) => acc ^ b.to_int()))
              Neg => @utils.unreachable_code()
            }

            Some(Natural(value=value, width=None, base=10, span~, ty~))
          }
        }
      }
      Binary(op~, lhs~, rhs~, output_width=_, span~, ty~) => {
        let lhs_value = try lhs.as_bigint() catch {
          _ => None
        } noraise {
          value => Some(value)
        }
        let rhs_value = try rhs.as_bigint() catch {
          _ => None
        } noraise {
          value => Some(value)
        }
        let is_single_bit = lhs is Natural(width=Some(1), ..) || rhs is Natural(width=Some(1), ..)
        
        match (lhs_value, rhs_value, lhs, rhs, op) {
          (Some(lhs), Some(rhs), _, _, _) => {
            let value = match op {
              Add => lhs + rhs
              Sub => lhs - rhs
              Mul => lhs * rhs
              Div => lhs / rhs
              Mod => lhs % rhs
              Shl => lhs << rhs.to_int()
              Shr => lhs >> rhs.to_int()
              Equ => if lhs == rhs { 1 } else { 0 }
              Neq => if lhs != rhs { 1 } else { 0 }
              Lss => if lhs < rhs { 1 } else { 0 }
              Gtr => if lhs > rhs { 1 } else { 0 }
              Leq => if lhs <= rhs { 1 } else { 0 }
              Geq => if lhs >= rhs { 1 } else { 0 }
              And => lhs & rhs
              Or => lhs | rhs
              Xor => lhs ^ rhs
              Nand | Nor | Xnor => return None
              _ => raise Failure::Failure("Invalid arithmetical binary operator")
            }

            Some(Natural(value~, width=None, base=10, span~, ty~))
          }
          ((Some(0), _, _, b, op) | (_, Some(0), b, _, op)) if is_single_bit => {
            match op {
              And => Some(Expr::nat(0, span~))
              Or | Xor => Some(b)
              Nand => Some(Expr::nat(1, span~))
              Xnor | Nor => Some(Expr::Unary(op=Not, expr=b, span~, ty~))
              _ => None
            }
          }
          ((Some(1), _, _, b, op) | (_, Some(1), b, _, op)) if is_single_bit => {
            match op {
              And | Xnor => Some(b)
              Or => Some(Expr::nat(1, span~))
              Xor | Nand => Some(Expr::Unary(op=Not, expr=b, span~, ty~))
              Nor => Some(Expr::nat(0, span~))
              _ => None
            }
          }
          _ => None
        }
      }
      Ternary(cond~, then~, else_~, ..) | If(cond~, then~, else_=Some(else_), ..) => {
        try cond.partial_eval().as_int() catch {
          _ => None
        } noraise {
          cond => Some(if cond != 0 { then } else { else_ })
        }
      }
      If(cond~, then~, else_=None, span~, ty~) => {
        try cond.partial_eval().as_int() catch {
          _ => None
        } noraise {
          cond => Some(if cond != 0 { then } else { Expr::Block(body=[], last=None, span~, ty~) })
        }
      }
      Match(subject~, cases~, ..) => {
        try subject.partial_eval().as_int() catch {
          _ => None
        } noraise {
          subject => {
            for case in cases {
              let (value, rhs) = case
              try value.partial_eval().as_int() catch {
                _ => ()
              } noraise {
                case => if subject == case { return Some(rhs) }
              }
            }

            None
          }
        }
      }
      FunCall(name~, args~, span~, ty=_) => {
        let fun = match builtin_functions.get(name) {
          Some(fun) => fun
          None => raise UnknownFunction(name~, span~)
        }

        let (min_arity, max_arity) = fun.arity.as_range()

        if args.length() < min_arity || args.length() > max_arity {
          raise InvalidFunCallArity(name~, expected=fun.arity, actual=args.length(), span~)
        }

        (fun.apply)(args, span)
      }
      _ => None
    }
  }

  rewrite_expr(self, { rewr_expr, rewr_stmt: stmt => Iter::singleton(stmt) })
}

fn as_bigint_or_none(expr: Expr) -> BigInt? {
  try expr.as_bigint() catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

enum Arity {
  Fixed(Int)
  Range(min~: Int, max~: Int)
}

fn Arity::as_range(self: Self) -> (Int, Int) {
  match self {
    Fixed(value) => (value, value)
    Range(min~, max~) => (min, max)
  }
}

impl Show for Arity with output(self, logger) {
  match self {
    Fixed(value) => logger.write_string(value.to_string())
    Range(min~, max~) => logger.write_string("\{min}..\{max}")
  }
}

priv struct BuiltinFunction {
  arity: Arity
  apply: (Array[Expr], Span) -> Expr? raise
}

let builtin_functions: Map[String, BuiltinFunction] = {
  "clog2": {
    arity: Fixed(1),
    apply: (args, span) => {
      match as_bigint_or_none(args[0]) {
        Some(arg) => Some(Expr::bignat(@utils.clog2(arg), width=None, span~))
        None => None
      }
    }
  },
  "pow": {
    arity: Fixed(2),
    apply: (args, span) => {
      match (as_bigint_or_none(args[0]), as_bigint_or_none(args[1])) {
        (Some(base), Some(exp)) => Some(Expr::bignat(@utils.pow(base, exp), span~))
        _ => None
      }
    }
  },
  "cdiv": {
    arity: Fixed(2),
    apply: (args, span) => {
      match (as_bigint_or_none(args[0]), as_bigint_or_none(args[1])) {
        (Some(dividend), Some(divisor)) => Some(Expr::bignat(@utils.cdiv(dividend, divisor), span~))
        _ => None
      }
    }
  },
  "csqrt": {
    arity: Fixed(1),
    apply: (args, span) => {
      match as_bigint_or_none(args[0]) {
        Some(arg) => Some(Expr::bignat(@utils.csqrt(arg), span~))
        None => None
      }
    }
  },
  "rev": {
    arity: Fixed(1),
    apply: (_, _) => None
  },
  "flip": {
    arity: Fixed(1),
    apply: (_, _) => None
  },
  "pad": {
    arity: Fixed(2),
    apply: (_, _) => None
  },
  "readmemb": {
    arity: Fixed(2),
    apply: (args, _) => {
      match args {
        [path, _mem] => { let _ = path.as_string() }
        _ => ()
      }

      None
    }
  },
  "readmemh": {
    arity: Fixed(2),
    apply: (args, _) => {
      match args {
        [path, _mem] => { let _ = path.as_string() }
        _ => ()
      }

      None
    }
  },
  "printf": {
    arity: Range(min=1, max=@int.MAX_VALUE),
    apply: (_, _) => None
  },
  "assert": {
    arity: Range(min=1, max=@int.MAX_VALUE),
    apply: (_, _) => None
  },
  "stop": {
    arity: Range(min=0, max=1),
    apply: (_, _) => None
  },
  "uint": {
    arity: Fixed(1),
    apply: (_, _) => None
  },
  "sint": {
    arity: Fixed(1),
    apply: (_, _) => None
  },
  "clock": {
    arity: Fixed(1),
    apply: (_, _) => None
  },
  "cat": {
    arity: Range(min=1, max=@int.MAX_VALUE),
    apply: (_, _) => None
  },
  "fill": {
    arity: Fixed(2),
    apply: (_, _) => None
  },
}

pub fn Expr::as_int(self: Expr) -> Int raise {
  match self {
    Natural(value~, ..) => value.to_int()
    _ => {
      raise ExpectedIntegerExpression(expr=self, span=Spanned::span(self))
    }
  }
}

pub fn Expr::as_bigint(self: Expr) -> BigInt raise {
  match self {
    Natural(value~, ..) => value
    _ => raise ExpectedIntegerExpression(expr=self, span=Spanned::span(self))
  }
}

pub fn Expr::as_string(self: Expr) -> String raise {
  match self {
    String(value=str, ..) => str
    _ => raise ExpectedStringExpression(expr=self, span=Spanned::span(self))
  }
}

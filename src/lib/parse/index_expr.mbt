pub(all) enum IndexExpr {
  Lit(Int)
  Var(String)
  Add(IndexExpr, IndexExpr)
  Sub(IndexExpr, IndexExpr)
  Mul(IndexExpr, IndexExpr)
  Clog2(IndexExpr, Span)
  CDiv(IndexExpr, IndexExpr, Span)
} derive(Eq)

// Size functions are defined over natural values. `clog2!(0)` is zero;
// ceiling division requires a nonnegative dividend and a positive divisor.
// Evaluate a closed, domain-valid IndexExpr to an Int. Returns None for unresolved
// variables or invalid `clog2`/ceiling-division domains.
pub fn IndexExpr::eval(self: IndexExpr) -> Int? {
  match self {
    Lit(n) => Some(n)
    Var(_) => None
    Add(a, b) | Sub(a, b) | Mul(a, b) | CDiv(a, b, _) => match (a.eval(), b.eval()) {
      (Some(x), Some(y)) => match self {
        Add(_, _) => Some(x + y)
        Sub(_, _) => Some(x - y)
        Mul(_, _) => Some(x * y)
        CDiv(_, _, _) if x >= 0 && y > 0 => Some(x / y + (if x % y == 0 { 0 } else { 1 }))
        _ => None
      }
      _ => None
    }
    Clog2(a, _) => match a.eval() {
      Some(n) if n >= 0 => Some(@utils.clog2_int(n))
      Some(_) => None
      None => None
    }
  }
}

// Core traversal: recurse over all nodes, calling `f` only for Var.
// Constant-folds binary/unary ops when both operands reduce to Lit after recursion.
pub fn[E : Error] IndexExpr::map_vars(self : IndexExpr, f : (String) -> IndexExpr raise E) -> IndexExpr raise E {
  match self {
    Lit(_) => self
    Var(name) => f(name)
    Add(a, b) => match (a.map_vars(f), b.map_vars(f)) {
      (Lit(x), Lit(y)) => Lit(x + y)
      (a2, b2) => Add(a2, b2)
    }
    Sub(a, b) => match (a.map_vars(f), b.map_vars(f)) {
      (Lit(x), Lit(y)) => Lit(x - y)
      (a2, b2) => Sub(a2, b2)
    }
    Mul(a, b) => match (a.map_vars(f), b.map_vars(f)) {
      (Lit(x), Lit(y)) => Lit(x * y)
      (a2, b2) => Mul(a2, b2)
    }
    Clog2(a, span) => match a.map_vars(f) {
      Lit(n) if n >= 0 => Lit(@utils.clog2_int(n))
      a2 => Clog2(a2, span)
    }
    CDiv(a, b, span) => match (a.map_vars(f), b.map_vars(f)) {
      (Lit(x), Lit(y)) if x >= 0 && y > 0 => Lit(x / y + (if x % y == 0 { 0 } else { 1 }))
      (a2, b2) => CDiv(a2, b2, span)
    }
  }
}

// Substitute Var(name) with Lit(n) from params_env, then constant-fold.
pub fn IndexExpr::substitute(self: IndexExpr, params_env: Map[String, StaticArg]) -> IndexExpr {
  match self {
    Lit(_) => self
    Var(name) => match params_env.get(name) {
      Some(NatParam(value=Natural(value~, ..), ..)) => Lit(value.to_int())
      _ => self
    }
    Add(a, b) => match (a.substitute(params_env), b.substitute(params_env)) {
      (Lit(x), Lit(y)) => Lit(x + y)
      (a2, b2) => Add(a2, b2)
    }
    Sub(a, b) => match (a.substitute(params_env), b.substitute(params_env)) {
      (Lit(x), Lit(y)) => Lit(x - y)
      (a2, b2) => Sub(a2, b2)
    }
    Mul(a, b) => match (a.substitute(params_env), b.substitute(params_env)) {
      (Lit(x), Lit(y)) => Lit(x * y)
      (a2, b2) => Mul(a2, b2)
    }
    Clog2(a, span) => match a.substitute(params_env) {
      Lit(n) if n >= 0 => Lit(@utils.clog2_int(n))
      a2 => Clog2(a2, span)
    }
    CDiv(a, b, span) => match (a.substitute(params_env), b.substitute(params_env)) {
      (Lit(x), Lit(y)) if x >= 0 && y > 0 => Lit(x / y + (if x % y == 0 { 0 } else { 1 }))
      (a2, b2) => CDiv(a2, b2, span)
    }
  }
}

pub fn IndexExpr::expect_lit(self: Self, span: Span) -> Int raise AstError {
  match self {
    Lit(value) => value
    _ => raise IndexExprNotLiteral(span~)
  }
}

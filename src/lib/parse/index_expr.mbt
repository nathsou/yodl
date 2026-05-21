pub(all) enum IndexExpr {
  Lit(Int)
  Var(String)
  Add(IndexExpr, IndexExpr)
  Sub(IndexExpr, IndexExpr)
  Mul(IndexExpr, IndexExpr)
  Clog2(IndexExpr)
  CDiv(IndexExpr, IndexExpr)
} derive(Eq)

// Evaluate a closed IndexExpr to an Int, or return None if it contains unresolved variables.
pub fn IndexExpr::eval(self: IndexExpr) -> Int? {
  match self {
    Lit(n) => Some(n)
    Var(_) => None
    Add(a, b) => match (a.eval(), b.eval()) {
      (Some(x), Some(y)) => Some(x + y)
      _ => None
    }
    Sub(a, b) => match (a.eval(), b.eval()) {
      (Some(x), Some(y)) => Some(x - y)
      _ => None
    }
    Mul(a, b) => match (a.eval(), b.eval()) {
      (Some(x), Some(y)) => Some(x * y)
      _ => None
    }
    Clog2(a) => match a.eval() {
      Some(n) => Some(@utils.clog2_int(n))
      None => None
    }
    CDiv(a, b) => match (a.eval(), b.eval()) {
      (Some(x), Some(y)) if y != 0 => Some((x + y - 1) / y)
      _ => None
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
    Clog2(a) => match a.map_vars(f) {
      Lit(n) => Lit(@utils.clog2_int(n))
      a2 => Clog2(a2)
    }
    CDiv(a, b) => match (a.map_vars(f), b.map_vars(f)) {
      (Lit(x), Lit(y)) if y != 0 => Lit((x + y - 1) / y)
      (a2, b2) => CDiv(a2, b2)
    }
  }
}

// Substitute Var(name) with Lit(n) from params_env, then constant-fold.
pub fn IndexExpr::substitute(self: IndexExpr, params_env: Map[String, ResolvedParam]) -> IndexExpr {
  match self {
    Lit(_) => self
    Var(name) => match params_env.get(name) {
      Some(ConstParam(value=Natural(value~, ..), ..)) => Lit(value.to_int())
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
    Clog2(a) => match a.substitute(params_env) {
      Lit(n) => Lit(@utils.clog2_int(n))
      a2 => Clog2(a2)
    }
    CDiv(a, b) => match (a.substitute(params_env), b.substitute(params_env)) {
      (Lit(x), Lit(y)) if y != 0 => Lit((x + y - 1) / y)
      (a2, b2) => CDiv(a2, b2)
    }
  }
}

pub fn IndexExpr::expect_lit(self: Self, span: Span) -> Int raise AstError {
  match self {
    Lit(value) => value
    _ => raise IndexExprNotLiteral(span~)
  }
}


pub fn rewrite_expr(expr: Expr, rewrite: (Expr) -> Expr!Error) -> Expr!Error {
  let res = match expr {
    Natural(_) => expr
    Identifier(_) => expr
    Unary(op~, expr~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewrite)
      Unary(op~, expr~, span~, ty~)
    }
    Binary(op~, lhs~, rhs~, span~, ty~) => {
      let lhs = rewrite_expr!(lhs, rewrite)
      let rhs = rewrite_expr!(rhs, rewrite)
      Binary(op~, lhs~, rhs~, span~, ty~)
    }
    Indexing(expr~, index~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewrite)
      let index = rewrite_expr!(index, rewrite)
      Indexing(expr~, index~, span~, ty~)
    }
    Slicing(expr~, msb~, lsb~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewrite)
      let msb = rewrite_expr!(msb, rewrite)
      let lsb = rewrite_expr!(lsb, rewrite)
      Slicing(expr~, msb~, lsb~, span~, ty~)
    }
    PortAccess(expr~, port~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewrite)
      PortAccess(expr~, port~, span~, ty~)
    }
    Instance(name~, params~, ports~, span~, ty~) => {
      let new_params = []

      for param in params {
        new_params.push(rewrite_expr!(param, rewrite))
      }

      let new_ports = {}

      for port, expr in ports {
        new_ports[port] = rewrite_expr!(expr, rewrite)
      }

      Instance(name~, params=new_params, ports=new_ports, span~, ty~)
    }
    Vector(elems~, span~, ty~) => {
      let new_elems = []

      for elem in elems {
        new_elems.push(rewrite_expr!(elem, rewrite))
      }

      Vector(elems=new_elems, span~, ty~)
    }
    Spread(expr~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewrite)
      Spread(expr~, span~, ty~)
    }
    Ternary(cond~, then~, else_~, span~, ty~) => {
      let cond = rewrite_expr!(cond, rewrite)
      let then = rewrite_expr!(then, rewrite)
      let else_ = rewrite_expr!(else_, rewrite)
      Ternary(cond~, then~, else_~, span~, ty~)
    }
  }

  (rewrite)!(res)
}

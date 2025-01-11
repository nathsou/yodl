
pub fn clone_ty(ty: Ref[Type?]) -> Ref[Type?] {
  let new_ty = match ty.val {
    Some(ty) => Some(ty.clone())
    None => None
  }

  { val: new_ty }
}

pub fn rewrite_expr(expr: Expr, rewrite: (Expr) -> Expr!) -> Expr! {
  let res = match expr {
    Natural(bits~, width~, base~, span~, ty~) => Expr::Natural(bits~, width~, base~, span~, ty=clone_ty(ty))
    Identifier(path~, span~, ty~) => Identifier(path~, span~, ty=clone_ty(ty)) 
    Unary(op~, expr~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewrite)
      Unary(op~, expr~, span~, ty=clone_ty(ty))
    }
    Binary(op~, lhs~, rhs~, span~, ty~) => {
      let lhs = rewrite_expr!(lhs, rewrite)
      let rhs = rewrite_expr!(rhs, rewrite)
      Binary(op~, lhs~, rhs~, span~, ty=clone_ty(ty))
    }
    Indexing(expr~, index~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewrite)
      let index = rewrite_expr!(index, rewrite)
      Indexing(expr~, index~, span~, ty=clone_ty(ty))
    }
    Slicing(expr~, msb~, lsb~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewrite)
      let msb = rewrite_expr!(msb, rewrite)
      let lsb = rewrite_expr!(lsb, rewrite)
      Slicing(expr~, msb~, lsb~, span~, ty=clone_ty(ty))
    }
    FieldAccess(expr~, field=port, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewrite)
      FieldAccess(expr~, field=port, span~, ty=clone_ty(ty))
    }
    Instance(path~, params~, ports~, span~, ty~) => {
      let new_params = params.map!(fn(expr) { rewrite_expr!(expr, rewrite) })
      let new_ports = Map::new(capacity=ports.size())

      for port, expr in ports {
        new_ports[port] = rewrite_expr!(expr, rewrite)
      }

      Instance(path~, params=new_params, ports=new_ports, span~, ty=clone_ty(ty))
    }
    Vector(elems~, span~, ty~) => {
      let new_elems = Array::new(capacity=elems.length())

      for elem in elems {
        new_elems.push(rewrite_expr!(elem, rewrite))
      }

      Vector(elems=new_elems, span~, ty=clone_ty(ty))
    }
    Spread(expr~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewrite)
      Spread(expr~, span~, ty=clone_ty(ty))
    }
    Ternary(cond~, then~, else_~, span~, ty~) => {
      let cond = rewrite_expr!(cond, rewrite)
      let then = rewrite_expr!(then, rewrite)
      let else_ = rewrite_expr!(else_, rewrite)
      Ternary(cond~, then~, else_~, span~, ty=clone_ty(ty))
    }
    Match(subject~, cases~, default~, span~, ty~) => {
      let new_subject = rewrite_expr!(subject, rewrite)
      let new_cases = Array::new(capacity=cases.length())

      for case in cases {
        let (pat, expr) = case
        let pat = rewrite_expr!(pat, rewrite)
        let expr = rewrite_expr!(expr, rewrite)
        new_cases.push((pat, expr))
      }

      let new_default = match default {
        Some(expr) => Some(rewrite_expr!(expr, rewrite))
        None => None
      }

      Match(subject=new_subject, cases=new_cases, default=new_default, span~, ty=clone_ty(ty))
    }
    Tuple(elems~, span~, ty~) => {
      let new_elems = Array::new(capacity=elems.length())

      for elem in elems {
        new_elems.push(rewrite_expr!(elem, rewrite))
      }

      Tuple(elems=new_elems, span~, ty=clone_ty(ty))
    }
    Replicate(expr~, count~, concat~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewrite)
      let count = rewrite_expr!(count, rewrite)
      Replicate(expr~, count~, concat~, span~, ty=clone_ty(ty))
    }
    FunCall(name~, args~, span~, ty~) => {
      let new_args = Array::new(capacity=args.length())

      for arg in args {
        new_args.push(rewrite_expr!(arg, rewrite))
      }

      FunCall(name~, args=new_args, span~, ty=clone_ty(ty))
    }
    Struct(fields~, span~, ty~) => {
      let new_fields = Map::new(capacity=fields.size())

      for field, expr in fields {
        new_fields[field] = rewrite_expr!(expr, rewrite)
      }

      Struct(fields=new_fields, span~, ty=clone_ty(ty))
    }
    String(_) => expr
  }

  (rewrite)!(res)
}

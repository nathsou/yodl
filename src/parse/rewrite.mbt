
pub fn clone_ty(ty: Ref[Type?]) -> Ref[Type?] {
  let new_ty = match ty.val {
    Some(ty) => Some(ty.clone())
    None => None
  }

  { val: new_ty }
}

pub fn rewrite_expr(expr: Expr, rewr_expr~: (Expr) -> Expr?!, rewr_stmt~: (Stmt) -> Iter[Stmt]!) -> Expr! {
  let res = match expr {
    Natural(bits~, width~, base~, span~, ty~) => Expr::Natural(bits~, width~, base~, span~, ty=clone_ty(ty))
    Identifier(path~, span~, ty~) => Identifier(path~, span~, ty=clone_ty(ty)) 
    Unary(op~, expr~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewr_expr~, rewr_stmt~)
      Unary(op~, expr~, span~, ty=clone_ty(ty))
    }
    Binary(op~, lhs~, rhs~, span~, ty~) => {
      let lhs = rewrite_expr!(lhs, rewr_expr~, rewr_stmt~)
      let rhs = rewrite_expr!(rhs, rewr_expr~, rewr_stmt~)
      Binary(op~, lhs~, rhs~, span~, ty=clone_ty(ty))
    }
    Indexing(expr~, index~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewr_expr~, rewr_stmt~)
      let index = rewrite_expr!(index, rewr_expr~, rewr_stmt~)
      Indexing(expr~, index~, span~, ty=clone_ty(ty))
    }
    Slicing(expr~, msb~, lsb~, kind~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewr_expr~, rewr_stmt~)
      let msb = rewrite_expr!(msb, rewr_expr~, rewr_stmt~)
      let lsb = rewrite_expr!(lsb, rewr_expr~, rewr_stmt~)
      Slicing(expr~, msb~, lsb~, kind~, span~, ty=clone_ty(ty))
    }
    FieldAccess(expr~, field=port, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewr_expr~, rewr_stmt~)
      FieldAccess(expr~, field=port, span~, ty=clone_ty(ty))
    }
    Instance(path~, params~, ports~, span~, ty~) => {
      let new_params = params.map!(fn!(expr) { rewrite_expr!(expr, rewr_expr~, rewr_stmt~) })
      let new_ports = Map::new(capacity=ports.size())

      for port, expr in ports {
        new_ports[port] = rewrite_expr!(expr, rewr_expr~, rewr_stmt~)
      }

      Instance(path~, params=new_params, ports=new_ports, span~, ty=clone_ty(ty))
    }
    Vector(elems~, span~, ty~) => {
      let new_elems = Array::new(capacity=elems.length())

      for elem in elems {
        new_elems.push(rewrite_expr!(elem, rewr_expr~, rewr_stmt~))
      }

      Vector(elems=new_elems, span~, ty=clone_ty(ty))
    }
    Spread(expr~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewr_expr~, rewr_stmt~)
      Spread(expr~, span~, ty=clone_ty(ty))
    }
    Ternary(cond~, then~, else_~, span~, ty~) => {
      let cond = rewrite_expr!(cond, rewr_expr~, rewr_stmt~)
      let then = rewrite_expr!(then, rewr_expr~, rewr_stmt~)
      let else_ = rewrite_expr!(else_, rewr_expr~, rewr_stmt~)
      Ternary(cond~, then~, else_~, span~, ty=clone_ty(ty))
    }
    Match(subject~, cases~, default~, span~, ty~) => {
      let new_subject = rewrite_expr!(subject, rewr_expr~, rewr_stmt~)
      let new_cases = Array::new(capacity=cases.length())

      for case in cases {
        let (pat, expr) = case
        let pat = rewrite_expr!(pat, rewr_expr~, rewr_stmt~)
        let expr = rewrite_expr!(expr, rewr_expr~, rewr_stmt~)
        new_cases.push((pat, expr))
      }

      let new_default = match default {
        Some(expr) => Some(rewrite_expr!(expr, rewr_expr~, rewr_stmt~))
        None => None
      }

      Match(subject=new_subject, cases=new_cases, default=new_default, span~, ty=clone_ty(ty))
    }
    Tuple(elems~, span~, ty~) => {
      let new_elems = Array::new(capacity=elems.length())

      for elem in elems {
        new_elems.push(rewrite_expr!(elem, rewr_expr~, rewr_stmt~))
      }

      Tuple(elems=new_elems, span~, ty=clone_ty(ty))
    }
    Replicate(expr~, count~, concat~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewr_expr~, rewr_stmt~)
      let count = rewrite_expr!(count, rewr_expr~, rewr_stmt~)
      Replicate(expr~, count~, concat~, span~, ty=clone_ty(ty))
    }
    FunCall(name~, args~, span~, ty~) => {
      let new_args = Array::new(capacity=args.length())

      for arg in args {
        new_args.push(rewrite_expr!(arg, rewr_expr~, rewr_stmt~))
      }

      FunCall(name~, args=new_args, span~, ty=clone_ty(ty))
    }
    Struct(fields~, span~, ty~) => {
      let new_fields = Map::new(capacity=fields.size())

      for field, expr in fields {
        new_fields[field] = rewrite_expr!(expr, rewr_expr~, rewr_stmt~)
      }

      Struct(fields=new_fields, span~, ty=clone_ty(ty))
    }
    String(_) => expr
    Block(body~, last~, span~, ty~) => {
      let new_body = Array::new(capacity=body.length())

      for stmt in body {
        new_body.push_iter(rewrite_stmt!(stmt, rewr_expr~, rewr_stmt~))
      }

      let last = match last {
        Some(last) => Some(rewrite_expr!(last, rewr_expr~, rewr_stmt~))
        None => None
      }

      Block(body=new_body, last~, span~, ty=clone_ty(ty))
    }
  }

  match (rewr_expr)!(res) {
    Some(expr) => expr
    None => res
  }
}

pub fn rewrite_stmt(stmt: Stmt, rewr_expr~: (Expr) -> Expr?!, rewr_stmt~: (Stmt) -> Iter[Stmt]!) -> Iter[Stmt]! {
  let res = match stmt {
    Expr(expr~, span~) => {
      let expr = rewrite_expr!(expr, rewr_expr~, rewr_stmt~)
      Expr(expr~, span~)
    }
    Const(decl~, span~) => {
      let new_decl: ConstDecl = {
        path: decl.path,
        ty: decl.ty,
        expr: rewrite_expr!(decl.expr, rewr_expr~, rewr_stmt~),
        span: decl.span,
      }

      Const(decl=new_decl, span~)
    }
    Let(name~, ty~, expr~, span~) => {
      let expr = match expr {
        Some(expr) => Some(rewrite_expr!(expr, rewr_expr~, rewr_stmt~))
        None => None
      }

      Let(name~, ty~, expr~, span~)
    }
    Assign(lhs~, rhs~, span~) => {
      let lhs = rewrite_expr!(lhs, rewr_expr~, rewr_stmt~)
      let rhs = rewrite_expr!(rhs, rewr_expr~, rewr_stmt~)
      Assign(lhs~, rhs~, span~)
    }
    For(var~, range~, body~, span~) => {
      let range: ForRange = {
        start: rewrite_expr!(range.start, rewr_expr~, rewr_stmt~),
        end: rewrite_expr!(range.end, rewr_expr~, rewr_stmt~),
        inclusive: range.inclusive,
      }

      let body = Array::new(capacity=body.length())

      for stmt in body {
        body.push_iter(rewr_stmt!(stmt))
      }

      For(var~, range~, body~, span~)
    }
    Scope(body~, span~) => {
      let body = Array::new(capacity=body.length())

      for stmt in body {
        body.push_iter(rewr_stmt!(stmt))
      }

      Scope(body~, span~)
    }
    Procedural(body~, span~) => {
      let body = Array::new(capacity=body.length())

      for stmt in body {
        body.push_iter(rewr_stmt!(stmt))
      }

      Procedural(body~, span~)
    }
  }

  (rewr_stmt)!(res)
}

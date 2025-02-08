
pub fn clone_ty(ty: Ref[Type?]) -> Ref[Type?] {
  let new_ty = match ty.val {
    Some(ty) => Some(ty.clone())
    None => None
  }

  { val: new_ty }
}

pub fn rewrite_expr(expr: Expr, rewr_expr~: (Expr) -> Expr?!, rewr_stmt~: (Stmt) -> Iter[Stmt]!) -> Expr! {
  let res = match expr {
    Natural(value~, width~, base~, span~, ty~) => Expr::Natural(value~, width~, base~, span~, ty=clone_ty(ty))
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
    Slicing(expr~, hi=msb, lo=lsb, kind~, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewr_expr~, rewr_stmt~)
      let msb = rewrite_expr!(msb, rewr_expr~, rewr_stmt~)
      let lsb = rewrite_expr!(lsb, rewr_expr~, rewr_stmt~)
      Slicing(expr~, hi=msb, lo=lsb, kind~, span~, ty=clone_ty(ty))
    }
    FieldAccess(expr~, field=port, span~, ty~) => {
      let expr = rewrite_expr!(expr, rewr_expr~, rewr_stmt~)
      FieldAccess(expr~, field=port, span~, ty=clone_ty(ty))
    }
    Instance(path~, params~, ports~, span~, ty~) => {
      let new_params = params.map!(map_expr=fn!(expr) { rewrite_expr!(expr, rewr_expr~, rewr_stmt~) }, map_type=fn(ty) { ty.clone() })
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
        let (pat, case_expr) = case
        let pat = rewrite_expr!(pat, rewr_expr~, rewr_stmt~)
        let case_expr = rewrite_expr!(case_expr, rewr_expr~, rewr_stmt~)
        new_cases.push((pat, case_expr))
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
    If(cond~, then~, else_~, span~, ty~) => {
      let cond = rewrite_expr!(cond, rewr_expr~, rewr_stmt~)
      let then = rewrite_expr!(then, rewr_expr~, rewr_stmt~)
      let else_ = match else_ {
        Some(expr) => Some(rewrite_expr!(expr, rewr_expr~, rewr_stmt~))
        None => None
      }

      If(cond~, then~, else_~, span~, ty=clone_ty(ty))
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
      Stmt::Expr(expr~, span~)
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
  }

  (rewr_stmt)!(res)
}

// top-down traversal
pub fn visit_expr(expr: Expr, on_expr~: (Expr) -> Bool!, on_stmt~: (Stmt) -> Bool!) -> Unit! {
  let should_visit = (on_expr)!(expr)

  if should_visit {
    match expr {
      Natural(_) => ()
      Identifier(_) => ()
      Unary(expr~, op=_, span=_, ty=_) => visit_expr!(expr, on_expr~, on_stmt~)
      Binary(lhs~, rhs~, op=_, span=_, ty=_) => {
        visit_expr!(lhs, on_expr~, on_stmt~)
        visit_expr!(rhs, on_expr~, on_stmt~)
      }
      Indexing(expr~, index~, span=_, ty=_) => {
        visit_expr!(expr, on_expr~, on_stmt~)
        visit_expr!(index, on_expr~, on_stmt~)
      }
      Slicing(expr~, hi=msb, lo=lsb, kind=_, span=_, ty=_) => {
        visit_expr!(expr, on_expr~, on_stmt~)
        visit_expr!(msb, on_expr~, on_stmt~)
        visit_expr!(lsb, on_expr~, on_stmt~)
      }
      FieldAccess(expr~, field=_, span=_, ty=_) => visit_expr!(expr, on_expr~, on_stmt~)
      Instance(path=_, params~, ports~, span=_, ty=_) => {
        for param in params.params {
          match param {
            Expr(name=_, value~) => visit_expr!(value, on_expr~, on_stmt~)
            Type(_) => ()
          }
        }

        for _, expr in ports {
          visit_expr!(expr, on_expr~, on_stmt~)
        }
      }
      Vector(elems~, span=_, ty=_) => {
        for elem in elems {
          visit_expr!(elem, on_expr~, on_stmt~)
        }
      }
      Spread(expr~, span=_, ty=_) => visit_expr!(expr, on_expr~, on_stmt~)
      Ternary(cond~, then~, else_~, span=_, ty=_) => {
        visit_expr!(cond, on_expr~, on_stmt~)
        visit_expr!(then, on_expr~, on_stmt~)
        visit_expr!(else_, on_expr~, on_stmt~)
      }
      Match(subject~, cases~, default~, span=_, ty=_) => {
        visit_expr!(subject, on_expr~, on_stmt~)

        for case in cases {
          visit_expr!(case.0, on_expr~, on_stmt~)
          visit_expr!(case.1, on_expr~, on_stmt~)
        }

        match default {
          Some(expr) => visit_expr!(expr, on_expr~, on_stmt~)
          None => ()
        }
      }
      Tuple(elems~, span=_, ty=_) => {
        for elem in elems {
          visit_expr!(elem, on_expr~, on_stmt~)
        }
      }
      Replicate(expr~, count~, concat=_, span=_, ty=_) => {
        visit_expr!(expr, on_expr~, on_stmt~)
        visit_expr!(count, on_expr~, on_stmt~)
      }
      FunCall(name=_, args~, span=_, ty=_) => {
        for arg in args {
          visit_expr!(arg, on_expr~, on_stmt~)
        }
      }
      Struct(fields~, span=_, ty=_) => {
        for _, expr in fields {
          visit_expr!(expr, on_expr~, on_stmt~)
        }
      }
      String(_) => ()
      Block(body~, last~, span=_, ty=_) => {
        for stmt in body {
          visit_stmt!(stmt, on_expr~, on_stmt~)
        }

        match last {
          Some(expr) => visit_expr!(expr, on_expr~, on_stmt~)
          None => ()
        }
      }
      If(cond~, then~, else_~, span=_, ty=_) => {
        visit_expr!(cond, on_expr~, on_stmt~)
        visit_expr!(then, on_expr~, on_stmt~)

        match else_ {
          Some(expr) => visit_expr!(expr, on_expr~, on_stmt~)
          None => ()
        }
      }
    }
  }
}

pub fn visit_stmt(stmt: Stmt, on_expr~: (Expr) -> Bool!, on_stmt~: (Stmt) -> Bool!) -> Unit! {
  let should_visit = (on_stmt)!(stmt)

  if should_visit {
    match stmt {
      Expr(expr~, span=_) => visit_expr!(expr, on_expr~, on_stmt~)
      Const(decl=_, span=_) => ()
      Let(name=_, ty=_, expr~, span=_) => {
        match expr {
          Some(expr) => visit_expr!(expr, on_expr~, on_stmt~)
          None => ()
        }
      }
      Assign(lhs~, rhs~, span=_) => {
        visit_expr!(lhs, on_expr~, on_stmt~)
        visit_expr!(rhs, on_expr~, on_stmt~)
      }
      For(var=_, range~, body~, span=_) => {
        visit_expr!(range.start, on_expr~, on_stmt~)
        visit_expr!(range.end, on_expr~, on_stmt~)

        for stmt in body {
          visit_stmt!(stmt, on_expr~, on_stmt~)
        }
      }
      Scope(body~, span=_) => {
        for stmt in body {
          visit_stmt!(stmt, on_expr~, on_stmt~)
        }
      }
    }
  }
}

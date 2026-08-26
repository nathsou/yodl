
pub fn clone_ty(ty: Ref[Type?]) -> Ref[Type?] {
  let new_ty = match ty.val {
    Some(ty) => Some(ty.clone())
    None => None
  }

  { val: new_ty }
}

pub(all) struct Rewriter {
  rewr_expr: (Expr) -> Expr? raise
  rewr_stmt: (Stmt) -> Iter[Stmt] raise
}

pub fn rewrite_expr(expr: Expr, rewriter: Rewriter) -> Expr raise {
  let rewr_expr = rewriter.rewr_expr
  let res = match expr {
    Natural(value~, width~, base~, span~, ty~) => Expr::Natural(value~, width~, base~, span~, ty=clone_ty(ty))
    Identifier(path~, span~, ty~) => Identifier(path~, span~, ty=clone_ty(ty)) 
    Unary(op~, expr~, span~, ty~) => {
      let expr = rewrite_expr(expr, rewriter)
      Unary(op~, expr~, span~, ty=clone_ty(ty))
    }
    Binary(op~, lhs~, rhs~, span~, ty~) => {
      let lhs = rewrite_expr(lhs, rewriter)
      let rhs = rewrite_expr(rhs, rewriter)
      Binary(op~, lhs~, rhs~, span~, ty=clone_ty(ty))
    }
    Indexing(expr~, index~, span~, ty~) => {
      let expr = rewrite_expr(expr, rewriter)
      let index = rewrite_expr(index, rewriter)
      Indexing(expr~, index~, span~, ty=clone_ty(ty))
    }
    Slicing(expr~, hi=msb, lo=lsb, kind~, span~, ty~) => {
      let expr = rewrite_expr(expr, rewriter)
      let msb = rewrite_expr(msb, rewriter)
      let lsb = rewrite_expr(lsb, rewriter)
      Slicing(expr~, hi=msb, lo=lsb, kind~, span~, ty=clone_ty(ty))
    }
    FieldAccess(expr~, field=port, span~, ty~) => {
      let expr = rewrite_expr(expr, rewriter)
      FieldAccess(expr~, field=port, span~, ty=clone_ty(ty))
    }
    Instance(path~, params~, ports~, span~, ty~) => {
      let new_params = params.map_raw(map_type=ty => ty.clone())
      let new_ports = Map([], capacity=ports.length())

      for port, expr in ports {
        new_ports[port] = rewrite_expr(expr, rewriter)
      }

      Instance(path~, params=new_params, ports=new_ports, span~, ty=clone_ty(ty))
    }
    Vector(elems~, span~, ty~) => {
      let new_elems = Array::new(capacity=elems.length())

      for elem in elems {
        new_elems.push(rewrite_expr(elem, rewriter))
      }

      Vector(elems=new_elems, span~, ty=clone_ty(ty))
    }
    Spread(expr~, span~, ty~) => {
      let expr = rewrite_expr(expr, rewriter)
      Spread(expr~, span~, ty=clone_ty(ty))
    }
    Ternary(cond~, then~, else_~, span~, ty~) => {
      let cond = rewrite_expr(cond, rewriter)
      let then = rewrite_expr(then, rewriter)
      let else_ = rewrite_expr(else_, rewriter)
      Ternary(cond~, then~, else_~, span~, ty=clone_ty(ty))
    }
    Match(subject~, cases~, default~, span~, ty~) => {
      let new_subject = rewrite_expr(subject, rewriter)
      let new_cases = Array::new(capacity=cases.length())

      for case in cases {
        let (pat, case_expr) = case
        let pat = rewrite_expr(pat, rewriter)
        let case_expr = rewrite_expr(case_expr, rewriter)
        new_cases.push((pat, case_expr))
      }

      let new_default = match default {
        Some(expr) => Some(rewrite_expr(expr, rewriter))
        None => None
      }

      Match(subject=new_subject, cases=new_cases, default=new_default, span~, ty=clone_ty(ty))
    }
    FunCall(name~, args~, span~, ty~) => {
      let new_args = Array::new(capacity=args.length())

      for arg in args {
        new_args.push(rewrite_expr(arg, rewriter))
      }

      FunCall(name~, args=new_args, span~, ty=clone_ty(ty))
    }
    Struct(fields~, span~, ty~) => {
      let new_fields = Map([], capacity=fields.length())

      for field, expr in fields {
        new_fields[field] = rewrite_expr(expr, rewriter)
      }

      Struct(fields=new_fields, span~, ty=clone_ty(ty))
    }
    String(_) => expr
    Block(body~, last~, span~, ty~) => {
      let new_body = Array::new(capacity=body.length())

      for stmt in body {
        new_body.push_iter(rewrite_stmt(stmt, rewr_expr=rewriter.rewr_expr, rewr_stmt=rewriter.rewr_stmt))
      }

      let last = match last {
        Some(last) => Some(rewrite_expr(last, rewriter))
        None => None
      }

      Block(body=new_body, last~, span~, ty=clone_ty(ty))
    }
    If(cond~, then~, else_~, span~, ty~) => {
      let cond = rewrite_expr(cond, rewriter)
      let then = rewrite_expr(then, rewriter)
      let else_ = match else_ {
        Some(expr) => Some(rewrite_expr(expr, rewriter))
        None => None
      }

      If(cond~, then~, else_~, span~, ty=clone_ty(ty))
    }
  }

  match (rewr_expr)(res) {
    Some(expr) => expr
    None => res
  }
}

pub fn rewrite_stmt(stmt: Stmt, rewr_expr~: (Expr) -> Expr? raise, rewr_stmt~: (Stmt) -> Iter[Stmt] raise) -> Iter[Stmt] raise {
  let rewriter: Rewriter = { rewr_expr, rewr_stmt: stmt => rewrite_stmt(stmt, rewr_expr~, rewr_stmt~) }
  let res = match stmt {
    Expr(expr~, span~) => {
      let expr = rewrite_expr(expr, rewriter)
      Stmt::Expr(expr~, span~)
    }
    Const(decl~, span~) => {
      let new_decl: ConstDecl = {
        path: decl.path,
        ty: decl.ty,
        expr: rewrite_expr(decl.expr, rewriter),
        span: decl.span,
      }

      Const(decl=new_decl, span~)
    }
    Let(name~, ty~, expr~, span~) => {
      let expr = match expr {
        Some(expr) => Some(rewrite_expr(expr, rewriter))
        None => None
      }

      Let(name~, ty~, expr~, span~)
    }
    Assign(lhs~, rhs~, span~) => {
      let lhs = rewrite_expr(lhs, rewriter)
      let rhs = rewrite_expr(rhs, rewriter)
      Assign(lhs~, rhs~, span~)
    }
    For(variable~, range~, body~, span~) => {
      let range: ForRange = {
        start: rewrite_expr(range.start, rewriter),
        end: rewrite_expr(range.end, rewriter),
        inclusive: range.inclusive,
      }

      let new_body = Array::new(capacity=body.length())

      for stmt in body {
        new_body.push_iter(rewr_stmt(stmt))
      }

      For(variable~, range~, body=new_body, span~)
    }
    Scope(body~, span~) => {
      let new_body = Array::new(capacity=body.length())

      for stmt in body {
        new_body.push_iter(rewr_stmt(stmt))
      }

      Scope(body=new_body, span~)
    }
  }

  (rewr_stmt)(res)
}

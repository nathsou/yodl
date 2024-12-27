
pub(readonly) struct Simplifier {
  genvars: @elaborate.Scope[Int]
  names: @elaborate.Scope[UniqueName]
  name_counts: Map[String, Int]
}

struct UniqueName {
  name: String
  id: Int
}

impl Show for UniqueName with output(self, logger) {
  if self.id > 0 {
    logger.write_string("%")
    logger.write_string(self.name)
    logger.write_string(self.id.to_string())
  } else {
    logger.write_string(self.name)
  }
}

pub fn Simplifier::new() -> Simplifier {
  {
    genvars: @elaborate.Scope::new(),
    names: @elaborate.Scope::new(),
    name_counts: {},
  }
}

pub(readonly) type! SimplificationError {

}

pub fn declare_unique(self: Simplifier, name: String) -> UniqueName {
  let count = match self.name_counts[name] {
    Some(count) => count
    None => 0
  }

  self.name_counts[name] = count + 1

  { name, id: count }
}

pub fn simplify_expr(self: Simplifier, expr: @parse.Expr) -> @parse.Expr!Error {
  let res = match expr {
    Natural(_) => expr
    Identifier(name~, span~, ty~) => {
      match self.genvars.resolve(name) {
        Some(value) => @parse.Expr::Natural(value=value, width=None, span~, ty~)
        None => match self.names.resolve(name) {
          Some(unique_name) => @parse.Expr::Identifier(name=unique_name.to_string(), span~, ty~)
          None => expr
        }
      }
    }
    Unary(op~, expr~, span~, ty~) => {
      let simplified_expr = self.simplify_expr!(expr)
      @parse.Expr::Unary(op~, expr=simplified_expr, span~, ty~)
    }
    Binary(op~, lhs~, rhs~, span~, ty~) => {
      let simplified_lhs = self.simplify_expr!(lhs)
      let simplified_rhs = self.simplify_expr!(rhs)
      @parse.Expr::Binary(op~, lhs=simplified_lhs, rhs=simplified_rhs, span~, ty~)
    }
    Indexing(expr~, index~, span~, ty~) => {
      let simplified_expr = self.simplify_expr!(expr)
      let simplified_index = self.simplify_expr!(index)
      @parse.Expr::Indexing(expr=simplified_expr, index=simplified_index, span~, ty~)
    }
    Slicing(expr~, msb~, lsb~, span~, ty~) => {
      let simplified_expr = self.simplify_expr!(expr)
      let simplified_msb = self.simplify_expr!(msb)
      let simplified_lsb = self.simplify_expr!(lsb)
      @parse.Expr::Slicing(expr=simplified_expr, msb=simplified_msb, lsb=simplified_lsb, span~, ty~)
    }
    PortAccess(expr~, port~, span~, ty~) => {
      let simplified_expr = self.simplify_expr!(expr)
      @parse.Expr::PortAccess(expr=simplified_expr, port~, span~, ty~)
    }
    Instance(name~, params~, span~, ty~, ports~) => {
      let simplified_ports = {}

      for name, val in ports {
        simplified_ports[name] = self.simplify_expr!(val)
      }

      @parse.Expr::Instance(name~, params~, ports=simplified_ports, span~, ty~)
    }
    Vector(elems~, span~, ty~) => {
      let simplified_elems = []

      for elem in elems {
        simplified_elems.push(self.simplify_expr!(elem))
      }

      @parse.Expr::Vector(elems=simplified_elems, span~, ty~)
    }
    Spread(expr~, span~, ty~) => {
      let simplified_expr = self.simplify_expr!(expr)
      @parse.Expr::Spread(expr=simplified_expr, span~, ty~)
    }
    Ternary(cond~, then~, else_~, span~, ty~) => {
      let simplified_cond = self.simplify_expr!(cond)
      let simplified_then = self.simplify_expr!(then)
      let simplified_else = self.simplify_expr!(else_)
      @parse.Expr::Ternary(cond=simplified_cond, then=simplified_then, else_=simplified_else, span~, ty~)
    }
  }

  res.constant_folding!()
}

pub fn simplify_stmt(self: Simplifier, stmt: @parse.Stmt) -> Array[@parse.Stmt]!Error {
  match stmt {
    Expr(expr~, span~) => {
      let simplified_expr = self.simplify_expr!(expr)
      [@parse.Stmt::Expr(expr=simplified_expr, span~)]
    }
    Let(name~, ty~, expr~, span~) => {
      let simplified_expr = match expr {
        Some(expr) => Some(self.simplify_expr!(expr))
        None => None
      }

      let unique_name = self.declare_unique(name)
      self.names.declare_shadowing(name, unique_name)

      [@parse.Stmt::Let(name=unique_name.to_string(), ty~, expr=simplified_expr, span~)]
    }
    Assign(lhs~, rhs~, span~) => {
      let simplified_lhs = self.simplify_expr!(lhs)
      let simplified_rhs = self.simplify_expr!(rhs)
      [@parse.Stmt::Assign(lhs=simplified_lhs, rhs=simplified_rhs, span~)]
    }
    For(var~, range~, body~, ..) => {
      let unrolled_stmts = []
      let start = self.simplify_expr!(range.start).expect_int!()
      let mut end = self.simplify_expr!(range.end).expect_int!()

      if range.inclusive {
        end += 1
      }

      for i in start..<end {
        self.genvars.declare!(var, i)

        for stmt in body {
          unrolled_stmts.push_iter(self.simplify_stmt!(stmt).iter())
        }

        self.genvars.remove(var)
      }

      unrolled_stmts
    }
    Scope(body~, ..) => {
      let simplified_body = []

      for stmt in body {
        simplified_body.push_iter(self.simplify_stmt!(stmt).iter())
      }

      simplified_body
    }
  }
}

pub fn simplify_decl(self: Simplifier, decl: @parse.Decl) -> @parse.Decl!Error {
  match decl {
    Module({ name, params, attributes, inputs, outputs, body, span }) => {
      let simplified_body = []

      for stmt in body {
        simplified_body.push_iter(self.simplify_stmt!(stmt).iter())
      }

      @parse.Decl::Module({ name, params, attributes, inputs, outputs, body: simplified_body, span })
    }
    ModuleDeclaration(sig) => {
      @parse.Decl::ModuleDeclaration(sig)
    }
  }
}

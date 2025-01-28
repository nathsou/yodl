
pub(all) enum Expr {
  Const(value~: Const, span~: @parse.Span)
  Variable(name~: String, width~: Int, span~: @parse.Span)
  Unary(op~: @parse.UnaryOp, expr~: Expr, width~: Int, span~: @parse.Span)
  Binary(op~: @parse.BinaryOp, lhs~: Expr, rhs~: Expr, width~: Int, span~: @parse.Span)
  Concat(elems~: Array[Expr], width~: Int, span~: @parse.Span)
  Select(expr~: Expr, offset~: Int, width~: Int, span~: @parse.Span)
  Mux(subject~: Expr, cases~: Array[(Const, Expr)], default~: Expr?, width~: Int, span~: @parse.Span)
  Block(body~: Array[Stmt], last~: Expr?, width~: Int, span~: @parse.Span)
  FunCall(name~: String, args~: Array[Expr], width~: Int, span~: @parse.Span)
  String(value~: String, width~: Int, span~: @parse.Span)
}

pub(all) enum Stmt {
  Expr(expr~: Expr, span~: @parse.Span)
  Wire(name~: String, width~: Int, span~: @parse.Span)
  Reg(
    width~: Int,
    async_reset~: Bool,
    clk~: Expr,
    data_in~: Expr,
    enable~: Expr?,
    reset~: Expr?,
    data_out~: Expr,
    span~: @parse.Span,
  )
  Assign(lhs~: Expr, rhs~: Expr, span~: @parse.Span)
  Memory(
    width~: Int,
    depth~: Int,
    init~: @parse.Bits?,
    clk~: Expr,
    read_addr~: Array[Expr],
    write_addr~: Array[Expr],
    write_enable~: Array[Expr]?,
    data_in~: Array[Expr],
    data_out~: Array[Expr],
    span~: @parse.Span,
  )
  Instance(module_name~: String, ports~: Map[String, Expr], span~: @parse.Span)
  Process(triggers~: ProcessTriggers, body~: Array[Stmt], span~: @parse.Span)
}

pub(all) enum ProcessTriggers {
  All
  Events(Array[SensitivityListEvent])
}

pub(all) struct SensitivityListEvent {
  polarity: Polarity?
  signal: String
}

pub(all) enum Polarity {
  Posedge; Negedge
} derive(Eq)

pub(all) struct Port {
  name: String
  width: Int
  direction: @parse.PortDirection
  span: @parse.Span
}

pub(all) struct Module {
  name: String
  ports: Array[Port]
  body: Array[Stmt]
  span: @parse.Span
}

pub(all) enum ConstBase {
  Bin; Oct; Dec; Hex
}

pub(all) struct Const {
  bits: @parse.Bits
  width: Int
  base: Int
} derive(Eq)

pub fn Const::zeros(width: Int, span~: @parse.Span) -> Const {
  {
    bits: { bits: @utils.fill(width, Zero), value: Some(BigInt::from_int(0)), span },
    width,
    base: 2,
  }
}

pub fn Const::xs(width: Int, span~: @parse.Span) -> Const {
  { bits: { bits: @utils.fill(width, X), value: None, span }, width, base: 2 }
}

pub fn Const::from(value: Int, width~: Int, span~: @parse.Span) -> Const! {
  { bits: @parse.Bits::from!(value, width=Some(width), span~), width, base: 10 }
}

pub fn Expr::width(self: Expr) -> Int {
  match self {
    Const(value~, ..) => value.width
    Variable(width~, ..) => width
    Unary(width~, ..) => width
    Binary(width~, ..) => width
    Concat(width~, ..) => width
    Select(width~, ..) => width
    Mux(width~, ..) => width
    Block(width~, ..) => width
    FunCall(width~, ..) => width
    String(width~, ..) => width
  }
}

pub fn Module::add_stmt(self: Module, stmt: Stmt) -> Unit {
  self.body.push(stmt)
}

pub fn Expr::child_statements(self: Expr) -> Iter[Stmt] {
  let mut iter = Iter::empty()
  let stack = [self]

  while stack.length() > 0 {
    let expr = stack.unsafe_pop()
    
    match expr {
      Const(_) => ()
      Variable(_) => ()
      Unary(expr~, ..) => stack.push(expr)
      Binary(lhs~, rhs~, ..) => {
        stack.push(lhs)
        stack.push(rhs)
      }
      Concat(elems~, ..) => stack.push_iter(elems.iter())
      Select(expr~, ..) => stack.push(expr)
      Mux(subject~, cases~, default~, ..) => {
        stack.push(subject)

        for case in cases {
          stack.push(case.1)
        }

        match default {
          Some(expr) => stack.push(expr)
          None => ()
        }
      }
      Block(body~, last~, ..) => {
        for stmt in body {
          iter += Iter::singleton(stmt) + stmt.child_statements()
        }

        match last {
          Some(expr) => stack.push(expr)
          None => ()
        }
      }
      FunCall(args~, ..) => stack.push_iter(args.iter())
      String(_) => ()
    }
  }

  iter
}

pub fn Stmt::child_statements(self: Stmt) -> Iter[Stmt] {
  let mut iter = Iter::empty()

  let stack = [self]

  while stack.length() > 0 {
    let stmt = stack.unsafe_pop()
    iter += Iter::singleton(stmt)

    match stmt {
      Expr(expr~, ..) => iter += expr.child_statements()
      Wire(_) => ()
      Reg(clk~, data_in~, enable~, reset~, data_out~, ..) => {
        iter += clk.child_statements()
        iter += data_in.child_statements()

        match enable {
          Some(expr) => iter += expr.child_statements()
          None => ()
        }

        match reset {
          Some(expr) => iter += expr.child_statements()
          None => ()
        }

        iter += data_out.child_statements()
      }
      Assign(lhs~, rhs~, ..) => iter += lhs.child_statements() + rhs.child_statements()
      Memory(clk~, read_addr~, write_addr~, write_enable~, data_in~, data_out~, ..) => {
        iter += clk.child_statements()

        for addr in read_addr {
          iter += addr.child_statements()
        }

        for addr in write_addr {
          iter += addr.child_statements()
        }

        match write_enable {
          Some(enables) => {
            for en in enables {
              iter += en.child_statements()
            }
          }
          None => ()
        }

        for data in data_in {
          iter += data.child_statements()
        }

        for data in data_out {
          iter += data.child_statements()
        }
      }
      Instance(ports~, ..) => {
        for port_expr in ports.values() {
          iter += port_expr.child_statements()
        }
      }
      Process(body~, ..) => {
        stack.push_iter(body.iter())
      }
    }
  }

  iter
}

pub fn Module::child_statements(self: Module) -> Iter[Stmt] {
  let stmts = []

  for stmt in self.body {
    stmts.push_iter(stmt.child_statements())
  }

  stmts.iter()
}

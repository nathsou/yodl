
pub enum Expr {
  Identifier(String)
  PartSelect(expr~: Expr, offset~: Expr, width~: Int)
  Concat(Array[Expr])
  Const(@yir.Const) 
  Unary(op~: @parse.UnaryOp, expr~: Expr)
  Binary(op~: @parse.BinaryOp, lhs~: Expr, rhs~: Expr)
  FunCall(name~: String, args~: Array[Expr])
  String(value~: String)
} derive(Eq)

pub enum Stmt {
  Expr(expr~: Expr)
  WireDecl(name~: String, top~: Int, bot~: Int, init~: Expr?)
  RegDecl(name~: String, top~: Int, bot~: Int, width~: Int, init~: Expr?)
  Assign(lhs~: Expr, rhs~: Expr, kind~: AssignmentKind)
  If(cond~: Expr, then~: Stmt, else_~: Stmt?)
  Casez(cond~: Expr, cases~: Array[(Expr, Stmt)], default~: Stmt?)
  Instance(mod~: String, name~: String, parameters~: Array[(String, @rtlil.Constant)], ports~: Array[(String, Expr)])
  Block(Array[Stmt])
  Always(sensitivity_list~: SensitivityList, body~: Stmt)
  Initial(body~: Stmt)
}

pub enum SensitivityList {
  All // always @(*)
  Events(Array[SensitivityListEvent]) // always @(posedge clk or negedge reset ...)
}

pub struct SensitivityListEvent {
  polarity: Polarity?
  signal: Expr
}

pub enum Polarity {
  Posedge; Negedge
} derive(Eq)

pub enum AssignmentKind {
  Continous; Blocking; NonBlocking
} derive(Eq)

pub enum PortType {
  Wire; Reg
}

pub struct Port {
  name: String
  type_: PortType
  width: Int
  direction: @parse.PortDirection
}

pub struct ModuleDecl {
  name: String
  ports: Array[Port]
  body: Array[Stmt]
}

pub enum Decl {
  Module(ModuleDecl)
}

fn is_reserved_keyword(name: String) -> Bool {
  match name {
    "module" | "endmodule" | "begin" | "end" | "wire" | "reg" |
    "input" | "output" | "inout" | "assign" | "always" | "cell" |
    "posedge" | "negedge" | "if" | "else" | "case" | "default" => true
    _ => false
  }
}

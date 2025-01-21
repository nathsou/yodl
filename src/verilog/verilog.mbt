
pub enum Expr {
  Identifier(String)
  BitSelect(expr~: Expr, offset~: Int)
  PartSelect(expr~: Expr, offset~: Expr, width~: Int)
  Concat(Array[Expr])
  Const(@rtlil.Constant)
  Unary(op~: @parse.UnaryOp, expr~: Expr)
  Binary(op~: @parse.BinaryOp, lhs~: Expr, rhs~: Expr)
  Ternary(cond~: Expr, then~: Expr, else_~: Expr)
  FunctionCall(name~: String, args~: Array[Expr])
} derive(Eq)

pub enum Stmt {
  WireDecl(name~: String, msb~: Int, lsb~: Int, init~: Expr?)
  RegDecl(name~: String, msb~: Int, lsb~: Int, width~: Int, init~: Expr?)
  FunctionDecl(name~: String, output_width~: Int, args~: Array[FunctionArgument], body~: Stmt)
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
  signal: String
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

pub struct FunctionArgument {
  name: String
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
    "input" | "output" | "inout" | "assign" | "always" |
    "posedge" | "negedge" | "if" | "else" | "case" | "default" => true
    _ => false
  }
}

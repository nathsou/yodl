struct Scope[T] {
  members: Map[String, T]
  parent: Scope[T]?
}

type! ScopeError {
  MemberAlreadyDeclared
}

pub fn Scope::new[T]() -> Scope[T] {
  { members: {}, parent: None }
}

pub fn child[T](self: Scope[T]) -> Scope[T] {
  { members: {}, parent: Some(self) }
}

pub fn declare[T](self: Scope[T], name: String, value: T) -> Unit!ScopeError {
  if self.members.contains(name) {
    raise MemberAlreadyDeclared
  }

  self.members[name] = value
}

pub fn declare_shadowing[T](self: Scope[T], name: String, value: T) -> Unit {
  self.members[name] = value
}

pub fn contains[T](self: Scope[T], name: String) -> Bool {
  self.members.contains(name) || (match self.parent {
    Some(parent) => parent.contains(name)
    None => false
  })
}

pub fn contains_local[T](self: Scope[T], name: String) -> Bool {
  self.members.contains(name)
}

pub fn resolve[T](self: Scope[T], name: String) -> T? {
  match self.members.get(name) {
    Some(value) => Some(value)
    None => match self.parent {
      Some(parent) => parent.resolve(name)
      None => None
    }
  }
}

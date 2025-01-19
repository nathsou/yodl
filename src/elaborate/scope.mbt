struct Scope[K, T] {
  members: Map[K, T]
  parent: Scope[K, T]?
}

type! ScopeError {
  MemberAlreadyDeclared(name~: String)
} derive(Show)

pub fn Scope::new[K: Eq + Hash, T]() -> Scope[K, T] {
  { members: {}, parent: None }
}

pub fn child[K: Eq + Hash, T](self: Scope[K, T]) -> Scope[K, T] {
  { members: {}, parent: Some(self) }
}

pub fn Scope::declare[K: Eq + Hash + Show, T](self: Scope[K, T], key: K, value: T) -> Unit!ScopeError {
  if self.members.contains(key) {
    raise MemberAlreadyDeclared(name=key.to_string())
  }

  self.members[key] = value
}

pub fn declare_shadowing[K: Eq + Hash, T](self: Scope[K, T], key: K, value: T) -> Unit {
  self.members[key] = value
}

pub fn contains[K: Eq + Hash, T](self: Scope[K, T], key: K) -> Bool {
  self.members.contains(key) || (match self.parent {
    Some(parent) => parent.contains(key)
    None => false
  })
}

pub fn contains_local[K: Eq + Hash, T](self: Scope[K, T], key: K) -> Bool {
  self.members.contains(key)
}

pub fn resolve[K: Eq + Hash, T](self: Scope[K, T], key: K) -> T? {
  match self.members.get(key) {
    Some(value) => Some(value)
    None => match self.parent {
      Some(parent) => parent.resolve(key)
      None => None
    }
  }
}

pub fn remove[K: Eq + Hash, T](self: Scope[K, T], key: K) -> Unit {
  self.members.remove(key)
}

pub fn members[K, T](self: Scope[K, T]) -> Iter[K] {
  self.members.keys()
}

pub fn members_rec[K, T](self: Scope[K, T]) -> Iter[K] {
  self.members.keys() + (match self.parent {
    Some(parent) => parent.members_rec()
    None => Iter::empty()
  })
}

pub fn values[K, T](self: Scope[K, T]) -> Iter[T] {
  self.members.values()
}

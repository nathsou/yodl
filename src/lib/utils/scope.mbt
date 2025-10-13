pub struct Scope[K, T] {
  members: Map[K, T]
  parent: Scope[K, T]?
}

pub suberror ScopeError {
  MemberAlreadyDeclared(name~: String)
} derive(Show)

pub fn[K: Eq + Hash, T] Scope::new() -> Scope[K, T] {
  { members: {}, parent: None }
}

pub fn[K: Eq + Hash, T] Scope::child(self: Scope[K, T]) -> Scope[K, T] {
  { members: {}, parent: Some(self) }
}

pub fn[K: Eq + Hash + Show, T] Scope::declare(self: Scope[K, T], key: K, value: T) -> Unit raise ScopeError {
  if self.members.contains(key) {
    raise MemberAlreadyDeclared(name=key.to_string())
  }

  self.members[key] = value
}

pub fn[K: Eq + Hash, T] Scope::declare_shadowing(self: Scope[K, T], key: K, value: T) -> Unit {
  self.members[key] = value
}

pub fn[K: Eq + Hash, T] Scope::contains(self: Scope[K, T], key: K) -> Bool {
  self.members.contains(key) || self.parent.map_or(false, parent => parent.contains(key))
}

pub fn[K: Eq + Hash, T] Scope::contains_local(self: Scope[K, T], key: K) -> Bool {
  self.members.contains(key)
}

pub fn[K: Eq + Hash, T] Scope::resolve(self: Scope[K, T], key: K) -> T? {
  match self.members.get(key) {
    Some(value) => Some(value)
    None => self.parent.map_or(None, parent => parent.resolve(key))
  }
}

pub fn[K: Eq + Hash, T] Scope::remove(self: Scope[K, T], key: K) -> Unit {
  self.members.remove(key)
}

pub fn[K, T] Scope::members(self: Scope[K, T]) -> Iter[K] {
  self.members.keys()
}

pub fn[K, T] Scope::members_rec(self: Scope[K, T]) -> Iter[K] {
  self.members.keys() + (match self.parent {
    Some(parent) => parent.members_rec()
    None => Iter::empty()
  })
}

pub fn[K, T] Scope::values(self: Scope[K, T]) -> Iter[T] {
  self.members.values()
}

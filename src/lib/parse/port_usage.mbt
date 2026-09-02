///|
/// Access mode collected for an instance port. This is lowering analysis data,
/// deliberately kept outside `Type` so type equality remains side-effect free.
pub(all) enum PortAccess {
  Read
  Write
  ReadWrite
} derive(Eq)

///|
/// Stable identity carried by instance-valued expressions and bindings.
pub(all) struct InstanceId {
  value : Int
} derive(Eq)

///|
pub fn InstanceId::new(value : Int) -> InstanceId {
  { value, }
}

///|
/// Port demand keyed by instance identity. The type checker populates this
/// table and the elaborator consumes it when materialising instance bundles.
pub struct PortUsage {
  instances : Map[Int, Map[String, PortAccess]]
  escaped_instances : Set[Int]
}

///|
pub fn PortUsage::new() -> PortUsage {
  { instances: {}, escaped_instances: Set([]) }
}

///|
/// Records that an instance identity is used as a whole value rather than
/// solely through direct port accesses.
pub fn PortUsage::record_escape(
  self : PortUsage,
  ids : Array[InstanceId],
) -> Unit {
  for id in ids {
    self.escaped_instances.add(id.value)
  }
}

///|
pub fn PortUsage::escapes(
  self : PortUsage,
  ids : Array[InstanceId],
) -> Bool {
  ids.any(id => self.escaped_instances.contains(id.value))
}

///|
fn merge_access(lhs : PortAccess, rhs : PortAccess) -> PortAccess {
  match (lhs, rhs) {
    (Read, Read) => Read
    (Write, Write) => Write
    _ => ReadWrite
  }
}

///|
pub fn PortUsage::record(
  self : PortUsage,
  ids : Array[InstanceId],
  port : String,
  access : PortAccess,
) -> Unit {
  for id in ids {
    let ports = match self.instances.get(id.value) {
      Some(ports) => ports
      None => {
        let ports = Map([])
        self.instances[id.value] = ports
        ports
      }
    }

    match ports.get(port) {
      Some(existing) => ports[port] = merge_access(existing, access)
      None => ports[port] = access
    }
  }
}

///|
pub fn PortUsage::record_read(
  self : PortUsage,
  ids : Array[InstanceId],
  port : String,
) -> Unit {
  self.record(ids, port, Read)
}

///|
pub fn PortUsage::record_write(
  self : PortUsage,
  ids : Array[InstanceId],
  port : String,
) -> Unit {
  self.record(ids, port, Write)
}

///|
/// Returns the deterministic union for a value which may denote any of the
/// supplied instances (for example, an instance selected by a branch).
pub fn PortUsage::for_instances(
  self : PortUsage,
  ids : Array[InstanceId],
) -> Map[String, PortAccess] {
  let merged = Map([])

  for id in ids {
    if self.instances.get(id.value) is Some(ports) {
      for port, access in ports {
        match merged.get(port) {
          Some(existing) => merged[port] = merge_access(existing, access)
          None => merged[port] = access
        }
      }
    }
  }

  merged
}

///|
pub fn PortUsage::contains(
  self : PortUsage,
  ids : Array[InstanceId],
  port : String,
) -> Bool {
  self.for_instances(ids).contains(port)
}

///|
pub fn PortUsage::is_written_to(
  self : PortUsage,
  ids : Array[InstanceId],
  port : String,
) -> Bool {
  match self.for_instances(ids).get(port) {
    Some(Write | ReadWrite) => true
    _ => false
  }
}

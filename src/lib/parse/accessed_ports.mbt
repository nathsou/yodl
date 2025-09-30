
pub(all) enum PortAccess {
  Read; Write
} derive(Eq)

pub struct AccessedPorts(Map[String, PortAccess]) derive(Eq)

pub impl Show for AccessedPorts with output(self, logger) {
  let mut first = true
  logger.write_char('{')

  for port, usage in self.0 {
    if !first {
      logger.write_string(", ")
    }

    logger.write_string(port)

    if usage == Write {
      logger.write_char('!')
    }

    first = false
  }

  logger.write_char('}')
}

pub fn AccessedPorts::new() -> AccessedPorts {
  AccessedPorts({})
}

pub fn AccessedPorts::set(self: AccessedPorts, port: String, usage: PortAccess) -> Unit {
  match self.0.get(port) {
    Some(existing) => {
      if existing == Write || usage == Write {
        self.0[port] = Write
      } else {
        self.0[port] = Read
      }
    }
    None => {
      self.0[port] = usage
    }
  }
}

pub fn AccessedPorts::register_access(self: AccessedPorts, port: String) -> Unit {
  self.set(port, Read)
}

pub fn AccessedPorts::register_write(self: AccessedPorts, port: String) -> Unit {
  self.set(port, Write)
}

pub fn AccessedPorts::contains(self: AccessedPorts, port: String) -> Bool {
  self.0.contains(port)
}

pub fn AccessedPorts::merge_inplace(self: AccessedPorts, other: AccessedPorts) -> Unit {
  for port, usage in other.0 {
    self.set(port, usage)
  }
}

pub fn AccessedPorts::is_written_to(self: AccessedPorts, port: String) -> Bool {
  self.0.get(port) is Some(Write)
}

pub fn AccessedPorts::is_read(self: AccessedPorts, port: String) -> Bool {
  self.0.get(port) is Some(Read)
}

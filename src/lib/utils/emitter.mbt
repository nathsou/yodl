
pub(all) struct Emitter {
  mut indent: Int
  builder: StringBuilder
}

pub fn Emitter::new() -> Emitter {
  { indent: 0, builder: StringBuilder::new() }
}

pub impl Show for Emitter with output(self, logger) {
  logger.write_string(self.builder.to_string())
}

pub fn[T: Show] Emitter::emit(self: Self, s: T) -> Unit {
  self.builder.write_string("  ".repeat(self.indent) + s.to_string() + "\n")
}

pub fn Emitter::write_indent(self: Self) -> Unit {
  self.builder.write_string("  ".repeat(self.indent))
}

pub fn[T: Show] Emitter::write(self: Self, s: T) -> Unit {
  self.builder.write_string(s.to_string())
}

pub fn[T: Show] Emitter::write_iter(
  self: Self,
  iter: Iter[T],
  prefix~: String,
  suffix~: String,
  sep~: String,
  trailing~: Bool = false,
  indent~: Bool = false
) -> Unit {
  self.write(prefix)

  if trailing {
    for x in iter {
      if indent {
        self.write_indent()
      }

      self.builder.write_object(x)
      self.write(sep)
    }
  } else {
    let mut first = true

    for x in iter {
      if first {
        first = false
      } else {
        self.write(sep)
      }

      if indent {
        self.write_indent()
      }

      self.builder.write_object(x)
    }
  }
  self.write(suffix)
}

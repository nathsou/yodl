
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

impl Logger for Emitter with write_string(self, s) {
  self.builder.write_string(s)
}

impl Logger for Emitter with write_char(self, c) {
  self.builder.write_char(c)
}

impl Logger for Emitter with write_substring(self, str, start, end) {
  self.write_string(substring(str, start~, end~))
}

pub fn[T: Show] emit(self: Emitter, s: T) -> Unit {
  self.builder.write_string("  ".repeat(self.indent) + s.to_string() + "\n")
}

pub fn write_indent(self: Emitter) -> Unit {
  self.builder.write_string("  ".repeat(self.indent))
}

pub fn[T: Show] write(self: Emitter, s: T) -> Unit {
  self.builder.write_string(s.to_string())
}

pub fn[T: Show] write_iter(
  self: Emitter,
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

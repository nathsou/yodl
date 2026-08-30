
pub suberror MemFileError {
  UnexpectedChar(Char)
  InvalidBase(Int)
  InvalidDigitForBase(digit~: Char, base~: Int)
  InconsistentWidth(expected~: Int, actual~: Int)
  Error(Error)
} derive(Debug)

pub fn[T: @utils.BinaryLike] parse_mem_file(content: String, base~: Int, start~: Int, end~: Int?) -> Array[T] raise MemFileError {
  let end = match end {
    Some(end) => end
    None => @int.MAX_VALUE
  }

  let width_factor = match base {
    2 => 1
    16 => 4
    _ => raise InvalidBase(base)
  }

  fn lex() -> Array[String] raise MemFileError {
    let values = []
    let mut char_idx = 0
    let mut found_value = false
    let mut value_index = 0
    let lexeme = StringBuilder()

    while char_idx < content.length() {
      let mut char = @utils.char_at(content, char_idx)
      
      while @utils.is_whitespace(char) {
        char_idx += 1
        if found_value {
          found_value = false

          let value = lexeme.to_string()

          if value_index >= start && value_index < end {
            values.push(value)
          }

          value_index += 1

          if value_index >= end {
            return values
          }

          lexeme.reset()
        }

        if char_idx >= content.length() {
          return values
        }

        char = @utils.char_at(content, char_idx)
      }

      match char {
        '0'..='9' | 'a'..='f' | 'A'..='F' => {
          if base == 2 {
            match char {
              '0' | '1' => ()
              _ => raise InvalidDigitForBase(digit=char, base~)
            }
          }

          char_idx += 1
          found_value = true
          lexeme.write_char(char)
        }
        '/' => {
          char_idx += 1

          if char_idx >= content.length() {
            break
          }

          if content.code_unit_at(char_idx) != '/' {
            raise UnexpectedChar('/')
          }

          while char_idx < content.length() {
            let char = content.code_unit_at(char_idx)

            if char == '\n' {
              break
            }

            char_idx += 1
          }
        }
        _ => raise UnexpectedChar(char)
      }
    }

    values
  }

  let values = lex()
  let bits = Array::new(capacity=(values.length() - start) * width_factor)
  let mut prev_width = None

  for i = values.length() - 1; i >= 0; i = i - 1 {
    let lexeme = values[i]
    let width = values[i].length() * width_factor

    match prev_width {
      Some(prev_width) => {
        if prev_width != width {
          raise InconsistentWidth(expected=prev_width, actual=width)
        }
      }
      None => {
        prev_width = Some(width)
      }
    }

    let value = parse_uint(lexeme, base~).to_uint()

    bits.push_iter(try @utils.bin_uint(value, width~) catch { err => raise Error(err) } noraise { bits => bits })
  }

  bits
}

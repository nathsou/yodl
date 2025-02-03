
pub type! MemFileError {
  IOError(Error)
  StrConvError(@strconv.StrConvError)
  UnexpectedChar(Char)
  InvalidBase(Int)
  InvalidDigitForBase(digit~: Char, base~: Int)
  InconsistentWidth(expected~: Int, actual~: Int)
} derive(Show)

pub fn parse_mem_file(path: String, base~: Int, start~: Int, end~: Int?) -> Bytes!MemFileError {
  let contents = match @fs.read_file_to_string?(path~) {
    Ok(contents) => contents
    Err(err) => raise IOError(err)
  }

  let end = match end {
    Some(end) => end
    None => @int.max_value
  }

  let width_factor = match base {
    2 => 1
    16 => 4
    _ => raise InvalidBase(base)
  };

  fn lex() -> Array[String]!MemFileError {
    let values = []
    let mut char_idx = 0
    let mut found_value = false
    let mut value_index = 0
    let lexeme = StringBuilder::new()

    while char_idx < contents.length() {
      let mut char = contents[char_idx]
      
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

        if char_idx >= contents.length() {
          return values
        }

        char = contents[char_idx]
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

          if char_idx >= contents.length() {
            break
          }

          if contents[char_idx] != '/' {
            raise UnexpectedChar('/')
          }

          while char_idx < contents.length() {
            let char = contents[char_idx]

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

  let values = lex!()
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

    if base == 2 {
      for char in lexeme {
        bits.push(char == '1')
      }
    } else {
      match @strconv.parse_int?(lexeme, base~) {
        Ok(value) => {
          bits.push_iter(@utils.bin(value, width~))
        }
        Err(err) => raise StrConvError(err)
      }
    }
  }

  @utils.bools_to_bytes(bits.iter())
}

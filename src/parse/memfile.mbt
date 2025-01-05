
pub type! MemFileError {
  IOError(Error)
  StrConvError(@strconv.StrConvError)
  UnexpectedChar(Char)
  InvalidBase(Int)
  InvalidDigitForBase(digit~: Char, base~: Int)
  InconsistentWidth(expected~: Int, actual~: Int)
  Unreachable(String)
} derive(Show)

pub fn parse_mem_file(path: String, base~: Int) -> Array[BinaryDigit]!MemFileError {
  let contents = match @fs.read_file_to_string?(path~) {
    Ok(contents) => contents
    Err(err) => raise IOError(err)
  }

  fn lex() -> Array[String]!MemFileError {
    let values = []
    let mut char_idx = 0
    let mut found_value = false
    let lexeme = StringBuilder::new()

    while char_idx < contents.length() {
      let mut char = contents[char_idx]
      
      while is_whitespace(char) {
        char_idx += 1
        if found_value {
          found_value = false
          values.push(lexeme.to_string())
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
  let bits = []
  let mut prev_width = None
  let width_factor = match base {
    2 => 1
    16 => 4
    _ => raise InvalidBase(base)
  };

  for i = values.length() - 1; i >= 0; i = i - 1 {
    let value = values[i]
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

    let value = match @strconv.parse_int?(value, base~) {
      Ok(value) => value
      Err(err) => raise StrConvError(err)
    }

    for bit in @utils.bin(value, width~) {
      bits.push(match bit {
        0 => BinaryDigit::Zero
        1 => BinaryDigit::One
        _ => raise Unreachable("unexpected bit value")
      })
    }
  }

  bits
}


pub enum FormatStringPart {
  StringPart(String)
  BinaryPlaceholder
  AsciiPlaceholder
  DecimalPlaceholder
  HexadecimalPlaceholder
  EscapedChar(Char)
} derive (Show, Eq)

pub struct FormatString {
  parts: Array[FormatStringPart]
} derive (Eq)

pub fn FormatString::parse(fmt: String) -> FormatString raise {
  let parts: Array[FormatStringPart] = []

  let mut index = 0

  while index < fmt.length() {
    if fmt.get_char(index) is Some(char) {
      match char {
        '%' => {
          index += 1

          match fmt.get_char(index) {
            Some('b') => {
              parts.push(BinaryPlaceholder)
              index += 1
            }
            Some('c') => {
              parts.push(AsciiPlaceholder)
              index += 1
            }
            Some('d') => {
              parts.push(DecimalPlaceholder)
              index += 1
            }
            Some('x') => {
              parts.push(HexadecimalPlaceholder)
              index += 1
            }
            Some('%') => {
              parts.push(EscapedChar('%'))
              index += 1
            }
            c => {
              raise Failure::Failure("Invalid format string: unexpected character after '%': \{c}")
            }
          }
        }
        '\n' | '\r' | '\t' | '\'' | '\"' => {
          parts.push(EscapedChar(char))
          index += 1
        }
        c => {
          index += 1
          let part = StringBuilder::new()
          part.write_char(c)

          while index < fmt.length() {
            match fmt.get_char(index) {
              Some(nc) if nc != '%' && nc.is_ascii() => {
                part.write_char(nc)
                index += 1
              }
              _ => {
                break
              }
            }
          }

          parts.push(StringPart(part.to_string()))
        }
      }
    } else {
      break
    }
  }

  { parts, }
}

///|
test "FormatString::parse" {
  let fmt = "Value: %d, Hex: %x, Char: %c, Percent: %%\n\t {{hello}}"
  let parsed = FormatString::parse(fmt)
  assert_eq(parsed.parts.length(), 11)
  assert_eq(parsed.parts[0], StringPart("Value: "))
  assert_eq(parsed.parts[1], DecimalPlaceholder)
  assert_eq(parsed.parts[2], StringPart(", Hex: "))
  assert_eq(parsed.parts[3], HexadecimalPlaceholder)
  assert_eq(parsed.parts[4], StringPart(", Char: "))
  assert_eq(parsed.parts[5], AsciiPlaceholder)
  assert_eq(parsed.parts[6], StringPart(", Percent: "))
  assert_eq(parsed.parts[7], EscapedChar('%'))
  assert_eq(parsed.parts[8], EscapedChar('\n'))
  assert_eq(parsed.parts[9], EscapedChar('\t'))
  assert_eq(parsed.parts[10], StringPart(" {{hello}}"))
}


enum Command {
  WriteRTLIL(path~: String?)
  WriteVerilog(path~: String?)
  WriteSource
  WriteMono(path~: String?)
  WriteTyped
  WriteYIR
  WriteSimplified(path~: String?)
  Flatten
} derive(Show)

struct ParsedCommand {
  name: String
  args: Array[String]
} derive(Show)

type! CommandParserError {
  ExpectedIdentifier(token~: CommandToken)
  ExpectedLiteral(token~: CommandToken)
  InvalidCommandArgs(name~: String, args~: Array[String])
  UnknownCommand(name~: String)
  UnexepectedChar(char~: Char)
} derive(Show)

enum CommandToken {
  Literal(String)
  Semicolon
  EOF
} derive(Eq, Show)

fn is_valid_literal_char(char: Char) -> Bool {
  match char {
    ';' => false
    _ => not(@utils.is_whitespace(char))
  }
}

fn lex_commands(source: String) -> Array[CommandToken]!CommandParserError {
  let tokens = []
  let mut idx = 0

  while idx < source.length() {
    let mut char = source[idx]

    while idx < source.length() && @utils.is_whitespace(char) {
      idx += 1
      char = source[idx]
    }

    if idx >= source.length() {
      break
    }

    match char {
      ';' => {
        tokens.push(Semicolon)
        idx += 1
      }
      _ => {
        if is_valid_literal_char(char) {
          let literal = StringBuilder::new()

          while idx < source.length() && is_valid_literal_char(source[idx]) {
            literal.write_char(source[idx])
            idx += 1
          }

          tokens.push(Literal(literal.to_string()))
        } else {
          raise UnexepectedChar(char~)
        }
      }
    }
  }

  tokens
}

fn parse_commands(source: String) -> Array[Command]!CommandParserError {
  let tokens = lex_commands!(source)
  let mut idx = 0

  fn peek() -> CommandToken {
    if idx < tokens.length() {
      tokens[idx]
    } else {
      EOF
    }
  }

  fn matches(token: CommandToken )-> Bool {
    if idx < tokens.length() {
      tokens[idx] == token
    } else {
      false
    }
  }

  fn parse_arg() -> String!CommandParserError {
    let token = peek()

    match token {
      Literal(lit) => {
        idx += 1
        lit
      }
      _ => raise ExpectedLiteral(token~)
    }
  }

  fn parse_cmd() -> ParsedCommand!CommandParserError {
    let token = peek()

    match token {
      Literal(name) => {
        idx += 1

        let args = []

        while idx < tokens.length() && not(matches(Semicolon)) {
          args.push(parse_arg!())
        }

        { name, args }
      }
      _ => raise ExpectedIdentifier(token~)
    }
  }

  let cmds = []

  while idx < tokens.length() {
    cmds.push(parse_cmd!())

    if matches(Semicolon) {
      idx += 1
    }
  }

  let commands = Array::new(capacity=cmds.length())

  for cmd in cmds {
    let command = match cmd.name {
      "write_source" => {
        match cmd.args.length() {
          0 => ()
          _ => raise InvalidCommandArgs(name=cmd.name, args=cmd.args)
        }

        WriteSource
      }
      "write_mono" => {
        let path = match cmd.args {
          [] => None
          [path] => Some(path)
          _ => raise InvalidCommandArgs(name=cmd.name, args=cmd.args)
        }

        WriteMono(path~)
      }
      "write_typed" => {
        match cmd.args.length() {
          0 => ()
          _ => raise InvalidCommandArgs(name=cmd.name, args=cmd.args)
        }

        WriteTyped
      }
      "write_simplified" => {
        let path = match cmd.args {
          [] => None
          [path] => Some(path)
          _ => raise InvalidCommandArgs(name=cmd.name, args=cmd.args)
        }

        WriteSimplified(path~)
      }
      "write_rtlil" => {
        let path = match cmd.args {
          [] => None
          [path] => Some(path)
          _ => raise InvalidCommandArgs(name=cmd.name, args=cmd.args)
        }

        WriteRTLIL(path~)
      }
      "write_verilog" => {
        let path = match cmd.args {
          [] => None
          [path] => Some(path)
          _ => raise InvalidCommandArgs(name=cmd.name, args=cmd.args)
        }

        WriteVerilog(path~)
      }
      "write_yir" => {
        match cmd.args.length() {
          0 => ()
          _ => raise InvalidCommandArgs(name=cmd.name, args=cmd.args)
        }

        WriteYIR
      }
      "flatten" => {
        match cmd.args.length() {
          0 => ()
          _ => raise InvalidCommandArgs(name=cmd.name, args=cmd.args)
        }

        Flatten
      }
      _ => raise UnknownCommand(name=cmd.name)
    }

    commands.push(command)
  }

  commands
}

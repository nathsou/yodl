
pub(all) enum Command {
  WriteSource(path~: String?)
  WriteMono(path~: String?)
  WriteTyped(path~: String?)
  WriteSimplified(path~: String?)
  WriteFIRRTL(path~: String?, passes~: Array[&@firrtl.FIRRTLPass])
  WriteRTLIL(path~: String?)
}

/// Passes applied by `write_firrtl`: collapses elaborator proxy wires to
/// produce clean, readable FIRRTL without expanding or lowering anything.
pub fn firrtl_passes() -> Array[&@firrtl.FIRRTLPass] {
  [@firrtl.ExpandConnectsPass::new(), @firrtl.CollapseWireAliasesPass::new()]
}

fn low_firrtl_passes() -> Array[&@firrtl.FIRRTLPass] {
  [
    @firrtl.ExpandConnectsPass::new(),
    @firrtl.ExpandWhensPass::new(),
    @firrtl.CollapseWireAliasesPass::new(),
    @firrtl.LowerAggregateTypesPass::new(split_memories=false),
  ]
}

priv struct ParsedCommand {
  name: String
  args: Array[String]
}

suberror CommandParserError {
  ExpectedIdentifier(token~: CommandToken)
  ExpectedLiteral(token~: CommandToken)
  InvalidCommandArgs(name~: String, args~: Array[String])
  UnknownCommand(name~: String)
  UnexepectedChar(char~: Char)
} derive(Debug)

priv enum CommandToken {
  Literal(String)
  Semicolon
  EOF
} derive(Eq, Debug)

fn is_valid_literal_char(char: Char) -> Bool {
  match char {
    ';' => false
    _ => !@utils.is_whitespace(char)
  }
}

fn lex_commands(source: String) -> Array[CommandToken] raise CommandParserError {
  let tokens = []
  let mut idx = 0

  while idx < source.length() {
    let mut char = @utils.char_at(source, idx)

    while idx < source.length() && @utils.is_whitespace(char) {
      idx += 1
      char = @utils.char_at(source, idx)
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

          while idx < source.length() && is_valid_literal_char(@utils.char_at(source, idx)) {
            literal.write_char(@utils.char_at(source, idx))
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

pub fn parse_commands(source: String) -> Array[Command] raise CommandParserError {
  let tokens = lex_commands(source)
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

  fn parse_arg() -> String raise CommandParserError {
    let token = peek()

    match token {
      Literal(lit) => {
        idx += 1
        lit
      }
      _ => raise ExpectedLiteral(token~)
    }
  }

  fn parse_cmd() -> ParsedCommand raise CommandParserError {
    let token = peek()

    match token {
      Literal(name) => {
        idx += 1

        let args = []

        while idx < tokens.length() && !matches(Semicolon) {
          args.push(parse_arg())
        }

        { name, args }
      }
      _ => raise ExpectedIdentifier(token~)
    }
  }

  let cmds = []

  while idx < tokens.length() {
    cmds.push(parse_cmd())

    if matches(Semicolon) {
      idx += 1
    }
  }

  let commands = Array::new(capacity=cmds.length())

  for cmd in cmds {
    let path = match cmd.args {
      [] => None
      [path] => Some(path)
      _ => raise InvalidCommandArgs(name=cmd.name, args=cmd.args)
    }

    let command = match cmd.name {
      "write_source" => WriteSource(path~)
      "write_mono" => WriteMono(path~)
      "write_typed" => WriteTyped(path~)
      "write_simplified" => WriteSimplified(path~)
      "write_firrtl" | "write_fir" => WriteFIRRTL(path~, passes=firrtl_passes())
      "write_low_firrtl" | "write_lofir" => WriteFIRRTL(path~, passes=low_firrtl_passes())
      "write_rtlil" => WriteRTLIL(path~)
      _ => raise UnknownCommand(name=cmd.name)
    }

    commands.push(command)
  }

  commands
}

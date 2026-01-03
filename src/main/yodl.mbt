const VERSION: String = "0.2.1"

fn main {
  let fs: @utils.FileSystem = {
    path_exists: @fs.path_exists,
    create_dir: path => @fs.create_dir(path),
    write_string_to_file: (path, content) => @fs.write_string_to_file(path, content),
    read_dir: path => @fs.read_dir(path),
    is_dir: path => @fs.is_dir(path),
    read_file_to_string: path => @fs.read_file_to_string(path),
  }
  
  match @sys.get_cli_args() {
    [_, path] => {
      try @driver.run(path~, commands=[@driver.WriteFIRRTL(path=Some(path.replace(old=".yodl", new=".fir")), passes=[])], fs~) catch {
        Failure(error) => {
          println(error)
          @sys.exit(1)
        }
        error => {
          println(error)
          @sys.exit(1)
        }
      }
    }
    [_, path, cmds] => {
      try @driver.parse_commands(cmds) catch {
        error => {
          println(error)
          @sys.exit(1)
        }
      } noraise {
        commands => {
          try @driver.run(path~, commands~, fs~) catch {
            error => {
              println(error)
              @sys.exit(1)
            }
          }
        }
      }
    }
    _ => {
      println("Yodl - Yet another hardware description language v\{VERSION}")
      println("Usage: yodl <file> [commands]")
      println("\nCommands are separated by semicolons ';'. Each command can optionally take a file path argument.")
      println("Available commands:")
      println("  write_source [path]     - Write the source code after parsing.")
      println("  write_mono [path]       - Write the monomorphized code.")
      println("  write_typed [path]      - Write the typed code.")
      println("  write_simplified [path] - Write the simplified code.")
      println("  write_firrtl [path]     - Write the FIRRTL output (alias: write_fir).")
      println("  write_low_firrtl [path] - Write the low FIRRTL output (alias: write_lofir).")
      println("  write_rtlil [path]      - Write the RTLIL output.")
      println("\nExample: yodl my_design.yodl \"write_firrtl my_design.fir; write_typed my_design.typed.txt\"")
    }
  }
}
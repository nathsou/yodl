fn main {
  let fs: @utils.FileSystem = {
    path_exists: @fs.path_exists,
    create_dir: fn (path) {
      if (try? @fs.create_dir(path)) is Err(err) {
        raise Failure(err.to_string())
      }
    },
    write_string_to_file: fn (path, content) {
      if (try? @fs.write_string_to_file(path, content)) is Err(err) {
        raise Failure(err.to_string())
      }
    },
    read_dir: fn(path) {
      match (try? @fs.read_dir(path)) {
        Err(err) => raise Failure(err.to_string())
        Ok(files) => files
      }
    },
    is_dir: fn (path) {
      match (try? @fs.is_dir(path)) {
        Err(err) => raise Failure(err.to_string())
        Ok(is_dir) => is_dir
      }
    },
    read_file_to_string: fn(path) {
      match (try? @fs.read_file_to_string(path)) {
        Err(err) => raise Failure(err.to_string())
        Ok(content) => content
      }
    },
  }
  
  match @env.args() {
    [_, path] => {
      match (try? @driver.run(path~, commands=[@driver.WriteFIRRTL(path=Some(path.replace(old=".yodl", new=".fir")))], fs~)) {
        Ok(_) => ()
        Err(Failure(error)) => {
          println(error)
          @sys.exit(1)
        }
      }
    }
    [_, path, cmds] => {
      match (try? @driver.parse_commands(cmds)) {
        Ok(commands) => {
          match (try? @driver.run(path~, commands~, fs~)) {
            Ok(_) => ()
            Err(Failure(error)) => {
              println(error)
              @sys.exit(1)
            }
          }
        }
        Err(error) => {
          println(error)
          @sys.exit(1)
        }
      }
    }
    _ => {
      println("Usage: yodl <file> [commands]")
      println("\nCommands are separated by semicolons ';'. Each command can optionally take a file path argument.")
      println("Available commands:")
      println("  write_source [path]     - Write the source code after parsing.")
      println("  write_mono [path]       - Write the monomorphized code.")
      println("  write_typed [path]      - Write the typed code.")
      println("  write_simplified [path] - Write the simplified code.")
      println("  write_firrtl [path]     - Write the FIRRTL output (alias: write_fir).")
      println("\nExample: yodl my_design.yodl \"write_firrtl my_design.fir; write_typed my_design.typed.txt\"")
    }
  }
}

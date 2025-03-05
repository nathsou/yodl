
fn main {
  let fs: @utils.FileSystem = {
    path_exists: @fs.path_exists,
    create_dir: fn (path) {
      if @fs.create_dir?(path) is Err(err) {
        raise Failure(err.to_string())
      }
    },
    write_string_to_file: fn (path, content) {
      if @fs.write_string_to_file?(path, content) is Err(err) {
        raise Failure(err.to_string())
      }
    },
    read_dir: fn(path) {
      match @fs.read_dir?(path) {
        Err(err) => raise Failure(err.to_string())
        Ok(files) => files
      }
    },
    is_dir: fn (path) {
      match @fs.is_dir?(path) {
        Err(err) => raise Failure(err.to_string())
        Ok(is_dir) => is_dir
      }
    },
    read_file_to_string: fn(path) {
      match @fs.read_file_to_string?(path) {
        Err(err) => raise Failure(err.to_string())
        Ok(content) => content
      }
    },
  }

  match @env.args() {
    [_, _, path] => {
      match @driver.run?(path~, commands=[@driver.WriteFIRRTL(path=Some(path.replace(old=".yodl", new=".fir")))], fs~) {
        Ok(_) => ()
        Err(error) => {
          println(error)
          @sys.exit(1)
        }
      }
    }
    [_, _, path, cmds] => {
      match @driver.parse_commands?(cmds) {
        Ok(commands) => {
          match @driver.run?(path~, commands~, fs~) {
            Ok(_) => ()
            Err(error) => {
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
    }
  }
}

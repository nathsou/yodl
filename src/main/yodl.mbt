
fn main {
  let fs: @utils.FileSystem = {
    path_exists: @fs.path_exists,
    create_dir: @fs.create_dir,
    write_string_to_file: fn (path, content) {
      @fs.write_string_to_file!(path, content)
    },
    read_dir: @fs.read_dir,
    is_dir: @fs.is_dir,
    read_file_to_string: fn(path) {
      @fs.read_file_to_string!(path)
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


fn main {
  let fs: @utils.FileSystem = {
    path_exists: @fs.path_exists,
    create_dir: path => @fs.create_dir(path),
    write_string_to_file: (path, content) => @fs.write_string_to_file(path, content),
    read_dir: path => @fs.read_dir(path),
    is_dir: path => @fs.is_dir(path),
    read_file_to_string: path => @fs.read_file_to_string(path),
  }

  let ext: @utils.Externals = {
    fs,
    println: str => println(str),
    get_args: @sys.get_cli_args,
    exit: code => @sys.exit(code.reinterpret_as_int()),
  }

  @driver.cli(ext)
}

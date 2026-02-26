
pub fn start() -> Unit {
  let fs : @utils.FileSystem = {
    path_exists: path => @fs.exists(path),
    create_dir: path => {
      @fs.mkdir(path) catch {
        e => {
          try! @stdio.stderr.write_sync(
            "Failed to create directory \{path}: \{e}\n",
          )
          @wasi.proc_exit(1)
        }
      }
    },
    write_string_to_file: (path, content) => {
      @fs.write_file_sync(path, content) catch {
        e => {
          try! @stdio.stderr.write_sync(
            "Failed to write to file \{path}: \{e}\n",
          )
          @wasi.proc_exit(1)
        }
      }
    },
    read_dir: path => {
      @fs.readdir(path, include_hidden=true, include_special=true, sort=true) catch {
        e => {
          try! @stdio.stderr.write_sync(
            "Failed to read directory \{path}: \{e}\n",
          )
          @wasi.proc_exit(1)
        }
      }
    },
    is_dir: path => {
      let kind = @fs.kind(path) catch {
        e => {
          try! @stdio.stderr.write_sync(
            "Failed to get kind of path \{path}: \{e}\n",
          )
          @wasi.proc_exit(1)
        }
      }
      kind == Directory
    },
    read_file_to_string: path => {
      let bytes = @fs.read_file_sync(path) catch {
        e => {
          try! @stdio.stderr.write_sync("Failed to read file \{path}: \{e}\n")
          @wasi.proc_exit(1)
        }
      }

      bytes.text()
    },
  }

  let ext : @utils.Externals = {
    fs,
    println: str => {
      try! @stdio.stdout.write_sync(str)
      try! @stdio.stdout.write_sync("\n")
    },
    get_args: () => {
      @wasi.args_get() catch {
        e => {
          try! @stdio.stderr.write_sync(
            "Failed to get command line arguments: \{e}\n",
          )
          @wasi.proc_exit(1)
        }
      }
    },
    exit: code => @wasi.proc_exit(code),
  }

  @driver.cli(ext)
}

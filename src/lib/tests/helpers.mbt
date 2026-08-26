
let fixture_dir : String = "src/lib/tests/fixtures"

let snapshot_dir : String = "src/lib/tests/snapshots"

/// Creates an in-memory `FileSystem` backed by a map of path → content.
///
/// Keys should be relative paths (e.g., `"fixture.yodl"`). Only exact file
/// paths are tracked — `path_exists` and `is_dir` do not synthesise directory
/// entries. `read_dir` returns the filenames whose directory component matches
/// the requested path.
pub fn make_vfs(files: Map[String, String]) -> @utils.FileSystem {
  {
    path_exists: fn(p) { files.contains(p) },
    read_file_to_string: fn(p) raise {
      match files.get(p) {
        Some(content) => content
        None => raise Failure::Failure("File not found: '\{p}'")
      }
    },
    read_dir: fn(dir) raise {
      let entries : Array[String] = []
      for path, _ in files {
        if @utils.dir_name(path) == dir {
          entries.push(@utils.file_name(path))
        }
      }
      entries
    },
    is_dir: fn(_) raise { false },
    create_dir: fn(_) raise { () },
    write_string_to_file: fn(_, _) raise { () },
  }
}

/// Compiles `source` as a top-level yodl module and returns the output of the
/// given `cmd_str` (e.g., `"write_source"`, `"write_firrtl"`,
/// `"write_low_firrtl"`).
///
/// Output is captured from the driver's `println` callback, which is invoked
/// when the command's output path is `None` (i.e., no file path argument).
pub fn compile_stage(source: String, cmd_str: String) -> String raise {
  let output : Ref[String] = { val: "" }
  let files : Map[String, String] = Map([])
  files["fixture.yodl"] = source
  let ext : @utils.Externals = {
    fs: make_vfs(files),
    println: fn(s) { output.val = s },
    get_args: fn() { [] },
    exit: fn(_) { () },
  }
  let commands = @driver.parse_commands(cmd_str)
  @driver.run(path="fixture.yodl", commands~, ext~)
  output.val
}

pub fn compile_error(source: String, cmd_str~: String = "write_low_firrtl") -> String {
  try {
    let _ = compile_stage(source, cmd_str)
    fail("Expected compilation to fail")
  } catch {
    Failure::Failure(message) => message
    err => err.to_string()
  }
}

/// Parses a snapshot filename of the form `<fixture>.<stage>.snap` into
/// `(fixture, stage)`. Returns `None` if the name doesn't match the pattern.
fn parse_snap_name(filename: String) -> (String, String)? {
  let snap_suffix = ".snap"
  if !filename.has_suffix(snap_suffix) {
    return None
  }
  let stem = @utils.substring(filename, start=0, end=filename.length() - snap_suffix.length())
  // find the first dot, which separates fixture name from stage name
  let mut dot = -1
  for i in 0..<stem.length() {
    if @utils.char_at(stem, i) == '.' {
      dot = i
      break
    }
  }
  if dot == -1 {
    return None
  }
  let fixture = @utils.substring(stem, start=0, end=dot)
  let stage = @utils.substring(stem, start=dot + 1)
  Some((fixture, stage))
}

/// Checks (or updates) the snapshot for the given fixture and compiler stage.
///
/// Reads fixture source from `src/lib/tests/fixtures/<fixture>.yodl`.
/// Compares actual compiler output against `src/lib/tests/snapshots/<fixture>.<stage>.snap`.
///
/// Snapshots are only written when `UPDATE_SNAPSHOTS` is set in the environment.
/// A missing snapshot file is a test failure — run with `UPDATE_SNAPSHOTS=1` to
/// generate it.
pub fn check_snapshot(fixture: String, stage: String) -> Unit raise {
  let source = @fs.read_file_to_string("\{fixture_dir}/\{fixture}.yodl")
  let actual = compile_stage(source, stage)
  let snap_path = "\{snapshot_dir}/\{fixture}.\{stage}.snap"
  if @sys.get_env_var("UPDATE_SNAPSHOTS") != None {
    if !@fs.path_exists(snapshot_dir) {
      @fs.create_dir(snapshot_dir)
    }
    @fs.write_string_to_file(snap_path, actual)
  } else if !@fs.path_exists(snap_path) {
    fail(
      "Missing snapshot: \{snap_path}\nRun with UPDATE_SNAPSHOTS=1 to generate it.",
    )
  } else {
    let expected = @fs.read_file_to_string(snap_path)
    if actual != expected {
      fail(
        "Snapshot mismatch: \{fixture}/\{stage}\n--- expected ---\n\{expected}\n--- actual ---\n\{actual}",
      )
    }
  }
}

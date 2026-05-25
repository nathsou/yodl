// Snapshot tests — dynamically discovered from the snapshots/ directory.
//
// Each `.snap` file in `src/lib/tests/snapshots/` encodes a (fixture, stage)
// pair via its name: `<fixture>.<stage>.snap`. The test below iterates all
// such files and verifies that the compiler still produces the same output.
//
// To add a new snapshot test:
//   1. Add (or reuse) a fixture in src/lib/tests/fixtures/<name>.yodl
//   2. Create a stub: touch src/lib/tests/snapshots/<name>.<stage>.snap
//   3. Run `UPDATE_SNAPSHOTS=1 moon test src/lib/tests`  ← populates the stub
//
// To regenerate snapshots after an intentional compiler change:
//   UPDATE_SNAPSHOTS=1 moon test src/lib/tests

test "snapshots" {
  let snap_files = @fs.read_dir(snapshot_dir)
  snap_files.sort()
  for snap_file in snap_files {
    match parse_snap_name(snap_file) {
      Some((fixture, stage)) => check_snapshot(fixture, stage)
      None => ()
    }
  }
}

test "tour lessons compile through every playground stage" {
  let stages = [
    "write_source", "write_mono", "write_typed", "write_simplified",
    "write_firrtl", "write_low_firrtl", "write_rtlil",
  ]
  let lessons = @fs.read_dir("tour").filter(name => name.has_suffix(".yodl"))
  assert_true(lessons.length() > 0)
  for lesson in lessons {
    let source = @fs.read_file_to_string("tour/\{lesson}")
    for stage in stages {
      let output = try compile_stage(source, stage) catch {
        err => fail("Tour lesson \{lesson} failed at \{stage}: \{err}")
      }
      assert_true(output.length() > 0)
    }
  }
}

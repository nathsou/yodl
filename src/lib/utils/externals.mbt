pub(all) struct Externals {
  fs: FileSystem
  println: (String) -> Unit
  get_args: () -> Array[String]
  exit: (UInt) -> Unit
}

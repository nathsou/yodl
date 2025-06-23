
pub(all) struct FileSystem {
  path_exists: (String) -> Bool
  create_dir: (String) -> Unit raise Failure
  write_string_to_file: (String, String) -> Unit raise Failure
  read_dir: (String) -> Array[String] raise Failure
  is_dir: (String) -> Bool raise Failure
  read_file_to_string: (String) -> String raise Failure
}

// TODO: Support Windows paths

pub fn file_name(path: String) -> String {
    path.split("/").last().or(path).to_string()
}

pub fn file_extension(path: String) -> String? {
    match path.rev_find(".") {
      None => None
      Some(i) => Some(path.substring(start=i))
    }
}

pub fn without_extension(path: String) -> String {
    match path.rev_find(".") {
      None => path
      Some(i) => path.substring(start=0, end=i)
    }
}

pub fn dir_name(path: String) -> String {
    match path.rev_find("/") {
      None => "."
      Some(i) => path.substring(start=0, end=i)
    }
}

pub fn join_paths(path1: String, path2: String) -> String {
    if path1.has_suffix("/") {
        path1 + path2
    } else {
        path1 + "/" + path2
    }
}

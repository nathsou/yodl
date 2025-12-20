
pub(all) struct FileSystem {
  path_exists: (String) -> Bool
  create_dir: (String) -> Unit raise
  write_string_to_file: (String, String) -> Unit raise
  read_dir: (String) -> Array[String] raise
  is_dir: (String) -> Bool raise
  read_file_to_string: (String) -> String raise
}

// TODO: Support Windows paths

pub fn file_name(path: String) -> String {
    path.split("/").last().unwrap_or(path).to_string()
}

pub fn file_extension(path: String) -> String? {
    match path.rev_find(".") {
      None => None
      Some(i) => Some(substring(path, start=i))
    }
}

pub fn without_extension(path: String) -> String {
    match path.rev_find(".") {
      None => path
      Some(i) => substring(path, start=0, end=i)
    }
}

pub fn dir_name(path: String) -> String {
    match path.rev_find("/") {
      None => "."
      Some(i) => substring(path, start=0, end=i)
    }
}

pub fn join_paths(path1: String, path2: String) -> String {
    if path1.has_suffix("/") {
        path1 + path2
    } else {
        path1 + "/" + path2
    }
}

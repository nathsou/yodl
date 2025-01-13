// TODO: Support Windows paths

pub fn file_name(path: String) -> String {
    path.split("/").last().or(path)
}

pub fn file_extension(path: String) -> String? {
    match path.last_index_of(".") {
      -1 => None
      i => Some(path.substring(start=i))
    }
}

pub fn without_extension(path: String) -> String {
    match path.last_index_of(".") {
      -1 => path
      i => path.substring(start=0, end=i)
    }
}

pub fn dir_name(path: String) -> String {
    match path.last_index_of("/") {
      -1 => "."
      i => path.substring(start=0, end=i)
    }
}

pub fn join_paths(path1: String, path2: String) -> String {
    if path1.ends_with("/") {
        path1 + path2
    } else {
        path1 + "/" + path2
    }
}


pub struct Resolver {
  resolved_packages: Map[String, @parse.PackageDecl]
  available_packages: Map[String, String]
  imports: Set[String]
  fs: @utils.FileSystem
}

pub suberror ResolutionError {
  PackageNotFound(name~: String)
  IOError(Error)
  LexerError(Error)
  ParseError(Error)
  CouldNotExtractPackageName(String)
  PackageNameConflict(name~: String, path1~: String, path2~: String)
  MultiLevelImportNotSupportedYet(packages~: Array[String])
} derive(Debug)

pub impl Show for ResolutionError with output(self, logger) {
  match self {
    PackageNotFound(name~) => logger.write_string("Package '\{name}' not found")
    IOError(err) => logger.write_string("IO error: \{err}")
    LexerError(err) => logger.write_string("Lexer error: \{err}")
    ParseError(err) => logger.write_string("Parse error: \{err}")
    CouldNotExtractPackageName(path) => logger.write_string("Could not extract package name from '\{path}'")
    PackageNameConflict(name~, path1~, path2~) => logger.write_string("Package name conflict for '\{name}': '\{path1}' and '\{path2}'")
    MultiLevelImportNotSupportedYet(packages~) => {
      let pkgs = packages.join(", ")
      logger.write_string("Multi-level imports are not yet supported: [\{pkgs}]")
    }
  }
}

pub fn Resolver::new(packages_dir: String, fs~: @utils.FileSystem) -> Resolver raise ResolutionError {
  {
    resolved_packages: {},
    available_packages: collect_packages(packages_dir, fs~),
    imports: Set([]),
    fs,
  }
}

fn extract_package_name_from_path(path: String) -> String raise ResolutionError {
  let name = @utils.file_name(path)

  if name.has_suffix(".yodl") {
    name.replace(old=".yodl", new="")
  } else {
    raise CouldNotExtractPackageName(path)
  }
}

fn collect_packages(dir: String, fs~: @utils.FileSystem, acc~: Map[String, String] = {}) -> Map[String, String] raise ResolutionError {
  let entries = try (fs.read_dir)(dir) catch {
    error => raise IOError(error)
  } noraise {
    entries => entries
  }

  for entry in entries {
    let path = @utils.join_paths(dir, entry)

    try (fs.is_dir)(path) catch {
      error => raise IOError(error)
    } noraise {
      true => {
        let _ = collect_packages(path, fs~, acc~)
      }
      false => {
        if entry.has_suffix(".yodl") {
          let name = extract_package_name_from_path(entry)
          if acc.contains(name) {
            raise PackageNameConflict(name~, path1=acc.get(name).unwrap(), path2=path)
          }
          
          acc[name] = path
        }
      }
    }
  }

  acc
}

let builtin_decls: Array[@parse.Decl] = {
  let source =
    #|const true = 1'b1
    #|const false = 1'b0
    #|
    #|@internal
    #|declare module Reg<T: Type>(
    #|    clk: clock,
    #|    d: T,
    #|    en?: bool,
    #|    rst?: bool,
    #|) -> (
    #|    q: T,
    #|)
    #|
    #|@internal
    #|declare module RegAsyncReset<T: Type>(
    #|    clk: clock,
    #|    d: T,
    #|    en?: bool,
    #|    rst?: bool,
    #|) -> (
    #|    q: T,
    #|)
    #|
    #|@internal
    #|declare module Memory<
    #|  T: Type,
    #|  Depth: Nat,
    #|  ReadPorts: Nat,
    #|  WritePorts: Nat,
    #|  ReadLatency: Nat,
    #|  WriteLatency: Nat,
    #| >(
    #|    read: (clk: clock, en: bool, addr: uint<clog2!(Depth)>)[ReadPorts],
    #|    write: (clk: clock, en: bool, addr: uint<clog2!(Depth)>, data: T, mask: MemoryMask<T>)[WritePorts],
    #|) -> (
    #|    q: T[ReadPorts],
    #|)
  
  let lexer = @parse.Lexer::new(source, file="builtin.yodl", file_content=source)
  let tokens = try lexer.lex() catch {
    error => @utils.fail("Error lexing builtin declarations: \{error}")
  } noraise {
    tokens => tokens
  }
  
  let parser = @parse.Parser::new(tokens, file="builtin.yodl", file_content=source)

  try parser.parse() catch {
    error => @utils.fail("Error parsing builtin declarations: \{error}")
  } noraise {
    decls => decls
  }
}

pub fn Resolver::resolve(self: Self, path~: String, is_top_package~: Bool) -> @parse.PackageDecl raise ResolutionError {
  match self.resolved_packages.get(path) {
    Some(pkg) => return pkg
    None => ()
  }

  let source = try (self.fs.read_file_to_string)(path) catch {
    error => raise IOError(error)
  } noraise {
    source => source
  }

  let tokens = try @parse.Lexer::new(source, file=path, file_content=source).lex() catch {
    error => raise LexerError(error)
  } noraise {
    tokens => tokens
  }

  let parser = @parse.Parser::new(tokens, file=path, file_content=source)

  let decls = try parser.parse() catch {
    error => raise ParseError(error)
  } noraise {
    decls => {
      let resolved_decl = Array::new(capacity=decls.length())

      for decl in decls {
        match self.resolve_decl(decl) {
          Some(decl) => resolved_decl.push(decl)
          None => ()
        }
      }

      resolved_decl 
    }
  }

  let pkg_name = if is_top_package {
    "Main"
  } else {
    extract_package_name_from_path(path)
  }

  let pkg: @parse.PackageDecl = {
    name: pkg_name,
    body: if is_top_package {
        let imports = self.imports.iter().map(fn(p) {
          @parse.Decl::Package(self.resolved_packages.get(p).unwrap())
        }).collect()

        builtin_decls + imports + decls
      } else {
        decls
      },
    span: parser.span(0),
  }

  if !is_top_package {
    self.resolved_packages[path] = pkg
  }

  pkg
}

pub fn Resolver::resolve_decl(self: Self, decl: @parse.Decl) -> @parse.Decl? raise ResolutionError {
  match decl {
    Import({ packages, span: _ }) => {
      let pkg = match packages {
        [pkg] => pkg
        _ => raise MultiLevelImportNotSupportedYet(packages~)
      }

      let path = match self.available_packages.get(pkg) {
        Some(path) => path
        None => raise PackageNotFound(name=pkg)
      }

      let _ = self.resolve(path~, is_top_package=false)
      self.imports.add(path)
      
      None
    }
    Package(pkg) => {
      let resolved_body = Array::new(capacity=pkg.body.length())

      for decl in pkg.body {
        match self.resolve_decl(decl) {
          Some(decl) => resolved_body.push(decl)
          None => ()
        }
      }

      Some(@parse.Decl::Package({ name: pkg.name, body: resolved_body, span: pkg.span }))
    }
    decl => Some(decl)
  }
}


pub struct Resolver {
  resolved_packages: Map[String, @parse.PackageDecl]
  available_packages: Map[String, String]
  imports: Set[String]
}

pub type! ResolutionError {
  PackageNotFound(name~: String)
  IOError(Error)
  LexerError(Error)
  ParseError(Error)
  CouldNotExtractPackageName(String)
  PackageNameConflict(name~: String, path1~: String, path2~: String)
  MultiLevelImportNotSupportedYet(packages~: Array[String])
} derive(Show)

pub fn Resolver::new(packages_dir: String) -> Resolver!ResolutionError {
  { resolved_packages: {}, available_packages: collect_packages!(packages_dir), imports: Set::new() }
}

fn extract_package_name_from_path(path: String) -> String!ResolutionError {
  let name = @utils.file_name(path)

  if name.ends_with(".yodl") {
    name.replace(old=".yodl", new="")
  } else {
    raise CouldNotExtractPackageName(path)
  }
}

fn collect_packages(dir: String, acc~: Map[String, String] = {}) -> Map[String, String]!ResolutionError {
  let entries = match @fs.read_dir?(path=dir) {
    Ok(entries) => entries
    Err(error) => raise IOError(error)
  }

  for entry in entries {
    let path = @utils.join_paths(dir, entry)

    match @fs.is_dir?(path~) {
      Ok(true) => {
        let _ = collect_packages!(path, acc~)
      }
      Ok(false) => {
        if entry.ends_with(".yodl") {
          let name = extract_package_name_from_path!(entry)
          if acc.contains(name) {
            raise PackageNameConflict(name~, path1=acc[name].unwrap(), path2=path)
          }
          
          acc[name] = path
        }
      }
      Err(error) => raise IOError(error)
    }
  }

  acc
}

let builtin_decls: Array[@parse.Decl] = {
  let source =
    #|const true = 1'b1;
    #|const false = 1'b0;
    #|
    #|@internal
    #|declare module Reg<Width>(
    #|    clk: uint<1>,
    #|    d: uint<Width>,
    #|    en?: bool,
    #|    rst?: bool,
    #|) -> (
    #|    q: uint<Width>,
    #|)
    #|
    #|@internal
    #|declare module RegAsyncReset<Width>(
    #|    clk: uint<1>,
    #|    d: uint<Width>,
    #|    en?: bool,
    #|    rst?: bool,
    #|) -> (
    #|    q: uint<Width>,
    #|)
    #|
    #|@internal
    #|declare module Memory<Width, Depth, ReadPorts, WritePorts, Init>(
    #|    clk: uint<1>,
    #|    read_addr: uint<$clog2(Depth) * ReadPorts>,
    #|    write_addr: uint<$clog2(Depth) * WritePorts>,
    #|    write_enable?: uint<WritePorts>,
    #|    data_in?: uint<Width * WritePorts>,
    #|) -> (
    #|    data_out: uint<Width * ReadPorts>,
    #|)
  
  let lexer = @parse.Lexer::new(source, file="builtin.yodl")
  let tokens = match lexer.lex?() {
    Ok(tokens) => tokens
    Err(error) => {
      println("Error lexing builtin declarations: \{error}")
      panic()
    }
  }
  
  let parser = @parse.Parser::new(tokens, file="builtin.yodl")

  match parser.parse?() {
    Ok(decls) => decls
    Err(error) => {
      println("Error parsing builtin declarations: \{error}")
      panic()
    }
  }
}

pub fn resolve(self: Resolver, path~: String, is_top_package~: Bool) -> @parse.PackageDecl!ResolutionError {
  match self.resolved_packages[path] {
    Some(package) => return package
    None => ()
  }

  let source = match @fs.read_file_to_string?(path~) {
    Ok(source) => source
    Err(error) => raise IOError(error)
  }

  let tokens = match @parse.Lexer::new(source, file=path).lex?() {
    Ok(tokens) => tokens
    Err(error) => raise LexerError(error)
  }

  let parser = @parse.Parser::new(tokens, file=path)

  let decls = match parser.parse?() {
    Ok(decls) => {
      let resolved_decl = Array::new(capacity=decls.length())

      for decl in decls {
        match self.resolve_decl!(decl) {
          Some(decl) => resolved_decl.push(decl)
          None => ()
        }
      }

      resolved_decl 
    }
    Err(error) => raise ParseError(error)
  }

  let pkg_name = if is_top_package {
    "Main"
  } else {
    extract_package_name_from_path!(path)
  }

  let pkg: @parse.PackageDecl = {
    name: pkg_name,
    body: if is_top_package {
        let imports = self.imports.iter().map(fn(p) {
          @parse.Decl::Package(self.resolved_packages[p].unwrap())
        }).collect()

        builtin_decls + imports + decls
      } else {
        decls
      },
    span: parser.span(0),
  }

  if not(is_top_package) {
    self.resolved_packages[path] = pkg
  }

  pkg
}

pub fn resolve_decl(self: Resolver, decl: @parse.Decl) -> @parse.Decl?!ResolutionError {
  match decl {
    Import({ packages, span: _ }) => {
      let pkg = match packages {
        [pkg] => pkg
        _ => raise MultiLevelImportNotSupportedYet(packages~)
      }

      let path = match self.available_packages[pkg] {
        Some(path) => path
        None => raise PackageNotFound(name=pkg)
      }

      let _ = self.resolve!(path~, is_top_package=false)
      self.imports.add(path)
      
      None
    }
    Package(pkg) => {
      let resolved_body = Array::new(capacity=pkg.body.length())

      for decl in pkg.body {
        match self.resolve_decl!(decl) {
          Some(decl) => resolved_body.push(decl)
          None => ()
        }
      }

      Some(@parse.Decl::Package({ name: pkg.name, body: resolved_body, span: pkg.span }))
    }
    decl => Some(decl)
  }
}

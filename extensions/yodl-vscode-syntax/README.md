# Yodl language support

Diagnostics as you type, type hovers, completion, module and builtin signature help,
go to definition/declaration/type, references, rename, document/workspace symbols,
semantic highlighting, folding, selection ranges, and quick fixes for misspelled
names and missing closing delimiters. Imported files and unsaved buffers are analysed
with the same MoonBit compiler frontend used by the CLI and playground.

The extension includes the language server. No MoonBit installation, compiler
process, synthesis tool, or network connection is needed while editing.

## Install

Build from the repository root:

```sh
cd extensions/yodl-vscode-syntax
bun install --frozen-lockfile
bun run package
```

In VS Code, run **Extensions: Install from VSIX…** and select
`yodl-syntax-highlighting-0.1.0.vsix`. Open a `.yodl` file. The extension runs on
the workspace host, including Remote SSH and Codespaces desktop workspaces.

Use **Go to Definition** (F12), **Find All References** (Shift+F12), **Rename Symbol**
(F2), and **Quick Fix** (Ctrl/Cmd+.) as usual. The Problems panel contains source
ranges, diagnostic codes, and related locations. Builtin definitions open as
read-only documents. The **Yodl** output channel contains server/client logs.

## Development

`bun run build` builds MoonBit and bundles the server and extension. Launch VS Code
with `--extensionDevelopmentPath` pointing at this directory. Keep the existing
language id and extension name so this upgrade replaces the syntax-only extension.

The portable Node stdio server is also available from the root package as
`yodl-lsp`; build it with `bun run build:lsp`. The browser uses the same MoonBit
server in a separate worker.

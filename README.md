# yodl

Yet anOther (hardware) Description Language

<img src="res/gol.png" alt="Parallel Game Of Life" width="480px"/>

## Quick links

- [Documentation](https://nathsou.github.io/yodl/book/)
- [Playground](https://nathsou.github.io/yodl/playground.html)

# Installation

## npm
The JS build of Yodl can be installed from npm:

```bash
$ npm install --global yodl
```

## wasm
A `WASI Preview 1` build of yodl is included in this repository:

```bash
wasmtime --dir examples res/yodl-wasi.wasm examples/RISCV.yodl "write_firrtl"
```

To compile FIRRTL outputs to SystemVerilog, install [firtool](https://github.com/llvm/circt/releases/tag/firtool-1.149.0)

## Usage
```bash
$ yodl examples/Hello.yodl "write_firrtl Hello.fir"
$ firtool --format=fir --verilog Hello.fir -o Hello.sv
```

## Development
Install [Moonbit](https://www.moonbitlang.com/):

```bash
$ curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash -s '0.10.11+8f8e8db1e'
```

### Documentation, playground, and tour

The playground includes a [12-lesson tour](tour/README.md), separate from the
larger designs under `examples/`. Start with a logic gate, then explore types,
combinational logic, reusable modules, registers, and memory. Each lesson offers
an explanation, a suggested compiler output to inspect, and a small experiment.
Drafts are saved locally, and circuits can be shared by link or downloaded.

With MoonBit, Bun **1.4.0**, and Python 3 installed, start the documentation and playground:

```bash
bash scripts/serve-playground.sh
```

Open `http://localhost:8080/book/` for documentation or
`http://localhost:8080/playground.html` for the playground. After editing Markdown,
browser code, or tour content, restart the script to rebuild, then reload the page.
The editor loads Monaco from a CDN, so its initial load requires internet access.

The book is built from Markdown using Bun's built-in parser and shares the
playground's themes, Monaco editor, and browser compiler. Examples support local
drafts, compiler stages, expected errors, output comparison, and share links.
See [documentation authoring](book/README.md) for example metadata and validation.

Build the complete static site into `dist/` with `bun run build:site`.
GitHub Pages deployment uses this same build; no application server is required.

Validate the browser components and documentation with `bun run test:docs`.
Validate the tour and backend output with:

```bash
moon test src/lib/tests
bash scripts/test.sh
```

## Checklist

- [x] [FIRRTL](https://github.com/chipsalliance/firrtl-spec) export
- [x] Generic multi-port memories
- [x] Imports (TODO: unqualified imports)
- [x] Verilator + SDL graphics simulation example
- [x] Multi-dimensional vectors ([4][8]u16)
- [ ] Optional module parameters (and register initial value)
- [x] Arbitrary port types
- [x] Type parameters
- [x] External modules
- [ ] Source Maps
- [ ] Test Benches
- [X] FIRRTL to RTLIL backend to bypass SystemVerilog generation
- [ ] Language Server Protocol (LSP) support
- [ ] [KiCad schematics](https://dev-docs.kicad.org/en/file-formats/sexpr-schematic/index.html) export
- [x] Web tour/playground

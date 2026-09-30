# Documentation

The site is generated from `src/*.md` with Bun **1.4.0**. `src/SUMMARY.md` defines
chapter order. The generator preserves the published chapter filenames and
mdBook heading links. Build it alongside the playground from the repository root:

```sh
bun run build:site
bun run dev:site
```

The preview serves `/playground.html`. Restart after source changes.
The result in `dist/` is one static site and one GitHub Pages artifact.
The guide, the tour, and the playground are modes of the single `playground.html`
page (`?mode=docs&chapter=<slug>`, `?lesson=<id>`, `?mode=examples`); they are not
deployed separately. The build writes every chapter to `book/chapters.json`, and
the page renders it on demand. The old `book/<slug>.html` URLs remain as small
pages that forward (keeping the `#anchor`) and hold the chapter text for readers
without JavaScript. Bun is needed only at build time. Reading and copying text
requires no compiler; the editor (Monaco, bundled from the pinned npm
development dependency) loads from the site itself only when the Tour or
Playground editor is first shown. Run `bun install` once before building; the
site requests nothing from a CDN.

## Examples

Use an explicit, stable `ex-` ID so bookmarks and saved drafts survive reordering.
IDs must be unique within a chapter and must not collide with heading IDs.

~~~~markdown
```yodl live id=ex-width stage=write_typed
# module Top() -> () {
    let value: u8 = 42
# }
```
~~~~

A leading `#` marks supporting code hidden in the reading view. The extractor
removes the marker and at most one following space, preserving indentation and
line numbers. The reading view removes the common leading whitespace from visible
lines, retaining indentation inside nested blocks. Editing reveals the complete program, and compiler diagnostics
refer to that complete program. The same extracted source is used in CI.

Options are whitespace-separated `name=value` pairs (values cannot contain
spaces):

| Option | Meaning |
| --- | --- |
| `id=ex-name` | Stable example and draft identity; explicit IDs are required by the book tests. |
| `live` | Enable editing (the default for complete Yodl examples). |
| `static` | Display code without an editor; it is still validated. |
| `stage=write_typed` | Initially selected compiler stage. Defaults depend on the chapter. |
| `expect=success` | Require compilation to succeed (the default). |
| `expect=error` | Require an error at the selected stage; show it as an intentional teaching example. |
| `diagnostic=substring` | Optionally require a specific substring in that error. |
| `expect=skip` | Illustrative fragment, neither runnable nor compiled. Use sparingly. |
| `unsupported=write_rtlil` | Comma-separated stages unavailable for this example. Disabled in the editor; CI verifies they still fail so the annotation does not conceal newly available support. |
| `src=tour/05-vectors.yodl` | Read source from a repository file instead of the fence body. The body must be empty. |
| `files=examples/lib/Timing.yodl` | Comma-separated dependency files to include in the virtual filesystem. Include transitive dependencies explicitly. |
| `region=name` | Show the part between `// region name` and `// endregion name`; compile and edit the complete source. |

Referenced `.yodl` files must be inside `book/src`, `examples`, or `tour`. Their
repository-relative paths are preserved for import resolution. Keep runnable
fences at the top level (up to three leading spaces); nested runnable fences in lists or
blockquotes are not supported.

## Validation

```sh
bun run test:docs
bash scripts/test.sh
```

The first command builds the browser compiler, runs content/worker regression
tests, and checks every complete example against every exposed compiler stage.
Intentional errors and unsupported stages are checked explicitly. The full
script additionally runs firtool on successful examples, alongside the existing
MoonBit, example, and tour validation. It requires firtool and may download an
external Verilog fixture. Neither command updates snapshots.

`src/docs/content.ts` is the shared extractor used by the generator and validator.
`src/docs/build.ts` writes the site: the page, `book/chapters.json`, a search index,
the example manifest, and the forwarding chapter pages. `src/main/docs-view.ts`
renders a chapter and its example blocks: **Compile ▸** compiles the complete
program (including hidden lines) and shows the result in a drawer beneath the
code, and **Open in Playground ↗** hands the program over for editing. Browser
compiler requests use a shared queue with cancellation and a 15-second worker
timeout.

Playground drafts are device-local and keyed by a hash of the original source, so
an updated example does not hide behind an old draft. Reset adopts the current
original. Share URLs carry source and stage, and always use the deployed compiler;
they do not pin an executable compiler version. Handoffs from the guide to the
playground also carry the example's entry path, dependencies, and chapter link
(offered as **Related chapter** in the `···` menu). Existing v1 playground share
links and `book/<chapter>.html#example=…` links continue to work; the latter open
in the playground.

The compiler currently cannot lower some assertions, aggregate register resets,
external modules, and missing memory initialization files to RTLIL. These cases
are marked individually. Compilation describes circuit structure; it does not
simulate signals or grade exercise behavior.

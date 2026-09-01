# Documentation

The site is generated from `src/*.md` with Bun **1.4.0**. `src/SUMMARY.md` defines
chapter order. The generator preserves the published chapter filenames and
mdBook heading links. Build it alongside the playground from the repository root:

```sh
bun run build:site
bun run dev:site
```

The preview serves `/book/` and `/playground.html`. Restart after source changes.
The result in `dist/` is entirely static and is also the GitHub Pages artifact.
Bun is needed only at build time. Reading and copying text requires no compiler;
Monaco loads from its pinned CDN only when an editor is activated.

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
line numbers. Editing reveals the complete program, and compiler diagnostics
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
`src/docs/build.ts` builds chapter pages, a search index, and the example manifest.
`src/docs/docs.ts` enhances static code blocks with lazy editors. Browser compiler
requests use a shared queue with cancellation and a 15-second worker timeout.

Drafts are device-local. Each stores its original source/dependency hash; if the
book changes, the editor offers the current original alongside the saved draft.
Reset adopts the current original. Shared documentation examples get separate
drafts. Share URLs carry source and stage, and always use the deployed compiler;
they do not pin an executable compiler version. Handoffs to the playground also
carry the example's entry path, dependencies, and chapter link. Existing v1
playground share links continue to work.

The compiler currently cannot lower some assertions, aggregate register resets,
external modules, and missing memory initialization files to RTLIL. These cases
are marked individually. Compilation describes circuit structure; it does not
simulate signals or grade exercise behavior.

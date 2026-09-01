# Yodl tour

The playground tour is a progressive introduction, separate from the larger
programs in `examples/`. Every lesson is a small, standalone circuit with a
single entry module. The playground starts with the first lesson for new users.

The sequence covers:

1. Signals, ports, and logic gates
2. Integer widths, signedness, and arithmetic
3. Conditions, match expressions, and multiplexers
4. Bit slices, concatenation, and reductions
5. Vectors and compile-time loops
6. Records and type aliases
7. Module instances and connections
8. Natural-number and type parameters
9. Registers, clocks, reset, and enable
10. Feedback, counters, and compile-time size functions
11. Packages and qualified names
12. Memory ports and latency

## Authoring lessons

Add a `.yodl` file here and an entry to `lessons.json`. The array order is the
navigation order. Use a stable `id` and filename so existing bookmarks and
browser drafts continue to work. Each entry contains:

- `title` and `topic`: the lesson name and short concept label.
- `intro` and `concepts`: the explanation and key points.
- `observe`: something concrete to inspect in the generated output.
- `challenge`: one small edit the learner can make.
- `stage`: the compiler stage that best illustrates the lesson.
- `file`: the standalone source file, relative to this directory.

Keep the lesson source independent of `examples/`. Compilation is structural;
the playground does not simulate a clock, execute the challenge, or grade it.
New lessons should compile at every stage exposed by the playground.

Run `moon test src/lib/tests` to check all tour sources against every stage.
Run `bash scripts/test.sh` to validate examples, tour lessons, and documentation
with the FIRRTL backend and firtool.
Run `bash scripts/test-playground.sh` to check the bundled browser compiler,
lesson metadata, challenge edits, sharing, diagnostic spans, isolated imports,
and worker protocol. Add the corresponding challenge transformation to
`scripts/test-playground.ts` when adding a lesson.

## Playground behavior

Tour and Examples have separate navigation. Each source keeps a local draft;
switching lessons or examples preserves edits. Reset restores only the selected
source after confirmation. Shared circuits open in a separate draft and do not
overwrite the recipient's normal lesson or example draft. Share links include
source, selection, and stage; they use the currently deployed compiler version.

Compilation runs in a worker with a 15-second timeout. Auto-compile waits for a
short typing pause; manual compilation is available with Command/Ctrl+Enter.
Errors retain the last successful output, clearly marked as out of date. Only
explicit source spans from the driver's rendered diagnostic are used for editor
markers; diagnostics without a matching source span remain in the error panel.

The browser application is in `src/main/playground.ts`, with styles in
`playground.css`, editor configuration in `playground-editor.ts`, and compilation
in `playground-compiler.ts` / `playground-worker.ts`. Content, stage metadata, and
share serialization live in `playground-model.ts`. The Bun build embeds tour and
example sources; no filesystem or compiler service is needed at runtime.

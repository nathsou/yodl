# Repository guidance

This document describes the repository's conventions and development workflow.
It is intended to be useful to any contributor or automated development tool.

## Project overview

Yodl is a MoonBit hardware-description-language compiler. The compiler reads
Yodl source files and produces progressively lower representations:

1. Parse source into an AST.
2. Resolve imports, constants, module references, and generic instances.
3. Type-check and validate dimensions, expressions, and module connections.
4. Simplify the typed representation into a Core representation.
5. Lower Core to FIRRTL or RTLIL and optionally run backend passes.

The main package boundaries are:

- src/lib/parse: lexer, parser, surface AST, type and expression utilities.
- src/lib/simplify: package resolution, constant handling, monomorphisation,
  and lowering to Core.
- src/lib/elaborate: type checking and lowering from Core to FIRRTL-facing
  structures.
- src/lib/firrtl: FIRRTL data structures, serialisers, type checking, and
  lowering passes.
- src/lib/rtlil: RTLIL lowering and serialisation.
- src/lib/driver: command parsing and the compiler driver used by the CLI
  and linked targets.
- src/lib/tests: unit, integration, fixture, and snapshot tests.
- src/main: the command-line entry point and browser-facing integration.
- book and examples: user documentation and representative designs.

## Toolchain and routine commands

Use the MoonBit version documented in README.md when working locally. Check
the pinned version in .github/Dockerfile when reproducing CI behaviour, since
toolchain changes can affect generated interfaces and diagnostics.

Useful commands from the repository root:

~~~sh
moon check
moon test
moon test src/lib/tests
~~~

Never format the code using `moon fmt`, the codebase's formatting should be preserved.

For full project validation, including examples and documentation code blocks,
run:

~~~sh
bash scripts/test.sh
~~~

That script requires firtool and may download the external Verilog fixture
used by the examples. If those tools or network access are unavailable, run
the MoonBit checks and tests separately and report the unavailable validation.

The CLI exposes intermediate compiler stages. To inspect them all:

~~~sh
for stage in write_source write_mono write_typed write_simplified \
  write_low_firrtl write_firrtl write_rtlil; do
  moon run src/main/yodl.mbt examples/Hello.yodl "$stage"
done
~~~

Use the earliest stage that demonstrates the behaviour under investigation.
This makes failures easier to localise and keeps tests focused.

## Testing expectations

Add a regression test for user-visible compiler behaviour. Prefer a focused
test close to the affected subsystem, and use the helpers in
src/lib/tests/helpers.mbt for compiling source strings and checking
diagnostics.

- Use compile_stage when asserting generated output.
- Use compile_error when asserting that invalid source is rejected.
- Put reusable source programs in src/lib/tests/fixtures when they are easier
  to understand as standalone files.
- Update snapshots only when the output change is intentional:

  ~~~sh
  UPDATE_SNAPSHOTS=1 moon test src/lib/tests
  ~~~

  Review every resulting snapshot diff; do not update snapshots merely to
  make a test pass.
- For parser or type-system changes, test both successful and invalid inputs
  where practical, including source-location behaviour for diagnostics.
- Run moon check and the relevant focused test while iterating, then run
  moon test src/lib/tests before handing off. Run scripts/test.sh when backend
  output, examples, or documentation may be affected.

## Compiler invariants

Keep the compiler's phase boundaries explicit:

- Surface and symbolic types may exist during parsing, resolution, and
  monomorphisation.
- Core construction and backend lowering require concrete, valid dimensions
  and supported types.
- Generic module declarations may defer checks that depend on their declared
  parameters, but those checks must be replayed when the parameters become
  concrete.
- Domain errors for size functions such as clog2! and cdiv! should retain the
  most precise source span available.
- Source spans are diagnostic metadata. They must not change semantic
  equality or cause equivalent types to compare differently.

When changing a compiler phase, inspect the next phase's assumptions and add a
test that would fail if an invalid or symbolic value crossed the boundary.

## Generated interface files

Files named pkg.generated.mbti are generated public package interfaces created
by moon info. They are tracked in version control in this project. When
changing a package's exported types, functions, constructors, traits, or
errors:

1. Run `moon info`.
2. Review the generated diff for the affected package.
3. Keep the relevant interface updates with the source change.
4. Discard unrelated toolchain-formatting churn after reviewing it.

Do not hand-edit generated interface contents. Do not commit build output from
_build, target, or other ignored directories.

## Documentation and examples

Language syntax or CLI changes should update the relevant README, book page,
playground option, or example when applicable. Documentation code blocks are
compiled by scripts/test.sh, so keep them valid Yodl programs.

When changing emitted FIRRTL or RTLIL, inspect representative output and run
the corresponding example or snapshot tests. Avoid treating serialised output
as an implementation detail when users or downstream tools consume it.

# Presentation

Yodl is a simple and modern behavioural [Hardware Description Language](https://en.wikipedia.org/wiki/Hardware_description_language) (HDL) which acts as a lightweight abstraction
layer over the [FIRRTL](https://github.com/chipsalliance/firrtl-spec) intermediate representation.

## Design goals

### Simple

- Yodl designs should be easy to read, even for hobbyists without any prior experience with HDLs, this is mainly achieved by using a familiar C/Rust-like syntax and limiting the amount of constructs (no always blocks / processes).
- Minimise implementation complexity by choosing an easy to parse syntax and by focusing on a restricted set of features.

### Explicit

- Established HDLs like Verilog suffer from implicit behaviours which can lead to subtle, hard-to-diagnose bugs like implicit signal declarations or implicit wire narrowing and widening.
Yodl enforces strict rules with explicit intent to prevent common mistakes.

### Robust

- Yodl's type-system can catch many classes of errors before elaboration even begins.

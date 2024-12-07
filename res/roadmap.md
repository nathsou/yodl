
# Pipeline
- Lexer
- Parser
- Simplification (monomorphisation + loop unrolling)
- Verilog export
- Synthesis 
- BLIF + Digital + KiCad export

## Roadmap

### 1. Combinational modules

Implement the full pipeline for a limited subset of Yodl with modules using logic gates only

```yodl
module FullAdder(
    a: logic,
    b: logic,
    carry_in: logic,
) -> (
    sum: logic,
    carry_out: logic,
) {
    let xor1 = a xor b;
    sum = xor1 xor carry_in;
    carry_out = (carry_in and xor1) or (a and b);
}
```

### 2. Module instantiation

Support module instantiation within other modules.

A module instance stores references to submodule instantiations.

The list of all primitive components used in the top-level circuit can be collected by performing a DFS on module instances.

```yodl
// built-in
declare module Reg1 (
    clk: logic,
    d: logic,
    enable: logic,
) -> (
    q: logic,
);

module Reg<W> (
    clk: logic,
    data: logic[W],
    enable: logic,
) -> (
    q: logic[W],
) {
    for i in 0..<W {
        let r = Reg1(
            clk: clk,
            d: data[i],
            enable: enable,
        );

        q[i] = r.q;
    }

    // q = [Reg1(clk, d: data[i], enable).q for i in 0..<W];
}
```
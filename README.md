# yodl

End-to-end circuit design, simulation, testing

## Goals
Create a friction-less workflow to manufacture circuits with confidence

## Pipeline
Circuit description (Yodl) -> Visualization (Digital) -> Software simulation (Yodl/Verilog simulator) -> FPGA synthesis (Yosys/Vivado, ...) -> Schematic & PCB (KiCad) -> Manufacturing (gerber)

- [ ] Built-in simulator
- [ ] Export to [Digital](https://github.com/hneemann/Digital) (with integrated component/wiring positioning editor?)
- [ ] Export Verilog
- [ ] Export [BLIF](https://www.cse.iitb.ac.in/~supratik/courses/cs226/spr16/blif.pdf) or [Yosys JSON](https://yosyshq.readthedocs.io/projects/yosys/en/latest/cmd/write_json.html)?
- [ ] Export [KiCad schematics](https://dev-docs.kicad.org/en/file-formats/sexpr-schematic/index.html)

## Syntax

```yodl
module RegAsyncReset[W] (
    clk: clock,
    rst: logic,
    data: logic[W],
    enable: logic,
) -> (
    q: logic[W],
) {
    r := Reg[W](
        clk: clk,
        data: if rst { '0 } else { data },
        enable: enable || rst,
    );

    q = r.q;
}

// built-in
declare module Reg1 (
    clk: clock,
    d: logic,
    enable: logic,
) -> (
    q: logic,
);

declare module Reg[W] (
    clk: clock,
    data: logic[W],
    enable: logic,
) -> (
    q: logic[W],
) {
    for i in 0..<W {
        r := Reg1(
            clk: clock,
            d: data[i],
            enable: enable,
        );

        q[i] = r.q;
    }
}
```

Should synthesize into a Digital circuit similar to:

![RegAsyncReset in Digital](res/RegAsyncResetDigital.png)

## Checkpoints

- [ ] MVP: Manufacture a simple calculator circuit with a KiCad export
- [ ] Latch detection

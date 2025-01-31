# yodl

Yet anOther (hardware) Description Language

![Text Verilator + SDL Simulation](res/text_sim.png)

## Usage
- Install [Moonbit](https://www.moonbitlang.com/)
- ```$ git clone https://github.com/nathsou/yodl.git yodl```
- ```$ cd yodl```
- ```$ moon run src/main examples/Hello.yodl "write_verilog Hello.v"```

## Checklist

- [ ] [FIRRTL](https://github.com/chipsalliance/firrtl-spec) export
- [x] Verilog export
- [x] Generic multi-port memories
- [x] Imports (TODO: unqualified imports)
- [x] Verilator + SDL graphics simulation example
- [ ] Multi-dimensional vectors (logic[16][4])
- [ ] Optional module parameters (and register initial value)
- [ ] Arbitrary port types
- [ ] Testbench generation (or use cocotb?)
- [ ] [KiCad schematics](https://dev-docs.kicad.org/en/file-formats/sexpr-schematic/index.html) export
- [ ] Web tour/playground

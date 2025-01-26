# yodl

Yet anOther (hardware) Description Language

![Text Verilator + SDL Simulation](res/text_sim.png)

## Usage
- Install [Moonbit](https://www.moonbitlang.com/)
- ```$ git clone https://github.com/nathsou/yodl.git yodl```
- ```$ cd yodl```
- ```$ moon run src/main examples/Hello.yodl "write_verilog Hello.v"```

## Checklist

- [x] Verilog export
- [x] Generic multi-port memories
- [x] Imports (TODO: unqualified imports)
- [x] Verilator + SDL graphics simulation example
- [x] Procedural (always_comb) blocks
- [ ] Multi-dimensional vectors (logic[16][4])
- [ ] Optional module parameters (and register initial value)
- [ ] Arbitrary port types
- [ ] Implement the [check](https://github.com/YosysHQ/yosys/blob/45e31f06b4dec9e0783481d6bf03fa906e21aaa4/passes/cmds/check.cc) pass
- [ ] Testbench generation (or use cocotb?)
- [ ] [Digital](https://github.com/hneemann/Digital) (with integrated component/wiring positioning editor?) export?
- [ ] [KiCad schematics](https://dev-docs.kicad.org/en/file-formats/sexpr-schematic/index.html) export
- [ ] Graphviz/Mermaid export
- [ ] Web tour/playground

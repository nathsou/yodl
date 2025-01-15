# yodl

Yet anOther (hardware) Description Language

## Usage
- Install [https://www.moonbitlang.com/](Moonbit)
- ```$ git clone https://github.com/nathsou/yodl.git yodl```
- ```$ cd yodl```
- ```$ moon run src/main Mod.yodl "write_rtlil Mod.rtlil; write_verilog Mod.v"```

## Checklist

- [x] [RTLIL](https://yosyshq.readthedocs.io/projects/yosys/en/latest/yosys_internals/formats/rtlil_rep.html) export
- [x] Verilog export
- [x] Generic multi-port memories
- [x] Imports (TODO: unqualified imports)
- [ ] Implement the [flatten](https://github.com/YosysHQ/yosys/blob/45e31f06b4dec9e0783481d6bf03fa906e21aaa4/passes/techmap/flatten.cc#L282) pass
- [ ] Built-in event-driven simulator?
- [ ] Multi-dimensional vectors (logic[16][4])
- [ ] Optional module parameters (and register initial value)
- [ ] Arbitrary port types
- [ ] Implement the [check](https://github.com/YosysHQ/yosys/blob/45e31f06b4dec9e0783481d6bf03fa906e21aaa4/passes/cmds/check.cc) pass
- [ ] Testbench generation (or use cocotb?)
- [ ] [Digital](https://github.com/hneemann/Digital) (with integrated component/wiring positioning editor?) export?
- [ ] [KiCad schematics](https://dev-docs.kicad.org/en/file-formats/sexpr-schematic/index.html) export
- [ ] Graphviz/Mermaid export
- [ ] Web tour/playground

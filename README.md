# yodl

Yet anOther (hardware) Description Language

## Goals
Automate schematic generation from a textual description.

## Pipeline
Circuit description (Yodl) -> Visualization (Digital) -> Software simulation (Yodl/Verilog simulator) -> FPGA synthesis (Yosys/Vivado, ...) -> Schematic & PCB (KiCad) -> Manufacturing (gerber)

- [x] [RTLIL](https://yosyshq.readthedocs.io/projects/yosys/en/latest/yosys_internals/formats/rtlil_rep.html) export
- [x] Verilog export
- [x] Generic multi-port memories
- [ ] Multi-dimensional vectors (logic[16][4])
- [ ] Optional module parameters (and register initial value)
- [ ] Arbitrary port types
- [ ] Implement the [check](https://github.com/YosysHQ/yosys/blob/45e31f06b4dec9e0783481d6bf03fa906e21aaa4/passes/cmds/check.cc) pass
- [ ] Implement the [flatten](https://github.com/YosysHQ/yosys/blob/45e31f06b4dec9e0783481d6bf03fa906e21aaa4/passes/techmap/flatten.cc#L282) pass
- [ ] Testbench generation (or use cocotb?)
- [ ] [Digital](https://github.com/hneemann/Digital) (with integrated component/wiring positioning editor?) export?
- [ ] [KiCad schematics](https://dev-docs.kicad.org/en/file-formats/sexpr-schematic/index.html) export
- [ ] Built-in event-driven simulator?
- [ ] Graphviz/Mermaid export

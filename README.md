# yodl

Yet anOther (hardware) Description Language

<img src="res/gol.png" alt="Parallel Game Of Life" width="480px"/>

## Usage
- Install [Moonbit](https://www.moonbitlang.com/) and [firtool](https://github.com/llvm/circt/releases) (tested with version 1.104.0)
- ```$ git clone https://github.com/nathsou/yodl.git yodl```
- ```$ cd yodl```
- ```$ moon run src/main examples/Hello.yodl "write_firrtl Hello.fir"```
- ```$ firtool --format=fir --verilog Hello.fir -o Hello.sv```

## Checklist

- [x] [FIRRTL](https://github.com/chipsalliance/firrtl-spec) export
- [x] Generic multi-port memories
- [x] Imports (TODO: unqualified imports)
- [x] Verilator + SDL graphics simulation example
- [x] Multi-dimensional vectors (uint<16>[4][8])
- [ ] Optional module parameters (and register initial value)
- [x] Arbitrary port types
- [x] Type parameters
- [ ] Testbench generation (or use cocotb?)
- [ ] [KiCad schematics](https://dev-docs.kicad.org/en/file-formats/sexpr-schematic/index.html) export
- [ ] Web tour/playground

# RISC-V

RISC-V is an open-source RISC instruction set architecture (ISA).

The following is a straightforward port of the [FemtoRV](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV/README.md) core to Yodl.

```yodl
{{#include ../../../examples/RISCV.yodl}}
```

Here is an example of how this core can be instanciated:

```yodl
{{#include ../../../examples/SOC.yodl}}
```

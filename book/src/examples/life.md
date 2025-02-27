# Game of Life

A fully parallel implementation of Conway's Game of Life is pretty straightforward to implement on an FPGA, at the cost of using a lot of resources.

```yodl
{{#include ../../../examples/Life.yodl}}
```

The `Life` module initialises a 30 by 40 grid of cells with a Gosper gun and and a glider eater.

```yodl
{{#include ../../../examples/Sim.yodl}}
```

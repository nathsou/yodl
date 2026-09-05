# Simulator benchmark matrix

The simulator benchmark is intentionally separate from compilation and
framebuffer conversion. Run each design with a prepared typed circuit and
measure only repeated `settle`/clock operations. Record MoonBit toolchain,
iterations, cycles, and wall time for both the incremental executor and
`settle_reference`.

The minimum matrix is:

| Case | What it measures |
| --- | --- |
| scalar counter | register sampling and ordinary combinational settling |
| repeated hierarchy | child input/output propagation and instance isolation |
| Game of Life | packed state and wide dependency fan-out |
| memory-heavy design | idle memory, one write/cycle, multiple ports, and unknown-address writes at several depths |
| pixel stream | bounded frame advancement and raster conversion separately |

For memory cases, report depths 16, 256, and 4096 and include an idle cycle.
Known-address writes should not scale with depth; unknown-address writes are a
separate conservative baseline. For display cases, report simulator cycles
and framebuffer conversion as separate timings. Generated-input/reference
comparison tests in `src/lib/tests/simulator_compile.mbt` are the correctness
oracle before interpreting a performance change.

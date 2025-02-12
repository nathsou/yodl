# Adapted from https://projectf.io/posts/verilog-sim-verilator-sdl/

VFLAGS = -O3 --x-assign fast --x-initial fast --noassert
SDL_CFLAGS = `sdl2-config --cflags`
SDL_LDFLAGS = `sdl2-config --libs`

all: VTop

VTop.mk: RISCV.sv
	verilator ${VFLAGS} -I./ RISCV.sv --top-module Top \
		-cc --exe -j 0 riscv_wrapper.cpp -o sim

VTop: VTop.mk
	make -C ./obj_dir -f VTop.mk

RISCV.fir:
	cd ../.. && moon run src/main examples/RISCV.yodl "write_firrtl sim/riscv/RISCV.fir"

RISCV.sv: RISCV.fir
	firtool -O=release --format=fir --verilog -disable-all-randomization -strip-debug-info RISCV.fir -o RISCV.sv

clean:
	rm -rf ./obj_dir RISCV.sv RISCV.fir

.PHONY: all VTop

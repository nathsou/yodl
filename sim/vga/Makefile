# Adapted from https://projectf.io/posts/verilog-sim-verilator-sdl/

VFLAGS = -O3 --x-assign fast --x-initial fast --noassert
SDL_CFLAGS = `sdl2-config --cflags`
SDL_LDFLAGS = `sdl2-config --libs`

all: VTopSim

VTopSim.mk: Sim.sv
	verilator ${VFLAGS} -I./ Sim.sv --top-module TopSim \
		-cc --exe -j 0 vga_wrapper.cpp -o sim \
		-CFLAGS "${SDL_CFLAGS}" -LDFLAGS "${SDL_LDFLAGS}"

VTopSim: VTopSim.mk
	make -C ./obj_dir -f VTopSim.mk

Sim.sv:
	cd ../.. && moon run src/main examples/Sim.yodl "write_firrtl sim/vga/Sim.fir"
	firtool -O=release --format=fir --verilog -disable-all-randomization -strip-debug-info Sim.fir -o Sim.sv

clean:
	rm -rf ./obj_dir Sim.sv Sim.fir

.PHONY: all VTopSim
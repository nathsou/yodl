# Adapted from https://projectf.io/posts/verilog-sim-verilator-sdl/

VFLAGS = -O3 --x-assign fast --x-initial fast --noassert
SDL_CFLAGS = `sdl2-config --cflags`
SDL_LDFLAGS = `sdl2-config --libs`

VTopSim: VTopSim.mk
	make -C ./obj_dir -f VTopSim.mk

VTopSim.mk: Sim.v
	verilator ${VFLAGS} -I./ Sim.v --top-module TopSim \
		-cc --exe main_sim.cpp -o sim \
		-CFLAGS "${SDL_CFLAGS}" -LDFLAGS "${SDL_LDFLAGS}"

Sim.v:
	cd .. && moon run src/main examples/Sim.yodl "write_firrtl sim/Sim.fir"
	firtool -O=debug --format=fir --verilog -disable-all-randomization -strip-debug-info Sim.fir -o Sim.v

clean:
	rm -rf ./obj_dir Sim.v Sim.fir

.PHONY: all VTopSim

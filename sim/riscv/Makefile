# Adapted from https://projectf.io/posts/verilog-sim-verilator-sdl/

VFLAGS = -O3 -DENABLE_INITIAL_MEM_ --x-assign fast --x-initial fast --noassert
SDL_CFLAGS = `sdl2-config --cflags`
SDL_LDFLAGS = `sdl2-config --libs`

all: VTop

VTop.mk: RISCV.sv
	verilator ${VFLAGS} -I./ RISCV.sv --top-module Top \
		-cc --exe -j 0 riscv_wrapper.cpp -o sim

VTop: VTop.mk
	make -C ./obj_dir -f VTop.mk

RISCV.fir: prog.hex
	cd ../.. && moon run src/main examples/RISCV.yodl "write_firrtl sim/riscv/RISCV.fir"

RISCV.sv: RISCV.fir
	firtool -O=release --format=fir --verilog -disable-all-randomization -strip-debug-info RISCV.fir -o RISCV.sv

prog.hex: prog.bram.elf
	tools/firmware_words prog.bram.elf -ram 6144 -max_addr 6144 -out prog.hex

prog.bram.elf: prog.o start.o putchar.o bram.ld
	riscv64-elf-ld prog.o putchar.o -o prog.bram.elf -T bram.ld -m elf32lriscv -nostdlib --no-relax-gp

prog.o: prog.s
	riscv64-elf-as -march=rv32i -mabi=ilp32 -mno-relax prog.s -o prog.o

start.o: start.s
	riscv64-elf-as -march=rv32i -mabi=ilp32 -mno-relax start.s -o start.o

putchar.o: putchar.s
	riscv64-elf-as -march=rv32i -mabi=ilp32 -mno-relax putchar.s -o putchar.o

clean:
	rm -rf ./obj_dir RISCV.sv RISCV.fir

.PHONY: all VTop

# Adapted from https://projectf.io/posts/verilog-sim-verilator-sdl/

VFLAGS = -O3 -DENABLE_INITIAL_MEM_ --x-assign fast --x-initial fast --noassert -Wno-CASEOVERLAP -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC

all: VTop

VTop.mk: RISCV.fir.sv
	verilator ${VFLAGS} -I./ RISCV.fir.sv --top-module Top \
		-cc --exe -j 0 riscv_wrapper.cpp -o sim

VTop: VTop.mk
	make -C ./obj_dir -f VTop.mk

RISCV.rtlil: prog.hex
	cd ../.. && moon run src/main examples/RISCV.yodl "write_rtlil sim/riscv/RISCV.rtlil"

RISCV.rtlil.sv: RISCV.rtlil
	yosys -p "read_rtlil RISCV.rtlil; opt; write_verilog RISCV.rtlil.sv"

RISCV.fir: prog.hex
	cd ../.. && moon run src/main examples/RISCV.yodl "write_low_firrtl sim/riscv/RISCV.fir"

RISCV.fir.sv: RISCV.fir
	firtool -O=release --format=fir --verilog -disable-all-randomization -strip-debug-info RISCV.fir -o RISCV.fir.sv

prog.hex: prog.bram.elf
	riscv64-elf-objcopy -O binary prog.bram.elf prog.bin
	hexdump -v -e '1/4 "%08x\n"' prog.bin > prog.hex

prog.bram.elf: prog.o start.o putchar.o bram.ld
	riscv64-elf-ld prog.o putchar.o -o prog.bram.elf -T bram.ld -m elf32lriscv -nostdlib --no-relax-gp

prog.o: prog.s
	riscv64-elf-as -march=rv32i -mabi=ilp32 -mno-relax prog.s -o prog.o

start.o: start.s
	riscv64-elf-as -march=rv32i -mabi=ilp32 -mno-relax start.s -o start.o

putchar.o: putchar.s
	riscv64-elf-as -march=rv32i -mabi=ilp32 -mno-relax putchar.s -o putchar.o

clean:
	rm -rf ./obj_dir RISCV.sv RISCV.fir RISCV.rtlil RISCV.rtlil.sv RISCV.fir.sv prog.hex prog.bin prog.bram.elf

.PHONY: all VTop

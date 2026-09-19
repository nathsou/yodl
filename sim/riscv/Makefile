# Adapted from https://projectf.io/posts/verilog-sim-verilator-sdl/

VFLAGS = -O3 -DENABLE_INITIAL_MEM_ --assert --x-assign unique --x-initial unique -Wno-CASEOVERLAP -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC
YODL_SOURCES := $(shell find ../../src ../../examples/lib -type f \( -name '*.mbt' -o -name '*.yodl' \)) ../../examples/RISCV.yodl

all: VTop

VTop.mk: RISCV.fir.sv riscv_wrapper.cpp Makefile
	verilator ${VFLAGS} -I./ RISCV.fir.sv --top-module Top \
		-cc --exe -j 0 riscv_wrapper.cpp -o sim

VTop: VTop.mk
	make -C ./obj_dir -f VTop.mk

VTop-rtlil.mk: RISCV.rtlil.sv riscv_wrapper.cpp Makefile
	verilator ${VFLAGS} -I./ RISCV.rtlil.sv --top-module Top \
		-cc --exe -j 0 riscv_wrapper.cpp --Mdir obj_dir_rtlil -o sim

VTop-rtlil: VTop-rtlil.mk
	make -C ./obj_dir_rtlil -f VTop.mk

run-rtlil: VTop-rtlil
	./obj_dir_rtlil/sim

RISCV.rtlil: prog.hex $(YODL_SOURCES)
	test ! -e ../../prog.hex
	cp prog.hex ../../prog.hex
	cd ../.. && moon run src/main examples/RISCV.yodl "write_rtlil sim/riscv/RISCV.rtlil"; status=$$?; rm -f prog.hex; exit $$status

RISCV.rtlil.sv: RISCV.rtlil
	yosys -p "read_rtlil RISCV.rtlil; opt; write_verilog RISCV.rtlil.sv"

RISCV.fir: prog.hex $(YODL_SOURCES)
	cd ../.. && moon run src/main examples/RISCV.yodl "write_low_firrtl sim/riscv/RISCV.fir"

RISCV.fir.sv: RISCV.fir
	firtool -O=release --format=fir --verilog -disable-all-randomization -strip-debug-info RISCV.fir -o RISCV.fir.sv

prog.hex: prog.bram.elf
	riscv64-elf-objcopy -O binary prog.bram.elf prog.bin
	hexdump -v -e '1/4 "%08x\n"' prog.bin | awk '{ if (NR > 1536) exit 1; words[NR] = $$0 } END { if (NR > 1536) exit 1; for (i = 1; i <= 1536; i++) print (i <= NR ? words[i] : "00000000") }' > prog.hex

prog.bram.elf: prog.o start.o putchar.o bram.ld
	riscv64-elf-ld start.o prog.o putchar.o -o prog.bram.elf -T bram.ld -m elf32lriscv -nostdlib --no-relax-gp

prog.o: prog.s
	riscv64-elf-as -march=rv32i -mabi=ilp32 -mno-relax prog.s -o prog.o

start.o: start.s
	riscv64-elf-as -march=rv32i -mabi=ilp32 -mno-relax start.s -o start.o

putchar.o: putchar.s
	riscv64-elf-as -march=rv32i -mabi=ilp32 -mno-relax putchar.s -o putchar.o

clean:
	rm -rf ./obj_dir ./obj_dir_rtlil RISCV.sv RISCV.fir RISCV.rtlil RISCV.rtlil.sv RISCV.fir.sv prog.hex prog.bin prog.bram.elf

.PHONY: all VTop VTop-rtlil run-rtlil

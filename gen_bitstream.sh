#!/bin/bash
module=$1
device=$2

rm output/$module.json output/$module.asc output/$module.bin

firtool --format=fir -O=release --verilog \
    -disable-all-randomization -strip-debug-info \
    --lowering-options=disallowPackedArrays,disallowLocalVariables,emitBindComments \
    output/$module.fir -o output/$module.sv

if [ $module == "RISCV" ]; then
    cp ../sim/riscv/prog.hex output/
fi

yosys -p "read_verilog -sv output/$module.sv; check -assert; synth_ice40 -top Top -json output/$module.json"

if [ $device == "cu" ]; then
    nextpnr-ice40 --hx8k --json output/$module.json --pcf examples/constraints/cu.pcf --package cb132 --freq 100 --asc output/$module.asc
elif [ $device == "go" ]; then
    nextpnr-ice40 --hx1k --json output/$module.json --pcf examples/constraints/go.pcf --package vq100 --freq 25 --asc output/$module.asc
else
    echo "Invalid device, must be either 'cu' or 'go'"
    exit 1
fi

icepack output/$module.asc output/$module.bin
openFPGALoader -b ice40_generic output/$module.bin

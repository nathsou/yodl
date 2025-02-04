module=$1

# Nandlang Go
rm output/$module.json output/$module.asc output/$module.bin
firtool --format=fir -O=release --verilog -disable-all-randomization -strip-debug-info --lowering-options=disallowPackedArrays,disallowLocalVariables output/$module.fir -o output/$module.sv
yosys -p "read_verilog -sv output/$module.sv; check -assert; synth_ice40 -top Top -json output/$module.json"
nextpnr-ice40 --hx1k --json output/$module.json --pcf examples/constraints/go.pcf --package vq100 --freq 25 --asc output/$module.asc
icepack output/$module.asc output/$module.bin
openFPGALoader -b ice40_generic output/$module.bin

# # Alchitry Cu
# moon run src/main &&
# yosys -p "read_verilog output/$module.v; check -assert; synth_ice40 -top Top -json output/$module.json" &&
# # yosys -p "read_rtlil output/$module.rtlil; check -assert; synth_ice40 -top Top -json output/$module.json" &&
# nextpnr-ice40 --hx8k --json output/$module.json --pcf examples/constraints/cu.pcf --package cb132 --freq 100 --asc output/$module.asc &&
# icepack output/$module.asc output/$module.bin

#!/bin/bash

# Exit on error
set -e

EXAMPLES_PATH=examples
EXAMPLES=$(ls $EXAMPLES_PATH/*.yodl)
OUTPUT_PATH=examples/output

mkdir -p $OUTPUT_PATH

for example in $EXAMPLES
do
    echo "Compiling $example..."
    fir_path="$OUTPUT_PATH/$(basename $example .yodl).fir"
    sv_path="$OUTPUT_PATH/$(basename $example .yodl).sv"
    moon run src/main/yodl.mbt $example "write_firrtl $fir_path"
    firtool --format=fir -O=debug --verilog $fir_path -o $sv_path
done

rm -rf $OUTPUT_PATH

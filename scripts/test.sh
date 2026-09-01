#!/bin/bash

# Exit on error
set -e

echo "Running snapshot tests..."
# To regenerate snapshots after intentional compiler changes, run:
#   UPDATE_SNAPSHOTS=1 moon test src/lib/tests
moon test src/lib/tests
echo "All snapshot tests passed."

EXAMPLES_PATH=examples
# all examples and standalone tour lessons except files starting with underscore
EXAMPLES=$(ls $EXAMPLES_PATH/*.yodl tour/*.yodl | grep -v '/_')
OUTPUT_PATH=examples/output

mkdir -p $OUTPUT_PATH

# download 7474.v if it doesn't exist for the ExternalModule.yodl example
if [ ! -f "$OUTPUT_PATH/7474.v" ]; then
  curl https://github.com/TimRudy/ice-chips-verilog/blob/09471fc7fb6053074549a5c6d51e92676c0d8df6/source-7400/7474.v -o "$OUTPUT_PATH/7474.v"
fi

for example in $EXAMPLES
do
    echo "Compiling $example..."
    fir_path="$OUTPUT_PATH/$(basename $example .yodl).fir"
    sv_path="$OUTPUT_PATH/$(basename $example .yodl).sv"
    moon run src/main/yodl.mbt $example "write_low_firrtl $fir_path"
    firtool --format=fir -O=debug --verilog $fir_path -o $sv_path
done

echo "All examples and tour lessons compiled successfully."

# The site and CI consume exactly the same source and example metadata.
moon build src/lib/driver --target=js --release
bun src/docs/validate.ts --backend

echo "All book examples compiled successfully."

rm -rf "$OUTPUT_PATH"

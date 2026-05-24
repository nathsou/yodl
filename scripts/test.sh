#!/bin/bash

# Exit on error
set -e

echo "Running snapshot tests..."
# To regenerate snapshots after intentional compiler changes, run:
#   UPDATE_SNAPSHOTS=1 moon test src/lib/tests
moon test src/lib/tests
echo "All snapshot tests passed."

EXAMPLES_PATH=examples
# all examples except files starting with underscore
EXAMPLES=$(ls $EXAMPLES_PATH/*.yodl | grep -v '/_')
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

echo "All examples compiled successfully."

counter=0

# Find all Markdown files under book and process each one.
find book -type f -name "*.md" | sort | while IFS= read -r file; do
  in_block=0
  while IFS= read -r line; do
    # Start of a fenced code block with language "yodl".
    if [[ "$line" =~ ^\`\`\`yodl ]]; then
      in_block=1
      counter=$((counter+1))
      example_file="$OUTPUT_PATH/example_${counter}.yodl"
      : > "$example_file"  # Create/empty the temporary file.
      continue
    fi

    # End of the fenced code block.
    if [[ $in_block -eq 1 && "$line" =~ ^\`\`\` ]]; then
      in_block=0
      echo "Compiling extracted example from '$file' -> '$example_file'..."
      # Define output file names based on the temporary file’s basename.
      fir_path="$OUTPUT_PATH/$(basename "$example_file" .yodl).fir"
      sv_path="$OUTPUT_PATH/$(basename "$example_file" .yodl).sv"
      
      # Run the compilation commands; any failure causes an exit.
      moon run src/main/yodl.mbt "$example_file" "write_low_firrtl $fir_path"
      firtool --format=fir -O=debug --verilog "$fir_path" -o "$sv_path"
      continue
    fi

    # If inside a yodl code block, remove leading '#' (and any following spaces) before appending.
    if [ $in_block -eq 1 ]; then
      clean_line=$(echo "$line" | sed 's/^#\s*//')
      echo "$clean_line" >> "$example_file"
    fi
  done < "$file"
done

echo "All book examples compiled successfully."

rm -rf "$OUTPUT_PATH"

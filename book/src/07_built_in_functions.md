# Built-in Functions and Operations

Yodl provides several built-in functions and operations to facilitate hardware design.

## Type Conversion Functions

### `uint(x)`

Reinterprets a value as an unsigned integer.

```yodl
let a: sint<8> = -7'd11;
let b: uint<8> = uint(a); // 8'd11
```

When applied to a vector of bits, it concatenates them into a single unsigned integer.

Note that the first element of the vector becomes the least significant bit (LSB) of the resulting integer.

```yodl
let bits = [true, false, true, true];
let value: uint<4> = uint(bits); // Results in 4'b1101
```

### `sint(x)`

Reinterprets a value as a signed integer.

```yodl
let a: sint<8> = sint(8'b10101010);
```

### `clock(x)`

Converts a boolean signal to a clock signal.

```yodl
let slow_clk = clock(counter.q[23]); // Divide the clock by 2^23
```

## Mathematical Functions

### `$clog2(n)`

Computes the ceiling of the base-2 logarithm of `n`.

Often used to determine the minimum number of bits required to represent a value.

```yodl
let addr: uint<$clog2(1024)>; // uint<10>
```

### `$pow(base, exp)`

Computes the power of `base` raised to `exp`.

```yodl
let kilobyte = $pow(2, 10); // 1024
```

### `$cdiv(a, b)`

Computes the ceiling of the division of `a` by `b`.

```yodl
let blocks_needed = $cdiv(data_size, block_size);
```

## Bit Manipulation

### `$flip(x)`

Reverses the bit order of `x`.

```yodl
let reversed = $flip(5'b11100); // Results in 5'b00111
```

## Array Functions

### `$rev(vec)`

Reverses the order of elements in a vector.

Particularly useful when constructing a bit vector from a list of bits from most to least significant
since vectors are indexed from least to most significant, i.e. `vec[0]` is the first element.

```yodl
let reversed = $rev([1'1, 1'0, 1'0, 1'0, 1'0]); // Results in [1'0, 1'0, 1'0, 1'0, 1'1]
```

## Memory Functions

Yodl provides familiar [`$readmemb` and `$readmemh`](https://projectf.io/posts/initialize-memory-in-verilog/) functions to initialize Memory instances from files.

### `$readmemb(file, memory)`

Initializes a memory from a binary format file.

```yodl
let rom = Memory<
    T: uint<8>,
    Depth: 256,
    ReadPorts: 1,
    WritePorts: 0,
>();

// Initialize memory from binary file
$readmemb("rom_data.bin", rom);
```

### `$readmemh(file, memory)`

Initializes a memory from a hexadecimal format file.

```yodl
let rom = Memory<
    T: uint<8>,
    Depth: 256,
    ReadPorts: 1,
    WritePorts: 0,
>();

// Initialize memory from hex file
$readmemh("rom_data.hex", rom);
```

## Debug Functions

### `$printf(format_string, args...)`

Prints formatted text during simulation. Similar to C's printf.

```yodl
$printf("Value of counter: %d", counter.q);
```

### `$assert(predicate, [format_string, args..])`

Asserts that the predicate is true. If the predicate is false, the simulation stops and prints an optional error message.

```yodl
$assert(true == 1'b1);
$assert(counter.q == 0, "Counter should be 0, but is %d", counter.q);
```

### `$stop([exit_code])`

Stops the simulation with an optional exit code.

```yodl
if error_condition {
    $stop(1);
}
```

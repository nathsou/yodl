# Built-in Functions and Operations

Yodl provides several built-in functions and operations to facilitate hardware design.

## Type Conversion Functions

### `uint!(x)`

Reinterprets a value as an unsigned integer.

```yodl
# module Test() -> () {
    let a: sint<8> = -7'd11
    let b: uint<8> = uint!(a) // 8'd11
# }
```

When applied to a vector of bits, it concatenates them into a single unsigned integer.

Note that the first element of the vector becomes the least significant bit (LSB) of the resulting integer. If you would like the order to be preserved, use the `cat!` built-in.

```yodl
# module Test(clk: clock) -> () {
    let bits = [true, false, true, true]
    assert!(uint!(bits) == 4'b1101)
# }
```

### `sint!(x)`

Reinterprets a value as a signed integer.

```yodl
# module Test() -> () {
    let a: sint<8> = sint!(8'b10101010)
# }
```

### `clock!(x)`

Converts a boolean signal to a clock signal.

```yodl
# module Test(clk: clock) -> () {
    let counter = Reg<uint<24>>(clk)
    counter.d = counter.q + 1
    let slow_clk = clock!(counter.q[23]) // Divide the clock by 2^23
# }
```

## Mathematical Functions

### `clog2!(n)`

Computes the ceiling of the base-2 logarithm of `n`.

Often used to determine the minimum number of bits required to represent a value.

```yodl
# module Test(clk: clock) -> () {
    const AddrWidth = clog2!(1024)
    let addr: uint<AddrWidth> = 10'd0
    assert!(AddrWidth == 10)
# }
```

### `pow!(base, exp)`

Computes the power of `base` raised to `exp`.

```yodl
# module Test(clk: clock) -> () {
    const kilobyte = pow!(2, 10)
    assert!(kilobyte == 1024)
# }
```

### `cdiv!(a, b)`

Computes the ceiling of the division of `a` by `b`.

```yodl
# module Test(clk: clock) -> () {
    const data_size = 1024
    const block_size = 100
    const blocks_needed = cdiv!(data_size, block_size)
    assert!(blocks_needed == 11)
# }
```

## Bit Manipulation

### `flip!(x)`

Reverses the bit order of `x`.

```yodl
# module Test(clk: clock) -> () {
    const flipped = flip!(5'b11100)
    assert!(flipped == 5'b00111)
# }
```

## Vector Functions

### `cat!(args...)`

Concatenates one or more integers (or integer vectors) into a single integer.
The width of the result is the sum of the widths of the arguments. Vectors of
integers are flattened recursively.

If any argument is a signed integer (`sint`), every argument must be signed.

```yodl
# module Test(clk: clock) -> () {
    let upper_nibble = 8'hAB
    let lower_nibble = 8'hCD
    let word = cat!(upper_nibble, lower_nibble)
    assert!(word == 16'hABCD)

    // Vectors are flattened
    let from_vec = cat!([16'hBABA, 16'hFABE])
    assert!(from_vec == 32'hBABAFABE)
# }
```

### `fill!(n, x)`

Produces a vector `T[n]` containing `n` copies of `x`. For bit-replication
(SystemVerilog `{n{x}}`), combine with `cat!`:

```yodl
# module Test(clk: clock) -> () {
    let zeros: bool[4] = fill!(4, 1'b0)
    let mask:  uint<4> = cat!(fill!(4, 1'b1))   // 4'b1111
    assert!(uint!(zeros) == 4'd0)
    assert!(mask == 4'b1111)
# }
```

### `rev!(vec)`

Reverses the order of elements in a vector.

Particularly useful when constructing a bit vector from a list of bits from most to least significant
since vectors are indexed from least to most significant, i.e. `vec[0]` is the first element.

```yodl
# module Test(clk: clock) -> () {
    let reversed = rev!([1'1, 1'0, 1'0, 1'0])
    assert!(reversed[0] == 1'0)
    assert!(reversed[1] == 1'0)
    assert!(reversed[2] == 1'0)
    assert!(reversed[3] == 1'1)
# }
```

### `pad!(x, width)`
Extends the bit-width of an integer `x` to `width` bits.
If `x` is signed, it performs sign-extension; if `x` is unsigned, it performs zero-extension:

| type of `x` | pad!(x, width) |
|-------------|----------------|
| sint<W>     | sign-extend    |
| uint<W>     | zero-extend    | 

```yodl
# module Test(clk: clock) -> () {
    let a = -4'd3 // 5'b1101
    let b: sint<8> = pad!(a, 8) // 8'b11111101 (sign-extended)
    assert!(uint!(b) == 8'b11111101)
    let c: uint<4> = 4'd3 // 4'b0011
    let d: uint<8> = pad!(c, 8) // 8'b00000011 (zero-extended)
    assert!(d == 8'b00000011)
# }
```

## Memory Functions

Yodl provides familiar [`$readmemb` and `$readmemh`](https://projectf.io/posts/initialize-memory-in-verilog/) functions to initialize Memory instances from files.

### `readmemb!(file, memory)`

Initializes a memory from a binary format file.

```yodl
# module Test(clk: clock, addr: uint<8>) -> () {
    let rom = Memory<
        T: uint<8>,
        Depth: 256,
        ReadPorts: 1,
        WritePorts: 0,
    >(
        read: [(clk: clk, en: true, addr: addr)],
    )

    // Initialize memory from binary file
    readmemb!("rom_data.bin", rom)

    let data = rom.q[0]
# }
```

### `readmemh!(file, memory)`

Initializes a memory from a hexadecimal format file.

```yodl
# module Test(clk: clock, addr: uint<8>) -> () {
    let rom = Memory<
        T: uint<8>,
        Depth: 256,
        ReadPorts: 1,
        WritePorts: 0,
    >(
        read: [(clk: clk, en: true, addr: addr)],
    )

    // Initialize memory from hex file
    readmemh!("rom_data.hex", rom)

    let data = rom.q[0]
# }
```

## Debug Functions

### `printf!(format_string, args..)`

Prints formatted text during simulation. Similar to C's printf.

```yodl
# module Test(clk: clock, data: uint<8>) -> () {
    printf!("Value of data: %d", data)
# }
```

### `assert!(predicate, [format_string, args..])`

Asserts that the predicate is true. If the predicate is false, the simulation stops and prints an optional error message.

```yodl
# module Test(clk: clock) -> () {
    assert!(true == 1'b1)
    const two_plus_two = 2 + 2
    assert!(two_plus_two == 4, "Math is broken, expected 4, got %d", two_plus_two)
# }
```

### `stop!([exit_code])`

Stops the simulation with an optional exit code.

```yodl
# module Test(clk: clock) -> () {
#   const error_condition = false
    if error_condition {
        stop!(1)
    }
# }
```

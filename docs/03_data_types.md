# Data Types

## Ground Types

### Integer types

Yodl supports two integer types, which require a width specifier.

#### Unsigned Integers

```yodl
// a 16-bit unsigned integer
let a: uint<16>;
a = 16'd1721;
```

#### Signed Integers

```yodl
// a 7-bit signed ingeger
let b: sint<7> = -6'd8;
let c: sint<32> = sint(32'd11);
```

Integer literals can be specified in decimal, binary, octal, or hexadecimal format.
The syntax is `<width in bits>'[base prefix]<value>`

The decimal value `1621` which requires at least 11 bits can be represented as follows:

| prefix | base | example    |
|-------------|------|------------|
| `b`         | 2    | `11'b11001010101` |
| `o`         | 8    | `11'o3125`    |
| `d`         | 10   | `11'd1621` |
| `h`         | 16   | `11'h655` | 

### Booleans

The `bool` type is an alias for the `uint<1>` type.

For readability, the `true` and `false` keywords are supported and correspond to `1'b1` and `1'b0` respectively. 

```yodl
let is_yodl_neat: bool = true;
```

### Clocks

The `clock` type is required for clock signals used in `Reg` and `Memory` module instances.

```yodl
module Counter(clk: clock) -> (count: uint<24>) {
    let counter = Reg<uint<24>>(clk);
    counter.d = counter.q + 1'd1;
    count = counter.q;
}
```

## Aggregate Types

Groud types can be combined to create more complex data structures.

## Vectors

Vectors are ordered and sized collections of elements.

```yodl
// a vector of eight booleans
let neighbours: bool[8] = [false, false, true, false, true, false, true, false];

// a vector of four 16-bit unsigned integers
let ints: uint<16>[4] = [16'd1, 16'd12, 16'd3, 16'd4];
```

## Strings

Strings use the ISO 8601 encoding (extended ASCII) to represent characters.

Each character is 8-bits wide and `string<Length>` is equivalent to `uint<8>[Length]`.

```yodl
let message1: string<9> = "Yo, Yodl!";
let message2: uint<8>[9] = "Yo, Yodl!";
```

Individual characters can be accessed using the following syntax:

```yodl
let first_char = message1[0];
```

## Structs

Structures (also known as Bundles in Chisel/FIRRTL) group multiple named values under a single name.

```yodl
let colour: { r: uint<8>, g: uint<8>, b: uint<8> } = { r: 8'd17, g: 8'd128, b: 8'd211 };
let red = colour.red;
```

### Instance Types

The type of a module instance is similar to a structure corresponding to the port signature of the module.

Note: Instance types are not compatible with structure types because only the ports which are accessed on a particular instance are included in the resulting type.

```yodl
module Adder(a: uint<8>, b: uint<8>) -> (sum: uint<9>) {
    sum = a + b;
}

module Top() -> () {
    let adder: Adder = Adder(a: 8'd1, b: 8'd2);
    let a = adder.a;
    let b = adder.b;
    let sum = adder.sum;
}
```

# Structural Typing

Yodl's type system is structural (except for instance types), which means that two types are compatible if they have the same shape.

| Type A | Type B | Compatible? |
|--------|--------|-------------|
| `uint<8>` | `uint<8>` | Yes |
| `string<3>` | `uint<8>[3]` | Yes |
| `uint<1>` | `bool` | Yes | 
| `{ a: uint<16>, b: bool }` | `{ b: bool, a: uint<16> }` | Yes |
| `{ a: uint<16>, b: bool }` | `{ a: uint<16> }` | No |
| `{ a: uint<16>, b: bool }` | `{ a: uint<16>, b: bool, c: bool[7] }` | No |
| `uint<8>[8][8]` | `uint<8>[64]` | No |
| `Adder` | `Adder` | Yes |
| `Adder` | `{ a: uint<8>, b: uint<8>, sum: uint<9> }` | No |


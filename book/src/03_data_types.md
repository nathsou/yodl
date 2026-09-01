# Data Types

## Ground Types

### Integer types

Yodl supports two integer types, which require a width specifier:

| Form           | Example            | When to use            |
|----------------|--------------------|------------------------|
| `uN` / `sN`    | `u8`, `u32`, `s7`  | Width is a literal     |
| `uint[expr]` / `sint[expr]` | `uint[clog2!(N)]`, `sint[W + 1]` | Width is a compile-time expression |

#### Unsigned Integers

```yodl live id=ex-unsigned-integers
# module Test() -> () {
    // a 16-bit unsigned integer
    let a: u16
    a = 16'd1721
# }
```

#### Signed Integers

```yodl live id=ex-signed-integers
# module Test() -> () {
    // a 7-bit signed integer
    let b: s7 = -6'd8
    let c: s32 = sint!(32'd11)
# }
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

When an integer value is assigned to a same-signed integer type, Yodl resizes
it to the destination width. Widening an unsigned value zero-extends it,
widening a signed value sign-extends it, and narrowing keeps the least
significant bits. Unsized literals instead adopt the contextual width when the
value fits. Signedness is never changed implicitly: use `uint!(x)` or `sint!(x)`
to request a signedness reinterpretation explicitly.

Without a context, an unsized nonnegative literal synthesizes as an unsigned
integer with its minimum representable width (`1` is `u1`, `255` is `u8`). In a
`uN` or `sN` context it is checked at the literal for overflow and then adopts
that exact type. Negative values are rejected by unsigned contexts and must fit
the two's-complement range of a signed context. Static `Nat` parameters and
width expressions are evaluated in the separate static/index language; they
are not runtime signal types.

### Try a width error

An unsized literal must fit the width supplied by its context. Compile this example to see the
error, then change `u8` to `u9` so that the value fits.

```yodl live id=ex-literal-overflow stage=write_typed expect=error
module WidthError() -> (value: u8) {
    value = 256
}
```

### Booleans

The `bool` type is an alias for the `u1` type.

For readability, the `true` and `false` keywords are supported and correspond to `1'b1` and `1'b0` respectively. 

```yodl live id=ex-booleans
# module Test() -> () {
    let is_yodl_neat: bool = true
# }
```

### Clocks

The `clock` type is required for clock signals used in `Reg` and `Memory` module instances.

```yodl live id=ex-clocks
module Counter(clk: clock) -> (count: u24) {
    let counter = Reg[u24](clk)
    counter.d = counter.q + 1'd1
    count = counter.q
}
```

## Aggregate Types

Ground types can be combined to create more complex data structures.

## Vectors

Vectors are ordered and sized collections of elements.

```yodl live id=ex-vectors
# module Test() -> () {
    // a vector of eight booleans
    let neighbours: [8]bool = [false, false, true, false, true, false, true, false]

    // a vector of four 16-bit unsigned integers
    let ints: [4]u16 = [16'd1, 16'd12, 16'd3, 16'd4]
# }
```

> **Note**: Instead of storing multiple register instances in a vector, define a single register instance with a vector type:

```yodl live id=ex-vectors-2 unsupported=write_rtlil
module RegisterFile(
    clk: clock,
    rst: bool,
    write_enable: bool,
    write_dest: u3,
    write_data: u16,
    read_src1: u3,
    read_src2: u3,
) -> (
    read_data1: u16,
    read_data2: u16,
) {
    // A register storing a vector of eight 16-bit unsigned integers
    let regs = Reg[[8]u16](clk, rst)

    if write_enable {
        regs.d[write_dest] = write_data
    }

    read_data1 = regs.q[read_src1]
    read_data2 = regs.q[read_src2]
}
```

## Characters and Strings

Characters use the ISO 8601 encoding (extended ASCII).

```yodl live id=ex-characters-and-strings
# module Test() -> () {
    let char: u8 = 'a'
# }
```

### Escape sequences

| Sequence | Description |
|----------|-------------|
| `\n`     | Newline     |
| `\t`     | Tab         |
| `\\`     | Backslash   |
| `\'`     | Single quote|

### Strings

Strings are fixed-length vectors of characters.

```yodl live id=ex-strings
# module Test() -> () {
    let message: [9]u8 = "Yo, Yodl!"
# }
```

Individual characters can be accessed using the following syntax:

```yodl live id=ex-strings-2 unsupported=write_rtlil
# module Test(clk: clock) -> () {
    let first_char = "Yo!"[0]
    assert!(first_char == 'Y')
# }
```

## Records

Records group a fixed number of values, accessed either by position or by name.
They subsume what other languages call *tuples* (positional) and *structs* /
*bundles* (named).

### Positional records (tuples)

Fields are accessed by their index (`.0`, `.1`, ...). A 1-element positional
record requires a trailing comma to distinguish it from a parenthesised
expression.

```yodl live id=ex-positional-records-tuples
# module Test() -> () {
    let pair: (bool, u8) = (true, 8'hFF)
    let single: (u8,) = (8'hFF,)
    let nested: ((a: [1]u4, b: bool), (bool, u8), u1) =
        ((a: [4'd1], b: false), pair, 1'b0)

    let first: bool = pair.0 // true
    let second: u8 = pair.1 // 8'hFF
# }
```

### Named records (structs / bundles)

Fields are named. This is what other HDLs call a *bundle* (Chisel/FIRRTL) or
*struct* (SystemVerilog).

```yodl live id=ex-named-records-structs-bundles
# module Test() -> () {
    let colour: (r: u8, g: u8, b: u8) = (r: 8'd17, g: 8'd128, b: 8'd211)
    let red = colour.r
# }
```

A named record can be partially updated by spreading another record with `..base`
followed by overriding fields. Spread is only allowed in named records.

```yodl live id=ex-named-records-structs-bundles-2
# module Test() -> () {
    let base = (r: 8'd17, g: 8'd128, b: 8'd211)
    let darker = (..base, r: 8'd0)
# }
```

Mixing positional and named fields in a single record is not allowed: a record
is either fully positional or fully named.

### Records and module signatures

Because a module's input and output port lists use the same `(name: type, ...)`
syntax as named record types, a module signature is literally a function from a
record of inputs to a record of outputs. Module instantiation passes a record of
named ports:

```yodl live id=ex-records-and-module-signatures
# module Adder(a: u8, b: u8) -> (sum: u9) {
#     sum = a + b
# }
# module Test() -> () {
    let r = Adder(a: 8'd1, b: 8'd2)
# }
```

### Instance Types

The type of a module instance behaves like a named record corresponding to the
port signature of the module.

Note: Instance types are not compatible with named record types because only the
ports which are accessed on a particular instance are included in the resulting
type.

```yodl live id=ex-instance-types
module Adder(a: u8, b: u8) -> (sum: u9) {
    sum = a + b;
}

module Top() -> () {
    let adder = Adder()
    adder.a = 8'd1
    adder.b = 8'd2
    let sum = adder.sum
}
```

## Structural Typing

Yodl's type system is structural (except for instance types), which means that two types are compatible if they have the same shape.

| Type A | Type B | Compatible? |
|--------|--------|-------------|
| `u8` | `u8` | Yes |
| `u1` | `bool` | Yes | 
| `(a: u16, b: bool)` | `(b: bool, a: u16)` | Yes |
| `(a: u16, b: bool)` | `(a: u16)` | No |
| `(a: u16, b: bool)` | `(a: u16, b: bool, c: [7]bool)` | No |
| `[8][8]u8` | `[64]u8` | No |
| `Adder` | `Adder` | Yes |
| `Adder` | `(a: u8, b: u8, sum: u9)` | No |

# Operators

## Unary Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `-` | Arithmetic negation | `-x` |
| `not` | Bitwise NOT | `not x` |
| `andr` | AND reduction | `andr x` |
| `orr` | OR reduction | `orr x` |
| `xorr` | XOR reduction | `xorr x` |

### Reduction Operators

Reduction operators apply the corresponding logic operation across all bits of the operand, returning a single bit result.

```yodl
# module Test(clk: clock) -> () {
    let all_ones = andr 8'b11111111
    assert!(all_ones == 1)

    let any_one = orr 8'b00000001
    assert!(any_one == 1)

    let parity = xorr 8'b10101010
    assert!(parity == 0)
# }
```

## Binary Operators

### Arithmetic Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `+` | Addition | `a + b` |
| `-` | Subtraction | `a - b` |
| `*` | Multiplication | `a * b` |
| `/` | Division | `a / b` |
| `mod` | Modulo | `a mod b` |

### Bitwise Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `and` | Bitwise AND | `a and b` |
| `or` | Bitwise OR | `a or b` |
| `xor` | Bitwise XOR | `a xor b` |
| `nand` | Bitwise NAND | `a nand b` |
| `nor` | Bitwise NOR | `a nor b` |
| `xnor` | Bitwise XNOR | `a xnor b` |
| `shl` | Shift Left | `a shl b` |
| `shr` | Shift Right | `a shr b` |

Note 1: When the shift amount (the right hand side) in a `shr` operation is signed (`sint` type), the operation corresponds to an arithmetic shift right.

Note 2: The `and`, `or`, `xor`, `nand`, `nor`, and `xnor` operators are used both to perform bitwise and logical operations.

### Comparison Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `==` | Equal | `a == b` |
| `!=` | Not Equal | `a != b` |
| `<:` | Less Than | `a <: b` |
| `>:` | Greater Than | `a >: b` |
| `<=` | Less Than or Equal | `a <= b` |
| `>=` | Greater Than or Equal | `a >= b` |

<div class="warning">
    Note: The `<:` and `>:` operators are used for comparison instead of `<` and `>` to avoid confusion with type parameter delimiters during parsing.
</div>

## Ternary Operator

The ternary operator is a concise way to express conditional expressions, generally spanning a single line.

```yodl
# module Test(a: uint<8>, b: uint<8>) -> () {
    let max = a >= b ? a : b
# }
```

## Concatenation

Integer concatenation is performed with the `cat!` built-in function:

```yodl
# module Test(clk: clock) -> () {
    let upper_nibble = 8'hAB
    let lower_nibble = 8'hCD
    let word = cat!(upper_nibble, lower_nibble)
    assert!(word == 16'hABCD)
# }
```

`cat!` also accepts Vectors of integers, which it flattens automatically.

```yodl
# module Test(clk: clock) -> () {
    let value = cat!([1'1, 1'0, 1'0, 1'0]) // 4'b1000
    assert!(value == 4'b1000)
# }
```

## Slicing and Indexing

Elements of vectors and bits of integers can be accessed using the `[]` operator:

```yodl
# module Test(clk: clock) -> () {
    let bits = [..8'd233]
    let first = bits[0]     // Access the first element
    let nibble = bits[7:4] // Extract a range of bits (inclusive)
    let byte = bits[7-:8]   // Extract 8 bits starting from bit 7 (equivalent to data[7:0])

    assert!(first == 1'b1)
    assert!(uint!(nibble) == 4'hE)
    assert!(uint!(byte) == 8'hE9)
# }
```

There are two forms of bit slicing:
1. `[high:low]` - Extract bits from position `high` down to `low` (inclusive)
2. `[start-:width]` - Extract `width` bits starting from position `start`


Note:

- Integers are indexed from the least significant bit (LSB) to the most significant bit (MSB) (right to left).
- Vectors follow standard array-indexing conventions, with the first element at index 0 (left to right).

When a bit vector (`bool[N]` i.e. `uint<1>[N]`) is used as the argument of the `uint` and `sint` built-in functions,
the first element of the vector becomes the MSB of the resulting integer:

```yodl
# module Test(clk: clock) -> () {
    let n = uint!([1'b1, 1'b0, 1'b0])
    assert!(n == 3'b0001)
# }
```

## Replication

The `fill!(n, x)` built-in produces a vector `[n]T` of `n` copies of `x`:

```yodl
# const a = 1'b1
# const b = 1'b0
# module Test(clk: clock) -> () {
    let zeros = fill!(4, 1'b0)        // [1'b0, 1'b0, 1'b0, 1'b0]
    let ones  = cat!(fill!(3, 1'b1))  // Concat-replicate: 3'b111

    assert!(uint!(zeros) == 4'd0)
    assert!(ones == 3'b111)
# }
```

The repeated expressions can contain any value, including instances:

```yodl
# module Cell(clk: clock, rst: bool) -> () {}
# const Rows = 1
# const Cols = 1

# module Test(clk: clock, rst: bool) -> () {
    // initialise a Rows by Cols grid of cells
    let cells = fill!(Cols, fill!(Rows, Cell(clk, rst)))
# }
```

## Concatenation

The `cat!` built-in concatenates a list of integers (or integer vectors) into a single integer.
The width of the result is the sum of the widths of the operands.

If any operand is a signed integer (sint), then all operands are required to be signed.

```yodl
# module Test(clk: clock) -> () {
    let concat_args = cat!(16'hBABA, 16'hFABE)
    let concat_vec  = cat!([16'hBABA, 16'hFABE])

    assert!(concat_args == 32'hBABAFABE)
    assert!(concat_vec == 32'hBABAFABE)
# }
```

## Spread

The spread operator `..` can only appear inside a vector expression and is used to decompose a value into its individual elements.

```yodl
# module Test(clk: clock) -> () {
    let bits: uint<1>[4] = [..4'b1100] // [1'b0, 1'b0, 1'b1, 1'b1]
    let chars: uint<8>[3] = [.."Yo!"] // [8'h59, 8'h6F, 8'h21]
    let flat: uint<2>[3] = [..[2'd1, 2'd2], 2'd3] // [2'd1, 2'd2, 2'd3]

    assert!(bits[0] == 1'b0)
    assert!(bits[1] == 1'b0)
    assert!(bits[2] == 1'b1)
    assert!(bits[3] == 1'b1)
    assert!(chars[0] == 8'h59)
    assert!(chars[1] == 8'h6F)
    assert!(chars[2] == 8'h21)
    assert!(flat[0] == 2'd1)
    assert!(flat[1] == 2'd2)
    assert!(flat[2] == 2'd3)
# }
```

## Operator Precedence

Operators are evaluated in the following order (from highest to lowest precedence):

1. Unary operators (`not`, `-`, `andr`, `orr`, `xorr`)
2. Multiplication, division, modulo (`*`, `/`, `mod`)
3. Addition, subtraction (`+`, `-`)
4. Shift operations (`shl`, `shr`)
5. Comparisons (`<:`, `>:`, `<=`, `>=`)
6. Equality operators (`==`, `!=`)
7. Bitwise AND and NAND (`and`, `nand`)
8. Bitwise XOR and XNOR (`xor`, `xnor`)
9. Bitwise OR and NOR (`or`, `nor`)

Parentheses can be used to override the default precedence order.

## Resulting Type

The output type of a binary operation is determined by the types of the operands and the operation being performed.

It matches the [FIRRTL specification](https://github.com/chipsalliance/firrtl-spec/blob/main/spec.md#primitive-operations-primitive-operations)

The following table summarises the resulting type for each operation:

| operation | lhs type | rhs type | output type |
|-----------|----------|----------|-------------|
| `+`, `-` | `uint<A>` | `uint<B>` | `uint<max(A, B) + 1>` |
| `+`, `-` | `sint<A>` | `sint<B>` | `sint<max(A, B) + 1>` |
| `*` | `uint<A>` | `uint<B>` | `uint<A + B>` |
| `*` | `sint<A>` | `sint<B>` | `sint<A + B>` |
| `/` | `uint<A>` | `uint<B>` | `uint<A>` |
| `/` | `sint<A>` | `sint<B>` | `sint<A + 1>` |
| `mod` | `uint<A>` | `uint<B>` | `uint<min(A, B)>` |
| `mod` | `sint<A>` | `sint<B>` | `sint<min(A, B)>` |
| `==`, `!=`, `<:`, `>:` | `uint<A>` | `uint<B>` | `uint<1>` |
| `==`, `!=`, `<:`, `>:` | `sint<A>` | `sint<B>` | `uint<1>` |
| `and`, `nand`, `or`, `nor`, `xor`, `xnor` | `uint<A>` | `uint<B>` | `uint<max(A, B)>` |
| `and`, `nand`, `or`, `nor`, `xor`, `xnor` | `sint<A>` | `sint<B>` | `uint<max(A, B)>` |

### Shift Operations

When the shift amount is known at compile time, the output type is determined as follows:

| operation | lhs type | shift amount | output type |
|-----------|----------|----------|-------------|
| `shl` | `uint<A>` | `n` | `uint<A + n>` |
| `shl` | `sint<A>` | `n` | `sint<A + n>` |
| `shr` | `uint<A>` | `n` | `uint<max(A - n, 0)>` |
| `shr` | `sint<A>` | `n` | `sint<max(A - n, 1)>` |

When the shift amount is not known at compile time, the output type is determined as follows:

| operation | lhs type | rhs type | output type |
|-----------|----------|----------|-------------|
| `shl` | `uint<A>` | `uint<B>` | `uint<A + 2^B - 1>` |
| `shl` | `sint<A>` | `uint<B>` | `sint<A + 2^B - 1>` |
| `shr` | `uint<A>` | `uint<B>` | `uint<A>` |
| `shr` | `sint<A>` | `uint<B>` | `sint<A>` |


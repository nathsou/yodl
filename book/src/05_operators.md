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
let all_ones = andr 8'b11111111; // 1
let any_one = orr 8'b00000001;   // 1
let parity = xorr 8'b10101010;   // 0
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
let max = a >= b ? a : b;
```

## Concatenation

Vector concatenation can be performed by wrapping a list of values in curly braces:

```yodl
let byte = {upper_nibble, lower_nibble};
```

The concatenation operator can also be used to split an integer into individual bits:

```yodl
let bits = {8'd200}; // [1'1, 1'1, 1'0, 1'0, 1'1, 1'0, 1'0, 1'0]
let value = uint(bits); // 8'd200
```

## Slicing and Indexing

Elements of vectors and bits of integers can be accessed using the `[]` operator:

```yodl
let first = array[0];          // Access the first element
let nibble = value[7:4];       // Extract a range of bits (inclusive)
let bytes = data[7-:8];        // Extract 8 bits starting from bit 7 (equivalent to data[7:0])
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
let n = uint([1'b1, 1'b0, 1'b0]); // 3'b100
```

If you instead want the first element to be the LSB, you can use the `$flip` built-in function:

```yodl
let n = $flip(uint([1'b1, 1'b0, 1'b0])); // 3'b001
```

## Replication

Replication expressions `<uint>*[<expr-list>]` and `<uint>*{<expr-list>}` can be used to create a vector by repeating a value multiple times:

```yodl
let zeros = 4*[1'b0];        // Creates [1'b0, 1'b0, 1'b0, 1'b0]
let pattern = 3*{a, b};      // Creates a concatenation equivalent to {a, b, a, b, a, b}
```

The repeated expressions can contain any value, including instances:

```yodl
// initialise a Rows by Cols grid of cells
let cells = Cols * [Rows * [Cell(clk, rst)]];
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


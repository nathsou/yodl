# Control Flow

Yodl supports several control flow constructs that help express complex behaviours in digital circuits.

## Conditional Statements

### If Expressions

If expressions evaluate a condition and execute one of two branches based on the result:

```yodl
# module Test(a: uint<8>, b: uint<8>) -> () {
    let max = if a >: b {
        a
    } else {
        b
    }
# }
```

If expressions always return a value. When used as statements (without assigning the result), the result is discarded.

### Match Expressions

Match expressions provide a compact way of handling multiple conditions based on a single value:

```yodl
# module Cell(clk: clock) -> () {
#   let alive = Reg<bool>(clk);
#   const count = 2
    // compute next state in the Game of Life
    alive.d = match count {
        3'd2 => alive.q // stable
        3'd3 => true // reproduction
        _ => false // overpopulation or underpopulation
    }
# }
```

A match expression must handle all possible values of the match condition, either by explicitly listing all cases or by providing a default case with the `_` wildcard.

## Iteration

### For Loops

The `for` loop iterates over a range of values:

```yodl
// Simple parallel hexadecimal to character decoder
module Hex<Bits: uint>(n: uint<Bits>) -> (chars: uint<8>[$cdiv(Bits, 4)]) {
    const Len = $cdiv(Bits, 4)
    for i in 0..<Len {
        chars[Len - 1 - i] = match n[(i + 1) * 4 - 1 -: 4] {
            4'h0 => '0'
            4'h1 => '1'
            4'h2 => '2'
            4'h3 => '3'
            4'h4 => '4'
            4'h5 => '5'
            4'h6 => '6'
            4'h7 => '7'
            4'h8 => '8'
            4'h9 => '9'
            4'hA => 'A'
            4'hB => 'B'
            4'hC => 'C'
            4'hD => 'D'
            4'hE => 'E'
            4'hF => 'F'
        }
    }
}

# module Top() -> () {}
```

The range syntax uses:
- `a..<b` for exclusive upper bound (iterates from a to b-1)
- `a..=b` for inclusive upper bound (iterates from a to b)

<div class="warning">
    For loops are fully unrolled during compilation, so they must have compile-time constant bounds.
</div>

## When to Use Each Control Flow Construct

- **If Expressions**: Use for simple binary decisions, especially when the logic is straightforward.
- **Match Expressions**: Use when you need to handle multiple distinct cases based on a single value.
- **For Loops**: Use to repeat operations a known number of times, especially when manipulating vectors or generating parallel hardware.

## Control Flow in Hardware Context

In hardware description languages, control flow constructs don't create sequential execution as in software—they describe hardware structures that implement the specified behavior. Yodl's compiler unrolls loops and elaborates conditional statements into multiplexers.

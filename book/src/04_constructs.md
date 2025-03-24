
# Language Constructs

## Packages

Packages group related top-level declarations under a common namespace.

```yodl
package VGA {
    const SCREEN_WIDTH = 640
    const SCREEN_HEIGHT = 480

    module SyncPulses(
        clk: clock,
    ) -> (
        hsync: bool,
        vsync: bool,
        row: uint<$clog2(SCREEN_HEIGHT)>,
        col: uint<$clog2(SCREEN_WIDTH)>,
    ) {
        // ...
#       hsync = 1'b0
#       vsync = 1'b0
#       row = 9'd0
#       col = 10'd0
    }
}

module Top(
    clk: clock,
) -> (
    hsync: bool,
    vsync: bool,
    vga_color: { r: uint<8>, g: uint<8>, b: uint<8> },
) {
    let pulses = VGA::SyncPulses(clk, hsync, vsync)
    vga_color = {
        r: pulses.row[7:0],
        g: pulses.col[7:0],
        b: 8'd127,
    }
}
```

- Members declared within a package are accessed using the `::` operator.

- Imported files are implicitly wrapped in a package with the same name as the file.

## Constant Declarations

Constants are named fixed values known at compile-time.

```yodl
const BAUD_RATE = 115200
const CLOCK_FREQ = 100 * 1_000_000 // 100 MHz
const CYCLES_PER_BIT = CLOCK_FREQ / BAUD_RATE
# module Top() -> () {}
```

## Type Alias Declarations

Type aliases are used to give a name to a commonly used type.

```yodl
type U8 = uint<8>
type RGB = { r: U8, g: U8, b: U8 }
# module Top() -> () {}
```

### Parameterised type aliases

Type aliases can be parameterised by providing a list of type parameters.

```yodl
type Triplet<T> = (T, T, T)

module Top() -> () {
    let triplet: Triplet<bool> = (true, false, false)
}
```

## Module Declarations

- Modules enable hierarchical design by encapsulating reusable functionality.

- A module is defined by a name, an optional list of parameters, and a list of input and output ports.

```yodl
module FullAdder(
    a: bool,
    b: bool,
    carry_in: bool,
) -> (
    sum: bool,
    carry_out: bool,
) {
    let xor1 = a xor b
    sum = carry_in xor xor1
    carry_out = (carry_in and xor1) or (a and b)
}

# module Top() -> () {}
```

### Parameterised Modules

Modules can be parameterised by specifying a list of parameters surrounded by `<` and `>` after the module name.

```yodl
module Adder<N: uint>(
    a: uint<N>,
    b: uint<N>,
    carry_in: bool,
) -> (
    sum: uint<N>,
    carry_out: bool,
) {
    let carry_chain: bool[N + 1]
    carry_chain[0] = carry_in
    let bits: bool[N]

    for i in 0..<N {
        FullAdder(
            a: a[i],
            b: b[i],
            carry_in: carry_chain[i],
            carry_out: carry_chain[i + 1],
            sum: bits[i],
        )
    }

    carry_out = carry_chain[N]
    sum = uint(bits)
}

# module Top() -> () {}
```

### Module instances

- Module instances are first-class values that can be assigned to variables.

- If a module is parameterised, all the parameters must be specified when creating an instance.

- Parameter names can be omitted if the parameters are specified in the same order as the declaration.

```yodl
module Adder<N: uint>(
    a: uint<N>,
    b: uint<N>,
    carry_in: bool,
) -> (
    sum: uint<N>,
    carry_out: bool,
) {
    let total: uint<N + 1> = a + b + carry_in
    sum = total[N - 1 : 0]
    carry_out = total[N]
}

module Top(clk: clock) -> () {
    let counter = Reg<uint<32>>(clk)
    counter.d = counter.q + 1
    
    let adder = Adder<32>( // or Adder<N: 32>(..)
        a: counter.q,
        b: 32'1,
        carry_in: 1'0,
    )
}
```

- A module instance need not assign all ports as the module's ports are accessible as fields of the instance using the `.` operator.

- Ports whose values are local variables with the same name can omit the right-hand side of the assignment.

All three `Reg` instances in the following example are equivalent.

```yodl
module Top(clk: clock, rst: bool) -> () {
    let reg1 = Reg<uint<32>>(clk: clk, rst: rst)
    let reg2 = Reg<uint<32>>(clk, rst)
    let reg3 = Reg<uint<32>>()

    reg3.clk = clk
    reg3.rst = rst
}
```

## Let Bindings

- A let binding introduces a named value in the current scope.
- Let bindings must be defined inside a module declaration.
- The type of the binding is inferred from the right-hand side of the assignment if present
    otherwise, the type must be explicitly specified.

```yodl
# module Test() -> () {
    let message1: uint<8>[3]
    message1 = "Yo!"
    let message2 = "Hi!"
    let message3: uint<8>[3] = "Hey"
# }
```

## Assignments

If a binding is assigned multiple times, only the last assignment is used.

```yodl
# module Test() -> () {
    let a = true // this first assignment is ignored
    a = false
# }
```

## Block Expressions

Block expressions group multiple statements in a new lexical scope and optionally return a value:

```yodl
# module Test(clk: clock) -> () {
    let result = {
        let a = 5
        let b = 10
        (a + b)  // Last expression becomes the block's value
    }

    $assert(result == 15)
# }
```

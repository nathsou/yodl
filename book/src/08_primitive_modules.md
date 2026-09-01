# Primitive Modules

Yodl provides a few essential modules for building sequential digital circuits.

## Registers

Registers are fundamental storage elements in digital circuits. They store data between clock cycles.

### Basic Register

```yodl live id=ex-basic-register
module Counter(clk: clock) -> (value: u8) {
    let counter = Reg[u8](clk)
    counter.d = counter.q + 1'b1
    value = counter.q
}
```

### Parameters

| Parameter | Sort | Description |
|-----------|------|-------------|
| `T` | `Type` | Data type of the register |


### Ports
| Port | Direction | Type | Description |
|------|-----------|------|-------------|
| `clk` | Input | `clock` | Clock input |
| `d` | Input | `T` | Data input (next state) |
| `en` | Input | `bool` | Enable signal (optional) |
| `rst` | Input | `bool` | Reset signal (optional) |
| `q` | Output | `T` | Data output (current state) |

### Register with Reset

```yodl live id=ex-register-with-reset
module Counter(clk: clock, rst: bool) -> (value: u8) {
    let counter = Reg[u8](clk, rst)
    counter.d = counter.q + 1'b1
    value = counter.q
}
```

When `rst` is asserted, the register's value is synchronously reset to 0.

### Register with Enable

```yodl live id=ex-register-with-enable
module Counter(clk: clock, enable: bool) -> (value: u8) {
    let counter = Reg[u8](clk, en: enable)
    counter.d = counter.q + 1'b1
    value = counter.q
}
```

The register only updates its value when `enable` is asserted.

The same behaviour can be obtained using the `d` port only:

```yodl live id=ex-register-with-enable-2
module Counter(clk: clock, enable: bool) -> (value: u8) {
    let counter = Reg[u8](clk)
    counter.d = enable ? counter.q + 1'b1 : counter.q
    value = counter.q
}
```

### Register with Asynchronous Reset

```yodl live id=ex-register-with-asynchronous-reset
# module Test(clk: clock, rst: bool) -> () {
    let state = RegAsyncReset[u2](clk, rst)
# }
```

With `RegAsyncReset`, the reset signal is asynchronous and takes effect immediately.

## Memory

Memories are arrays of registers that can be read from and written to.

Some configurations may be synthesised as block RAMs in FPGAs.

### Parameters

| Parameter | Sort | Description |
|-----------|------|-------------|
| `T` | `Type` | Data type of each element |
| `Depth` | `Nat` | Number of entries |
| `ReadPorts` | `Nat` | Number of read ports |
| `WritePorts` | `Nat` | Number of write ports |
| `ReadLatency` | `Nat` | Cycles to read |
| `WriteLatency` | `Nat` | Cycles to write |

### Ports

| Port | Direction | Type | Description |
|------|-----|------|-------------|
| `read` | Input | [`ReadPorts`](`clk`: `clock`, `en`: `bool`, `addr`: `uint[clog2!(Depth)]`) | Read port(s) |
| `write` | Input | [`WritePorts`](`clk`: `clock`, `en`: `bool`, `addr`: `uint[clog2!(Depth)]`, `data`: `T`, `mask`: `MemoryMask[T]`) | Write port(s) |
| `q` | Output | [`ReadPorts`]`T` | Read data port(s) |

### Basic Memory

```yodl live id=ex-basic-memory
module RAM(
    clk: clock,
    addr: u10,
    write_data: u8,
    write_enable: bool,
) -> (
    read_data: u8,
) {
    let mem = Memory[
        T: u8,           // Data type
        Depth: 1024,          // Number of entries
        ReadPorts: 1,         // Number of read ports
        WritePorts: 1,        // Number of write ports
        ReadLatency: 1,       // Cycles to read
        WriteLatency: 1,      // Cycles to write
    ](
        read: [(clk: clk, en: true, addr: addr)],
        write: [(clk: clk, en: write_enable, addr: addr, data: write_data, mask: true)],
    )
    
    read_data = mem.q[0]
}
```

### Memory with Write Masking

Write masking allows selective updates to parts of a memory word:

```yodl live id=ex-memory-with-write-masking
module ByteAddressableRAM(
    clk: clock,
    addr: u10,
    write_data: [4]u8,   // 32-bit word as 4 bytes
    byte_mask: [4]bool,       // Which bytes to write
    write_enable: bool,
) -> (
    read_data: u32,
) {
    let mem = Memory[
        T: [4]u8,
        Depth: 1024,
        ReadPorts: 1,
        WritePorts: 1,
        ReadLatency: 1,
        WriteLatency: 1,
    ](
        read: [(clk: clk, en: true, addr: addr)],
        write: [(clk: clk, en: write_enable, addr: addr, data: write_data, mask: byte_mask)],
    )

    read_data = uint!(mem.q[0])
}
```

#### Mask Type

Intuitively, the mask type `MemoryMask[T]` of a data type `T` matches the structure of `T` with each ground type (e.g. `uint[N]`, `sint[N]`, ..) replaced with `bool`.

Examples:

| Data Type | Mask Type |
|-----------|-----------|
| `bool` | `bool` |
| `u8` | `bool` |
| `[4]u32` | `[4]bool` |
| `(a: u8, b: u8)` | `(a: bool, b: bool)` |
| `(a: (b: [64]u16, c: bool))` | `(a: (b: [64]bool, c: bool))` |

<div class="warning">
    Portions of an integer cannot directly be masked in Yodl, just like in Chisel.
    Instead, the integer can be split into smaller parts which can be masked individually.
</div>

To learn more about write masks, check out the [FIRRTL specification](https://github.com/chipsalliance/firrtl-spec/blob/main/spec.md#write-ports).

# Primitive Modules

Yodl provides a few essential modules for building sequential digital circuits.

## Registers

Registers are fundamental storage elements in digital circuits. They store data between clock cycles.

### Basic Register

```yodl
module Counter(clk: clock) -> (value: uint<8>) {
    let counter = Reg<uint<8>>(clk);
    counter.d = counter.q + 1'b1;
    value = counter.q;
}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `T` | type | Data type of the register |


### Ports
| Port | Direction | Type | Description |
|------|-----------|------|-------------|
| `clk` | Input | `clock` | Clock input |
| `d` | Input | `T` | Data input (next state) |
| `en` | Input | `bool` | Enable signal (optional) |
| `rst` | Input | `bool` | Reset signal (optional) |
| `q` | Output | `T` | Data output (current state) |

### Register with Reset

```yodl
module Counter(clk: clock, rst: bool) -> (value: uint<8>) {
    let counter = Reg<uint<8>>(clk, rst);
    counter.d = counter.q + 1'b1;
    value = counter.q;
}
```

When `rst` is asserted, the register's value is synchronously reset to 0.

### Register with Enable

```yodl
module Counter(clk: clock, enable: bool) -> (value: uint<8>) {
    let counter = Reg<uint<8>>(clk, en: enable);
    counter.d = counter.q + 1'b1;
    value = counter.q;
}
```

The register only updates its value when `enable` is asserted.

The same behaviour can be obtained using the `d` port only:

```yodl
module Counter(clk: clock, enable: bool) -> (value: uint<8>) {
    let counter = Reg<uint<8>>(clk);
    counter.d = enable ? counter.q + 1'b1 : counter.q;
    value = counter.q;
}
```

### Register with Asynchronous Reset

```yodl
let state = RegAsyncReset<uint<2>>(clk, rst);
```

With `RegAsyncReset`, the reset signal is asynchronous and takes effect immediately.

   <!-- #|@internal
    #|declare module Memory<
    #|  T: type,
    #|  Depth: uint,
    #|  ReadPorts: uint,
    #|  WritePorts: uint,
    #|  Mask: type,
    #|  ReadLatency: uint,
    #|  WriteLatency: uint,
    #| >(
    #|    read: { clk: clock, en: bool, addr: uint<$clog2(Depth)> }[ReadPorts],
    #|    write: { clk: clock, en: bool, addr: uint<$clog2(Depth)>, data: T, mask: Mask }[WritePorts],
    #|) -> (
    #|    q: T[ReadPorts],
    #|) -->

## Memory

Memories are arrays of registers that can be read from and written to.

Some configurations may be synthesised as block RAMs in FPGAs.

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `T` | type | Data type of each element |
| `Depth` | uint | Number of entries |
| `ReadPorts` | uint | Number of read ports |
| `WritePorts` | uint | Number of write ports |
| `ReadLatency` | uint | Cycles to read |
| `WriteLatency` | uint | Cycles to write |

### Ports

| Port | Direction | Type | Description |
|------|-----|------|-------------|
| `read` | Input | {`clk`: `clock`, `en`: `bool`, `addr`: `uint<$clog2(Depth)>`}[`ReadPorts`] | Read port(s) |
| `write` | Input | {`clk`: `clock`, `en`: `bool`, `addr`: `uint<$clog2(Depth)>`, `data`: `T`, `mask`: `MemoryMask<T>`}[`WritePorts`] | Write port(s) |
| `q` | Output | `T`[`ReadPorts`] | Read data port(s) |

### Basic Memory

```yodl
module RAM(
    clk: clock,
    addr: uint<10>,
    write_data: uint<8>,
    write_enable: bool,
) -> (
    read_data: uint<8>,
) {
    let mem = Memory<
        T: uint<8>,           // Data type
        Depth: 1024,          // Number of entries
        ReadPorts: 1,         // Number of read ports
        WritePorts: 1,        // Number of write ports
        ReadLatency: 1,       // Cycles to read
        WriteLatency: 1,      // Cycles to write
    >(
        read: [{ clk, en: true, addr }],
        write: [{ clk, en: write_enable, addr, data: write_data, mask: true }],
    );
    
    read_data = mem.q[0];
}
```

### Memory with Write Masking

Write masking allows selective updates to parts of a memory word:

```yodl
module ByteAddressableRAM(
    clk: clock,
    addr: uint<10>,
    write_data: uint<8>[4],   // 32-bit word as 4 bytes
    byte_mask: bool[4],       // Which bytes to write
    write_enable: bool,
) -> (
    read_data: uint<32>,
) {
    let mem = Memory<
        T: uint<8>[4],
        Depth: 1024,
        ReadPorts: 1,
        WritePorts: 1,
        ReadLatency: 1,
        WriteLatency: 1,
    >(
        read: [{ clk, en: true, addr }],
        write: [{ clk, en: write_enable, addr, data: write_data, mask: byte_mask }],
    );

    read_data = uint(mem.q[0]);
}
```

#### Mask Type

Intuitively, the mask type `MemoryMask<T>` of a data type `T` matches the structure of `T` with each ground type (e.g. `uint<N>`, `sint<N>`, ..) replaced with `bool`.

Examples:

| Data Type | Mask Type |
|-----------|-----------|
| `bool` | `bool` |
| `uint<8>` | `bool` |
| `uint<32>[4]` | `bool[4]` |
| `{a: uint<8>, b: uint<8>}` | `{a: bool, b: bool}` |
| `{a: {b: uint<16>[64], c: bool}}` | `{a: {b: bool[64], c: bool}}` |

<div class="warning">
    Portions of an integer cannot directly be masked in Yodl, just like in Chisel.
    Instead, the integer can be split into smaller parts which can be masked individually.
</div>

To learn more about write masks, check out the [FIRRTL specification](https://github.com/chipsalliance/firrtl-spec/blob/main/spec.md#write-ports).

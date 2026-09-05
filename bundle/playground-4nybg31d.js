import{a as ve,b as Ce,c as Te,d as Me,e as C,f as W,g as pe,h as He,i as De}from"./chunk-qqzxw519.js";import{j as y,m as Oe}from"./chunk-h0yppet7.js";import"./chunk-wv6qjh5b.js";var xe={"01_presentation":[{id:"gates",title:"Your first circuit"}],"02_getting_started":[{id:"gates",title:"Your first circuit"},{id:"counter",title:"Describe the next state"}],"03_data_types":[{id:"widths",title:"Give every bit a place"},{id:"records",title:"Name a group of signals"}],"04_constructs":[{id:"modules",title:"Connect reusable modules"},{id:"generics",title:"Parameterise a design"},{id:"packages",title:"Organise a design"}],"05_operators":[{id:"bits",title:"Take signals apart"}],"06_control_flow":[{id:"selection",title:"Choose a signal"},{id:"vectors",title:"Build parallel hardware"}],"07_built_in_functions":[{id:"bits",title:"Take signals apart"},{id:"counter",title:"Describe the next state"}],"08_primitive_modules":[{id:"registers",title:"Remember a value"},{id:"memory",title:"Store a small table"}],"09_external_modules":[{id:"modules",title:"Connect reusable modules"}]};var ke=[{id:"gates",title:"Your first circuit",topic:"Signals & modules",intro:"A Yodl program describes hardware. A module connects named inputs to named outputs; the connections operate continuously.",concepts:["bool is a one-bit signal.","The expression a and b describes a logic gate. It does not wait for a clock."],observe:"In FIRRTL, find the two input ports, the output port, and the and operation.",challenge:"Change and to xor. The output will describe a gate that is high when exactly one input is high.",stage:"write_firrtl",file:"01-gates.yodl"},{id:"widths",title:"Give every bit a place",topic:"Integers & arithmetic",intro:"Hardware signals have fixed widths. u8 is an unsigned eight-bit integer; s8 is a signed eight-bit integer. Choose the output width to retain the bits you need.",concepts:["Adding two eight-bit unsigned values can require nine bits.","Sized literals spell out width and base: 8'hFF is eight bits of hexadecimal FF. Signedness changes require an explicit cast."],observe:"Inspect the nine-bit sum and sixteen-bit product ports. Switch to Typed to see expression types.",challenge:"Change sum from u9 to u8. Narrowing keeps the low eight bits, so a carry no longer fits in the output.",stage:"write_firrtl",file:"02-widths.yodl"},{id:"selection",title:"Choose a signal",topic:"Conditions & multiplexers",intro:"Conditions select between signals. Both alternatives describe hardware; a condition does not make the circuit execute one software branch at a time.",concepts:["Use if for a two-way choice.","Use match for several cases, with _ as the default."],observe:"Look for mux operations in FIRRTL: these are the signal selectors described by the conditions.",challenge:"Add a 2 case to match that returns a xor b. Keep the default case.",stage:"write_firrtl",file:"03-selection.yodl"},{id:"bits",title:"Take signals apart",topic:"Slices & built-ins",intro:"Individual bits and slices let you work with the representation of a value. Built-in functions have names ending in !.",concepts:["word[7:4] takes bits seven through four, inclusive.","cat! joins bit strings in order; xorr reduces a signal to its parity bit."],observe:"Find bits, cat, and xorr operations in the FIRRTL output.",challenge:"Change swapped to cat!(low, low). Both halves of the output now come from the same four input bits.",stage:"write_firrtl",file:"04-bits.yodl"},{id:"vectors",title:"Build parallel hardware",topic:"Vectors & loops",intro:"A vector groups a fixed number of values. A for loop creates repeated hardware at compile time, so the loop bounds must be known before the circuit runs.",concepts:["[4]u8 is four eight-bit elements.","0..<Lanes excludes the upper bound. All four lanes exist in parallel."],observe:"The Simplified output expands the loop into individual assignments. Switch to FIRRTL to see the vector ports.",challenge:"Change Lanes from 4 to 8. Compile again and count the expanded assignments.",stage:"write_simplified",file:"05-vectors.yodl"},{id:"records",title:"Name a group of signals",topic:"Records & type aliases",intro:"Records collect related signals into named fields. A type alias gives the collection a reusable name without allocating storage.",concepts:["Access a field with . followed by its name.","A record spread copies fields; later fields override the copied values."],observe:"Find the r, g, and b fields in the output ports. They remain individual signals within a bundle.",challenge:"Also override b with 0 in muted. Only the red channel will pass through.",stage:"write_firrtl",file:"06-records.yodl"},{id:"modules",title:"Connect reusable circuits",topic:"Instances & ports",intro:"Define a module once and instantiate it wherever you need that hardware. Each instance is a separate circuit with its own connections.",concepts:["Named arguments connect inputs when creating an instance.","Access an instance output with .sum. Top is the entry circuit in this design."],observe:"Find two Adder instances under Top. They share a definition but connect to different inputs.",challenge:"Connect the second adder to a and c instead of b and c.",stage:"write_firrtl",file:"07-modules.yodl"},{id:"generics",title:"Parameterise a design",topic:"Compile-time parameters",intro:"Generic parameters configure hardware before it runs. Nat parameters describe sizes; Type parameters let a module work with different signal types.",concepts:["uint[Width] uses a compile-time width.","Instantiation specialises each generic module with concrete parameters. These parameters are not input ports."],observe:"Monomorphised output shows concrete versions of the generic modules. Compare it with Source.",challenge:"Change the wide input and output from u16 to u12, and change Mask[16] to Mask[12].",stage:"write_mono",file:"08-generics.yodl"},{id:"registers",title:"Remember a value",topic:"Clocked state",intro:"Combinational logic has no memory. Reg adds state: q is the current value and d is the value sampled at the next rising clock edge.",concepts:["Reg[u8] stores eight bits.","rst resets the register to zero synchronously. en controls whether it captures a new value."],observe:"Find the register and its clock, reset, and enable logic in FIRRTL. The output reads the stored q value.",challenge:"Connect en to true instead of enable. The register will capture data on every rising edge unless reset is asserted.",stage:"write_firrtl",file:"09-registers.yodl"},{id:"counter",title:"Describe the next state",topic:"Feedback & constants",intro:"A counter feeds its current register value through combinational logic to compute the next value. The register breaks the feedback path into clock cycles.",concepts:["clog2!(Limit) computes the number of address bits needed for Limit values.","The comparison makes the counter wrap after Limit - 1. Reset establishes the initial zero state."],observe:"Follow the register output through the increment and selection logic back to its input.",challenge:"Change Limit from 10 to 16. The width stays four bits, but the wrap comparison changes.",stage:"write_firrtl",file:"10-counter.yodl"},{id:"packages",title:"Organise a design",topic:"Packages & names",intro:"Packages group declarations under a namespace. Qualified names make it clear where a reusable module belongs.",concepts:["Use :: to access a declaration inside a package.","A file brought in with import is also wrapped in a package named after the file. Larger examples demonstrate imports."],observe:"Find the qualified Logic::Invert name in Source, then switch to FIRRTL to inspect its instance.",challenge:"Add another Invert instance after the first and connect q to its output. Two inversions restore the original signal.",stage:"write_source",file:"11-packages.yodl"},{id:"memory",title:"Store a small table",topic:"Memory & latency",intro:"Memory describes indexed storage with explicit read and write ports. Latency is part of the interface: this design requests a read latency of one cycle.",concepts:["Depth is the number of stored words; T is the type of each word.","Read and write ports carry clocks, addresses, and enables. A true write mask enables the whole byte."],observe:"Find the memory depth, read latency, and write latency in FIRRTL. Compilation shows structure; the playground does not simulate clock cycles.",challenge:"Increase Depth to 32 and change addr from u4 to u5 so every word remains addressable.",stage:"write_firrtl",file:"12-memory.yodl"}];var I={...{"examples/Clock.yodl":`import Text
import Font

module ClockState(
    clk: clock,
    rst: bool,
) -> (
    hours: u8,
    minutes: u8,
    seconds: u8,
) {
    let second = Reg[u8](clk, rst)
    let minute = Reg[u8](clk, rst)
    let hour = Reg[u8](clk, rst)
    let last_second = second.q == 59
    let last_minute = minute.q == 59
    let last_hour = hour.q == 23
    second.d = last_second ? 0 : second.q + 1
    minute.d = last_second ? (last_minute ? 0 : minute.q + 1) : minute.q
    hour.d = last_second and last_minute ? (last_hour ? 0 : hour.q + 1) : hour.q
    hours = hour.q
    minutes = minute.q
    seconds = second.q
}

module TwoDecimalDigits(n: u8) -> (chars: [2]u8) {
    let packed_bcd = cat!((n / 10)[3:0], (n % 10)[3:0])
    chars = Text::Dec[8](n: packed_bcd).chars
}

module ClockText(hours: u8, minutes: u8, seconds: u8) -> (chars: [8]u8) {
    chars = [
        ..TwoDecimalDigits(n: hours).chars,
        ':',
        ..TwoDecimalDigits(n: minutes).chars,
        ':',
        ..TwoDecimalDigits(n: seconds).chars,
    ]
}

@simulation({
    display: { buffer: "pixel", width: 400, height: 300, mode: "binary", packing: "bits32", on_color: 9485933, off_color: 1118744 },
    reset: "rst",
    clock_hz: 1,
})
module ClockSim(
    clk: clock,
    rst: bool,
) -> (
    pixel: [300][13]u32,
    seconds: u8,
) {
    let state = ClockState(clk, rst)
    seconds = state.seconds
    let clock_text = ClockText(hours: state.hours, minutes: state.minutes, seconds: state.seconds).chars
    Font::TextFramebufferWords[Length: 8, Width: 400, Height: 300, PackedWidth: 13, X: 2, Y: 3, Scale: 8](text: clock_text, pixel)
}
`,"examples/RISCV.yodl":`import RISCVCore
import UART
import Reset

module RAM(
    clk: clock,
    addr: u32,
    read_enable: bool,
    write_data: [4]u8,
    mask: [4]bool,
) -> (
    q: u32,
) {
    let mem = Memory[
        T: [4]u8,
        Depth: (6 * 1024) / 4, // 6KB
        ReadPorts: 1,
        WritePorts: 1,
    ](
        read: [(clk: clk, en: read_enable, addr: addr[10:0])],
        write: [(clk: clk, en: true, addr: addr[10:0], data: write_data, mask: mask)],
    )

    readmemh!("prog.hex", mem)

    q = uint!(mem.q[0])
}

// One-hot encoding of MMIO devices
package MemoryMappedIO {
    const LEDs = 0
    const UART_DATA = 1
    const UART_BUSY = 2
}

const CLOCK_FREQ = 100_000_000 // 100 MHz

module Top(
    clk: clock,
    rst_n: bool,
) -> (
    usb_tx: u1,
    led: u8,
    io_led: u24,
) {
    // wait 125 ms for the FPGA to configure
    let power_reset = Reset::PowerOnReset[CLOCK_FREQ / 8](clk)
    let rst = power_reset.rst or (not rst_n)

    let slow_clk = {
        let counter = Reg[u2](clk, rst)
        counter.d = counter.q + 1'b1
        clock!(counter.q[1])
    }

    let ram = RAM(clk: slow_clk)
    let cpu = RISCVCore::CPU(
        clk: slow_clk,
        rst,
        mem_read_busy: false,
        mem_write_busy: false
    )

    let word_addr = cat!(2'b0, cpu.mem_addr[31:2]) // divide by 4
    ram.addr = word_addr

    let is_io = cpu.mem_addr[22]
    let is_ram = not is_io
    
    ram.read_enable = is_ram and cpu.mem_read_enable
    ram.write_data = cpu.mem_write_data
    ram.mask = is_ram ? cpu.mem_write_mask : fill!(4, false)
    let write_enable = orr uint!(cpu.mem_write_mask)

    // devices
    let leds = Reg[u32](clk: slow_clk, rst)
    let uart_valid = is_io and write_enable and word_addr[MemoryMappedIO::UART_DATA]

    let uart_transmitter = UART::Transmitter[
        ClockFreq: CLOCK_FREQ,
        BaudRate: 921600,
    ](
        clk,
        rst,
        tx: usb_tx,
        data_in: cpu.mem_write_data[0],
        data_valid: uart_valid,
    )

    if is_io and write_enable and word_addr[MemoryMappedIO::LEDs] {
        leds.d = uint!(cpu.mem_write_data)
    }

    if is_io and write_enable and word_addr[MemoryMappedIO::UART_DATA] and uart_transmitter.ready {
        printf!("%c", cpu.mem_write_data[0])
    }

    let io_read_data = word_addr[MemoryMappedIO::UART_BUSY] ?
        cat!(22'b0, not uart_transmitter.ready, 9'b0) :
        32'd0

    cpu.mem_read_data = is_ram ? ram.q : io_read_data

    led = leds.q[7:0]
    io_led = cpu.status
}
`,"examples/FullAdder.yodl":`
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

module Adder[N: Nat](
    a: uint[N],
    b: uint[N],
    carry_in: bool,
) -> (
    sum: uint[N],
    carry_out: bool,
) {
    let carry_chain: [N + 1]bool
    carry_chain[0] = carry_in
    let bits: [N]bool

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
    sum = uint!(bits)
}

module Top(
    clk: clock,
) -> (
    led: u16,
) {
    let counter = Reg[u32](clk)
    let adder = Adder[32](
        a: counter.q,
        b: 32'1,
        carry_in: 1'0,
    )

    counter.d = adder.sum

    led = adder.sum[31:16]
}
`,"examples/Euler1.yodl":`import Text
import Font

module Euler1(clk: clock, rst: bool) -> (q: u18, is_ready: bool) {
    const N = 1000
    let counter = Reg[uint[clog2!(N)]](clk, rst)
    let is_active = counter.q < N
    counter.d = counter.q + is_active
    let sum = Reg[u18](clk, en: is_active, rst, q)
    let is_divisible = counter.q % 3 == 0 or counter.q % 5 == 0
    sum.d = sum.q + (is_divisible ? counter.q : 0)
    is_ready = not is_active
}

@simulation({
    display: { buffer: "pixel", width: 400, height: 300, mode: "binary", packing: "bits32", on_color: 16096865, off_color: 1773349 },
    reset: "rst",
    clock_hz: 60,
})
module Euler1Sim(
    clk: clock,
    rst: bool,
) -> (
    pixel: [300][13]u32,
    value: u18,
) {
    let euler = Euler1(clk, rst)
    value = euler.q
    let hex = Text::Hex[20](n: cat!(2'0, euler.q)).chars
    let message = [.."Euler 1: ", ..hex]
    Font::TextFramebufferWords[Length: 14, Width: 400, Height: 300, PackedWidth: 13, X: 2, Y: 4, Scale: 8](text: message, pixel)
}
`,"examples/Hello.yodl":`import Font

@simulation({
    display: { buffer: "pixel", width: 400, height: 300, mode: "binary", packing: "bits32", on_color: 8116210, off_color: 1056800 },
})
module HelloSim() -> (pixel: [300][13]u32) {
    let message = "YODL; Yet anOther Description Language by Nathan Soufflet!"
    Font::TextFramebufferWords[Length: 58, Width: 400, Height: 300, PackedWidth: 13, X: 1, Y: 2, Scale: 8](text: message, pixel)
}
`,"examples/ExternalModule.yodl":`
// https://github.com/TimRudy/ice-chips-verilog/blob/09471fc7fb6053074549a5c6d51e92676c0d8df6/source-7400/7474.v
@external("ttl_7474", "7474.v")
@parameters({ BLOCKS: 4, DELAY_RISE: 0, DELAY_FALL: 0 })
declare module U74x74(
    Preset_bar: [2]bool,
    Clear_bar: [2]bool,
    D: [2]bool,
    clk: [2]clock,
) -> (
    Q: [2]bool,
    Q_bar: [2]bool,
)

module Top(
    clk: clock,
    rst: bool,
    button: u4,
) -> (
    led: u4,
) {
    let u74x74 = U74x74(
        Preset_bar: [1'b1, 1'b1],
        Clear_bar: [rst, rst],
        D: [button[0], button[1]],
        clk: [clk, clk],
    )

    led = cat!(fill!(4, u74x74.Q[0]))
}
`,"examples/GameOfLife.yodl":`// Fully parallel game of life simulation
// adapted from https://k155la3.blog/2020/10/09/conways-game-of-life-on-fpga/

const LIFE_ROWS = 480 / 16
const LIFE_COLS = 640 / 16

module GameOfLifePattern() -> (pattern: [LIFE_ROWS][LIFE_COLS]bool) {
    pattern = [
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000010000000000000]),
        rev!([..40'b0000000000000000000000001010000000000000]),
        rev!([..40'b0000000000000011000000110000000000001100]),
        rev!([..40'b0000000000000100010000110000000000001100]),
        rev!([..40'b0011000000001000001000110000000000000000]),
        rev!([..40'b0011000000001000101100001010000000000000]),
        rev!([..40'b0000000000001000001000000010000000000000]),
        rev!([..40'b0000000000000100010000000000000000000000]),
        rev!([..40'b0000000000000011000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000000000]),
        rev!([..40'b0000000000000000000000000000000000001100]),
        rev!([..40'b0000000000000000000000000000000000001010]),
        rev!([..40'b0000000000000000000000000000000000000010]),
        rev!([..40'b0000000000000000000000000000000000000011]),
        rev!([..40'b0000000000000000000000000000000000000000]),
    ]
}

// One clk edge advances one Game of Life generation. The vector register
// keeps all 1,200 cells in one sequential object.
@simulation({
    display: { buffer: "state" },
    reset: "init",
})
module GameOfLifeSim(
    clk: clock,
    rst: bool,
    init: bool,
) -> (
    state: [LIFE_ROWS][LIFE_COLS]bool,
    ready: bool,
) {
    let pattern = GameOfLifePattern().pattern
    let cells = Reg[[LIFE_ROWS][LIFE_COLS]bool](clk, rst)

    for row in 0..<LIFE_ROWS {
        for col in 0..<LIFE_COLS {
            const prev_row = row == 0 ? LIFE_ROWS - 1 : row - 1
            const next_row = row == LIFE_ROWS - 1 ? 0 : row + 1
            const prev_col = col == 0 ? LIFE_COLS - 1 : col - 1
            const next_col = col == LIFE_COLS - 1 ? 0 : col + 1

            let count: u3 = cells.q[prev_row][prev_col] + cells.q[prev_row][col] + cells.q[prev_row][next_col] +
                            cells.q[row][prev_col] + cells.q[row][next_col] +
                            cells.q[next_row][prev_col] + cells.q[next_row][col] + cells.q[next_row][next_col]
            cells.d[row][col] = if init {
                pattern[row][col]
            } else {
                match count {
                    3'd2 => cells.q[row][col]
                    3'd3 => true
                    _ => false
                }
            }
            state[row][col] = cells.q[row][col]
        }
    }
    ready = init ? 1'b0 : 1'b1
}

// Conventional CLI entry point with the same semantic outputs as GameOfLifeSim.
// It deliberately exposes the logical cell state instead of display timing.
module Top(
    clk: clock,
    rst: bool,
    init: bool,
) -> (
    state: [LIFE_ROWS][LIFE_COLS]bool,
    ready: bool,
) {
    let life = GameOfLifeSim(clk, rst, init)
    state = life.state
    ready = life.ready
}
`,"examples/Noise.yodl":`// A logical framebuffer: one clock edge advances one complete noise frame.
// Each pixel consumes the next 32-bit LFSR state in row-major order.
// Keep the logical image small for interactive execution; use canvas zoom.
const WIDTH = 80
const HEIGHT = 60

@simulation({ display: { buffer: "pixel" }, reset: "rst" })
module NoiseSim(clk: clock, rst: bool) -> (pixel: [HEIGHT][WIDTH]u24) {
    let seed = Reg[u32](clk, rst)
    let samples: [WIDTH * HEIGHT + 1]u32
    samples[0] = seed.q

    for row in 0..<HEIGHT {
        for col in 0..<WIDTH {
            const i = row * WIDTH + col
            let random = samples[i]
            let feedback = random[31] xnor random[21] xnor random[1] xnor random[0]
            samples[i + 1] = cat!(random[30:0], feedback)

            let r = random[2:0]
            let g = random[5:3]
            let b = random[8:6]
            // Expand each three-bit channel to eight bits for RGB output.
            pixel[row][col] = cat!(r, r, r[2:1], g, g, g[2:1], b, b, b[2:1])
        }
    }
    seed.d = samples[WIDTH * HEIGHT]
}
`,"examples/Image.yodl":`// A 40x30 (4x decimated) extract of res/york.mem, packed as eight 3-bit
// palette indices per u24 word.
@simulation({
    display: { buffer: "pixel" },
})
module ImageSim() -> (pixel: [30][40]u24) {
    const image: [30][5]u24 = [
        [0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0],
        [196608, 0, 0, 0, 8654144],
        [2088960, 0, 0, 0, 1464952],
        [14032192, 5, 0, 14376960, 16055925],
        [14146472, 62, 0, 11984896, 9437039],
        [14343543, 53, 0, 12025856, 6265125],
        [12245941, 438, 0, 12550144, 16554303],
        [12283317, 16552886, 16776783, 16764543, 2422975],
        [14368118, 15007670, 16028623, 16252927, 2521199],
        [13557102, 12283830, 14118270, 16228334, 16556031],
        [12049454, 16702381, 16448447, 9671247, 9586980],
        [13781998, 12049333, 3922879, 16750713, 2510415],
        [14420846, 14146486, 3660735, 16751097, 2400039],
        [14380470, 12049334, 3464127, 16775673, 15105639],
        [2583499, 11984207, 16215406, 16752639, 16244735],
        [2498505, 12243913, 8254429, 16777215, 16711679],
        [2610907, 11983689, 15637245, 4768719, 2995986],
        [14996447, 12049289, 16666191, 4856319, 9582354],
        [2441087, 12050279, 16664697, 5118463, 6862610],
        [9600603, 16241497, 16664895, 4756479, 6859034],
        [8879867, 16244604, 4016487, 6856655, 8692698],
        [7806825, 16555899, 3281529, 4756044, 6689636],
        [3637244, 2472443, 8688201, 7452443, 9314250],
        [3665983, 9288188, 8688227, 5322849, 5392666],
        [3604335, 2410809, 9585249, 9586468, 8688227],
        [16187391, 2396793, 9488457, 9550052, 7190307],
        [14684159, 2593791, 9582881, 9585436, 7190812],
        [16777215, 16777215, 9586767, 7194915, 9549387],
    ]
    for row in 0..<30 {
        for col in 0..<40 {
            let palette_index = (image[row][col / 8] shr ((col % 8) * 3))[2:0]
            pixel[row][col] = match palette_index {
                3'd0 => 24'h6DB6FF
                3'd1 => 24'h494949
                3'd2 => 24'h000000
                3'd3 => 24'h242400
                3'd4 => 24'h242424
                3'd5 => 24'hFFFFDB
                3'd6 => 24'hFFFFFF
                _ => 24'h6D6D6D
            }
        }
    }
}
`,"examples/Assert.yodl":`
module Top(clk: clock) -> () {
    // static assertions checked by firtool

    // uint casting
    assert!(uint!(4'b1000) == 4'b1000)
    assert!(uint!([1'b0, 1'b0, 1'b0, 1'b1]) == 4'b1000)
    assert!(uint!([..4'b1000]) == 4'b1000)
    assert!(uint!([4'hA, 4'hB]) == 8'hBA)

    // clock casting
    assert!(uint!(clock!(1'b1)) == 1'b1)

    // concatenation
    assert!(cat!(8'hBA, 8'hFA) == 16'hBAFA)
    assert!(cat!([8'hBE, 8'hEF]) == 16'hBEEF)

    // decomposition
    assert!([..4'b1000][0] == 1'b0)
    assert!([..4'b1000][1] == 1'b0)
    assert!([..4'b1000][2] == 1'b0)
    assert!([..4'b1000][3] == 1'b1)
    assert!([.."yo!"][0] == 8'd121)

    // arithmetical operators
    assert!(1998 + 2025 == 4023)
    assert!(2025 - 1998 == 27)
    assert!(not 16'd1998 == 16'63537)
    assert!(sint!(63538) == -1998)
    assert!(sint!(1998) - sint!(2025) == -27)
    assert!(1998 * 2025 == 4045950)
    assert!(4045950 / 2025 == 1998)
    assert!(2025 % 1998 == 27)
    
    // reduction operators
    assert!(orr 4'b1000 == 1'b1)
    assert!(orr 4'b1111 == 1'b1)
    assert!(orr 4'd0 == 1'b0)

    assert!(andr 4'b1000 == 1'b0)
    assert!(andr 4'd0 == 1'b0)
    assert!(andr 4'b1111 == 1'b1)

    assert!(xorr 4'b1000 == 1'b1)
    assert!(xorr 4'b1111 == 1'b0)
    assert!(xorr 4'd0 == 1'b0)
    
    printf!("All assertions passed")
}
`,"examples/lib/LFSR.yodl":`
// Linear Feedback Shift Register
module LFSR[NumBits: Nat](
    clk: clock,
    enable: bool,
    rst?: bool,
) -> (
    q: uint[NumBits],
    done: bool,
) {
    let r_lfsr = Reg[uint[NumBits]](clk, en: enable, rst, q)

    // https://docs.amd.com/v/u/en-US/xapp052
    let feedback = match NumBits {
        3 => r_lfsr.q[2] xnor r_lfsr.q[1]
        4 => r_lfsr.q[3] xnor r_lfsr.q[2]
        5 => r_lfsr.q[4] xnor r_lfsr.q[2]
        6 => r_lfsr.q[5] xnor r_lfsr.q[4]
        7 => r_lfsr.q[6] xnor r_lfsr.q[5]
        8 => r_lfsr.q[7] xnor r_lfsr.q[5] xnor r_lfsr.q[4] xnor r_lfsr.q[3]
        9 => r_lfsr.q[8] xnor r_lfsr.q[4]
        10 => r_lfsr.q[9] xnor r_lfsr.q[6]
        11 => r_lfsr.q[10] xnor r_lfsr.q[8]
        12 => r_lfsr.q[11] xnor r_lfsr.q[5] xnor r_lfsr.q[3] xnor r_lfsr.q[0]
        13 => r_lfsr.q[12] xnor r_lfsr.q[3] xnor r_lfsr.q[2] xnor r_lfsr.q[0]
        14 => r_lfsr.q[13] xnor r_lfsr.q[4] xnor r_lfsr.q[2] xnor r_lfsr.q[0]
        15 => r_lfsr.q[14] xnor r_lfsr.q[13]
        16 => r_lfsr.q[15] xnor r_lfsr.q[14] xnor r_lfsr.q[12] xnor r_lfsr.q[3]
        17 => r_lfsr.q[16] xnor r_lfsr.q[13]
        18 => r_lfsr.q[17] xnor r_lfsr.q[10]
        19 => r_lfsr.q[18] xnor r_lfsr.q[5] xnor r_lfsr.q[1] xnor r_lfsr.q[0]
        20 => r_lfsr.q[19] xnor r_lfsr.q[16]
        21 => r_lfsr.q[20] xnor r_lfsr.q[18]
        22 => r_lfsr.q[21] xnor r_lfsr.q[20]
        23 => r_lfsr.q[22] xnor r_lfsr.q[17]
        24 => r_lfsr.q[23] xnor r_lfsr.q[22] xnor r_lfsr.q[21] xnor r_lfsr.q[16]
        25 => r_lfsr.q[24] xnor r_lfsr.q[21]
        26 => r_lfsr.q[25] xnor r_lfsr.q[5] xnor r_lfsr.q[1] xnor r_lfsr.q[0]
        27 => r_lfsr.q[26] xnor r_lfsr.q[4] xnor r_lfsr.q[1] xnor r_lfsr.q[0]
        28 => r_lfsr.q[27] xnor r_lfsr.q[24]
        29 => r_lfsr.q[28] xnor r_lfsr.q[26]
        30 => r_lfsr.q[29] xnor r_lfsr.q[5] xnor r_lfsr.q[3] xnor r_lfsr.q[0]
        31 => r_lfsr.q[30] xnor r_lfsr.q[27]
        32 => r_lfsr.q[31] xnor r_lfsr.q[21] xnor r_lfsr.q[1] xnor r_lfsr.q[0]
    }

    r_lfsr.d = cat!(r_lfsr.q[NumBits - 2:0], feedback)
    done = r_lfsr.q == 0
}
`,"examples/lib/UART.yodl":`
// https://gist.github.com/olofk/e91fba2572396f55525f8814f05fb33d
module Transmitter[ClockFreq: Nat, BaudRate: Nat](
    clk: clock,
    rst: bool,
    data_in: u8,
    data_valid: bool, 
) -> (
    tx: u1,
    ready: bool,
) {
    const START_VALUE = ClockFreq / BaudRate
    const WIDTH = clog2!(START_VALUE)
    let counter = Reg[uint[WIDTH + 1]](clk, rst)
    let data = Reg[u10](clk, rst)
    let ready_reg = Reg[bool](clk, rst, q: ready)

    if counter.q[WIDTH] and data.q == 0 {
        ready_reg.d = true
    } else if data_valid and ready_reg.q {
        ready_reg.d = false
    }

    // if counter underflows
    if ready_reg.q or counter.q[WIDTH] {
        counter.d = uint!(cat!(1'0, START_VALUE))
    } else {
        counter.d = counter.q - 1'd1
    }

    if counter.q[WIDTH] {
        data.d = cat!(1'b0, data.q[9:1])
    } else if data_valid and ready_reg.q {
        data.d = cat!(1'b1, data_in, 1'b0)
    }

    tx = data.q[0] or data.q == 0
}
`,"examples/lib/Timing.yodl":`
// outputs a 1 on \`q\` for one clock cycle once every \`Cycles\` clock cycles
module Timer[Cycles: Nat](clk: clock) -> (q: bool, dffs: uint[clog2!(Cycles)]) {
    const Width = clog2!(Cycles)
    let counter = Reg[uint[Width]](clk)
    let end = counter.q == Cycles
    counter.d = end ? uint!(fill!(Width, 1'0)) : counter.q + 1
    q = end
    dffs = counter.q
}

module Counter[Width: Nat](clk: clock, en: bool, rst: bool) -> (q: uint[Width]) {
    let counter = Reg[uint[Width]](clk, en, rst)
    counter.d = counter.q + 1'1
    q = counter.q
}
`,"examples/lib/RISCVCore.yodl":`// https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV/README.md

package Inst {
    const ALU_REG = 7'b0110011 // rd <- rs1 OP rs2
    const ALU_IMM = 7'b0010011 // rd <- rs1 OP Iimm
    const BRANCH = 7'b1100011 // if(rs1 OP rs2) PC<-PC+Bimm
    const JALR = 7'b1100111 // rd <- PC+4 PC<-rs1+Iimm
    const JAL = 7'b1101111 // rd <- PC+4 PC<-PC+Jimm
    const AUIPC = 7'b0010111 // rd <- PC + Uimm
    const LUI = 7'b0110111 // rd <- Uimm
    const LOAD = 7'b0000011 // rd <- mem[rs1+Iimm]
    const STORE = 7'b0100011 // mem[rs1+Simm] <- rs2
    const SYSTEM = 7'b1110011 // special
}

package Stage {
    const FETCH_INST = 3'd0
    const WAIT_INST = 3'd1
    const DECODE = 3'd2
    const EXECUTE = 3'd3
    const WAIT_DATA = 3'd4
    const WAIT_WRITE = 3'd5
}

module RegisterFile(
    clk: clock,
    rs1_addr: u5,
    rs2_addr: u5,
    rd_addr: u5,
    rd_data: u32,
    write_enable: bool,
) -> (
    rs1: u32,
    rs2: u32,
) {
    let regs = Memory[
        T: u32,
        Depth: 32,
        ReadPorts: 2,
        WritePorts: 1,
        ReadLatency: 0,
        WriteLatency: 1,
    ](
        read: [
            (clk: clk, en: true, addr: rs1_addr),
            (clk: clk, en: true, addr: rs2_addr),
        ],
        write: [
            (clk: clk, en: write_enable, addr: rd_addr, data: rd_data, mask: true),
        ],
    )

    rs1 = regs.q[0]
    rs2 = regs.q[1]
}

module CPU(
    clk: clock,
    rst: bool,
    mem_read_data: u32,
    mem_read_busy: bool,
    mem_write_busy: bool,
) -> (
    mem_addr: u32,
    mem_read_enable: bool,
    mem_write_data: [4]u8,
    mem_write_mask: [4]bool,
    status: u24,
) {
    let inst = Reg[u32](clk, rst)
    let opcode = inst.q[6:0]
    let is_alu_reg = opcode == Inst::ALU_REG
    let is_alu_imm = opcode == Inst::ALU_IMM
    let is_branch = opcode == Inst::BRANCH
    let is_jalr = opcode == Inst::JALR
    let is_jal = opcode == Inst::JAL
    let is_auipc = opcode == Inst::AUIPC
    let is_lui = opcode == Inst::LUI
    let is_load = opcode == Inst::LOAD
    let is_store = opcode == Inst::STORE
    let is_system = opcode == Inst::SYSTEM

    let imm_u = cat!(inst.q[31:12], 12'0)
    let imm_i = uint!(pad!(sint!(inst.q[31:20]), 32))
    let imm_s = uint!(pad!(sint!(cat!(inst.q[31:25], inst.q[11:7])), 32))
    let imm_b = uint!(pad!(sint!(cat!(inst.q[31], inst.q[7], inst.q[30:25], inst.q[11:8], 1'b0)), 32))
    let imm_j = uint!(pad!(sint!(cat!(inst.q[31], inst.q[19:12], inst.q[20], inst.q[30:21], 1'b0)), 32))

    let stage = Reg[u3](clk, rst)
    let rs1_addr = inst.q[19:15]
    let rs2_addr = inst.q[24:20]
    let rd_addr = inst.q[11:7]

    let funct3 = inst.q[14:12]
    let funct7 = inst.q[31:25]

    let pc = Reg[u32](clk, rst)
    let rs1 = Reg[u32](clk, rst)
    let rs2 = Reg[u32](clk, rst)
    let regs = RegisterFile(clk, rs1_addr, rs2_addr, rd_addr)

    let alu_in1 = rs1.q
    let alu_in2 = is_alu_reg or is_branch ? rs2.q : imm_i
    let alu_plus = alu_in1 + alu_in2
    let alu_minus: u33 = cat!(1'b1, not alu_in2) + cat!(1'b0, alu_in1) + 33'b1
    let alu_equ = alu_minus[31:0] == 32'b0
    let alu_lss_unsigned = alu_minus[32]
    let alu_lss_signed = alu_in1[31] xor alu_in2[31] ? alu_in1[31] : alu_minus[32]
    let shifter_in = funct3 == 3'd1 ? flip!(alu_in1) : alu_in1
    let shifter: u32 = uint!(sint!(cat!(inst.q[30] and alu_in1[31], shifter_in)) shr alu_in2[4:0])
    let left_shift = flip!(shifter)

    let alu_out = match funct3 {
        3'b000 => (funct7[5] and inst.q[5] ? alu_minus : alu_plus)[31:0]
        3'b001 => left_shift
        3'b010 => pad!(alu_lss_signed, 32)
        3'b011 => pad!(alu_lss_unsigned, 32)
        3'b100 => alu_in1 xor alu_in2
        3'b101 => shifter
        3'b110 => alu_in1 or alu_in2
        3'b111 => alu_in1 and alu_in2
    }

    let is_jump_inst = is_jal or is_jalr
    let next_addr: u32 = pc.q + 4
    let inst_imm = inst.q[3] ? imm_j : inst.q[4] ? imm_u : imm_b
    let pc_plus_imm: u32 = pc.q + inst_imm
    let take_branch = match funct3 {
        3'b000 => alu_equ
        3'b001 => not alu_equ
        3'b100 => alu_lss_signed
        3'b101 => not alu_lss_signed
        3'b110 => alu_lss_unsigned
        3'b111 => not alu_lss_unsigned
        _ => false
    }

    let next_pc = (is_branch and take_branch) or is_jal ? pc_plus_imm :
                  is_jalr ? cat!(alu_plus[31:1], 1'b0) :
                  next_addr

    let load_store_addr: u32 = rs1.q + (is_store ? imm_s : imm_i)
    let load_half_word = load_store_addr[1] ? mem_read_data[31:16] : mem_read_data[15:0]
    let load_byte = load_store_addr[0] ? load_half_word[15:8] : load_half_word[7:0]
    let byte_access = funct3[1:0] == 2'd0
    let half_word_access = funct3[1:0] == 2'd1
    let load_sign = (not funct3[2]) and (byte_access ? load_byte[7] : load_half_word[15])
    let load_data = byte_access ? cat!(fill!(24, load_sign), load_byte) :
        half_word_access ? cat!(fill!(16, load_sign), load_half_word) :
        mem_read_data

    let write_back_enable = (stage.q == Stage::EXECUTE and (not is_branch) and (not is_store) and (not is_load)) or
                            (stage.q == Stage::WAIT_DATA and (not mem_read_busy))

    let write_back_data =
        is_jump_inst ? next_addr :
        is_lui ? imm_u :
        is_auipc ? pc_plus_imm :
        is_load ? load_data :
        alu_out

    mem_write_data = rev!([
        load_store_addr[0] ? rs2.q[7:0] : load_store_addr[1] ? rs2.q[15:8] : rs2.q[31:24],
        load_store_addr[1] ? rs2.q[7:0] : rs2.q[23:16],
        load_store_addr[0] ? rs2.q[7:0] : rs2.q[15:8],
        rs2.q[7:0],
    ])

    let mask = byte_access ?
        (load_store_addr[1] ?
        (load_store_addr[0] ? 4'b1000 : 4'b0100) :
        (load_store_addr[0] ? 4'b0010 : 4'b0001)) :
        (half_word_access ? (load_store_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111)

    // Fix #4 (part 1): Hold mem_write_mask HIGH throughout the duration of the write process
    let is_writing = (stage.q == Stage::EXECUTE and is_store) or stage.q == Stage::WAIT_WRITE
    mem_write_mask = is_writing ? [..mask] : fill!(4, false)

    regs.rd_data = write_back_data
    regs.write_enable = write_back_enable and rd_addr != 5'd0

    if rst {
        pc.d = 32'd0
        stage.d = Stage::FETCH_INST
    } else {
        match stage.q {
            Stage::FETCH_INST => {
                stage.d = Stage::WAIT_INST
            }
            Stage::WAIT_INST => {
                if not mem_read_busy {
                    inst.d = mem_read_data
                    stage.d = Stage::DECODE
                }
            }
            Stage::DECODE => {
                // By adding DECODE, inst.d gets successfully clocked into inst.q
                // breaking the critical combinational timing path.
                rs1.d = regs.rs1
                rs2.d = regs.rs2
                stage.d = Stage::EXECUTE
            }
            Stage::EXECUTE => {
                if not is_system {
                    pc.d = next_pc
                    if is_load {
                        stage.d = Stage::WAIT_DATA
                    } else if is_store {
                        stage.d = mem_write_busy ? Stage::WAIT_WRITE : Stage::FETCH_INST
                    } else {
                        stage.d = Stage::FETCH_INST
                    }
                } else {
                    stop!()
                }
            }
            Stage::WAIT_DATA => {
                if not mem_read_busy {
                    stage.d = Stage::FETCH_INST
                }
            }
            Stage::WAIT_WRITE => {
                if not mem_write_busy {
                    stage.d = Stage::FETCH_INST
                }
            }
        }
    }

    mem_addr = stage.q == Stage::FETCH_INST or stage.q == Stage::WAIT_INST ? pc.q : load_store_addr
    let is_fetching = stage.q == Stage::FETCH_INST or stage.q == Stage::WAIT_INST
    let is_loading = (stage.q == Stage::EXECUTE and is_load) or stage.q == Stage::WAIT_DATA
    mem_read_enable = is_fetching or is_loading
    status = cat!(uint!(clk), opcode, 5'd0, stage.q, pc.q[7:0])
}
`,"examples/lib/VGA.yodl":`
const H_ACTIVE = 640
const V_ACTIVE = 480

module SyncPulses(
    pixel_clk: clock, // a roughly 25.175 MHz clock
    rst?: bool,
) -> (
    hsync: bool,
    vsync: bool,
    col: u10,
    row: u10,
    is_active_area: bool,
    new_pixel: bool,
) {
    const H_FRONT_PORCH = 16
    const H_SYNC_PULSE = 96
    const H_BACK_PORCH = 48
    const H_TOTAL = H_ACTIVE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH

    const V_FRONT_PORCH = 10
    const V_SYNC_PULSE = 2
    const V_BACK_PORCH = 33
    const V_TOTAL = V_ACTIVE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH

    let col_reg = Reg[u10](clk: pixel_clk, rst, q: col)
    let row_reg = Reg[u10](clk: pixel_clk, rst, q: row)

    let last_col = col_reg.q == H_TOTAL - 1
    let last_row = row_reg.q == V_TOTAL - 1

    col_reg.d = last_col ? 10'd0 : col_reg.q + 1'1
    row_reg.d = last_col ? (last_row ? 10'd0 : row_reg.q + 1'1) : row_reg.q
    new_pixel = last_col nand last_row

    hsync = (col_reg.q >= (H_ACTIVE + H_FRONT_PORCH)) and (col_reg.q < (H_ACTIVE + H_FRONT_PORCH + H_SYNC_PULSE))
    vsync = (row_reg.q >= (V_ACTIVE + V_FRONT_PORCH)) and (row_reg.q < (V_ACTIVE + V_FRONT_PORCH + V_SYNC_PULSE))
    is_active_area = col_reg.q < H_ACTIVE and row_reg.q < V_ACTIVE
}
`,"examples/lib/Segments.yodl":`
module SevenSegmentDecoder(char: u4) -> (segs: u7) {
    segs = match char {
        4'h0 => 7'b0111111
        4'h1 => 7'b0000110
        4'h2 => 7'b1011011
        4'h3 => 7'b1001111
        4'h4 => 7'b1100110
        4'h5 => 7'b1101101
        4'h6 => 7'b1111101
        4'h7 => 7'b0000111
        4'h8 => 7'b1111111
        4'h9 => 7'b1100111
        4'ha => 7'b1110111
        4'hb => 7'b1111100
        4'hc => 7'b0111001
        4'hd => 7'b1011110
        4'he => 7'b1111001
        4'hf => 7'b1110001
    }
}

module Multi(
    clk: clock,
    rst: bool,
    value: u16,
) -> (
    segs: u8,
    sel: u4,
) {
    let counter = Reg[u13](clk, rst)
    counter.d = counter.q + 1

    let active_seg = match counter.q[12:11] {
        2'b00 => (char: value[3:0], sel: 4'b1110)
        2'b01 => (char: value[7:4], sel: 4'b1101)
        2'b10 => (char: value[11:8], sel: 4'b1011)
        2'b11 => (char: value[15:12], sel: 4'b0111)
    }

    sel = active_seg.sel
    segs = cat!(1'b0, not SevenSegmentDecoder(char: active_seg.char).segs)
}
`,"examples/lib/Text.yodl":`// Numeric text helpers are independent of any display protocol. Framebuffer
// adapters should import Font directly for glyph rasterization.
type Char = u8

module CharAt[Length: Nat, IndexWidth: Nat](
    str: [Length]Char,
    index: uint[IndexWidth],
) -> (
    char: Char,
    is_out_of_bounds: bool,
) {
    is_out_of_bounds = index >= Length
    char = is_out_of_bounds ? ' ' : str[index]
}

module Hex[Bits: Nat](n: uint[Bits]) -> (chars: [cdiv!(Bits, 4)]Char) {
    const Len = cdiv!(Bits, 4)
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

module Dec[Bits: Nat](n: uint[Bits]) -> (chars: [cdiv!(Bits, 4)]Char) {
    const Len = cdiv!(Bits, 4)
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
            _ => '9'
        }
    }
}

module Bin[Bits: Nat](n: uint[Bits]) -> (chars: [Bits]Char) {
    for i in 0..<Bits {
        chars[Bits - 1 - i] = n[i] ? '1' : '0'
    }
}
`,"examples/lib/Font.yodl":`// Character primitives shared by framebuffer adapters.
type Char = u8

module AsciiTable(char: Char) -> (q: u64) {
    q = match char[6:0] {
        7'h21 => 64'h000C000C0C1E1E0C
        7'h22 => 64'h0000000000363636
        7'h23 => 64'h0036367F367F3636
        7'h24 => 64'h000C1F301E033E0C
        7'h25 => 64'h0063660C18336300
        7'h26 => 64'h006E333B6E1C361C
        7'h27 => 64'h0000000000030606
        7'h28 => 64'h00180C0606060C18
        7'h29 => 64'h00060C1818180C06
        7'h2a => 64'h0000663CFF3C6600
        7'h2b => 64'h00000C0C3F0C0C00
        7'h2c => 64'h060C0C0000000000
        7'h2d => 64'h000000003F000000
        7'h2e => 64'h000C0C0000000000
        7'h2f => 64'h000103060C183060
        7'h30 => 64'h003E676F7B73633E
        7'h31 => 64'h003F0C0C0C0C0E0C
        7'h32 => 64'h003F33061C30331E
        7'h33 => 64'h001E33301C30331E
        7'h34 => 64'h0078307F33363C38
        7'h35 => 64'h001E3330301F033F
        7'h36 => 64'h001E33331F03061C
        7'h37 => 64'h000C0C0C1830333F
        7'h38 => 64'h001E33331E33331E
        7'h39 => 64'h000E18303E33331E
        7'h3a => 64'h000C0C00000C0C00
        7'h3b => 64'h060C0C00000C0C00
        7'h3c => 64'h00180C0603060C18
        7'h3d => 64'h00003F00003F0000
        7'h3e => 64'h00060C1830180C06
        7'h3f => 64'h000C000C1830331E
        7'h40 => 64'h001E037B7B7B633E
        7'h41 => 64'h0033333F33331E0C
        7'h42 => 64'h003F66663E66663F
        7'h43 => 64'h003C66030303663C
        7'h44 => 64'h001F36666666361F
        7'h45 => 64'h007F46161E16467F
        7'h46 => 64'h000F06161E16467F
        7'h47 => 64'h007C66730303663C
        7'h48 => 64'h003333333F333333
        7'h49 => 64'h001E0C0C0C0C0C1E
        7'h4a => 64'h001E333330303078
        7'h4b => 64'h006766361E366667
        7'h4c => 64'h007F66460606060F
        7'h4d => 64'h0063636B7F7F7763
        7'h4e => 64'h006363737B6F6763
        7'h4f => 64'h001C36636363361C
        7'h50 => 64'h000F06063E66663F
        7'h51 => 64'h00381E3B3333331E
        7'h52 => 64'h006766363E66663F
        7'h53 => 64'h001E33180C06331E
        7'h54 => 64'h001E0C0C0C0C2D3F
        7'h55 => 64'h003F333333333333
        7'h56 => 64'h000C1E3333333333
        7'h57 => 64'h0063777F6B636363
        7'h58 => 64'h0063361C1C366363
        7'h59 => 64'h001E0C0C1E333333
        7'h5a => 64'h007F664C1831637F
        7'h5b => 64'h001E06060606061E
        7'h5c => 64'h00406030180C0603
        7'h5d => 64'h001E18181818181E
        7'h5e => 64'h0000000063361C08
        7'h5f => 64'hFF00000000000000
        7'h60 => 64'h0000000000180C0C
        7'h61 => 64'h006E333E301E0000
        7'h62 => 64'h003B66663E060607
        7'h63 => 64'h001E3303331E0000
        7'h64 => 64'h006E33333E303038
        7'h65 => 64'h001E033F331E0000
        7'h66 => 64'h000F06060F06361C
        7'h67 => 64'h1F303E33336E0000
        7'h68 => 64'h006766666E360607
        7'h69 => 64'h001E0C0C0C0E000C
        7'h6a => 64'h1E33333030300030
        7'h6b => 64'h0067361E36660607
        7'h6c => 64'h001E0C0C0C0C0C0E
        7'h6d => 64'h00636B7F7F330000
        7'h6e => 64'h00333333331F0000
        7'h6f => 64'h001E3333331E0000
        7'h70 => 64'h0F063E66663B0000
        7'h71 => 64'h78303E33336E0000
        7'h72 => 64'h000F06666E3B0000
        7'h73 => 64'h001F301E033E0000
        7'h74 => 64'h00182C0C0C3E0C08
        7'h75 => 64'h006E333333330000
        7'h76 => 64'h000C1E3333330000
        7'h77 => 64'h00367F7F6B630000
        7'h78 => 64'h0063361C36630000
        7'h79 => 64'h1F303E3333330000
        7'h7a => 64'h003F260C193F0000
        7'h7b => 64'h00380C0C070C0C38
        7'h7c => 64'h0018181800181818
        7'h7d => 64'h00070C0C380C0C07
        7'h7e => 64'h0000000000003B6E
        7'h7f => 64'h007F6363361C0800
        _ => 64'h0000000000000000
    }
}

// Render text into a framebuffer. Glyphs are enlarged to Scale pixels and
// long strings wrap at the framebuffer edge.
module TextFramebuffer[Length: Nat, Width: Nat, Height: Nat, X: Nat, Y: Nat, Scale: Nat](
    text: [Length]Char,
) -> (pixel: [Height][Width]bool) {
    const cells_per_row = Width / Scale
    const chars_per_row = cells_per_row - X
    for row in 0..<Height {
        for col in 0..<Width {
            const cell_x = col / Scale
            const cell_y = row / Scale
            const text_row = cell_y >= Y ? cell_y - Y : 0
            const text_col = cell_x >= X ? cell_x - X : 0
            const text_idx = text_row * chars_per_row + text_col
            const glyph_x0 = ((col % Scale) * 8) / Scale
            const glyph_x1 = (((col % Scale) + 1) * 8) / Scale - 1
            const glyph_y0 = ((row % Scale) * 8) / Scale
            const glyph_y1 = (((row % Scale) + 1) * 8) / Scale - 1
            let char = cell_x >= X and cell_x < cells_per_row and cell_y >= Y and text_idx < Length ? text[text_idx] : ' '
            let bitmap = AsciiTable(char).q
            let row0 = (bitmap shr (glyph_y0 * 8))[glyph_x1:glyph_x0]
            let row1 = (bitmap shr (glyph_y1 * 8))[glyph_x1:glyph_x0]
            pixel[row][col] = orr row0 or orr row1
        }
    }
}

// Bit-packed variant for larger framebuffers. Eight horizontal pixels share
// one output byte.
module TextFramebufferBits[Length: Nat, Width: Nat, Height: Nat, PackedWidth: Nat, X: Nat, Y: Nat, Scale: Nat](
    text: [Length]Char,
) -> (pixel: [Height][PackedWidth]u8) {
    const cells_per_row = Width / Scale
    const chars_per_row = cells_per_row - X
    for row in 0..<Height {
        for packed_col in 0..<PackedWidth {
            let bits = fill!(8, 1'b0)
            for bit in 0..<8 {
                const col = packed_col * 8 + bit
                const cell_x = col / Scale
                const cell_y = row / Scale
                const text_row = cell_y >= Y ? cell_y - Y : 0
                const text_col = cell_x >= X ? cell_x - X : 0
                const text_idx = text_row * chars_per_row + text_col
                const glyph_x0 = ((col % Scale) * 8) / Scale
                const glyph_x1 = (((col % Scale) + 1) * 8) / Scale - 1
                const glyph_y0 = ((row % Scale) * 8) / Scale
                const glyph_y1 = (((row % Scale) + 1) * 8) / Scale - 1
                let char = cell_x >= X and cell_x < cells_per_row and cell_y >= Y and text_idx < Length ? text[text_idx] : ' '
                let bitmap = AsciiTable(char).q
                let row0 = (bitmap shr (glyph_y0 * 8))[glyph_x1:glyph_x0]
                let row1 = (bitmap shr (glyph_y1 * 8))[glyph_x1:glyph_x0]
                bits[bit] = orr row0 or orr row1
            }
            pixel[row][packed_col] = uint!(bits)
        }
    }
}

// Word-packed variant for 400x300 text outputs. At Scale=8 a framebuffer byte
// is exactly one font row; four bytes cover one u32 output word.
module TextFramebufferWords[Length: Nat, Width: Nat, Height: Nat, PackedWidth: Nat, X: Nat, Y: Nat, Scale: Nat](
    text: [Length]Char,
) -> (pixel: [Height][PackedWidth]u32) {
    const cells_per_row = Width / Scale
    const chars_per_word = 4
    const chars_per_row = cells_per_row - X
    for row in 0..<Height {
        const cell_y = row / Scale
        const glyph_y = row % Scale
        const text_row = cell_y >= Y ? cell_y - Y : 0
        for word in 0..<PackedWidth {
            const cell0 = word * chars_per_word
            const cell1 = cell0 + 1
            const cell2 = cell0 + 2
            const cell3 = cell0 + 3
            const idx0 = text_row * chars_per_row + (cell0 >= X ? cell0 - X : 0)
            const idx1 = text_row * chars_per_row + (cell1 >= X ? cell1 - X : 0)
            const idx2 = text_row * chars_per_row + (cell2 >= X ? cell2 - X : 0)
            const idx3 = text_row * chars_per_row + (cell3 >= X ? cell3 - X : 0)
            let char0 = cell0 >= X and cell0 < cells_per_row and cell_y >= Y and idx0 < Length ? text[idx0] : ' '
            let char1 = cell1 >= X and cell1 < cells_per_row and cell_y >= Y and idx1 < Length ? text[idx1] : ' '
            let char2 = cell2 >= X and cell2 < cells_per_row and cell_y >= Y and idx2 < Length ? text[idx2] : ' '
            let char3 = cell3 >= X and cell3 < cells_per_row and cell_y >= Y and idx3 < Length ? text[idx3] : ' '
            let byte0 = (AsciiTable(char: char0).q shr (glyph_y * 8))[7:0]
            let byte1 = (AsciiTable(char: char1).q shr (glyph_y * 8))[7:0]
            let byte2 = (AsciiTable(char: char2).q shr (glyph_y * 8))[7:0]
            let byte3 = (AsciiTable(char: char3).q shr (glyph_y * 8))[7:0]
            pixel[row][word] = cat!(byte3, byte2, byte1, byte0)
        }
    }
}
`,"examples/lib/Reset.yodl":`
module PowerOnReset[ClockCycles: Nat](clk: clock) -> (rst: bool) {
    let counter = Reg[uint[clog2!(ClockCycles)]](clk)

    if counter.q < ClockCycles - 1 {
        counter.d = counter.q + 1'b1
        rst = true
    } else {
        rst = false
    }
}
`},...{"tour/12-memory.yodl":`module Top(clk: clock, addr: u4, data: u8, write_enable: bool) -> (q: u8) {
    let memory = Memory[
        T: u8,
        Depth: 16,
        ReadPorts: 1,
        WritePorts: 1,
        ReadLatency: 1,
        WriteLatency: 1,
    ](
        read: [(clk: clk, en: true, addr: addr)],
        write: [(clk: clk, en: write_enable, addr: addr, data: data, mask: true)],
    )
    q = memory.q[0]
}
`,"tour/10-counter.yodl":`const Limit = 10

module Top(clk: clock, rst: bool) -> (count: uint[clog2!(Limit)]) {
    let state = Reg[uint[clog2!(Limit)]](clk, rst)
    state.d = if state.q == Limit - 1 {
        0
    } else {
        state.q + 1
    }
    count = state.q
}
`,"tour/04-bits.yodl":`module Top(word: u8) -> (swapped: u8, parity: bool) {
    let high = word[7:4]
    let low = word[3:0]
    swapped = cat!(low, high)
    parity = xorr word
}
`,"tour/06-records.yodl":`type Color = (r: u8, g: u8, b: u8)

module Top(color: Color) -> (muted: Color, red: u8) {
    muted = (..color, g: 0)
    red = color.r
}
`,"tour/08-generics.yodl":`module Mask[Width: Nat](value: uint[Width], mask: uint[Width]) -> (
    q: uint[Width],
) {
    q = value and mask
}

module Identity[T: Type](value: T) -> (q: T) {
    q = value
}

module Top(small: u8, wide: u16, flag: bool) -> (a: u8, b: u16, c: bool) {
    a = Mask[8](value: small, mask: 8'h0F).q
    b = Mask[16](value: wide, mask: 16'h00FF).q
    c = Identity[bool](value: flag).q
}
`,"tour/01-gates.yodl":`// Two inputs, one gate, one output.
module Top(a: bool, b: bool) -> (q: bool) {
    q = a and b
}
`,"tour/11-packages.yodl":`package Logic {
    module Invert(value: bool) -> (q: bool) {
        q = not value
    }
}

module Top(value: bool) -> (q: bool) {
    let inverter = Logic::Invert(value: value)
    q = inverter.q
}
`,"tour/02-widths.yodl":`module Top(a: u8, b: u8, offset: s8) -> (
    sum: u9,
    product: u16,
    adjusted: s9,
) {
    sum = a + b
    product = a * b
    adjusted = offset + sint!(8'd1)
}
`,"tour/05-vectors.yodl":`const Lanes = 4

module Top(values: [Lanes]u8, mask: u8) -> (result: [Lanes]u8) {
    for i in 0..<Lanes {
        result[i] = values[i] xor mask
    }
}
`,"tour/07-modules.yodl":`module Adder(a: u8, b: u8) -> (sum: u9) {
    sum = a + b
}

module Top(a: u8, b: u8, c: u8) -> (ab: u9, bc: u9) {
    let first = Adder(a: a, b: b)
    let second = Adder(a: b, b: c)
    ab = first.sum
    bc = second.sum
}
`,"tour/03-selection.yodl":`module Top(a: u8, b: u8, select: bool, operation: u2) -> (
    chosen: u8,
    result: u8,
) {
    chosen = if select {
        a
    } else {
        b
    }
    result = match operation {
        0 => a and b
        1 => a or b
        _ => 0
    }
}
`,"tour/09-registers.yodl":`module Top(clk: clock, rst: bool, enable: bool, data: u8) -> (q: u8) {
    let state = Reg[u8](clk, rst, en: enable)
    state.d = data
    q = state.q
}
`}},h=ke,se=Object.keys(I).filter((e)=>/^examples\/[^/]+\.yodl$/.test(e)).sort(),O="examples/Playground.yodl",ae={mode:"tour",path:`tour/${h[0].file}`,stage:"write_firrtl"};function Y(e){if(!e||typeof e!=="object")return!1;let t=e;return Object.hasOwn(C,t.stage)&&(t.mode==="tour"?h.some((i)=>`tour/${i.file}`===t.path):t.mode==="examples"&&(se.includes(t.path)||t.path===O))}function Le(e){return ve({...e,version:e.entryPath?2:1})}function Ee(e){if(!e.startsWith("#code="))return null;try{let t=Ce(e.slice(6));if(![1,2].includes(t.version)||!Y(t)||typeof t.source!=="string")throw Error();if(t.version===2&&(!Te(t.entryPath)||!Me(t.files)||t.origin!==void 0&&!/^[a-zA-Z0-9_-]+\.html#[a-z0-9-]+$/.test(t.origin)))throw Error();if(t.version===1)return{version:1,mode:t.mode,path:t.path,stage:t.stage,source:t.source};return t}catch{throw Error("This share link is invalid, too large, or uses an unsupported version.")}}var o=(e)=>document.getElementById(e),r=(e)=>o(e),f=(e)=>o(e),ze="yodl-playground-v2:",me=!0;function H(e){try{return localStorage.getItem(ze+e)}catch{return me=!1,null}}function P(e,t){try{localStorage.setItem(ze+e,t)}catch{me=!1}}function j(e){let t=o("notice");t.textContent=e;let i=document.createElement("button");i.textContent="Dismiss",i.addEventListener("click",()=>{t.hidden=!0}),t.append(i),t.hidden=!1}function k(e,t="idle"){o("compile-status").textContent=e,o("compile-status").dataset.state=t}var Je=De(f("theme-select"),(e)=>{if(y)y.editor.setTheme(e?"yodl-dark":"yodl-light")}),c={...ae};try{let e=JSON.parse(H("selection")??"null");if(Y(e))c=e}catch{}var Ne=new URLSearchParams(location.search),re=h.find((e)=>e.id===Ne.get("lesson"));if(re)c={mode:"tour",path:`tour/${re.file}`,stage:re.stage};else if(Ne.get("mode")==="examples")c={mode:"examples",path:O,stage:"write_firrtl"};var D={},R,q,B=null,K="";try{let e=Ee(location.hash);if(e)c={mode:e.mode,path:e.path,stage:e.stage},B=e.source,D=e.files??{},R=e.entryPath,q=e.origin,K=`shared:${location.hash.slice(6)}`,j("Shared circuit opened. Your existing lesson and example drafts are kept separately.")}catch(e){j(e.message)}var l,V=!1,M,g="",N="",b=new Map,J=new Map,m=()=>R??c.path,E=()=>M.getValue();function te(e){let t=e===m()?M:b.get(e);if(!t)return;if(g)J.set(g,l.input.saveViewState());g=e,l.input.setModel(t),l.input.updateOptions({readOnly:e!==m(),ariaLabel:`${e}${e===m()?", main source":", imported, read only"}`});let i=J.get(e);if(i)l.input.restoreViewState(i);he(),l.input.layout()}function he(){let e=g!==m(),t=b.size>0;o("source-files").hidden=!t,o("editors").dataset.imports=String(t),o("input-filename").textContent=g,o("input-filename").title=g,o("source-kind").textContent=e?"Imported · read only":"",o("source-kind").hidden=!e,o("draft-badge").hidden=e||E()===ge(),r("reset-button").disabled=e,o("source-files").replaceChildren(...[m(),...b.keys()].map((i)=>{let n=document.createElement("button");return n.textContent=i.split("/").at(-1),n.title=i===m()?`${i} · compile and simulation target`:`${i} · imported, read only`,n.setAttribute("aria-pressed",String(i===g)),n.onclick=()=>te(i),n}))}function Xe(e){let t=Object.entries(e).filter(([n])=>n!==m()&&n.endsWith(".yodl")),i=new Set(t.map(([n])=>n));if(g!==m()&&!i.has(g))te(m());for(let[n,a]of b)if(!i.has(n))a.dispose(),b.delete(n),J.delete(n);for(let[n,a]of t){let s=b.get(n);if(!s)b.set(n,y.editor.createModel(a,"yodl"));else if(s.getValue()!==a)s.setValue(a)}he()}function Ze(){g="",J.clear(),l.input.setModel(M);for(let e of b.values())e.dispose();b.clear(),te(m())}var X=0,S="",Z=-1,Q,Ve=new pe,je=new pe,le=0,$e;async function qe(){let e=++le,t=await je.compile("imports",{source:E(),path:m(),stage:"write_source",files:{...I,...D}});if(e===le&&t?.sources)Xe(t.sources)}function Qe(){++le,je.cancel("imports"),clearTimeout($e),$e=setTimeout(qe,150)}var T=new He,d="ready",Be=0,ce=0,x=null,_=o("auto-compile");_.checked=H("auto")!=="false";var et=`// Start a new circuit here.
module Top(a: bool) -> (q: bool) {
    q = a
}
`,ie=(e)=>I[e]??et,ge=()=>R&&B!==null?B:ie(c.path);function tt(e){let t=2166136261;for(let i=0;i<e.length;i++)t^=e.charCodeAt(i),t=Math.imul(t,16777619);return(t>>>0).toString(36)}var fe=()=>K||`draft:${c.path}:${tt(ie(c.path))}`;function ee(){return h.findIndex((e)=>`tour/${e.file}`===c.path)}function U(){if(P(fe(),E()),!K)P("selection",JSON.stringify(c));o("save-status").textContent=me?"Draft saved locally":"Draft not saved · storage unavailable",o("draft-badge").hidden=g!==m()||E()===ge()}function Ue(){o("output-pane").dataset.view="output";let e=c.mode==="tour";o("site-section").textContent=e?"tour":"playground",r("tour-mode").setAttribute("aria-pressed",String(e)),r("examples-mode").setAttribute("aria-pressed",String(!e)),o("guide").hidden=!e,o("source-label").textContent=e?"Lesson":"Example";let t=f("source-selector");t.replaceChildren();let i=e?h.map((s,u)=>({value:`tour/${s.file}`,label:`${String(u+1).padStart(2,"0")} · ${s.title}`})):[{value:O,label:"New circuit"},...se.map((s)=>({value:s,label:s.split("/").at(-1)}))];for(let s of i)t.add(new Option(s.label,s.value));t.value=c.path,he();let n=o("related-docs"),a=Object.entries(xe).find(([,s])=>s.some((u)=>u.id===h[ee()]?.id));if(n.hidden=!a&&!q,n.href=`./book/${q??(a?a[0]+".html":"")}`,e){let s=ee(),u=h[s];o("lesson-position").textContent=`${String(s+1).padStart(2,"0")} / ${h.length}`,o("lesson-topic").textContent=u.topic,o("lesson-title").textContent=u.title,o("lesson-intro").textContent=u.intro,o("lesson-observe").textContent=u.observe,o("lesson-challenge").textContent=u.challenge,o("lesson-concepts").replaceChildren(...u.concepts.map((p)=>{let v=document.createElement("li");return v.textContent=p,v})),r("suggested-stage").textContent=`Show ${C[u.stage].label} →`,r("previous-lesson").disabled=s===0,r("next-lesson").disabled=!1,r("next-lesson").textContent=s===h.length-1?"Explore examples →":"Next lesson →"}f("pass-selector").value=c.stage,ye()}function ye(){let e=C[c.stage];o("stage-description").textContent=e.description,o("stage-description").title=e.description,f("pass-selector").title=e.description,o("stage-command").textContent=c.stage,y.editor.setModelLanguage(l.output.getModel(),e.language)}function Ke(){o("problems").hidden=!0,x=null;for(let e of[M,...b.values()])y.editor.setModelMarkers(e,"yodl",[])}function be(){if(Ve.cancel("playground"),T.stop(),d="ready",F(),X++,Qe(),ce=++Be,clearTimeout(Q),Ke(),r("copy-output").disabled=!0,r("download-output").disabled=!0,k(S?"Source changed · output is out of date":"Ready to compile"),_.checked)Q=setTimeout(L,500)}function we(e){if(U(),A([]),K="",B=null,D={},R=void 0,q=void 0,location.hash.startsWith("#code="))history.replaceState(null,"",location.pathname+location.search);c=e,Ze();for(let i of["simulation-top","simulation-clock","simulation-inputs"])o(i).value="";V=!0,l.input.setValue(H(fe())??ie(c.path)),V=!1,l.input.setScrollTop(0),l.output.setValue(""),S="",Z=-1,Ue();let t=new URL(location.href);t.searchParams.delete("lesson"),t.searchParams.delete("mode"),history.replaceState(null,"",t),U(),be()}function ue(e){if(e===c.mode&&!K)return;let t=e==="tour"?ae.path:O,i=H(`last:${e}`);if(Y({mode:e,path:i,stage:"write_firrtl"}))t=i;we({mode:e,path:t,stage:e==="tour"?h.find((n)=>`tour/${n.file}`===t).stage:"write_firrtl"})}function Re(e){A([]),c.stage=e,f("pass-selector").value=e,l.output.setValue(""),S="",ye(),o("output-pane").dataset.view="output",U(),be()}function G(e){o("editors").dataset.view=e,r("source-tab").setAttribute("aria-pressed",String(e==="source")),r("output-tab").setAttribute("aria-pressed",String(e==="output")),l.input.layout(),l.output.layout()}function it(e){if(o("output-pane").dataset.view="output",o("problems").hidden=!1,o("error-message").textContent=e,N=[m(),...b.keys()].find((t)=>W(e,t))??m(),x=W(e,N),r("jump-error").hidden=x===null,x){let t=N===m()?M:b.get(N),i=t.validateRange(x);x=i,y.editor.setModelMarkers(t,"yodl",[{...i,message:e,severity:y.MarkerSeverity.Error}])}k(S?"Compilation failed · showing previous output":"Compilation failed · check diagnostics","error")}async function L(){clearTimeout(Q),T.stop(),d="ready",F(),A([]);let e=++Be;ce=e;let t=X;Ke(),k("Compiling…","loading");let i=await Ve.compile("playground",{source:E(),path:R??c.path,stage:c.stage,files:{...I,...D}});if(!i||e!==ce)return;if(i.error!==void 0){it(i.error);return}S=i.output??"",Z=t,l.output.setValue(S),ye(),o("output-pane").dataset.view="output",r("copy-output").disabled=!S,r("download-output").disabled=!S,k(`✓ Compiled · ${Math.round(i.duration)} ms`,"success")}function We(e){let t={};for(let i of e.split(",")){let n=/^\s*([A-Za-z_$][\w$]*)(?::(\d+))?\s*=\s*(-?\d+)\s*$/.exec(i);if(!i.trim())continue;if(!n)throw Error(`Invalid input assignment: ${i}`);if(!Number.isSafeInteger(Number(n[3])))throw Error("Input exceeds the safe integer range.");t[n[1]]={width:Number(n[2]??32),value:Number(n[3])}}return t}function F(){let e=r("simulation-run"),t=r("simulation-stop");e.textContent=d==="running"||d==="stepping"?"Pause":d==="paused"?"Resume":"Run",e.disabled=d==="starting"||d==="halted",t.disabled=d==="ready"}var Ie,de;function A(e){let t=o("simulation-framebuffer"),i=e.at(-1);if(de=i,o("simulation-zoom-control").hidden=!i,!i){t.hidden=!0;return}if(t.hidden=!1,t.width!==i.width||t.height!==i.height)t.width=i.width,t.height=i.height,Ie=void 0;let n=t.parentElement?.clientWidth||640,a=f("simulation-zoom").value,s=a==="fit"?Math.min(n/i.width,480/i.height):Number(a);t.style.width=`${i.width*s}px`,t.style.height=`${i.height*s}px`;let u=t.getContext("2d");if(!u)return;let p=Ie??=u.createImageData(i.width,i.height),v=Math.ceil(i.width/32);for(let w=0;w<i.width*i.height;w++){let Ye=Math.floor(w/i.width),oe=w%i.width,Se=Ye*v+Math.floor(oe/32),ne=!(!i.valid||(i.packed?(i.valid[Se]&1<<oe%32)!==0:i.valid[w]!==0))?16711935:i.packed?(i.packed[Se]&1<<oe%32)!==0?i.onColor??16777215:i.offColor??0:i.rgb?.[w]??i.pixels?.[w]??0;p.data[w*4]=ne>>>16&255,p.data[w*4+1]=ne>>>8&255,p.data[w*4+2]=ne&255,p.data[w*4+3]=255}u.putImageData(p,0,0)}function ot(e,t,i,n){let a=[`cycles: ${i}`],s=e;for(let u of s.slice(0,100))a.push(`${u.name}: u${u.width} = ${u.known?u.value:"X"}`);if(s.length>100)a.push(`… ${s.length-100} more outputs`);if(t.length)a.push("",...t);o("simulation-output").textContent=a.join(`
`)}function nt(e){let t=o("simulation-inputs-controls"),i=e.map((n)=>`${n.name}:${n.width}:${n.value}:${n.known}`).join("|");if(t.dataset.signature===i)return;t.dataset.signature=i,t.replaceChildren();for(let n of e){let a=document.createElement("label");a.textContent=n.name;let s=document.createElement("input");if(s.dataset.signal=n.name,s.dataset.width=String(n.width),n.width===1)s.type="checkbox",s.checked=n.value!=="0";else s.type="text",s.value=n.value,s.inputMode="numeric",s.title=`u${n.width}`;s.addEventListener("change",()=>{let u=[...t.querySelectorAll("input")].map((p)=>{let v=p.type==="checkbox"?Number(p.checked):p.value;return`${p.dataset.signal}:${p.dataset.width}=${v}`});o("simulation-inputs").value=u.join(", ");try{let p=We(u.join(", "));if(s.setCustomValidity(""),d!=="ready")T.setInputs(p)}catch(p){s.setCustomValidity(String(p)),s.reportValidity()}}),a.append(s),t.append(a)}t.hidden=e.length===0}function _e(e){if(e.type==="error"){d="error",o("simulation-output").textContent=e.error??"Simulation failed.",o("simulation-state").textContent="Error",F(),k("Simulation failed","error");return}if(d=e.type==="halted"?"halted":e.type==="stopped"?"ready":e.type==="stepping"?"stepping":e.type==="frame"||e.type==="resumed"?"running":"paused",e.frame)A([e.frame]);else if(e.metadata&&!e.metadata.display)A([]);if(e.outputs)ot(e.outputs,e.messages??[],e.totalCycles??0,e.frame?.signal);if(e.inputs)nt(e.inputs);if(r("simulation-step-cycle").disabled=!e.clock||d==="halted",r("simulation-step-frame").hidden=!(e.frame&&e.clock),e.metadata){let u={"simulation-top":e.metadata.top,"simulation-clock":e.clock,"simulation-cycles-per-frame":e.playback?.cyclesPerFrame,"simulation-clock-hz":e.playback?.clockHz??"maximum","simulation-refresh-fps":e.playback?.refreshFps};for(let[p,v]of Object.entries(u))o(p).placeholder=String(v??"automatic");o("simulation-cycles-per-frame").disabled=!e.clock||Boolean(e.metadata.display?.stream),o("simulation-clock-hz").disabled=!e.clock,o("simulation-refresh-fps").disabled=!e.clock}let t=e.simulatedSeconds===void 0?"":` · ${e.simulatedSeconds.toFixed(3)} simulated s`,i=e.cyclesPerSecond===void 0?"":` · ${Math.round(e.cyclesPerSecond).toLocaleString()} cycles/s achieved`,n=e.status?.failed??!1,a=n?"Failed":d[0].toUpperCase()+d.slice(1),s=e.status?.exit_code===void 0?"":` · exit ${e.status.exit_code}`;o("simulation-state").textContent=`${a}${s} · ${(e.totalCycles??0).toLocaleString()} cycles${t}${i}`,F(),k(n?`Simulation failed${e.status?.first_failure?`: ${e.status.first_failure.message}`:""}`:d==="running"||d==="stepping"?"Simulating…":`Simulation ${d}`,n?"error":void 0)}async function z(e="run"){G("output");let t=(s)=>{let u=Number(o(s).value);return Number.isFinite(u)&&u>0?u:void 0},i={clockHz:t("simulation-clock-hz"),refreshFps:t("simulation-refresh-fps"),cyclesPerFrame:t("simulation-cycles-per-frame")};if(d!=="ready"&&d!=="error"){if(e==="run")if(d==="running"||d==="stepping")T.pause();else T.resume(i);else T.command(e,i);return}let n=o("simulation-top").value.trim(),a=o("simulation-clock").value.trim();o("output-pane").dataset.view="simulation",o("simulation-state").textContent="Compiling simulation…",d="starting",F();try{T.start({source:E(),path:R??c.path,stage:"write_low_firrtl",files:{...I,...D},simulate:{action:e,...n?{top:n}:{},...a?{clock:a}:{},...Object.fromEntries(Object.entries(i).filter(([,s])=>s!==void 0)),inputs:We(o("simulation-inputs").value)}},_e)}catch(s){_e({id:0,type:"error",error:String(s)})}}function Pe(e,t){let i=URL.createObjectURL(new Blob([t],{type:"text/plain;charset=utf-8"})),n=document.createElement("a");n.href=i,n.download=e,n.click(),setTimeout(()=>URL.revokeObjectURL(i),1000)}async function Fe(e,t){try{await navigator.clipboard.writeText(e);let i=t.textContent;t.textContent="Copied",setTimeout(()=>{t.textContent=i},1800)}catch{if(j("Clipboard access is unavailable. Select the text and use your browser’s Copy command."),t.id==="copy-share")o("share-url").select();else l.output.focus(),l.output.setSelection(l.output.getModel().getFullModelRange())}}async function st(){l=await Oe(),M=l.input.getModel(),g=m(),Je();for(let[t,i]of Object.entries(C))f("pass-selector").add(new Option(i.label,t));if(V=!0,l.input.setValue(H(fe())??B??ie(c.path)),V=!1,Ue(),matchMedia("(max-width: 820px)").matches)o("guide-details").open=!1;U();for(let t of["share-button","source-selector","compile-button","simulate-button","simulation-reset","simulation-step-cycle","simulation-step-frame","simulation-stop","simulation-run","simulation-top","simulation-clock","simulation-cycles-per-frame","simulation-clock-hz","simulation-refresh-fps","simulation-inputs","pass-selector","reset-button","download-source"])o(t).disabled=!1;let e=/Mac|iPhone|iPad/.test(navigator.platform);if(o("compile-shortcut").textContent=e?"⌘ ↵":"Ctrl ↵",l.input.addAction({id:"compile-yodl",label:"Compile Yodl",keybindings:[y.KeyMod.CtrlCmd|y.KeyCode.Enter],run:L}),l.output.addAction({id:"compile-yodl-output",label:"Compile Yodl",keybindings:[y.KeyMod.CtrlCmd|y.KeyCode.Enter],run:L}),document.addEventListener("keydown",(t)=>{if(!t.defaultPrevented&&(t.metaKey||t.ctrlKey)&&t.key==="Enter")t.preventDefault(),L()}),l.input.onDidChangeModelContent(()=>{if(V||l.input.getModel()!==M)return;U(),be()}),l.input.onDidChangeCursorPosition((t)=>{o("cursor-position").textContent=`Ln ${t.position.lineNumber}, Col ${t.position.column}`}),r("tour-mode").onclick=()=>ue("tour"),r("examples-mode").onclick=()=>ue("examples"),f("source-selector").onchange=()=>{let t=f("source-selector").value;P(`last:${c.mode}`,t),we({mode:c.mode,path:t,stage:c.mode==="tour"?h.find((i)=>`tour/${i.file}`===t).stage:c.stage})},r("previous-lesson").onclick=()=>Ae(-1),r("next-lesson").onclick=()=>Ae(1),r("suggested-stage").onclick=()=>Re(h[ee()].stage),f("pass-selector").onchange=()=>Re(f("pass-selector").value),r("compile-button").onclick=L,r("simulate-button").onclick=()=>z("run"),r("simulation-run").onclick=()=>z("run"),r("simulation-reset").onclick=()=>z("reset"),r("simulation-step-cycle").onclick=()=>z("step_cycle"),r("simulation-step-frame").onclick=()=>z("step_frame"),f("simulation-zoom").onchange=()=>{if(de)A([de])},r("simulation-stop").onclick=()=>{T.stop(),d="ready",F(),o("simulation-state").textContent="Stopped",k("Simulation stopped")},_.onchange=()=>{if(P("auto",String(_.checked)),clearTimeout(Q),_.checked)L()},r("source-tab").onclick=()=>G("source"),r("output-tab").onclick=()=>G("output"),r("jump-error").onclick=()=>{if(!x)return;G("source"),te(N),l.input.setSelection(x),l.input.revealRangeInCenter(x),l.input.focus()},r("reset-button").onclick=()=>o("reset-dialog").showModal(),o("reset-dialog").addEventListener("close",()=>{if(o("reset-dialog").returnValue==="reset")M.setValue(ge())}),r("download-source").onclick=()=>Pe(g.split("/").at(-1),l.input.getValue()),r("download-output").onclick=()=>{if(Z===X)Pe(`${c.path.split("/").at(-1).replace(/\.yodl$/,"")}.${C[c.stage].extension}`,S)},r("copy-output").onclick=()=>{if(Z===X)Fe(S,r("copy-output"))},r("share-button").onclick=()=>{let t=new URL(location.href);if(t.hash=`code=${Le({...c,source:E(),files:D,entryPath:R,origin:q})}`,t.href.length>32000){j("This circuit is too large for a reliable share link. Use Save to download the source instead.");return}o("share-url").value=t.href,o("share-dialog").showModal(),o("share-url").select()},r("copy-share").onclick=()=>void Fe(o("share-url").value,r("copy-share")),at(),k("Ready to compile"),qe(),_.checked)L()}function Ae(e){let t=ee()+e;if(t>=h.length){ue("examples");return}let i=h[t];if(i)P("last:tour",`tour/${i.file}`),we({mode:"tour",path:`tour/${i.file}`,stage:i.stage}),o("guide").scrollTop=0}function at(){let e=o("resize-handle"),t=Number(H("split")??50);function i(a){t=Math.max(25,Math.min(75,Number.isFinite(a)?a:50)),o("editors").style.setProperty("--source-width",`${t}%`),e.setAttribute("aria-valuenow",String(Math.round(t))),l.input.layout(),l.output.layout()}i(t),e.onpointerdown=(a)=>{e.setPointerCapture(a.pointerId),e.classList.add("dragging"),a.preventDefault()},e.onpointermove=(a)=>{if(!e.hasPointerCapture(a.pointerId))return;let s=o("editors").getBoundingClientRect();i((a.clientX-s.left)/s.width*100)};let n=()=>{e.classList.remove("dragging"),P("split",String(t))};e.onlostpointercapture=n,e.onpointerup=(a)=>{if(e.hasPointerCapture(a.pointerId))e.releasePointerCapture(a.pointerId)},e.onkeydown=(a)=>{if(!["ArrowLeft","ArrowRight","Home","End"].includes(a.key))return;a.preventDefault(),i(a.key==="Home"?25:a.key==="End"?75:t+(a.key==="ArrowLeft"?-5:5)),n()}}st().catch((e)=>{k("Could not load the editor","error"),o("input-panel").textContent="The editor could not load. Check your connection and reload the page.",j(`Playground startup failed: ${e.message??String(e)}`)});

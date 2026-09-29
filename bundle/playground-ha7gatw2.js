var Ae={"01_presentation":[{id:"gates",title:"Your first circuit"}],"02_getting_started":[{id:"gates",title:"Your first circuit"},{id:"counter",title:"Describe the next state"}],"03_data_types":[{id:"widths",title:"Give every bit a place"},{id:"records",title:"Name a group of signals"}],"04_constructs":[{id:"modules",title:"Connect reusable modules"},{id:"generics",title:"Parameterise a design"},{id:"packages",title:"Organise a design"}],"05_operators":[{id:"bits",title:"Take signals apart"}],"06_control_flow":[{id:"selection",title:"Choose a signal"},{id:"vectors",title:"Build parallel hardware"}],"07_built_in_functions":[{id:"bits",title:"Take signals apart"},{id:"counter",title:"Describe the next state"}],"08_primitive_modules":[{id:"registers",title:"Remember a value"},{id:"memory",title:"Store a small table"}],"09_external_modules":[{id:"modules",title:"Connect reusable modules"}]};function wt(e){let t=new TextEncoder().encode(JSON.stringify(e)),n="";for(let r of t)n+=String.fromCharCode(r);return btoa(n).replaceAll("+","-").replaceAll("/","_").replace(/=+$/,"")}function _e(e){if(e.length>200000)throw Error("This shared program is too large to open.");let t=atob(e.replaceAll("-","+").replaceAll("_","/"));return JSON.parse(new TextDecoder().decode(Uint8Array.from(t,(n)=>n.charCodeAt(0))))}function Ze(e){return typeof e==="string"&&/^(book\/src|examples|tour)\/[\w./-]+\.yodl$/.test(e)&&!e.split("/").some((t)=>t===".."||t===".")}function xt(e){return!!e&&typeof e==="object"&&!Array.isArray(e)&&Object.entries(e).every(([t,n])=>Ze(t)&&typeof n==="string")}var kt=[{id:"gates",title:"Your first circuit",topic:"Signals & modules",intro:"A Yodl program describes hardware. A module connects named inputs to named outputs; the connections operate continuously.",concepts:["bool is a one-bit signal.","The expression a and b describes a logic gate. It does not wait for a clock."],observe:"In FIRRTL, find the two input ports, the output port, and the and operation.",challenge:"Change and to xor. The output will describe a gate that is high when exactly one input is high.",stage:"write_firrtl",file:"01-gates.yodl"},{id:"widths",title:"Give every bit a place",topic:"Integers & arithmetic",intro:"Hardware signals have fixed widths. u8 is an unsigned eight-bit integer; s8 is a signed eight-bit integer. Choose the output width to retain the bits you need.",concepts:["Adding two eight-bit unsigned values can require nine bits.","Sized literals spell out width and base: 8'hFF is eight bits of hexadecimal FF. Signedness changes require an explicit cast."],observe:"Inspect the nine-bit sum and sixteen-bit product ports. Switch to Typed to see expression types.",challenge:"Change sum from u9 to u8. Narrowing keeps the low eight bits, so a carry no longer fits in the output.",stage:"write_firrtl",file:"02-widths.yodl"},{id:"selection",title:"Choose a signal",topic:"Conditions & multiplexers",intro:"Conditions select between signals. Both alternatives describe hardware; a condition does not make the circuit execute one software branch at a time.",concepts:["Use if for a two-way choice.","Use match for several cases, with _ as the default."],observe:"Look for mux operations in FIRRTL: these are the signal selectors described by the conditions.",challenge:"Add a 2 case to match that returns a xor b. Keep the default case.",stage:"write_firrtl",file:"03-selection.yodl"},{id:"bits",title:"Take signals apart",topic:"Slices & built-ins",intro:"Individual bits and slices let you work with the representation of a value. Built-in functions have names ending in !.",concepts:["word[7:4] takes bits seven through four, inclusive.","cat! joins bit strings in order; xorr reduces a signal to its parity bit."],observe:"Find bits, cat, and xorr operations in the FIRRTL output.",challenge:"Change swapped to cat!(low, low). Both halves of the output now come from the same four input bits.",stage:"write_firrtl",file:"04-bits.yodl"},{id:"vectors",title:"Build parallel hardware",topic:"Vectors & loops",intro:"A vector groups a fixed number of values. A for loop creates repeated hardware at compile time, so the loop bounds must be known before the circuit runs.",concepts:["[4]u8 is four eight-bit elements.","0..<Lanes excludes the upper bound. All four lanes exist in parallel."],observe:"The Simplified output expands the loop into individual assignments. Switch to FIRRTL to see the vector ports.",challenge:"Change Lanes from 4 to 8. Compile again and count the expanded assignments.",stage:"write_simplified",file:"05-vectors.yodl"},{id:"records",title:"Name a group of signals",topic:"Records & type aliases",intro:"Records collect related signals into named fields. A type alias gives the collection a reusable name without allocating storage.",concepts:["Access a field with . followed by its name.","A record spread copies fields; later fields override the copied values."],observe:"Find the r, g, and b fields in the output ports. They remain individual signals within a bundle.",challenge:"Also override b with 0 in muted. Only the red channel will pass through.",stage:"write_firrtl",file:"06-records.yodl"},{id:"modules",title:"Connect reusable circuits",topic:"Instances & ports",intro:"Define a module once and instantiate it wherever you need that hardware. Each instance is a separate circuit with its own connections.",concepts:["Named arguments connect inputs when creating an instance.","Access an instance output with .sum. Top is the entry circuit in this design."],observe:"Find two Adder instances under Top. They share a definition but connect to different inputs.",challenge:"Connect the second adder to a and c instead of b and c.",stage:"write_firrtl",file:"07-modules.yodl"},{id:"generics",title:"Parameterise a design",topic:"Compile-time parameters",intro:"Generic parameters configure hardware before it runs. Nat parameters describe sizes; Type parameters let a module work with different signal types.",concepts:["uint[Width] uses a compile-time width.","Instantiation specialises each generic module with concrete parameters. These parameters are not input ports."],observe:"Monomorphised output shows concrete versions of the generic modules. Compare it with Source.",challenge:"Change the wide input and output from u16 to u12, and change Mask[16] to Mask[12].",stage:"write_mono",file:"08-generics.yodl"},{id:"registers",title:"Remember a value",topic:"Clocked state",intro:"Combinational logic has no memory. Reg adds state: q is the current value and d is the value sampled at the next rising clock edge.",concepts:["Reg[u8] stores eight bits.","rst resets the register to zero synchronously. en controls whether it captures a new value."],observe:"Find the register and its clock, reset, and enable logic in FIRRTL. The output reads the stored q value.",challenge:"Connect en to true instead of enable. The register will capture data on every rising edge unless reset is asserted.",stage:"write_firrtl",file:"09-registers.yodl"},{id:"counter",title:"Describe the next state",topic:"Feedback & constants",intro:"A counter feeds its current register value through combinational logic to compute the next value. The register breaks the feedback path into clock cycles.",concepts:["clog2!(Limit) computes the number of address bits needed for Limit values.","The comparison makes the counter wrap after Limit - 1. Reset establishes the initial zero state."],observe:"Follow the register output through the increment and selection logic back to its input.",challenge:"Change Limit from 10 to 16. The width stays four bits, but the wrap comparison changes.",stage:"write_firrtl",file:"10-counter.yodl"},{id:"packages",title:"Organise a design",topic:"Packages & names",intro:"Packages group declarations under a namespace. Qualified names make it clear where a reusable module belongs.",concepts:["Use :: to access a declaration inside a package.","A file brought in with import is also wrapped in a package named after the file. Larger examples demonstrate imports."],observe:"Find the qualified Logic::Invert name in Source, then switch to FIRRTL to inspect its instance.",challenge:"Add another Invert instance after the first and connect q to its output. Two inversions restore the original signal.",stage:"write_source",file:"11-packages.yodl"},{id:"memory",title:"Store a small table",topic:"Memory & latency",intro:"Memory describes indexed storage with explicit read and write ports. Latency is part of the interface: this design requests a read latency of one cycle.",concepts:["Depth is the number of stored words; T is the type of each word.","Read and write ports carry clocks, addresses, and enables. A true write mask enables the whole byte."],observe:"Find the memory depth, read latency, and write latency in FIRRTL. Compilation shows structure; the playground does not simulate clock cycles.",challenge:"Increase Depth to 32 and change addr from u4 to u5 so every word remains addressable.",stage:"write_firrtl",file:"12-memory.yodl"}];var F={write_source:{label:"Source",short:"Source",extension:"yodl",language:"yodl",description:"Resolved source, with imported declarations available to the compiler."},write_mono:{label:"Monomorphised",short:"Mono",extension:"yodl",language:"yodl",description:"Generic modules specialised with concrete parameters."},write_typed:{label:"Typed",short:"Typed",extension:"yodl",language:"yodl",description:"Expressions annotated with their resolved types and widths."},write_simplified:{label:"Simplified",short:"Simplified",extension:"yodl",language:"yodl",description:"Core representation with loops expanded and expressions simplified."},write_firrtl:{label:"FIRRTL",short:"FIRRTL",extension:"fir",language:"firrtl",description:"Hardware represented as ports, operations, registers, and connections."},write_low_firrtl:{label:"Low FIRRTL",short:"Low",extension:"fir",language:"firrtl",description:"FIRRTL after lowering passes, ready for downstream tools."},write_rtlil:{label:"RTLIL",short:"RTLIL",extension:"il",language:"rtlil",description:"Hardware in the intermediate language used by Yosys."},test:{label:"Tests",short:"Tests",extension:"txt",language:"plaintext",description:"Run procedural testbenches and report each passing test."}};function He(e,t){let n=t.replace(/[.*+?^${}()|[\]\\]/g,"\\$&"),r=e.match(new RegExp(`${n}:(\\d+)\\.(\\d+)-(\\d+)\\.(\\d+)`));if(!r)return null;return{startLineNumber:+r[1],startColumn:+r[2],endLineNumber:+r[3],endColumn:+r[4]}}var be={...{"examples/Testbench.yodl":`module XorGate(a: bool, b: bool) -> (out: bool) {
    out = a xor b
}

const XorTruthTable = [
    3'b000, // a, b, out
    3'b011,
    3'b101,
    3'b110,
]

module Counter[Width: Nat](
    clk: clock,
    rst: bool,
    enable: bool,
) -> (value: uint[Width]) {
    let state = Reg[uint[Width]](clk, rst, en: enable)
    state.d = state.q + 1
    value = state.q
}

test "complete XOR truth table" for XorGate {
    for i in 0..<4 {
        drive!(a, XorTruthTable[i][2])
        drive!(b, XorTruthTable[i][1])
        expect!(out, XorTruthTable[i][0])
    }
}

test "counter reset, increment, and hold" for Counter[8] {
    drive!(rst, true)
    drive!(enable, false)
    step!(1)
    expect!(value, 0)

    drive!(rst, false)
    drive!(enable, true)
    for expected in 1..<6 {
        step!(1)
        expect!(value, expected)
    }

    drive!(enable, false)
    step!(2)
    expect!(value, 5)
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
`,"examples/Hello.yodl":`import Font

@simulation({
    display: { buffer: "pixel", width: 400, height: 300, mode: "binary", packing: "bits32", on_color: 8116210, off_color: 1056800 },
})
module HelloSim() -> (pixel: [300][13]u32) {
    let message = "YODL; Yet anOther Description Language by Nathan Soufflet!"
    Font::TextFramebufferWords[Length: 58, Width: 400, Height: 300, PackedWidth: 13, X: 1, Y: 2, Scale: 8](text: message, pixel)
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
`,"examples/Clock.yodl":`import Text
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

test "Euler 1 sums multiples below 1000" for Euler1 {
    drive!(rst, true)
    step!(1)
    expect!(q, 0)

    drive!(rst, false)
    step!(1000)
    expect!(q, 233168)
    expect!(is_ready, true)
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
`},...{"tour/11-packages.yodl":`package Logic {
    module Invert(value: bool) -> (q: bool) {
        q = not value
    }
}

module Top(value: bool) -> (q: bool) {
    let inverter = Logic::Invert(value: value)
    q = inverter.q
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
`,"tour/02-widths.yodl":`module Top(a: u8, b: u8, offset: s8) -> (
    sum: u9,
    product: u16,
    adjusted: s9,
) {
    sum = a + b
    product = a * b
    adjusted = offset + sint!(8'd1)
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
`,"tour/01-gates.yodl":`// Two inputs, one gate, one output.
module Top(a: bool, b: bool) -> (q: bool) {
    q = a and b
}
`,"tour/05-vectors.yodl":`const Lanes = 4

module Top(values: [Lanes]u8, mask: u8) -> (result: [Lanes]u8) {
    for i in 0..<Lanes {
        result[i] = values[i] xor mask
    }
}
`,"tour/04-bits.yodl":`module Top(word: u8) -> (swapped: u8, parity: bool) {
    let high = word[7:4]
    let low = word[3:0]
    swapped = cat!(low, high)
    parity = xorr word
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
`,"tour/07-modules.yodl":`module Adder(a: u8, b: u8) -> (sum: u9) {
    sum = a + b
}

module Top(a: u8, b: u8, c: u8) -> (ab: u9, bc: u9) {
    let first = Adder(a: a, b: b)
    let second = Adder(a: b, b: c)
    ab = first.sum
    bc = second.sum
}
`,"tour/06-records.yodl":`type Color = (r: u8, g: u8, b: u8)

module Top(color: Color) -> (muted: Color, red: u8) {
    muted = (..color, g: 0)
    red = color.r
}
`,"tour/09-registers.yodl":`module Top(clk: clock, rst: bool, enable: bool, data: u8) -> (q: u8) {
    let state = Reg[u8](clk, rst, en: enable)
    state.d = data
    q = state.q
}
`,"tour/12-memory.yodl":`module Top(clk: clock, addr: u4, data: u8, write_enable: bool) -> (q: u8) {
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
`}},P=kt,we=Object.keys(be).filter((e)=>/^examples\/[^/]+\.yodl$/.test(e)).sort(),V="examples/Playground.yodl",Qe={mode:"tour",path:`tour/${P[0].file}`,stage:"write_firrtl"};function xe(e){if(!e||typeof e!=="object")return!1;let t=e;return Object.hasOwn(F,t.stage)&&(t.mode==="tour"?P.some((n)=>`tour/${n.file}`===t.path):t.mode==="examples"&&(we.includes(t.path)||t.path===V))}function Pe(e){return wt({...e,version:e.entryPath?2:1})}function Xe(e){if(!e.startsWith("#code="))return null;try{let t=_e(e.slice(6));if(![1,2].includes(t.version)||!xe(t)||typeof t.source!=="string")throw Error();if(t.version===2&&(!Ze(t.entryPath)||!xt(t.files)||t.origin!==void 0&&!/^[a-zA-Z0-9_-]+\.html#[a-z0-9-]+$/.test(t.origin)))throw Error();if(t.version===1)return{version:1,mode:t.mode,path:t.path,stage:t.stage,source:t.source};return t}catch{throw Error("This share link is invalid, too large, or uses an unsupported version.")}}class ge{timeoutMs;worker;active;queue=[];timer;nextId=0;constructor(e=15000){this.timeoutMs=e}compile(e,t){return this.cancel(e),new Promise((n)=>{this.queue.push({owner:e,request:{...t,id:++this.nextId},resolve:n}),this.pump()})}cancel(e){if(this.queue=this.queue.filter((t)=>{if(t.owner!==e)return!0;return t.resolve(null),!1}),this.active?.owner===e)this.worker?.terminate(),this.worker=void 0,this.finish(null)}dispose(){for(let e of this.queue)e.resolve(null);if(this.queue=[],this.active)this.cancel(this.active.owner);this.worker?.terminate(),this.worker=void 0}finish(e){clearTimeout(this.timer);let t=this.active;this.active=void 0,t?.resolve(e),this.pump()}pump(){if(this.active||!this.queue.length)return;let e=this.active=this.queue.shift(),t=(n)=>{if(this.active!==e)return;this.worker?.terminate(),this.worker=void 0,this.finish({id:e.request.id,error:n,duration:0})};try{this.worker??=new Worker(new URL("./playground-worker-z7j5mmrs.js",import.meta.url),{type:"module"}),this.worker.onmessage=(n)=>{if(this.active===e&&n.data.id===e.request.id)this.finish(n.data)},this.worker.onerror=()=>t("The compiler worker could not run. Try Compile again."),this.timer=setTimeout(()=>t("Compilation exceeded 15 seconds. Try a smaller design or reduce compile-time loop bounds."),this.timeoutMs),this.worker.postMessage(e.request)}catch(n){t(`Could not start the compiler: ${n.message}`)}}}class et{startupTimeoutMs;worker;requestId=0;activeId;request;startupTimer;constructor(e=30000){this.startupTimeoutMs=e}start(e,t){this.stop();let n=++this.requestId;this.activeId=n,this.request=e;let r=this.worker=new Worker(new URL("./playground-worker-z7j5mmrs.js",import.meta.url),{type:"module"});r.onmessage=(a)=>{if(this.worker!==r||a.data.id!==n)return;clearTimeout(this.startupTimer),t(a.data)},r.onerror=()=>{if(this.worker!==r)return;this.stop(),t({id:n,type:"error",error:"The simulation worker could not run. Try Run again."})},this.startupTimer=setTimeout(()=>{if(this.worker!==r)return;this.stop(),t({id:n,type:"error",error:"Simulation compilation timed out. Try a smaller design."})},this.startupTimeoutMs),r.postMessage({...e,id:n,simulate:{...e.simulate,mode:"realtime",action:e.simulate?.action??"run"}})}pause(){this.postControl("pause")}resume(e){this.postControl("resume",e)}command(e,t){this.postControl(e,t)}setInputs(e){if(!this.request?.simulate)return;this.request={...this.request,simulate:{...this.request.simulate,inputs:e}},this.postControl("settle")}stop(){clearTimeout(this.startupTimer),this.worker?.terminate(),this.worker=void 0,this.activeId=void 0,this.request=void 0}postControl(e,t){if(!this.worker||this.activeId===void 0||!this.request)return;this.worker.postMessage({id:this.activeId,control:{action:e,options:t,...e==="settle"?{inputs:this.request.simulate?.inputs}:{}}})}}var St=[{id:"teal",label:"Teal"},{id:"cobalt",label:"Cobalt"},{id:"moss",label:"Moss"},{id:"plum",label:"Plum"},{id:"ochre",label:"Ochre"},{id:"signal",label:"Signal"},{id:"ember",label:"Ember"}];function vt(e){return getComputedStyle(document.documentElement).getPropertyValue(`--${e}`).trim()}function Ct(e){try{return localStorage.getItem(e)}catch{return null}}function Et(e,t){try{localStorage.setItem(e,t)}catch{}}function Tt(e,t){let n=matchMedia("(prefers-color-scheme: dark)"),r=Array.from(e.querySelectorAll("[data-theme-preference]")),a=Ct("yodl-playground-v2:theme"),y=a==="light"||a==="dark"?a:"system",p=()=>{let m=y==="dark"||y==="system"&&n.matches;document.documentElement.dataset.theme=m?"dark":"light";for(let E of r)E.setAttribute("aria-pressed",String(E.dataset.themePreference===y));t(m)};for(let m of r)m.addEventListener("click",()=>{y=m.dataset.themePreference,Et("yodl-playground-v2:theme",y),p()});return n.addEventListener("change",p),p(),p}function Lt(e,t){let n=e.querySelector("#accent-button"),r=e.querySelector("#accent-menu"),a=e.querySelector("#accent-label"),y=Array.from(e.querySelectorAll(".swatch")),p=Ct("yodl-playground-v2:accent"),m=St.some((C)=>C.id===p)?p:"teal",E=()=>{document.documentElement.dataset.accent=m,a.textContent=St.find((C)=>C.id===m).label;for(let C of y)C.setAttribute("aria-pressed",String(C.dataset.accent===m))},j=(C)=>{r.hidden=!C,n.setAttribute("aria-expanded",String(C))};n.addEventListener("click",()=>j(r.hidden===!0));for(let C of y)C.addEventListener("click",()=>{m=C.dataset.accent,Et("yodl-playground-v2:accent",m),E(),t()});return document.addEventListener("pointerdown",(C)=>{if(!r.hidden&&!e.contains(C.target))j(!1)}),e.addEventListener("keydown",(C)=>{if(C.key==="Escape"&&!r.hidden)j(!1),n.focus()}),E(),E}var H,Mt;function Rt(){if(H)return Promise.resolve();return Mt??=gn().catch((e)=>{throw Mt=void 0,e})}var mn="./monaco-q1wq37d6.js",hn="./monaco-yc0h762w.css";function fn(e){return new Promise((t,n)=>{let r=document.createElement("link");r.rel="stylesheet",r.href=e,r.onload=()=>t(),r.onerror=()=>{r.remove(),n(Error("Could not load the editor styles. Reload the page to try again."))},document.head.append(r)})}async function gn(){if(!window.monaco){let e,t=new Promise((n,r)=>{e=setTimeout(()=>r(Error("The code editor took too long to load. Try again.")),30000)});try{let n=Promise.all([fn(new URL(hn,import.meta.url).href),import(new URL(mn,import.meta.url).href)]),[,r]=await Promise.race([n,t]);window.monaco=r.monaco}finally{clearTimeout(e)}}H=window.monaco,H.languages.register({id:"yodl"}),H.languages.setMonarchTokensProvider("yodl",{keywords:["declare","module","test","let","match","if","else","for","in","const","package","import","true","false"],typeKeywords:["uint","sint","bool","clock","type","Nat","Type"],wordOperators:["and","or","not","xor","nand","nor","xnor","shl","shr","andr","orr","xorr"],operators:["==","!=","<=",">=","<:",">:","+:","-:","..","..<","..=","+","-","*","/","%","=>","?",":",".","->","::"],symbols:/[=><!~?:&|+\-*/^%.]+/,tokenizer:{root:[[/\w+!/,"function"],[/\b[us]\d+\b/,"type"],[/[A-Z]\w*/,{cases:{"@typeKeywords":"type","@default":"ident.cap"}}],[/[a-zA-Z_]\w*/,{cases:{"@keywords":"keyword","@typeKeywords":"type","@wordOperators":"keyword.operator","@default":"identifier"}}],[/"([^"\\]|\\.)*$/,"string.invalid"],[/"/,{token:"string.quote",bracket:"@open",next:"@string"}],[/'[^'\\]'/,"string"],[/'\\.'/,"string"],[/\/\/.*$/,"comment"],[/\b\d+'[bhod]?\w+\b/,"number"],[/\b\d+(_\d+)*\b/,"number"],[/@symbols/,"delimiter"],[/[(){}\[\],;]/,"delimiter"],[/\s+/,"white"]],string:[[/[^\\"]+/,"string"],[/\\./,"string.escape"],[/"/,{token:"string.quote",bracket:"@close",next:"@pop"}]]}}),H.languages.setLanguageConfiguration("yodl",{comments:{lineComment:"//"},brackets:[["{","}"],["[","]"],["(",")"]],autoClosingPairs:[{open:"{",close:"}"},{open:"[",close:"]"},{open:"(",close:")"},{open:'"',close:'"'}]});for(let e of["firrtl","rtlil"])H.languages.register({id:e}),H.languages.setMonarchTokensProvider(e,{tokenizer:{root:[[e==="firrtl"?/;.*/:/#.*/,"comment"],[/"[^"\\]*(?:\\.[^"\\]*)*"/,"string"],[/\b(?:circuit|module|extmodule|input|output|wire|node|reg|regreset|mem|inst|of|when|else|connect|attribute|parameter|cell|end|process|sync|update|assign)\b/,"keyword"],[/\b(?:UInt|SInt|Clock|Reset|AsyncReset)\b/,"type"],[/\b(?:mux|add|sub|mul|and|or|xor|not|bits|cat|pad|eq|lt|gt)\b/,"function"],[/-?\b\d+(?:'[01xzm-]+)?\b/,"number"],[/[<>=:]+/,"delimiter"]]}});De()}var yn={panel:"#fefdfc",ink:"#211c17",mute:"#69625d",line:"#e2dfdb",sunk:"#f3f1ed",bg:"#faf9f6",acc:"#008381","acc-soft":"#dbf3f1","k-kw":"#6b46a0","k-ty":"#00717f","k-fn":"#945a00","k-nm":"#2b7440","k-id":"#23588a"},T=(e)=>(typeof getComputedStyle==="function"?vt(e):"")||yn[e],U=(e)=>e.replace("#","");function De(){if(!H)return;let e=document.documentElement.dataset.theme==="dark";H.editor.defineTheme("yodl",{base:e?"vs-dark":"vs",inherit:!0,rules:[{token:"",foreground:U(T("ink"))},{token:"keyword",foreground:U(T("k-kw"))},{token:"keyword.operator",foreground:U(T("k-kw"))},{token:"identifier",foreground:U(T("ink"))},{token:"operator",foreground:U(T("mute"))},{token:"type.identifier",foreground:U(T("k-ty"))},{token:"type",foreground:U(T("k-ty"))},{token:"function",foreground:U(T("k-fn"))},{token:"number",foreground:U(T("k-nm"))},{token:"string",foreground:U(T("k-nm"))},{token:"ident.cap",foreground:U(T("k-id"))},{token:"comment",foreground:U(T("mute"))},{token:"delimiter",foreground:U(T("mute"))}],colors:{"editor.background":T("panel"),"editor.foreground":T("ink"),"editorLineNumber.foreground":T("mute")+"99","editorLineNumber.activeForeground":T("ink"),"editor.selectionBackground":T("acc-soft"),"editor.inactiveSelectionBackground":T("sunk"),"editor.lineHighlightBackground":T("sunk")+"00","editor.lineHighlightBorder":T("sunk")+"00","editorCursor.foreground":T("acc"),"editorIndentGuide.background1":T("line"),...Object.fromEntries([1,2,3,4,5,6].map((t)=>[`editorBracketHighlight.foreground${t}`,T("mute")])),"editorBracketHighlight.unexpectedBracket.foreground":T("mute"),"editorWidget.background":T("panel"),"editorWidget.border":T("line"),"scrollbarSlider.background":T("line")+"aa","scrollbarSlider.hoverBackground":T("mute")+"66"}}),H.editor.setTheme("yodl")}async function bn(){let e=typeof document<"u"?document.fonts:void 0;if(!e)return;try{await Promise.race([e.load('13.5px "IBM Plex Mono"'),new Promise((t)=>setTimeout(t,1500))])}catch{}e.ready.then(()=>H?.editor.remeasureFonts?.())}async function $t(e,t={}){await Rt(),await bn();let n={automaticLayout:!0,minimap:{enabled:!1},scrollBeyondLastLine:!1,fontSize:13.5,lineHeight:23,fontFamily:'"IBM Plex Mono", ui-monospace, SFMono-Regular, Consolas, monospace',padding:{top:18,bottom:18},renderLineHighlight:"none",glyphMargin:!1,folding:!1,lineNumbersMinChars:3,lineDecorationsWidth:18,overviewRulerLanes:0,hideCursorInOverviewRuler:!0,overviewRulerBorder:!1,bracketPairColorization:{enabled:!1},guides:{indentation:!1,bracketPairs:!1},matchBrackets:"never",scrollbar:{useShadows:!1,verticalScrollbarSize:8,horizontalScrollbarSize:8},tabSize:4,insertSpaces:!0,fixedOverflowWidgets:!0};return e.replaceChildren(),H.editor.create(e,{...n,language:"yodl",ariaLabel:"Yodl source code",...t})}async function At(){await Rt();let e=H.editor.createModel("","yodl"),t=await $t(document.getElementById("input-panel"),{model:e}),n=await $t(document.getElementById("output-panel"),{readOnly:!0,language:"firrtl",ariaLabel:"Compiled output"});return{input:t,output:n}}var I=(e)=>document.getElementById(e),tt=16,wn=10,xn=512;function _t(e){let t={};for(let n of e.split(",")){let r=/^\s*([A-Za-z_$][\w$]*)(?::(\d+))?\s*=\s*(-?\d+)\s*$/.exec(n);if(!n.trim())continue;if(!r)throw Error(`Invalid input assignment: ${n}`);if(!Number.isSafeInteger(Number(r[3])))throw Error("Input exceeds the safe integer range.");t[r[1]]={width:Number(r[2]??32),value:Number(r[3])}}return t}function kn(e){if(!e.known)return"x";if(e.width===1)return e.value==="0"?"0":"1";try{return`${e.width}'h${BigInt(e.value).toString(16)}`}catch{return e.value}}var Sn=(e)=>{if(!e.known)return"x";try{return BigInt(e.value).toString(16)}catch{return e.value}};function vn(e){if(e>=1e6)return`${(e/1e6).toFixed(1)} MHz`;if(e>=1e4)return`${Math.round(e/1000)} kHz`;if(e>=1000)return`${(e/1000).toFixed(1)} kHz`;return`${e<10?e.toFixed(1):Math.round(e)} Hz`}function Ht(e){let t=new et,n="ready",r,a=[],y,p,m=(o)=>I(o),E=(o)=>I(o),j=["simulation-top","simulation-clock","simulation-cycles-per-frame","simulation-clock-hz","simulation-refresh-fps"];function C(){let o=n==="running"||n==="stepping";m("simulation-run").textContent=o?"Pause":n==="paused"?"Resume":"Run",m("simulation-run").disabled=n==="starting"||n==="halted",m("simulation-reset").disabled=n==="ready"||n==="starting",m("simulation-stop").disabled=n==="ready"}function X(o){let s=I("simulation-framebuffer");if(y=o,I("simulation-zoom-control").hidden=!o,!o){s.hidden=!0;return}if(s.hidden=!1,s.width!==o.width||s.height!==o.height)s.width=o.width,s.height=o.height,p=void 0;let h=(s.parentElement?.clientWidth||640)-32,x=I("simulation-zoom").value,c=x==="fit"?Math.min(h/o.width,480/o.height):Number(x);s.style.width=`${o.width*c}px`,s.style.height=`${o.height*c}px`;let k=s.getContext("2d");if(!k)return;let l=p??=k.createImageData(o.width,o.height),L=Math.ceil(o.width/32);for(let S=0;S<o.width*o.height;S++){let A=Math.floor(S/o.width),M=S%o.width,_=A*L+Math.floor(M/32),ie=!(!o.valid||(o.packed?(o.valid[_]&1<<M%32)!==0:o.valid[S]!==0))?16711935:o.packed?(o.packed[_]&1<<M%32)!==0?o.onColor??16777215:o.offColor??0:o.rgb?.[S]??o.pixels?.[S]??0;l.data[S*4]=ie>>>16&255,l.data[S*4+1]=ie>>>8&255,l.data[S*4+2]=ie&255,l.data[S*4+3]=255}k.putImageData(l,0,0)}function w(o,s){let h=document.createElement("div");h.className="signal";let x=document.createElement("span");x.className="signal-name",x.append(o.name+" ");let c=document.createElement("small");return c.textContent=o.width===1?"bool":`u${o.width}`,x.append(c),h.append(x,s),h}function B(o){let s=I("simulation-inputs-controls"),h=o.map((c)=>`${c.name}:${c.width}:${c.value}:${c.known}`).join("|");if(s.dataset.signature===h)return;s.dataset.signature=h,s.replaceChildren();let x=(c)=>{let k=[...s.querySelectorAll("[data-signal]")].map((l)=>{let L=l instanceof HTMLInputElement?l.value:l.getAttribute("aria-checked")==="true"?1:0;return`${l.dataset.signal}:${l.dataset.width}=${L}`});E("simulation-inputs").value=k.join(", ");try{let l=_t(k.join(", "));if(c instanceof HTMLInputElement)c.setCustomValidity("");if(n!=="ready")t.setInputs(l)}catch(l){if(c instanceof HTMLInputElement)c.setCustomValidity(String(l)),c.reportValidity()}};for(let c of o){let k;if(c.width===1){let l=document.createElement("button");l.type="button",l.setAttribute("role","switch"),l.setAttribute("aria-checked",String(c.value!=="0")),l.setAttribute("aria-label",c.name),l.textContent=c.value!=="0"?"1":"0",l.addEventListener("click",()=>{let L=l.getAttribute("aria-checked")!=="true";l.setAttribute("aria-checked",String(L)),l.textContent=L?"1":"0",x(l)}),k=l}else{let l=document.createElement("input");l.type="text",l.value=c.value,l.inputMode="numeric",l.title=`u${c.width}`,l.setAttribute("aria-label",c.name),l.addEventListener("change",()=>x(l)),k=l}k.className="signal-value",k.dataset.signal=c.name,k.dataset.width=String(c.width),s.append(w(c,k))}if(!o.length)s.append(z("No inputs"))}function z(o){let s=document.createElement("p");return s.className="signal-empty",s.textContent=o,s}function oe(o){let s=I("simulation-outputs"),h=o.slice(0,100).map((x)=>{let c=document.createElement("span");return c.className="signal-value signal-output",c.textContent=kn(x),w(x,c)});if(o.length>100)h.push(w({name:`… ${o.length-100} more`,width:0,value:"",known:!1},document.createElement("span")));s.replaceChildren(...h.length?h:[z("No outputs")])}function re(o){if(o.totalCycles===void 0||!o.outputs&&!o.inputs)return;let s=new Map;for(let x of[...o.inputs??[],...o.outputs??[]])s.set(x.name,x);let h=a.at(-1);if(h&&h.cycle===o.totalCycles){h.values=s;return}if(h&&o.totalCycles<h.cycle)a=[];if(a.push({cycle:o.totalCycles,values:s}),a.length>xn)a.shift()}function ee(){let o=I("simulation-trace");if(!a.length){o.replaceChildren(z("Run or step the simulation to record signals.")),I("trace-range").textContent="";return}let s=a.at(-1),h=[...s.values.keys()].filter((S)=>S!==r).slice(0,wn-(r?1:0)),x=Math.max(0,a.length-tt),c=a.slice(x),k=[],l=(S,A)=>{let M=document.createElement("div");M.className="trace-row";let _=document.createElement("span");_.className="trace-name",_.textContent=S,_.title=S;let K=document.createElement("div");return K.className="trace-lane",K.append(...A),M.append(_,K),M},L=(S,A,M)=>{let _=document.createElement("div");if(_.className="trace-cell",_.dataset.kind=S,A)_.dataset.future="";if(M)_.dataset.edge="";return _};if(r){let S=[];for(let A=0;A<tt;A++){let M=L("clock",A>=c.length,A===0);M.append(document.createElement("span"),document.createElement("span")),S.push(M)}k.push(l(r,S))}for(let S of h){let A=[],M;for(let _=0;_<tt;_++){let K=c[Math.min(_,c.length-1)].values.get(S),ie=_>=c.length;if(!K){A.push(L("bus",ie,!1));continue}let Ye=K.width===1&&K.known,yt=`${K.known}:${K.value}`,bt=!ie&&(M===void 0||M!==yt),Je=L(Ye?"bit":"bus",ie,bt);if(Ye&&K.value!=="0")Je.dataset.high="";if(!Ye&&bt){let Ge=document.createElement("span");Ge.className="bus-value",Ge.textContent=Sn(K),Je.append(Ge)}if(!ie)M=yt;A.push(Je)}k.push(l(S,A))}o.replaceChildren(...k),I("trace-range").textContent=c.length>1?`cycles ${c[0].cycle}–${s.cycle}`:`cycle ${s.cycle}`}function u(o){let s=I("simulation-output");if(o.type==="error"){n="error",s.hidden=!1,s.textContent=o.error??"Simulation failed.",I("simulation-state").textContent="Error",C(),e.setStatus("Simulation failed","error");return}if(n=o.type==="halted"?"halted":o.type==="stopped"?"ready":o.type==="stepping"?"stepping":o.type==="frame"||o.type==="resumed"?"running":"paused",o.frame)X(o.frame);else if(o.metadata&&!o.metadata.display)X(void 0);if(o.clock!==void 0)r=o.clock;if(o.inputs)o={...o,inputs:o.inputs.filter((A)=>A.name!==r)};if(o.outputs)oe(o.outputs);if(o.inputs)B(o.inputs);re(o),ee();let h=o.messages??[];if(s.hidden=h.length===0,s.textContent=h.join(`
`),m("simulation-step-cycle").disabled=!o.clock||n==="halted",m("simulation-step-frame").hidden=!(o.frame&&o.clock),m("simulation-step-frame").disabled=n==="halted",o.metadata){let A={"simulation-top":o.metadata.top,"simulation-clock":o.clock,"simulation-cycles-per-frame":o.playback?.cyclesPerFrame,"simulation-clock-hz":o.playback?.clockHz??"maximum","simulation-refresh-fps":o.playback?.refreshFps};for(let[M,_]of Object.entries(A))E(M).placeholder=String(_??"automatic");E("simulation-cycles-per-frame").disabled=!o.clock||Boolean(o.metadata.display?.stream),E("simulation-clock-hz").disabled=!o.clock,E("simulation-refresh-fps").disabled=!o.clock}let x=o.totalCycles??0,c=o.cyclesPerSecond===void 0||n!=="running"&&n!=="stepping"?"":` · ${vn(o.cyclesPerSecond)}`;I("simulation-cycle").textContent=`cycle ${x.toLocaleString()}${c}`;let k=o.simulatedSeconds===void 0?"":` · ${o.simulatedSeconds.toFixed(3)} simulated s`,l=o.status?.failed??!1,L=l?"Failed":n[0].toUpperCase()+n.slice(1),S=o.status?.exit_code===void 0?"":` · exit ${o.status.exit_code}`;I("simulation-state").textContent=`${L}${S}${k}`,C(),e.setStatus(l?`Simulation failed${o.status?.first_failure?`: ${o.status.first_failure.message}`:""}`:n==="running"||n==="stepping"?"Simulating…":`Simulation ${n}`,l?"error":void 0)}function d(o="run"){let s=(k)=>{let l=Number(E(k).value);return Number.isFinite(l)&&l>0?l:void 0},h={clockHz:s("simulation-clock-hz"),refreshFps:s("simulation-refresh-fps"),cyclesPerFrame:s("simulation-cycles-per-frame")};if(n!=="ready"&&n!=="error"){if(o==="run")if(n==="running"||n==="stepping")t.pause();else t.resume(h);else t.command(o,h);return}let x=E("simulation-top").value.trim(),c=E("simulation-clock").value.trim();a=[],ee(),I("simulation-state").textContent="Compiling simulation…",n="starting",C();try{let{source:k,path:l,files:L}=e.request();t.start({source:k,path:l,stage:"write_low_firrtl",files:L,simulate:{action:o,...x?{top:x}:{},...c?{clock:c}:{},...Object.fromEntries(Object.entries(h).filter(([,S])=>S!==void 0)),inputs:_t(E("simulation-inputs").value)}},u)}catch(k){u({id:0,type:"error",error:String(k)})}}function f(){t.stop(),n="ready",I("simulation-state").textContent="Ready",I("simulation-cycle").textContent="cycle 0",C()}return m("simulation-run").onclick=()=>d("run"),m("simulation-reset").onclick=()=>{a=[],ee(),d("reset")},m("simulation-step-cycle").onclick=()=>d("step_cycle"),m("simulation-step-frame").onclick=()=>d("step_frame"),I("simulation-zoom").onchange=()=>{if(y)X(y)},m("simulation-stop").onclick=()=>{f(),e.setStatus("Simulation stopped")},m("simulation-settings").onclick=()=>{let o=I("simulation-options");o.hidden=!o.hidden,m("simulation-settings").setAttribute("aria-expanded",String(!o.hidden))},ee(),oe([]),B([]),C(),{enable(){for(let o of["simulation-run","simulation-step-cycle",...j])I(o).disabled=!1;C()},stop:f,clear(){f(),a=[],r=void 0,X(void 0),ee(),oe([]),I("simulation-inputs-controls").dataset.signature="",B([]),I("simulation-output").hidden=!0;for(let o of["simulation-top","simulation-clock","simulation-inputs"])E(o).value=""},clearFrame(){X(void 0)},get active(){return n!=="ready"&&n!=="error"},run:d}}var nt=(e)=>e.replace(/[&<>"']/g,(t)=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[t]),Cn=/^(module|declare|test|let|const|type|package|import|for|in|if|else|match|true|false)$/,En=/^(and|or|not|xor|nand|nor|xnor|shl|shr|andr|orr|xorr)$/,Tn=/^(u\d+|s\d+|uint|sint|bool|clock|Nat|Type)$/,Ln=/^(circuit|module|extmodule|input|output|wire|node|reg|regreset|mem|inst|of|when|else|connect|attribute|parameter|cell|end|process|sync|update|assign|public|version|intmodule|invalidate|skip|printf|stop|assert|cover|assume)$/,Mn=/^(UInt|SInt|Clock|Reset|AsyncReset|Analog)$/,$n=/^(mux|add|sub|mul|div|rem|and|or|xor|not|bits|cat|pad|eq|neq|lt|leq|gt|geq|shl|shr|dshl|dshr|head|tail|andr|orr|xorr|neg|cvt|asUInt|asSInt|asClock|validif)$/;function Rn(e,t){if(t==="yodl"){if(e.startsWith("//"))return"comment";if(e.startsWith('"'))return"string";if(Cn.test(e)||En.test(e))return"keyword";if(Tn.test(e))return"type";if(/^\w+!$/.test(e))return"function";if(/^\d/.test(e))return"number";if(/^[A-Z]/.test(e))return"ident";if(/^[=<>+\-*/%:?.&|^~!]+$/.test(e))return"punct";return""}if(e.startsWith(t==="firrtl"?";":"#"))return"comment";if(e.startsWith('"'))return"string";if(Ln.test(e))return"keyword";if(Mn.test(e))return"type";if($n.test(e))return"function";if(/^-?\d/.test(e))return"number";if(/^[<>=:]+$/.test(e))return"punct";return""}function An(e,t="yodl"){if(t==="plaintext")return nt(e);let a=new RegExp(`(${t==="rtlil"?"#[^\\n]*":t==="firrtl"?";[^\\n]*":"\\/\\/[^\\n]*"}|"(?:[^"\\\\\\n]|\\\\.)*"|\\b\\w+!|${t==="yodl"?"\\b\\d+":"-?\\b\\d+"}(?:'[bhod]?[\\da-fA-F_]+)?\\b|\\b[a-zA-Z_]\\w*\\b|[=<>+\\-*/%:?.&|^~!]+)`,"g");return e.split(a).map((y)=>{let p=Rn(y,t);return p?`<span class="token-${p}">${nt(y)}</span>`:nt(y)}).join("")}function Pt(e,t="yodl"){return e.replace(/\n$/,"").split(`
`).map((r,a)=>`<div class="code-line"><span class="ln">${a+1}</span><span class="lt">${An(r,t)||" "}</span></div>`).join("")}var te=(e)=>document.getElementById(e),Ie=(e)=>String(e).padStart(2,"0"),qe=(e,t)=>`./playground.html?mode=docs&chapter=${e}${t?`#${t}`:""}`;function D(e,t,n){let r=document.createElement(e);if(t)r.className=t;if(n!==void 0)r.textContent=n;return r}function Dt(e){let t=new ge,n,r,a,y=te("docs-main"),p=te("docs-content");function m(){return n??=fetch("./book/chapters.json").then((u)=>{if(!u.ok)throw Error("The language guide could not be loaded.");return u.json()}).catch((u)=>{throw n=void 0,u})}function E(u,d,f){let o=D("a");return o.href=qe(u,d),o.append(...typeof f==="string"?[f]:f),o.addEventListener("click",(s)=>{if(s.metaKey||s.ctrlKey||s.shiftKey||s.button!==0)return;s.preventDefault(),e.navigate(u,d)}),o}function j(u,d){te("docs-chapters").replaceChildren(...u.chapters.map((f,o)=>{let s=E(f.slug,void 0,[D("span",void 0,Ie(o+1)),f.title]);if(f===d)s.setAttribute("aria-current","page");return s})),te("docs-version").textContent=`Yodl ${u.version} · ${u.revision}`,te("docs-toc").replaceChildren(...d.headings.filter((f)=>f.level>1&&f.level<4).map((f)=>{let o=E(d.slug,f.id,f.title);return o.className=`toc-level-${f.level}`,o})),C()}function C(){a?.disconnect();let u=Array.from(te("docs-toc").querySelectorAll("a"));if(!u.length||typeof IntersectionObserver>"u")return;a=new IntersectionObserver((d)=>{for(let f of d)if(f.isIntersecting)for(let o of u)if(o.href.endsWith(`#${f.target.id}`))o.setAttribute("aria-current","location");else o.removeAttribute("aria-current")},{root:y,rootMargin:"0px 0px -70% 0px"});for(let d of Array.from(p.querySelectorAll("h2[id], h3[id]")))a.observe(d)}function X(u,d){let f=u.chapters.indexOf(d),o=D("p","docs-meta",`Chapter ${Ie(f+1)} of ${Ie(u.chapters.length)}`),s=D("article");s.innerHTML=d.html;let h=[o,s],x=Ae[d.slug]??[];if(x.length){let M=D("section","practice");M.append(D("p","section-label","Practice in the tour"));for(let _ of x){let K=D("button");K.type="button",K.append(D("strong",void 0,_.title),D("span",void 0,"→")),K.addEventListener("click",()=>e.openLesson(_.id)),M.append(K)}h.push(M)}let c=u.chapters[f-1],k=u.chapters[f+1],l=D("nav","page-navigation");l.setAttribute("aria-label","Previous and next chapters");let L=(M,_)=>M?E(M.slug,void 0,[D("small",void 0,_),M.title]):D("span");l.append(L(c,"← Previous"),L(k,"Next →"));let S=D("footer","article-footer"),A=D("a",void 0,"Edit this page ↗");A.href=`https://github.com/nathsou/yodl/edit/main/book/src/${d.slug}.md`,S.append(A,D("span",void 0,"Examples compile locally in your browser.")),h.push(l,S),p.replaceChildren(...h),p.className="docs-content",w(u,d);for(let M of d.examples)B(d,M)}function w(u,d){for(let f of Array.from(p.querySelectorAll("article a[href]"))){let o=f.getAttribute("href"),s=/^#(.+)$/.exec(o),h=/^\.?\/?([\w-]+)\.html(?:#(.+))?$/.exec(o),x=h&&u.chapters.find((l)=>l.slug===h[1]);if(!s&&!x)continue;let c=s?d.slug:x.slug,k=s?s[1]:h[2];f.href=qe(c,k),f.addEventListener("click",(l)=>{if(l.metaKey||l.ctrlKey||l.shiftKey||l.button!==0)return;l.preventDefault(),e.navigate(c,k)})}}function B(u,d){let f=p.querySelector(`#${CSS.escape(d.id)}`);if(!f||!d.live)return;let o=f.querySelector('[data-action="compile"]');f.querySelector('[data-action="playground"]').onclick=()=>e.openExample(u,d,d.source,oe(f)??d.stage);let s=async(h)=>{let x=re(f,d,h,s),c=x.querySelector(".example-status");c.dataset.state="",c.firstChild.textContent="● Compiling · ",o.disabled=!0;let k=await t.compile(d.id,{source:d.source,path:d.path,files:d.files,stage:h});if(o.disabled=!1,!k||!f.isConnected)return;let l=x.querySelector(".example-output-body");if(k.error!==void 0){let L=d.expect==="error";c.dataset.state=L?"expected":"error",c.firstChild.textContent=L?"● Expected compiler error · ":"● Compilation failed · ";let S=D("pre","diagnostic",k.error);S.tabIndex=0,l.replaceChildren(S)}else{c.dataset.state="success",c.firstChild.textContent="● Compiled · ",c.title=`${Math.round(k.duration)} ms · Yodl ${z}`;let L=D("div","code-lines");L.tabIndex=0,L.innerHTML=Pt(k.output??"",F[h].language),l.replaceChildren(L)}};o.onclick=()=>void s(oe(f)??d.stage)}let z="",oe=(u)=>u.querySelector(".example-output select")?.value;function re(u,d,f,o){let s=u.querySelector(".example-output");if(s)return s.hidden=!1,s;s=D("div","example-output");let h=D("div","example-output-header"),x=D("span","example-status");x.append(document.createTextNode("● Compiled · "));let c=D("select");c.setAttribute("aria-label","Compiler output stage");for(let[L,S]of Object.entries(F)){if(L==="test"&&d.stage!=="test")continue;let A=new Option(S.label,L);if(A.disabled=d.unsupported.includes(L),A.disabled)A.text+=" (unavailable)";c.add(A)}c.value=f,c.title=F[f].description,c.onchange=()=>{c.title=F[c.value].description,o(c.value)};let k=D("span","stage-select");k.append(c),x.append(k);let l=D("button",void 0,"Hide");return l.type="button",l.onclick=()=>{s.hidden=!0},h.append(x,l),s.append(h,D("div","example-output-body")),u.append(s),s}function ee(u){let d=u?p.querySelector(`#${CSS.escape(u)}`):null;if(d)d.scrollIntoView();else y.scrollTop=0}return{load:m,async show(u,d){let f=te("docs-loading"),o;try{f.hidden=!1,f.textContent="Loading the language guide…",o=await m()}catch(x){f.textContent=`${x.message} Check your connection and reload the page.`;return}f.hidden=!0,z=o.version;let s=o.chapters.find((x)=>x.slug===u)??o.chapters[0],h=s!==r;if(h){if(r)for(let x of r.examples)t.cancel(x.id);if(r=s,j(o,s),X(o,s),document.title=`${s.title} · Yodl`,te("docs-current").textContent=`${Ie(o.chapters.indexOf(s)+1)} · ${s.title}`,matchMedia("(max-width: 820px)").matches)te("chapter-menu").open=!1}if(h||d)ee(d);return s},get current(){return r},dispose(){t.dispose()}}}var ce=(e)=>document.getElementById(e);function It(e){let t=ce("search-dialog"),n=ce("search-input"),r=ce("search-results"),a=ce("search-status"),y,p,m=e.lessons.map((w,B)=>({title:w.title,where:`Tour · Lesson ${String(B+1).padStart(2,"0")}`,excerpt:w.intro,text:[w.title,w.topic,w.intro,...w.concepts,w.observe,w.challenge].join(" "),go:()=>e.openLesson(w.id)}));async function E(){if(y)return!0;try{return await(p??=fetch("./book/search.json").then((w)=>{if(!w.ok)throw Error("Search unavailable");return w.json()}).then((w)=>{y=w}).finally(()=>{p=void 0})),!0}catch{return!1}}async function j(){let w=n.value.toLowerCase().trim();a.textContent=w?"Searching…":"Type to search the guide and the tour.";let B=await E();if(n.value.toLowerCase().trim()!==w)return;if(r.replaceChildren(),!w)return;let z=w.split(/\s+/),oe=(y??[]).map((u)=>({title:u.title,where:`Docs · ${u.chapter}`,excerpt:u.text,text:`${u.title} ${u.text}`,go:()=>e.openDoc(u.slug,u.id)})),re=[...m,...oe].filter((u)=>z.every((d)=>u.text.toLowerCase().includes(d))).sort((u,d)=>Number(d.title.toLowerCase().includes(w))-Number(u.title.toLowerCase().includes(w))).slice(0,30),ee=B?"":" The guide index could not load; showing lessons only.";a.textContent=(re.length?`${re.length} result${re.length===1?"":"s"}`:"No results. Try a concept, operator, or built-in name.")+ee;for(let u of re){let d=document.createElement("a");d.href="#",d.addEventListener("click",(x)=>{x.preventDefault(),t.close(),u.go()});let f=document.createElement("strong");f.textContent=u.title;let o=document.createElement("small");o.textContent=u.where;let s=document.createElement("span"),h=Math.max(0,u.excerpt.toLowerCase().indexOf(z[0])-50);s.textContent=`${h?"…":""}${u.excerpt.slice(h,h+160)}${u.excerpt.length>h+160?"…":""}`,d.append(f,o,s),r.append(d)}}let C=()=>{if(!t.open)t.showModal();n.focus(),n.select(),j()};ce("search-open").addEventListener("click",C),ce("search-close").addEventListener("click",()=>t.close()),n.addEventListener("input",()=>void j()),t.addEventListener("click",(w)=>{if(w.target===t)t.close()}),t.addEventListener("keydown",(w)=>{let B=Array.from(r.querySelectorAll("a")),z=B.indexOf(document.activeElement);if(w.key==="ArrowDown")w.preventDefault(),B[Math.min(B.length-1,z+1)]?.focus();if(w.key==="ArrowUp")if(w.preventDefault(),z<=0)n.focus();else B[z-1].focus();if(w.key==="Enter"&&document.activeElement===n)B[0]?.click()});let X=/Mac|iPhone|iPad/.test(navigator.platform);return ce("search-shortcut").textContent=X?"⌘K":"Ctrl K",document.addEventListener("keydown",(w)=>{let B=w.target;if((w.metaKey||w.ctrlKey)&&w.key.toLowerCase()==="k"){w.preventDefault(),C();return}if(w.key==="/"&&!w.metaKey&&!w.ctrlKey&&!B.closest('input, textarea, select, [contenteditable="true"], .monaco-editor')&&!document.querySelector("dialog[open]"))w.preventDefault(),C()}),{open:C}}var i=(e)=>document.getElementById(e),g=(e)=>i(e),Kt="yodl-playground-v2:",ct=!0;function he(e){try{return localStorage.getItem(Kt+e)}catch{return ct=!1,null}}function ue(e,t){try{localStorage.setItem(Kt+e,t)}catch{ct=!1}}function ae(e){let t=i("notice");t.textContent=e;let n=document.createElement("button");n.textContent="Dismiss",n.addEventListener("click",()=>{t.hidden=!0}),t.append(n),t.hidden=!1}function se(e,t="idle"){i("compile-status").textContent=e,i("compile-status").dataset.state=t}var ot=/Mac|iPhone|iPad/.test(navigator.platform);Tt(document.querySelector(".site-header"),()=>De());Lt(document.querySelector(".accent-picker"),()=>De());var jt=(e)=>e==="tour"?"tour":"playground",it=(e)=>`tour/${e.file}`,Q=(e)=>e.split("/").at(-1),N="tour",Ce,st,v={...Qe};try{let e=JSON.parse(he("selection")??"null");if(xe(e))v=e}catch{}var R,_n=()=>R?`shared:${R.code}`:"",O=()=>R?.entryPath??v.path,b,qt,Se=!1,J,W="",ke="",Y=new Map,Oe=new Map,Z=()=>J.getValue();function Be(e){let t=e===O()?J:Y.get(e);if(!t)return;if(W)Oe.set(W,b.input.saveViewState());W=e,b.input.setModel(t),b.input.updateOptions({readOnly:e!==O(),ariaLabel:`${e}${e===O()?", main source":", imported, read only"}`});let n=Oe.get(e);if(n)b.input.restoreViewState(n);dt(),b.input.layout()}function dt(){let e=W!==O(),t=Y.size>0;i("source-files").hidden=!t,i("editors").dataset.imports=String(t),i("input-filename").textContent=Q(W||O()),i("input-filename").title=W,i("source-kind").textContent=e?"Imported · read only":"",i("source-kind").hidden=!e,i("draft-badge").hidden=e||!J||Z()===Le(),g("reset-button").disabled=e,i("source-files").replaceChildren(...[O(),...Y.keys()].map((n)=>{let r=document.createElement("button");return r.textContent=Q(n),r.title=n===O()?`${n} · compile and simulation target`:`${n} · imported, read only`,r.setAttribute("aria-pressed",String(n===W)),r.onclick=()=>Be(n),r}))}function Hn(e){let t=Object.entries(e).filter(([r])=>r!==O()&&r.endsWith(".yodl")),n=new Set(t.map(([r])=>r));if(W!==O()&&!n.has(W))Be(O());for(let[r,a]of Y)if(!n.has(r))a.dispose(),Y.delete(r),Oe.delete(r);for(let[r,a]of t){let y=Y.get(r);if(!y)Y.set(r,H.editor.createModel(a,"yodl"));else if(y.getValue()!==a)y.setValue(a)}dt()}function Pn(){W="",Oe.clear(),b.input.setModel(J);for(let e of Y.values())e.dispose();Y.clear(),Be(O())}var Ke=0,G="",je=-1,Wt=new ge,zt=new ge,at=0,Nt,ut=()=>({...be,...R?.files});async function Ut(){let e=++at,t=await zt.compile("imports",{source:Z(),path:O(),stage:"write_source",files:ut()});if(e===at&&t?.sources)Hn(t.sources)}function Dn(){++at,zt.cancel("imports"),clearTimeout(Nt),Nt=setTimeout(Ut,150)}var Vt=(e)=>/\btest\s+(?:"|for\b)/.test(e),pe=Ht({request:()=>({source:Z(),path:O(),files:ut()}),setStatus:se}),Yt=0,lt=0,ne=null,In=`// Start a new circuit here.
module Top(a: bool) -> (q: bool) {
    q = a
}
`,We=(e)=>be[e]??In,Le=()=>R?R.source:We(v.path);function qn(e){let t=2166136261;for(let n=0;n<e.length;n++)t^=e.charCodeAt(n),t=Math.imul(t,16777619);return(t>>>0).toString(36)}var Jt=(e)=>`draft:${e}:${qn(We(e))}`,Me=()=>_n()||Jt(v.path),Nn=12;function Gt(){try{let e=JSON.parse(he("drafts")??"[]");return Array.isArray(e)?e.filter((t)=>typeof t?.key==="string"&&typeof t.label==="string"&&typeof t.updated==="number"):[]}catch{return[]}}function On(){if(v.mode!=="examples"&&!R)return;let e=Me(),t=Gt(),n=t.findIndex((a)=>a.key===e);if(Z()===Le()){if(n<0)return;t.splice(n,1)}else{if(n===0&&Date.now()-t[0].updated<30000)return;if(n>=0)t.splice(n,1);let a=R?`Shared · ${Q(R.entryPath??R.path)}`:v.path===V?"scratch.yodl":Q(v.path);t.unshift({key:e,path:v.path,label:a,updated:Date.now(),...R?{shared:!0}:{}})}ue("drafts",JSON.stringify(t.slice(0,Nn))),Qt()}function Fn(e){let t=Math.floor((Date.now()-e)/60000);if(t<1)return"Just now";if(t<60)return`${t} min ago`;let n=Math.floor(t/60);if(n<24)return`${n} h ago`;let r=Math.floor(n/24);return r===1?"Yesterday":r<14?`${r} days ago`:new Date(e).toLocaleDateString()}function Ee(){if(!J)return;if(ue(Me(),Z()),!R)ue("selection",JSON.stringify(v));i("save-status").textContent=ct?"Draft saved locally":"Draft not saved · storage unavailable",i("draft-badge").hidden=W!==O()||Z()===Le(),On()}var fe=()=>P.findIndex((e)=>it(e)===v.path),Bn=(e)=>Object.entries(Ae).find(([,t])=>t.some((n)=>n.id===e))?.[0],Zt=new Map,Kn=(e)=>{let t=e.replace(/^\d+_/,"").replaceAll("_"," ");return t[0].toUpperCase()+t.slice(1)},Te=(e)=>String(e).padStart(2,"0");function ze(){let e=fe(),t=P[e];if(!t)return;let n=document.createElement("span");n.className="lesson-prefix",n.textContent="Tour · ",i("lesson-position").replaceChildren(n,`Lesson ${Te(e+1)} of ${P.length}`),ht(),i("lesson-topic").textContent=t.topic,i("lesson-title").textContent=t.title,i("lesson-intro").textContent=t.intro,i("lesson-observe").textContent=t.observe,i("lesson-challenge").textContent=t.challenge,i("lesson-concepts").replaceChildren(...t.concepts.map((p,m)=>{let E=document.createElement("li"),j=document.createElement("span");j.className="n",j.textContent=Te(m+1);let C=document.createElement("span");return C.textContent=p,E.append(j,C),E})),g("suggested-stage").textContent=`Open ${F[t.stage].label} →`;let r=Bn(t.id);if(i("lesson-reference").hidden=!r,r){let p=i("related-docs");p.textContent=Zt.get(r)??Kn(r),p.href=qe(r),p.onclick=(m)=>{m.preventDefault(),q({section:"docs",chapter:r})}}let a=P[e-1],y=P[e+1];g("previous-lesson").disabled=!a,i("previous-title").textContent=a?.title??"",g("next-lesson").disabled=!1,i("next-title").textContent=y?.title??"Explore the Playground";for(let[p,m]of Array.from(i("lesson-progress").children).entries())if(p===e)m.setAttribute("aria-current","step");else m.removeAttribute("aria-current");for(let[p,m]of Array.from(i("lesson-list").children).entries())if(p===e)m.setAttribute("aria-current","step");else m.removeAttribute("aria-current")}function jn(){i("lesson-progress").style.setProperty("--lessons",String(P.length)),i("lesson-progress").replaceChildren(...P.map((e,t)=>{let n=document.createElement("button");return n.type="button",n.title=`${Te(t+1)} · ${e.title}`,n.setAttribute("aria-label",`Lesson ${t+1}: ${e.title}`),n.onclick=()=>void q({section:"tour",lesson:e.id}),n})),i("lesson-list").replaceChildren(...P.map((e,t)=>{let n=document.createElement("button");return n.type="button",n.innerHTML='<span class="n"></span><span><strong></strong><small></small></span>',n.querySelector(".n").textContent=Te(t+1),n.querySelector("strong").textContent=e.title,n.querySelector("small").textContent=e.topic,n.onclick=()=>{$e(!1),q({section:"tour",lesson:e.id})},n}))}function $e(e){if(i("lesson-list-scrim").hidden=!e,g("lesson-list-button").setAttribute("aria-expanded",String(e)),e)i("lesson-list").querySelector("[aria-current]")?.scrollIntoView({block:"nearest"})}function Wn(e){let t=be[e]??"";return`${t.split(`
`).length} lines${t.includes("@simulation")?" · simulation":""}`}function pt(){ht(),i("example-list").replaceChildren(...we.map((e)=>{let t=document.createElement("button");t.type="button",t.className="entry";let n=!R&&v.path===e;if(n)t.setAttribute("aria-current","true");let r=document.createElement("span");r.className="entry-name",r.textContent=Q(e).replace(/\.yodl$/,"");let a=document.createElement("span");return a.className="entry-note",a.textContent=n?Q(e):Wn(e),t.append(r,a),t.onclick=()=>{ue("last:examples",e),le(!1),q({section:"playground",path:e})},t})),Qt()}function Qt(){let e=Gt().filter((t)=>t.shared||(t.path===V||we.includes(t.path))&&t.key===Jt(t.path));i("drafts-empty").hidden=e.length>0,i("draft-list").replaceChildren(...e.map((t)=>{let n=document.createElement("button");if(n.type="button",n.className="entry draft",t.key===Me()&&(v.mode==="examples"||R))n.setAttribute("aria-current","true");let r=document.createElement("span");r.className="entry-name",r.textContent=t.label;let a=document.createElement("span");return a.className="entry-note",a.textContent=Fn(t.updated),n.append(r,a),n.onclick=()=>{if(le(!1),t.shared){let y=t.key.slice(7);try{q({section:"shared",shared:cn(Xe(`#code=${y}`),y)})}catch(p){ae(p.message)}}else q({section:"playground",path:t.path})},n}))}var zn=()=>v.mode==="tour"?P[fe()]?.stage:void 0,me=matchMedia("(max-width: 819px)"),Un=matchMedia("(max-width: 639px)"),ve=he("sidebar")==="hidden";function mt(){let e=i("editor-view");e.dataset.sidebar=ve?"hidden":"shown";let t=g("sidebar-toggle");t.setAttribute("aria-expanded",String(!ve));let n=N==="tour"?"lesson":"examples";t.title=ve?`Show ${n}`:`Hide ${n}`,t.setAttribute("aria-label",t.title)}function Vn(e){ve=e,ue("sidebar",e?"hidden":"shown"),mt()}function le(e){let t=i("editor-view");if(t.dataset.sheet==="open"===e)return;if(t.dataset.sheet=e?"open":"closed",g("context-toggle").setAttribute("aria-expanded",String(e)),i("sidebar").inert=me.matches&&!e,e&&me.matches)i(N==="tour"?"guide-body":"library").scrollTop=0}function ht(){let e=i("context-label");if(N==="tour"){let t=fe(),n=document.createElement("small");n.textContent=`${Te(t+1)}/${P.length}  `,e.replaceChildren(n,P[t]?.title??"")}else e.textContent=R?"Examples & drafts · shared circuit":"Examples & drafts";g("context-toggle").title=N==="tour"?"Show or hide the lesson":"Show or hide examples and drafts"}new ResizeObserver(()=>en()).observe(i("output-view-switch").parentElement);me.addEventListener("change",()=>{i("sidebar").inert=me.matches&&i("editor-view").dataset.sheet!=="open"});function Xt(){let e=v.stage==="test"||J!==void 0&&Vt(Z()),t=zn();i("stage-tabs").replaceChildren(...Object.keys(F).filter((r)=>r!=="test"||e).map((r)=>{let a=document.createElement("button");if(a.type="button",a.className="stage-tab",a.dataset.stage=r,a.title=F[r].description,a.setAttribute("aria-pressed",String(r===v.stage)),a.append(F[r].short),r===t&&r!==v.stage){let y=document.createElement("span");y.className="suggested",y.title="Suggested for this lesson",a.append(y)}return a.onclick=()=>gt(r),a}));let n=i("stage-select");n.replaceChildren(...Array.from(i("stage-tabs").children).map((r)=>{let a=r.dataset.stage;return new Option(`${F[a].label}${a===t?" · suggested":""}`,a)})),n.value=v.stage,n.title=F[v.stage].description,en()}function en(){let e=i("output-view-switch").parentElement,t=i("stage-tabs").scrollWidth+i("output-view-switch").offsetWidth+24;if(e.clientWidth>0&&t>e.clientWidth)e.dataset.compact="";else delete e.dataset.compact}function ye(e){i("output-pane").dataset.view=e,g("view-output").setAttribute("aria-pressed",String(e==="output")),g("view-simulate").setAttribute("aria-pressed",String(e==="simulation")),b?.output.layout()}function Fe(){let e=F[v.stage];if(i("stage-description").textContent=e.description,i("stage-description").title=e.description,b)H.editor.setModelLanguage(b.output.getModel(),e.language);Xt()}function tn(){ye("output"),dt(),ze(),pt(),i("related-docs-menu").hidden=!R?.origin,Fe()}function rt(){for(let t of Array.from(document.querySelectorAll(".mode-switch button")))t.setAttribute("aria-pressed",String(t.dataset.mode===N));let e=N!=="docs";if(i("editor-view").hidden=!e,i("docs-view").hidden=e,i("editor-view").dataset.section=N,i("guide").hidden=N!=="tour",i("library").hidden=N!=="playground",mt(),ht(),e)document.title=N==="tour"?"Tour · Yodl":"Playground · Yodl",b?.input.layout(),b?.output.layout();else pe.stop()}function nn(){if(i("problems").hidden=!0,ne=null,!J)return;for(let e of[J,...Y.values()])H.editor.setModelMarkers(e,"yodl",[])}function ft(){if(Wt.cancel("playground"),pe.stop(),Ke++,Dn(),lt=++Yt,nn(),g("copy-output").disabled=!0,g("output-download").disabled=!0,g("download-output").disabled=!0,se(G?"Source changed · output is out of date":"Ready to compile"),i("stage-tabs").querySelector('[data-stage="test"]')!==null!==(v.stage==="test"||Vt(Z())))Xt()}function Ot(e,t){if(b)Ee();if(R=t,v=e,ze(),pt(),!b)return;Pn(),pe.clear(),Se=!0,b.input.setValue(he(Me())??R?.source??We(v.path)),Se=!1,b.input.setScrollTop(0),b.output.setValue(""),G="",je=-1,tn(),Ee(),ft(),de()}function gt(e){if(v.stage=e,!b){Fe();return}pe.clearFrame(),b.output.setValue(""),G="",Fe(),ye("output"),Ee(),ft(),de()}function Re(e){i("editors").dataset.view=e,g("source-tab").setAttribute("aria-pressed",String(e==="source")),g("output-tab").setAttribute("aria-pressed",String(e==="output")),b?.input.layout(),b?.output.layout()}function Yn(e){if(ye("output"),i("problems").hidden=!1,i("error-message").textContent=e,ke=[O(),...Y.keys()].find((t)=>He(e,t))??O(),ne=He(e,ke),g("jump-error").hidden=ne===null,ne){let t=ke===O()?J:Y.get(ke),n=t.validateRange(ne);ne=n,H.editor.setModelMarkers(t,"yodl",[{...n,message:e,severity:H.MarkerSeverity.Error}])}se(G?"Compilation failed · showing previous output":"Compilation failed · check diagnostics","error")}async function de(){if(!b)return;pe.stop(),pe.clearFrame();let e=++Yt;lt=e;let t=Ke;nn(),se("Compiling…","loading");let n=await Wt.compile("playground",{source:Z(),path:O(),stage:v.stage,files:ut()});if(!n||e!==lt)return;if(n.error!==void 0){Yn(n.error);return}G=n.output??"",je=t,b.output.setValue(G),Fe(),ye("output"),g("copy-output").disabled=!G,g("output-download").disabled=!G,g("download-output").disabled=!G,se(`Compiled · ${Math.round(n.duration)} ms`,"success")}function on(e,t){let n=URL.createObjectURL(new Blob([t],{type:"text/plain;charset=utf-8"})),r=document.createElement("a");r.href=n,r.download=e,r.click(),setTimeout(()=>URL.revokeObjectURL(n),1000)}async function rn(e,t){try{await navigator.clipboard.writeText(e);let n=t.textContent;t.textContent="Copied",setTimeout(()=>{t.textContent=n},1800)}catch{if(ae("Clipboard access is unavailable. Select the text and use your browser’s Copy command."),t.id==="copy-share")i("share-url").select();else b.output.focus(),b.output.setSelection(b.output.getModel().getFullModelRange())}}function sn(){if(je===Ke)on(`${Q(v.path).replace(/\.yodl$/,"")}.${F[v.stage].extension}`,G)}function Ue(e){i("file-menu").hidden=!e,g("menu-button").setAttribute("aria-expanded",String(e))}function an(){if(!b)return;let e=new URL(location.href);if(e.search="",e.hash=`code=${Pe({...v,source:Z(),files:R?.files,entryPath:R?.entryPath,origin:R?.origin})}`,e.href.length>32000){ae("This circuit is too large for a reliable share link. Use Download source instead.");return}i("share-url").value=e.href,i("share-dialog").showModal(),i("share-url").select()}function ln(){if(b&&W===O())i("reset-dialog").showModal()}function cn(e,t){return{code:t,mode:e.mode,path:e.path,stage:e.stage,source:e.source,files:e.files??{},entryPath:e.entryPath,origin:e.origin}}function Jn(e){if(v.mode===e&&!R)return v.path;let t=he(`last:${e}`);if(xe({mode:e,path:t,stage:"write_firrtl"}))return t;return e==="tour"?Qe.path:V}function Gn(){let e=new URL(location.href);if(e.search="",e.hash="",N==="docs"){if(e.searchParams.set("mode","docs"),Ce)e.searchParams.set("chapter",Ce);if(st)e.hash=st}else if(R)e.hash=`code=${R.code}`;else if(N==="tour")e.searchParams.set("lesson",P[fe()]?.id??P[0].id);else if(e.searchParams.set("mode","examples"),v.path!==V)e.searchParams.set("example",Q(v.path).replace(/\.yodl$/,""));return e.href}function Ft(e){let t=Gn();if(e==="none"||t===location.href)return;if(e==="push")history.pushState(null,"",t);else history.replaceState(null,"",t)}var Bt=0;async function q(e,t="push"){let n=++Bt;if($e(!1),e.section==="docs"){N="docs",rt(),Ce=e.chapter,st=e.anchor;let r=await Ve.show(e.chapter,e.anchor);if(n!==Bt)return;if(Ce=r?.slug??e.chapter,r)document.title=`${r.title} · Yodl`;Ft(t);return}if(e.section==="shared")N=jt(e.shared.mode),rt(),Ot({mode:e.shared.mode,path:e.shared.path,stage:e.shared.stage},e.shared),ae("Shared circuit opened. Your existing lesson and example drafts are kept separately.");else{N=e.section,rt();let r=N==="tour"?"tour":"examples",a=e.section==="tour"?P.find((m)=>m.id===e.lesson):void 0,y=e.section==="playground"&&e.path&&xe({mode:r,path:e.path,stage:"write_firrtl"})?e.path:a?it(a):Jn(r);if(!(!R&&v.mode===r&&v.path===y)){ue(`last:${r}`,y);let m=r==="tour"?P.find((E)=>it(E)===y).stage:"write_firrtl";Ot({mode:r,path:y,stage:m})}else if(!b)ze(),pt();if(e.section==="tour")i("guide-body").scrollTop=0}Qn(),Ft(t)}function dn(){let e=new URLSearchParams(location.search);if(location.hash.startsWith("#code="))try{let n=location.hash.slice(6);return{section:"shared",shared:cn(Xe(location.hash),n)}}catch(n){ae(n.message)}if(e.get("mode")==="docs")return{section:"docs",chapter:e.get("chapter")??void 0,anchor:location.hash.slice(1)||void 0};let t=P.find((n)=>n.id===e.get("lesson"));if(t)return{section:"tour",lesson:t.id};if(e.get("mode")==="examples")return{section:"playground",path:we.find((r)=>Q(r)===`${e.get("example")}.yodl`)??V};return{section:jt(v.mode)}}var Ve=Dt({navigate:(e,t)=>void q({section:"docs",chapter:e,anchor:t}),openLesson:(e)=>void q({section:"tour",lesson:e}),openExample(e,t,n,r){let a={mode:"examples",path:V,stage:r,source:n,files:t.files,entryPath:t.path,origin:`${e.slug}.html#${t.id}`},y=Pe(a);if(y.length>30000){ae("This example is too large for a reliable handoff. Copy the source instead.");return}q({section:"shared",shared:{...a,code:y}})}}),Zn=It({lessons:P,openLesson:(e)=>void q({section:"tour",lesson:e}),openDoc:(e,t)=>void q({section:"docs",chapter:e,anchor:t})});function Qn(){return qt??=Xn().catch((e)=>{qt=void 0,se("Could not load the editor","error"),i("input-panel").textContent="The editor could not load. Check your connection and reload the page.",ae(`Playground startup failed: ${e.message??String(e)}`)})}async function Xn(){b=await At(),J=b.input.getModel(),W=O(),Se=!0,b.input.setValue(he(Me())??R?.source??We(v.path)),Se=!1,tn(),Ee();for(let e of[g("compile-button"),g("menu-button"),g("view-simulate")])e.disabled=!1;pe.enable(),g("compile-shortcut").textContent=ot?"⌘↵":"Ctrl ↵",i("share-shortcut").textContent=ot?"⌘S":"Ctrl S",i("new-shortcut").textContent=ot?"⌘N":"Ctrl N",b.input.addAction({id:"compile-yodl",label:"Compile Yodl",keybindings:[H.KeyMod.CtrlCmd|H.KeyCode.Enter],run:de}),b.output.addAction({id:"compile-yodl-output",label:"Compile Yodl",keybindings:[H.KeyMod.CtrlCmd|H.KeyCode.Enter],run:de});for(let e of[b.input,b.output])e.addCommand(H.KeyMod.CtrlCmd|H.KeyCode.KeyK,()=>Zn.open());b.input.onDidChangeModelContent(()=>{if(Se||b.input.getModel()!==J)return;Ee(),ft()}),b.input.onDidChangeCursorPosition((e)=>{i("cursor-position").textContent=`Ln ${e.position.lineNumber}, Col ${e.position.column}`}),eo(),se("Ready to compile"),Ut(),de()}function un(){if(N!=="playground"){q({section:"playground",path:V});return}if(b&&v.path===V&&!R&&Z()!==Le())ln();else q({section:"playground",path:V})}function eo(){let e=i("resize-handle"),t=i("editors"),n=()=>getComputedStyle(t).getPropertyValue("--split-axis").trim()==="y",r=Number(he("split")??50);function a(p){r=Math.max(20,Math.min(80,Number.isFinite(p)?p:50)),t.style.setProperty("--split-a",`${r}fr`),t.style.setProperty("--split-b",`${100-r}fr`),e.setAttribute("aria-valuenow",String(Math.round(r))),e.setAttribute("aria-orientation",n()?"horizontal":"vertical")}a(r),e.onpointerdown=(p)=>{e.setPointerCapture(p.pointerId),e.classList.add("dragging"),p.preventDefault()},e.onpointermove=(p)=>{if(!e.hasPointerCapture(p.pointerId))return;let m=t.getBoundingClientRect();a(n()?(p.clientY-m.top)/m.height*100:(p.clientX-m.left)/m.width*100)};let y=()=>{e.classList.remove("dragging"),ue("split",String(r))};e.onlostpointercapture=y,e.onpointerup=(p)=>{if(e.hasPointerCapture(p.pointerId))e.releasePointerCapture(p.pointerId)},e.onkeydown=(p)=>{let m=n()?"ArrowUp":"ArrowLeft",E=n()?"ArrowDown":"ArrowRight";if(![m,E,"Home","End"].includes(p.key))return;p.preventDefault(),a(p.key==="Home"?20:p.key==="End"?80:r+(p.key===m?-5:5)),y()},matchMedia("(max-width: 1199px)").addEventListener("change",()=>a(r))}for(let e of Array.from(document.querySelectorAll(".mode-switch button")))e.onclick=()=>void q(e.dataset.mode==="docs"?{section:"docs",chapter:Ce}:e.dataset.mode==="tour"?{section:"tour"}:{section:"playground"});document.querySelector(".site-brand").onclick=(e)=>{e.preventDefault(),q({section:"tour",lesson:P[0].id})};g("lesson-list-button").onclick=()=>$e(i("lesson-list-scrim").hidden===!0);i("lesson-list-scrim").onclick=(e)=>{if(e.target===e.currentTarget)$e(!1)};g("previous-lesson").onclick=()=>{let e=P[fe()-1];if(e)q({section:"tour",lesson:e.id})};g("next-lesson").onclick=()=>{let e=P[fe()+1];q(e?{section:"tour",lesson:e.id}:{section:"playground"})};g("suggested-stage").onclick=()=>{if(!b)return;if(gt(P[fe()].stage),me.matches)le(!1),Re("output")};g("new-file").onclick=()=>{le(!1),un()};g("sidebar-toggle").onclick=()=>Vn(!ve);g("context-toggle").onclick=()=>le(i("editor-view").dataset.sheet!=="open");i("stage-select").onchange=()=>gt(i("stage-select").value);g("compile-button").onclick=()=>{if(de(),Un.matches)Re("output")};g("view-output").onclick=()=>ye("output");g("view-simulate").onclick=()=>ye("simulation");g("source-tab").onclick=()=>Re("source");g("output-tab").onclick=()=>Re("output");g("menu-button").onclick=()=>Ue(i("file-menu").hidden===!0);i("file-menu").onclick=()=>Ue(!1);document.addEventListener("pointerdown",(e)=>{if(!i("file-menu").hidden&&!i("file-menu").parentElement.contains(e.target))Ue(!1)});g("share-button").onclick=an;g("download-source").onclick=()=>{if(b)on(Q(W),b.input.getValue())};g("download-output").onclick=sn;g("output-download").onclick=sn;g("copy-output").onclick=()=>{if(je===Ke)rn(G,g("copy-output"))};g("reset-button").onclick=ln;g("related-docs-menu").onclick=()=>{let[e,t]=R?.origin?.replace(/\.html$/,"").split("#")??[];if(e)q({section:"docs",chapter:e,anchor:t})};g("jump-error").onclick=()=>{if(!ne||!b)return;Re("source"),Be(ke),b.input.setSelection(ne),b.input.revealRangeInCenter(ne),b.input.focus()};i("reset-dialog").addEventListener("close",()=>{if(i("reset-dialog").returnValue==="reset")J.setValue(Le())});g("copy-share").onclick=()=>void rn(i("share-url").value,g("copy-share"));document.addEventListener("keydown",(e)=>{let t=e.metaKey||e.ctrlKey;if(e.key==="Escape"){if(!i("lesson-list-scrim").hidden)$e(!1);else if(me.matches&&i("editor-view").dataset.sheet==="open")le(!1);Ue(!1)}if(N==="docs"||!t)return;if(e.key==="Enter"&&!e.defaultPrevented)e.preventDefault(),de();else if(e.key.toLowerCase()==="s"&&!e.altKey)e.preventDefault(),an();else if(e.key.toLowerCase()==="n"&&!e.altKey&&N==="playground")e.preventDefault(),un()});window.addEventListener("popstate",()=>void q(dn(),"none"));window.addEventListener("pagehide",()=>Ve.dispose());jn();mt();le(!1);se("Starting editor…","loading");async function to(){if(!location.hash.startsWith("#example="))return!1;let e=await Ve.show(new URLSearchParams(location.search).get("chapter")??void 0);try{let t=_e(location.hash.slice(9)),n=e?.examples.find((a)=>a.id===t.id);if(t.version!==1||!n||typeof t.source!=="string"||!Object.hasOwn(F,t.stage))throw Error();let r={mode:"examples",path:V,stage:t.stage,source:t.source,files:n.files,entryPath:n.path,origin:`${e.slug}.html#${n.id}`};await q({section:"shared",shared:{...r,code:Pe(r)}},"replace")}catch{return ae("This shared example could not be opened. The original examples are shown in the guide."),!1}return!0}var Ne=dn();if(me.matches&&Ne.section==="tour")le(!0);if(Ne.section==="docs"&&location.hash.startsWith("#example="))to().then((e)=>{if(!e)q({...Ne,anchor:void 0},"replace")});else q(Ne,"replace");setTimeout(()=>void Ve.load().then((e)=>{for(let t of e.chapters)Zt.set(t.slug,t.title);if(N==="tour")ze()}).catch(()=>{}),1500);

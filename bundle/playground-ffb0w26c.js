var Ue={"01_presentation":[{id:"gates",title:"Your first circuit"}],"02_getting_started":[{id:"gates",title:"Your first circuit"},{id:"counter",title:"Describe the next state"}],"03_data_types":[{id:"widths",title:"Give every bit a place"},{id:"records",title:"Name a group of signals"}],"04_constructs":[{id:"modules",title:"Connect reusable modules"},{id:"generics",title:"Parameterise a design"},{id:"packages",title:"Organise a design"}],"05_operators":[{id:"bits",title:"Take signals apart"}],"06_control_flow":[{id:"selection",title:"Choose a signal"},{id:"vectors",title:"Build parallel hardware"}],"07_built_in_functions":[{id:"bits",title:"Take signals apart"},{id:"counter",title:"Describe the next state"}],"08_primitive_modules":[{id:"registers",title:"Remember a value"},{id:"memory",title:"Store a small table"}],"09_external_modules":[{id:"modules",title:"Connect reusable modules"}]};function Tt(e){let t=new TextEncoder().encode(JSON.stringify(e)),n="";for(let o of t)n+=String.fromCharCode(o);return btoa(n).replaceAll("+","-").replaceAll("/","_").replace(/=+$/,"")}function Ve(e){if(e.length>200000)throw Error("This shared program is too large to open.");let t=atob(e.replaceAll("-","+").replaceAll("_","/"));return JSON.parse(new TextDecoder().decode(Uint8Array.from(t,(n)=>n.charCodeAt(0))))}function lt(e){return typeof e==="string"&&/^(book\/src|examples|tour)\/[\w./-]+\.yodl$/.test(e)&&!e.split("/").some((t)=>t===".."||t===".")}function Mt(e){return!!e&&typeof e==="object"&&!Array.isArray(e)&&Object.entries(e).every(([t,n])=>lt(t)&&typeof n==="string")}var Rt=[{id:"gates",title:"Your first circuit",topic:"Signals & modules",intro:"A Yodl program describes hardware. A module connects named inputs to named outputs; the connections operate continuously.",concepts:["bool is a one-bit signal.","The expression a and b describes a logic gate. It does not wait for a clock."],observe:"In FIRRTL, find the two input ports, the output port, and the and operation.",challenge:"Change and to xor. The output will describe a gate that is high when exactly one input is high.",stage:"write_firrtl",file:"01-gates.yodl"},{id:"widths",title:"Give every bit a place",topic:"Integers & arithmetic",intro:"Hardware signals have fixed widths. u8 is an unsigned eight-bit integer; s8 is a signed eight-bit integer. Choose the output width to retain the bits you need.",concepts:["Adding two eight-bit unsigned values can require nine bits.","Sized literals spell out width and base: 8'hFF is eight bits of hexadecimal FF. Signedness changes require an explicit cast."],observe:"Inspect the nine-bit sum and sixteen-bit product ports. Switch to Typed to see expression types.",challenge:"Change sum from u9 to u8. Narrowing keeps the low eight bits, so a carry no longer fits in the output.",stage:"write_firrtl",file:"02-widths.yodl"},{id:"selection",title:"Choose a signal",topic:"Conditions & multiplexers",intro:"Conditions select between signals. Both alternatives describe hardware; a condition does not make the circuit execute one software branch at a time.",concepts:["Use if for a two-way choice.","Use match for several cases, with _ as the default."],observe:"Look for mux operations in FIRRTL: these are the signal selectors described by the conditions.",challenge:"Add a 2 case to match that returns a xor b. Keep the default case.",stage:"write_firrtl",file:"03-selection.yodl"},{id:"bits",title:"Take signals apart",topic:"Slices & built-ins",intro:"Individual bits and slices let you work with the representation of a value. Built-in functions have names ending in !.",concepts:["word[7:4] takes bits seven through four, inclusive.","cat! joins bit strings in order; xorr reduces a signal to its parity bit."],observe:"Find bits, cat, and xorr operations in the FIRRTL output.",challenge:"Change swapped to cat!(low, low). Both halves of the output now come from the same four input bits.",stage:"write_firrtl",file:"04-bits.yodl"},{id:"vectors",title:"Build parallel hardware",topic:"Vectors & loops",intro:"A vector groups a fixed number of values. A for loop creates repeated hardware at compile time, so the loop bounds must be known before the circuit runs.",concepts:["[4]u8 is four eight-bit elements.","0..<Lanes excludes the upper bound. All four lanes exist in parallel."],observe:"The Simplified output expands the loop into individual assignments. Switch to FIRRTL to see the vector ports.",challenge:"Change Lanes from 4 to 8. Compile again and count the expanded assignments.",stage:"write_simplified",file:"05-vectors.yodl"},{id:"records",title:"Name a group of signals",topic:"Records & type aliases",intro:"Records collect related signals into named fields. A type alias gives the collection a reusable name without allocating storage.",concepts:["Access a field with . followed by its name.","A record spread copies fields; later fields override the copied values."],observe:"Find the r, g, and b fields in the output ports. They remain individual signals within a bundle.",challenge:"Also override b with 0 in muted. Only the red channel will pass through.",stage:"write_firrtl",file:"06-records.yodl"},{id:"modules",title:"Connect reusable circuits",topic:"Instances & ports",intro:"Define a module once and instantiate it wherever you need that hardware. Each instance is a separate circuit with its own connections.",concepts:["Named arguments connect inputs when creating an instance.","Access an instance output with .sum. Top is the entry circuit in this design."],observe:"Find two Adder instances under Top. They share a definition but connect to different inputs.",challenge:"Connect the second adder to a and c instead of b and c.",stage:"write_firrtl",file:"07-modules.yodl"},{id:"generics",title:"Parameterise a design",topic:"Compile-time parameters",intro:"Generic parameters configure hardware before it runs. Nat parameters describe sizes; Type parameters let a module work with different signal types.",concepts:["uint[Width] uses a compile-time width.","Instantiation specialises each generic module with concrete parameters. These parameters are not input ports."],observe:"Monomorphised output shows concrete versions of the generic modules. Compare it with Source.",challenge:"Change the wide input and output from u16 to u12, and change Mask[16] to Mask[12].",stage:"write_mono",file:"08-generics.yodl"},{id:"registers",title:"Remember a value",topic:"Clocked state",intro:"Combinational logic has no memory. Reg adds state: q is the current value and d is the value sampled at the next rising clock edge.",concepts:["Reg[u8] stores eight bits.","rst resets the register to zero synchronously. en controls whether it captures a new value."],observe:"Find the register and its clock, reset, and enable logic in FIRRTL. The output reads the stored q value.",challenge:"Connect en to true instead of enable. The register will capture data on every rising edge unless reset is asserted.",stage:"write_firrtl",file:"09-registers.yodl"},{id:"counter",title:"Describe the next state",topic:"Feedback & constants",intro:"A counter feeds its current register value through combinational logic to compute the next value. The register breaks the feedback path into clock cycles.",concepts:["clog2!(Limit) computes the number of address bits needed for Limit values.","The comparison makes the counter wrap after Limit - 1. Reset establishes the initial zero state."],observe:"Follow the register output through the increment and selection logic back to its input.",challenge:"Change Limit from 10 to 16. The width stays four bits, but the wrap comparison changes.",stage:"write_firrtl",file:"10-counter.yodl"},{id:"packages",title:"Organise a design",topic:"Packages & names",intro:"Packages group declarations under a namespace. Qualified names make it clear where a reusable module belongs.",concepts:["Use :: to access a declaration inside a package.","A file brought in with import is also wrapped in a package named after the file. Larger examples demonstrate imports."],observe:"Find the qualified Logic::Invert name in Source, then switch to FIRRTL to inspect its instance.",challenge:"Add another Invert instance after the first and connect q to its output. Two inversions restore the original signal.",stage:"write_source",file:"11-packages.yodl"},{id:"memory",title:"Store a small table",topic:"Memory & latency",intro:"Memory describes indexed storage with explicit read and write ports. Latency is part of the interface: this design requests a read latency of one cycle.",concepts:["Depth is the number of stored words; T is the type of each word.","Read and write ports carry clocks, addresses, and enables. A true write mask enables the whole byte."],observe:"Find the memory depth, read latency, and write latency in FIRRTL. Compilation shows structure; the playground does not simulate clock cycles.",challenge:"Increase Depth to 32 and change addr from u4 to u5 so every word remains addressable.",stage:"write_firrtl",file:"12-memory.yodl"}];var K={write_source:{label:"Source",short:"Source",extension:"yodl",language:"yodl",description:"Resolved source, with imported declarations available to the compiler."},write_mono:{label:"Monomorphised",short:"Mono",extension:"yodl",language:"yodl",description:"Generic modules specialised with concrete parameters."},write_typed:{label:"Typed",short:"Typed",extension:"yodl",language:"yodl",description:"Expressions annotated with their resolved types and widths."},write_simplified:{label:"Simplified",short:"Simplified",extension:"yodl",language:"yodl",description:"Core representation with loops expanded and expressions simplified."},write_firrtl:{label:"FIRRTL",short:"FIRRTL",extension:"fir",language:"firrtl",description:"Hardware represented as ports, operations, registers, and connections."},write_low_firrtl:{label:"Low FIRRTL",short:"Low",extension:"fir",language:"firrtl",description:"FIRRTL after lowering passes, ready for downstream tools."},write_rtlil:{label:"RTLIL",short:"RTLIL",extension:"il",language:"rtlil",description:"Hardware in the intermediate language used by Yosys."},test:{label:"Tests",short:"Tests",extension:"txt",language:"plaintext",description:"Run procedural testbenches and report each passing test."}};function Se(e,t){if(e.uri!==t||!e.range)return null;let{start:n,end:o}=e.range;return{startLineNumber:n.line+1,startColumn:n.character+1,endLineNumber:o.line+1,endColumn:o.character+1}}var Ce={...{"examples/Testbench.yodl":`module XorGate(a: bool, b: bool) -> (out: bool) {
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
`}},H=Rt,$e=Object.keys(Ce).filter((e)=>/^examples\/[^/]+\.yodl$/.test(e)).sort(),X="examples/Playground.yodl",ct={mode:"tour",path:`tour/${H[0].file}`,stage:"write_firrtl"};function Pe(e){if(!e||typeof e!=="object")return!1;let t=e;return Object.hasOwn(K,t.stage)&&(t.mode==="tour"?H.some((n)=>`tour/${n.file}`===t.path):t.mode==="examples"&&($e.includes(t.path)||t.path===X))}function ze(e){return Tt({...e,version:e.entryPath?2:1})}function dt(e){if(!e.startsWith("#code="))return null;try{let t=Ve(e.slice(6));if(![1,2].includes(t.version)||!Pe(t)||typeof t.source!=="string")throw Error();if(t.version===2&&(!lt(t.entryPath)||!Mt(t.files)||t.origin!==void 0&&!/^[a-zA-Z0-9_-]+\.html#[a-z0-9-]+$/.test(t.origin)))throw Error();if(t.version===1)return{version:1,mode:t.mode,path:t.path,stage:t.stage,source:t.source};return t}catch{throw Error("This share link is invalid, too large, or uses an unsupported version.")}}class _e{timeoutMs;worker;active;queue=[];timer;nextId=0;constructor(e=15000){this.timeoutMs=e}compile(e,t){return this.cancel(e),new Promise((n)=>{this.queue.push({owner:e,request:{...t,id:++this.nextId},resolve:n}),this.pump()})}cancel(e){if(this.queue=this.queue.filter((t)=>{if(t.owner!==e)return!0;return t.resolve(null),!1}),this.active?.owner===e)this.worker?.terminate(),this.worker=void 0,this.finish(null)}dispose(){for(let e of this.queue)e.resolve(null);if(this.queue=[],this.active)this.cancel(this.active.owner);this.worker?.terminate(),this.worker=void 0}finish(e){clearTimeout(this.timer);let t=this.active;this.active=void 0,t?.resolve(e),this.pump()}pump(){if(this.active||!this.queue.length)return;let e=this.active=this.queue.shift(),t=(n)=>{if(this.active!==e)return;this.worker?.terminate(),this.worker=void 0,this.finish({id:e.request.id,error:n,duration:0})};try{this.worker??=new Worker(new URL("./playground-worker-cxe13d5w.js",import.meta.url),{type:"module"}),this.worker.onmessage=(n)=>{if(this.active===e&&n.data.id===e.request.id)this.finish(n.data)},this.worker.onerror=()=>t("The compiler worker could not run. Try Compile again."),this.timer=setTimeout(()=>t("Compilation exceeded 15 seconds. Try a smaller design or reduce compile-time loop bounds."),this.timeoutMs),this.worker.postMessage(e.request)}catch(n){t(`Could not start the compiler: ${n.message}`)}}}class ut{startupTimeoutMs;worker;requestId=0;activeId;request;startupTimer;constructor(e=30000){this.startupTimeoutMs=e}start(e,t){this.stop();let n=++this.requestId;this.activeId=n,this.request=e;let o=this.worker=new Worker(new URL("./playground-worker-cxe13d5w.js",import.meta.url),{type:"module"});o.onmessage=(r)=>{if(this.worker!==o||r.data.id!==n)return;clearTimeout(this.startupTimer),t(r.data)},o.onerror=()=>{if(this.worker!==o)return;this.stop(),t({id:n,type:"error",error:"The simulation worker could not run. Try Run again."})},this.startupTimer=setTimeout(()=>{if(this.worker!==o)return;this.stop(),t({id:n,type:"error",error:"Simulation compilation timed out. Try a smaller design."})},this.startupTimeoutMs),o.postMessage({...e,id:n,simulate:{...e.simulate,mode:"realtime",action:e.simulate?.action??"run"}})}pause(){this.postControl("pause")}resume(e){this.postControl("resume",e)}command(e,t){this.postControl(e,t)}setInputs(e){if(!this.request?.simulate)return;this.request={...this.request,simulate:{...this.request.simulate,inputs:e}},this.postControl("settle")}stop(){clearTimeout(this.startupTimer),this.worker?.terminate(),this.worker=void 0,this.activeId=void 0,this.request=void 0}postControl(e,t){if(!this.worker||this.activeId===void 0||!this.request)return;this.worker.postMessage({id:this.activeId,control:{action:e,options:t,...e==="settle"?{inputs:this.request.simulate?.inputs}:{}}})}}var $t=[{id:"teal",label:"Teal"},{id:"cobalt",label:"Cobalt"},{id:"moss",label:"Moss"},{id:"plum",label:"Plum"},{id:"ochre",label:"Ochre"},{id:"signal",label:"Signal"},{id:"ember",label:"Ember"}];function Pt(e){return getComputedStyle(document.documentElement).getPropertyValue(`--${e}`).trim()}function _t(e){try{return localStorage.getItem(e)}catch{return null}}function Dt(e,t){try{localStorage.setItem(e,t)}catch{}}function At(e,t){let n=matchMedia("(prefers-color-scheme: dark)"),o=Array.from(e.querySelectorAll("[data-theme-preference]")),r=_t("yodl-playground-v2:theme"),d=r==="light"||r==="dark"?r:"system",s=()=>{let l=d==="dark"||d==="system"&&n.matches;document.documentElement.dataset.theme=l?"dark":"light";for(let g of o)g.setAttribute("aria-pressed",String(g.dataset.themePreference===d));t(l)};for(let l of o)l.addEventListener("click",()=>{d=l.dataset.themePreference,Dt("yodl-playground-v2:theme",d),s()});return n.addEventListener("change",s),s(),s}function Ht(e,t){let n=e.querySelector("#accent-button"),o=e.querySelector("#accent-menu"),r=e.querySelector("#accent-label"),d=Array.from(e.querySelectorAll(".swatch")),s=_t("yodl-playground-v2:accent"),l=$t.some((x)=>x.id===s)?s:"teal",g=()=>{document.documentElement.dataset.accent=l,r.textContent=$t.find((x)=>x.id===l).label;for(let x of d)x.setAttribute("aria-pressed",String(x.dataset.accent===l))},T=(x)=>{o.hidden=!x,n.setAttribute("aria-expanded",String(x))};n.addEventListener("click",()=>T(o.hidden===!0));for(let x of d)x.addEventListener("click",()=>{l=x.dataset.accent,Dt("yodl-playground-v2:accent",l),g(),t()});return document.addEventListener("pointerdown",(x)=>{if(!o.hidden&&!e.contains(x.target))T(!1)}),e.addEventListener("keydown",(x)=>{if(x.key==="Escape"&&!o.hidden)T(!1),n.focus()}),g(),g}var P,It;function Nt(){if(P)return Promise.resolve();return It??=Ln().catch((e)=>{throw It=void 0,e})}var Sn="./monaco-wn4p6kqb.js",Cn="./monaco-44nfyfsx.css";function En(e){return new Promise((t,n)=>{let o=document.createElement("link");o.rel="stylesheet",o.href=e,o.onload=()=>t(),o.onerror=()=>{o.remove(),n(Error("Could not load the editor styles. Reload the page to try again."))},document.head.append(o)})}async function Ln(){if(!window.monaco){let e,t=new Promise((n,o)=>{e=setTimeout(()=>o(Error("The code editor took too long to load. Try again.")),30000)});try{let n=Promise.all([En(new URL(Cn,import.meta.url).href),import(new URL(Sn,import.meta.url).href)]),[,o]=await Promise.race([n,t]);window.monaco=o.monaco}finally{clearTimeout(e)}}P=window.monaco,P.languages.register({id:"yodl"}),P.languages.setMonarchTokensProvider("yodl",{keywords:["declare","module","test","let","match","if","else","for","in","const","package","import","true","false"],typeKeywords:["uint","sint","bool","clock","type","Nat","Type"],wordOperators:["and","or","not","xor","nand","nor","xnor","shl","shr","andr","orr","xorr"],operators:["==","!=","<=",">=","<:",">:","+:","-:","..","..<","..=","+","-","*","/","%","=>","?",":",".","->","::"],symbols:/[=><!~?:&|+\-*/^%.]+/,tokenizer:{root:[[/\w+!/,"function"],[/\b[us]\d+\b/,"type"],[/[A-Z]\w*/,{cases:{"@typeKeywords":"type","@default":"ident.cap"}}],[/[a-zA-Z_]\w*/,{cases:{"@keywords":"keyword","@typeKeywords":"type","@wordOperators":"keyword.operator","@default":"identifier"}}],[/"([^"\\]|\\.)*$/,"string.invalid"],[/"/,{token:"string.quote",bracket:"@open",next:"@string"}],[/'[^'\\]'/,"string"],[/'\\.'/,"string"],[/\/\/.*$/,"comment"],[/\b\d+'[bhod]?\w+\b/,"number"],[/\b\d+(_\d+)*\b/,"number"],[/@symbols/,"delimiter"],[/[(){}\[\],;]/,"delimiter"],[/\s+/,"white"]],string:[[/[^\\"]+/,"string"],[/\\./,"string.escape"],[/"/,{token:"string.quote",bracket:"@close",next:"@pop"}]]}}),P.languages.setLanguageConfiguration("yodl",{comments:{lineComment:"//"},brackets:[["{","}"],["[","]"],["(",")"]],autoClosingPairs:[{open:"{",close:"}"},{open:"[",close:"]"},{open:"(",close:")"},{open:'"',close:'"'}]});for(let e of["firrtl","rtlil"])P.languages.register({id:e}),P.languages.setMonarchTokensProvider(e,{tokenizer:{root:[[e==="firrtl"?/;.*/:/#.*/,"comment"],[/"[^"\\]*(?:\\.[^"\\]*)*"/,"string"],[/\b(?:circuit|module|extmodule|input|output|wire|node|reg|regreset|mem|inst|of|when|else|connect|attribute|parameter|cell|end|process|sync|update|assign)\b/,"keyword"],[/\b(?:UInt|SInt|Clock|Reset|AsyncReset)\b/,"type"],[/\b(?:mux|add|sub|mul|and|or|xor|not|bits|cat|pad|eq|lt|gt)\b/,"function"],[/-?\b\d+(?:'[01xzm-]+)?\b/,"number"],[/[<>=:]+/,"delimiter"]]}});Ye()}var Tn={panel:"#fefdfc",ink:"#211c17",mute:"#69625d",line:"#e2dfdb",sunk:"#f3f1ed",bg:"#faf9f6",acc:"#008381","acc-soft":"#dbf3f1","k-kw":"#6b46a0","k-ty":"#00717f","k-fn":"#945a00","k-nm":"#2b7440","k-id":"#23588a"},M=(e)=>(typeof getComputedStyle==="function"?Pt(e):"")||Tn[e],G=(e)=>e.replace("#","");function Ye(){if(!P)return;let e=document.documentElement.dataset.theme==="dark";P.editor.defineTheme("yodl",{base:e?"vs-dark":"vs",inherit:!0,rules:[{token:"",foreground:G(M("ink"))},{token:"keyword",foreground:G(M("k-kw"))},{token:"keyword.operator",foreground:G(M("k-kw"))},{token:"identifier",foreground:G(M("ink"))},{token:"operator",foreground:G(M("mute"))},{token:"type.identifier",foreground:G(M("k-ty"))},{token:"type",foreground:G(M("k-ty"))},{token:"function",foreground:G(M("k-fn"))},{token:"number",foreground:G(M("k-nm"))},{token:"string",foreground:G(M("k-nm"))},{token:"ident.cap",foreground:G(M("k-id"))},{token:"comment",foreground:G(M("mute"))},{token:"delimiter",foreground:G(M("mute"))}],colors:{"editor.background":M("panel"),"editor.foreground":M("ink"),"editorLineNumber.foreground":M("mute")+"99","editorLineNumber.activeForeground":M("ink"),"editor.selectionBackground":M("acc-soft"),"editor.inactiveSelectionBackground":M("sunk"),"editor.lineHighlightBackground":M("sunk")+"00","editor.lineHighlightBorder":M("sunk")+"00","editorCursor.foreground":M("acc"),"editorIndentGuide.background1":M("line"),...Object.fromEntries([1,2,3,4,5,6].map((t)=>[`editorBracketHighlight.foreground${t}`,M("mute")])),"editorBracketHighlight.unexpectedBracket.foreground":M("mute"),"editorWidget.background":M("panel"),"editorWidget.border":M("line"),"scrollbarSlider.background":M("line")+"aa","scrollbarSlider.hoverBackground":M("mute")+"66"}}),P.editor.setTheme("yodl")}async function Mn(){let e=typeof document<"u"?document.fonts:void 0;if(!e)return;try{await Promise.race([e.load('13.5px "IBM Plex Mono"'),new Promise((t)=>setTimeout(t,1500))])}catch{}e.ready.then(()=>P?.editor.remeasureFonts?.())}async function qt(e,t={}){await Nt(),await Mn();let n={automaticLayout:!0,minimap:{enabled:!1},scrollBeyondLastLine:!1,fontSize:13.5,lineHeight:23,fontFamily:'"IBM Plex Mono", ui-monospace, SFMono-Regular, Consolas, monospace',padding:{top:18,bottom:18},renderLineHighlight:"none",glyphMargin:!1,folding:!0,lineNumbersMinChars:3,lineDecorationsWidth:18,overviewRulerLanes:0,"semanticHighlighting.enabled":!0,hideCursorInOverviewRuler:!0,overviewRulerBorder:!1,bracketPairColorization:{enabled:!1},guides:{indentation:!1,bracketPairs:!1},matchBrackets:"never",scrollbar:{useShadows:!1,verticalScrollbarSize:8,horizontalScrollbarSize:8},tabSize:4,insertSpaces:!0,fixedOverflowWidgets:!0};return e.replaceChildren(),P.editor.create(e,{...n,language:"yodl",ariaLabel:"Yodl source code",...t})}async function Ot(){await Nt();let e=P.editor.createModel("","yodl"),t=await qt(document.getElementById("input-panel"),{model:e}),n=await qt(document.getElementById("output-panel"),{readOnly:!0,language:"firrtl",ariaLabel:"Compiled output"});return{input:t,output:n}}var O=(e)=>document.getElementById(e),pt=16,Rn=10,$n=512;function Ft(e){let t={};for(let n of e.split(",")){let o=/^\s*([A-Za-z_$][\w$]*)(?::(\d+))?\s*=\s*(-?\d+)\s*$/.exec(n);if(!n.trim())continue;if(!o)throw Error(`Invalid input assignment: ${n}`);if(!Number.isSafeInteger(Number(o[3])))throw Error("Input exceeds the safe integer range.");t[o[1]]={width:Number(o[2]??32),value:Number(o[3])}}return t}function Pn(e){if(!e.known)return"x";if(e.width===1)return e.value==="0"?"0":"1";try{return`${e.width}'h${BigInt(e.value).toString(16)}`}catch{return e.value}}var _n=(e)=>{if(!e.known)return"x";try{return BigInt(e.value).toString(16)}catch{return e.value}};function Dn(e){if(e>=1e6)return`${(e/1e6).toFixed(1)} MHz`;if(e>=1e4)return`${Math.round(e/1000)} kHz`;if(e>=1000)return`${(e/1000).toFixed(1)} kHz`;return`${e<10?e.toFixed(1):Math.round(e)} Hz`}function jt(e){let t=new ut,n="ready",o,r=[],d,s,l=(i)=>O(i),g=(i)=>O(i),T=["simulation-top","simulation-clock","simulation-cycles-per-frame","simulation-clock-hz","simulation-refresh-fps"];function x(){let i=n==="running"||n==="stepping";l("simulation-run").textContent=i?"Pause":n==="paused"?"Resume":"Run",l("simulation-run").disabled=n==="starting"||n==="halted",l("simulation-reset").disabled=n==="ready"||n==="starting",l("simulation-stop").disabled=n==="ready"}function Q(i){let b=O("simulation-framebuffer");if(d=i,O("simulation-zoom-control").hidden=!i,!i){b.hidden=!0;return}if(b.hidden=!1,b.width!==i.width||b.height!==i.height)b.width=i.width,b.height=i.height,s=void 0;let E=(b.parentElement?.clientWidth||640)-32,R=O("simulation-zoom").value,v=R==="fit"?Math.min(E/i.width,480/i.height):Number(R);b.style.width=`${i.width*v}px`,b.style.height=`${i.height*v}px`;let u=b.getContext("2d");if(!u)return;let a=s??=u.createImageData(i.width,i.height),m=Math.ceil(i.width/32);for(let p=0;p<i.width*i.height;p++){let h=Math.floor(p/i.width),S=p%i.width,k=h*m+Math.floor(S/32),q=!(!i.valid||(i.packed?(i.valid[k]&1<<S%32)!==0:i.valid[p]!==0))?16711935:i.packed?(i.packed[k]&1<<S%32)!==0?i.onColor??16777215:i.offColor??0:i.rgb?.[p]??i.pixels?.[p]??0;a.data[p*4]=q>>>16&255,a.data[p*4+1]=q>>>8&255,a.data[p*4+2]=q&255,a.data[p*4+3]=255}u.putImageData(a,0,0)}function w(i,b){let E=document.createElement("div");E.className="signal";let R=document.createElement("span");R.className="signal-name",R.append(i.name+" ");let v=document.createElement("small");return v.textContent=i.width===1?"bool":`u${i.width}`,R.append(v),E.append(R,b),E}function B(i){let b=O("simulation-inputs-controls"),E=i.map((v)=>`${v.name}:${v.width}:${v.value}:${v.known}`).join("|");if(b.dataset.signature===E)return;b.dataset.signature=E,b.replaceChildren();let R=(v)=>{let u=[...b.querySelectorAll("[data-signal]")].map((a)=>{let m=a instanceof HTMLInputElement?a.value:a.getAttribute("aria-checked")==="true"?1:0;return`${a.dataset.signal}:${a.dataset.width}=${m}`});g("simulation-inputs").value=u.join(", ");try{let a=Ft(u.join(", "));if(v instanceof HTMLInputElement)v.setCustomValidity("");if(n!=="ready")t.setInputs(a)}catch(a){if(v instanceof HTMLInputElement)v.setCustomValidity(String(a)),v.reportValidity()}};for(let v of i){let u;if(v.width===1){let a=document.createElement("button");a.type="button",a.setAttribute("role","switch"),a.setAttribute("aria-checked",String(v.value!=="0")),a.setAttribute("aria-label",v.name),a.textContent=v.value!=="0"?"1":"0",a.addEventListener("click",()=>{let m=a.getAttribute("aria-checked")!=="true";a.setAttribute("aria-checked",String(m)),a.textContent=m?"1":"0",R(a)}),u=a}else{let a=document.createElement("input");a.type="text",a.value=v.value,a.inputMode="numeric",a.title=`u${v.width}`,a.setAttribute("aria-label",v.name),a.addEventListener("change",()=>R(a)),u=a}u.className="signal-value",u.dataset.signal=v.name,u.dataset.width=String(v.width),b.append(w(v,u))}if(!i.length)b.append(Y("No inputs"))}function Y(i){let b=document.createElement("p");return b.className="signal-empty",b.textContent=i,b}function ue(i){let b=O("simulation-outputs"),E=i.slice(0,100).map((R)=>{let v=document.createElement("span");return v.className="signal-value signal-output",v.textContent=Pn(R),w(R,v)});if(i.length>100)E.push(w({name:`… ${i.length-100} more`,width:0,value:"",known:!1},document.createElement("span")));b.replaceChildren(...E.length?E:[Y("No outputs")])}function ie(i){if(i.totalCycles===void 0||!i.outputs&&!i.inputs)return;let b=new Map;for(let R of[...i.inputs??[],...i.outputs??[]])b.set(R.name,R);let E=r.at(-1);if(E&&E.cycle===i.totalCycles){E.values=b;return}if(E&&i.totalCycles<E.cycle)r=[];if(r.push({cycle:i.totalCycles,values:b}),r.length>$n)r.shift()}function ce(){let i=O("simulation-trace");if(!r.length){i.replaceChildren(Y("Run or step the simulation to record signals.")),O("trace-range").textContent="";return}let b=r.at(-1),E=[...b.values.keys()].filter((p)=>p!==o).slice(0,Rn-(o?1:0)),R=Math.max(0,r.length-pt),v=r.slice(R),u=[],a=(p,h)=>{let S=document.createElement("div");S.className="trace-row";let k=document.createElement("span");k.className="trace-name",k.textContent=p,k.title=p;let L=document.createElement("div");return L.className="trace-lane",L.append(...h),S.append(k,L),S},m=(p,h,S)=>{let k=document.createElement("div");if(k.className="trace-cell",k.dataset.kind=p,h)k.dataset.future="";if(S)k.dataset.edge="";return k};if(o){let p=[];for(let h=0;h<pt;h++){let S=m("clock",h>=v.length,h===0);S.append(document.createElement("span"),document.createElement("span")),p.push(S)}u.push(a(o,p))}for(let p of E){let h=[],S;for(let k=0;k<pt;k++){let L=v[Math.min(k,v.length-1)].values.get(p),q=k>=v.length;if(!L){h.push(m("bus",q,!1));continue}let N=L.width===1&&L.known,V=`${L.known}:${L.value}`,se=!q&&(S===void 0||S!==V),ne=m(N?"bit":"bus",q,se);if(N&&L.value!=="0")ne.dataset.high="";if(!N&&se){let J=document.createElement("span");J.className="bus-value",J.textContent=_n(L),ne.append(J)}if(!q)S=V;h.push(ne)}u.push(a(p,h))}i.replaceChildren(...u),O("trace-range").textContent=v.length>1?`cycles ${v[0].cycle}–${b.cycle}`:`cycle ${b.cycle}`}function I(i){let b=O("simulation-output");if(i.type==="error"){n="error",b.hidden=!1,b.textContent=i.error??"Simulation failed.",O("simulation-state").textContent="Error",x(),e.setStatus("Simulation failed","error");return}if(n=i.type==="halted"?"halted":i.type==="stopped"?"ready":i.type==="stepping"?"stepping":i.type==="frame"||i.type==="resumed"?"running":"paused",i.frame)Q(i.frame);else if(i.metadata&&!i.metadata.display)Q(void 0);if(i.clock!==void 0)o=i.clock;if(i.inputs)i={...i,inputs:i.inputs.filter((h)=>h.name!==o)};if(i.outputs)ue(i.outputs);if(i.inputs)B(i.inputs);ie(i),ce();let E=i.messages??[];if(b.hidden=E.length===0,b.textContent=E.join(`
`),l("simulation-step-cycle").disabled=!i.clock||n==="halted",l("simulation-step-frame").hidden=!(i.frame&&i.clock),l("simulation-step-frame").disabled=n==="halted",i.metadata){let h={"simulation-top":i.metadata.top,"simulation-clock":i.clock,"simulation-cycles-per-frame":i.playback?.cyclesPerFrame,"simulation-clock-hz":i.playback?.clockHz??"maximum","simulation-refresh-fps":i.playback?.refreshFps};for(let[S,k]of Object.entries(h))g(S).placeholder=String(k??"automatic");g("simulation-cycles-per-frame").disabled=!i.clock||Boolean(i.metadata.display?.stream),g("simulation-clock-hz").disabled=!i.clock,g("simulation-refresh-fps").disabled=!i.clock}let R=i.totalCycles??0,v=i.cyclesPerSecond===void 0||n!=="running"&&n!=="stepping"?"":` · ${Dn(i.cyclesPerSecond)}`;O("simulation-cycle").textContent=`cycle ${R.toLocaleString()}${v}`;let u=i.simulatedSeconds===void 0?"":` · ${i.simulatedSeconds.toFixed(3)} simulated s`,a=i.status?.failed??!1,m=a?"Failed":n[0].toUpperCase()+n.slice(1),p=i.status?.exit_code===void 0?"":` · exit ${i.status.exit_code}`;O("simulation-state").textContent=`${m}${p}${u}`,x(),e.setStatus(a?`Simulation failed${i.status?.first_failure?`: ${i.status.first_failure.message}`:""}`:n==="running"||n==="stepping"?"Simulating…":`Simulation ${n}`,a?"error":void 0)}function U(i="run"){let b=(u)=>{let a=Number(g(u).value);return Number.isFinite(a)&&a>0?a:void 0},E={clockHz:b("simulation-clock-hz"),refreshFps:b("simulation-refresh-fps"),cyclesPerFrame:b("simulation-cycles-per-frame")};if(n!=="ready"&&n!=="error"){if(i==="run")if(n==="running"||n==="stepping")t.pause();else t.resume(E);else t.command(i,E);return}let R=g("simulation-top").value.trim(),v=g("simulation-clock").value.trim();r=[],ce(),O("simulation-state").textContent="Compiling simulation…",n="starting",x();try{let{source:u,path:a,files:m}=e.request();t.start({source:u,path:a,stage:"write_low_firrtl",files:m,simulate:{action:i,...R?{top:R}:{},...v?{clock:v}:{},...Object.fromEntries(Object.entries(E).filter(([,p])=>p!==void 0)),inputs:Ft(g("simulation-inputs").value)}},I)}catch(u){I({id:0,type:"error",error:String(u)})}}function pe(){t.stop(),n="ready",O("simulation-state").textContent="Ready",O("simulation-cycle").textContent="cycle 0",x()}return l("simulation-run").onclick=()=>U("run"),l("simulation-reset").onclick=()=>{r=[],ce(),U("reset")},l("simulation-step-cycle").onclick=()=>U("step_cycle"),l("simulation-step-frame").onclick=()=>U("step_frame"),O("simulation-zoom").onchange=()=>{if(d)Q(d)},l("simulation-stop").onclick=()=>{pe(),e.setStatus("Simulation stopped")},l("simulation-settings").onclick=()=>{let i=O("simulation-options");i.hidden=!i.hidden,l("simulation-settings").setAttribute("aria-expanded",String(!i.hidden))},ce(),ue([]),B([]),x(),{enable(){for(let i of["simulation-run","simulation-step-cycle",...T])O(i).disabled=!1;x()},stop:pe,clear(){pe(),r=[],o=void 0,Q(void 0),ce(),ue([]),O("simulation-inputs-controls").dataset.signature="",B([]),O("simulation-output").hidden=!0;for(let i of["simulation-top","simulation-clock","simulation-inputs"])g(i).value=""},clearFrame(){Q(void 0)},get active(){return n!=="ready"&&n!=="error"},run:U}}var Bt=(e)=>e.replace(/[&<>"']/g,(t)=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[t]),An=/^(module|declare|test|let|const|type|package|import|for|in|if|else|match|true|false)$/,Hn=/^(and|or|not|xor|nand|nor|xnor|shl|shr|andr|orr|xorr)$/,In=/^(u\d+|s\d+|uint|sint|bool|clock|Nat|Type)$/,qn=/^(circuit|module|extmodule|input|output|wire|node|reg|regreset|mem|inst|of|when|else|connect|attribute|parameter|cell|end|process|sync|update|assign|public|version|intmodule|invalidate|skip|printf|stop|assert|cover|assume)$/,Nn=/^(UInt|SInt|Clock|Reset|AsyncReset|Analog)$/,On=/^(mux|add|sub|mul|div|rem|and|or|xor|not|bits|cat|pad|eq|neq|lt|leq|gt|geq|shl|shr|dshl|dshr|head|tail|andr|orr|xorr|neg|cvt|asUInt|asSInt|asClock|validif)$/;function Fn(e,t){if(t==="yodl"){if(e.startsWith("//"))return"comment";if(e.startsWith('"'))return"string";if(An.test(e)||Hn.test(e))return"keyword";if(In.test(e))return"type";if(/^\w+!$/.test(e))return"function";if(/^\d/.test(e))return"number";if(/^[A-Z]/.test(e))return"ident";if(/^[=<>+\-*/%:?.&|^~!]+$/.test(e))return"punct";return""}if(e.startsWith(t==="firrtl"?";":"#"))return"comment";if(e.startsWith('"'))return"string";if(qn.test(e))return"keyword";if(Nn.test(e))return"type";if(On.test(e))return"function";if(/^-?\d/.test(e))return"number";if(/^[<>=:]+$/.test(e))return"punct";return""}function jn(e,t="yodl"){if(t==="plaintext")return[{text:e,kind:"",start:0,end:e.length}];let r=new RegExp(`(${t==="rtlil"?"#[^\\n]*":t==="firrtl"?";[^\\n]*":"\\/\\/[^\\n]*"}|"(?:[^"\\\\\\n]|\\\\.)*"|\\b\\w+!|${t==="yodl"?"\\b\\d+":"-?\\b\\d+"}(?:'[bhod]?[\\da-fA-F_]+)?\\b|\\b[a-zA-Z_]\\w*\\b|[=<>+\\-*/%:?.&|^~!]+)`,"g"),d=0;return e.split(r).filter(Boolean).map((s)=>{let l=d;return d+=s.length,{text:s,kind:Fn(s,t),start:l,end:d}})}function Bn(e,t="yodl"){return jn(e,t).map(({text:n,kind:o})=>o?`<span class="token-${o}">${Bt(n)}</span>`:Bt(n)).join("")}function Kt(e,t="yodl"){return e.replace(/\n$/,"").split(`
`).map((o,r)=>`<div class="code-line"><span class="ln">${r+1}</span><span class="lt">${Bn(o,t)||" "}</span></div>`).join("")}var de=(e)=>document.getElementById(e),Je=(e)=>String(e).padStart(2,"0"),Ge=(e,t)=>`./playground.html?mode=docs&chapter=${e}${t?`#${t}`:""}`;function A(e,t,n){let o=document.createElement(e);if(t)o.className=t;if(n!==void 0)o.textContent=n;return o}function Wt(e){let t=new _e,n,o,r,d=de("docs-main"),s=de("docs-content"),l=A("div","code-tooltip");l.id="docs-code-tooltip",l.setAttribute("role","tooltip"),l.hidden=!0,document.body.append(l);let g,T,x=()=>{clearTimeout(T),l.hidden=!0,g?.removeAttribute("aria-describedby"),g=void 0},Q=()=>{if(g===document.activeElement)return;clearTimeout(T),T=setTimeout(x,100)},w=(u)=>{x(),g=u,l.textContent=u.dataset.codeInfo,l.hidden=!1,u.setAttribute("aria-describedby",l.id);let a=u.getBoundingClientRect(),m=l.offsetWidth,p=l.offsetHeight;l.style.left=`${Math.max(8,Math.min(a.left,innerWidth-m-8))}px`,l.style.top=`${Math.max(8,a.top>p+12?a.top-p-8:Math.min(a.bottom+8,innerHeight-p-8))}px`},B=(u)=>u.target.closest("[data-code-info]");s.addEventListener("pointerover",(u)=>{let a=B(u);if(a&&a!==g)w(a)}),s.addEventListener("pointerout",(u)=>{if(g&&!g.contains(u.relatedTarget))Q()}),l.addEventListener("pointerenter",()=>clearTimeout(T)),l.addEventListener("pointerleave",Q),s.addEventListener("focusin",(u)=>{let a=B(u);if(a)w(a)}),s.addEventListener("focusout",x);let Y=(u)=>{if(u.key==="Escape")x()};document.addEventListener("keydown",Y),d.addEventListener("scroll",x,{passive:!0});function ue(){return n??=fetch("./book/chapters.json").then((u)=>{if(!u.ok)throw Error("The language guide could not be loaded.");return u.json()}).catch((u)=>{throw n=void 0,u})}function ie(u,a,m){let p=A("a");return p.href=Ge(u,a),p.append(...typeof m==="string"?[m]:m),p.addEventListener("click",(h)=>{if(h.metaKey||h.ctrlKey||h.shiftKey||h.button!==0)return;h.preventDefault(),e.navigate(u,a)}),p}function ce(u,a){de("docs-chapters").replaceChildren(...u.chapters.map((m,p)=>{let h=ie(m.slug,void 0,[A("span",void 0,Je(p+1)),m.title]);if(m===a)h.setAttribute("aria-current","page");return h})),de("docs-version").textContent=`Yodl ${u.version} · ${u.revision}`,de("docs-toc").replaceChildren(...a.headings.filter((m)=>m.level>1&&m.level<4).map((m)=>{let p=ie(a.slug,m.id,m.title);return p.className=`toc-level-${m.level}`,p})),I()}function I(){r?.disconnect();let u=Array.from(de("docs-toc").querySelectorAll("a"));if(!u.length||typeof IntersectionObserver>"u")return;r=new IntersectionObserver((a)=>{for(let m of a)if(m.isIntersecting)for(let p of u)if(p.href.endsWith(`#${m.target.id}`))p.setAttribute("aria-current","location");else p.removeAttribute("aria-current")},{root:d,rootMargin:"0px 0px -70% 0px"});for(let a of Array.from(s.querySelectorAll("h2[id], h3[id]")))r.observe(a)}function U(u,a){x();let m=u.chapters.indexOf(a),p=A("p","docs-meta",`Chapter ${Je(m+1)} of ${Je(u.chapters.length)}`),h=A("article");h.innerHTML=a.html;let S=[p,h],k=Ue[a.slug]??[];if(k.length){let J=A("section","practice");J.append(A("p","section-label","Practice in the tour"));for(let Ke of k){let We=A("button");We.type="button",We.append(A("strong",void 0,Ke.title),A("span",void 0,"→")),We.addEventListener("click",()=>e.openLesson(Ke.id)),J.append(We)}S.push(J)}let L=u.chapters[m-1],q=u.chapters[m+1],N=A("nav","page-navigation");N.setAttribute("aria-label","Previous and next chapters");let V=(J,Ke)=>J?ie(J.slug,void 0,[A("small",void 0,Ke),J.title]):A("span");N.append(V(L,"← Previous"),V(q,"Next →"));let se=A("footer","article-footer"),ne=A("a",void 0,"Edit this page ↗");ne.href=`https://github.com/nathsou/yodl/edit/main/book/src/${a.slug}.md`,se.append(ne,A("span",void 0,"Examples compile locally in your browser.")),S.push(N,se),s.replaceChildren(...S),s.className="docs-content",pe(u,a);for(let J of a.examples)i(a,J)}function pe(u,a){for(let m of Array.from(s.querySelectorAll("article a[href]"))){let p=m.getAttribute("href"),h=/^#(.+)$/.exec(p),S=/^\.?\/?([\w-]+)\.html(?:#(.+))?$/.exec(p),k=S&&u.chapters.find((N)=>N.slug===S[1]);if(!h&&!k)continue;let L=h?a.slug:k.slug,q=h?h[1]:S[2];m.href=Ge(L,q),m.addEventListener("click",(N)=>{if(N.metaKey||N.ctrlKey||N.shiftKey||N.button!==0)return;N.preventDefault(),e.navigate(L,q)})}}function i(u,a){let m=s.querySelector(`#${CSS.escape(a.id)}`);if(!m||!a.live)return;let p=m.querySelector('[data-action="compile"]');m.querySelector('[data-action="playground"]').onclick=()=>e.openExample(u,a,a.source,E(m)??a.stage);let h=async(S)=>{let k=R(m,a,S,h),L=k.querySelector(".example-status");L.dataset.state="",L.firstChild.textContent="● Compiling · ",p.disabled=!0;let q=await t.compile(a.id,{source:a.source,path:a.path,files:a.files,stage:S});if(p.disabled=!1,!q||!m.isConnected)return;let N=k.querySelector(".example-output-body");if(q.error!==void 0){let V=a.expect==="error";L.dataset.state=V?"expected":"error",L.firstChild.textContent=V?"● Expected compiler error · ":"● Compilation failed · ";let se=A("pre","diagnostic",q.error);se.tabIndex=0,N.replaceChildren(se)}else{L.dataset.state="success",L.firstChild.textContent="● Compiled · ",L.title=`${Math.round(q.duration)} ms · Yodl ${b}`;let V=A("div","code-lines");V.tabIndex=0,V.innerHTML=Kt(q.output??"",K[S].language),N.replaceChildren(V)}};p.onclick=()=>void h(E(m)??a.stage)}let b="",E=(u)=>u.querySelector(".example-output select")?.value;function R(u,a,m,p){let h=u.querySelector(".example-output");if(h)return h.hidden=!1,h;h=A("div","example-output");let S=A("div","example-output-header"),k=A("span","example-status");k.append(document.createTextNode("● Compiled · "));let L=A("select");L.setAttribute("aria-label","Compiler output stage");for(let[V,se]of Object.entries(K)){if(V==="test"&&a.stage!=="test")continue;let ne=new Option(se.label,V);if(ne.disabled=a.unsupported.includes(V),ne.disabled)ne.text+=" (unavailable)";L.add(ne)}L.value=m,L.title=K[m].description,L.onchange=()=>{L.title=K[L.value].description,p(L.value)};let q=A("span","stage-select");q.append(L),k.append(q);let N=A("button",void 0,"Hide");return N.type="button",N.onclick=()=>{h.hidden=!0},S.append(k,N),h.append(S,A("div","example-output-body")),u.append(h),h}function v(u){let a=u?s.querySelector(`#${CSS.escape(u)}`):null;if(a){if(a.scrollIntoView(),a.hasAttribute("data-code-info"))a.focus({preventScroll:!0})}else d.scrollTop=0}return{load:ue,async show(u,a){let m=de("docs-loading"),p;try{m.hidden=!1,m.textContent="Loading the language guide…",p=await ue()}catch(k){m.textContent=`${k.message} Check your connection and reload the page.`;return}m.hidden=!0,b=p.version;let h=p.chapters.find((k)=>k.slug===u)??p.chapters[0],S=h!==o;if(S){if(o)for(let k of o.examples)t.cancel(k.id);if(o=h,ce(p,h),U(p,h),document.title=`${h.title} · Yodl`,de("docs-current").textContent=`${Je(p.chapters.indexOf(h)+1)} · ${h.title}`,matchMedia("(max-width: 820px)").matches)de("chapter-menu").open=!1}if(S||a)v(a);return h},get current(){return o},dispose(){x(),document.removeEventListener("keydown",Y),l.remove(),t.dispose()}}}var fe=(e)=>document.getElementById(e);function Ut(e){let t=fe("search-dialog"),n=fe("search-input"),o=fe("search-results"),r=fe("search-status"),d,s,l=e.lessons.map((w,B)=>({title:w.title,where:`Tour · Lesson ${String(B+1).padStart(2,"0")}`,excerpt:w.intro,text:[w.title,w.topic,w.intro,...w.concepts,w.observe,w.challenge].join(" "),go:()=>e.openLesson(w.id)}));async function g(){if(d)return!0;try{return await(s??=fetch("./book/search.json").then((w)=>{if(!w.ok)throw Error("Search unavailable");return w.json()}).then((w)=>{d=w}).finally(()=>{s=void 0})),!0}catch{return!1}}async function T(){let w=n.value.toLowerCase().trim();r.textContent=w?"Searching…":"Type to search the guide and the tour.";let B=await g();if(n.value.toLowerCase().trim()!==w)return;if(o.replaceChildren(),!w)return;let Y=w.split(/\s+/),ue=(d??[]).map((I)=>({title:I.title,where:`Docs · ${I.chapter}`,excerpt:I.text,text:`${I.title} ${I.text}`,go:()=>e.openDoc(I.slug,I.id)})),ie=[...l,...ue].filter((I)=>Y.every((U)=>I.text.toLowerCase().includes(U))).sort((I,U)=>Number(U.title.toLowerCase().includes(w))-Number(I.title.toLowerCase().includes(w))).slice(0,30),ce=B?"":" The guide index could not load; showing lessons only.";r.textContent=(ie.length?`${ie.length} result${ie.length===1?"":"s"}`:"No results. Try a concept, operator, or built-in name.")+ce;for(let I of ie){let U=document.createElement("a");U.href="#",U.addEventListener("click",(R)=>{R.preventDefault(),t.close(),I.go()});let pe=document.createElement("strong");pe.textContent=I.title;let i=document.createElement("small");i.textContent=I.where;let b=document.createElement("span"),E=Math.max(0,I.excerpt.toLowerCase().indexOf(Y[0])-50);b.textContent=`${E?"…":""}${I.excerpt.slice(E,E+160)}${I.excerpt.length>E+160?"…":""}`,U.append(pe,i,b),o.append(U)}}let x=()=>{if(!t.open)t.showModal();n.focus(),n.select(),T()};fe("search-open").addEventListener("click",x),fe("search-close").addEventListener("click",()=>t.close()),n.addEventListener("input",()=>void T()),t.addEventListener("click",(w)=>{if(w.target===t)t.close()}),t.addEventListener("keydown",(w)=>{let B=Array.from(o.querySelectorAll("a")),Y=B.indexOf(document.activeElement);if(w.key==="ArrowDown")w.preventDefault(),B[Math.min(B.length-1,Y+1)]?.focus();if(w.key==="ArrowUp")if(w.preventDefault(),Y<=0)n.focus();else B[Y-1].focus();if(w.key==="Enter"&&document.activeElement===n)B[0]?.click()});let Q=/Mac|iPhone|iPad/.test(navigator.platform);return fe("search-shortcut").textContent=Q?"⌘K":"Ctrl K",document.addEventListener("keydown",(w)=>{let B=w.target;if((w.metaKey||w.ctrlKey)&&w.key.toLowerCase()==="k"){w.preventDefault(),x();return}if(w.key==="/"&&!w.metaKey&&!w.ctrlKey&&!B.closest('input, textarea, select, [contenteditable="true"], .monaco-editor')&&!document.querySelector("dialog[open]"))w.preventDefault(),x()}),{open:x}}class mt{id=0;pending=new Map;worker;onDiagnostics=()=>{};onError=()=>{};constructor(e){this.worker=e??new Worker(new URL("./lsp-worker-ejtef7wa.js",import.meta.url),{type:"module"}),this.worker.onmessage=(t)=>{let n=t.data;if(n.id!==void 0){let o=this.pending.get(n.id);if(!o)return;if(this.pending.delete(n.id),clearTimeout(o.timer),n.error)o.reject(Error(n.error.message));else o.resolve(n.result)}else if(n.method==="textDocument/publishDiagnostics")this.onDiagnostics(n.params.uri,n.params.diagnostics,n.params.version);else if(n.method==="window/logMessage"&&n.params.type===1)this.onError(n.params.message)},this.worker.onerror=(t)=>{this.fail(Error(t.message||"Language worker failed")),this.onError(t.message||"Language worker failed")}}request(e,t={},n){let o=++this.id,r;return new Promise((s,l)=>{if(n?.isCancellationRequested){s(null);return}let g=setTimeout(()=>{this.pending.delete(o),l(Error(`Language service timed out: ${e}`))},30000);this.pending.set(o,{resolve:s,reject:l,timer:g}),r=n?.onCancellationRequested(()=>{let T=this.pending.get(o);if(T)this.pending.delete(o),clearTimeout(T.timer),T.resolve(null),this.notify("$/cancelRequest",{id:o})}),this.worker.postMessage({jsonrpc:"2.0",id:o,method:e,params:t})}).finally(()=>r?.dispose())}notify(e,t){this.worker.postMessage({jsonrpc:"2.0",method:e,params:t})}fail(e){for(let t of this.pending.values())clearTimeout(t.timer),t.reject(e);this.pending.clear()}dispose(){this.fail(Error("Language client disposed")),this.worker.terminate()}}var De=(e)=>`yodl:///workspace/${e.split("/").map(encodeURIComponent).join("/")}`,Ee=(e)=>e.startsWith("yodl:///workspace/")?e.slice(18).split("/").map(decodeURIComponent).join("/"):e,ee=(e)=>({line:e.lineNumber-1,character:e.column-1}),Vt=(e)=>({start:ee({lineNumber:e.startLineNumber,column:e.startColumn}),end:ee({lineNumber:e.endLineNumber,column:e.endColumn})}),te=(e)=>({startLineNumber:e.start.line+1,startColumn:e.start.character+1,endLineNumber:e.end.line+1,endColumn:e.end.character+1});class ht{monaco;open;problems;client;models=new Map;uris=new Map;listeners=new Map;registrations=[];ready;epoch=0;errors=new Map;model(e){return this.models.get(e.startsWith("yodl-builtin:")?e:De(e))}constructor(e,t,n,o,r=new mt){this.monaco=e;this.open=t;this.problems=n;this.client=r,this.client.onError=o,this.ready=r.request("initialize",{capabilities:{general:{positionEncodings:["utf-16"]}}}).then((d)=>(r.notify("initialized",{}),d)),r.onDiagnostics=(d,s,l)=>{let g=this.models.get(d);if(l!==void 0&&g&&l!==g.getVersionId())return;if(this.errors.set(d,s),g)this.markers(g,s);this.problems([...this.errors].flatMap(([T,x])=>x.map((Q)=>({...Q,uri:Ee(T)}))))},this.register(),this.registrations.push(e.editor.registerEditorOpener({openCodeEditor:(d,s,l)=>{let g=e.editor.getModel(s),T=this.uris.get(g);if(!T)return!1;return this.open(Ee(T),l),!0}}))}markers(e,t){this.monaco.editor.setModelMarkers(e,"yodl",t.map((n)=>({...te(n.range),message:n.message,code:n.code,source:"yodl",severity:n.severity===2?this.monaco.MarkerSeverity.Warning:this.monaco.MarkerSeverity.Error,relatedInformation:n.relatedInformation?.map((o)=>({resource:this.monaco.Uri.parse(o.location.uri),...te(o.location.range),message:o.message}))})))}attach(e,t){let n=t.startsWith("yodl-builtin:")?t:De(t);if(this.uris.get(e)===n)return;if(this.uris.has(e))this.detach(e);this.uris.set(e,n),this.models.set(n,e),this.ready.then(()=>{if(this.uris.get(e)===n)this.client.notify("textDocument/didOpen",{textDocument:{uri:n,languageId:"yodl",version:e.getVersionId(),text:e.getValue()}})}),this.listeners.set(e,[e.onDidChangeContent(()=>{this.ready.then(()=>{if(this.uris.get(e)===n)this.client.notify("textDocument/didChange",{textDocument:{uri:n,version:e.getVersionId()},contentChanges:[{text:e.getValue()}]})})}),e.onWillDispose(()=>this.detach(e))]),this.markers(e,this.errors.get(n)??[])}detach(e){let t=this.uris.get(e);for(let n of this.listeners.get(e)??[])n.dispose();if(this.listeners.delete(e),this.uris.delete(e),t)this.models.delete(t),this.errors.delete(t),this.ready.then(()=>this.client.notify("textDocument/didClose",{textDocument:{uri:t}}));this.monaco.editor.setModelMarkers(e,"yodl",[])}async workspace(e,t,n){let o=++this.epoch;this.attach(t,n),await this.ready;let r=Object.fromEntries(Object.entries(e).map(([s,l])=>[De(s),l]));await this.client.request("yodl/setFiles",{files:r});let d=await this.client.request("yodl/dependencies",{uri:De(n)});if(o!==this.epoch)return;return Object.fromEntries(Object.entries(d).map(([s,l])=>[Ee(s),l]))}async query(e,t,n,o){let r=this.uris.get(e),d=e.getVersionId();if(!r)return null;await this.ready;let s=await this.client.request(`textDocument/${t}`,{textDocument:{uri:r},...n},o);return this.uris.get(e)===r&&e.getVersionId()===d?s:null}async ensure(e){if(this.models.has(e))return this.models.get(e);let t=await this.client.request("yodl/source",{uri:e});if(t===null)return;if(this.models.has(e))return this.models.get(e);let n=this.monaco.editor.createModel(t,"yodl",this.monaco.Uri.parse(e));return this.attach(n,Ee(e)),this.open(Ee(e),void 0),n}async locations(e){if(!e)return[];return(await Promise.all((Array.isArray(e)?e:[e]).map(async(t)=>{let n=await this.ensure(t.uri);return n?{uri:n.uri,range:te(t.range)}:null}))).filter(Boolean)}async edits(e){if(!e?.changes)return;let t=[];for(let[n,o]of Object.entries(e.changes)){let r=await this.ensure(n);if(!r)return;for(let d of o)t.push({resource:r.uri,versionId:r.getVersionId(),textEdit:{range:te(d.range),text:d.newText}})}return{edits:t}}register(){let e=this.monaco.languages,t=(o,r)=>this.registrations.push(e[o]("yodl",r));t("registerHoverProvider",{provideHover:async(o,r,d)=>{let s=await this.query(o,"hover",{position:ee(r)},d);return s?{range:s.range&&te(s.range),contents:[{value:s.contents.value}]}:null}});for(let[o,r]of[["Definition","definition"],["Declaration","declaration"],["TypeDefinition","typeDefinition"]])t(`register${o}Provider`,{[`provide${o}`]:async(d,s,l)=>this.locations(await this.query(d,r,{position:ee(s)},l))});t("registerReferenceProvider",{provideReferences:async(o,r,d,s)=>this.locations(await this.query(o,"references",{position:ee(r),context:d},s))}),t("registerDocumentHighlightProvider",{provideDocumentHighlights:async(o,r,d)=>(await this.query(o,"documentHighlight",{position:ee(r)},d)??[]).map((s)=>({...s,range:te(s.range)}))});let n=(o)=>({...o,kind:o.kind-1,range:te(o.range),selectionRange:te(o.selectionRange),children:o.children?.map(n)});t("registerDocumentSymbolProvider",{provideDocumentSymbols:async(o,r)=>(await this.query(o,"documentSymbol",{},r)??[]).map(n)}),t("registerCompletionItemProvider",{triggerCharacters:[".",":","["],provideCompletionItems:async(o,r,d,s)=>{let l=await this.query(o,"completion",{position:ee(r)},s),g=[0,18,0,1,2,3,4,7,5,8,9,12,13,15,17,28,19,20,21,23,16,14,6,10,11,24];return{incomplete:l?.isIncomplete??!1,suggestions:(l?.items??[]).map((T)=>({label:T.label,detail:T.detail,kind:g[T.kind??1],insertText:T.textEdit?.newText??T.label,range:T.textEdit?te(T.textEdit.range):void 0}))}}}),t("registerSignatureHelpProvider",{signatureHelpTriggerCharacters:["(","[",",",":"],signatureHelpRetriggerCharacters:[","],provideSignatureHelp:async(o,r,d)=>{let s=await this.query(o,"signatureHelp",{position:ee(r)},d);return s?{value:s,dispose(){}}:null}}),t("registerRenameProvider",{resolveRenameLocation:async(o,r,d)=>{try{let s=await this.query(o,"prepareRename",{position:ee(r)},d);return s?{range:te(s.range),text:s.placeholder}:{rejectReason:"No renameable symbol here"}}catch(s){return{rejectReason:s.message}}},provideRenameEdits:async(o,r,d,s)=>{try{return await this.edits(await this.query(o,"rename",{position:ee(r),newName:d},s))}catch(l){return{edits:[],rejectReason:l.message}}}}),t("registerCodeActionProvider",{providedCodeActionKinds:["quickfix"],provideCodeActions:async(o,r,d,s)=>{let l=await this.query(o,"codeAction",{range:Vt(r),context:{diagnostics:[],only:d.only?[d.only]:void 0}},s);return{actions:await Promise.all((l??[]).map(async(g)=>({title:g.title,kind:g.kind,isPreferred:g.isPreferred,edit:await this.edits(g.edit)}))),dispose(){}}}}),t("registerFoldingRangeProvider",{provideFoldingRanges:async(o,r,d)=>(await this.query(o,"foldingRange",{},d)??[]).map((s)=>({start:s.startLine+1,end:s.endLine+1}))}),t("registerSelectionRangeProvider",{provideSelectionRanges:async(o,r,d)=>(await this.query(o,"selectionRange",{positions:r.map(ee)},d)??[]).map((l)=>{let g=[];while(l)g.push({range:te(l.range)}),l=l.parent;return g})}),t("registerDocumentSemanticTokensProvider",{getLegend:()=>({tokenTypes:["namespace","type","class","parameter","variable","property","function","keyword","number","string","operator"],tokenModifiers:["declaration","readonly"]}),provideDocumentSemanticTokens:async(o,r,d)=>{let s=await this.query(o,"semanticTokens/full",{},d);return s?{data:Uint32Array.from(s.data)}:null},releaseDocumentSemanticTokens(){}})}dispose(){for(let e of[...this.uris.keys()])this.detach(e);for(let e of this.registrations)e.dispose();this.client.dispose()}}var c=(e)=>document.getElementById(e),y=(e)=>c(e),Qt="yodl-playground-v2:",xt=!0;function xe(e){try{return localStorage.getItem(Qt+e)}catch{return xt=!1,null}}function be(e,t){try{localStorage.setItem(Qt+e,t)}catch{xt=!1}}function le(e){let t=c("notice");t.textContent=e;let n=document.createElement("button");n.textContent="Dismiss",n.addEventListener("click",()=>{t.hidden=!0}),t.append(n),t.hidden=!1}function he(e,t="idle"){c("compile-status").textContent=e,c("compile-status").dataset.state=t}var gt=/Mac|iPhone|iPad/.test(navigator.platform);At(document.querySelector(".site-header"),()=>Ye());Ht(document.querySelector(".accent-picker"),()=>Ye());var Xt=(e)=>e==="tour"?"tour":"playground",yt=(e)=>`tour/${e.file}`,re=(e)=>e.split("/").at(-1),j="tour",He,bt,C={...ct};try{let e=JSON.parse(xe("selection")??"null");if(Pe(e))C=e}catch{}var _,Kn=()=>_?`shared:${_.code}`:"",D=()=>_?.entryPath??C.path,f,zt,Le=!1,Z,Ie,z="",qe="",W=new Map,Qe=new Map,ae=()=>Z.getValue();function Te(e){let t=e===D()?Z:W.get(e);if(!t)return;if(z)Qe.set(z,f.input.saveViewState());z=e,f.input.setModel(t),f.input.updateOptions({readOnly:e!==D(),ariaLabel:`${e}${e===D()?", main source":", imported, read only"}`});let n=Qe.get(e);if(n)f.input.restoreViewState(n);kt(),f.input.layout()}function kt(){let e=z!==D(),t=W.size>0;c("source-files").hidden=!t,c("editors").dataset.imports=String(t),c("input-filename").textContent=re(z||D()),c("input-filename").title=z,c("source-kind").textContent=e?"Imported · read only":"",c("source-kind").hidden=!e,c("draft-badge").hidden=e||!Z||ae()===Fe(),y("reset-button").disabled=e,c("source-files").replaceChildren(...[D(),...W.keys()].map((n)=>{let o=document.createElement("button");return o.textContent=re(n),o.title=n===D()?`${n} · compile and simulation target`:`${n} · imported, read only`,o.setAttribute("aria-pressed",String(n===z)),o.onclick=()=>Te(n),o}))}function en(e){let t=Object.entries(e).filter(([o])=>o!==D()&&o.endsWith(".yodl")),n=new Set(t.map(([o])=>o));if(z!==D()&&!n.has(z))Te(D());for(let[o,r]of W)if(!n.has(o))r.dispose(),W.delete(o),Qe.delete(o);for(let[o,r]of t){let d=W.get(o);if(!d){let s=P.editor.createModel(r,"yodl");W.set(o,s),Ie?.attach(s,o),s.onDidChangeContent(()=>{if(!Le)it()})}else if(d.getValue()!==r)d.setValue(r)}kt()}function Wn(){z="",Qe.clear(),f.input.setModel(Z);for(let e of W.values())e.dispose();W.clear(),Te(D())}var et=0,oe="",tt=-1,tn=new _e,wt=0,Yt,nt=()=>({...Ce,..._?.files,...Object.fromEntries([...W].filter(([e])=>!e.startsWith("yodl-builtin:")).map(([e,t])=>[e,t.getValue()]))});async function nn(){let e=++wt;try{let t=await Ie?.workspace(nt(),Z,D());if(e===wt&&t)en(t)}catch(t){le(`Language service: ${t.message}`)}}function Un(){++wt,clearTimeout(Yt),Yt=setTimeout(nn,150)}var on=(e)=>/\btest\s+(?:"|for\b)/.test(e),we=jt({request:()=>({source:ae(),path:D(),files:nt()}),setStatus:he}),rn=0,vt=0,me=null,Vn=`// Start a new circuit here.
module Top(a: bool) -> (q: bool) {
    q = a
}
`,ot=(e)=>Ce[e]??Vn,Fe=()=>_?_.source:ot(C.path);function zn(e){let t=2166136261;for(let n=0;n<e.length;n++)t^=e.charCodeAt(n),t=Math.imul(t,16777619);return(t>>>0).toString(36)}var sn=(e)=>`draft:${e}:${zn(ot(e))}`,je=()=>Kn()||sn(C.path),Yn=12;function an(){try{let e=JSON.parse(xe("drafts")??"[]");return Array.isArray(e)?e.filter((t)=>typeof t?.key==="string"&&typeof t.label==="string"&&typeof t.updated==="number"):[]}catch{return[]}}function Jn(){if(C.mode!=="examples"&&!_)return;let e=je(),t=an(),n=t.findIndex((r)=>r.key===e);if(ae()===Fe()){if(n<0)return;t.splice(n,1)}else{if(n===0&&Date.now()-t[0].updated<30000)return;if(n>=0)t.splice(n,1);let r=_?`Shared · ${re(_.entryPath??_.path)}`:C.path===X?"scratch.yodl":re(C.path);t.unshift({key:e,path:C.path,label:r,updated:Date.now(),..._?{shared:!0}:{}})}be("drafts",JSON.stringify(t.slice(0,Yn))),cn()}function Gn(e){let t=Math.floor((Date.now()-e)/60000);if(t<1)return"Just now";if(t<60)return`${t} min ago`;let n=Math.floor(t/60);if(n<24)return`${n} h ago`;let o=Math.floor(n/24);return o===1?"Yesterday":o<14?`${o} days ago`:new Date(e).toLocaleDateString()}function Ne(){if(!Z)return;if(be(je(),ae()),!_)be("selection",JSON.stringify(C));c("save-status").textContent=xt?"Draft saved locally":"Draft not saved · storage unavailable",c("draft-badge").hidden=z!==D()||ae()===Fe(),Jn()}var ke=()=>H.findIndex((e)=>yt(e)===C.path),Zn=(e)=>Object.entries(Ue).find(([,t])=>t.some((n)=>n.id===e))?.[0],ln=new Map,Qn=(e)=>{let t=e.replace(/^\d+_/,"").replaceAll("_"," ");return t[0].toUpperCase()+t.slice(1)},Oe=(e)=>String(e).padStart(2,"0");function rt(){let e=ke(),t=H[e];if(!t)return;let n=document.createElement("span");n.className="lesson-prefix",n.textContent="Tour · ",c("lesson-position").replaceChildren(n,`Lesson ${Oe(e+1)} of ${H.length}`),Et(),c("lesson-topic").textContent=t.topic,c("lesson-title").textContent=t.title,c("lesson-intro").textContent=t.intro,c("lesson-observe").textContent=t.observe,c("lesson-challenge").textContent=t.challenge,c("lesson-concepts").replaceChildren(...t.concepts.map((s,l)=>{let g=document.createElement("li"),T=document.createElement("span");T.className="n",T.textContent=Oe(l+1);let x=document.createElement("span");return x.textContent=s,g.append(T,x),g})),y("suggested-stage").textContent=`Open ${K[t.stage].label} →`;let o=Zn(t.id);if(c("lesson-reference").hidden=!o,o){let s=c("related-docs");s.textContent=ln.get(o)??Qn(o),s.href=Ge(o),s.onclick=(l)=>{l.preventDefault(),F({section:"docs",chapter:o})}}let r=H[e-1],d=H[e+1];y("previous-lesson").disabled=!r,c("previous-title").textContent=r?.title??"",y("next-lesson").disabled=!1,c("next-title").textContent=d?.title??"Explore the Playground";for(let[s,l]of Array.from(c("lesson-progress").children).entries())if(s===e)l.setAttribute("aria-current","step");else l.removeAttribute("aria-current");for(let[s,l]of Array.from(c("lesson-list").children).entries())if(s===e)l.setAttribute("aria-current","step");else l.removeAttribute("aria-current")}function Xn(){c("lesson-progress").style.setProperty("--lessons",String(H.length)),c("lesson-progress").replaceChildren(...H.map((e,t)=>{let n=document.createElement("button");return n.type="button",n.title=`${Oe(t+1)} · ${e.title}`,n.setAttribute("aria-label",`Lesson ${t+1}: ${e.title}`),n.onclick=()=>void F({section:"tour",lesson:e.id}),n})),c("lesson-list").replaceChildren(...H.map((e,t)=>{let n=document.createElement("button");return n.type="button",n.innerHTML='<span class="n"></span><span><strong></strong><small></small></span>',n.querySelector(".n").textContent=Oe(t+1),n.querySelector("strong").textContent=e.title,n.querySelector("small").textContent=e.topic,n.onclick=()=>{Be(!1),F({section:"tour",lesson:e.id})},n}))}function Be(e){if(c("lesson-list-scrim").hidden=!e,y("lesson-list-button").setAttribute("aria-expanded",String(e)),e)c("lesson-list").querySelector("[aria-current]")?.scrollIntoView({block:"nearest"})}function eo(e){let t=Ce[e]??"";return`${t.split(`
`).length} lines${t.includes("@simulation")?" · simulation":""}`}function St(){Et(),c("example-list").replaceChildren(...$e.map((e)=>{let t=document.createElement("button");t.type="button",t.className="entry";let n=!_&&C.path===e;if(n)t.setAttribute("aria-current","true");let o=document.createElement("span");o.className="entry-name",o.textContent=re(e).replace(/\.yodl$/,"");let r=document.createElement("span");return r.className="entry-note",r.textContent=n?re(e):eo(e),t.append(o,r),t.onclick=()=>{be("last:examples",e),ge(!1),F({section:"playground",path:e})},t})),cn()}function cn(){let e=an().filter((t)=>t.shared||(t.path===X||$e.includes(t.path))&&t.key===sn(t.path));c("drafts-empty").hidden=e.length>0,c("draft-list").replaceChildren(...e.map((t)=>{let n=document.createElement("button");if(n.type="button",n.className="entry draft",t.key===je()&&(C.mode==="examples"||_))n.setAttribute("aria-current","true");let o=document.createElement("span");o.className="entry-name",o.textContent=t.label;let r=document.createElement("span");return r.className="entry-note",r.textContent=Gn(t.updated),n.append(o,r),n.onclick=()=>{if(ge(!1),t.shared){let d=t.key.slice(7);try{F({section:"shared",shared:wn(dt(`#code=${d}`),d)})}catch(s){le(s.message)}}else F({section:"playground",path:t.path})},n}))}var to=()=>C.mode==="tour"?H[ke()]?.stage:void 0,ve=matchMedia("(max-width: 819px)"),no=matchMedia("(max-width: 639px)"),Ae=xe("sidebar")==="hidden";function Ct(){let e=c("editor-view");e.dataset.sidebar=Ae?"hidden":"shown";let t=y("sidebar-toggle");t.setAttribute("aria-expanded",String(!Ae));let n=j==="tour"?"lesson":"examples";t.title=Ae?`Show ${n}`:`Hide ${n}`,t.setAttribute("aria-label",t.title)}function oo(e){Ae=e,be("sidebar",e?"hidden":"shown"),Ct()}function ge(e){let t=c("editor-view");if(t.dataset.sheet==="open"===e)return;if(t.dataset.sheet=e?"open":"closed",y("context-toggle").setAttribute("aria-expanded",String(e)),c("sidebar").inert=ve.matches&&!e,e&&ve.matches)c(j==="tour"?"guide-body":"library").scrollTop=0}function Et(){let e=c("context-label");if(j==="tour"){let t=ke(),n=document.createElement("small");n.textContent=`${Oe(t+1)}/${H.length}  `,e.replaceChildren(n,H[t]?.title??"")}else e.textContent=_?"Examples & drafts · shared circuit":"Examples & drafts";y("context-toggle").title=j==="tour"?"Show or hide the lesson":"Show or hide examples and drafts"}new ResizeObserver(()=>un()).observe(c("output-view-switch").parentElement);ve.addEventListener("change",()=>{c("sidebar").inert=ve.matches&&c("editor-view").dataset.sheet!=="open"});function dn(){let e=C.stage==="test"||Z!==void 0&&on(ae()),t=to();c("stage-tabs").replaceChildren(...Object.keys(K).filter((o)=>o!=="test"||e).map((o)=>{let r=document.createElement("button");if(r.type="button",r.className="stage-tab",r.dataset.stage=o,r.title=K[o].description,r.setAttribute("aria-pressed",String(o===C.stage)),r.append(K[o].short),o===t&&o!==C.stage){let d=document.createElement("span");d.className="suggested",d.title="Suggested for this lesson",r.append(d)}return r.onclick=()=>Lt(o),r}));let n=c("stage-select");n.replaceChildren(...Array.from(c("stage-tabs").children).map((o)=>{let r=o.dataset.stage;return new Option(`${K[r].label}${r===t?" · suggested":""}`,r)})),n.value=C.stage,n.title=K[C.stage].description,un()}function un(){let e=c("output-view-switch").parentElement,t=c("stage-tabs").scrollWidth+c("output-view-switch").offsetWidth+24;if(e.clientWidth>0&&t>e.clientWidth)e.dataset.compact="";else delete e.dataset.compact}function Me(e){c("output-pane").dataset.view=e,y("view-output").setAttribute("aria-pressed",String(e==="output")),y("view-simulate").setAttribute("aria-pressed",String(e==="simulation")),f?.output.layout()}function Xe(){let e=K[C.stage];if(c("stage-description").textContent=e.description,c("stage-description").title=e.description,f)P.editor.setModelLanguage(f.output.getModel(),e.language);dn()}function pn(){Me("output"),kt(),rt(),St(),c("related-docs-menu").hidden=!_?.origin,Xe()}function ft(){for(let t of Array.from(document.querySelectorAll(".mode-switch button")))t.setAttribute("aria-pressed",String(t.dataset.mode===j));let e=j!=="docs";if(c("editor-view").hidden=!e,c("docs-view").hidden=e,c("editor-view").dataset.section=j,c("guide").hidden=j!=="tour",c("library").hidden=j!=="playground",Ct(),Et(),e)document.title=j==="tour"?"Tour · Yodl":"Playground · Yodl",f?.input.layout(),f?.output.layout();else we.stop()}function mn(){if(c("problems").hidden=!0,me=null,!Z)return;for(let e of[Z,...W.values()])P.editor.setModelMarkers(e,"yodl",[])}function it(){if(tn.cancel("playground"),we.stop(),et++,Un(),vt=++rn,mn(),y("copy-output").disabled=!0,y("output-download").disabled=!0,y("download-output").disabled=!0,he(oe?"Source changed · output is out of date":"Ready to compile"),c("stage-tabs").querySelector('[data-stage="test"]')!==null!==(C.stage==="test"||on(ae())))dn()}function Jt(e,t){if(f)Ne();if(_=t,C=e,rt(),St(),!f)return;Wn(),we.clear(),Le=!0,f.input.setValue(xe(je())??_?.source??ot(C.path)),Le=!1,f.input.setScrollTop(0),f.output.setValue(""),oe="",tt=-1,pn(),Ne(),it(),ye()}function Lt(e){if(C.stage=e,!f){Xe();return}we.clearFrame(),f.output.setValue(""),oe="",Xe(),Me("output"),Ne(),it(),ye()}function Re(e){c("editors").dataset.view=e,y("source-tab").setAttribute("aria-pressed",String(e==="source")),y("output-tab").setAttribute("aria-pressed",String(e==="output")),f?.input.layout(),f?.output.layout()}function ro(e,t=[]){Me("output"),c("problems").hidden=!1,c("error-message").textContent=e;let n=t.find((o)=>o.range&&(o.uri===D()||W.has(o.uri)));qe=n?.uri??D(),me=n?Se(n,qe):null,y("jump-error").hidden=me===null;for(let o of[D(),...W.keys()]){let r=o===D()?Z:W.get(o),d=t.flatMap((s)=>{let l=Se(s,o);return l?[{...r.validateRange(l),message:s.message,code:s.code,severity:s.severity===2?P.MarkerSeverity.Warning:P.MarkerSeverity.Error}]:[]});P.editor.setModelMarkers(r,"yodl",d)}he(oe?"Compilation failed · showing previous output":"Compilation failed · check diagnostics","error")}function io(e){let t=e.find((n)=>n.range&&(n.uri===D()||W.has(n.uri)));c("problems").hidden=e.length===0,c("error-message").replaceChildren(...e.map((n)=>{let o=document.createElement("button");o.type="button",o.className="diagnostic",o.textContent=`${n.uri?`${re(n.uri)}:${(n.range?.start.line??0)+1}:${(n.range?.start.character??0)+1}: `:""}${n.message}${n.code?` [${n.code}]`:""}${n.notes?.length?`
${n.notes.join(`
`)}`:""}`;let r=Se(n,n.uri??D());return o.disabled=!r||n.uri!==D()&&!W.has(n.uri),o.onclick=()=>{if(!r)return;Re("source"),Te(n.uri??D()),f.input.setSelection(r),f.input.revealRangeInCenter(r),f.input.focus()},o})),qe=t?.uri??D(),me=t?Se(t,qe):null,y("jump-error").hidden=me===null}async function ye(){if(!f)return;we.stop(),we.clearFrame();let e=++rn;vt=e;let t=et;mn(),he("Compiling…","loading");let n=await tn.compile("playground",{source:ae(),path:D(),stage:C.stage,files:nt()});if(!n||e!==vt)return;if(n.sources)en(n.sources);if(n.error!==void 0){ro(n.error,n.diagnostics);return}oe=n.output??"",tt=t,f.output.setValue(oe),Xe(),Me("output"),y("copy-output").disabled=!oe,y("output-download").disabled=!oe,y("download-output").disabled=!oe,he(`Compiled · ${Math.round(n.duration)} ms`,"success")}function hn(e,t){let n=URL.createObjectURL(new Blob([t],{type:"text/plain;charset=utf-8"})),o=document.createElement("a");o.href=n,o.download=e,o.click(),setTimeout(()=>URL.revokeObjectURL(n),1000)}async function gn(e,t){try{await navigator.clipboard.writeText(e);let n=t.textContent;t.textContent="Copied",setTimeout(()=>{t.textContent=n},1800)}catch{if(le("Clipboard access is unavailable. Select the text and use your browser’s Copy command."),t.id==="copy-share")c("share-url").select();else f.output.focus(),f.output.setSelection(f.output.getModel().getFullModelRange())}}function fn(){if(tt===et)hn(`${re(C.path).replace(/\.yodl$/,"")}.${K[C.stage].extension}`,oe)}function st(e){c("file-menu").hidden=!e,y("menu-button").setAttribute("aria-expanded",String(e))}function yn(){if(!f)return;let e=new URL(location.href);e.search="";let t=Object.fromEntries(Object.entries(nt()).filter(([n,o])=>Ce[n]!==o));if(e.hash=`code=${ze({...C,source:ae(),files:t,entryPath:_?.entryPath,origin:_?.origin})}`,e.href.length>32000){le("This circuit is too large for a reliable share link. Use Download source instead.");return}c("share-url").value=e.href,c("share-dialog").showModal(),c("share-url").select()}function bn(){if(f&&z===D())c("reset-dialog").showModal()}function wn(e,t){return{code:t,mode:e.mode,path:e.path,stage:e.stage,source:e.source,files:e.files??{},entryPath:e.entryPath,origin:e.origin}}function so(e){if(C.mode===e&&!_)return C.path;let t=xe(`last:${e}`);if(Pe({mode:e,path:t,stage:"write_firrtl"}))return t;return e==="tour"?ct.path:X}function ao(){let e=new URL(location.href);if(e.search="",e.hash="",j==="docs"){if(e.searchParams.set("mode","docs"),He)e.searchParams.set("chapter",He);if(bt)e.hash=bt}else if(_)e.hash=`code=${_.code}`;else if(j==="tour")e.searchParams.set("lesson",H[ke()]?.id??H[0].id);else if(e.searchParams.set("mode","examples"),C.path!==X)e.searchParams.set("example",re(C.path).replace(/\.yodl$/,""));return e.href}function Gt(e){let t=ao();if(e==="none"||t===location.href)return;if(e==="push")history.pushState(null,"",t);else history.replaceState(null,"",t)}var Zt=0;async function F(e,t="push"){let n=++Zt;if(Be(!1),e.section==="docs"){j="docs",ft(),He=e.chapter,bt=e.anchor;let o=await at.show(e.chapter,e.anchor);if(n!==Zt)return;if(He=o?.slug??e.chapter,o)document.title=`${o.title} · Yodl`;Gt(t);return}if(e.section==="shared")j=Xt(e.shared.mode),ft(),Jt({mode:e.shared.mode,path:e.shared.path,stage:e.shared.stage},e.shared),le("Shared circuit opened. Your existing lesson and example drafts are kept separately.");else{j=e.section,ft();let o=j==="tour"?"tour":"examples",r=e.section==="tour"?H.find((l)=>l.id===e.lesson):void 0,d=e.section==="playground"&&e.path&&Pe({mode:o,path:e.path,stage:"write_firrtl"})?e.path:r?yt(r):so(o);if(!(!_&&C.mode===o&&C.path===d)){be(`last:${o}`,d);let l=o==="tour"?H.find((g)=>yt(g)===d).stage:"write_firrtl";Jt({mode:o,path:d,stage:l})}else if(!f)rt(),St();if(e.section==="tour")c("guide-body").scrollTop=0}co(),Gt(t)}function vn(){let e=new URLSearchParams(location.search);if(location.hash.startsWith("#code="))try{let n=location.hash.slice(6);return{section:"shared",shared:wn(dt(location.hash),n)}}catch(n){le(n.message)}if(e.get("mode")==="docs")return{section:"docs",chapter:e.get("chapter")??void 0,anchor:location.hash.slice(1)||void 0};let t=H.find((n)=>n.id===e.get("lesson"));if(t)return{section:"tour",lesson:t.id};if(e.get("mode")==="examples")return{section:"playground",path:$e.find((o)=>re(o)===`${e.get("example")}.yodl`)??X};return{section:Xt(C.mode)}}var at=Wt({navigate:(e,t)=>void F({section:"docs",chapter:e,anchor:t}),openLesson:(e)=>void F({section:"tour",lesson:e}),openExample(e,t,n,o){let r={mode:"examples",path:X,stage:o,source:n,files:t.files,entryPath:t.path,origin:`${e.slug}.html#${t.id}`},d=ze(r);if(d.length>30000){le("This example is too large for a reliable handoff. Copy the source instead.");return}F({section:"shared",shared:{...r,code:d}})}}),lo=Ut({lessons:H,openLesson:(e)=>void F({section:"tour",lesson:e}),openDoc:(e,t)=>void F({section:"docs",chapter:e,anchor:t})});function co(){return zt??=uo().catch((e)=>{zt=void 0,he("Could not load the editor","error"),c("input-panel").textContent="The editor could not load. Check your connection and reload the page.",le(`Playground startup failed: ${e.message??String(e)}`)})}async function uo(){f=await Ot(),Z=f.input.getModel(),Ie=new ht(P,(e,t)=>{if(e!==D()&&!W.has(e)){let n=Ie?.model(e);if(n)W.set(e,n)}if(Te(e),t){if("startLineNumber"in t)f.input.setSelection(t);else f.input.setPosition(t);f.input.revealPositionInCenter({lineNumber:t.startLineNumber??t.lineNumber,column:t.startColumn??t.column})}},io,(e)=>le(`Language service: ${e}`)),z=D(),Le=!0,f.input.setValue(xe(je())??_?.source??ot(C.path)),Le=!1,pn(),Ne();for(let e of[y("compile-button"),y("menu-button"),y("view-simulate")])e.disabled=!1;we.enable(),y("compile-shortcut").textContent=gt?"⌘↵":"Ctrl ↵",c("share-shortcut").textContent=gt?"⌘S":"Ctrl S",c("new-shortcut").textContent=gt?"⌘N":"Ctrl N",f.input.addAction({id:"compile-yodl",label:"Compile Yodl",keybindings:[P.KeyMod.CtrlCmd|P.KeyCode.Enter],run:ye}),f.output.addAction({id:"compile-yodl-output",label:"Compile Yodl",keybindings:[P.KeyMod.CtrlCmd|P.KeyCode.Enter],run:ye});for(let e of[f.input,f.output])e.addCommand(P.KeyMod.CtrlCmd|P.KeyCode.KeyK,()=>lo.open());f.input.onDidChangeModelContent(()=>{if(Le||f.input.getModel()!==Z)return;Ne(),it()}),f.input.onDidChangeCursorPosition((e)=>{c("cursor-position").textContent=`Ln ${e.position.lineNumber}, Col ${e.position.column}`}),po(),he("Ready to compile"),nn(),ye()}function xn(){if(j!=="playground"){F({section:"playground",path:X});return}if(f&&C.path===X&&!_&&ae()!==Fe())bn();else F({section:"playground",path:X})}function po(){let e=c("resize-handle"),t=c("editors"),n=()=>getComputedStyle(t).getPropertyValue("--split-axis").trim()==="y",o=Number(xe("split")??50);function r(s){o=Math.max(20,Math.min(80,Number.isFinite(s)?s:50)),t.style.setProperty("--split-a",`${o}fr`),t.style.setProperty("--split-b",`${100-o}fr`),e.setAttribute("aria-valuenow",String(Math.round(o))),e.setAttribute("aria-orientation",n()?"horizontal":"vertical")}r(o),e.onpointerdown=(s)=>{e.setPointerCapture(s.pointerId),e.classList.add("dragging"),s.preventDefault()},e.onpointermove=(s)=>{if(!e.hasPointerCapture(s.pointerId))return;let l=t.getBoundingClientRect();r(n()?(s.clientY-l.top)/l.height*100:(s.clientX-l.left)/l.width*100)};let d=()=>{e.classList.remove("dragging"),be("split",String(o))};e.onlostpointercapture=d,e.onpointerup=(s)=>{if(e.hasPointerCapture(s.pointerId))e.releasePointerCapture(s.pointerId)},e.onkeydown=(s)=>{let l=n()?"ArrowUp":"ArrowLeft",g=n()?"ArrowDown":"ArrowRight";if(![l,g,"Home","End"].includes(s.key))return;s.preventDefault(),r(s.key==="Home"?20:s.key==="End"?80:o+(s.key===l?-5:5)),d()},matchMedia("(max-width: 1199px)").addEventListener("change",()=>r(o))}for(let e of Array.from(document.querySelectorAll(".mode-switch button")))e.onclick=()=>void F(e.dataset.mode==="docs"?{section:"docs",chapter:He}:e.dataset.mode==="tour"?{section:"tour"}:{section:"playground"});document.querySelector(".site-brand").onclick=(e)=>{e.preventDefault(),F({section:"tour",lesson:H[0].id})};y("lesson-list-button").onclick=()=>Be(c("lesson-list-scrim").hidden===!0);c("lesson-list-scrim").onclick=(e)=>{if(e.target===e.currentTarget)Be(!1)};y("previous-lesson").onclick=()=>{let e=H[ke()-1];if(e)F({section:"tour",lesson:e.id})};y("next-lesson").onclick=()=>{let e=H[ke()+1];F(e?{section:"tour",lesson:e.id}:{section:"playground"})};y("suggested-stage").onclick=()=>{if(!f)return;if(Lt(H[ke()].stage),ve.matches)ge(!1),Re("output")};y("new-file").onclick=()=>{ge(!1),xn()};y("sidebar-toggle").onclick=()=>oo(!Ae);y("context-toggle").onclick=()=>ge(c("editor-view").dataset.sheet!=="open");c("stage-select").onchange=()=>Lt(c("stage-select").value);y("compile-button").onclick=()=>{if(ye(),no.matches)Re("output")};y("view-output").onclick=()=>Me("output");y("view-simulate").onclick=()=>Me("simulation");y("source-tab").onclick=()=>Re("source");y("output-tab").onclick=()=>Re("output");y("menu-button").onclick=()=>st(c("file-menu").hidden===!0);c("file-menu").onclick=()=>st(!1);document.addEventListener("pointerdown",(e)=>{if(!c("file-menu").hidden&&!c("file-menu").parentElement.contains(e.target))st(!1)});y("share-button").onclick=yn;y("download-source").onclick=()=>{if(f)hn(re(z),f.input.getValue())};y("download-output").onclick=fn;y("output-download").onclick=fn;y("copy-output").onclick=()=>{if(tt===et)gn(oe,y("copy-output"))};y("reset-button").onclick=bn;y("related-docs-menu").onclick=()=>{let[e,t]=_?.origin?.replace(/\.html$/,"").split("#")??[];if(e)F({section:"docs",chapter:e,anchor:t})};y("jump-error").onclick=()=>{if(!me||!f)return;Re("source"),Te(qe),f.input.setSelection(me),f.input.revealRangeInCenter(me),f.input.focus()};c("reset-dialog").addEventListener("close",()=>{if(c("reset-dialog").returnValue==="reset")Z.setValue(Fe())});y("copy-share").onclick=()=>void gn(c("share-url").value,y("copy-share"));document.addEventListener("keydown",(e)=>{let t=e.metaKey||e.ctrlKey;if(e.key==="Escape"){if(!c("lesson-list-scrim").hidden)Be(!1);else if(ve.matches&&c("editor-view").dataset.sheet==="open")ge(!1);st(!1)}if(j==="docs"||!t)return;if(e.key==="Enter"&&!e.defaultPrevented)e.preventDefault(),ye();else if(e.key.toLowerCase()==="s"&&!e.altKey)e.preventDefault(),yn();else if(e.key.toLowerCase()==="n"&&!e.altKey&&j==="playground")e.preventDefault(),xn()});window.addEventListener("popstate",()=>void F(vn(),"none"));window.addEventListener("pagehide",()=>{at.dispose(),Ie?.dispose()});Xn();Ct();ge(!1);he("Starting editor…","loading");async function mo(){if(!location.hash.startsWith("#example="))return!1;let e=await at.show(new URLSearchParams(location.search).get("chapter")??void 0);try{let t=Ve(location.hash.slice(9)),n=e?.examples.find((r)=>r.id===t.id);if(t.version!==1||!n||typeof t.source!=="string"||!Object.hasOwn(K,t.stage))throw Error();let o={mode:"examples",path:X,stage:t.stage,source:t.source,files:n.files,entryPath:n.path,origin:`${e.slug}.html#${n.id}`};await F({section:"shared",shared:{...o,code:ze(o)}},"replace")}catch{return le("This shared example could not be opened. The original examples are shown in the guide."),!1}return!0}var Ze=vn();if(ve.matches&&Ze.section==="tour")ge(!0);if(Ze.section==="docs"&&location.hash.startsWith("#example="))mo().then((e)=>{if(!e)F({...Ze,anchor:void 0},"replace")});else F(Ze,"replace");setTimeout(()=>void at.load().then((e)=>{for(let t of e.chapters)ln.set(t.slug,t.title);if(j==="tour")rt()}).catch(()=>{}),1500);

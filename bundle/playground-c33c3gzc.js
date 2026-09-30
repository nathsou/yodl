var st={"01_presentation":[{id:"gates",title:"Your first circuit"}],"02_getting_started":[{id:"gates",title:"Your first circuit"},{id:"counter",title:"Describe the next state"}],"03_data_types":[{id:"widths",title:"Give every bit a place"},{id:"records",title:"Name a group of signals"}],"04_constructs":[{id:"modules",title:"Connect reusable modules"},{id:"generics",title:"Parameterise a design"},{id:"packages",title:"Organise a design"}],"05_operators":[{id:"bits",title:"Take signals apart"}],"06_control_flow":[{id:"selection",title:"Choose a signal"},{id:"vectors",title:"Build parallel hardware"}],"07_built_in_functions":[{id:"bits",title:"Take signals apart"},{id:"counter",title:"Describe the next state"}],"08_primitive_modules":[{id:"registers",title:"Remember a value"},{id:"memory",title:"Store a small table"}],"09_external_modules":[{id:"modules",title:"Connect reusable modules"}]};function Ut(e){let t=new TextEncoder().encode(JSON.stringify(e)),n="";for(let o of t)n+=String.fromCharCode(o);return btoa(n).replaceAll("+","-").replaceAll("/","_").replace(/=+$/,"")}function at(e){if(e.length>200000)throw Error("This shared program is too large to open.");let t=atob(e.replaceAll("-","+").replaceAll("_","/"));return JSON.parse(new TextDecoder().decode(Uint8Array.from(t,(n)=>n.charCodeAt(0))))}function Et(e){return typeof e==="string"&&/^(book\/src|examples|tour)\/[\w./-]+\.yodl$/.test(e)&&!e.split("/").some((t)=>t===".."||t===".")}function Vt(e){return!!e&&typeof e==="object"&&!Array.isArray(e)&&Object.entries(e).every(([t,n])=>Et(t)&&typeof n==="string")}var Yt=[{id:"gates",title:"Your first circuit",topic:"Signals & modules",intro:"A Yodl program describes hardware. A module connects named inputs to named outputs; the connections operate continuously.",concepts:["bool is a one-bit signal.","The expression a and b describes a logic gate. It does not wait for a clock."],observe:"In FIRRTL, find the two input ports, the output port, and the and operation.",challenge:"Change and to xor. The output will describe a gate that is high when exactly one input is high.",stage:"write_firrtl",file:"01-gates.yodl"},{id:"widths",title:"Give every bit a place",topic:"Integers & arithmetic",intro:"Hardware signals have fixed widths. u8 is an unsigned eight-bit integer; s8 is a signed eight-bit integer. Choose the output width to retain the bits you need.",concepts:["Adding two eight-bit unsigned values can require nine bits.","Sized literals spell out width and base: 8'hFF is eight bits of hexadecimal FF. Signedness changes require an explicit cast."],observe:"Inspect the nine-bit sum and sixteen-bit product ports. Switch to Typed to see expression types.",challenge:"Change sum from u9 to u8. Narrowing keeps the low eight bits, so a carry no longer fits in the output.",stage:"write_firrtl",file:"02-widths.yodl"},{id:"selection",title:"Choose a signal",topic:"Conditions & multiplexers",intro:"Conditions select between signals. Both alternatives describe hardware; a condition does not make the circuit execute one software branch at a time.",concepts:["Use if for a two-way choice.","Use match for several cases, with _ as the default."],observe:"Look for mux operations in FIRRTL: these are the signal selectors described by the conditions.",challenge:"Add a 2 case to match that returns a xor b. Keep the default case.",stage:"write_firrtl",file:"03-selection.yodl"},{id:"bits",title:"Take signals apart",topic:"Slices & built-ins",intro:"Individual bits and slices let you work with the representation of a value. Built-in functions have names ending in !.",concepts:["word[7:4] takes bits seven through four, inclusive.","cat! joins bit strings in order; xorr reduces a signal to its parity bit."],observe:"Find bits, cat, and xorr operations in the FIRRTL output.",challenge:"Change swapped to cat!(low, low). Both halves of the output now come from the same four input bits.",stage:"write_firrtl",file:"04-bits.yodl"},{id:"vectors",title:"Build parallel hardware",topic:"Vectors & loops",intro:"A vector groups a fixed number of values. A for loop creates repeated hardware at compile time, so the loop bounds must be known before the circuit runs.",concepts:["[4]u8 is four eight-bit elements.","0..<Lanes excludes the upper bound. All four lanes exist in parallel."],observe:"The Simplified output expands the loop into individual assignments. Switch to FIRRTL to see the vector ports.",challenge:"Change Lanes from 4 to 8. Compile again and count the expanded assignments.",stage:"write_simplified",file:"05-vectors.yodl"},{id:"records",title:"Name a group of signals",topic:"Records & type aliases",intro:"Records collect related signals into named fields. A type alias gives the collection a reusable name without allocating storage.",concepts:["Access a field with . followed by its name.","A record spread copies fields; later fields override the copied values."],observe:"Find the r, g, and b fields in the output ports. They remain individual signals within a bundle.",challenge:"Also override b with 0 in muted. Only the red channel will pass through.",stage:"write_firrtl",file:"06-records.yodl"},{id:"modules",title:"Connect reusable circuits",topic:"Instances & ports",intro:"Define a module once and instantiate it wherever you need that hardware. Each instance is a separate circuit with its own connections.",concepts:["Named arguments connect inputs when creating an instance.","Access an instance output with .sum. Top is the entry circuit in this design."],observe:"Find two Adder instances under Top. They share a definition but connect to different inputs.",challenge:"Connect the second adder to a and c instead of b and c.",stage:"write_firrtl",file:"07-modules.yodl"},{id:"generics",title:"Parameterise a design",topic:"Compile-time parameters",intro:"Generic parameters configure hardware before it runs. Nat parameters describe sizes; Type parameters let a module work with different signal types.",concepts:["uint[Width] uses a compile-time width.","Instantiation specialises each generic module with concrete parameters. These parameters are not input ports."],observe:"Monomorphised output shows concrete versions of the generic modules. Compare it with Source.",challenge:"Change the wide input and output from u16 to u12, and change Mask[16] to Mask[12].",stage:"write_mono",file:"08-generics.yodl"},{id:"registers",title:"Remember a value",topic:"Clocked state",intro:"Combinational logic has no memory. Reg adds state: q is the current value and d is the value sampled at the next rising clock edge.",concepts:["Reg[u8] stores eight bits.","rst resets the register to zero synchronously. en controls whether it captures a new value."],observe:"Find the register and its clock, reset, and enable logic in FIRRTL. The output reads the stored q value.",challenge:"Connect en to true instead of enable. The register will capture data on every rising edge unless reset is asserted.",stage:"write_firrtl",file:"09-registers.yodl"},{id:"counter",title:"Describe the next state",topic:"Feedback & constants",intro:"A counter feeds its current register value through combinational logic to compute the next value. The register breaks the feedback path into clock cycles.",concepts:["clog2!(Limit) computes the number of address bits needed for Limit values.","The comparison makes the counter wrap after Limit - 1. Reset establishes the initial zero state."],observe:"Follow the register output through the increment and selection logic back to its input.",challenge:"Change Limit from 10 to 16. The width stays four bits, but the wrap comparison changes.",stage:"write_firrtl",file:"10-counter.yodl"},{id:"packages",title:"Organise a design",topic:"Packages & names",intro:"Packages group declarations under a namespace. Qualified names make it clear where a reusable module belongs.",concepts:["Use :: to access a declaration inside a package.","A file brought in with import is also wrapped in a package named after the file. Larger examples demonstrate imports."],observe:"Find the qualified Logic::Invert name in Source, then switch to FIRRTL to inspect its instance.",challenge:"Add another Invert instance after the first and connect q to its output. Two inversions restore the original signal.",stage:"write_source",file:"11-packages.yodl"},{id:"memory",title:"Store a small table",topic:"Memory & latency",intro:"Memory describes indexed storage with explicit read and write ports. Latency is part of the interface: this design requests a read latency of one cycle.",concepts:["Depth is the number of stored words; T is the type of each word.","Read and write ports carry clocks, addresses, and enables. A true write mask enables the whole byte."],observe:"Find the memory depth, read latency, and write latency in FIRRTL. Compilation shows structure; the playground does not simulate clock cycles.",challenge:"Increase Depth to 32 and change addr from u4 to u5 so every word remains addressable.",stage:"write_firrtl",file:"12-memory.yodl"}];var X={write_source:{label:"Source",short:"Source",extension:"yodl",language:"yodl",description:"Resolved source, with imported declarations available to the compiler."},write_mono:{label:"Monomorphised",short:"Mono",extension:"yodl",language:"yodl",description:"Generic modules specialised with concrete parameters."},write_typed:{label:"Typed",short:"Typed",extension:"yodl",language:"yodl",description:"Expressions annotated with their resolved types and widths."},write_simplified:{label:"Simplified",short:"Simplified",extension:"yodl",language:"yodl",description:"Core representation with loops expanded and expressions simplified."},write_firrtl:{label:"FIRRTL",short:"FIRRTL",extension:"fir",language:"firrtl",description:"Hardware represented as ports, operations, registers, and connections."},write_low_firrtl:{label:"Low FIRRTL",short:"Low",extension:"fir",language:"firrtl",description:"FIRRTL after lowering passes, ready for downstream tools."},write_rtlil:{label:"RTLIL",short:"RTLIL",extension:"il",language:"rtlil",description:"Hardware in the intermediate language used by Yosys."},test:{label:"Tests",short:"Tests",extension:"txt",language:"plaintext",description:"Run procedural testbenches and report each passing test."}};function Ie(e,t){if(e.uri!==t||!e.range)return null;let{start:n,end:o}=e.range;return{startLineNumber:n.line+1,startColumn:n.character+1,endLineNumber:o.line+1,endColumn:o.character+1}}var De={...{"examples/Testbench.yodl":`module XorGate(a: bool, b: bool) -> (out: bool) {
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
`}},j=Yt,Ke=Object.keys(De).filter((e)=>/^examples\/[^/]+\.yodl$/.test(e)).sort(),me="examples/Playground.yodl",Ct={mode:"tour",path:`tour/${j[0].file}`,stage:"write_firrtl"};function ze(e){if(!e||typeof e!=="object")return!1;let t=e;return Object.hasOwn(X,t.stage)&&(t.mode==="tour"?j.some((n)=>`tour/${n.file}`===t.path):t.mode==="examples"&&(Ke.includes(t.path)||t.path===me))}function lt(e){return Ut({...e,version:e.entryPath?2:1})}function Lt(e){if(!e.startsWith("#code="))return null;try{let t=at(e.slice(6));if(![1,2].includes(t.version)||!ze(t)||typeof t.source!=="string")throw Error();if(t.version===2&&(!Et(t.entryPath)||!Vt(t.files)||t.origin!==void 0&&!/^[a-zA-Z0-9_-]+\.html#[a-z0-9-]+$/.test(t.origin)))throw Error();if(t.version===1)return{version:1,mode:t.mode,path:t.path,stage:t.stage,source:t.source};return t}catch{throw Error("This share link is invalid, too large, or uses an unsupported version.")}}class Ue{timeoutMs;worker;active;queue=[];timer;nextId=0;constructor(e=15000){this.timeoutMs=e}compile(e,t){return this.cancel(e),new Promise((n)=>{this.queue.push({owner:e,request:{...t,id:++this.nextId},resolve:n}),this.pump()})}cancel(e){if(this.queue=this.queue.filter((t)=>{if(t.owner!==e)return!0;return t.resolve(null),!1}),this.active?.owner===e)this.worker?.terminate(),this.worker=void 0,this.finish(null)}dispose(){for(let e of this.queue)e.resolve(null);if(this.queue=[],this.active)this.cancel(this.active.owner);this.worker?.terminate(),this.worker=void 0}finish(e){clearTimeout(this.timer);let t=this.active;this.active=void 0,t?.resolve(e),this.pump()}pump(){if(this.active||!this.queue.length)return;let e=this.active=this.queue.shift(),t=(n)=>{if(this.active!==e)return;this.worker?.terminate(),this.worker=void 0,this.finish({id:e.request.id,error:n,duration:0})};try{this.worker??=new Worker(new URL("./playground-worker-cxe13d5w.js",import.meta.url),{type:"module"}),this.worker.onmessage=(n)=>{if(this.active===e&&n.data.id===e.request.id)this.finish(n.data)},this.worker.onerror=()=>t("The compiler worker could not run. Try Compile again."),this.timer=setTimeout(()=>t("Compilation exceeded 15 seconds. Try a smaller design or reduce compile-time loop bounds."),this.timeoutMs),this.worker.postMessage(e.request)}catch(n){t(`Could not start the compiler: ${n.message}`)}}}class Tt{startupTimeoutMs;worker;requestId=0;activeId;request;startupTimer;constructor(e=30000){this.startupTimeoutMs=e}start(e,t){this.stop();let n=++this.requestId;this.activeId=n,this.request=e;let o=this.worker=new Worker(new URL("./playground-worker-cxe13d5w.js",import.meta.url),{type:"module"});o.onmessage=(i)=>{if(this.worker!==o||i.data.id!==n)return;clearTimeout(this.startupTimer),t(i.data)},o.onerror=()=>{if(this.worker!==o)return;this.stop(),t({id:n,type:"error",error:"The simulation worker could not run. Try Run again."})},this.startupTimer=setTimeout(()=>{if(this.worker!==o)return;this.stop(),t({id:n,type:"error",error:"Simulation compilation timed out. Try a smaller design."})},this.startupTimeoutMs),o.postMessage({...e,id:n,simulate:{...e.simulate,mode:"realtime",action:e.simulate?.action??"run"}})}pause(){this.postControl("pause")}resume(e){this.postControl("resume",e)}command(e,t){this.postControl(e,t)}setInputs(e){if(!this.request?.simulate)return;this.request={...this.request,simulate:{...this.request.simulate,inputs:e}},this.postControl("settle")}stop(){clearTimeout(this.startupTimer),this.worker?.terminate(),this.worker=void 0,this.activeId=void 0,this.request=void 0}postControl(e,t){if(!this.worker||this.activeId===void 0||!this.request)return;this.worker.postMessage({id:this.activeId,control:{action:e,options:t,...e==="settle"?{inputs:this.request.simulate?.inputs}:{}}})}}var Jt=[{id:"teal",label:"Teal"},{id:"cobalt",label:"Cobalt"},{id:"moss",label:"Moss"},{id:"plum",label:"Plum"},{id:"ochre",label:"Ochre"},{id:"signal",label:"Signal"},{id:"ember",label:"Ember"}];function Gt(e){return getComputedStyle(document.documentElement).getPropertyValue(`--${e}`).trim()}function Zt(e){try{return localStorage.getItem(e)}catch{return null}}function Xt(e,t){try{localStorage.setItem(e,t)}catch{}}function Qt(e,t){let n=matchMedia("(prefers-color-scheme: dark)"),o=Array.from(e.querySelectorAll("[data-theme-preference]")),i=Zt("yodl-playground-v2:theme"),d=i==="light"||i==="dark"?i:"system",l=()=>{let c=d==="dark"||d==="system"&&n.matches;document.documentElement.dataset.theme=c?"dark":"light";for(let w of o)w.setAttribute("aria-pressed",String(w.dataset.themePreference===d));t(c)};for(let c of o)c.addEventListener("click",()=>{d=c.dataset.themePreference,Xt("yodl-playground-v2:theme",d),l()});return n.addEventListener("change",l),l(),l}function en(e,t){let n=e.querySelector("#accent-button"),o=e.querySelector("#accent-menu"),i=e.querySelector("#accent-label"),d=Array.from(e.querySelectorAll(".swatch")),l=Zt("yodl-playground-v2:accent"),c=Jt.some((k)=>k.id===l)?l:"teal",w=()=>{document.documentElement.dataset.accent=c,i.textContent=Jt.find((k)=>k.id===c).label;for(let k of d)k.setAttribute("aria-pressed",String(k.dataset.accent===c))},P=(k)=>{o.hidden=!k,n.setAttribute("aria-expanded",String(k))};n.addEventListener("click",()=>P(o.hidden===!0));for(let k of d)k.addEventListener("click",()=>{c=k.dataset.accent,Xt("yodl-playground-v2:accent",c),w(),t()});return document.addEventListener("pointerdown",(k)=>{if(!o.hidden&&!e.contains(k.target))P(!1)}),e.addEventListener("keydown",(k)=>{if(k.key==="Escape"&&!o.hidden)P(!1),n.focus()}),w(),w}var q,tn;function on(){if(q)return Promise.resolve();return tn??=Yn().catch((e)=>{throw tn=void 0,e})}var zn="./monaco-wn4p6kqb.js",Un="./monaco-44nfyfsx.css";function Vn(e){return new Promise((t,n)=>{let o=document.createElement("link");o.rel="stylesheet",o.href=e,o.onload=()=>t(),o.onerror=()=>{o.remove(),n(Error("Could not load the editor styles. Reload the page to try again."))},document.head.append(o)})}async function Yn(){if(!window.monaco){let e,t=new Promise((n,o)=>{e=setTimeout(()=>o(Error("The code editor took too long to load. Try again.")),30000)});try{let n=Promise.all([Vn(new URL(Un,import.meta.url).href),import(new URL(zn,import.meta.url).href)]),[,o]=await Promise.race([n,t]);window.monaco=o.monaco}finally{clearTimeout(e)}}q=window.monaco,q.languages.register({id:"yodl"}),q.languages.setMonarchTokensProvider("yodl",{keywords:["declare","module","test","let","match","if","else","for","in","const","package","import","true","false"],typeKeywords:["uint","sint","bool","clock","type","Nat","Type"],wordOperators:["and","or","not","xor","nand","nor","xnor","shl","shr","andr","orr","xorr"],operators:["==","!=","<=",">=","<:",">:","+:","-:","..","..<","..=","+","-","*","/","%","=>","?",":",".","->","::"],symbols:/[=><!~?:&|+\-*/^%.]+/,tokenizer:{root:[[/\w+!/,"function"],[/\b[us]\d+\b/,"type"],[/[A-Z]\w*/,{cases:{"@typeKeywords":"type","@default":"ident.cap"}}],[/[a-zA-Z_]\w*/,{cases:{"@keywords":"keyword","@typeKeywords":"type","@wordOperators":"keyword.operator","@default":"identifier"}}],[/"([^"\\]|\\.)*$/,"string.invalid"],[/"/,{token:"string.quote",bracket:"@open",next:"@string"}],[/'[^'\\]'/,"string"],[/'\\.'/,"string"],[/\/\/.*$/,"comment"],[/\b\d+'[bhod]?\w+\b/,"number"],[/\b\d+(_\d+)*\b/,"number"],[/@symbols/,"delimiter"],[/[(){}\[\],;]/,"delimiter"],[/\s+/,"white"]],string:[[/[^\\"]+/,"string"],[/\\./,"string.escape"],[/"/,{token:"string.quote",bracket:"@close",next:"@pop"}]]}}),q.languages.setLanguageConfiguration("yodl",{comments:{lineComment:"//"},brackets:[["{","}"],["[","]"],["(",")"]],autoClosingPairs:[{open:"{",close:"}"},{open:"[",close:"]"},{open:"(",close:")"},{open:'"',close:'"'}]});for(let e of["firrtl","rtlil"])q.languages.register({id:e}),q.languages.setMonarchTokensProvider(e,{tokenizer:{root:[[e==="firrtl"?/;.*/:/#.*/,"comment"],[/"[^"\\]*(?:\\.[^"\\]*)*"/,"string"],[/\b(?:circuit|module|extmodule|input|output|wire|node|reg|regreset|mem|inst|of|when|else|connect|attribute|parameter|cell|end|process|sync|update|assign)\b/,"keyword"],[/\b(?:UInt|SInt|Clock|Reset|AsyncReset)\b/,"type"],[/\b(?:mux|add|sub|mul|and|or|xor|not|bits|cat|pad|eq|lt|gt)\b/,"function"],[/-?\b\d+(?:'[01xzm-]+)?\b/,"number"],[/[<>=:]+/,"delimiter"]]}});ct()}var Jn={panel:"#fefdfc",ink:"#211c17",mute:"#69625d",line:"#e2dfdb",sunk:"#f3f1ed",bg:"#faf9f6",acc:"#008381","acc-soft":"#dbf3f1","k-kw":"#6b46a0","k-ty":"#00717f","k-fn":"#945a00","k-nm":"#2b7440","k-id":"#23588a"},I=(e)=>(typeof getComputedStyle==="function"?Gt(e):"")||Jn[e],ce=(e)=>e.replace("#","");function ct(){if(!q)return;let e=document.documentElement.dataset.theme==="dark";q.editor.defineTheme("yodl",{base:e?"vs-dark":"vs",inherit:!0,rules:[{token:"",foreground:ce(I("ink"))},{token:"keyword",foreground:ce(I("k-kw"))},{token:"keyword.operator",foreground:ce(I("k-kw"))},{token:"identifier",foreground:ce(I("ink"))},{token:"operator",foreground:ce(I("mute"))},{token:"type.identifier",foreground:ce(I("k-ty"))},{token:"type",foreground:ce(I("k-ty"))},{token:"function",foreground:ce(I("k-fn"))},{token:"number",foreground:ce(I("k-nm"))},{token:"string",foreground:ce(I("k-nm"))},{token:"ident.cap",foreground:ce(I("k-id"))},{token:"comment",foreground:ce(I("mute"))},{token:"delimiter",foreground:ce(I("mute"))}],colors:{"editor.background":I("panel"),"editor.foreground":I("ink"),"editorLineNumber.foreground":I("mute")+"99","editorLineNumber.activeForeground":I("ink"),"editor.selectionBackground":I("acc-soft"),"editor.inactiveSelectionBackground":I("sunk"),"editor.lineHighlightBackground":I("sunk")+"00","editor.lineHighlightBorder":I("sunk")+"00","editorCursor.foreground":I("acc"),"editorIndentGuide.background1":I("line"),...Object.fromEntries([1,2,3,4,5,6].map((t)=>[`editorBracketHighlight.foreground${t}`,I("mute")])),"editorBracketHighlight.unexpectedBracket.foreground":I("mute"),"editorWidget.background":I("panel"),"editorWidget.border":I("line"),"scrollbarSlider.background":I("line")+"aa","scrollbarSlider.hoverBackground":I("mute")+"66"}}),q.editor.setTheme("yodl")}async function Gn(){let e=typeof document<"u"?document.fonts:void 0;if(!e)return;try{await Promise.race([e.load('13.5px "IBM Plex Mono"'),new Promise((t)=>setTimeout(t,1500))])}catch{}e.ready.then(()=>q?.editor.remeasureFonts?.())}async function nn(e,t={}){await on(),await Gn();let n={automaticLayout:!0,minimap:{enabled:!1},scrollBeyondLastLine:!1,fontSize:13.5,lineHeight:23,fontFamily:'"IBM Plex Mono", ui-monospace, SFMono-Regular, Consolas, monospace',padding:{top:18,bottom:18},renderLineHighlight:"none",glyphMargin:!1,folding:!0,lineNumbersMinChars:3,lineDecorationsWidth:18,overviewRulerLanes:0,"semanticHighlighting.enabled":!0,hideCursorInOverviewRuler:!0,overviewRulerBorder:!1,bracketPairColorization:{enabled:!1},guides:{indentation:!1,bracketPairs:!1},matchBrackets:"never",scrollbar:{useShadows:!1,verticalScrollbarSize:8,horizontalScrollbarSize:8},tabSize:4,insertSpaces:!0,fixedOverflowWidgets:!0};return e.replaceChildren(),q.editor.create(e,{...n,language:"yodl",ariaLabel:"Yodl source code",...t})}async function rn(){await on();let e=q.editor.createModel("","yodl"),t=await nn(document.getElementById("input-panel"),{model:e}),n=await nn(document.getElementById("output-panel"),{readOnly:!0,language:"firrtl",ariaLabel:"Compiled output"});return{input:t,output:n}}var U=(e)=>document.getElementById(e),Mt=16,Zn=10,Xn=512;function sn(e){let t={};for(let n of e.split(",")){let o=/^\s*([A-Za-z_$][\w$]*)(?::(\d+))?\s*=\s*(-?\d+)\s*$/.exec(n);if(!n.trim())continue;if(!o)throw Error(`Invalid input assignment: ${n}`);if(!Number.isSafeInteger(Number(o[3])))throw Error("Input exceeds the safe integer range.");t[o[1]]={width:Number(o[2]??32),value:Number(o[3])}}return t}function Qn(e){if(!e.known)return"x";if(e.width===1)return e.value==="0"?"0":"1";try{return`${e.width}'h${BigInt(e.value).toString(16)}`}catch{return e.value}}var eo=(e)=>{if(!e.known)return"x";try{return BigInt(e.value).toString(16)}catch{return e.value}};function to(e){if(e>=1e6)return`${(e/1e6).toFixed(1)} MHz`;if(e>=1e4)return`${Math.round(e/1000)} kHz`;if(e>=1000)return`${(e/1000).toFixed(1)} kHz`;return`${e<10?e.toFixed(1):Math.round(e)} Hz`}function an(e){let t=new Tt,n="ready",o,i=[],d,l,c=(r)=>U(r),w=(r)=>U(r),P=["simulation-top","simulation-clock","simulation-cycles-per-frame","simulation-clock-hz","simulation-refresh-fps"];function k(){let r=n==="running"||n==="stepping";c("simulation-run").textContent=r?"Pause":n==="paused"?"Resume":"Run",c("simulation-run").disabled=n==="starting"||n==="halted",c("simulation-reset").disabled=n==="ready"||n==="starting",c("simulation-stop").disabled=n==="ready"}function ee(r){let b=U("simulation-framebuffer");if(d=r,U("simulation-zoom-control").hidden=!r,!r){b.hidden=!0;return}if(b.hidden=!1,b.width!==r.width||b.height!==r.height)b.width=r.width,b.height=r.height,l=void 0;let C=(b.parentElement?.clientWidth||640)-32,R=U("simulation-zoom").value,E=R==="fit"?Math.min(C/r.width,480/r.height):Number(R);b.style.width=`${r.width*E}px`,b.style.height=`${r.height*E}px`;let p=b.getContext("2d");if(!p)return;let a=l??=p.createImageData(r.width,r.height),g=Math.ceil(r.width/32);for(let m=0;m<r.width*r.height;m++){let f=Math.floor(m/r.width),L=m%r.width,T=f*g+Math.floor(L/32),A=!(!r.valid||(r.packed?(r.valid[T]&1<<L%32)!==0:r.valid[m]!==0))?16711935:r.packed?(r.packed[T]&1<<L%32)!==0?r.onColor??16777215:r.offColor??0:r.rgb?.[m]??r.pixels?.[m]??0;a.data[m*4]=A>>>16&255,a.data[m*4+1]=A>>>8&255,a.data[m*4+2]=A&255,a.data[m*4+3]=255}p.putImageData(a,0,0)}function h(r,b){let C=document.createElement("div");C.className="signal";let R=document.createElement("span");R.className="signal-name",R.append(r.name+" ");let E=document.createElement("small");return E.textContent=r.width===1?"bool":`u${r.width}`,R.append(E),C.append(R,b),C}function K(r){let b=U("simulation-inputs-controls"),C=r.map((E)=>`${E.name}:${E.width}:${E.value}:${E.known}`).join("|");if(b.dataset.signature===C)return;b.dataset.signature=C,b.replaceChildren();let R=(E)=>{let p=[...b.querySelectorAll("[data-signal]")].map((a)=>{let g=a instanceof HTMLInputElement?a.value:a.getAttribute("aria-checked")==="true"?1:0;return`${a.dataset.signal}:${a.dataset.width}=${g}`});w("simulation-inputs").value=p.join(", ");try{let a=sn(p.join(", "));if(E instanceof HTMLInputElement)E.setCustomValidity("");if(n!=="ready")t.setInputs(a)}catch(a){if(E instanceof HTMLInputElement)E.setCustomValidity(String(a)),E.reportValidity()}};for(let E of r){let p;if(E.width===1){let a=document.createElement("button");a.type="button",a.setAttribute("role","switch"),a.setAttribute("aria-checked",String(E.value!=="0")),a.setAttribute("aria-label",E.name),a.textContent=E.value!=="0"?"1":"0",a.addEventListener("click",()=>{let g=a.getAttribute("aria-checked")!=="true";a.setAttribute("aria-checked",String(g)),a.textContent=g?"1":"0",R(a)}),p=a}else{let a=document.createElement("input");a.type="text",a.value=E.value,a.inputMode="numeric",a.title=`u${E.width}`,a.setAttribute("aria-label",E.name),a.addEventListener("change",()=>R(a)),p=a}p.className="signal-value",p.dataset.signal=E.name,p.dataset.width=String(E.width),b.append(h(E,p))}if(!r.length)b.append(z("No inputs"))}function z(r){let b=document.createElement("p");return b.className="signal-empty",b.textContent=r,b}function ue(r){let b=U("simulation-outputs"),C=r.slice(0,100).map((R)=>{let E=document.createElement("span");return E.className="signal-value signal-output",E.textContent=Qn(R),h(R,E)});if(r.length>100)C.push(h({name:`… ${r.length-100} more`,width:0,value:"",known:!1},document.createElement("span")));b.replaceChildren(...C.length?C:[z("No outputs")])}function ie(r){if(r.totalCycles===void 0||!r.outputs&&!r.inputs)return;let b=new Map;for(let R of[...r.inputs??[],...r.outputs??[]])b.set(R.name,R);let C=i.at(-1);if(C&&C.cycle===r.totalCycles){C.values=b;return}if(C&&r.totalCycles<C.cycle)i=[];if(i.push({cycle:r.totalCycles,values:b}),i.length>Xn)i.shift()}function pe(){let r=U("simulation-trace");if(!i.length){r.replaceChildren(z("Run or step the simulation to record signals.")),U("trace-range").textContent="";return}let b=i.at(-1),C=[...b.values.keys()].filter((m)=>m!==o).slice(0,Zn-(o?1:0)),R=Math.max(0,i.length-Mt),E=i.slice(R),p=[],a=(m,f)=>{let L=document.createElement("div");L.className="trace-row";let T=document.createElement("span");T.className="trace-name",T.textContent=m,T.title=m;let M=document.createElement("div");return M.className="trace-lane",M.append(...f),L.append(T,M),L},g=(m,f,L)=>{let T=document.createElement("div");if(T.className="trace-cell",T.dataset.kind=m,f)T.dataset.future="";if(L)T.dataset.edge="";return T};if(o){let m=[];for(let f=0;f<Mt;f++){let L=g("clock",f>=E.length,f===0);L.append(document.createElement("span"),document.createElement("span")),m.push(L)}p.push(a(o,m))}for(let m of C){let f=[],L;for(let T=0;T<Mt;T++){let M=E[Math.min(T,E.length-1)].values.get(m),A=T>=E.length;if(!M){f.push(g("bus",A,!1));continue}let W=M.width===1&&M.known,_=`${M.known}:${M.value}`,re=!A&&(L===void 0||L!==_),se=g(W?"bit":"bus",A,re);if(W&&M.value!=="0")se.dataset.high="";if(!W&&re){let te=document.createElement("span");te.className="bus-value",te.textContent=eo(M),se.append(te)}if(!A)L=_;f.push(se)}p.push(a(m,f))}r.replaceChildren(...p),U("trace-range").textContent=E.length>1?`cycles ${E[0].cycle}–${b.cycle}`:`cycle ${b.cycle}`}function D(r){let b=U("simulation-output");if(r.type==="error"){n="error",b.hidden=!1,b.textContent=r.error??"Simulation failed.",U("simulation-state").textContent="Error",k(),e.setStatus("Simulation failed","error");return}if(n=r.type==="halted"?"halted":r.type==="stopped"?"ready":r.type==="stepping"?"stepping":r.type==="frame"||r.type==="resumed"?"running":"paused",r.frame)ee(r.frame);else if(r.metadata&&!r.metadata.display)ee(void 0);if(r.clock!==void 0)o=r.clock;if(r.inputs)r={...r,inputs:r.inputs.filter((f)=>f.name!==o)};if(r.outputs)ue(r.outputs);if(r.inputs)K(r.inputs);ie(r),pe();let C=r.messages??[];if(b.hidden=C.length===0,b.textContent=C.join(`
`),c("simulation-step-cycle").disabled=!r.clock||n==="halted",c("simulation-step-frame").hidden=!(r.frame&&r.clock),c("simulation-step-frame").disabled=n==="halted",r.metadata){let f={"simulation-top":r.metadata.top,"simulation-clock":r.clock,"simulation-cycles-per-frame":r.playback?.cyclesPerFrame,"simulation-clock-hz":r.playback?.clockHz??"maximum","simulation-refresh-fps":r.playback?.refreshFps};for(let[L,T]of Object.entries(f))w(L).placeholder=String(T??"automatic");w("simulation-cycles-per-frame").disabled=!r.clock||Boolean(r.metadata.display?.stream),w("simulation-clock-hz").disabled=!r.clock,w("simulation-refresh-fps").disabled=!r.clock}let R=r.totalCycles??0,E=r.cyclesPerSecond===void 0||n!=="running"&&n!=="stepping"?"":` · ${to(r.cyclesPerSecond)}`;U("simulation-cycle").textContent=`cycle ${R.toLocaleString()}${E}`;let p=r.simulatedSeconds===void 0?"":` · ${r.simulatedSeconds.toFixed(3)} simulated s`,a=r.status?.failed??!1,g=a?"Failed":n[0].toUpperCase()+n.slice(1),m=r.status?.exit_code===void 0?"":` · exit ${r.status.exit_code}`;U("simulation-state").textContent=`${g}${m}${p}`,k(),e.setStatus(a?`Simulation failed${r.status?.first_failure?`: ${r.status.first_failure.message}`:""}`:n==="running"||n==="stepping"?"Simulating…":`Simulation ${n}`,a?"error":void 0)}function Y(r="run"){let b=(p)=>{let a=Number(w(p).value);return Number.isFinite(a)&&a>0?a:void 0},C={clockHz:b("simulation-clock-hz"),refreshFps:b("simulation-refresh-fps"),cyclesPerFrame:b("simulation-cycles-per-frame")};if(n!=="ready"&&n!=="error"){if(r==="run")if(n==="running"||n==="stepping")t.pause();else t.resume(C);else t.command(r,C);return}let R=w("simulation-top").value.trim(),E=w("simulation-clock").value.trim();i=[],pe(),U("simulation-state").textContent="Compiling simulation…",n="starting",k();try{let{source:p,path:a,files:g}=e.request();t.start({source:p,path:a,stage:"write_low_firrtl",files:g,simulate:{action:r,...R?{top:R}:{},...E?{clock:E}:{},...Object.fromEntries(Object.entries(C).filter(([,m])=>m!==void 0)),inputs:sn(w("simulation-inputs").value)}},D)}catch(p){D({id:0,type:"error",error:String(p)})}}function J(){t.stop(),n="ready",U("simulation-state").textContent="Ready",U("simulation-cycle").textContent="cycle 0",k()}return c("simulation-run").onclick=()=>Y("run"),c("simulation-reset").onclick=()=>{i=[],pe(),Y("reset")},c("simulation-step-cycle").onclick=()=>Y("step_cycle"),c("simulation-step-frame").onclick=()=>Y("step_frame"),U("simulation-zoom").onchange=()=>{if(d)ee(d)},c("simulation-stop").onclick=()=>{J(),e.setStatus("Simulation stopped")},c("simulation-settings").onclick=()=>{let r=U("simulation-options");r.hidden=!r.hidden,c("simulation-settings").setAttribute("aria-expanded",String(!r.hidden))},pe(),ue([]),K([]),k(),{enable(){for(let r of["simulation-run","simulation-step-cycle",...P])U(r).disabled=!1;k()},stop:J,clear(){J(),i=[],o=void 0,ee(void 0),pe(),ue([]),U("simulation-inputs-controls").dataset.signature="",K([]),U("simulation-output").hidden=!0;for(let r of["simulation-top","simulation-clock","simulation-inputs"])w(r).value=""},clearFrame(){ee(void 0)},get active(){return n!=="ready"&&n!=="error"},run:Y}}var ln=(e)=>e.replace(/[&<>"']/g,(t)=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[t]),no=/^(module|declare|test|let|const|type|package|import|for|in|if|else|match|true|false)$/,oo=/^(and|or|not|xor|nand|nor|xnor|shl|shr|andr|orr|xorr)$/,io=/^(u\d+|s\d+|uint|sint|bool|clock|Nat|Type)$/,ro=/^(circuit|module|extmodule|input|output|wire|node|reg|regreset|mem|inst|of|when|else|connect|attribute|parameter|cell|end|process|sync|update|assign|public|version|intmodule|invalidate|skip|printf|stop|assert|cover|assume)$/,so=/^(UInt|SInt|Clock|Reset|AsyncReset|Analog)$/,ao=/^(mux|add|sub|mul|div|rem|and|or|xor|not|bits|cat|pad|eq|neq|lt|leq|gt|geq|shl|shr|dshl|dshr|head|tail|andr|orr|xorr|neg|cvt|asUInt|asSInt|asClock|validif)$/;function lo(e,t){if(t==="yodl"){if(e.startsWith("//"))return"comment";if(e.startsWith('"'))return"string";if(no.test(e)||oo.test(e))return"keyword";if(io.test(e))return"type";if(/^\w+!$/.test(e))return"function";if(/^\d/.test(e))return"number";if(/^[A-Z]/.test(e))return"ident";if(/^[=<>+\-*/%:?.&|^~!]+$/.test(e))return"punct";return""}if(e.startsWith(t==="firrtl"?";":"#"))return"comment";if(e.startsWith('"'))return"string";if(ro.test(e))return"keyword";if(so.test(e))return"type";if(ao.test(e))return"function";if(/^-?\d/.test(e))return"number";if(/^[<>=:]+$/.test(e))return"punct";return""}function co(e,t="yodl"){if(t==="plaintext")return[{text:e,kind:"",start:0,end:e.length}];let i=new RegExp(`(${t==="rtlil"?"#[^\\n]*":t==="firrtl"?";[^\\n]*":"\\/\\/[^\\n]*"}|"(?:[^"\\\\\\n]|\\\\.)*"|\\b\\w+!|${t==="yodl"?"\\b\\d+":"-?\\b\\d+"}(?:'[bhod]?[\\da-fA-F_]+)?\\b|\\b[a-zA-Z_]\\w*\\b|[=<>+\\-*/%:?.&|^~!]+)`,"g"),d=0;return e.split(i).filter(Boolean).map((l)=>{let c=d;return d+=l.length,{text:l,kind:lo(l,t),start:c,end:d}})}function uo(e,t="yodl"){return co(e,t).map(({text:n,kind:o})=>o?`<span class="token-${o}">${ln(n)}</span>`:ln(n)).join("")}function cn(e,t="yodl"){return e.replace(/\n$/,"").split(`
`).map((o,i)=>`<div class="code-line"><span class="ln">${i+1}</span><span class="lt">${uo(o,t)||" "}</span></div>`).join("")}var Se=(e)=>document.getElementById(e),dt=(e)=>String(e).padStart(2,"0"),ut=(e,t)=>`./playground.html?mode=docs&chapter=${e}${t?`#${t}`:""}`;function F(e,t,n){let o=document.createElement(e);if(t)o.className=t;if(n!==void 0)o.textContent=n;return o}function dn(e){let t=new Ue,n,o,i,d=Se("docs-main"),l=Se("docs-content"),c=F("div","code-tooltip");c.id="docs-code-tooltip",c.setAttribute("role","tooltip"),c.hidden=!0,document.body.append(c);let w,P,k=()=>{clearTimeout(P),c.hidden=!0,w?.removeAttribute("aria-describedby"),w=void 0},ee=()=>{if(w===document.activeElement)return;clearTimeout(P),P=setTimeout(k,100)},h=(p)=>{if(k(),w=p,p.dataset.codeTooltip!==void 0)c.innerHTML=p.dataset.codeTooltip;else c.textContent=p.dataset.codeInfo;c.hidden=!1,p.setAttribute("aria-describedby",c.id);let a=p.getBoundingClientRect(),g=c.offsetWidth,m=c.offsetHeight;c.style.left=`${Math.max(8,Math.min(a.left,innerWidth-g-8))}px`,c.style.top=`${Math.max(8,a.top>m+12?a.top-m-8:Math.min(a.bottom+8,innerHeight-m-8))}px`},K=(p)=>p.target.closest("[data-code-info]");l.addEventListener("pointerover",(p)=>{let a=K(p);if(a&&a!==w)h(a)}),l.addEventListener("pointerout",(p)=>{if(w&&!w.contains(p.relatedTarget))ee()}),c.addEventListener("pointerenter",()=>clearTimeout(P)),c.addEventListener("pointerleave",ee),l.addEventListener("focusin",(p)=>{let a=K(p);if(a)h(a)}),l.addEventListener("focusout",k);let z=(p)=>{if(p.key==="Escape")k()};document.addEventListener("keydown",z),d.addEventListener("scroll",k,{passive:!0});function ue(){return n??=fetch("./book/chapters.json").then((p)=>{if(!p.ok)throw Error("The language guide could not be loaded.");return p.json()}).catch((p)=>{throw n=void 0,p})}function ie(p,a,g){let m=F("a");return m.href=ut(p,a),m.append(...typeof g==="string"?[g]:g),m.addEventListener("click",(f)=>{if(f.metaKey||f.ctrlKey||f.shiftKey||f.button!==0)return;f.preventDefault(),e.navigate(p,a)}),m}function pe(p,a){Se("docs-chapters").replaceChildren(...p.chapters.map((g,m)=>{let f=ie(g.slug,void 0,[F("span",void 0,dt(m+1)),g.title]);if(g===a)f.setAttribute("aria-current","page");return f})),Se("docs-version").textContent=`Yodl ${p.version} · ${p.revision}`,Se("docs-toc").replaceChildren(...a.headings.filter((g)=>g.level>1&&g.level<4).map((g)=>{let m=ie(a.slug,g.id,g.title);return m.className=`toc-level-${g.level}`,m})),D()}function D(){i?.disconnect();let p=Array.from(Se("docs-toc").querySelectorAll("a"));if(!p.length||typeof IntersectionObserver>"u")return;i=new IntersectionObserver((a)=>{for(let g of a)if(g.isIntersecting)for(let m of p)if(m.href.endsWith(`#${g.target.id}`))m.setAttribute("aria-current","location");else m.removeAttribute("aria-current")},{root:d,rootMargin:"0px 0px -70% 0px"});for(let a of Array.from(l.querySelectorAll("h2[id], h3[id]")))i.observe(a)}function Y(p,a){k();let g=p.chapters.indexOf(a),m=F("p","docs-meta",`Chapter ${dt(g+1)} of ${dt(p.chapters.length)}`),f=F("article");f.innerHTML=a.html;let L=[m,f],T=st[a.slug]??[];if(T.length){let te=F("section","practice");te.append(F("p","section-label","Practice in the tour"));for(let s of T){let x=F("button");x.type="button",x.append(F("strong",void 0,s.title),F("span",void 0,"→")),x.addEventListener("click",()=>e.openLesson(s.id)),te.append(x)}L.push(te)}let M=p.chapters[g-1],A=p.chapters[g+1],W=F("nav","page-navigation");W.setAttribute("aria-label","Previous and next chapters");let _=(te,s)=>te?ie(te.slug,void 0,[F("small",void 0,s),te.title]):F("span");W.append(_(M,"← Previous"),_(A,"Next →"));let re=F("footer","article-footer"),se=F("a",void 0,"Edit this page ↗");se.href=`https://github.com/nathsou/yodl/edit/main/book/src/${a.slug}.md`,re.append(se,F("span",void 0,"Examples compile locally in your browser.")),L.push(W,re),l.replaceChildren(...L),l.className="docs-content",J(p,a);for(let te of a.examples)r(a,te)}function J(p,a){for(let g of Array.from(l.querySelectorAll("article a[href]"))){let m=g.getAttribute("href"),f=/^#(.+)$/.exec(m),L=/^\.?\/?([\w-]+)\.html(?:#(.+))?$/.exec(m),T=L&&p.chapters.find((W)=>W.slug===L[1]);if(!f&&!T)continue;let M=f?a.slug:T.slug,A=f?f[1]:L[2];g.href=ut(M,A),g.addEventListener("click",(W)=>{if(W.metaKey||W.ctrlKey||W.shiftKey||W.button!==0)return;W.preventDefault(),e.navigate(M,A)})}}function r(p,a){let g=l.querySelector(`#${CSS.escape(a.id)}`);if(!g||!a.live)return;let m=g.querySelector('[data-action="compile"]');g.querySelector('[data-action="playground"]').onclick=()=>e.openExample(p,a,a.source,C(g)??a.stage);let f=async(L)=>{let T=R(g,a,L,f),M=T.querySelector(".example-status");M.dataset.state="",M.firstChild.textContent="● Compiling · ",m.disabled=!0;let A=await t.compile(a.id,{source:a.source,path:a.path,files:a.files,stage:L});if(m.disabled=!1,!A||!g.isConnected)return;let W=T.querySelector(".example-output-body");if(A.error!==void 0){let _=a.expect==="error";M.dataset.state=_?"expected":"error",M.firstChild.textContent=_?"● Expected compiler error · ":"● Compilation failed · ";let re=F("pre","diagnostic",A.error);re.tabIndex=0,W.replaceChildren(re)}else{M.dataset.state="success",M.firstChild.textContent="● Compiled · ",M.title=`${Math.round(A.duration)} ms · Yodl ${b}`;let _=F("div","code-lines");_.tabIndex=0,_.innerHTML=cn(A.output??"",X[L].language),W.replaceChildren(_)}};m.onclick=()=>void f(C(g)??a.stage)}let b="",C=(p)=>p.querySelector(".example-output select")?.value;function R(p,a,g,m){let f=p.querySelector(".example-output");if(f)return f.hidden=!1,f;f=F("div","example-output");let L=F("div","example-output-header"),T=F("span","example-status");T.append(document.createTextNode("● Compiled · "));let M=F("select");M.setAttribute("aria-label","Compiler output stage");for(let[_,re]of Object.entries(X)){if(_==="test"&&a.stage!=="test")continue;let se=new Option(re.label,_);if(se.disabled=a.unsupported.includes(_),se.disabled)se.text+=" (unavailable)";M.add(se)}M.value=g,M.title=X[g].description,M.onchange=()=>{M.title=X[M.value].description,m(M.value)};let A=F("span","stage-select");A.append(M),T.append(A);let W=F("button",void 0,"Hide");return W.type="button",W.onclick=()=>{f.hidden=!0},L.append(T,W),f.append(L,F("div","example-output-body")),p.append(f),f}function E(p){let a=p?l.querySelector(`#${CSS.escape(p)}`):null;if(a){if(a.scrollIntoView(),a.hasAttribute("data-code-info"))a.focus({preventScroll:!0})}else d.scrollTop=0}return{load:ue,async show(p,a){let g=Se("docs-loading"),m;try{g.hidden=!1,g.textContent="Loading the language guide…",m=await ue()}catch(T){g.textContent=`${T.message} Check your connection and reload the page.`;return}g.hidden=!0,b=m.version;let f=m.chapters.find((T)=>T.slug===p)??m.chapters[0],L=f!==o;if(L){if(o)for(let T of o.examples)t.cancel(T.id);if(o=f,pe(m,f),Y(m,f),document.title=`${f.title} · Yodl`,Se("docs-current").textContent=`${dt(m.chapters.indexOf(f)+1)} · ${f.title}`,matchMedia("(max-width: 820px)").matches)Se("chapter-menu").open=!1}if(L||a)E(a);return f},get current(){return o},dispose(){k(),document.removeEventListener("keydown",z),c.remove(),t.dispose()}}}var Me=(e)=>document.getElementById(e);function un(e){let t=Me("search-dialog"),n=Me("search-input"),o=Me("search-results"),i=Me("search-status"),d,l,c=e.lessons.map((h,K)=>({title:h.title,where:`Tour · Lesson ${String(K+1).padStart(2,"0")}`,excerpt:h.intro,text:[h.title,h.topic,h.intro,...h.concepts,h.observe,h.challenge].join(" "),go:()=>e.openLesson(h.id)}));async function w(){if(d)return!0;try{return await(l??=fetch("./book/search.json").then((h)=>{if(!h.ok)throw Error("Search unavailable");return h.json()}).then((h)=>{d=h}).finally(()=>{l=void 0})),!0}catch{return!1}}async function P(){let h=n.value.toLowerCase().trim();i.textContent=h?"Searching…":"Type to search the guide and the tour.";let K=await w();if(n.value.toLowerCase().trim()!==h)return;if(o.replaceChildren(),!h)return;let z=h.split(/\s+/),ue=(d??[]).map((D)=>({title:D.title,where:`Docs · ${D.chapter}`,excerpt:D.text,text:`${D.title} ${D.text}`,go:()=>e.openDoc(D.slug,D.id)})),ie=[...c,...ue].filter((D)=>z.every((Y)=>D.text.toLowerCase().includes(Y))).sort((D,Y)=>Number(Y.title.toLowerCase().includes(h))-Number(D.title.toLowerCase().includes(h))).slice(0,30),pe=K?"":" The guide index could not load; showing lessons only.";i.textContent=(ie.length?`${ie.length} result${ie.length===1?"":"s"}`:"No results. Try a concept, operator, or built-in name.")+pe;for(let D of ie){let Y=document.createElement("a");Y.href="#",Y.addEventListener("click",(R)=>{R.preventDefault(),t.close(),D.go()});let J=document.createElement("strong");J.textContent=D.title;let r=document.createElement("small");r.textContent=D.where;let b=document.createElement("span"),C=Math.max(0,D.excerpt.toLowerCase().indexOf(z[0])-50);b.textContent=`${C?"…":""}${D.excerpt.slice(C,C+160)}${D.excerpt.length>C+160?"…":""}`,Y.append(J,r,b),o.append(Y)}}let k=()=>{if(!t.open)t.showModal();n.focus(),n.select(),P()};Me("search-open").addEventListener("click",k),Me("search-close").addEventListener("click",()=>t.close()),n.addEventListener("input",()=>void P()),t.addEventListener("click",(h)=>{if(h.target===t)t.close()}),t.addEventListener("keydown",(h)=>{let K=Array.from(o.querySelectorAll("a")),z=K.indexOf(document.activeElement);if(h.key==="ArrowDown")h.preventDefault(),K[Math.min(K.length-1,z+1)]?.focus();if(h.key==="ArrowUp")if(h.preventDefault(),z<=0)n.focus();else K[z-1].focus();if(h.key==="Enter"&&document.activeElement===n)K[0]?.click()});let ee=/Mac|iPhone|iPad/.test(navigator.platform);return Me("search-shortcut").textContent=ee?"⌘K":"Ctrl K",document.addEventListener("keydown",(h)=>{let K=h.target;if((h.metaKey||h.ctrlKey)&&h.key.toLowerCase()==="k"){h.preventDefault(),k();return}if(h.key==="/"&&!h.metaKey&&!h.ctrlKey&&!K.closest('input, textarea, select, [contenteditable="true"], .monaco-editor')&&!document.querySelector("dialog[open]"))h.preventDefault(),k()}),{open:k}}class Pt{id=0;pending=new Map;worker;onDiagnostics=()=>{};onError=()=>{};constructor(e){this.worker=e??new Worker(new URL("./lsp-worker-ag08b16w.js",import.meta.url),{type:"module"}),this.worker.onmessage=(t)=>{let n=t.data;if(n.id!==void 0){let o=this.pending.get(n.id);if(!o)return;if(this.pending.delete(n.id),clearTimeout(o.timer),n.error)o.reject(Error(n.error.message));else o.resolve(n.result)}else if(n.method==="textDocument/publishDiagnostics")this.onDiagnostics(n.params.uri,n.params.diagnostics,n.params.version);else if(n.method==="window/logMessage"&&n.params.type===1)this.onError(n.params.message)},this.worker.onerror=(t)=>{this.fail(Error(t.message||"Language worker failed")),this.onError(t.message||"Language worker failed")}}request(e,t={},n){let o=++this.id,i;return new Promise((l,c)=>{if(n?.isCancellationRequested){l(null);return}let w=setTimeout(()=>{this.pending.delete(o),c(Error(`Language service timed out: ${e}`))},30000);this.pending.set(o,{resolve:l,reject:c,timer:w}),i=n?.onCancellationRequested(()=>{let P=this.pending.get(o);if(P)this.pending.delete(o),clearTimeout(P.timer),P.resolve(null),this.notify("$/cancelRequest",{id:o})}),this.worker.postMessage({jsonrpc:"2.0",id:o,method:e,params:t})}).finally(()=>i?.dispose())}notify(e,t){this.worker.postMessage({jsonrpc:"2.0",method:e,params:t})}fail(e){for(let t of this.pending.values())clearTimeout(t.timer),t.reject(e);this.pending.clear()}dispose(){this.fail(Error("Language client disposed")),this.worker.terminate()}}var Ve=(e)=>`yodl:///workspace/${e.split("/").map(encodeURIComponent).join("/")}`,_e=(e)=>e.startsWith("yodl:///workspace/")?e.slice(18).split("/").map(decodeURIComponent).join("/"):e,he=(e)=>({line:e.lineNumber-1,character:e.column-1}),pn=(e)=>({start:he({lineNumber:e.startLineNumber,column:e.startColumn}),end:he({lineNumber:e.endLineNumber,column:e.endColumn})}),ge=(e)=>({startLineNumber:e.start.line+1,startColumn:e.start.character+1,endLineNumber:e.end.line+1,endColumn:e.end.character+1});class Rt{monaco;open;problems;client;models=new Map;uris=new Map;listeners=new Map;registrations=[];ready;epoch=0;errors=new Map;model(e){return this.models.get(e.startsWith("yodl-builtin:")?e:Ve(e))}constructor(e,t,n,o,i=new Pt){this.monaco=e;this.open=t;this.problems=n;this.client=i,this.client.onError=o,this.ready=i.request("initialize",{capabilities:{general:{positionEncodings:["utf-16"]}}}).then((d)=>(i.notify("initialized",{}),d)),i.onDiagnostics=(d,l,c)=>{let w=this.models.get(d);if(c!==void 0&&w&&c!==w.getVersionId())return;if(this.errors.set(d,l),w)this.markers(w,l);this.problems([...this.errors].flatMap(([P,k])=>k.map((ee)=>({...ee,uri:_e(P)}))))},this.register(),this.registrations.push(e.editor.registerEditorOpener({openCodeEditor:(d,l,c)=>{let w=e.editor.getModel(l),P=this.uris.get(w);if(!P)return!1;return this.open(_e(P),c),!0}}))}markers(e,t){this.monaco.editor.setModelMarkers(e,"yodl",t.map((n)=>({...ge(n.range),message:n.message,code:n.code,source:"yodl",severity:n.severity===2?this.monaco.MarkerSeverity.Warning:this.monaco.MarkerSeverity.Error,relatedInformation:n.relatedInformation?.map((o)=>({resource:this.monaco.Uri.parse(o.location.uri),...ge(o.location.range),message:o.message}))})))}attach(e,t){let n=t.startsWith("yodl-builtin:")?t:Ve(t);if(this.uris.get(e)===n)return;if(this.uris.has(e))this.detach(e);this.uris.set(e,n),this.models.set(n,e),this.ready.then(()=>{if(this.uris.get(e)===n)this.client.notify("textDocument/didOpen",{textDocument:{uri:n,languageId:"yodl",version:e.getVersionId(),text:e.getValue()}})}),this.listeners.set(e,[e.onDidChangeContent(()=>{this.ready.then(()=>{if(this.uris.get(e)===n)this.client.notify("textDocument/didChange",{textDocument:{uri:n,version:e.getVersionId()},contentChanges:[{text:e.getValue()}]})})}),e.onWillDispose(()=>this.detach(e))]),this.markers(e,this.errors.get(n)??[])}detach(e){let t=this.uris.get(e);for(let n of this.listeners.get(e)??[])n.dispose();if(this.listeners.delete(e),this.uris.delete(e),t)this.models.delete(t),this.errors.delete(t),this.ready.then(()=>this.client.notify("textDocument/didClose",{textDocument:{uri:t}}));this.monaco.editor.setModelMarkers(e,"yodl",[])}async workspace(e,t,n){let o=++this.epoch;this.attach(t,n),await this.ready;let i=Object.fromEntries(Object.entries(e).map(([l,c])=>[Ve(l),c]));await this.client.request("yodl/setFiles",{files:i});let d=await this.client.request("yodl/dependencies",{uri:Ve(n)});if(o!==this.epoch)return;return Object.fromEntries(Object.entries(d).map(([l,c])=>[_e(l),c]))}async query(e,t,n,o){let i=this.uris.get(e),d=e.getVersionId();if(!i)return null;await this.ready;let l=await this.client.request(`textDocument/${t}`,{textDocument:{uri:i},...n},o);return this.uris.get(e)===i&&e.getVersionId()===d?l:null}async ensure(e){if(this.models.has(e))return this.models.get(e);let t=await this.client.request("yodl/source",{uri:e});if(t===null)return;if(this.models.has(e))return this.models.get(e);let n=this.monaco.editor.createModel(t,"yodl",this.monaco.Uri.parse(e));return this.attach(n,_e(e)),this.open(_e(e),void 0),n}async locations(e){if(!e)return[];return(await Promise.all((Array.isArray(e)?e:[e]).map(async(t)=>{let n=await this.ensure(t.uri);return n?{uri:n.uri,range:ge(t.range)}:null}))).filter(Boolean)}async edits(e){if(!e?.changes)return;let t=[];for(let[n,o]of Object.entries(e.changes)){let i=await this.ensure(n);if(!i)return;for(let d of o)t.push({resource:i.uri,versionId:i.getVersionId(),textEdit:{range:ge(d.range),text:d.newText}})}return{edits:t}}register(){let e=this.monaco.languages,t=(o,i)=>this.registrations.push(e[o]("yodl",i));t("registerHoverProvider",{provideHover:async(o,i,d)=>{let l=await this.query(o,"hover",{position:he(i)},d);return l?{range:l.range&&ge(l.range),contents:[{value:l.contents.value}]}:null}});for(let[o,i]of[["Definition","definition"],["Declaration","declaration"],["TypeDefinition","typeDefinition"]])t(`register${o}Provider`,{[`provide${o}`]:async(d,l,c)=>this.locations(await this.query(d,i,{position:he(l)},c))});t("registerReferenceProvider",{provideReferences:async(o,i,d,l)=>this.locations(await this.query(o,"references",{position:he(i),context:d},l))}),t("registerDocumentHighlightProvider",{provideDocumentHighlights:async(o,i,d)=>(await this.query(o,"documentHighlight",{position:he(i)},d)??[]).map((l)=>({...l,range:ge(l.range)}))});let n=(o)=>({...o,kind:o.kind-1,range:ge(o.range),selectionRange:ge(o.selectionRange),children:o.children?.map(n)});t("registerDocumentSymbolProvider",{provideDocumentSymbols:async(o,i)=>(await this.query(o,"documentSymbol",{},i)??[]).map(n)}),t("registerCompletionItemProvider",{triggerCharacters:[".",":","["],provideCompletionItems:async(o,i,d,l)=>{let c=await this.query(o,"completion",{position:he(i)},l),w=[0,18,0,1,2,3,4,7,5,8,9,12,13,15,17,28,19,20,21,23,16,14,6,10,11,24];return{incomplete:c?.isIncomplete??!1,suggestions:(c?.items??[]).map((P)=>({label:P.label,detail:P.detail,kind:w[P.kind??1],insertText:P.textEdit?.newText??P.label,range:P.textEdit?ge(P.textEdit.range):void 0}))}}}),t("registerSignatureHelpProvider",{signatureHelpTriggerCharacters:["(","[",",",":"],signatureHelpRetriggerCharacters:[","],provideSignatureHelp:async(o,i,d)=>{let l=await this.query(o,"signatureHelp",{position:he(i)},d);return l?{value:l,dispose(){}}:null}}),t("registerRenameProvider",{resolveRenameLocation:async(o,i,d)=>{try{let l=await this.query(o,"prepareRename",{position:he(i)},d);return l?{range:ge(l.range),text:l.placeholder}:{rejectReason:"No renameable symbol here"}}catch(l){return{rejectReason:l.message}}},provideRenameEdits:async(o,i,d,l)=>{try{return await this.edits(await this.query(o,"rename",{position:he(i),newName:d},l))}catch(c){return{edits:[],rejectReason:c.message}}}}),t("registerCodeActionProvider",{providedCodeActionKinds:["quickfix"],provideCodeActions:async(o,i,d,l)=>{let c=await this.query(o,"codeAction",{range:pn(i),context:{diagnostics:[],only:d.only?[d.only]:void 0}},l);return{actions:await Promise.all((c??[]).map(async(w)=>({title:w.title,kind:w.kind,isPreferred:w.isPreferred,edit:await this.edits(w.edit)}))),dispose(){}}}}),t("registerFoldingRangeProvider",{provideFoldingRanges:async(o,i,d)=>(await this.query(o,"foldingRange",{},d)??[]).map((l)=>({start:l.startLine+1,end:l.endLine+1}))}),t("registerSelectionRangeProvider",{provideSelectionRanges:async(o,i,d)=>(await this.query(o,"selectionRange",{positions:i.map(he)},d)??[]).map((c)=>{let w=[];while(c)w.push({range:ge(c.range)}),c=c.parent;return w})}),t("registerDocumentSemanticTokensProvider",{getLegend:()=>({tokenTypes:["namespace","type","class","parameter","variable","property","function","keyword","number","string","operator"],tokenModifiers:["declaration","readonly"]}),provideDocumentSemanticTokens:async(o,i,d)=>{let l=await this.query(o,"semanticTokens/full",{},d);return l?{data:Uint32Array.from(l.data)}:null},releaseDocumentSemanticTokens(){}})}dispose(){for(let e of[...this.uris.keys()])this.detach(e);for(let e of this.registrations)e.dispose();this.client.dispose()}}var ye=["source","output","simulation"],Ht=()=>({order:[...ye],visible:["source","output"],weights:{source:1,output:1,simulation:1},axis:"auto",sidebarPosition:"left",sidebarWidth:340}),$t=(e,t,n)=>Math.min(n,Math.max(t,e));function mn(e){let t=Ht();try{let n=JSON.parse(e??"null");if(!n||!Array.isArray(n.order)||n.order.length!==ye.length||new Set(n.order).size!==ye.length||n.order.some((o)=>!ye.includes(o)))return t;if(!Array.isArray(n.visible)||n.visible.some((o)=>!ye.includes(o))||new Set(n.visible).size!==n.visible.length)return t;if(!["auto","horizontal","vertical"].includes(n.axis)||!["left","right"].includes(n.sidebarPosition))return t;if(!Number.isFinite(n.sidebarWidth)||ye.some((o)=>!Number.isFinite(n.weights?.[o])||n.weights[o]<=0))return t;return{order:n.order,visible:n.visible,axis:n.axis,sidebarPosition:n.sidebarPosition,sidebarWidth:$t(n.sidebarWidth,200,600),weights:Object.fromEntries(ye.map((o)=>[o,$t(n.weights[o],0.1,10)]))}}catch{return t}}function pt(e,t,n){let o=e.order.filter((i)=>i!==t);return o.splice(e.order.indexOf(n),0,t),{...e,order:o}}function hn(e,t,n,o){let i=e.weights[t]+e.weights[n],d=$t(o,0.1,0.9);return{...e,weights:{...e.weights,[t]:i*d,[n]:i*(1-d)}}}var ve={source:"Source",output:"Output",simulation:"Simulation",sidebar:"Sidebar"},ne=(e)=>document.getElementById(e),Ye=(e,t,n)=>{let o=document.createElement("button");return o.type="button",o.title=e,o.setAttribute("aria-label",e),o.textContent=t,o.onclick=n,o};function gn(e){let t=mn(e.read("panes")),n="source",o,i,d=[],l=null,c=matchMedia("(max-width: 639px)"),w=matchMedia("(max-width: 1199px)"),P=matchMedia("(max-width: 819px)"),k=ne("editors"),ee=ne("editor-view"),h={source:ne("source-pane"),output:ne("output-pane"),simulation:ne("simulation-pane"),sidebar:ne("sidebar")};h.source.append(ne("compile-status").closest("footer"));let K=document.createElement("p");K.className="panes-empty",K.textContent="All panes are hidden. Use Layout to show a pane or reset the arrangement.";let z=ne("layout-menu"),ue=ne("layout-axis"),ie=ne("sidebar-position"),pe=new Map,D=new Map,Y=[],J=()=>t.axis==="vertical"||t.axis==="auto"&&w.matches,r=()=>e.save("panes",JSON.stringify(t)),b=()=>t.order.filter((s)=>t.visible.includes(s)),C=(s)=>{t=s,r(),A()};function R(){if(!o)return;h[o].classList.remove("pane-fullscreen");for(let[s,x]of d)s.inert=x;if(d=[],o=void 0,A(),l?.isConnected&&l.getClientRects().length)l.focus()}function E(s){if(o===s){R();return}R(),z.open=!1,a(s),l=document.activeElement,o=s,h[s].classList.add("pane-fullscreen"),d.push([h[s],h[s].inert]),h[s].inert=!1;let x=h[s];while(x.parentElement){for(let y of x.parentElement.children)if(y!==x&&y instanceof HTMLElement&&!(y instanceof HTMLDialogElement))d.push([y,y.inert]),y.inert=!0;if(x=x.parentElement,x===document.body)break}m(),D.get(s).querySelector('[data-action="fullscreen"]').focus(),e.changed()}function p(s,x){let y=!x&&h[s].contains(document.activeElement);if(o===s&&!x)R();if(C({...t,visible:x?[...new Set([...t.visible,s])]:t.visible.filter((B)=>B!==s)}),y)z.querySelector("summary").focus()}function a(s){if(o&&o!==s)R();if(n=s,!t.visible.includes(s))p(s,!0);else A()}function g(s){if(c.matches&&!o)a(s);else if(!t.visible.includes(s))p(s,!0)}function m(){for(let s of[...ye,"sidebar"]){let x=D.get(s),y=x.querySelector('[data-action="move"]');if(y.textContent=s==="sidebar"?t.sidebarPosition==="left"?"→":"←":J()?"↑":"←",y.disabled=s!=="sidebar"&&b().indexOf(s)<=0,s!=="sidebar"){let B=x.querySelector('[data-action="fullscreen"]');B.textContent=o===s?"↙":"⛶",B.title=`${o===s?"Restore":"Full screen"} ${ve[s]}`,B.setAttribute("aria-label",B.title),B.setAttribute("aria-pressed",String(o===s));let oe=x.querySelector('[data-action="later"]');oe.disabled=b().indexOf(s)===b().length-1,oe.textContent=J()?"↓":"→"}}}function f(s,x){let y=document.createElement("div");y.className="pane-controls",y.setAttribute("aria-label",`${ve[s]} pane controls`);let B=Ye(s==="sidebar"?"Move sidebar to the other side":`Move ${ve[s]} earlier`,"←",()=>{if(s==="sidebar")C({...t,sidebarPosition:t.sidebarPosition==="left"?"right":"left"});else{let oe=b(),fe=oe.indexOf(s);if(fe>0)C(pt(t,s,oe[fe-1]))}});if(B.dataset.action="move",y.append(B),s!=="sidebar"){let oe=Ye(`Move ${ve[s]} later`,"→",()=>{let ae=b(),it=ae.indexOf(s);if(it<ae.length-1)C(pt(t,s,ae[it+1]))});oe.dataset.action="later",y.append(oe);let fe=Ye(`Drag to move ${ve[s]}`,"⠿",()=>{});fe.className="pane-grip",fe.draggable=!0,fe.ondragstart=(ae)=>{i=s,ae.dataTransfer.effectAllowed="move",ae.dataTransfer.setData("text/plain",s)},fe.ondragend=()=>{i=void 0,h[s].classList.remove("pane-drop")},y.prepend(fe),x.ondragover=(ae)=>{if(i&&i!==s)ae.preventDefault(),ae.dataTransfer.dropEffect="move",h[s].classList.add("pane-drop")},x.ondragleave=()=>h[s].classList.remove("pane-drop"),x.ondrop=(ae)=>{if(ae.preventDefault(),h[s].classList.remove("pane-drop"),i&&i!==s)C(pt(t,i,s));i=void 0};let Be=Ye(`Full screen ${ve[s]}`,"⛶",()=>E(s));Be.dataset.action="fullscreen",y.append(Be)}y.append(Ye(`Hide ${ve[s]}`,"×",()=>{if(s==="sidebar")e.showSidebar(!1),A(),z.querySelector("summary").focus();else p(s,!1)})),x.append(y),D.set(s,y)}for(let s of["source","output"]){let x=document.createElement("div");x.className="pane-heading",x.textContent=ve[s],h[s].prepend(x),f(s,x)}f("simulation",h.simulation.querySelector(".panel-header"));let L=document.createElement("div");L.className="pane-heading",L.textContent="Sidebar",h.sidebar.prepend(L),f("sidebar",L);function T(s,x){let y=document.createElement("div");y.className="pane-resizer",y.tabIndex=0,y.setAttribute("role","separator"),y.inert=o!==void 0,y.setAttribute("aria-label",`Resize ${ve[s]} and ${ve[x]}`),y.setAttribute("aria-orientation",J()?"horizontal":"vertical"),y.setAttribute("aria-valuemin","10"),y.setAttribute("aria-valuemax","90");let B=()=>t.weights[s]/(t.weights[s]+t.weights[x]),oe=(Z)=>{t=hn(t,s,x,Z),M(),y.setAttribute("aria-valuenow",String(Math.round(B()*100))),e.changed()};oe(B());let fe=0,Be=0,ae=1;y.onpointerdown=(Z)=>{let je=h[s].getBoundingClientRect(),rt=h[x].getBoundingClientRect();fe=J()?Z.clientY:Z.clientX,Be=B(),ae=Math.max(1,J()?je.height+rt.height:je.width+rt.width),y.setPointerCapture(Z.pointerId),y.classList.add("dragging"),Z.preventDefault()},y.onpointermove=(Z)=>{if(y.hasPointerCapture(Z.pointerId))oe(Be+((J()?Z.clientY:Z.clientX)-fe)/ae)};let it=()=>{y.classList.remove("dragging"),r()};return y.onlostpointercapture=it,y.onpointerup=(Z)=>{if(y.hasPointerCapture(Z.pointerId))y.releasePointerCapture(Z.pointerId)},y.onkeydown=(Z)=>{let je=J()?"ArrowUp":"ArrowLeft",rt=J()?"ArrowDown":"ArrowRight";if(![je,rt,"Home","End"].includes(Z.key))return;Z.preventDefault(),oe(Z.key==="Home"?0.1:Z.key==="End"?0.9:B()+(Z.key===je?-0.05:0.05)),r()},y}function M(){let x=b().flatMap((y,B)=>[...B?["6px"]:[],`minmax(0, ${t.weights[y]}fr)`]).join(" ")||"1fr";k.style.gridTemplateColumns=J()?"minmax(0, 1fr)":x,k.style.gridTemplateRows=J()?x:"minmax(0, 1fr)"}function A(){let s=document.activeElement;if(!t.visible.includes(n))n=b()[0]??"source";for(let y of Y)y.remove();Y.length=0;let x=b();for(let y of t.order){let B=x.indexOf(y);if(h[y].hidden=B<0||c.matches&&y!==n,k.append(h[y]),B>=0&&B<x.length-1){let oe=T(y,x[B+1]);k.append(oe),Y.push(oe)}}k.append(K),K.hidden=x.length>0,k.dataset.axis=J()?"vertical":"horizontal",k.dataset.view=n,ee.dataset.sidebarPosition=t.sidebarPosition,ee.style.setProperty("--sidebar-width",`${t.sidebarWidth}px`),M(),ue.value=t.axis,ie.value=t.sidebarPosition;for(let[y,B]of pe)B.checked=y==="sidebar"?!e.sidebarHidden():t.visible.includes(y);for(let y of ye)ne(`${y==="simulation"?"simulation":y}-tab`).setAttribute("aria-pressed",String(n===y));if(ne("view-output").setAttribute("aria-pressed",String(t.visible.includes("output"))),ne("view-simulate").setAttribute("aria-pressed",String(t.visible.includes("simulation"))),m(),e.changed(),s?.isConnected&&!s.inert&&s.getClientRects().length)s.focus({preventScroll:!0})}for(let s of[...ye,"sidebar"]){let x=ne(`show-${s}`);pe.set(s,x),x.onchange=()=>{if(s==="sidebar")e.showSidebar(x.checked),A();else p(s,x.checked)}}ue.onchange=()=>C({...t,axis:ue.value}),ie.onchange=()=>C({...t,sidebarPosition:ie.value}),ne("reset-layout").onclick=()=>{R(),e.showSidebar(!0),C(Ht()),z.open=!1,z.querySelector("summary").focus()},document.addEventListener("pointerdown",(s)=>{if(!z.contains(s.target))z.open=!1});let W=()=>[...document.querySelectorAll(".quick-input-widget, .suggest-widget.visible, .find-widget.visible, .monaco-hover")].some((s)=>{let x=s.getBoundingClientRect();return x.width>0&&x.height>0&&getComputedStyle(s).visibility!=="hidden"});document.addEventListener("keydown",(s)=>{if(s.key!=="Escape")return;if(o&&!document.querySelector("dialog[open]")&&!W())s.preventDefault(),s.stopImmediatePropagation(),R();z.open=!1},!0);for(let s of[c,w,P])s.addEventListener("change",()=>{R(),A()});let _=ne("sidebar-resizer"),re=(s)=>{t={...t,sidebarWidth:Math.max(200,Math.min(600,s))},ee.style.setProperty("--sidebar-width",`${t.sidebarWidth}px`),_.setAttribute("aria-valuenow",String(t.sidebarWidth)),e.changed()},se=0,te=340;return _.onpointerdown=(s)=>{se=s.clientX,te=t.sidebarWidth,_.setPointerCapture(s.pointerId),s.preventDefault()},_.onpointermove=(s)=>{if(_.hasPointerCapture(s.pointerId))re(te+(s.clientX-se)*(t.sidebarPosition==="left"?1:-1))},_.onpointerup=(s)=>{if(_.hasPointerCapture(s.pointerId))_.releasePointerCapture(s.pointerId)},_.onlostpointercapture=r,_.onkeydown=(s)=>{if(!["ArrowLeft","ArrowRight","Home","End"].includes(s.key))return;s.preventDefault(),re(s.key==="Home"?200:s.key==="End"?600:t.sidebarWidth+(s.key==="ArrowLeft"?-20:20)*(t.sidebarPosition==="left"?1:-1)),r()},re(t.sidebarWidth),A(),{activate:a,reveal:g,sync:A,exitFullscreen:R}}var u=(e)=>document.getElementById(e),S=(e)=>u(e),xn="yodl-playground-v2:",Ot=!0;function He(e){try{return localStorage.getItem(xn+e)}catch{return Ot=!1,null}}function Re(e,t){try{localStorage.setItem(xn+e,t)}catch{Ot=!1}}function ke(e){let t=u("notice");t.textContent=e;let n=document.createElement("button");n.textContent="Dismiss",n.addEventListener("click",()=>{t.hidden=!0}),t.append(n),t.hidden=!1}function Le(e,t="idle"){u("compile-status").textContent=e,u("compile-status").dataset.state=t}var At=/Mac|iPhone|iPad/.test(navigator.platform);Qt(document.querySelector(".site-header"),()=>ct());en(document.querySelector(".accent-picker"),()=>ct());var kn=(e)=>e==="tour"?"tour":"playground",Dt=(e)=>`tour/${e.file}`,we=(e)=>e.split("/").at(-1),G="tour",Je,_t,H={...Ct};try{let e=JSON.parse(He("selection")??"null");if(ze(e))H=e}catch{}var N,po=()=>N?`shared:${N.code}`:"",O=()=>N?.entryPath??H.path,v,fn,qe=!1,de,Ge,le="",Ze="",Q=new Map,ht=new Map,xe=()=>de.getValue();function Oe(e){let t=e===O()?de:Q.get(e);if(!t)return;if(le)ht.set(le,v.input.saveViewState());le=e,v.input.setModel(t),v.input.updateOptions({readOnly:e!==O(),ariaLabel:`${e}${e===O()?", main source":", imported, read only"}`});let n=ht.get(e);if(n)v.input.restoreViewState(n);Ft(),v.input.layout()}function Ft(){let e=le!==O(),t=Q.size>0;u("source-files").hidden=!t,u("editors").dataset.imports=String(t),u("input-filename").textContent=we(le||O()),u("input-filename").title=le,u("source-kind").textContent=e?"Imported · read only":"",u("source-kind").hidden=!e,u("draft-badge").hidden=e||!de||xe()===et(),S("reset-button").disabled=e,u("source-files").replaceChildren(...[O(),...Q.keys()].map((n)=>{let o=document.createElement("button");return o.textContent=we(n),o.title=n===O()?`${n} · compile and simulation target`:`${n} · imported, read only`,o.setAttribute("aria-pressed",String(n===le)),o.onclick=()=>Oe(n),o}))}function Sn(e){let t=Object.entries(e).filter(([o])=>o!==O()&&o.endsWith(".yodl")),n=new Set(t.map(([o])=>o));if(le!==O()&&!n.has(le))Oe(O());for(let[o,i]of Q)if(!n.has(o))i.dispose(),Q.delete(o),ht.delete(o);for(let[o,i]of t){let d=Q.get(o);if(!d){let l=q.editor.createModel(i,"yodl");Q.set(o,l),Ge?.attach(l,o),l.onDidChangeContent(()=>{if(!qe)xt()})}else if(d.getValue()!==i)d.setValue(i)}Ft()}function mo(){le="",ht.clear(),v.input.setModel(de);for(let e of Q.values())e.dispose();Q.clear(),Oe(O())}var ft=0,be="",yt=-1,En=new Ue,qt=0,yn,bt=()=>({...De,...N?.files,...Object.fromEntries([...Q].filter(([e])=>!e.startsWith("yodl-builtin:")).map(([e,t])=>[e,t.getValue()]))});async function Cn(){let e=++qt;try{let t=await Ge?.workspace(bt(),de,O());if(e===qt&&t)Sn(t)}catch(t){ke(`Language service: ${t.message}`)}}function ho(){++qt,clearTimeout(yn),yn=setTimeout(Cn,150)}var Ln=(e)=>/\btest\s+(?:"|for\b)/.test(e),$e=an({request:()=>({source:xe(),path:O(),files:bt()}),setStatus:Le}),Tn=0,Nt=0,Ce=null,go=`// Start a new circuit here.
module Top(a: bool) -> (q: bool) {
    q = a
}
`,wt=(e)=>De[e]??go,et=()=>N?N.source:wt(H.path);function fo(e){let t=2166136261;for(let n=0;n<e.length;n++)t^=e.charCodeAt(n),t=Math.imul(t,16777619);return(t>>>0).toString(36)}var Mn=(e)=>`draft:${e}:${fo(wt(e))}`,tt=()=>po()||Mn(H.path),yo=12;function Pn(){try{let e=JSON.parse(He("drafts")??"[]");return Array.isArray(e)?e.filter((t)=>typeof t?.key==="string"&&typeof t.label==="string"&&typeof t.updated==="number"):[]}catch{return[]}}function bo(){if(H.mode!=="examples"&&!N)return;let e=tt(),t=Pn(),n=t.findIndex((i)=>i.key===e);if(xe()===et()){if(n<0)return;t.splice(n,1)}else{if(n===0&&Date.now()-t[0].updated<30000)return;if(n>=0)t.splice(n,1);let i=N?`Shared · ${we(N.entryPath??N.path)}`:H.path===me?"scratch.yodl":we(H.path);t.unshift({key:e,path:H.path,label:i,updated:Date.now(),...N?{shared:!0}:{}})}Re("drafts",JSON.stringify(t.slice(0,yo))),$n()}function wo(e){let t=Math.floor((Date.now()-e)/60000);if(t<1)return"Just now";if(t<60)return`${t} min ago`;let n=Math.floor(t/60);if(n<24)return`${n} h ago`;let o=Math.floor(n/24);return o===1?"Yesterday":o<14?`${o} days ago`:new Date(e).toLocaleDateString()}function Xe(){if(!de)return;if(Re(tt(),xe()),!N)Re("selection",JSON.stringify(H));u("save-status").textContent=Ot?"Draft saved locally":"Draft not saved · storage unavailable",u("draft-badge").hidden=le!==O()||xe()===et(),bo()}var Ae=()=>j.findIndex((e)=>Dt(e)===H.path),vo=(e)=>Object.entries(st).find(([,t])=>t.some((n)=>n.id===e))?.[0],Rn=new Map,xo=(e)=>{let t=e.replace(/^\d+_/,"").replaceAll("_"," ");return t[0].toUpperCase()+t.slice(1)},Qe=(e)=>String(e).padStart(2,"0");function vt(){let e=Ae(),t=j[e];if(!t)return;let n=document.createElement("span");n.className="lesson-prefix",n.textContent="Tour · ",u("lesson-position").replaceChildren(n,`Lesson ${Qe(e+1)} of ${j.length}`),jt(),u("lesson-topic").textContent=t.topic,u("lesson-title").textContent=t.title,u("lesson-intro").textContent=t.intro,u("lesson-observe").textContent=t.observe,u("lesson-challenge").textContent=t.challenge,u("lesson-concepts").replaceChildren(...t.concepts.map((l,c)=>{let w=document.createElement("li"),P=document.createElement("span");P.className="n",P.textContent=Qe(c+1);let k=document.createElement("span");return k.textContent=l,w.append(P,k),w})),S("suggested-stage").textContent=`Open ${X[t.stage].label} →`;let o=vo(t.id);if(u("lesson-reference").hidden=!o,o){let l=u("related-docs");l.textContent=Rn.get(o)??xo(o),l.href=ut(o),l.onclick=(c)=>{c.preventDefault(),V({section:"docs",chapter:o})}}let i=j[e-1],d=j[e+1];S("previous-lesson").disabled=!i,u("previous-title").textContent=i?.title??"",S("next-lesson").disabled=!1,u("next-title").textContent=d?.title??"Explore the Playground";for(let[l,c]of Array.from(u("lesson-progress").children).entries())if(l===e)c.setAttribute("aria-current","step");else c.removeAttribute("aria-current");for(let[l,c]of Array.from(u("lesson-list").children).entries())if(l===e)c.setAttribute("aria-current","step");else c.removeAttribute("aria-current")}function ko(){u("lesson-progress").style.setProperty("--lessons",String(j.length)),u("lesson-progress").replaceChildren(...j.map((e,t)=>{let n=document.createElement("button");return n.type="button",n.title=`${Qe(t+1)} · ${e.title}`,n.setAttribute("aria-label",`Lesson ${t+1}: ${e.title}`),n.onclick=()=>void V({section:"tour",lesson:e.id}),n})),u("lesson-list").replaceChildren(...j.map((e,t)=>{let n=document.createElement("button");return n.type="button",n.innerHTML='<span class="n"></span><span><strong></strong><small></small></span>',n.querySelector(".n").textContent=Qe(t+1),n.querySelector("strong").textContent=e.title,n.querySelector("small").textContent=e.topic,n.onclick=()=>{nt(!1),V({section:"tour",lesson:e.id})},n}))}function nt(e){if(u("lesson-list-scrim").hidden=!e,S("lesson-list-button").setAttribute("aria-expanded",String(e)),e)u("lesson-list").querySelector("[aria-current]")?.scrollIntoView({block:"nearest"})}function So(e){let t=De[e]??"";return`${t.split(`
`).length} lines${t.includes("@simulation")?" · simulation":""}`}function Wt(){jt(),u("example-list").replaceChildren(...Ke.map((e)=>{let t=document.createElement("button");t.type="button",t.className="entry";let n=!N&&H.path===e;if(n)t.setAttribute("aria-current","true");let o=document.createElement("span");o.className="entry-name",o.textContent=we(e).replace(/\.yodl$/,"");let i=document.createElement("span");return i.className="entry-note",i.textContent=n?we(e):So(e),t.append(o,i),t.onclick=()=>{Re("last:examples",e),Ee(!1),V({section:"playground",path:e})},t})),$n()}function $n(){let e=Pn().filter((t)=>t.shared||(t.path===me||Ke.includes(t.path))&&t.key===Mn(t.path));u("drafts-empty").hidden=e.length>0,u("draft-list").replaceChildren(...e.map((t)=>{let n=document.createElement("button");if(n.type="button",n.className="entry draft",t.key===tt()&&(H.mode==="examples"||N))n.setAttribute("aria-current","true");let o=document.createElement("span");o.className="entry-name",o.textContent=t.label;let i=document.createElement("span");return i.className="entry-note",i.textContent=wo(t.updated),n.append(o,i),n.onclick=()=>{if(Ee(!1),t.shared){let d=t.key.slice(7);try{V({section:"shared",shared:Wn(Lt(`#code=${d}`),d)})}catch(l){ke(l.message)}}else V({section:"playground",path:t.path})},n}))}var Eo=()=>H.mode==="tour"?j[Ae()]?.stage:void 0,Te=matchMedia("(max-width: 819px)"),vi=matchMedia("(max-width: 639px)"),Ne=He("sidebar")==="hidden";function Bt(){let e=u("editor-view");e.dataset.sidebar=Ne?"hidden":"shown";let t=S("sidebar-toggle");t.setAttribute("aria-expanded",String(!Ne));let n=G==="tour"?"lesson":"examples";t.title=Ne?`Show ${n}`:`Hide ${n}`,t.setAttribute("aria-label",t.title)}function Hn(e){Ne=e,Re("sidebar",e?"hidden":"shown"),Bt()}function Ee(e){let t=u("editor-view");if(t.dataset.sheet==="open"===e)return;if(t.dataset.sheet=e?"open":"closed",S("context-toggle").setAttribute("aria-expanded",String(e)),u("sidebar").inert=Te.matches&&!e,e&&Te.matches)u(G==="tour"?"guide-body":"library").scrollTop=0}function jt(){let e=u("context-label");if(G==="tour"){let t=Ae(),n=document.createElement("small");n.textContent=`${Qe(t+1)}/${j.length}  `,e.replaceChildren(n,j[t]?.title??"")}else e.textContent=N?"Examples & drafts · shared circuit":"Examples & drafts";S("context-toggle").title=G==="tour"?"Show or hide the lesson":"Show or hide examples and drafts"}new ResizeObserver(()=>Kt()).observe(u("output-view-switch").parentElement);Te.addEventListener("change",()=>{u("sidebar").inert=Te.matches&&u("editor-view").dataset.sheet!=="open"});function An(){let e=H.stage==="test"||de!==void 0&&Ln(xe()),t=Eo();u("stage-tabs").replaceChildren(...Object.keys(X).filter((o)=>o!=="test"||e).map((o)=>{let i=document.createElement("button");if(i.type="button",i.className="stage-tab",i.dataset.stage=o,i.title=X[o].description,i.setAttribute("aria-pressed",String(o===H.stage)),i.append(X[o].short),o===t&&o!==H.stage){let d=document.createElement("span");d.className="suggested",d.title="Suggested for this lesson",i.append(d)}return i.onclick=()=>zt(o),i}));let n=u("stage-select");n.replaceChildren(...Array.from(u("stage-tabs").children).map((o)=>{let i=o.dataset.stage;return new Option(`${X[i].label}${i===t?" · suggested":""}`,i)})),n.value=H.stage,n.title=X[H.stage].description,Kt()}function Kt(){let e=u("output-view-switch").parentElement,t=u("stage-tabs").scrollWidth+u("output-view-switch").offsetWidth+24;if(e.clientWidth>0&&t>e.clientWidth)e.dataset.compact="";else delete e.dataset.compact}function Fe(e,t=!1){if(t)ot.activate(e);v?.output.layout()}function gt(){let e=X[H.stage];if(u("stage-description").textContent=e.description,u("stage-description").title=e.description,v)q.editor.setModelLanguage(v.output.getModel(),e.language);An()}function In(){Fe("output"),Ft(),vt(),Wt(),u("related-docs-menu").hidden=!N?.origin,gt()}function It(){ot.exitFullscreen();for(let t of Array.from(document.querySelectorAll(".mode-switch button")))t.setAttribute("aria-pressed",String(t.dataset.mode===G));let e=G!=="docs";if(u("editor-view").hidden=!e,u("docs-view").hidden=e,u("editor-view").dataset.section=G,u("guide").hidden=G!=="tour",u("library").hidden=G!=="playground",Bt(),jt(),e)document.title=G==="tour"?"Tour · Yodl":"Playground · Yodl",v?.input.layout(),v?.output.layout();else $e.stop()}function Dn(){if(u("problems").hidden=!0,Ce=null,!de)return;for(let e of[de,...Q.values()])q.editor.setModelMarkers(e,"yodl",[])}function xt(){if(En.cancel("playground"),$e.stop(),ft++,ho(),Nt=++Tn,Dn(),S("copy-output").disabled=!0,S("output-download").disabled=!0,S("download-output").disabled=!0,Le(be?"Source changed · output is out of date":"Ready to compile"),u("stage-tabs").querySelector('[data-stage="test"]')!==null!==(H.stage==="test"||Ln(xe())))An()}function bn(e,t){if(v)Xe();if(N=t,H=e,vt(),Wt(),!v)return;mo(),$e.clear(),qe=!0,v.input.setValue(He(tt())??N?.source??wt(H.path)),qe=!1,v.input.setScrollTop(0),v.output.setValue(""),be="",yt=-1,In(),Xe(),xt(),Pe()}function zt(e){if(H.stage=e,!v){gt();return}$e.clearFrame(),v.output.setValue(""),be="",gt(),Fe("output"),Xe(),xt(),Pe()}function We(e){ot.activate(e),u("editors").dataset.view=e,S("source-tab").setAttribute("aria-pressed",String(e==="source")),S("output-tab").setAttribute("aria-pressed",String(e==="output")),v?.input.layout(),v?.output.layout()}function Co(e,t=[]){Fe("output"),u("problems").hidden=!1,u("error-message").textContent=e;let n=t.find((o)=>o.range&&(o.uri===O()||Q.has(o.uri)));Ze=n?.uri??O(),Ce=n?Ie(n,Ze):null,S("jump-error").hidden=Ce===null;for(let o of[O(),...Q.keys()]){let i=o===O()?de:Q.get(o),d=t.flatMap((l)=>{let c=Ie(l,o);return c?[{...i.validateRange(c),message:l.message,code:l.code,severity:l.severity===2?q.MarkerSeverity.Warning:q.MarkerSeverity.Error}]:[]});q.editor.setModelMarkers(i,"yodl",d)}Le(be?"Compilation failed · showing previous output":"Compilation failed · check diagnostics","error")}function Lo(e){let t=e.find((n)=>n.range&&(n.uri===O()||Q.has(n.uri)));u("problems").hidden=e.length===0,u("error-message").replaceChildren(...e.map((n)=>{let o=document.createElement("button");o.type="button",o.className="diagnostic",o.textContent=`${n.uri?`${we(n.uri)}:${(n.range?.start.line??0)+1}:${(n.range?.start.character??0)+1}: `:""}${n.message}${n.code?` [${n.code}]`:""}${n.notes?.length?`
${n.notes.join(`
`)}`:""}`;let i=Ie(n,n.uri??O());return o.disabled=!i||n.uri!==O()&&!Q.has(n.uri),o.onclick=()=>{if(!i)return;We("source"),Oe(n.uri??O()),v.input.setSelection(i),v.input.revealRangeInCenter(i),v.input.focus()},o})),Ze=t?.uri??O(),Ce=t?Ie(t,Ze):null,S("jump-error").hidden=Ce===null}async function Pe(){if(!v)return;$e.stop(),$e.clearFrame();let e=++Tn;Nt=e;let t=ft;Dn(),Le("Compiling…","loading");let n=await En.compile("playground",{source:xe(),path:O(),stage:H.stage,files:bt()});if(!n||e!==Nt)return;if(n.sources)Sn(n.sources);if(n.error!==void 0){Co(n.error,n.diagnostics);return}be=n.output??"",yt=t,v.output.setValue(be),gt(),Fe("output"),S("copy-output").disabled=!be,S("output-download").disabled=!be,S("download-output").disabled=!be,Le(`Compiled · ${Math.round(n.duration)} ms`,"success")}function _n(e,t){let n=URL.createObjectURL(new Blob([t],{type:"text/plain;charset=utf-8"})),o=document.createElement("a");o.href=n,o.download=e,o.click(),setTimeout(()=>URL.revokeObjectURL(n),1000)}async function qn(e,t){try{await navigator.clipboard.writeText(e);let n=t.textContent;t.textContent="Copied",setTimeout(()=>{t.textContent=n},1800)}catch{if(ke("Clipboard access is unavailable. Select the text and use your browser’s Copy command."),t.id==="copy-share")u("share-url").select();else v.output.focus(),v.output.setSelection(v.output.getModel().getFullModelRange())}}function Nn(){if(yt===ft)_n(`${we(H.path).replace(/\.yodl$/,"")}.${X[H.stage].extension}`,be)}function kt(e){u("file-menu").hidden=!e,S("menu-button").setAttribute("aria-expanded",String(e))}function On(){if(!v)return;let e=new URL(location.href);e.search="";let t=Object.fromEntries(Object.entries(bt()).filter(([n,o])=>De[n]!==o));if(e.hash=`code=${lt({...H,source:xe(),files:t,entryPath:N?.entryPath,origin:N?.origin})}`,e.href.length>32000){ke("This circuit is too large for a reliable share link. Use Download source instead.");return}u("share-url").value=e.href,u("share-dialog").showModal(),u("share-url").select()}function Fn(){if(v&&le===O())u("reset-dialog").showModal()}function Wn(e,t){return{code:t,mode:e.mode,path:e.path,stage:e.stage,source:e.source,files:e.files??{},entryPath:e.entryPath,origin:e.origin}}function To(e){if(H.mode===e&&!N)return H.path;let t=He(`last:${e}`);if(ze({mode:e,path:t,stage:"write_firrtl"}))return t;return e==="tour"?Ct.path:me}function Mo(){let e=new URL(location.href);if(e.search="",e.hash="",G==="docs"){if(e.searchParams.set("mode","docs"),Je)e.searchParams.set("chapter",Je);if(_t)e.hash=_t}else if(N)e.hash=`code=${N.code}`;else if(G==="tour")e.searchParams.set("lesson",j[Ae()]?.id??j[0].id);else if(e.searchParams.set("mode","examples"),H.path!==me)e.searchParams.set("example",we(H.path).replace(/\.yodl$/,""));return e.href}function wn(e){let t=Mo();if(e==="none"||t===location.href)return;if(e==="push")history.pushState(null,"",t);else history.replaceState(null,"",t)}var vn=0;async function V(e,t="push"){let n=++vn;if(nt(!1),e.section==="docs"){G="docs",It(),Je=e.chapter,_t=e.anchor;let o=await St.show(e.chapter,e.anchor);if(n!==vn)return;if(Je=o?.slug??e.chapter,o)document.title=`${o.title} · Yodl`;wn(t);return}if(e.section==="shared")G=kn(e.shared.mode),It(),bn({mode:e.shared.mode,path:e.shared.path,stage:e.shared.stage},e.shared),ke("Shared circuit opened. Your existing lesson and example drafts are kept separately.");else{G=e.section,It();let o=G==="tour"?"tour":"examples",i=e.section==="tour"?j.find((c)=>c.id===e.lesson):void 0,d=e.section==="playground"&&e.path&&ze({mode:o,path:e.path,stage:"write_firrtl"})?e.path:i?Dt(i):To(o);if(!(!N&&H.mode===o&&H.path===d)){Re(`last:${o}`,d);let c=o==="tour"?j.find((w)=>Dt(w)===d).stage:"write_firrtl";bn({mode:o,path:d,stage:c})}else if(!v)vt(),Wt();if(e.section==="tour")u("guide-body").scrollTop=0}Ro(),wn(t)}function Bn(){let e=new URLSearchParams(location.search);if(location.hash.startsWith("#code="))try{let n=location.hash.slice(6);return{section:"shared",shared:Wn(Lt(location.hash),n)}}catch(n){ke(n.message)}if(e.get("mode")==="docs")return{section:"docs",chapter:e.get("chapter")??void 0,anchor:location.hash.slice(1)||void 0};let t=j.find((n)=>n.id===e.get("lesson"));if(t)return{section:"tour",lesson:t.id};if(e.get("mode")==="examples")return{section:"playground",path:Ke.find((o)=>we(o)===`${e.get("example")}.yodl`)??me};return{section:kn(H.mode)}}var St=dn({navigate:(e,t)=>void V({section:"docs",chapter:e,anchor:t}),openLesson:(e)=>void V({section:"tour",lesson:e}),openExample(e,t,n,o){let i={mode:"examples",path:me,stage:o,source:n,files:t.files,entryPath:t.path,origin:`${e.slug}.html#${t.id}`},d=lt(i);if(d.length>30000){ke("This example is too large for a reliable handoff. Copy the source instead.");return}V({section:"shared",shared:{...i,code:d}})}}),Po=un({lessons:j,openLesson:(e)=>void V({section:"tour",lesson:e}),openDoc:(e,t)=>void V({section:"docs",chapter:e,anchor:t})});function Ro(){return fn??=$o().catch((e)=>{fn=void 0,Le("Could not load the editor","error"),u("input-panel").textContent="The editor could not load. Check your connection and reload the page.",ke(`Playground startup failed: ${e.message??String(e)}`)})}async function $o(){v=await rn(),de=v.input.getModel(),Ge=new Rt(q,(e,t)=>{if(e!==O()&&!Q.has(e)){let n=Ge?.model(e);if(n)Q.set(e,n)}if(Oe(e),t){if("startLineNumber"in t)v.input.setSelection(t);else v.input.setPosition(t);v.input.revealPositionInCenter({lineNumber:t.startLineNumber??t.lineNumber,column:t.startColumn??t.column})}},Lo,(e)=>ke(`Language service: ${e}`)),le=O(),qe=!0,v.input.setValue(He(tt())??N?.source??wt(H.path)),qe=!1,In(),Xe();for(let e of[S("compile-button"),S("menu-button"),S("view-simulate")])e.disabled=!1;$e.enable(),S("compile-shortcut").textContent=At?"⌘↵":"Ctrl ↵",u("share-shortcut").textContent=At?"⌘S":"Ctrl S",u("new-shortcut").textContent=At?"⌘N":"Ctrl N",v.input.addAction({id:"compile-yodl",label:"Compile Yodl",keybindings:[q.KeyMod.CtrlCmd|q.KeyCode.Enter],run:Pe}),v.output.addAction({id:"compile-yodl-output",label:"Compile Yodl",keybindings:[q.KeyMod.CtrlCmd|q.KeyCode.Enter],run:Pe});for(let e of[v.input,v.output])e.addCommand(q.KeyMod.CtrlCmd|q.KeyCode.KeyK,()=>Po.open());v.input.onDidChangeModelContent(()=>{if(qe||v.input.getModel()!==de)return;Xe(),xt()}),v.input.onDidChangeCursorPosition((e)=>{u("cursor-position").textContent=`Ln ${e.position.lineNumber}, Col ${e.position.column}`}),Le("Ready to compile"),Cn(),Pe()}function jn(){if(G!=="playground"){V({section:"playground",path:me});return}if(v&&H.path===me&&!N&&xe()!==et())Fn();else V({section:"playground",path:me})}var ot=gn({read:He,save:Re,sidebarHidden:()=>Ne,showSidebar:(e)=>{if(Hn(!e),Te.matches)Ee(e)},changed:()=>{v?.input.layout(),v?.output.layout(),Kt()}});for(let e of Array.from(document.querySelectorAll(".mode-switch button")))e.onclick=()=>void V(e.dataset.mode==="docs"?{section:"docs",chapter:Je}:e.dataset.mode==="tour"?{section:"tour"}:{section:"playground"});document.querySelector(".site-brand").onclick=(e)=>{e.preventDefault(),V({section:"tour",lesson:j[0].id})};S("lesson-list-button").onclick=()=>nt(u("lesson-list-scrim").hidden===!0);u("lesson-list-scrim").onclick=(e)=>{if(e.target===e.currentTarget)nt(!1)};S("previous-lesson").onclick=()=>{let e=j[Ae()-1];if(e)V({section:"tour",lesson:e.id})};S("next-lesson").onclick=()=>{let e=j[Ae()+1];V(e?{section:"tour",lesson:e.id}:{section:"playground"})};S("suggested-stage").onclick=()=>{if(!v)return;if(zt(j[Ae()].stage),Te.matches)Ee(!1),We("output")};S("new-file").onclick=()=>{Ee(!1),jn()};S("sidebar-toggle").onclick=()=>{Hn(!Ne),ot.sync()};S("context-toggle").onclick=()=>Ee(u("editor-view").dataset.sheet!=="open");u("stage-select").onchange=()=>zt(u("stage-select").value);S("compile-button").onclick=()=>{ot.reveal("output"),Pe()};S("view-output").onclick=()=>Fe("output",!0);S("view-simulate").onclick=()=>Fe("simulation",!0);S("source-tab").onclick=()=>We("source");S("output-tab").onclick=()=>We("output");S("simulation-tab").onclick=()=>We("simulation");S("menu-button").onclick=()=>kt(u("file-menu").hidden===!0);u("file-menu").onclick=()=>kt(!1);document.addEventListener("pointerdown",(e)=>{if(!u("file-menu").hidden&&!u("file-menu").parentElement.contains(e.target))kt(!1)});S("share-button").onclick=On;S("download-source").onclick=()=>{if(v)_n(we(le),v.input.getValue())};S("download-output").onclick=Nn;S("output-download").onclick=Nn;S("copy-output").onclick=()=>{if(yt===ft)qn(be,S("copy-output"))};S("reset-button").onclick=Fn;S("related-docs-menu").onclick=()=>{let[e,t]=N?.origin?.replace(/\.html$/,"").split("#")??[];if(e)V({section:"docs",chapter:e,anchor:t})};S("jump-error").onclick=()=>{if(!Ce||!v)return;We("source"),Oe(Ze),v.input.setSelection(Ce),v.input.revealRangeInCenter(Ce),v.input.focus()};u("reset-dialog").addEventListener("close",()=>{if(u("reset-dialog").returnValue==="reset")de.setValue(et())});S("copy-share").onclick=()=>void qn(u("share-url").value,S("copy-share"));document.addEventListener("keydown",(e)=>{let t=e.metaKey||e.ctrlKey;if(e.key==="Escape"){if(!u("lesson-list-scrim").hidden)nt(!1);else if(Te.matches&&u("editor-view").dataset.sheet==="open")Ee(!1);kt(!1)}if(G==="docs"||!t)return;if(e.key==="Enter"&&!e.defaultPrevented)e.preventDefault(),Pe();else if(e.key.toLowerCase()==="s"&&!e.altKey)e.preventDefault(),On();else if(e.key.toLowerCase()==="n"&&!e.altKey&&G==="playground")e.preventDefault(),jn()});window.addEventListener("popstate",()=>void V(Bn(),"none"));window.addEventListener("pagehide",()=>{St.dispose(),Ge?.dispose()});ko();Bt();Ee(!1);Le("Starting editor…","loading");async function Ho(){if(!location.hash.startsWith("#example="))return!1;let e=await St.show(new URLSearchParams(location.search).get("chapter")??void 0);try{let t=at(location.hash.slice(9)),n=e?.examples.find((i)=>i.id===t.id);if(t.version!==1||!n||typeof t.source!=="string"||!Object.hasOwn(X,t.stage))throw Error();let o={mode:"examples",path:me,stage:t.stage,source:t.source,files:n.files,entryPath:n.path,origin:`${e.slug}.html#${n.id}`};await V({section:"shared",shared:{...o,code:lt(o)}},"replace")}catch{return ke("This shared example could not be opened. The original examples are shown in the guide."),!1}return!0}var mt=Bn();if(Te.matches&&mt.section==="tour")Ee(!0);if(mt.section==="docs"&&location.hash.startsWith("#example="))Ho().then((e)=>{if(!e)V({...mt,anchor:void 0},"replace")});else V(mt,"replace");setTimeout(()=>void St.load().then((e)=>{for(let t of e.chapters)Rn.set(t.slug,t.title);if(G==="tour")vt()}).catch(()=>{}),1500);

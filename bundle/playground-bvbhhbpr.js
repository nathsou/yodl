var Ne={"01_presentation":[{id:"gates",title:"Your first circuit"}],"02_getting_started":[{id:"gates",title:"Your first circuit"},{id:"counter",title:"Describe the next state"}],"03_data_types":[{id:"widths",title:"Give every bit a place"},{id:"records",title:"Name a group of signals"}],"04_constructs":[{id:"modules",title:"Connect reusable modules"},{id:"generics",title:"Parameterise a design"},{id:"packages",title:"Organise a design"}],"05_operators":[{id:"bits",title:"Take signals apart"}],"06_control_flow":[{id:"selection",title:"Choose a signal"},{id:"vectors",title:"Build parallel hardware"}],"07_built_in_functions":[{id:"bits",title:"Take signals apart"},{id:"counter",title:"Describe the next state"}],"08_primitive_modules":[{id:"registers",title:"Remember a value"},{id:"memory",title:"Store a small table"}],"09_external_modules":[{id:"modules",title:"Connect reusable modules"}]};function Lt(e){let t=new TextEncoder().encode(JSON.stringify(e)),n="";for(let o of t)n+=String.fromCharCode(o);return btoa(n).replaceAll("+","-").replaceAll("/","_").replace(/=+$/,"")}function Oe(e){if(e.length>200000)throw Error("This shared program is too large to open.");let t=atob(e.replaceAll("-","+").replaceAll("_","/"));return JSON.parse(new TextDecoder().decode(Uint8Array.from(t,(n)=>n.charCodeAt(0))))}function rt(e){return typeof e==="string"&&/^(book\/src|examples|tour)\/[\w./-]+\.yodl$/.test(e)&&!e.split("/").some((t)=>t===".."||t===".")}function Tt(e){return!!e&&typeof e==="object"&&!Array.isArray(e)&&Object.entries(e).every(([t,n])=>rt(t)&&typeof n==="string")}var Mt=[{id:"gates",title:"Your first circuit",topic:"Signals & modules",intro:"A Yodl program describes hardware. A module connects named inputs to named outputs; the connections operate continuously.",concepts:["bool is a one-bit signal.","The expression a and b describes a logic gate. It does not wait for a clock."],observe:"In FIRRTL, find the two input ports, the output port, and the and operation.",challenge:"Change and to xor. The output will describe a gate that is high when exactly one input is high.",stage:"write_firrtl",file:"01-gates.yodl"},{id:"widths",title:"Give every bit a place",topic:"Integers & arithmetic",intro:"Hardware signals have fixed widths. u8 is an unsigned eight-bit integer; s8 is a signed eight-bit integer. Choose the output width to retain the bits you need.",concepts:["Adding two eight-bit unsigned values can require nine bits.","Sized literals spell out width and base: 8'hFF is eight bits of hexadecimal FF. Signedness changes require an explicit cast."],observe:"Inspect the nine-bit sum and sixteen-bit product ports. Switch to Typed to see expression types.",challenge:"Change sum from u9 to u8. Narrowing keeps the low eight bits, so a carry no longer fits in the output.",stage:"write_firrtl",file:"02-widths.yodl"},{id:"selection",title:"Choose a signal",topic:"Conditions & multiplexers",intro:"Conditions select between signals. Both alternatives describe hardware; a condition does not make the circuit execute one software branch at a time.",concepts:["Use if for a two-way choice.","Use match for several cases, with _ as the default."],observe:"Look for mux operations in FIRRTL: these are the signal selectors described by the conditions.",challenge:"Add a 2 case to match that returns a xor b. Keep the default case.",stage:"write_firrtl",file:"03-selection.yodl"},{id:"bits",title:"Take signals apart",topic:"Slices & built-ins",intro:"Individual bits and slices let you work with the representation of a value. Built-in functions have names ending in !.",concepts:["word[7:4] takes bits seven through four, inclusive.","cat! joins bit strings in order; xorr reduces a signal to its parity bit."],observe:"Find bits, cat, and xorr operations in the FIRRTL output.",challenge:"Change swapped to cat!(low, low). Both halves of the output now come from the same four input bits.",stage:"write_firrtl",file:"04-bits.yodl"},{id:"vectors",title:"Build parallel hardware",topic:"Vectors & loops",intro:"A vector groups a fixed number of values. A for loop creates repeated hardware at compile time, so the loop bounds must be known before the circuit runs.",concepts:["[4]u8 is four eight-bit elements.","0..<Lanes excludes the upper bound. All four lanes exist in parallel."],observe:"The Simplified output expands the loop into individual assignments. Switch to FIRRTL to see the vector ports.",challenge:"Change Lanes from 4 to 8. Compile again and count the expanded assignments.",stage:"write_simplified",file:"05-vectors.yodl"},{id:"records",title:"Name a group of signals",topic:"Records & type aliases",intro:"Records collect related signals into named fields. A type alias gives the collection a reusable name without allocating storage.",concepts:["Access a field with . followed by its name.","A record spread copies fields; later fields override the copied values."],observe:"Find the r, g, and b fields in the output ports. They remain individual signals within a bundle.",challenge:"Also override b with 0 in muted. Only the red channel will pass through.",stage:"write_firrtl",file:"06-records.yodl"},{id:"modules",title:"Connect reusable circuits",topic:"Instances & ports",intro:"Define a module once and instantiate it wherever you need that hardware. Each instance is a separate circuit with its own connections.",concepts:["Named arguments connect inputs when creating an instance.","Access an instance output with .sum. Top is the entry circuit in this design."],observe:"Find two Adder instances under Top. They share a definition but connect to different inputs.",challenge:"Connect the second adder to a and c instead of b and c.",stage:"write_firrtl",file:"07-modules.yodl"},{id:"generics",title:"Parameterise a design",topic:"Compile-time parameters",intro:"Generic parameters configure hardware before it runs. Nat parameters describe sizes; Type parameters let a module work with different signal types.",concepts:["uint[Width] uses a compile-time width.","Instantiation specialises each generic module with concrete parameters. These parameters are not input ports."],observe:"Monomorphised output shows concrete versions of the generic modules. Compare it with Source.",challenge:"Change the wide input and output from u16 to u12, and change Mask[16] to Mask[12].",stage:"write_mono",file:"08-generics.yodl"},{id:"registers",title:"Remember a value",topic:"Clocked state",intro:"Combinational logic has no memory. Reg adds state: q is the current value and d is the value sampled at the next rising clock edge.",concepts:["Reg[u8] stores eight bits.","rst resets the register to zero synchronously. en controls whether it captures a new value."],observe:"Find the register and its clock, reset, and enable logic in FIRRTL. The output reads the stored q value.",challenge:"Connect en to true instead of enable. The register will capture data on every rising edge unless reset is asserted.",stage:"write_firrtl",file:"09-registers.yodl"},{id:"counter",title:"Describe the next state",topic:"Feedback & constants",intro:"A counter feeds its current register value through combinational logic to compute the next value. The register breaks the feedback path into clock cycles.",concepts:["clog2!(Limit) computes the number of address bits needed for Limit values.","The comparison makes the counter wrap after Limit - 1. Reset establishes the initial zero state."],observe:"Follow the register output through the increment and selection logic back to its input.",challenge:"Change Limit from 10 to 16. The width stays four bits, but the wrap comparison changes.",stage:"write_firrtl",file:"10-counter.yodl"},{id:"packages",title:"Organise a design",topic:"Packages & names",intro:"Packages group declarations under a namespace. Qualified names make it clear where a reusable module belongs.",concepts:["Use :: to access a declaration inside a package.","A file brought in with import is also wrapped in a package named after the file. Larger examples demonstrate imports."],observe:"Find the qualified Logic::Invert name in Source, then switch to FIRRTL to inspect its instance.",challenge:"Add another Invert instance after the first and connect q to its output. Two inversions restore the original signal.",stage:"write_source",file:"11-packages.yodl"},{id:"memory",title:"Store a small table",topic:"Memory & latency",intro:"Memory describes indexed storage with explicit read and write ports. Latency is part of the interface: this design requests a read latency of one cycle.",concepts:["Depth is the number of stored words; T is the type of each word.","Read and write ports carry clocks, addresses, and enables. A true write mask enables the whole byte."],observe:"Find the memory depth, read latency, and write latency in FIRRTL. Compilation shows structure; the playground does not simulate clock cycles.",challenge:"Increase Depth to 32 and change addr from u4 to u5 so every word remains addressable.",stage:"write_firrtl",file:"12-memory.yodl"}];var j={write_source:{label:"Source",short:"Source",extension:"yodl",language:"yodl",description:"Resolved source, with imported declarations available to the compiler."},write_mono:{label:"Monomorphised",short:"Mono",extension:"yodl",language:"yodl",description:"Generic modules specialised with concrete parameters."},write_typed:{label:"Typed",short:"Typed",extension:"yodl",language:"yodl",description:"Expressions annotated with their resolved types and widths."},write_simplified:{label:"Simplified",short:"Simplified",extension:"yodl",language:"yodl",description:"Core representation with loops expanded and expressions simplified."},write_firrtl:{label:"FIRRTL",short:"FIRRTL",extension:"fir",language:"firrtl",description:"Hardware represented as ports, operations, registers, and connections."},write_low_firrtl:{label:"Low FIRRTL",short:"Low",extension:"fir",language:"firrtl",description:"FIRRTL after lowering passes, ready for downstream tools."},write_rtlil:{label:"RTLIL",short:"RTLIL",extension:"il",language:"rtlil",description:"Hardware in the intermediate language used by Yosys."},test:{label:"Tests",short:"Tests",extension:"txt",language:"plaintext",description:"Run procedural testbenches and report each passing test."}};function be(e,t){if(e.uri!==t||!e.range)return null;let{start:n,end:o}=e.range;return{startLineNumber:n.line+1,startColumn:n.character+1,endLineNumber:o.line+1,endColumn:o.character+1}}var we={...{"examples/Testbench.yodl":`module XorGate(a: bool, b: bool) -> (out: bool) {
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
`}},I=Mt,Ee=Object.keys(we).filter((e)=>/^examples\/[^/]+\.yodl$/.test(e)).sort(),J="examples/Playground.yodl",it={mode:"tour",path:`tour/${I[0].file}`,stage:"write_firrtl"};function Le(e){if(!e||typeof e!=="object")return!1;let t=e;return Object.hasOwn(j,t.stage)&&(t.mode==="tour"?I.some((n)=>`tour/${n.file}`===t.path):t.mode==="examples"&&(Ee.includes(t.path)||t.path===J))}function Fe(e){return Lt({...e,version:e.entryPath?2:1})}function st(e){if(!e.startsWith("#code="))return null;try{let t=Oe(e.slice(6));if(![1,2].includes(t.version)||!Le(t)||typeof t.source!=="string")throw Error();if(t.version===2&&(!rt(t.entryPath)||!Tt(t.files)||t.origin!==void 0&&!/^[a-zA-Z0-9_-]+\.html#[a-z0-9-]+$/.test(t.origin)))throw Error();if(t.version===1)return{version:1,mode:t.mode,path:t.path,stage:t.stage,source:t.source};return t}catch{throw Error("This share link is invalid, too large, or uses an unsupported version.")}}class Te{timeoutMs;worker;active;queue=[];timer;nextId=0;constructor(e=15000){this.timeoutMs=e}compile(e,t){return this.cancel(e),new Promise((n)=>{this.queue.push({owner:e,request:{...t,id:++this.nextId},resolve:n}),this.pump()})}cancel(e){if(this.queue=this.queue.filter((t)=>{if(t.owner!==e)return!0;return t.resolve(null),!1}),this.active?.owner===e)this.worker?.terminate(),this.worker=void 0,this.finish(null)}dispose(){for(let e of this.queue)e.resolve(null);if(this.queue=[],this.active)this.cancel(this.active.owner);this.worker?.terminate(),this.worker=void 0}finish(e){clearTimeout(this.timer);let t=this.active;this.active=void 0,t?.resolve(e),this.pump()}pump(){if(this.active||!this.queue.length)return;let e=this.active=this.queue.shift(),t=(n)=>{if(this.active!==e)return;this.worker?.terminate(),this.worker=void 0,this.finish({id:e.request.id,error:n,duration:0})};try{this.worker??=new Worker(new URL("./playground-worker-cxe13d5w.js",import.meta.url),{type:"module"}),this.worker.onmessage=(n)=>{if(this.active===e&&n.data.id===e.request.id)this.finish(n.data)},this.worker.onerror=()=>t("The compiler worker could not run. Try Compile again."),this.timer=setTimeout(()=>t("Compilation exceeded 15 seconds. Try a smaller design or reduce compile-time loop bounds."),this.timeoutMs),this.worker.postMessage(e.request)}catch(n){t(`Could not start the compiler: ${n.message}`)}}}class at{startupTimeoutMs;worker;requestId=0;activeId;request;startupTimer;constructor(e=30000){this.startupTimeoutMs=e}start(e,t){this.stop();let n=++this.requestId;this.activeId=n,this.request=e;let o=this.worker=new Worker(new URL("./playground-worker-cxe13d5w.js",import.meta.url),{type:"module"});o.onmessage=(i)=>{if(this.worker!==o||i.data.id!==n)return;clearTimeout(this.startupTimer),t(i.data)},o.onerror=()=>{if(this.worker!==o)return;this.stop(),t({id:n,type:"error",error:"The simulation worker could not run. Try Run again."})},this.startupTimer=setTimeout(()=>{if(this.worker!==o)return;this.stop(),t({id:n,type:"error",error:"Simulation compilation timed out. Try a smaller design."})},this.startupTimeoutMs),o.postMessage({...e,id:n,simulate:{...e.simulate,mode:"realtime",action:e.simulate?.action??"run"}})}pause(){this.postControl("pause")}resume(e){this.postControl("resume",e)}command(e,t){this.postControl(e,t)}setInputs(e){if(!this.request?.simulate)return;this.request={...this.request,simulate:{...this.request.simulate,inputs:e}},this.postControl("settle")}stop(){clearTimeout(this.startupTimer),this.worker?.terminate(),this.worker=void 0,this.activeId=void 0,this.request=void 0}postControl(e,t){if(!this.worker||this.activeId===void 0||!this.request)return;this.worker.postMessage({id:this.activeId,control:{action:e,options:t,...e==="settle"?{inputs:this.request.simulate?.inputs}:{}}})}}var Rt=[{id:"teal",label:"Teal"},{id:"cobalt",label:"Cobalt"},{id:"moss",label:"Moss"},{id:"plum",label:"Plum"},{id:"ochre",label:"Ochre"},{id:"signal",label:"Signal"},{id:"ember",label:"Ember"}];function $t(e){return getComputedStyle(document.documentElement).getPropertyValue(`--${e}`).trim()}function Pt(e){try{return localStorage.getItem(e)}catch{return null}}function _t(e,t){try{localStorage.setItem(e,t)}catch{}}function Dt(e,t){let n=matchMedia("(prefers-color-scheme: dark)"),o=Array.from(e.querySelectorAll("[data-theme-preference]")),i=Pt("yodl-playground-v2:theme"),l=i==="light"||i==="dark"?i:"system",s=()=>{let d=l==="dark"||l==="system"&&n.matches;document.documentElement.dataset.theme=d?"dark":"light";for(let y of o)y.setAttribute("aria-pressed",String(y.dataset.themePreference===l));t(d)};for(let d of o)d.addEventListener("click",()=>{l=d.dataset.themePreference,_t("yodl-playground-v2:theme",l),s()});return n.addEventListener("change",s),s(),s}function At(e,t){let n=e.querySelector("#accent-button"),o=e.querySelector("#accent-menu"),i=e.querySelector("#accent-label"),l=Array.from(e.querySelectorAll(".swatch")),s=Pt("yodl-playground-v2:accent"),d=Rt.some((E)=>E.id===s)?s:"teal",y=()=>{document.documentElement.dataset.accent=d,i.textContent=Rt.find((E)=>E.id===d).label;for(let E of l)E.setAttribute("aria-pressed",String(E.dataset.accent===d))},L=(E)=>{o.hidden=!E,n.setAttribute("aria-expanded",String(E))};n.addEventListener("click",()=>L(o.hidden===!0));for(let E of l)E.addEventListener("click",()=>{d=E.dataset.accent,_t("yodl-playground-v2:accent",d),y(),t()});return document.addEventListener("pointerdown",(E)=>{if(!o.hidden&&!e.contains(E.target))L(!1)}),e.addEventListener("keydown",(E)=>{if(E.key==="Escape"&&!o.hidden)L(!1),n.focus()}),y(),y}var P,Ht;function qt(){if(P)return Promise.resolve();return Ht??=Cn().catch((e)=>{throw Ht=void 0,e})}var xn="./monaco-wn4p6kqb.js",kn="./monaco-44nfyfsx.css";function Sn(e){return new Promise((t,n)=>{let o=document.createElement("link");o.rel="stylesheet",o.href=e,o.onload=()=>t(),o.onerror=()=>{o.remove(),n(Error("Could not load the editor styles. Reload the page to try again."))},document.head.append(o)})}async function Cn(){if(!window.monaco){let e,t=new Promise((n,o)=>{e=setTimeout(()=>o(Error("The code editor took too long to load. Try again.")),30000)});try{let n=Promise.all([Sn(new URL(kn,import.meta.url).href),import(new URL(xn,import.meta.url).href)]),[,o]=await Promise.race([n,t]);window.monaco=o.monaco}finally{clearTimeout(e)}}P=window.monaco,P.languages.register({id:"yodl"}),P.languages.setMonarchTokensProvider("yodl",{keywords:["declare","module","test","let","match","if","else","for","in","const","package","import","true","false"],typeKeywords:["uint","sint","bool","clock","type","Nat","Type"],wordOperators:["and","or","not","xor","nand","nor","xnor","shl","shr","andr","orr","xorr"],operators:["==","!=","<=",">=","<:",">:","+:","-:","..","..<","..=","+","-","*","/","%","=>","?",":",".","->","::"],symbols:/[=><!~?:&|+\-*/^%.]+/,tokenizer:{root:[[/\w+!/,"function"],[/\b[us]\d+\b/,"type"],[/[A-Z]\w*/,{cases:{"@typeKeywords":"type","@default":"ident.cap"}}],[/[a-zA-Z_]\w*/,{cases:{"@keywords":"keyword","@typeKeywords":"type","@wordOperators":"keyword.operator","@default":"identifier"}}],[/"([^"\\]|\\.)*$/,"string.invalid"],[/"/,{token:"string.quote",bracket:"@open",next:"@string"}],[/'[^'\\]'/,"string"],[/'\\.'/,"string"],[/\/\/.*$/,"comment"],[/\b\d+'[bhod]?\w+\b/,"number"],[/\b\d+(_\d+)*\b/,"number"],[/@symbols/,"delimiter"],[/[(){}\[\],;]/,"delimiter"],[/\s+/,"white"]],string:[[/[^\\"]+/,"string"],[/\\./,"string.escape"],[/"/,{token:"string.quote",bracket:"@close",next:"@pop"}]]}}),P.languages.setLanguageConfiguration("yodl",{comments:{lineComment:"//"},brackets:[["{","}"],["[","]"],["(",")"]],autoClosingPairs:[{open:"{",close:"}"},{open:"[",close:"]"},{open:"(",close:")"},{open:'"',close:'"'}]});for(let e of["firrtl","rtlil"])P.languages.register({id:e}),P.languages.setMonarchTokensProvider(e,{tokenizer:{root:[[e==="firrtl"?/;.*/:/#.*/,"comment"],[/"[^"\\]*(?:\\.[^"\\]*)*"/,"string"],[/\b(?:circuit|module|extmodule|input|output|wire|node|reg|regreset|mem|inst|of|when|else|connect|attribute|parameter|cell|end|process|sync|update|assign)\b/,"keyword"],[/\b(?:UInt|SInt|Clock|Reset|AsyncReset)\b/,"type"],[/\b(?:mux|add|sub|mul|and|or|xor|not|bits|cat|pad|eq|lt|gt)\b/,"function"],[/-?\b\d+(?:'[01xzm-]+)?\b/,"number"],[/[<>=:]+/,"delimiter"]]}});je()}var En={panel:"#fefdfc",ink:"#211c17",mute:"#69625d",line:"#e2dfdb",sunk:"#f3f1ed",bg:"#faf9f6",acc:"#008381","acc-soft":"#dbf3f1","k-kw":"#6b46a0","k-ty":"#00717f","k-fn":"#945a00","k-nm":"#2b7440","k-id":"#23588a"},T=(e)=>(typeof getComputedStyle==="function"?$t(e):"")||En[e],z=(e)=>e.replace("#","");function je(){if(!P)return;let e=document.documentElement.dataset.theme==="dark";P.editor.defineTheme("yodl",{base:e?"vs-dark":"vs",inherit:!0,rules:[{token:"",foreground:z(T("ink"))},{token:"keyword",foreground:z(T("k-kw"))},{token:"keyword.operator",foreground:z(T("k-kw"))},{token:"identifier",foreground:z(T("ink"))},{token:"operator",foreground:z(T("mute"))},{token:"type.identifier",foreground:z(T("k-ty"))},{token:"type",foreground:z(T("k-ty"))},{token:"function",foreground:z(T("k-fn"))},{token:"number",foreground:z(T("k-nm"))},{token:"string",foreground:z(T("k-nm"))},{token:"ident.cap",foreground:z(T("k-id"))},{token:"comment",foreground:z(T("mute"))},{token:"delimiter",foreground:z(T("mute"))}],colors:{"editor.background":T("panel"),"editor.foreground":T("ink"),"editorLineNumber.foreground":T("mute")+"99","editorLineNumber.activeForeground":T("ink"),"editor.selectionBackground":T("acc-soft"),"editor.inactiveSelectionBackground":T("sunk"),"editor.lineHighlightBackground":T("sunk")+"00","editor.lineHighlightBorder":T("sunk")+"00","editorCursor.foreground":T("acc"),"editorIndentGuide.background1":T("line"),...Object.fromEntries([1,2,3,4,5,6].map((t)=>[`editorBracketHighlight.foreground${t}`,T("mute")])),"editorBracketHighlight.unexpectedBracket.foreground":T("mute"),"editorWidget.background":T("panel"),"editorWidget.border":T("line"),"scrollbarSlider.background":T("line")+"aa","scrollbarSlider.hoverBackground":T("mute")+"66"}}),P.editor.setTheme("yodl")}async function Ln(){let e=typeof document<"u"?document.fonts:void 0;if(!e)return;try{await Promise.race([e.load('13.5px "IBM Plex Mono"'),new Promise((t)=>setTimeout(t,1500))])}catch{}e.ready.then(()=>P?.editor.remeasureFonts?.())}async function It(e,t={}){await qt(),await Ln();let n={automaticLayout:!0,minimap:{enabled:!1},scrollBeyondLastLine:!1,fontSize:13.5,lineHeight:23,fontFamily:'"IBM Plex Mono", ui-monospace, SFMono-Regular, Consolas, monospace',padding:{top:18,bottom:18},renderLineHighlight:"none",glyphMargin:!1,folding:!0,lineNumbersMinChars:3,lineDecorationsWidth:18,overviewRulerLanes:0,"semanticHighlighting.enabled":!0,hideCursorInOverviewRuler:!0,overviewRulerBorder:!1,bracketPairColorization:{enabled:!1},guides:{indentation:!1,bracketPairs:!1},matchBrackets:"never",scrollbar:{useShadows:!1,verticalScrollbarSize:8,horizontalScrollbarSize:8},tabSize:4,insertSpaces:!0,fixedOverflowWidgets:!0};return e.replaceChildren(),P.editor.create(e,{...n,language:"yodl",ariaLabel:"Yodl source code",...t})}async function Nt(){await qt();let e=P.editor.createModel("","yodl"),t=await It(document.getElementById("input-panel"),{model:e}),n=await It(document.getElementById("output-panel"),{readOnly:!0,language:"firrtl",ariaLabel:"Compiled output"});return{input:t,output:n}}var N=(e)=>document.getElementById(e),lt=16,Tn=10,Mn=512;function Ot(e){let t={};for(let n of e.split(",")){let o=/^\s*([A-Za-z_$][\w$]*)(?::(\d+))?\s*=\s*(-?\d+)\s*$/.exec(n);if(!n.trim())continue;if(!o)throw Error(`Invalid input assignment: ${n}`);if(!Number.isSafeInteger(Number(o[3])))throw Error("Input exceeds the safe integer range.");t[o[1]]={width:Number(o[2]??32),value:Number(o[3])}}return t}function Rn(e){if(!e.known)return"x";if(e.width===1)return e.value==="0"?"0":"1";try{return`${e.width}'h${BigInt(e.value).toString(16)}`}catch{return e.value}}var $n=(e)=>{if(!e.known)return"x";try{return BigInt(e.value).toString(16)}catch{return e.value}};function Pn(e){if(e>=1e6)return`${(e/1e6).toFixed(1)} MHz`;if(e>=1e4)return`${Math.round(e/1000)} kHz`;if(e>=1000)return`${(e/1000).toFixed(1)} kHz`;return`${e<10?e.toFixed(1):Math.round(e)} Hz`}function Ft(e){let t=new at,n="ready",o,i=[],l,s,d=(r)=>N(r),y=(r)=>N(r),L=["simulation-top","simulation-clock","simulation-cycles-per-frame","simulation-clock-hz","simulation-refresh-fps"];function E(){let r=n==="running"||n==="stepping";d("simulation-run").textContent=r?"Pause":n==="paused"?"Resume":"Run",d("simulation-run").disabled=n==="starting"||n==="halted",d("simulation-reset").disabled=n==="ready"||n==="starting",d("simulation-stop").disabled=n==="ready"}function Q(r){let c=N("simulation-framebuffer");if(l=r,N("simulation-zoom-control").hidden=!r,!r){c.hidden=!0;return}if(c.hidden=!1,c.width!==r.width||c.height!==r.height)c.width=r.width,c.height=r.height,s=void 0;let f=(c.parentElement?.clientWidth||640)-32,x=N("simulation-zoom").value,p=x==="fit"?Math.min(f/r.width,480/r.height):Number(x);c.style.width=`${r.width*p}px`,c.style.height=`${r.height*p}px`;let k=c.getContext("2d");if(!k)return;let u=s??=k.createImageData(r.width,r.height),M=Math.ceil(r.width/32);for(let S=0;S<r.width*r.height;S++){let A=Math.floor(S/r.width),R=S%r.width,H=A*M+Math.floor(R/32),ae=!(!r.valid||(r.packed?(r.valid[H]&1<<R%32)!==0:r.valid[S]!==0))?16711935:r.packed?(r.packed[H]&1<<R%32)!==0?r.onColor??16777215:r.offColor??0:r.rgb?.[S]??r.pixels?.[S]??0;u.data[S*4]=ae>>>16&255,u.data[S*4+1]=ae>>>8&255,u.data[S*4+2]=ae&255,u.data[S*4+3]=255}k.putImageData(u,0,0)}function v(r,c){let f=document.createElement("div");f.className="signal";let x=document.createElement("span");x.className="signal-name",x.append(r.name+" ");let p=document.createElement("small");return p.textContent=r.width===1?"bool":`u${r.width}`,x.append(p),f.append(x,c),f}function K(r){let c=N("simulation-inputs-controls"),f=r.map((p)=>`${p.name}:${p.width}:${p.value}:${p.known}`).join("|");if(c.dataset.signature===f)return;c.dataset.signature=f,c.replaceChildren();let x=(p)=>{let k=[...c.querySelectorAll("[data-signal]")].map((u)=>{let M=u instanceof HTMLInputElement?u.value:u.getAttribute("aria-checked")==="true"?1:0;return`${u.dataset.signal}:${u.dataset.width}=${M}`});y("simulation-inputs").value=k.join(", ");try{let u=Ot(k.join(", "));if(p instanceof HTMLInputElement)p.setCustomValidity("");if(n!=="ready")t.setInputs(u)}catch(u){if(p instanceof HTMLInputElement)p.setCustomValidity(String(u)),p.reportValidity()}};for(let p of r){let k;if(p.width===1){let u=document.createElement("button");u.type="button",u.setAttribute("role","switch"),u.setAttribute("aria-checked",String(p.value!=="0")),u.setAttribute("aria-label",p.name),u.textContent=p.value!=="0"?"1":"0",u.addEventListener("click",()=>{let M=u.getAttribute("aria-checked")!=="true";u.setAttribute("aria-checked",String(M)),u.textContent=M?"1":"0",x(u)}),k=u}else{let u=document.createElement("input");u.type="text",u.value=p.value,u.inputMode="numeric",u.title=`u${p.width}`,u.setAttribute("aria-label",p.name),u.addEventListener("change",()=>x(u)),k=u}k.className="signal-value",k.dataset.signal=p.name,k.dataset.width=String(p.width),c.append(v(p,k))}if(!r.length)c.append(V("No inputs"))}function V(r){let c=document.createElement("p");return c.className="signal-empty",c.textContent=r,c}function ie(r){let c=N("simulation-outputs"),f=r.slice(0,100).map((x)=>{let p=document.createElement("span");return p.className="signal-value signal-output",p.textContent=Rn(x),v(x,p)});if(r.length>100)f.push(v({name:`… ${r.length-100} more`,width:0,value:"",known:!1},document.createElement("span")));c.replaceChildren(...f.length?f:[V("No outputs")])}function se(r){if(r.totalCycles===void 0||!r.outputs&&!r.inputs)return;let c=new Map;for(let x of[...r.inputs??[],...r.outputs??[]])c.set(x.name,x);let f=i.at(-1);if(f&&f.cycle===r.totalCycles){f.values=c;return}if(f&&r.totalCycles<f.cycle)i=[];if(i.push({cycle:r.totalCycles,values:c}),i.length>Mn)i.shift()}function oe(){let r=N("simulation-trace");if(!i.length){r.replaceChildren(V("Run or step the simulation to record signals.")),N("trace-range").textContent="";return}let c=i.at(-1),f=[...c.values.keys()].filter((S)=>S!==o).slice(0,Tn-(o?1:0)),x=Math.max(0,i.length-lt),p=i.slice(x),k=[],u=(S,A)=>{let R=document.createElement("div");R.className="trace-row";let H=document.createElement("span");H.className="trace-name",H.textContent=S,H.title=S;let W=document.createElement("div");return W.className="trace-lane",W.append(...A),R.append(H,W),R},M=(S,A,R)=>{let H=document.createElement("div");if(H.className="trace-cell",H.dataset.kind=S,A)H.dataset.future="";if(R)H.dataset.edge="";return H};if(o){let S=[];for(let A=0;A<lt;A++){let R=M("clock",A>=p.length,A===0);R.append(document.createElement("span"),document.createElement("span")),S.push(R)}k.push(u(o,S))}for(let S of f){let A=[],R;for(let H=0;H<lt;H++){let W=p[Math.min(H,p.length-1)].values.get(S),ae=H>=p.length;if(!W){A.push(M("bus",ae,!1));continue}let tt=W.width===1&&W.known,Ct=`${W.known}:${W.value}`,Et=!ae&&(R===void 0||R!==Ct),nt=M(tt?"bit":"bus",ae,Et);if(tt&&W.value!=="0")nt.dataset.high="";if(!tt&&Et){let ot=document.createElement("span");ot.className="bus-value",ot.textContent=$n(W),nt.append(ot)}if(!ae)R=Ct;A.push(nt)}k.push(u(S,A))}r.replaceChildren(...k),N("trace-range").textContent=p.length>1?`cycles ${p[0].cycle}–${c.cycle}`:`cycle ${c.cycle}`}function h(r){let c=N("simulation-output");if(r.type==="error"){n="error",c.hidden=!1,c.textContent=r.error??"Simulation failed.",N("simulation-state").textContent="Error",E(),e.setStatus("Simulation failed","error");return}if(n=r.type==="halted"?"halted":r.type==="stopped"?"ready":r.type==="stepping"?"stepping":r.type==="frame"||r.type==="resumed"?"running":"paused",r.frame)Q(r.frame);else if(r.metadata&&!r.metadata.display)Q(void 0);if(r.clock!==void 0)o=r.clock;if(r.inputs)r={...r,inputs:r.inputs.filter((A)=>A.name!==o)};if(r.outputs)ie(r.outputs);if(r.inputs)K(r.inputs);se(r),oe();let f=r.messages??[];if(c.hidden=f.length===0,c.textContent=f.join(`
`),d("simulation-step-cycle").disabled=!r.clock||n==="halted",d("simulation-step-frame").hidden=!(r.frame&&r.clock),d("simulation-step-frame").disabled=n==="halted",r.metadata){let A={"simulation-top":r.metadata.top,"simulation-clock":r.clock,"simulation-cycles-per-frame":r.playback?.cyclesPerFrame,"simulation-clock-hz":r.playback?.clockHz??"maximum","simulation-refresh-fps":r.playback?.refreshFps};for(let[R,H]of Object.entries(A))y(R).placeholder=String(H??"automatic");y("simulation-cycles-per-frame").disabled=!r.clock||Boolean(r.metadata.display?.stream),y("simulation-clock-hz").disabled=!r.clock,y("simulation-refresh-fps").disabled=!r.clock}let x=r.totalCycles??0,p=r.cyclesPerSecond===void 0||n!=="running"&&n!=="stepping"?"":` · ${Pn(r.cyclesPerSecond)}`;N("simulation-cycle").textContent=`cycle ${x.toLocaleString()}${p}`;let k=r.simulatedSeconds===void 0?"":` · ${r.simulatedSeconds.toFixed(3)} simulated s`,u=r.status?.failed??!1,M=u?"Failed":n[0].toUpperCase()+n.slice(1),S=r.status?.exit_code===void 0?"":` · exit ${r.status.exit_code}`;N("simulation-state").textContent=`${M}${S}${k}`,E(),e.setStatus(u?`Simulation failed${r.status?.first_failure?`: ${r.status.first_failure.message}`:""}`:n==="running"||n==="stepping"?"Simulating…":`Simulation ${n}`,u?"error":void 0)}function m(r="run"){let c=(k)=>{let u=Number(y(k).value);return Number.isFinite(u)&&u>0?u:void 0},f={clockHz:c("simulation-clock-hz"),refreshFps:c("simulation-refresh-fps"),cyclesPerFrame:c("simulation-cycles-per-frame")};if(n!=="ready"&&n!=="error"){if(r==="run")if(n==="running"||n==="stepping")t.pause();else t.resume(f);else t.command(r,f);return}let x=y("simulation-top").value.trim(),p=y("simulation-clock").value.trim();i=[],oe(),N("simulation-state").textContent="Compiling simulation…",n="starting",E();try{let{source:k,path:u,files:M}=e.request();t.start({source:k,path:u,stage:"write_low_firrtl",files:M,simulate:{action:r,...x?{top:x}:{},...p?{clock:p}:{},...Object.fromEntries(Object.entries(f).filter(([,S])=>S!==void 0)),inputs:Ot(y("simulation-inputs").value)}},h)}catch(k){h({id:0,type:"error",error:String(k)})}}function w(){t.stop(),n="ready",N("simulation-state").textContent="Ready",N("simulation-cycle").textContent="cycle 0",E()}return d("simulation-run").onclick=()=>m("run"),d("simulation-reset").onclick=()=>{i=[],oe(),m("reset")},d("simulation-step-cycle").onclick=()=>m("step_cycle"),d("simulation-step-frame").onclick=()=>m("step_frame"),N("simulation-zoom").onchange=()=>{if(l)Q(l)},d("simulation-stop").onclick=()=>{w(),e.setStatus("Simulation stopped")},d("simulation-settings").onclick=()=>{let r=N("simulation-options");r.hidden=!r.hidden,d("simulation-settings").setAttribute("aria-expanded",String(!r.hidden))},oe(),ie([]),K([]),E(),{enable(){for(let r of["simulation-run","simulation-step-cycle",...L])N(r).disabled=!1;E()},stop:w,clear(){w(),i=[],o=void 0,Q(void 0),oe(),ie([]),N("simulation-inputs-controls").dataset.signature="",K([]),N("simulation-output").hidden=!0;for(let r of["simulation-top","simulation-clock","simulation-inputs"])y(r).value=""},clearFrame(){Q(void 0)},get active(){return n!=="ready"&&n!=="error"},run:m}}var ct=(e)=>e.replace(/[&<>"']/g,(t)=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[t]),_n=/^(module|declare|test|let|const|type|package|import|for|in|if|else|match|true|false)$/,Dn=/^(and|or|not|xor|nand|nor|xnor|shl|shr|andr|orr|xorr)$/,An=/^(u\d+|s\d+|uint|sint|bool|clock|Nat|Type)$/,Hn=/^(circuit|module|extmodule|input|output|wire|node|reg|regreset|mem|inst|of|when|else|connect|attribute|parameter|cell|end|process|sync|update|assign|public|version|intmodule|invalidate|skip|printf|stop|assert|cover|assume)$/,In=/^(UInt|SInt|Clock|Reset|AsyncReset|Analog)$/,qn=/^(mux|add|sub|mul|div|rem|and|or|xor|not|bits|cat|pad|eq|neq|lt|leq|gt|geq|shl|shr|dshl|dshr|head|tail|andr|orr|xorr|neg|cvt|asUInt|asSInt|asClock|validif)$/;function Nn(e,t){if(t==="yodl"){if(e.startsWith("//"))return"comment";if(e.startsWith('"'))return"string";if(_n.test(e)||Dn.test(e))return"keyword";if(An.test(e))return"type";if(/^\w+!$/.test(e))return"function";if(/^\d/.test(e))return"number";if(/^[A-Z]/.test(e))return"ident";if(/^[=<>+\-*/%:?.&|^~!]+$/.test(e))return"punct";return""}if(e.startsWith(t==="firrtl"?";":"#"))return"comment";if(e.startsWith('"'))return"string";if(Hn.test(e))return"keyword";if(In.test(e))return"type";if(qn.test(e))return"function";if(/^-?\d/.test(e))return"number";if(/^[<>=:]+$/.test(e))return"punct";return""}function On(e,t="yodl"){if(t==="plaintext")return ct(e);let i=new RegExp(`(${t==="rtlil"?"#[^\\n]*":t==="firrtl"?";[^\\n]*":"\\/\\/[^\\n]*"}|"(?:[^"\\\\\\n]|\\\\.)*"|\\b\\w+!|${t==="yodl"?"\\b\\d+":"-?\\b\\d+"}(?:'[bhod]?[\\da-fA-F_]+)?\\b|\\b[a-zA-Z_]\\w*\\b|[=<>+\\-*/%:?.&|^~!]+)`,"g");return e.split(i).map((l)=>{let s=Nn(l,t);return s?`<span class="token-${s}">${ct(l)}</span>`:ct(l)}).join("")}function jt(e,t="yodl"){return e.replace(/\n$/,"").split(`
`).map((o,i)=>`<div class="code-line"><span class="ln">${i+1}</span><span class="lt">${On(o,t)||" "}</span></div>`).join("")}var re=(e)=>document.getElementById(e),Be=(e)=>String(e).padStart(2,"0"),Ke=(e,t)=>`./playground.html?mode=docs&chapter=${e}${t?`#${t}`:""}`;function q(e,t,n){let o=document.createElement(e);if(t)o.className=t;if(n!==void 0)o.textContent=n;return o}function Bt(e){let t=new Te,n,o,i,l=re("docs-main"),s=re("docs-content");function d(){return n??=fetch("./book/chapters.json").then((h)=>{if(!h.ok)throw Error("The language guide could not be loaded.");return h.json()}).catch((h)=>{throw n=void 0,h})}function y(h,m,w){let r=q("a");return r.href=Ke(h,m),r.append(...typeof w==="string"?[w]:w),r.addEventListener("click",(c)=>{if(c.metaKey||c.ctrlKey||c.shiftKey||c.button!==0)return;c.preventDefault(),e.navigate(h,m)}),r}function L(h,m){re("docs-chapters").replaceChildren(...h.chapters.map((w,r)=>{let c=y(w.slug,void 0,[q("span",void 0,Be(r+1)),w.title]);if(w===m)c.setAttribute("aria-current","page");return c})),re("docs-version").textContent=`Yodl ${h.version} · ${h.revision}`,re("docs-toc").replaceChildren(...m.headings.filter((w)=>w.level>1&&w.level<4).map((w)=>{let r=y(m.slug,w.id,w.title);return r.className=`toc-level-${w.level}`,r})),E()}function E(){i?.disconnect();let h=Array.from(re("docs-toc").querySelectorAll("a"));if(!h.length||typeof IntersectionObserver>"u")return;i=new IntersectionObserver((m)=>{for(let w of m)if(w.isIntersecting)for(let r of h)if(r.href.endsWith(`#${w.target.id}`))r.setAttribute("aria-current","location");else r.removeAttribute("aria-current")},{root:l,rootMargin:"0px 0px -70% 0px"});for(let m of Array.from(s.querySelectorAll("h2[id], h3[id]")))i.observe(m)}function Q(h,m){let w=h.chapters.indexOf(m),r=q("p","docs-meta",`Chapter ${Be(w+1)} of ${Be(h.chapters.length)}`),c=q("article");c.innerHTML=m.html;let f=[r,c],x=Ne[m.slug]??[];if(x.length){let R=q("section","practice");R.append(q("p","section-label","Practice in the tour"));for(let H of x){let W=q("button");W.type="button",W.append(q("strong",void 0,H.title),q("span",void 0,"→")),W.addEventListener("click",()=>e.openLesson(H.id)),R.append(W)}f.push(R)}let p=h.chapters[w-1],k=h.chapters[w+1],u=q("nav","page-navigation");u.setAttribute("aria-label","Previous and next chapters");let M=(R,H)=>R?y(R.slug,void 0,[q("small",void 0,H),R.title]):q("span");u.append(M(p,"← Previous"),M(k,"Next →"));let S=q("footer","article-footer"),A=q("a",void 0,"Edit this page ↗");A.href=`https://github.com/nathsou/yodl/edit/main/book/src/${m.slug}.md`,S.append(A,q("span",void 0,"Examples compile locally in your browser.")),f.push(u,S),s.replaceChildren(...f),s.className="docs-content",v(h,m);for(let R of m.examples)K(m,R)}function v(h,m){for(let w of Array.from(s.querySelectorAll("article a[href]"))){let r=w.getAttribute("href"),c=/^#(.+)$/.exec(r),f=/^\.?\/?([\w-]+)\.html(?:#(.+))?$/.exec(r),x=f&&h.chapters.find((u)=>u.slug===f[1]);if(!c&&!x)continue;let p=c?m.slug:x.slug,k=c?c[1]:f[2];w.href=Ke(p,k),w.addEventListener("click",(u)=>{if(u.metaKey||u.ctrlKey||u.shiftKey||u.button!==0)return;u.preventDefault(),e.navigate(p,k)})}}function K(h,m){let w=s.querySelector(`#${CSS.escape(m.id)}`);if(!w||!m.live)return;let r=w.querySelector('[data-action="compile"]');w.querySelector('[data-action="playground"]').onclick=()=>e.openExample(h,m,m.source,ie(w)??m.stage);let c=async(f)=>{let x=se(w,m,f,c),p=x.querySelector(".example-status");p.dataset.state="",p.firstChild.textContent="● Compiling · ",r.disabled=!0;let k=await t.compile(m.id,{source:m.source,path:m.path,files:m.files,stage:f});if(r.disabled=!1,!k||!w.isConnected)return;let u=x.querySelector(".example-output-body");if(k.error!==void 0){let M=m.expect==="error";p.dataset.state=M?"expected":"error",p.firstChild.textContent=M?"● Expected compiler error · ":"● Compilation failed · ";let S=q("pre","diagnostic",k.error);S.tabIndex=0,u.replaceChildren(S)}else{p.dataset.state="success",p.firstChild.textContent="● Compiled · ",p.title=`${Math.round(k.duration)} ms · Yodl ${V}`;let M=q("div","code-lines");M.tabIndex=0,M.innerHTML=jt(k.output??"",j[f].language),u.replaceChildren(M)}};r.onclick=()=>void c(ie(w)??m.stage)}let V="",ie=(h)=>h.querySelector(".example-output select")?.value;function se(h,m,w,r){let c=h.querySelector(".example-output");if(c)return c.hidden=!1,c;c=q("div","example-output");let f=q("div","example-output-header"),x=q("span","example-status");x.append(document.createTextNode("● Compiled · "));let p=q("select");p.setAttribute("aria-label","Compiler output stage");for(let[M,S]of Object.entries(j)){if(M==="test"&&m.stage!=="test")continue;let A=new Option(S.label,M);if(A.disabled=m.unsupported.includes(M),A.disabled)A.text+=" (unavailable)";p.add(A)}p.value=w,p.title=j[w].description,p.onchange=()=>{p.title=j[p.value].description,r(p.value)};let k=q("span","stage-select");k.append(p),x.append(k);let u=q("button",void 0,"Hide");return u.type="button",u.onclick=()=>{c.hidden=!0},f.append(x,u),c.append(f,q("div","example-output-body")),h.append(c),c}function oe(h){let m=h?s.querySelector(`#${CSS.escape(h)}`):null;if(m)m.scrollIntoView();else l.scrollTop=0}return{load:d,async show(h,m){let w=re("docs-loading"),r;try{w.hidden=!1,w.textContent="Loading the language guide…",r=await d()}catch(x){w.textContent=`${x.message} Check your connection and reload the page.`;return}w.hidden=!0,V=r.version;let c=r.chapters.find((x)=>x.slug===h)??r.chapters[0],f=c!==o;if(f){if(o)for(let x of o.examples)t.cancel(x.id);if(o=c,L(r,c),Q(r,c),document.title=`${c.title} · Yodl`,re("docs-current").textContent=`${Be(r.chapters.indexOf(c)+1)} · ${c.title}`,matchMedia("(max-width: 820px)").matches)re("chapter-menu").open=!1}if(f||m)oe(m);return c},get current(){return o},dispose(){t.dispose()}}}var ue=(e)=>document.getElementById(e);function Kt(e){let t=ue("search-dialog"),n=ue("search-input"),o=ue("search-results"),i=ue("search-status"),l,s,d=e.lessons.map((v,K)=>({title:v.title,where:`Tour · Lesson ${String(K+1).padStart(2,"0")}`,excerpt:v.intro,text:[v.title,v.topic,v.intro,...v.concepts,v.observe,v.challenge].join(" "),go:()=>e.openLesson(v.id)}));async function y(){if(l)return!0;try{return await(s??=fetch("./book/search.json").then((v)=>{if(!v.ok)throw Error("Search unavailable");return v.json()}).then((v)=>{l=v}).finally(()=>{s=void 0})),!0}catch{return!1}}async function L(){let v=n.value.toLowerCase().trim();i.textContent=v?"Searching…":"Type to search the guide and the tour.";let K=await y();if(n.value.toLowerCase().trim()!==v)return;if(o.replaceChildren(),!v)return;let V=v.split(/\s+/),ie=(l??[]).map((h)=>({title:h.title,where:`Docs · ${h.chapter}`,excerpt:h.text,text:`${h.title} ${h.text}`,go:()=>e.openDoc(h.slug,h.id)})),se=[...d,...ie].filter((h)=>V.every((m)=>h.text.toLowerCase().includes(m))).sort((h,m)=>Number(m.title.toLowerCase().includes(v))-Number(h.title.toLowerCase().includes(v))).slice(0,30),oe=K?"":" The guide index could not load; showing lessons only.";i.textContent=(se.length?`${se.length} result${se.length===1?"":"s"}`:"No results. Try a concept, operator, or built-in name.")+oe;for(let h of se){let m=document.createElement("a");m.href="#",m.addEventListener("click",(x)=>{x.preventDefault(),t.close(),h.go()});let w=document.createElement("strong");w.textContent=h.title;let r=document.createElement("small");r.textContent=h.where;let c=document.createElement("span"),f=Math.max(0,h.excerpt.toLowerCase().indexOf(V[0])-50);c.textContent=`${f?"…":""}${h.excerpt.slice(f,f+160)}${h.excerpt.length>f+160?"…":""}`,m.append(w,r,c),o.append(m)}}let E=()=>{if(!t.open)t.showModal();n.focus(),n.select(),L()};ue("search-open").addEventListener("click",E),ue("search-close").addEventListener("click",()=>t.close()),n.addEventListener("input",()=>void L()),t.addEventListener("click",(v)=>{if(v.target===t)t.close()}),t.addEventListener("keydown",(v)=>{let K=Array.from(o.querySelectorAll("a")),V=K.indexOf(document.activeElement);if(v.key==="ArrowDown")v.preventDefault(),K[Math.min(K.length-1,V+1)]?.focus();if(v.key==="ArrowUp")if(v.preventDefault(),V<=0)n.focus();else K[V-1].focus();if(v.key==="Enter"&&document.activeElement===n)K[0]?.click()});let Q=/Mac|iPhone|iPad/.test(navigator.platform);return ue("search-shortcut").textContent=Q?"⌘K":"Ctrl K",document.addEventListener("keydown",(v)=>{let K=v.target;if((v.metaKey||v.ctrlKey)&&v.key.toLowerCase()==="k"){v.preventDefault(),E();return}if(v.key==="/"&&!v.metaKey&&!v.ctrlKey&&!K.closest('input, textarea, select, [contenteditable="true"], .monaco-editor')&&!document.querySelector("dialog[open]"))v.preventDefault(),E()}),{open:E}}class dt{id=0;pending=new Map;worker;onDiagnostics=()=>{};onError=()=>{};constructor(e){this.worker=e??new Worker(new URL("./lsp-worker-xhqyywt1.js",import.meta.url),{type:"module"}),this.worker.onmessage=(t)=>{let n=t.data;if(n.id!==void 0){let o=this.pending.get(n.id);if(!o)return;if(this.pending.delete(n.id),clearTimeout(o.timer),n.error)o.reject(Error(n.error.message));else o.resolve(n.result)}else if(n.method==="textDocument/publishDiagnostics")this.onDiagnostics(n.params.uri,n.params.diagnostics,n.params.version);else if(n.method==="window/logMessage"&&n.params.type===1)this.onError(n.params.message)},this.worker.onerror=(t)=>{this.fail(Error(t.message||"Language worker failed")),this.onError(t.message||"Language worker failed")}}request(e,t={},n){let o=++this.id,i;return new Promise((s,d)=>{if(n?.isCancellationRequested){s(null);return}let y=setTimeout(()=>{this.pending.delete(o),d(Error(`Language service timed out: ${e}`))},30000);this.pending.set(o,{resolve:s,reject:d,timer:y}),i=n?.onCancellationRequested(()=>{let L=this.pending.get(o);if(L)this.pending.delete(o),clearTimeout(L.timer),L.resolve(null),this.notify("$/cancelRequest",{id:o})}),this.worker.postMessage({jsonrpc:"2.0",id:o,method:e,params:t})}).finally(()=>i?.dispose())}notify(e,t){this.worker.postMessage({jsonrpc:"2.0",method:e,params:t})}fail(e){for(let t of this.pending.values())clearTimeout(t.timer),t.reject(e);this.pending.clear()}dispose(){this.fail(Error("Language client disposed")),this.worker.terminate()}}var Me=(e)=>`yodl:///workspace/${e.split("/").map(encodeURIComponent).join("/")}`,ve=(e)=>e.startsWith("yodl:///workspace/")?e.slice(18).split("/").map(decodeURIComponent).join("/"):e,G=(e)=>({line:e.lineNumber-1,character:e.column-1}),Wt=(e)=>({start:G({lineNumber:e.startLineNumber,column:e.startColumn}),end:G({lineNumber:e.endLineNumber,column:e.endColumn})}),Z=(e)=>({startLineNumber:e.start.line+1,startColumn:e.start.character+1,endLineNumber:e.end.line+1,endColumn:e.end.character+1});class ut{monaco;open;problems;client;models=new Map;uris=new Map;listeners=new Map;registrations=[];ready;epoch=0;errors=new Map;model(e){return this.models.get(e.startsWith("yodl-builtin:")?e:Me(e))}constructor(e,t,n,o,i=new dt){this.monaco=e;this.open=t;this.problems=n;this.client=i,this.client.onError=o,this.ready=i.request("initialize",{capabilities:{general:{positionEncodings:["utf-16"]}}}).then((l)=>(i.notify("initialized",{}),l)),i.onDiagnostics=(l,s,d)=>{let y=this.models.get(l);if(d!==void 0&&y&&d!==y.getVersionId())return;if(this.errors.set(l,s),y)this.markers(y,s);this.problems([...this.errors].flatMap(([L,E])=>E.map((Q)=>({...Q,uri:ve(L)}))))},this.register(),this.registrations.push(e.editor.registerEditorOpener({openCodeEditor:(l,s,d)=>{let y=e.editor.getModel(s),L=this.uris.get(y);if(!L)return!1;return this.open(ve(L),d),!0}}))}markers(e,t){this.monaco.editor.setModelMarkers(e,"yodl",t.map((n)=>({...Z(n.range),message:n.message,code:n.code,source:"yodl",severity:n.severity===2?this.monaco.MarkerSeverity.Warning:this.monaco.MarkerSeverity.Error,relatedInformation:n.relatedInformation?.map((o)=>({resource:this.monaco.Uri.parse(o.location.uri),...Z(o.location.range),message:o.message}))})))}attach(e,t){let n=t.startsWith("yodl-builtin:")?t:Me(t);if(this.uris.get(e)===n)return;if(this.uris.has(e))this.detach(e);this.uris.set(e,n),this.models.set(n,e),this.ready.then(()=>{if(this.uris.get(e)===n)this.client.notify("textDocument/didOpen",{textDocument:{uri:n,languageId:"yodl",version:e.getVersionId(),text:e.getValue()}})}),this.listeners.set(e,[e.onDidChangeContent(()=>{this.ready.then(()=>{if(this.uris.get(e)===n)this.client.notify("textDocument/didChange",{textDocument:{uri:n,version:e.getVersionId()},contentChanges:[{text:e.getValue()}]})})}),e.onWillDispose(()=>this.detach(e))]),this.markers(e,this.errors.get(n)??[])}detach(e){let t=this.uris.get(e);for(let n of this.listeners.get(e)??[])n.dispose();if(this.listeners.delete(e),this.uris.delete(e),t)this.models.delete(t),this.errors.delete(t),this.ready.then(()=>this.client.notify("textDocument/didClose",{textDocument:{uri:t}}));this.monaco.editor.setModelMarkers(e,"yodl",[])}async workspace(e,t,n){let o=++this.epoch;this.attach(t,n),await this.ready;let i=Object.fromEntries(Object.entries(e).map(([s,d])=>[Me(s),d]));await this.client.request("yodl/setFiles",{files:i});let l=await this.client.request("yodl/dependencies",{uri:Me(n)});if(o!==this.epoch)return;return Object.fromEntries(Object.entries(l).map(([s,d])=>[ve(s),d]))}async query(e,t,n,o){let i=this.uris.get(e),l=e.getVersionId();if(!i)return null;await this.ready;let s=await this.client.request(`textDocument/${t}`,{textDocument:{uri:i},...n},o);return this.uris.get(e)===i&&e.getVersionId()===l?s:null}async ensure(e){if(this.models.has(e))return this.models.get(e);let t=await this.client.request("yodl/source",{uri:e});if(t===null)return;if(this.models.has(e))return this.models.get(e);let n=this.monaco.editor.createModel(t,"yodl",this.monaco.Uri.parse(e));return this.attach(n,ve(e)),this.open(ve(e),void 0),n}async locations(e){if(!e)return[];return(await Promise.all((Array.isArray(e)?e:[e]).map(async(t)=>{let n=await this.ensure(t.uri);return n?{uri:n.uri,range:Z(t.range)}:null}))).filter(Boolean)}async edits(e){if(!e?.changes)return;let t=[];for(let[n,o]of Object.entries(e.changes)){let i=await this.ensure(n);if(!i)return;for(let l of o)t.push({resource:i.uri,versionId:i.getVersionId(),textEdit:{range:Z(l.range),text:l.newText}})}return{edits:t}}register(){let e=this.monaco.languages,t=(o,i)=>this.registrations.push(e[o]("yodl",i));t("registerHoverProvider",{provideHover:async(o,i,l)=>{let s=await this.query(o,"hover",{position:G(i)},l);return s?{range:s.range&&Z(s.range),contents:[{value:s.contents.value}]}:null}});for(let[o,i]of[["Definition","definition"],["Declaration","declaration"],["TypeDefinition","typeDefinition"]])t(`register${o}Provider`,{[`provide${o}`]:async(l,s,d)=>this.locations(await this.query(l,i,{position:G(s)},d))});t("registerReferenceProvider",{provideReferences:async(o,i,l,s)=>this.locations(await this.query(o,"references",{position:G(i),context:l},s))}),t("registerDocumentHighlightProvider",{provideDocumentHighlights:async(o,i,l)=>(await this.query(o,"documentHighlight",{position:G(i)},l)??[]).map((s)=>({...s,range:Z(s.range)}))});let n=(o)=>({...o,kind:o.kind-1,range:Z(o.range),selectionRange:Z(o.selectionRange),children:o.children?.map(n)});t("registerDocumentSymbolProvider",{provideDocumentSymbols:async(o,i)=>(await this.query(o,"documentSymbol",{},i)??[]).map(n)}),t("registerCompletionItemProvider",{triggerCharacters:[".",":","["],provideCompletionItems:async(o,i,l,s)=>{let d=await this.query(o,"completion",{position:G(i)},s),y=[0,18,0,1,2,3,4,7,5,8,9,12,13,15,17,28,19,20,21,23,16,14,6,10,11,24];return{incomplete:d?.isIncomplete??!1,suggestions:(d?.items??[]).map((L)=>({label:L.label,detail:L.detail,kind:y[L.kind??1],insertText:L.textEdit?.newText??L.label,range:L.textEdit?Z(L.textEdit.range):void 0}))}}}),t("registerSignatureHelpProvider",{signatureHelpTriggerCharacters:["(","[",",",":"],signatureHelpRetriggerCharacters:[","],provideSignatureHelp:async(o,i,l)=>{let s=await this.query(o,"signatureHelp",{position:G(i)},l);return s?{value:s,dispose(){}}:null}}),t("registerRenameProvider",{resolveRenameLocation:async(o,i,l)=>{try{let s=await this.query(o,"prepareRename",{position:G(i)},l);return s?{range:Z(s.range),text:s.placeholder}:{rejectReason:"No renameable symbol here"}}catch(s){return{rejectReason:s.message}}},provideRenameEdits:async(o,i,l,s)=>{try{return await this.edits(await this.query(o,"rename",{position:G(i),newName:l},s))}catch(d){return{edits:[],rejectReason:d.message}}}}),t("registerCodeActionProvider",{providedCodeActionKinds:["quickfix"],provideCodeActions:async(o,i,l,s)=>{let d=await this.query(o,"codeAction",{range:Wt(i),context:{diagnostics:[],only:l.only?[l.only]:void 0}},s);return{actions:await Promise.all((d??[]).map(async(y)=>({title:y.title,kind:y.kind,isPreferred:y.isPreferred,edit:await this.edits(y.edit)}))),dispose(){}}}}),t("registerFoldingRangeProvider",{provideFoldingRanges:async(o,i,l)=>(await this.query(o,"foldingRange",{},l)??[]).map((s)=>({start:s.startLine+1,end:s.endLine+1}))}),t("registerSelectionRangeProvider",{provideSelectionRanges:async(o,i,l)=>(await this.query(o,"selectionRange",{positions:i.map(G)},l)??[]).map((d)=>{let y=[];while(d)y.push({range:Z(d.range)}),d=d.parent;return y})}),t("registerDocumentSemanticTokensProvider",{getLegend:()=>({tokenTypes:["namespace","type","class","parameter","variable","property","function","keyword","number","string","operator"],tokenModifiers:["declaration","readonly"]}),provideDocumentSemanticTokens:async(o,i,l)=>{let s=await this.query(o,"semanticTokens/full",{},l);return s?{data:Uint32Array.from(s.data)}:null},releaseDocumentSemanticTokens(){}})}dispose(){for(let e of[...this.uris.keys()])this.detach(e);for(let e of this.registrations)e.dispose();this.client.dispose()}}var a=(e)=>document.getElementById(e),b=(e)=>a(e),Gt="yodl-playground-v2:",bt=!0;function fe(e){try{return localStorage.getItem(Gt+e)}catch{return bt=!1,null}}function me(e,t){try{localStorage.setItem(Gt+e,t)}catch{bt=!1}}function ne(e){let t=a("notice");t.textContent=e;let n=document.createElement("button");n.textContent="Dismiss",n.addEventListener("click",()=>{t.hidden=!0}),t.append(n),t.hidden=!1}function ce(e,t="idle"){a("compile-status").textContent=e,a("compile-status").dataset.state=t}var pt=/Mac|iPhone|iPad/.test(navigator.platform);Dt(document.querySelector(".site-header"),()=>je());At(document.querySelector(".accent-picker"),()=>je());var Zt=(e)=>e==="tour"?"tour":"playground",ht=(e)=>`tour/${e.file}`,ee=(e)=>e.split("/").at(-1),F="tour",$e,gt,C={...it};try{let e=JSON.parse(fe("selection")??"null");if(Le(e))C=e}catch{}var _,Fn=()=>_?`shared:${_.code}`:"",D=()=>_?.entryPath??C.path,g,Ut,xe=!1,Y,Pe,U="",_e="",B=new Map,Ue=new Map,te=()=>Y.getValue();function ke(e){let t=e===D()?Y:B.get(e);if(!t)return;if(U)Ue.set(U,g.input.saveViewState());U=e,g.input.setModel(t),g.input.updateOptions({readOnly:e!==D(),ariaLabel:`${e}${e===D()?", main source":", imported, read only"}`});let n=Ue.get(e);if(n)g.input.restoreViewState(n);wt(),g.input.layout()}function wt(){let e=U!==D(),t=B.size>0;a("source-files").hidden=!t,a("editors").dataset.imports=String(t),a("input-filename").textContent=ee(U||D()),a("input-filename").title=U,a("source-kind").textContent=e?"Imported · read only":"",a("source-kind").hidden=!e,a("draft-badge").hidden=e||!Y||te()===He(),b("reset-button").disabled=e,a("source-files").replaceChildren(...[D(),...B.keys()].map((n)=>{let o=document.createElement("button");return o.textContent=ee(n),o.title=n===D()?`${n} · compile and simulation target`:`${n} · imported, read only`,o.setAttribute("aria-pressed",String(n===U)),o.onclick=()=>ke(n),o}))}function Qt(e){let t=Object.entries(e).filter(([o])=>o!==D()&&o.endsWith(".yodl")),n=new Set(t.map(([o])=>o));if(U!==D()&&!n.has(U))ke(D());for(let[o,i]of B)if(!n.has(o))i.dispose(),B.delete(o),Ue.delete(o);for(let[o,i]of t){let l=B.get(o);if(!l){let s=P.editor.createModel(i,"yodl");B.set(o,s),Pe?.attach(s,o),s.onDidChangeContent(()=>{if(!xe)Qe()})}else if(l.getValue()!==i)l.setValue(i)}wt()}function jn(){U="",Ue.clear(),g.input.setModel(Y);for(let e of B.values())e.dispose();B.clear(),ke(D())}var ze=0,X="",Ye=-1,Xt=new Te,ft=0,Vt,Je=()=>({...we,..._?.files,...Object.fromEntries([...B].filter(([e])=>!e.startsWith("yodl-builtin:")).map(([e,t])=>[e,t.getValue()]))});async function en(){let e=++ft;try{let t=await Pe?.workspace(Je(),Y,D());if(e===ft&&t)Qt(t)}catch(t){ne(`Language service: ${t.message}`)}}function Bn(){++ft,clearTimeout(Vt),Vt=setTimeout(en,150)}var tn=(e)=>/\btest\s+(?:"|for\b)/.test(e),he=Ft({request:()=>({source:te(),path:D(),files:Je()}),setStatus:ce}),nn=0,yt=0,le=null,Kn=`// Start a new circuit here.
module Top(a: bool) -> (q: bool) {
    q = a
}
`,Ge=(e)=>we[e]??Kn,He=()=>_?_.source:Ge(C.path);function Wn(e){let t=2166136261;for(let n=0;n<e.length;n++)t^=e.charCodeAt(n),t=Math.imul(t,16777619);return(t>>>0).toString(36)}var on=(e)=>`draft:${e}:${Wn(Ge(e))}`,Ie=()=>Fn()||on(C.path),Un=12;function rn(){try{let e=JSON.parse(fe("drafts")??"[]");return Array.isArray(e)?e.filter((t)=>typeof t?.key==="string"&&typeof t.label==="string"&&typeof t.updated==="number"):[]}catch{return[]}}function Vn(){if(C.mode!=="examples"&&!_)return;let e=Ie(),t=rn(),n=t.findIndex((i)=>i.key===e);if(te()===He()){if(n<0)return;t.splice(n,1)}else{if(n===0&&Date.now()-t[0].updated<30000)return;if(n>=0)t.splice(n,1);let i=_?`Shared · ${ee(_.entryPath??_.path)}`:C.path===J?"scratch.yodl":ee(C.path);t.unshift({key:e,path:C.path,label:i,updated:Date.now(),..._?{shared:!0}:{}})}me("drafts",JSON.stringify(t.slice(0,Un))),an()}function zn(e){let t=Math.floor((Date.now()-e)/60000);if(t<1)return"Just now";if(t<60)return`${t} min ago`;let n=Math.floor(t/60);if(n<24)return`${n} h ago`;let o=Math.floor(n/24);return o===1?"Yesterday":o<14?`${o} days ago`:new Date(e).toLocaleDateString()}function De(){if(!Y)return;if(me(Ie(),te()),!_)me("selection",JSON.stringify(C));a("save-status").textContent=bt?"Draft saved locally":"Draft not saved · storage unavailable",a("draft-badge").hidden=U!==D()||te()===He(),Vn()}var ye=()=>I.findIndex((e)=>ht(e)===C.path),Yn=(e)=>Object.entries(Ne).find(([,t])=>t.some((n)=>n.id===e))?.[0],sn=new Map,Jn=(e)=>{let t=e.replace(/^\d+_/,"").replaceAll("_"," ");return t[0].toUpperCase()+t.slice(1)},Ae=(e)=>String(e).padStart(2,"0");function Ze(){let e=ye(),t=I[e];if(!t)return;let n=document.createElement("span");n.className="lesson-prefix",n.textContent="Tour · ",a("lesson-position").replaceChildren(n,`Lesson ${Ae(e+1)} of ${I.length}`),kt(),a("lesson-topic").textContent=t.topic,a("lesson-title").textContent=t.title,a("lesson-intro").textContent=t.intro,a("lesson-observe").textContent=t.observe,a("lesson-challenge").textContent=t.challenge,a("lesson-concepts").replaceChildren(...t.concepts.map((s,d)=>{let y=document.createElement("li"),L=document.createElement("span");L.className="n",L.textContent=Ae(d+1);let E=document.createElement("span");return E.textContent=s,y.append(L,E),y})),b("suggested-stage").textContent=`Open ${j[t.stage].label} →`;let o=Yn(t.id);if(a("lesson-reference").hidden=!o,o){let s=a("related-docs");s.textContent=sn.get(o)??Jn(o),s.href=Ke(o),s.onclick=(d)=>{d.preventDefault(),O({section:"docs",chapter:o})}}let i=I[e-1],l=I[e+1];b("previous-lesson").disabled=!i,a("previous-title").textContent=i?.title??"",b("next-lesson").disabled=!1,a("next-title").textContent=l?.title??"Explore the Playground";for(let[s,d]of Array.from(a("lesson-progress").children).entries())if(s===e)d.setAttribute("aria-current","step");else d.removeAttribute("aria-current");for(let[s,d]of Array.from(a("lesson-list").children).entries())if(s===e)d.setAttribute("aria-current","step");else d.removeAttribute("aria-current")}function Gn(){a("lesson-progress").style.setProperty("--lessons",String(I.length)),a("lesson-progress").replaceChildren(...I.map((e,t)=>{let n=document.createElement("button");return n.type="button",n.title=`${Ae(t+1)} · ${e.title}`,n.setAttribute("aria-label",`Lesson ${t+1}: ${e.title}`),n.onclick=()=>void O({section:"tour",lesson:e.id}),n})),a("lesson-list").replaceChildren(...I.map((e,t)=>{let n=document.createElement("button");return n.type="button",n.innerHTML='<span class="n"></span><span><strong></strong><small></small></span>',n.querySelector(".n").textContent=Ae(t+1),n.querySelector("strong").textContent=e.title,n.querySelector("small").textContent=e.topic,n.onclick=()=>{qe(!1),O({section:"tour",lesson:e.id})},n}))}function qe(e){if(a("lesson-list-scrim").hidden=!e,b("lesson-list-button").setAttribute("aria-expanded",String(e)),e)a("lesson-list").querySelector("[aria-current]")?.scrollIntoView({block:"nearest"})}function Zn(e){let t=we[e]??"";return`${t.split(`
`).length} lines${t.includes("@simulation")?" · simulation":""}`}function vt(){kt(),a("example-list").replaceChildren(...Ee.map((e)=>{let t=document.createElement("button");t.type="button",t.className="entry";let n=!_&&C.path===e;if(n)t.setAttribute("aria-current","true");let o=document.createElement("span");o.className="entry-name",o.textContent=ee(e).replace(/\.yodl$/,"");let i=document.createElement("span");return i.className="entry-note",i.textContent=n?ee(e):Zn(e),t.append(o,i),t.onclick=()=>{me("last:examples",e),de(!1),O({section:"playground",path:e})},t})),an()}function an(){let e=rn().filter((t)=>t.shared||(t.path===J||Ee.includes(t.path))&&t.key===on(t.path));a("drafts-empty").hidden=e.length>0,a("draft-list").replaceChildren(...e.map((t)=>{let n=document.createElement("button");if(n.type="button",n.className="entry draft",t.key===Ie()&&(C.mode==="examples"||_))n.setAttribute("aria-current","true");let o=document.createElement("span");o.className="entry-name",o.textContent=t.label;let i=document.createElement("span");return i.className="entry-note",i.textContent=zn(t.updated),n.append(o,i),n.onclick=()=>{if(de(!1),t.shared){let l=t.key.slice(7);try{O({section:"shared",shared:yn(st(`#code=${l}`),l)})}catch(s){ne(s.message)}}else O({section:"playground",path:t.path})},n}))}var Qn=()=>C.mode==="tour"?I[ye()]?.stage:void 0,ge=matchMedia("(max-width: 819px)"),Xn=matchMedia("(max-width: 639px)"),Re=fe("sidebar")==="hidden";function xt(){let e=a("editor-view");e.dataset.sidebar=Re?"hidden":"shown";let t=b("sidebar-toggle");t.setAttribute("aria-expanded",String(!Re));let n=F==="tour"?"lesson":"examples";t.title=Re?`Show ${n}`:`Hide ${n}`,t.setAttribute("aria-label",t.title)}function eo(e){Re=e,me("sidebar",e?"hidden":"shown"),xt()}function de(e){let t=a("editor-view");if(t.dataset.sheet==="open"===e)return;if(t.dataset.sheet=e?"open":"closed",b("context-toggle").setAttribute("aria-expanded",String(e)),a("sidebar").inert=ge.matches&&!e,e&&ge.matches)a(F==="tour"?"guide-body":"library").scrollTop=0}function kt(){let e=a("context-label");if(F==="tour"){let t=ye(),n=document.createElement("small");n.textContent=`${Ae(t+1)}/${I.length}  `,e.replaceChildren(n,I[t]?.title??"")}else e.textContent=_?"Examples & drafts · shared circuit":"Examples & drafts";b("context-toggle").title=F==="tour"?"Show or hide the lesson":"Show or hide examples and drafts"}new ResizeObserver(()=>cn()).observe(a("output-view-switch").parentElement);ge.addEventListener("change",()=>{a("sidebar").inert=ge.matches&&a("editor-view").dataset.sheet!=="open"});function ln(){let e=C.stage==="test"||Y!==void 0&&tn(te()),t=Qn();a("stage-tabs").replaceChildren(...Object.keys(j).filter((o)=>o!=="test"||e).map((o)=>{let i=document.createElement("button");if(i.type="button",i.className="stage-tab",i.dataset.stage=o,i.title=j[o].description,i.setAttribute("aria-pressed",String(o===C.stage)),i.append(j[o].short),o===t&&o!==C.stage){let l=document.createElement("span");l.className="suggested",l.title="Suggested for this lesson",i.append(l)}return i.onclick=()=>St(o),i}));let n=a("stage-select");n.replaceChildren(...Array.from(a("stage-tabs").children).map((o)=>{let i=o.dataset.stage;return new Option(`${j[i].label}${i===t?" · suggested":""}`,i)})),n.value=C.stage,n.title=j[C.stage].description,cn()}function cn(){let e=a("output-view-switch").parentElement,t=a("stage-tabs").scrollWidth+a("output-view-switch").offsetWidth+24;if(e.clientWidth>0&&t>e.clientWidth)e.dataset.compact="";else delete e.dataset.compact}function Se(e){a("output-pane").dataset.view=e,b("view-output").setAttribute("aria-pressed",String(e==="output")),b("view-simulate").setAttribute("aria-pressed",String(e==="simulation")),g?.output.layout()}function Ve(){let e=j[C.stage];if(a("stage-description").textContent=e.description,a("stage-description").title=e.description,g)P.editor.setModelLanguage(g.output.getModel(),e.language);ln()}function dn(){Se("output"),wt(),Ze(),vt(),a("related-docs-menu").hidden=!_?.origin,Ve()}function mt(){for(let t of Array.from(document.querySelectorAll(".mode-switch button")))t.setAttribute("aria-pressed",String(t.dataset.mode===F));let e=F!=="docs";if(a("editor-view").hidden=!e,a("docs-view").hidden=e,a("editor-view").dataset.section=F,a("guide").hidden=F!=="tour",a("library").hidden=F!=="playground",xt(),kt(),e)document.title=F==="tour"?"Tour · Yodl":"Playground · Yodl",g?.input.layout(),g?.output.layout();else he.stop()}function un(){if(a("problems").hidden=!0,le=null,!Y)return;for(let e of[Y,...B.values()])P.editor.setModelMarkers(e,"yodl",[])}function Qe(){if(Xt.cancel("playground"),he.stop(),ze++,Bn(),yt=++nn,un(),b("copy-output").disabled=!0,b("output-download").disabled=!0,b("download-output").disabled=!0,ce(X?"Source changed · output is out of date":"Ready to compile"),a("stage-tabs").querySelector('[data-stage="test"]')!==null!==(C.stage==="test"||tn(te())))ln()}function zt(e,t){if(g)De();if(_=t,C=e,Ze(),vt(),!g)return;jn(),he.clear(),xe=!0,g.input.setValue(fe(Ie())??_?.source??Ge(C.path)),xe=!1,g.input.setScrollTop(0),g.output.setValue(""),X="",Ye=-1,dn(),De(),Qe(),pe()}function St(e){if(C.stage=e,!g){Ve();return}he.clearFrame(),g.output.setValue(""),X="",Ve(),Se("output"),De(),Qe(),pe()}function Ce(e){a("editors").dataset.view=e,b("source-tab").setAttribute("aria-pressed",String(e==="source")),b("output-tab").setAttribute("aria-pressed",String(e==="output")),g?.input.layout(),g?.output.layout()}function to(e,t=[]){Se("output"),a("problems").hidden=!1,a("error-message").textContent=e;let n=t.find((o)=>o.range&&(o.uri===D()||B.has(o.uri)));_e=n?.uri??D(),le=n?be(n,_e):null,b("jump-error").hidden=le===null;for(let o of[D(),...B.keys()]){let i=o===D()?Y:B.get(o),l=t.flatMap((s)=>{let d=be(s,o);return d?[{...i.validateRange(d),message:s.message,code:s.code,severity:s.severity===2?P.MarkerSeverity.Warning:P.MarkerSeverity.Error}]:[]});P.editor.setModelMarkers(i,"yodl",l)}ce(X?"Compilation failed · showing previous output":"Compilation failed · check diagnostics","error")}function no(e){let t=e.find((n)=>n.range&&(n.uri===D()||B.has(n.uri)));a("problems").hidden=e.length===0,a("error-message").replaceChildren(...e.map((n)=>{let o=document.createElement("button");o.type="button",o.className="diagnostic",o.textContent=`${n.uri?`${ee(n.uri)}:${(n.range?.start.line??0)+1}:${(n.range?.start.character??0)+1}: `:""}${n.message}${n.code?` [${n.code}]`:""}${n.notes?.length?`
${n.notes.join(`
`)}`:""}`;let i=be(n,n.uri??D());return o.disabled=!i||n.uri!==D()&&!B.has(n.uri),o.onclick=()=>{if(!i)return;Ce("source"),ke(n.uri??D()),g.input.setSelection(i),g.input.revealRangeInCenter(i),g.input.focus()},o})),_e=t?.uri??D(),le=t?be(t,_e):null,b("jump-error").hidden=le===null}async function pe(){if(!g)return;he.stop(),he.clearFrame();let e=++nn;yt=e;let t=ze;un(),ce("Compiling…","loading");let n=await Xt.compile("playground",{source:te(),path:D(),stage:C.stage,files:Je()});if(!n||e!==yt)return;if(n.sources)Qt(n.sources);if(n.error!==void 0){to(n.error,n.diagnostics);return}X=n.output??"",Ye=t,g.output.setValue(X),Ve(),Se("output"),b("copy-output").disabled=!X,b("output-download").disabled=!X,b("download-output").disabled=!X,ce(`Compiled · ${Math.round(n.duration)} ms`,"success")}function pn(e,t){let n=URL.createObjectURL(new Blob([t],{type:"text/plain;charset=utf-8"})),o=document.createElement("a");o.href=n,o.download=e,o.click(),setTimeout(()=>URL.revokeObjectURL(n),1000)}async function mn(e,t){try{await navigator.clipboard.writeText(e);let n=t.textContent;t.textContent="Copied",setTimeout(()=>{t.textContent=n},1800)}catch{if(ne("Clipboard access is unavailable. Select the text and use your browser’s Copy command."),t.id==="copy-share")a("share-url").select();else g.output.focus(),g.output.setSelection(g.output.getModel().getFullModelRange())}}function hn(){if(Ye===ze)pn(`${ee(C.path).replace(/\.yodl$/,"")}.${j[C.stage].extension}`,X)}function Xe(e){a("file-menu").hidden=!e,b("menu-button").setAttribute("aria-expanded",String(e))}function gn(){if(!g)return;let e=new URL(location.href);e.search="";let t=Object.fromEntries(Object.entries(Je()).filter(([n,o])=>we[n]!==o));if(e.hash=`code=${Fe({...C,source:te(),files:t,entryPath:_?.entryPath,origin:_?.origin})}`,e.href.length>32000){ne("This circuit is too large for a reliable share link. Use Download source instead.");return}a("share-url").value=e.href,a("share-dialog").showModal(),a("share-url").select()}function fn(){if(g&&U===D())a("reset-dialog").showModal()}function yn(e,t){return{code:t,mode:e.mode,path:e.path,stage:e.stage,source:e.source,files:e.files??{},entryPath:e.entryPath,origin:e.origin}}function oo(e){if(C.mode===e&&!_)return C.path;let t=fe(`last:${e}`);if(Le({mode:e,path:t,stage:"write_firrtl"}))return t;return e==="tour"?it.path:J}function ro(){let e=new URL(location.href);if(e.search="",e.hash="",F==="docs"){if(e.searchParams.set("mode","docs"),$e)e.searchParams.set("chapter",$e);if(gt)e.hash=gt}else if(_)e.hash=`code=${_.code}`;else if(F==="tour")e.searchParams.set("lesson",I[ye()]?.id??I[0].id);else if(e.searchParams.set("mode","examples"),C.path!==J)e.searchParams.set("example",ee(C.path).replace(/\.yodl$/,""));return e.href}function Yt(e){let t=ro();if(e==="none"||t===location.href)return;if(e==="push")history.pushState(null,"",t);else history.replaceState(null,"",t)}var Jt=0;async function O(e,t="push"){let n=++Jt;if(qe(!1),e.section==="docs"){F="docs",mt(),$e=e.chapter,gt=e.anchor;let o=await et.show(e.chapter,e.anchor);if(n!==Jt)return;if($e=o?.slug??e.chapter,o)document.title=`${o.title} · Yodl`;Yt(t);return}if(e.section==="shared")F=Zt(e.shared.mode),mt(),zt({mode:e.shared.mode,path:e.shared.path,stage:e.shared.stage},e.shared),ne("Shared circuit opened. Your existing lesson and example drafts are kept separately.");else{F=e.section,mt();let o=F==="tour"?"tour":"examples",i=e.section==="tour"?I.find((d)=>d.id===e.lesson):void 0,l=e.section==="playground"&&e.path&&Le({mode:o,path:e.path,stage:"write_firrtl"})?e.path:i?ht(i):oo(o);if(!(!_&&C.mode===o&&C.path===l)){me(`last:${o}`,l);let d=o==="tour"?I.find((y)=>ht(y)===l).stage:"write_firrtl";zt({mode:o,path:l,stage:d})}else if(!g)Ze(),vt();if(e.section==="tour")a("guide-body").scrollTop=0}so(),Yt(t)}function bn(){let e=new URLSearchParams(location.search);if(location.hash.startsWith("#code="))try{let n=location.hash.slice(6);return{section:"shared",shared:yn(st(location.hash),n)}}catch(n){ne(n.message)}if(e.get("mode")==="docs")return{section:"docs",chapter:e.get("chapter")??void 0,anchor:location.hash.slice(1)||void 0};let t=I.find((n)=>n.id===e.get("lesson"));if(t)return{section:"tour",lesson:t.id};if(e.get("mode")==="examples")return{section:"playground",path:Ee.find((o)=>ee(o)===`${e.get("example")}.yodl`)??J};return{section:Zt(C.mode)}}var et=Bt({navigate:(e,t)=>void O({section:"docs",chapter:e,anchor:t}),openLesson:(e)=>void O({section:"tour",lesson:e}),openExample(e,t,n,o){let i={mode:"examples",path:J,stage:o,source:n,files:t.files,entryPath:t.path,origin:`${e.slug}.html#${t.id}`},l=Fe(i);if(l.length>30000){ne("This example is too large for a reliable handoff. Copy the source instead.");return}O({section:"shared",shared:{...i,code:l}})}}),io=Kt({lessons:I,openLesson:(e)=>void O({section:"tour",lesson:e}),openDoc:(e,t)=>void O({section:"docs",chapter:e,anchor:t})});function so(){return Ut??=ao().catch((e)=>{Ut=void 0,ce("Could not load the editor","error"),a("input-panel").textContent="The editor could not load. Check your connection and reload the page.",ne(`Playground startup failed: ${e.message??String(e)}`)})}async function ao(){g=await Nt(),Y=g.input.getModel(),Pe=new ut(P,(e,t)=>{if(e!==D()&&!B.has(e)){let n=Pe?.model(e);if(n)B.set(e,n)}if(ke(e),t){if("startLineNumber"in t)g.input.setSelection(t);else g.input.setPosition(t);g.input.revealPositionInCenter({lineNumber:t.startLineNumber??t.lineNumber,column:t.startColumn??t.column})}},no,(e)=>ne(`Language service: ${e}`)),U=D(),xe=!0,g.input.setValue(fe(Ie())??_?.source??Ge(C.path)),xe=!1,dn(),De();for(let e of[b("compile-button"),b("menu-button"),b("view-simulate")])e.disabled=!1;he.enable(),b("compile-shortcut").textContent=pt?"⌘↵":"Ctrl ↵",a("share-shortcut").textContent=pt?"⌘S":"Ctrl S",a("new-shortcut").textContent=pt?"⌘N":"Ctrl N",g.input.addAction({id:"compile-yodl",label:"Compile Yodl",keybindings:[P.KeyMod.CtrlCmd|P.KeyCode.Enter],run:pe}),g.output.addAction({id:"compile-yodl-output",label:"Compile Yodl",keybindings:[P.KeyMod.CtrlCmd|P.KeyCode.Enter],run:pe});for(let e of[g.input,g.output])e.addCommand(P.KeyMod.CtrlCmd|P.KeyCode.KeyK,()=>io.open());g.input.onDidChangeModelContent(()=>{if(xe||g.input.getModel()!==Y)return;De(),Qe()}),g.input.onDidChangeCursorPosition((e)=>{a("cursor-position").textContent=`Ln ${e.position.lineNumber}, Col ${e.position.column}`}),lo(),ce("Ready to compile"),en(),pe()}function wn(){if(F!=="playground"){O({section:"playground",path:J});return}if(g&&C.path===J&&!_&&te()!==He())fn();else O({section:"playground",path:J})}function lo(){let e=a("resize-handle"),t=a("editors"),n=()=>getComputedStyle(t).getPropertyValue("--split-axis").trim()==="y",o=Number(fe("split")??50);function i(s){o=Math.max(20,Math.min(80,Number.isFinite(s)?s:50)),t.style.setProperty("--split-a",`${o}fr`),t.style.setProperty("--split-b",`${100-o}fr`),e.setAttribute("aria-valuenow",String(Math.round(o))),e.setAttribute("aria-orientation",n()?"horizontal":"vertical")}i(o),e.onpointerdown=(s)=>{e.setPointerCapture(s.pointerId),e.classList.add("dragging"),s.preventDefault()},e.onpointermove=(s)=>{if(!e.hasPointerCapture(s.pointerId))return;let d=t.getBoundingClientRect();i(n()?(s.clientY-d.top)/d.height*100:(s.clientX-d.left)/d.width*100)};let l=()=>{e.classList.remove("dragging"),me("split",String(o))};e.onlostpointercapture=l,e.onpointerup=(s)=>{if(e.hasPointerCapture(s.pointerId))e.releasePointerCapture(s.pointerId)},e.onkeydown=(s)=>{let d=n()?"ArrowUp":"ArrowLeft",y=n()?"ArrowDown":"ArrowRight";if(![d,y,"Home","End"].includes(s.key))return;s.preventDefault(),i(s.key==="Home"?20:s.key==="End"?80:o+(s.key===d?-5:5)),l()},matchMedia("(max-width: 1199px)").addEventListener("change",()=>i(o))}for(let e of Array.from(document.querySelectorAll(".mode-switch button")))e.onclick=()=>void O(e.dataset.mode==="docs"?{section:"docs",chapter:$e}:e.dataset.mode==="tour"?{section:"tour"}:{section:"playground"});document.querySelector(".site-brand").onclick=(e)=>{e.preventDefault(),O({section:"tour",lesson:I[0].id})};b("lesson-list-button").onclick=()=>qe(a("lesson-list-scrim").hidden===!0);a("lesson-list-scrim").onclick=(e)=>{if(e.target===e.currentTarget)qe(!1)};b("previous-lesson").onclick=()=>{let e=I[ye()-1];if(e)O({section:"tour",lesson:e.id})};b("next-lesson").onclick=()=>{let e=I[ye()+1];O(e?{section:"tour",lesson:e.id}:{section:"playground"})};b("suggested-stage").onclick=()=>{if(!g)return;if(St(I[ye()].stage),ge.matches)de(!1),Ce("output")};b("new-file").onclick=()=>{de(!1),wn()};b("sidebar-toggle").onclick=()=>eo(!Re);b("context-toggle").onclick=()=>de(a("editor-view").dataset.sheet!=="open");a("stage-select").onchange=()=>St(a("stage-select").value);b("compile-button").onclick=()=>{if(pe(),Xn.matches)Ce("output")};b("view-output").onclick=()=>Se("output");b("view-simulate").onclick=()=>Se("simulation");b("source-tab").onclick=()=>Ce("source");b("output-tab").onclick=()=>Ce("output");b("menu-button").onclick=()=>Xe(a("file-menu").hidden===!0);a("file-menu").onclick=()=>Xe(!1);document.addEventListener("pointerdown",(e)=>{if(!a("file-menu").hidden&&!a("file-menu").parentElement.contains(e.target))Xe(!1)});b("share-button").onclick=gn;b("download-source").onclick=()=>{if(g)pn(ee(U),g.input.getValue())};b("download-output").onclick=hn;b("output-download").onclick=hn;b("copy-output").onclick=()=>{if(Ye===ze)mn(X,b("copy-output"))};b("reset-button").onclick=fn;b("related-docs-menu").onclick=()=>{let[e,t]=_?.origin?.replace(/\.html$/,"").split("#")??[];if(e)O({section:"docs",chapter:e,anchor:t})};b("jump-error").onclick=()=>{if(!le||!g)return;Ce("source"),ke(_e),g.input.setSelection(le),g.input.revealRangeInCenter(le),g.input.focus()};a("reset-dialog").addEventListener("close",()=>{if(a("reset-dialog").returnValue==="reset")Y.setValue(He())});b("copy-share").onclick=()=>void mn(a("share-url").value,b("copy-share"));document.addEventListener("keydown",(e)=>{let t=e.metaKey||e.ctrlKey;if(e.key==="Escape"){if(!a("lesson-list-scrim").hidden)qe(!1);else if(ge.matches&&a("editor-view").dataset.sheet==="open")de(!1);Xe(!1)}if(F==="docs"||!t)return;if(e.key==="Enter"&&!e.defaultPrevented)e.preventDefault(),pe();else if(e.key.toLowerCase()==="s"&&!e.altKey)e.preventDefault(),gn();else if(e.key.toLowerCase()==="n"&&!e.altKey&&F==="playground")e.preventDefault(),wn()});window.addEventListener("popstate",()=>void O(bn(),"none"));window.addEventListener("pagehide",()=>{et.dispose(),Pe?.dispose()});Gn();xt();de(!1);ce("Starting editor…","loading");async function co(){if(!location.hash.startsWith("#example="))return!1;let e=await et.show(new URLSearchParams(location.search).get("chapter")??void 0);try{let t=Oe(location.hash.slice(9)),n=e?.examples.find((i)=>i.id===t.id);if(t.version!==1||!n||typeof t.source!=="string"||!Object.hasOwn(j,t.stage))throw Error();let o={mode:"examples",path:J,stage:t.stage,source:t.source,files:n.files,entryPath:n.path,origin:`${e.slug}.html#${n.id}`};await O({section:"shared",shared:{...o,code:Fe(o)}},"replace")}catch{return ne("This shared example could not be opened. The original examples are shown in the guide."),!1}return!0}var We=bn();if(ge.matches&&We.section==="tour")de(!0);if(We.section==="docs"&&location.hash.startsWith("#example="))co().then((e)=>{if(!e)O({...We,anchor:void 0},"replace")});else O(We,"replace");setTimeout(()=>void et.load().then((e)=>{for(let t of e.chapters)sn.set(t.slug,t.title);if(F==="tour")Ze()}).catch(()=>{}),1500);

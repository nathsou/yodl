import{a as ee,b as te,c as oe,d as ie,e as f,f as O,g as de,h as ue}from"./chunk-tgpaa6jf.js";import{i as p,l as pe}from"./chunk-f5z96p44.js";import"./chunk-q7fxykkh.js";var X={"01_presentation":[{id:"gates",title:"Your first circuit"}],"02_getting_started":[{id:"gates",title:"Your first circuit"},{id:"counter",title:"Describe the next state"}],"03_data_types":[{id:"widths",title:"Give every bit a place"},{id:"records",title:"Name a group of signals"}],"04_constructs":[{id:"modules",title:"Connect reusable modules"},{id:"generics",title:"Parameterise a design"},{id:"packages",title:"Organise a design"}],"05_operators":[{id:"bits",title:"Take signals apart"}],"06_control_flow":[{id:"selection",title:"Choose a signal"},{id:"vectors",title:"Build parallel hardware"}],"07_built_in_functions":[{id:"bits",title:"Take signals apart"},{id:"counter",title:"Describe the next state"}],"08_primitive_modules":[{id:"registers",title:"Remember a value"},{id:"memory",title:"Store a small table"}],"09_external_modules":[{id:"modules",title:"Connect reusable modules"}]};var Z=[{id:"gates",title:"Your first circuit",topic:"Signals & modules",intro:"A Yodl program describes hardware. A module connects named inputs to named outputs; the connections operate continuously.",concepts:["bool is a one-bit signal.","The expression a and b describes a logic gate. It does not wait for a clock."],observe:"In FIRRTL, find the two input ports, the output port, and the and operation.",challenge:"Change and to xor. The output will describe a gate that is high when exactly one input is high.",stage:"write_firrtl",file:"01-gates.yodl"},{id:"widths",title:"Give every bit a place",topic:"Integers & arithmetic",intro:"Hardware signals have fixed widths. u8 is an unsigned eight-bit integer; s8 is a signed eight-bit integer. Choose the output width to retain the bits you need.",concepts:["Adding two eight-bit unsigned values can require nine bits.","Sized literals spell out width and base: 8'hFF is eight bits of hexadecimal FF. Signedness changes require an explicit cast."],observe:"Inspect the nine-bit sum and sixteen-bit product ports. Switch to Typed to see expression types.",challenge:"Change sum from u9 to u8. Narrowing keeps the low eight bits, so a carry no longer fits in the output.",stage:"write_firrtl",file:"02-widths.yodl"},{id:"selection",title:"Choose a signal",topic:"Conditions & multiplexers",intro:"Conditions select between signals. Both alternatives describe hardware; a condition does not make the circuit execute one software branch at a time.",concepts:["Use if for a two-way choice.","Use match for several cases, with _ as the default."],observe:"Look for mux operations in FIRRTL: these are the signal selectors described by the conditions.",challenge:"Add a 2 case to match that returns a xor b. Keep the default case.",stage:"write_firrtl",file:"03-selection.yodl"},{id:"bits",title:"Take signals apart",topic:"Slices & built-ins",intro:"Individual bits and slices let you work with the representation of a value. Built-in functions have names ending in !.",concepts:["word[7:4] takes bits seven through four, inclusive.","cat! joins bit strings in order; xorr reduces a signal to its parity bit."],observe:"Find bits, cat, and xorr operations in the FIRRTL output.",challenge:"Change swapped to cat!(low, low). Both halves of the output now come from the same four input bits.",stage:"write_firrtl",file:"04-bits.yodl"},{id:"vectors",title:"Build parallel hardware",topic:"Vectors & loops",intro:"A vector groups a fixed number of values. A for loop creates repeated hardware at compile time, so the loop bounds must be known before the circuit runs.",concepts:["[4]u8 is four eight-bit elements.","0..<Lanes excludes the upper bound. All four lanes exist in parallel."],observe:"The Simplified output expands the loop into individual assignments. Switch to FIRRTL to see the vector ports.",challenge:"Change Lanes from 4 to 8. Compile again and count the expanded assignments.",stage:"write_simplified",file:"05-vectors.yodl"},{id:"records",title:"Name a group of signals",topic:"Records & type aliases",intro:"Records collect related signals into named fields. A type alias gives the collection a reusable name without allocating storage.",concepts:["Access a field with . followed by its name.","A record spread copies fields; later fields override the copied values."],observe:"Find the r, g, and b fields in the output ports. They remain individual signals within a bundle.",challenge:"Also override b with 0 in muted. Only the red channel will pass through.",stage:"write_firrtl",file:"06-records.yodl"},{id:"modules",title:"Connect reusable circuits",topic:"Instances & ports",intro:"Define a module once and instantiate it wherever you need that hardware. Each instance is a separate circuit with its own connections.",concepts:["Named arguments connect inputs when creating an instance.","Access an instance output with .sum. Top is the entry circuit in this design."],observe:"Find two Adder instances under Top. They share a definition but connect to different inputs.",challenge:"Connect the second adder to a and c instead of b and c.",stage:"write_firrtl",file:"07-modules.yodl"},{id:"generics",title:"Parameterise a design",topic:"Compile-time parameters",intro:"Generic parameters configure hardware before it runs. Nat parameters describe sizes; Type parameters let a module work with different signal types.",concepts:["uint[Width] uses a compile-time width.","Instantiation specialises each generic module with concrete parameters. These parameters are not input ports."],observe:"Monomorphised output shows concrete versions of the generic modules. Compare it with Source.",challenge:"Change the wide input and output from u16 to u12, and change Mask[16] to Mask[12].",stage:"write_mono",file:"08-generics.yodl"},{id:"registers",title:"Remember a value",topic:"Clocked state",intro:"Combinational logic has no memory. Reg adds state: q is the current value and d is the value sampled at the next rising clock edge.",concepts:["Reg[u8] stores eight bits.","rst resets the register to zero synchronously. en controls whether it captures a new value."],observe:"Find the register and its clock, reset, and enable logic in FIRRTL. The output reads the stored q value.",challenge:"Connect en to true instead of enable. The register will capture data on every rising edge unless reset is asserted.",stage:"write_firrtl",file:"09-registers.yodl"},{id:"counter",title:"Describe the next state",topic:"Feedback & constants",intro:"A counter feeds its current register value through combinational logic to compute the next value. The register breaks the feedback path into clock cycles.",concepts:["clog2!(Limit) computes the number of address bits needed for Limit values.","The comparison makes the counter wrap after Limit - 1. Reset establishes the initial zero state."],observe:"Follow the register output through the increment and selection logic back to its input.",challenge:"Change Limit from 10 to 16. The width stays four bits, but the wrap comparison changes.",stage:"write_firrtl",file:"10-counter.yodl"},{id:"packages",title:"Organise a design",topic:"Packages & names",intro:"Packages group declarations under a namespace. Qualified names make it clear where a reusable module belongs.",concepts:["Use :: to access a declaration inside a package.","A file brought in with import is also wrapped in a package named after the file. Larger examples demonstrate imports."],observe:"Find the qualified Logic::Invert name in Source, then switch to FIRRTL to inspect its instance.",challenge:"Add another Invert instance after the first and connect q to its output. Two inversions restore the original signal.",stage:"write_source",file:"11-packages.yodl"},{id:"memory",title:"Store a small table",topic:"Memory & latency",intro:"Memory describes indexed storage with explicit read and write ports. Latency is part of the interface: this design requests a read latency of one cycle.",concepts:["Depth is the number of stored words; T is the type of each word.","Read and write ports carry clocks, addresses, and enables. A true write mask enables the whole byte."],observe:"Find the memory depth, read latency, and write latency in FIRRTL. Compilation shows structure; the playground does not simulate clock cycles.",challenge:"Increase Depth to 32 and change addr from u4 to u5 so every word remains addressable.",stage:"write_firrtl",file:"12-memory.yodl"}];var _={...{"examples/Sim.yodl":`import VGA
import Life

module TopSim(
    clk: clock,
    rst: bool,
) -> (
    is_active_area: bool,
    screen_x: u10,
    screen_y: u10,
    r: u3,
    g: u3,
    b: u3,
) {
   let vga = VGA::SyncPulses(
        pixel_clk: clk,
        is_active_area,
        col: screen_x,
        row: screen_y,
    )

    let life = Life::Life(
        clk,
        rst,
        hsync: vga.hsync,
        vsync: vga.vsync,
        row: vga.row,
        col: vga.col,
    )

    let color = vga.is_active_area ? life.color : (r: 3'd0, g: 3'd0, b: 3'd0)

    r = color.r
    g = color.g
    b = color.b
}
`,"examples/Hello.yodl":`import Timing
import LFSR
import Text

module Top(
    clk: clock,
) -> (
    led: u4,
    vga_hsync: bool,
    vga_vsync: bool,
    vga_red: u3,
    vga_green: u3,
    vga_blue: u3,
) {
    let vga = VGA::SyncPulses(
        pixel_clk: clk,
        hsync: vga_hsync,
        vsync: vga_vsync,
    )

    const MsgLen = 69
    let timer = Timing::Timer[100_000_000](clk)
    let timer2 = Timing::Timer[5_000_000](clk)
    let messages = [
        "YODL; Yet anOther (hardware) Description Language by Nathan Soufflet!",
        "Visit https://github.com/nathsou/yodl for more information :)        ",
    ]

    let msg_index = Timing::Counter[1](clk, en: timer.q, rst: 1'b0).q
    let rand_color = LFSR::LFSR[32](clk, enable: timer.q).q[8:0]
    let y = Timing::Counter[6](clk, en: timer2.q)
    y.rst = y.q >= (Text::Cols - 1)

    let text = Text::TextDynamicPosition[MsgLen](
        text: messages[msg_index],
        x_offset: 7'd5,
        y_offset: y.q,
        screen_x: vga.col,
        screen_y: vga.row,
    )

    let color = match vga.is_active_area and text.is_active {
        1'b0 => (r: 3'd0, g: 3'd0, b: 3'd0)
        1'b1 => (r: rand_color[2:0], g: rand_color[5:3], b: rand_color[8:6])
    }

    vga_red = color.r
    vga_green = color.g
    vga_blue = color.b
    led = 4'd0
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
`,"examples/Euler1.yodl":`import Text

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

module Top(
    clk: clock,
    button: u4,
) -> (
    led: u4,
    vga_hsync: bool,
    vga_vsync: bool,
    vga_red: u3,
    vga_green: u3,
    vga_blue: u3,
) {
    let rst = orr button
    let vga = VGA::SyncPulses(
        pixel_clk: clk,
        hsync: vga_hsync,
        vsync: vga_vsync,
    )

    let euler1 = Euler1(clk, rst)
    let hex = Text::Hex[20](n: cat!(2'0, euler1.q))
    let text = Text::Text[Length: 40, X: 20, Y: 30](
        text: [.."The solution to Project Euler 1 is ", ..hex.chars],
        screen_x: vga.col,
        screen_y: vga.row,
    )

    let color = match vga.is_active_area and text.is_active {
        1'b0 => (r: 3'd0, g: 3'd0, b: 3'd0)
        1'b1 => (r: 3'd1, g: 3'd5, b: 3'd6)
    }

    vga_red = color.r
    vga_green = color.g
    vga_blue = color.b
    led = uint!(cat!(fill!(4, euler1.is_ready)))
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
`,"examples/RISCV.yodl":`// https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV/README.md

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
`,"examples/Life.yodl":`// Fully parallel game of life simulation
// adapted from https://k155la3.blog/2020/10/09/conways-game-of-life-on-fpga/

module Cell(
    clk: clock,
    rst: bool,
    enable: bool,
    neighbors: [8]bool,
    write_enable: bool,
    write_state: bool,
) -> (
    state: bool,
) {
    let alive = Reg[bool](clk, rst, en: enable, q: state)
    let count: u3 = neighbors[0] + neighbors[1] + neighbors[2] + neighbors[3] +
                    neighbors[4] + neighbors[5] + neighbors[6] + neighbors[7]

    alive.d = if write_enable {
        write_state // direct write during initialization
    } else {
        match count {
            3'd2 => alive.q // stable
            3'd3 => true // reproduction
            _ => false // overpopulation or underpopulation
        }
    }
}

module Grid[Rows: Nat, Cols: Nat](
    clk: clock,
    rst: bool,
    read_row: uint[clog2!(Rows)],
    read_col: uint[clog2!(Cols)],
    write_enable: bool,
    write_state: bool,
    write_row: uint[clog2!(Rows)],
    write_col: uint[clog2!(Cols)],
) -> (
    read_state: bool,
) {
    let cells = fill!(Cols, fill!(Rows, Cell(clk, rst)))

    for row in 0..<Rows {
        for col in 0..<Cols {
            let cell = cells[col][row]
            let cell_active = (write_row == row) and (write_col == col)

            cell.enable = write_enable ? cell_active : 1'b1
            cell.write_enable = write_enable and cell_active
            cell.write_state = write_state

            // wrap around
            const prev_row = row == 0 ? Rows - 1 : row - 1
            const next_row = row == Rows - 1 ? 0 : row + 1
            const prev_col = col == 0 ? Cols - 1 : col - 1
            const next_col = col == Cols - 1 ? 0 : col + 1

            cell.neighbors[0] = cells[prev_col][prev_row].state
            cell.neighbors[1] = cells[col][prev_row].state
            cell.neighbors[2] = cells[next_col][prev_row].state
            cell.neighbors[3] = cells[prev_col][row].state
            cell.neighbors[4] = cells[next_col][row].state
            cell.neighbors[5] = cells[prev_col][next_row].state
            cell.neighbors[6] = cells[col][next_row].state
            cell.neighbors[7] = cells[next_col][next_row].state
        }
    }

    read_state = cells[read_col][read_row].state
}

module GridInit[Rows: Nat, Cols: Nat](
    clk: clock,
    rst: bool,
    read_row: uint[clog2!(Rows)],
    read_col: uint[clog2!(Cols)],
    pattern: [Rows][Cols]bool,
) -> (
    read_state: bool,
    ready: bool,
) {
    let grid = Grid[Rows, Cols](clk, rst, read_row, read_col, read_state)
    const PatternLen = Rows * Cols
    let counter = Reg[uint[clog2!(PatternLen)]](clk, rst)
    let row = Reg[uint[clog2!(Rows)]](clk, rst)
    let col = Reg[uint[clog2!(Cols)]](clk, rst)
    let state = pattern[row.q][col.q]

    col.d = col.q
    row.d = row.q
    counter.d = counter.q

    if counter.q < PatternLen {
        grid.write_enable = 1'1
        grid.write_state = state
        grid.write_row = row.q
        grid.write_col = col.q
        ready = 1'0

        counter.d = counter.q + 1'1

        if col.q == Cols - 1 {
            col.d = pad!(1'0, clog2!(Cols))
            row.d = row.q + 1'1
        } else {
            col.d = col.q + 1'1
        }
    } else {
        grid.write_enable = 1'0
        grid.write_state = 1'0
        grid.write_row = pad!(1'0, clog2!(Rows))
        grid.write_col = pad!(1'0, clog2!(Cols))
        ready = 1'b1
    }
}

module Life(
    clk: clock,
    rst: bool,
    hsync: bool,
    vsync: bool,
    row: u10,
    col: u10,
) -> (
    color: (r: u3, g: u3, b: u3),
) {
    const Rows = 480 / 16
    const Cols = 640 / 16

    let x = col[9:4]
    let y = row[8:4]

    // Gosper glider gun and a glider eater
    let pattern: [Rows][Cols]bool = [
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

    let grid = GridInit[Rows, Cols](
        rst,
        read_col: x,
        read_row: y,
        pattern,
    )

    grid.clk = grid.ready ? clock!(vsync) : clk

    color = match grid.ready {
        1'0 => (r: 3'd0, g: 3'd0, b: 3'd0)
        1'1 => {
            if col[3:0] == 4'0 or row[3:0] == 4'0 {
                (r: 3'd1, g: 3'd1, b: 3'd1)
            } else if grid.read_state {
                (r: 3'd1, g: 3'd6, b: 3'd4)
            } else {
                (r: 3'd0, g: 3'd0, b: 3'd0)
            }
        }
    }
}
`,"examples/Image.yodl":`import VGA
import LFSR
import Timing

module Top(
    clk: clock,
    button: u4,
) -> (
    led: u4,
    vga_hsync: bool,
    vga_vsync: bool,
    vga_red: u3,
    vga_green: u3,
    vga_blue: u3,
) {
    let vga = VGA::SyncPulses(pixel_clk: clk, hsync: vga_hsync, vsync: vga_vsync)
    let div = (x: vga.col[9:2], y: vga.row[9:2])
    let cell_idx: u15 = div.y * 160 + div.x
    let timer = Timing::Timer[100_000](clk)
    let rand_cell = LFSR::LFSR[15](clk, enable: timer.q).q
    let rand_color = LFSR::LFSR[3](clk, enable: timer.q).q
    let add_noise = orr button

    let mem = Memory[
        T: u3,
        Depth: (VGA::H_ACTIVE / 4) * (VGA::V_ACTIVE / 4),
        ReadPorts: 1,
        WritePorts: 1,
    ](
        read: [(clk: clk, en: vga.is_active_area, addr: cell_idx)],
        write: [(clk: clk, en: add_noise and timer.q, addr: rand_cell, data: rand_color, mask: true)],
    )

    readmemb!("res/york.mem", mem)

    let color_idx = mem.q[0]

    let color = match vga.is_active_area {
        1'b0 => (r: 3'd0, g: 3'd0, b: 3'd0)
        1'b1 => match color_idx {
            3'd0 => (r: 3'd3, g: 3'd5, b: 3'd7)
            3'd1 => (r: 3'd2, g: 3'd2, b: 3'd2)
            3'd2 => (r: 3'd0, g: 3'd0, b: 3'd0)
            3'd3 => (r: 3'd1, g: 3'd1, b: 3'd0)
            3'd4 => (r: 3'd1, g: 3'd1, b: 3'd1)
            3'd5 => (r: 3'd7, g: 3'd7, b: 3'd6)
            3'd6 => (r: 3'd7, g: 3'd7, b: 3'd7)
            3'd7 => (r: 3'd3, g: 3'd3, b: 3'd3)
        }
    }

    vga_red = color.r
    vga_green = color.g
    vga_blue = color.b
    led = uint!(fill!(4, add_noise))
}
`,"examples/SOC.yodl":`import RISCV
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
    let cpu = RISCV::CPU(
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
}`,"examples/Clock.yodl":`import Text

const CLOCK_FREQ = 25_000_000 // 25 Mhz on Nandland Go

module Dabble(bin: u4) -> (q: u4) {
    q = bin >= 4'd5 ? bin + 4'd3 : bin
}

module BCD2(bin: u6) -> (q: u8) {
    let a = bin[5]
    let b = bin[4]
    let c = bin[3]
    let d = bin[2]
    let e = bin[1]
    let f = bin[0]

    let t = Dabble(bin: cat!(1'b0, a, b, c)).q
    let u = Dabble(bin: cat!(t[2:0], d)).q
    let v = Dabble(bin: cat!(u[2:0], e)).q

    q = cat!(1'b0, t[3], u[3], v, f)
}

module TicTac[Max: Nat](clk: clock, en: bool, rst: bool) -> (tick: bool, count: uint[clog2!(Max)]) {
    let counter = Reg[uint[clog2!(Max)]](clk, en, rst: rst or tick, q: count)
    counter.d = counter.q + 1
    tick = counter.q == Max
}

module Clock(
    clk: clock,
    pixel_clk: clock,
    rst: bool,
) -> (
    is_active_area: bool,
    screen_x: u10,
    screen_y: u10,
    vga_hsync: bool,
    vga_vsync: bool,
    vga_red: u3,
    vga_green: u3,
    vga_blue: u3,
) {
    VGA::SyncPulses(
        pixel_clk,
        hsync: vga_hsync,
        vsync: vga_vsync,
        col: screen_x,
        row: screen_y,
        is_active_area,
    )

    let ticks = TicTac[CLOCK_FREQ](clk, en: 1'b1, rst)
    let seconds = TicTac[60](clk, en: ticks.tick, rst)
    let minutes = TicTac[60](clk, en: seconds.tick, rst)
    let hours = TicTac[24](clk, en: minutes.tick, rst)

    let text = Text::Text[Length: 8, X: 36, Y: 30](
        text: {
            let seconds_dec = Text::Dec[8](n: BCD2(bin: seconds.count).q).chars
            let minutes_dec = Text::Dec[8](n: BCD2(bin: minutes.count).q).chars
            let hours_dec = Text::Dec[8](n: BCD2(bin: cat!(1'b0, hours.count)).q).chars
            [..hours_dec, ':', ..minutes_dec, ':', ..seconds_dec]
        },
        screen_x,
        screen_y,
    )

    let color = match is_active_area and text.is_active {
        1'b0 => (r: 3'd0, g: 3'd0, b: 3'd0)
        1'b1 => (r: 3'd1, g: 3'd6, b: 3'd3)
    }

    vga_red = color.r
    vga_green = color.g
    vga_blue = color.b
}

module Top(
    clk: clock,
    button: u4,
) -> (
    led: u4,
    vga_hsync: bool,
    vga_vsync: bool,
    vga_red: u3,
    vga_green: u3,
    vga_blue: u3,
) {
    Clock(
        clk,
        pixel_clk: clk,
        rst: orr button,
        vga_hsync,
        vga_vsync,
        vga_red,
        vga_green,
        vga_blue,
    )

    led = 4'd0
}
`,"examples/Noise.yodl":`import VGA
import LFSR

module Top(
    clk: clock,
) -> (
    led: u4,
    vga_hsync: bool,
    vga_vsync: bool,
    vga_red: u3,
    vga_green: u3,
    vga_blue: u3,
) {
    let vga = VGA::SyncPulses(pixel_clk: clk, hsync: vga_hsync, vsync: vga_vsync)
    let rand_color = LFSR::LFSR[32](clk, enable: vga.new_pixel).q[8:0]
    let color = match vga.is_active_area {
        1'b0 => (r: 3'd0, g: 3'd0, b: 3'd0)
        1'b1 => (r: rand_color[2-:3], g: rand_color[5-:3], b: rand_color[8-:3])
    }

    vga_red = color.r
    vga_green = color.g
    vga_blue = color.b
    led = 4'd0
}
`,"examples/lib/VGA.yodl":`
const H_ACTIVE = 640
const V_ACTIVE = 480

module SyncPulses(
    pixel_clk: clock, // a roughly 25.175 MHz clock
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

    let col_reg = Reg[u10](clk: pixel_clk, q: col)
    let row_reg = Reg[u10](clk: pixel_clk, q: row)

    let last_col = col_reg.q == H_TOTAL - 1
    let last_row = row_reg.q == V_TOTAL - 1

    col_reg.d = last_col ? 10'd0 : col_reg.q + 1'1
    row_reg.d = last_col ? (last_row ? 10'd0 : row_reg.q + 1'1) : row_reg.q
    new_pixel = last_col nand last_row

    hsync = (col_reg.q >= (H_ACTIVE + H_FRONT_PORCH)) and (col_reg.q < (H_ACTIVE + H_FRONT_PORCH + H_SYNC_PULSE))
    vsync = (row_reg.q >= (V_ACTIVE + V_FRONT_PORCH)) and (row_reg.q < (V_ACTIVE + V_FRONT_PORCH + V_SYNC_PULSE))
    is_active_area = col_reg.q < H_ACTIVE and row_reg.q < V_ACTIVE
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
`,"examples/lib/Text.yodl":`import VGA
import LFSR
import Timing

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

const Rows = VGA::V_ACTIVE / 8
const Cols = VGA::H_ACTIVE / 8

module Text[Length: Nat, X: Nat, Y: Nat](
    text: [Length]Char,
    screen_x: u10,
    screen_y: u10,
) -> (
    is_active: bool,
) {
    const StartIdx = Y * Cols + X
    let x_div = screen_x[9:3]
    let y_div = screen_y[9:3]
    let x = screen_x[2:0]
    let y = screen_y[2:0]
    let cell_idx: u13 = y_div * Cols + x_div
    let diff: u13 = cell_idx - StartIdx
    let char = cell_idx >= StartIdx ? CharAt[Length: Length, IndexWidth: 13](str: text, index: diff).char : ' '
    let bitmap = AsciiTable(char).q
    let pixel_idx: u6 = y * 8 + x
    is_active = (bitmap shr pixel_idx)[0]
}

module TextDynamicPosition[Length: Nat](
    text: [Length]Char,
    x_offset: uint[clog2!(Cols)],
    y_offset: uint[clog2!(Rows)],
    screen_x: u10,
    screen_y: u10,
) -> (
    is_active: bool,
) {
    let x_div = screen_x[9:3]
    let y_div = screen_y[9:3]
    let x = screen_x[2:0]
    let y = screen_y[2:0]
    let start_idx: u13 = y_offset * Cols + x_offset
    let cell_idx: u13 = y_div * Cols + x_div
    let diff: u13 = cell_idx - start_idx
    let char = cell_idx >= start_idx ? CharAt[Length: Length, IndexWidth: 13](str: text, index: diff).char : ' '
    let bitmap = AsciiTable(char).q
    let pixel_idx: u6 = y * 8 + x
    is_active = (bitmap shr pixel_idx)[0]
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
`,"examples/lib/LFSR.yodl":`
// Linear Feedback Shift Register
module LFSR[NumBits: Nat](
    clk: clock,
    enable: bool,
) -> (
    q: uint[NumBits],
    done: bool,
) {
    let r_xnor = Reg[bool](clk)
    let r_lfsr = Reg[uint[NumBits]](clk, en: enable, q)
    r_lfsr.d = cat!(r_lfsr.q[NumBits - 2:0], r_xnor.q)

    // https://docs.amd.com/v/u/en-US/xapp052
    r_xnor.d = match NumBits {
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

    done = r_lfsr.q == 0
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
`,"tour/02-widths.yodl":`module Top(a: u8, b: u8, offset: s8) -> (
    sum: u9,
    product: u16,
    adjusted: s9,
) {
    sum = a + b
    product = a * b
    adjusted = offset + sint!(8'd1)
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
`,"tour/07-modules.yodl":`module Adder(a: u8, b: u8) -> (sum: u9) {
    sum = a + b
}

module Top(a: u8, b: u8, c: u8) -> (ab: u9, bc: u9) {
    let first = Adder(a: a, b: b)
    let second = Adder(a: b, b: c)
    ab = first.sum
    bc = second.sum
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
`,"tour/05-vectors.yodl":`const Lanes = 4

module Top(values: [Lanes]u8, mask: u8) -> (result: [Lanes]u8) {
    for i in 0..<Lanes {
        result[i] = values[i] xor mask
    }
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
`,"tour/01-gates.yodl":`// Two inputs, one gate, one output.
module Top(a: bool, b: bool) -> (q: bool) {
    q = a and b
}
`}},c=Z,V=Object.keys(_).filter((e)=>/^examples\/[^/]+\.yodl$/.test(e)).sort(),S="examples/Playground.yodl",q={mode:"tour",path:`tour/${c[0].file}`,stage:"write_firrtl"};function I(e){if(!e||typeof e!=="object")return!1;let t=e;return Object.hasOwn(f,t.stage)&&(t.mode==="tour"?c.some((i)=>`tour/${i.file}`===t.path):t.mode==="examples"&&(V.includes(t.path)||t.path===S))}function ne(e){return ee({...e,version:e.entryPath?2:1})}function se(e){if(!e.startsWith("#code="))return null;try{let t=te(e.slice(6));if(![1,2].includes(t.version)||!I(t)||typeof t.source!=="string")throw Error();if(t.version===2&&(!oe(t.entryPath)||!ie(t.files)||t.origin!==void 0&&!/^[a-zA-Z0-9_-]+\.html#[a-z0-9-]+$/.test(t.origin)))throw Error();if(t.version===1)return{version:1,mode:t.mode,path:t.path,stage:t.stage,source:t.source};return t}catch{throw Error("This share link is invalid, too large, or uses an unsupported version.")}}var o=(e)=>document.getElementById(e),r=(e)=>o(e),g=(e)=>o(e),he="yodl-playground-v2:",K=!0;function k(e){try{return localStorage.getItem(he+e)}catch{return K=!1,null}}function v(e,t){try{localStorage.setItem(he+e,t)}catch{K=!1}}function T(e){let t=o("notice");t.textContent=e;let i=document.createElement("button");i.textContent="Dismiss",i.addEventListener("click",()=>{t.hidden=!0}),t.append(i),t.hidden=!1}function x(e,t="idle"){o("compile-status").textContent=e,o("compile-status").dataset.state=t}var ke=ue(g("theme-select"),(e)=>{if(p)p.editor.setTheme(e?"yodl-dark":"yodl-light")}),s={...q};try{let e=JSON.parse(k("selection")??"null");if(I(e))s=e}catch{}var ge=new URLSearchParams(location.search),B=c.find((e)=>e.id===ge.get("lesson"));if(B)s={mode:"tour",path:`tour/${B.file}`,stage:B.stage};else if(ge.get("mode")==="examples")s={mode:"examples",path:S,stage:"write_firrtl"};var H={},b,L,M=null,E="";try{let e=se(location.hash);if(e)s={mode:e.mode,path:e.path,stage:e.stage},M=e.source,H=e.files??{},b=e.entryPath,L=e.origin,E=`shared:${location.hash.slice(6)}`,T("Shared circuit opened. Your existing lesson and example drafts are kept separately.")}catch(e){T(e.message)}var n,C=!1,P=0,h="",A=-1,F,me=new de,fe=0,U=0,m=null,w=o("auto-compile");w.checked=k("auto")!=="false";var Se=`// Start a new circuit here.
module Top(a: bool) -> (q: bool) {
    q = a
}
`,z=(e)=>_[e]??Se,be=()=>b&&M!==null?M:z(s.path),Y=()=>E||`draft:${s.path}`;function D(){return c.findIndex((e)=>`tour/${e.file}`===s.path)}function R(){if(v(Y(),n.input.getValue()),!E)v("selection",JSON.stringify(s));o("save-status").textContent=K?"Draft saved locally":"Draft not saved · storage unavailable",o("draft-badge").hidden=n.input.getValue()===be()}function ye(){let e=s.mode==="tour";o("site-section").textContent=e?"tour":"playground",r("tour-mode").setAttribute("aria-pressed",String(e)),r("examples-mode").setAttribute("aria-pressed",String(!e)),o("guide").hidden=!e,o("source-label").textContent=e?"Lesson":"Example";let t=g("source-selector");t.replaceChildren();let i=e?c.map((l,u)=>({value:`tour/${l.file}`,label:`${String(u+1).padStart(2,"0")} · ${l.title}`})):[{value:S,label:"New circuit"},...V.map((l)=>({value:l,label:l.split("/").at(-1)}))];for(let l of i)t.add(new Option(l.label,l.value));t.value=s.path,o("input-filename").textContent=(b??s.path).split("/").at(-1),o("input-filename").title=b??s.path;let d=o("related-docs"),a=Object.entries(X).find(([,l])=>l.some((u)=>u.id===c[D()]?.id));if(d.hidden=!a&&!L,d.href=`./book/${L??(a?a[0]+".html":"")}`,e){let l=D(),u=c[l];o("lesson-position").textContent=`${String(l+1).padStart(2,"0")} / ${c.length}`,o("lesson-topic").textContent=u.topic,o("lesson-title").textContent=u.title,o("lesson-intro").textContent=u.intro,o("lesson-observe").textContent=u.observe,o("lesson-challenge").textContent=u.challenge,o("lesson-concepts").replaceChildren(...u.concepts.map((ve)=>{let Q=document.createElement("li");return Q.textContent=ve,Q})),r("suggested-stage").textContent=`Show ${f[u.stage].label} →`,r("previous-lesson").disabled=l===0,r("next-lesson").disabled=!1,r("next-lesson").textContent=l===c.length-1?"Explore examples →":"Next lesson →"}g("pass-selector").value=s.stage,G()}function G(){let e=f[s.stage];o("stage-description").textContent=e.description,o("stage-command").textContent=s.stage,p.editor.setModelLanguage(n.output.getModel(),e.language)}function we(){o("problems").hidden=!0,m=null,p.editor.setModelMarkers(n.input.getModel(),"yodl",[])}function W(){if(me.cancel("playground"),P++,U=++fe,clearTimeout(F),we(),r("copy-output").disabled=!0,r("download-output").disabled=!0,x(h?"Source changed · output is out of date":"Ready to compile"),w.checked)F=setTimeout(y,500)}function J(e){if(R(),E="",M=null,H={},b=void 0,L=void 0,location.hash.startsWith("#code="))history.replaceState(null,"",location.pathname+location.search);s=e,C=!0,n.input.setValue(k(Y())??z(s.path)),C=!1,n.input.setScrollTop(0),n.output.setValue(""),h="",A=-1,ye();let t=new URL(location.href);t.searchParams.delete("lesson"),t.searchParams.delete("mode"),history.replaceState(null,"",t),R(),W()}function j(e){if(e===s.mode&&!E)return;let t=e==="tour"?q.path:S,i=k(`last:${e}`);if(I({mode:e,path:i,stage:"write_firrtl"}))t=i;J({mode:e,path:t,stage:e==="tour"?c.find((d)=>`tour/${d.file}`===t).stage:"write_firrtl"})}function re(e){s.stage=e,g("pass-selector").value=e,n.output.setValue(""),h="",G(),R(),W()}function N(e){o("editors").dataset.view=e,r("source-tab").setAttribute("aria-pressed",String(e==="source")),r("output-tab").setAttribute("aria-pressed",String(e==="output")),n.input.layout(),n.output.layout()}function Ce(e){if(o("problems").hidden=!1,o("error-message").textContent=e,m=O(e,b??s.path),r("jump-error").hidden=m===null,m){let t=n.input.getModel().validateRange(m);m=t,p.editor.setModelMarkers(n.input.getModel(),"yodl",[{...t,message:e,severity:p.MarkerSeverity.Error}])}x(h?"Compilation failed · showing previous output":"Compilation failed · check diagnostics","error")}async function y(){clearTimeout(F);let e=++fe;U=e;let t=P;we(),x("Compiling…","loading");let i=await me.compile("playground",{source:n.input.getValue(),path:b??s.path,stage:s.stage,files:{..._,...H}});if(!i||e!==U)return;if(i.error!==void 0){Ce(i.error);return}h=i.output??"",A=t,n.output.setValue(h),G(),r("copy-output").disabled=!h,r("download-output").disabled=!h,x(`✓ Compiled · ${Math.round(i.duration)} ms`,"success")}function ae(e,t){let i=URL.createObjectURL(new Blob([t],{type:"text/plain;charset=utf-8"})),d=document.createElement("a");d.href=i,d.download=e,d.click(),setTimeout(()=>URL.revokeObjectURL(i),1000)}async function le(e,t){try{await navigator.clipboard.writeText(e);let i=t.textContent;t.textContent="Copied",setTimeout(()=>{t.textContent=i},1800)}catch{if(T("Clipboard access is unavailable. Select the text and use your browser’s Copy command."),t.id==="copy-share")o("share-url").select();else n.output.focus(),n.output.setSelection(n.output.getModel().getFullModelRange())}}async function Te(){n=await pe(),ke();for(let[t,i]of Object.entries(f))g("pass-selector").add(new Option(i.label,t));if(C=!0,n.input.setValue(k(Y())??M??z(s.path)),C=!1,ye(),matchMedia("(max-width: 820px)").matches)o("guide-details").open=!1;R();for(let t of["share-button","source-selector","compile-button","pass-selector","reset-button","download-source"])o(t).disabled=!1;let e=/Mac|iPhone|iPad/.test(navigator.platform);if(o("compile-shortcut").textContent=e?"⌘ ↵":"Ctrl ↵",n.input.addAction({id:"compile-yodl",label:"Compile Yodl",keybindings:[p.KeyMod.CtrlCmd|p.KeyCode.Enter],run:y}),n.output.addAction({id:"compile-yodl-output",label:"Compile Yodl",keybindings:[p.KeyMod.CtrlCmd|p.KeyCode.Enter],run:y}),document.addEventListener("keydown",(t)=>{if(!t.defaultPrevented&&(t.metaKey||t.ctrlKey)&&t.key==="Enter")t.preventDefault(),y()}),n.input.onDidChangeModelContent(()=>{if(C)return;R(),W()}),n.input.onDidChangeCursorPosition((t)=>{o("cursor-position").textContent=`Ln ${t.position.lineNumber}, Col ${t.position.column}`}),r("tour-mode").onclick=()=>j("tour"),r("examples-mode").onclick=()=>j("examples"),g("source-selector").onchange=()=>{let t=g("source-selector").value;v(`last:${s.mode}`,t),J({mode:s.mode,path:t,stage:s.mode==="tour"?c.find((i)=>`tour/${i.file}`===t).stage:s.stage})},r("previous-lesson").onclick=()=>ce(-1),r("next-lesson").onclick=()=>ce(1),r("suggested-stage").onclick=()=>re(c[D()].stage),g("pass-selector").onchange=()=>re(g("pass-selector").value),r("compile-button").onclick=y,w.onchange=()=>{if(v("auto",String(w.checked)),clearTimeout(F),w.checked)y()},r("source-tab").onclick=()=>N("source"),r("output-tab").onclick=()=>N("output"),r("jump-error").onclick=()=>{if(!m)return;N("source"),n.input.setSelection(m),n.input.revealRangeInCenter(m),n.input.focus()},r("reset-button").onclick=()=>o("reset-dialog").showModal(),o("reset-dialog").addEventListener("close",()=>{if(o("reset-dialog").returnValue==="reset")n.input.setValue(be())}),r("download-source").onclick=()=>ae(s.path.split("/").at(-1),n.input.getValue()),r("download-output").onclick=()=>{if(A===P)ae(`${s.path.split("/").at(-1).replace(/\.yodl$/,"")}.${f[s.stage].extension}`,h)},r("copy-output").onclick=()=>{if(A===P)le(h,r("copy-output"))},r("share-button").onclick=()=>{let t=new URL(location.href);if(t.hash=`code=${ne({...s,source:n.input.getValue(),files:H,entryPath:b,origin:L})}`,t.href.length>32000){T("This circuit is too large for a reliable share link. Use Save to download the source instead.");return}o("share-url").value=t.href,o("share-dialog").showModal(),o("share-url").select()},r("copy-share").onclick=()=>void le(o("share-url").value,r("copy-share")),Le(),x("Ready to compile"),w.checked)y()}function ce(e){let t=D()+e;if(t>=c.length){j("examples");return}let i=c[t];if(i)v("last:tour",`tour/${i.file}`),J({mode:"tour",path:`tour/${i.file}`,stage:i.stage}),o("guide").scrollTop=0}function Le(){let e=o("resize-handle"),t=Number(k("split")??50);function i(a){t=Math.max(25,Math.min(75,Number.isFinite(a)?a:50)),o("editors").style.setProperty("--source-width",`${t}%`),e.setAttribute("aria-valuenow",String(Math.round(t))),n.input.layout(),n.output.layout()}i(t),e.onpointerdown=(a)=>{e.setPointerCapture(a.pointerId),e.classList.add("dragging"),a.preventDefault()},e.onpointermove=(a)=>{if(!e.hasPointerCapture(a.pointerId))return;let l=o("editors").getBoundingClientRect();i((a.clientX-l.left)/l.width*100)};let d=()=>{e.classList.remove("dragging"),v("split",String(t))};e.onlostpointercapture=d,e.onpointerup=(a)=>{if(e.hasPointerCapture(a.pointerId))e.releasePointerCapture(a.pointerId)},e.onkeydown=(a)=>{if(!["ArrowLeft","ArrowRight","Home","End"].includes(a.key))return;a.preventDefault(),i(a.key==="Home"?25:a.key==="End"?75:t+(a.key==="ArrowLeft"?-5:5)),d()}}Te().catch((e)=>{x("Could not load the editor","error"),o("input-panel").textContent="The editor could not load. Check your connection and reload the page.",T(`Playground startup failed: ${e.message??String(e)}`)});

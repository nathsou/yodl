.section .data
test_word:   .word 0
test_half:   .hword 0
test_byte:   .byte 0

.section .text
.globl main
	
main:
    # Test 1: SW/LW
    li      t0, 0xDEADBEEF
    la      t1, test_word
    sw      t0, 0(t1)
    lw      t2, 0(t1)
    bne     t0, t2, error
    li      a0, '1'
    jal     ra, putchar

    # Test 2: SH/LH/LHU
    li      t0, 0xFFFF8000
    la      t1, test_half
    sh      t0, 0(t1)
    lh      t2, 0(t1)
    li      t3, 0xFFFF8000
    bne     t2, t3, error
    lhu     t2, 0(t1)
    li      t3, 0x00008000
    bne     t2, t3, error
    li      a0, '2'
    jal     ra, putchar

    # Test 3: SB/LB/LBU
    li      t0, 0xFF
    la      t1, test_byte
    sb      t0, 0(t1)
    lb      t2, 0(t1)
    li      t3, -1
    bne     t2, t3, error
    lbu     t2, 0(t1)
    li      t3, 0xFF
    bne     t2, t3, error
    li      a0, '3'
    jal     ra, putchar

    # Test LUI
    lui     t0, 0x12345
    li      t1, 0x12345000
    bne     t0, t1, error
    li      a0, 'L'
    jal     ra, putchar

    # Test AUIPC (fixed)
1:  auipc   t0, 0x100
    la      t1, 1b
    lui     t2, 0x100           # Load upper 20 bits of 0x100000
    add     t1, t1, t2          # Add offset
    bne     t0, t1, error
    li      a0, 'A'
    jal     ra, putchar

    # Test ADDI
    addi    t0, zero, 0x55
    li      t1, 0x55
    bne     t0, t1, error
    li      a0, 'I'
    jal     ra, putchar

    # Test SLTI
    addi    t0, zero, -1
    slti    t1, t0, 0
    li      t2, 1
    bne     t1, t2, error
    li      a0, 'S'
    jal     ra, putchar

    # Test SLTIU
    addi    t0, zero, 0
    sltiu   t1, t0, -1
    li      t2, 1
    bne     t1, t2, error
    li      a0, 'U'
    jal     ra, putchar

    # Test ANDI (fixed)
    li      t0, 0xF0F0
    andi    t1, t0, 0x0FF       # Use 12-bit immediate
    li      t2, 0x00F0
    bne     t1, t2, error
    li      a0, '&'
    jal     ra, putchar

    # # Test ORI (fixed)
    # li      t0, 0xF0F0
    # ori     t1, t0, 0x0FFF      # Use 12-bit immediate
    # li      t2, 0xFFFF
    # bne     t1, t2, error
    # li      a0, '|'
    # jal     ra, putchar

    # Test XORI
    li      t0, 0x12345678
    xori    t1, t0, -1
    not     t2, t0
    bne     t1, t2, error
    li      a0, '^'
    jal     ra, putchar

    # Test SLLI
    li      t0, 0x0F
    slli    t1, t0, 4
    li      t2, 0xF0
    bne     t1, t2, error
    li      a0, '<'
    jal     ra, putchar

    # Test SRLI
    li      t0, 0xF0000000
    srli    t1, t0, 4
    li      t2, 0x0F000000
    bne     t1, t2, error
    li      a0, '>'
    jal     ra, putchar

    # Test SRAI
    li      t0, 0xF0000000
    srai    t1, t0, 4
    li      t2, 0xFF000000
    bne     t1, t2, error
    li      a0, '/'
    jal     ra, putchar

    # Test ADD
    li      t0, 5
    li      t1, 3
    add     t2, t0, t1
    li      t3, 8
    bne     t2, t3, error
    li      a0, '+'
    jal     ra, putchar

    # Test SUB
    li      t0, 5
    li      t1, 3
    sub     t2, t0, t1
    li      t3, 2
    bne     t2, t3, error
    li      a0, '-'
    jal     ra, putchar

    # Test SLL
    li      t0, 0x0F
    li      t1, 4
    sll     t2, t0, t1
    li      t3, 0xF0
    bne     t2, t3, error
    li      a0, 'L'
    jal     ra, putchar

    # Test SLT
    li      t0, -1
    li      t1, 0
    slt     t2, t0, t1
    li      t3, 1
    bne     t2, t3, error
    li      a0, 's'
    jal     ra, putchar

    # Test SLTU
    li      t0, 0xFFFFFFFF
    li      t1, 0
    sltu    t2, t0, t1
    li      t3, 0
    bne     t2, t3, error
    li      a0, 'u'
    jal     ra, putchar

    # Test SRL
    li      t0, 0xF0000000
    li      t1, 4
    srl     t2, t0, t1
    li      t3, 0x0F000000
    bne     t2, t3, error
    li      a0, 'R'
    jal     ra, putchar

    # Test SRA
    li      t0, 0xF0000000
    li      t1, 4
    sra     t2, t0, t1
    li      t3, 0xFF000000
    bne     t2, t3, error
    li      a0, 'A'
    jal     ra, putchar

    # Test XOR
    li      t0, 0xAAAA5555
    li      t1, 0x5555AAAA
    xor     t2, t0, t1
    li      t3, 0xFFFFFFFF
    bne     t2, t3, error
    li      a0, 'X'
    jal     ra, putchar

    # Test OR
    li      t0, 0x12340000
    li      t1, 0x00005678
    or      t2, t0, t1
    li      t3, 0x12345678
    bne     t2, t3, error
    li      a0, 'O'
    jal     ra, putchar

    # Test AND
    li      t0, 0x12345678
    li      t1, 0xFFFF0000
    and     t2, t0, t1
    li      t3, 0x12340000
    bne     t2, t3, error
    li      a0, 'N'
    jal     ra, putchar

    # Test JAL
    jal     t0, 1f
    j       error
1:  la      t1, 1b
    addi    t1, t1, -4
    bne     t0, t1, error
    li      a0, 'J'
    jal     ra, putchar

    # Test BEQ
    li      t0, 5
    li      t1, 5
    beq     t0, t1, 1f
    j       error
1:  li      a0, 'E'
    jal     ra, putchar

    # Test BNE
    li      t0, 5
    li      t1, 6
    bne     t0, t1, 1f
    j       error
1:  li      a0, 'N'
    jal     ra, putchar

    # Test BLT
    li      t0, -1
    li      t1, 0
    blt     t0, t1, 1f
    j       error
1:  li      a0, 'B'
    jal     ra, putchar

    # Test BGE
    li      t0, 0
    li      t1, -1
    bge     t0, t1, 1f
    j       error
1:  li      a0, 'G'
    jal     ra, putchar

    # Test BLTU
    li      t0, 0
    li      t1, 1
    bltu    t0, t1, 1f
    j       error
1:  li      a0, 'L'
    jal     ra, putchar

    # Test BGEU
    li      t0, 0xFFFFFFFF
    li      t1, 0
    bgeu    t0, t1, 1f
    j       error
1:  li      a0, 'g'
    jal     ra, putchar

    # All tests passed
    j       pass

error:
    li      a0, '.'
    jal     ra, putchar
    jal     ra, putchar
    li      a0, 'e'
    jal     ra, putchar
    li      a0, 'r'
    jal     ra, putchar
    jal     ra, putchar
    li      a0, 10
    jal     ra, putchar
    ebreak

pass:
    li      a0, '.'
    jal     ra, putchar
    jal     ra, putchar
    li      a0, 'o'
    jal     ra, putchar
    li      a0, 'k'
    jal     ra, putchar
    li      a0, 10
    jal     ra, putchar
    ebreak


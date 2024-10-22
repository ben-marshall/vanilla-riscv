
.data

.align 4
original_mtvec: .word 0x0
int_seen_addr:  .word 0x0

.text

.func setup_timer_interrupt_handler
.global setup_timer_interrupt_handler
setup_timer_interrupt_handler:

    la t0, int_seen_addr
    la t1, timer_interrupt_handler
    la t2, original_mtvec
    
    sw a0,0(t0)         // int_seen_addr <- indicator address

    csrrw t1, mtvec, t1 // mtvec <- timer_interrupt_handler, t1 <- mtvec
    sw t1, 0(t2)        // original_mtvec <- t1=mtvec

    ret
.endfunc


.align 2
.func timer_interrupt_handler
.global timer_interrupt_handler
timer_interrupt_handler:

    addi sp,sp,-32
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2,12(sp)
    sw t3,16(sp)
    sw t4,20(sp)

    la t0, int_seen_addr
    lw t0, 0(t0)

    la t1, original_mtvec
    lw t1, 0(t1)

    li t2, 0x1
    sw t2,0(t0)         // int_seen_addr <- 1

    csrw mtvec, t1

    csrr t3, mcause     // Check mcause == 7, with MSB bit set.
    li   t4, 0x80000007
    bne  t3, t4, test_fail

    li t3, 0x00001008   // Set mtime cmp to something enormous.
    li t4, -1
    sw t4, 0(t3)
    sw t4, 4(t3)
    
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2,12(sp)
    lw t3,16(sp)
    lw t4,20(sp)
    addi sp,sp,32

    mret
.endfunc


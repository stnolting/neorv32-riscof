// SPDX-License-Identifier: BSD-3-Clause
// Modified for the NEORV32 RISC-V Processor by Stephan Nolting

#ifndef _COMPLIANCE_MODEL_H
#define _COMPLIANCE_MODEL_H

#define RVMODEL_DATA_SECTION                                                  \
        .pushsection .tohost,"aw",@progbits;                                  \
        .align 8; .global tohost; tohost: .dword 0;                           \
        .align 8; .global fromhost; fromhost: .dword 0;                       \
        .popsection;                                                          \
        .align 8; .global begin_regstate; begin_regstate:                     \
        .word 128;                                                            \
        .align 8; .global end_regstate; end_regstate:                         \
        .word 4;

//RV_COMPLIANCE_HALT
// neorv32: this will dump the results via the UART0_SIM_MODE data file output
// neorv32: due to the modifications on "end_signature" (not 4-aligned) we need to make sure we output a 4-aligned number of data here
// neorv32: -> for zero-padding of the rest of the SIGNATURE section
// neorv32: terminate simulation via VHDL2008 "finish", triggered by 0xCAFECAFE -> MEM[0xF0000000]
#define RVMODEL_HALT                                                          \
      signature_dump:                                                         \
        la   a0, begin_signature;                                             \
        la   a1, end_signature;                                               \
        li   a2, 0xFFFFFFA4;                                                  \
      signature_dump_loop:                                                    \
        beq  a0, a1, signature_dump_padding;                                  \
        lw   t0, 0(a0);                                                       \
        sw   t0, 0(a2);                                                       \
        addi a0, a0, 4;                                                       \
        j    signature_dump_loop;                                             \
nop;                                                                          \
nop;                                                                          \
      signature_dump_padding:                                                 \
        andi a0, a1, 0x0000000C;                                              \
        beq  a0, zero, signature_dump_end;                                    \
        li   t0, 16;                                                          \
        sub  a0, t0, a0;                                                      \
      signature_dump_padding_loop:                                            \
        beq  a0, zero, signature_dump_end;                                    \
        sw   zero, 0(a2);                                                     \
        addi a0, a0, -4;                                                      \
        j    signature_dump_padding_loop;                                     \
      signature_dump_end:                                                     \
nop;                                                                          \
nop;                                                                          \
      terminate_simulation:                                                   \
        li   a0, 0xF0000000;                                                  \
        li   a1, 0xCAFECAFE;                                                  \
        sw   a1, 0(a0);                                                       \
        j    terminate_simulation

//RVMODEL_BOOT
// neorv32: enable UART0 (ctrl(28)) and enable UART0_SIM_MODE (ctrl(12))
// neorv32: this code also provides a dummy trap handler that just moves on to the next instruction
// neorv32: -> this trap handler can be overridden by the compliance-suite by modifying mtval
// neorv32: -> the dummy trap handler is required to deal with the neorv32 X extension (= all illegal/undefined instruction trigger an exception)
#define RVMODEL_BOOT                                                          \
      core_init:                                                              \
        la x1, core_dummy_trap_handler;                                       \
        csrw   mtvec, x1;                                                     \
        csrw   mie, x0;                                                       \
        j      uart0_sim_mode_init;                                           \
nop;                                                                          \
nop;                                                                          \
      .balign 4;                                                              \
      core_dummy_trap_handler:                                                \
        csrw  mscratch, sp;                                                   \
        la    sp, end_signature;                                              \
        addi  sp, sp, 32;                                                     \
        sw    x8, 0(sp);                                                      \
        sw    x9, 4(sp);                                                      \
        csrr  x8, mcause;                                                     \
        blt   x8, zero, core_dummy_trap_handler_irq;                          \
        csrr  x8, mepc;                                                       \
      core_dummy_trap_handler_exc_c_check:                                    \
        lh    x9, 0(x8);                                                      \
        andi  x9, x9, 3;                                                      \
        addi  x8, x8, +2;                                                     \
        csrw  mepc, x8;                                                       \
        addi  x8, zero, 3;                                                    \
        bne   x8, x9, core_dummy_trap_handler_irq;                            \
      core_dummy_trap_handler_exc_uncrompressed:                              \
        csrr  x8, mepc;                                                       \
        addi  x8, x8, +2;                                                     \
        csrw  mepc, x8;                                                       \
      core_dummy_trap_handler_irq:                                            \
        lw    x9, 0(sp);                                                      \
        lw    x8, 4(sp);                                                      \
        csrr  sp, mscratch;                                                   \
        mret;                                                                 \
nop;                                                                          \
nop;                                                                          \
      uart0_sim_mode_init:                                                    \
        li    a0,   0xFFFFFFA0;                                               \
        sw    zero, 0(a0);                                                    \
        li    a1,   1 << 28;                                                  \
        li    a2,   1 << 12;                                                  \
        or    a1,   a1, a2;                                                   \
        sw    a1,   0(a0);

// declare the start of your signature region here. Nothing else to be used here.
// The .align 4 ensures that the signature ends at a 16-byte boundary
#define RVMODEL_DATA_BEGIN                                                    \
  RVMODEL_DATA_SECTION                                                        \
  .align 4; .global begin_signature; begin_signature:

// declare the end of the signature region here. Add other target specific contents here.
#define RVMODEL_DATA_END                                                      \
  .align 4; .global end_signature; end_signature:

//RVTEST_IO_INIT
#define RVMODEL_IO_INIT

//RVTEST_IO_WRITE_STR
#define RVMODEL_IO_WRITE_STR(_R, _STR)

//RVTEST_IO_CHECK
#define RVMODEL_IO_CHECK()

//RVTEST_IO_ASSERT_GPR_EQ
#define RVMODEL_IO_ASSERT_GPR_EQ(_S, _R, _I)

//RVTEST_IO_ASSERT_SFPR_EQ
#define RVMODEL_IO_ASSERT_SFPR_EQ(_F, _R, _I)

//RVTEST_IO_ASSERT_DFPR_EQ
#define RVMODEL_IO_ASSERT_DFPR_EQ(_D, _R, _I)

// NEORV32: specify the routine for setting machine software interrupt
#define RVMODEL_SET_MSW_INT                                                   \
      machine_irq_msi_set:                                                    \
        li   a0, 0xF0000000;                                                  \
        li   a1, 0x11111111;                                                  \
        sw   a1, 0(a0);

// NEORV32: specify the routine for clearing machine software interrupt
#define RVMODEL_CLEAR_MSW_INT                                                 \
      machine_irq_msi_clr:                                                    \
        li   a0, 0xF0000000;                                                  \
        li   a1, 0x22222222;                                                  \
        sw   a1, 0(a0);

// NEORV32: specify the routine for setting machine external interrupt
#define RVMODEL_SET_MEXT_INT                                                  \
      machine_irq_mei_set:                                                    \
        li   a0, 0xF0000000;                                                  \
        li   a1, 0x33333333;                                                  \
        sw   a1, 0(a0);

// NEORV32: specify the routine for clearing machine external interrupt
#define RVMODEL_CLEAR_MEXT_INT                                                \
      machine_irq_mei_clr:                                                    \
        li   a0, 0xF0000000;                                                  \
        li   a1, 0x44444444;                                                  \
        sw   a1, 0(a0);

// NEORV32: specify the routine for clearing machine timer interrupt
#define RVMODEL_CLEAR_MTIMER_INT                                              \
      machine_irq_mti_clr:                                                    \
        li   a0, 0xFFFFFF90;                                                  \
        li   a1, 0xFFFFFFFF;                                                  \
        sw   a1, 4(a0);                                                       \
        sw   a1, 0(a0);


#endif // _COMPLIANCE_MODEL_H

// SPDX-License-Identifier: BSD-3-Clause
// Modified for the NEORV32 RISC-V Processor by Stephan Nolting

#ifndef _COMPLIANCE_MODEL_H
#define _COMPLIANCE_MODEL_H

#define RVMODEL_DATA_SECTION                                  \
    .pushsection .tohost,"aw",@progbits;                      \
    .align 8; .global tohost; tohost: .dword 0;               \
    .align 8; .global fromhost; fromhost: .dword 0;           \
    .popsection;                                              \
    .align 8; .global begin_regstate; begin_regstate:         \
    .word 128;                                                \
    .align 8; .global end_regstate; end_regstate:             \
    .word 4;

// This will dump the test results (signature) via the testbench dump module.
#define RVMODEL_HALT                                          \
    signature_dump:                                           \
      la   a0, begin_signature;                               \
      la   a1, end_signature;                                 \
      li   a2, 0xF0000004;                                    \
    signature_dump_loop:                                      \
      bge  a0, a1, signature_dump_end;                        \
      lw   t0, 0(a0);                                         \
      sw   t0, 0(a2);                                         \
      addi a0, a0, 4;                                         \
      j    signature_dump_loop;                               \
    signature_dump_end:                                       \
      nop;                                                    \
    terminate_simulation:                                     \
      li   a0, 0xF0000000;                                    \
      li   a1, 0xCAFECAFE;                                    \
      sw   a1, 0(a0);                                         \
      j    terminate_simulation

#define RVMODEL_BOOT

// declare the start of your signature region here. Nothing else to be used here.
#define RVMODEL_DATA_BEGIN                                    \
    RVMODEL_DATA_SECTION                                      \
    .align 4;                                                 \
    .global begin_signature; begin_signature:

// declare the end of the signature region here. Add other target specific contents here.
#define RVMODEL_DATA_END                                      \
    .align 4;                                                 \
    .global end_signature; end_signature:

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
#define RVMODEL_SET_MSW_INT                                   \
    machine_irq_msi_set:                                      \
      li   a0, 0xF0000000;                                    \
      li   a1, 0x11111111;                                    \
      sw   a1, 0(a0);

// NEORV32: specify the routine for clearing machine software interrupt
#define RVMODEL_CLEAR_MSW_INT                                 \
    machine_irq_msi_clr:                                      \
      li   a0, 0xF0000000;                                    \
      li   a1, 0x22222222;                                    \
      sw   a1, 0(a0);

// NEORV32: specify the routine for setting machine external interrupt
#define RVMODEL_SET_MEXT_INT                                  \
    machine_irq_mei_set:                                      \
      li   a0, 0xF0000000;                                    \
      li   a1, 0x33333333;                                    \
      sw   a1, 0(a0);

// NEORV32: specify the routine for clearing machine external interrupt
#define RVMODEL_CLEAR_MEXT_INT                                \
    machine_irq_mei_clr:                                      \
      li   a0, 0xF0000000;                                    \
      li   a1, 0x44444444;                                    \
      sw   a1, 0(a0);

// NEORV32: specify the routine for setting machine timer interrupt
#define RVMODEL_SET_MTIMER_INT                                \
    machine_irq_mei_set:                                      \
      li   a0, 0xF0000000;                                    \
      li   a1, 0x55555555;                                    \
      sw   a1, 0(a0);

// NEORV32: specify the routine for clearing machine timer interrupt
#define RVMODEL_CLEAR_MTIMER_INT                              \
    machine_irq_mei_clr:                                      \
      li   a0, 0xF0000000;                                    \
      li   a1, 0x66666666;                                    \
      sw   a1, 0(a0);


#endif // _COMPLIANCE_MODEL_H

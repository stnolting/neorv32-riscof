#!/usr/bin/env bash

set -e

cd $(dirname "$0")

NEORV32_RTL=${NEORV32_RTL:-../neorv32/rtl}
SRC_FOLDER=${SRC_FOLDER:-.}

# # build library manually as automatic ghdl -i command doestn't handle coverage parameters
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_package.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_application_image.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_bootloader_image.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_boot_rom.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_bus_keeper.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_busswitch.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_cfs.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_cpu_alu.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_cpu_bus.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_cpu_control.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_cpu_cp_bitmanip.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_cpu_cp_cfu.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_cpu_cp_fpu.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_cpu_cp_muldiv.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_cpu_cp_shifter.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_cpu_decompressor.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_cpu_regfile.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_cpu.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_debug_dm.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_debug_dtm.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_dmem.entity.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_fifo.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_gpio.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_gptmr.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_icache.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_imem.entity.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_mtime.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_neoled.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_onewire.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_pwm.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_slink.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_spi.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_sysinfo.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_top.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_trng.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_twi.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_uart.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_wdt.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_wishbone.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_xip.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/neorv32_xirq.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/mem/neorv32_dmem.default.vhd
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08 "$NEORV32_RTL"/core/mem/neorv32_imem.default.vhd
ghdl -a --work=neorv32 --std=08 "$SRC_FOLDER"/neorv32_riscof_tb.vhd 

# #elaborate with coverage support
ghdl -e -Wl,-lgcov --std=08 --work=neorv32 neorv32_riscof_tb
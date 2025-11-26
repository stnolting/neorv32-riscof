#!/usr/bin/env bash

set -e

cd $(dirname "$0")

NEORV32_RTL=${NEORV32_RTL:-../neorv32/rtl}
SRC_FOLDER=${SRC_FOLDER:-.}

ghdl -i --work=neorv32 --std=08 "$NEORV32_RTL"/core/*.vhd "$SRC_FOLDER"/neorv32_riscof_tb.vhd
ghdl -m --std=08 --work=neorv32 neorv32_riscof_tb

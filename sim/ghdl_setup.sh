#!/usr/bin/env bash

set -e

cd $(dirname "$0")

NEORV32_RTL=${NEORV32_RTL:-../neorv32/rtl}
SRC_FOLDER=${SRC_FOLDER:-.}

# analyse with covvverage support (need compiled GHDL with gcc backend and gcov support) 
ghdl -a -Wc,-fprofile-arcs -Wc,-ftest-coverage --work=neorv32 --std=08  \
  "$NEORV32_RTL"/core/*.vhd \
  "$NEORV32_RTL"/core/mem/*.vhd 

ghdl -a --work=neorv32 --std=08 "$SRC_FOLDER"/neorv32_riscof_tb.vhd 

#elaborate with coverage support
ghdl -e -Wl,-lgcov neorv32_riscof_tb 


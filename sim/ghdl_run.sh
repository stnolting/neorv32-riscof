#!/usr/bin/env bash

set -e

cd $(dirname "$0")

# run arguments
GHDL_RUN_ARGS="${@}"

# run simulation
# timeout as fall-back - simulation should be terminated by the testbench using "finish;"
ghdl -r --std=08 --work=neorv32 neorv32_riscof_tb \
  $GHDL_RUN_ARGS \
  --max-stack-alloc=0 \
  --ieee-asserts=disable \
  --assert-level=error \
  --stop-time=4ms

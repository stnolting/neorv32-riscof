#!/usr/bin/env bash

set -e

cd $(dirname "$0")

SRC_FOLDER=${SRC_FOLDER:-.}

# run simulation
# timeout as fall-back - simulation should be terminated by the testbench using "finish;"
ghdl -r --std=08 --work=neorv32 neorv32_riscof_tb \
  -gMEM_FILE=${SRC_FOLDER}/main.hex \
  --max-stack-alloc=0 \
  --ieee-asserts=disable \
  --assert-level=error \
  --stop-time=4ms

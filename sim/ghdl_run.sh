#!/usr/bin/env bash

set -e

cd $(dirname "$0")

SRC_FOLDER=${SRC_FOLDER:-.}

# prepare simulation output file
touch DUT-neorv32.signature
chmod 777 DUT-neorv32.signature

GHDL="${GHDL:-ghdl}"

$GHDL -m --std=08 --work=neorv32 neorv32_riscof_tb

# timeout as fall-back; simulation should be terminated by the testbench using "finish;"
GHDL_TIMEOUT="--stop-time=4ms"

# custom arguments
GHDL_RUN_ARGS="${@}"
echo "Using custom simulation arguments: $GHDL_RUN_ARGS";

# run simulation
$GHDL -r --std=08 --work=neorv32 neorv32_riscof_tb \
  -gMEM_FILE=${SRC_FOLDER}/main.hex \
  --max-stack-alloc=0 \
  --ieee-asserts=disable \
  --assert-level=error $GHDL_RUN_ARGS $GHDL_TIMEOUT

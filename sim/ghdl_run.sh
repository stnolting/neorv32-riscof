#!/usr/bin/env bash

set -e

cd $(dirname "$0")

SRC_FOLDER=${SRC_FOLDER:-.}

# prepare simulation output files for UART0 simulation mode
# -> direct simulation output (neorv32.uart0.sim_mode.[text|data].out)
touch neorv32.uart0.sim_mode.data.out
chmod 777 neorv32.uart0.sim_mode.data.out
touch neorv32.uart0.sim_mode.text.out
chmod 777 neorv32.uart0.sim_mode.text.out

GHDL="${GHDL:-ghdl}"

$GHDL -m --std=08 --work=neorv32 neorv32_riscof_tb

# timeout as fall-back; simulation should be terminated by the testbench using "finish;"
GHDL_TIMEOUT="--stop-time=2ms"

# custom arguments
GHDL_RUN_ARGS="${@}"
echo "Using custom simulation arguments: $GHDL_RUN_ARGS";

# run simulation
$GHDL -r --std=08 --work=neorv32 neorv32_riscof_tb \
  -gIMEM_FILE=${SRC_FOLDER}/main.hex \
  --max-stack-alloc=0 \
  --ieee-asserts=disable \
  --assert-level=error $GHDL_RUN_ARGS $GHDL_TIMEOUT

# Rename final signature file
cp -f neorv32.uart0.sim_mode.data.out DUT-neorv32.signature

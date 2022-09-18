#!/usr/bin/env bash

set -e

riscof run --config=config.ini \
           --suite=riscv-arch-test/riscv-test-suite/ \
           --env=riscv-arch-test/riscv-test-suite/env \
           --no-browser

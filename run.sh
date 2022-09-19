#!/usr/bin/env bash

set -e

riscof run --config=config.ini \
           --suite=riscv-arch-test/riscv-test-suite/ \
           --env=riscv-arch-test/riscv-test-suite/env \
           --no-browser

if grep -rni riscof_work/report.html -e '>0failed<'
then
  echo "Test successful!"
  exit 0
else
  echo "Test failed!"
  exit 1
fi

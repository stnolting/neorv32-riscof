# NEORV32 Core Verification using RISCOF

[![neorv32-riscof](https://img.shields.io/github/actions/workflow/status/stnolting/neorv32-riscof/main.yml?branch=main&longCache=true&style=flat-square&label=neorv32-riscof&logo=Github%20Actions&logoColor=fff)](https://github.com/stnolting/neorv32-riscof/actions/workflows/main.yml)
[![License](https://img.shields.io/github/license/stnolting/neorv32-riscof?longCache=true&style=flat-square&label=License)](https://github.com/stnolting/neorv32-riscof/blob/main/LICENSE)

1. [Prerequisites](#prerequisites)
2. [Setup Configuration](#setup-configuration)
3. [Device-Under-Test (DUT)](#device-under-test-dut)

This repository is a port of the "**RISCOF** RISC-V Architectural Test Framework" to test the
[NEORV32 RISC-V Processor](https://github.com/stnolting/neorv32) for compatibility to the RISC-V
user and privileged ISA specifications. **Sail RISC-V** is used as reference model.
Currently, the following tests are supported:

- [x] `rv32i_m\A` - atomic memory operations (`Zaamo` only)
- [x] `rv32i_m\B` - bit-manipulation (`Zba` + `Zbb` + `Zbs`)
- [x] `rv32i_m\C` - compressed instructions (`Zca` + `Zcb`)
- [x] `rv32i_m\I` - base integer ISA
- [x] `rv32i_m\K` - scalar cryptography, `Zkn` and `Zks` (`Zbkb` + `Zbkc` + `Zbkx` + `Zknd` + `Zkne` + `Zknh` + `Zksed` + `Zksh`)
- [x] `rv32i_m\M` - hardware integer multiplication and division
- [x] `rv32i_m\Zicond` - conditional operations
- [x] `rv32i_m\Zifencei` - instruction stream synchronization
- [x] `rv32i_m\Zimop` - may-be-operation
- [x] `rv32i_m\hints` - hint instructions
- [x] `rv32i_m\pmp` - physical memory protection (`M` + `U` modes)
- [x] `rv32i_m\privilege` - privileged machine-mode architecture

> [!TIP]
> The general structure of this repository was setup according to the
[RISCOF installation guide](https://riscof.readthedocs.io/en/stable/installation.html).


## Prerequisites

Several tools and submodules are required to run this port of the architecture test framework. The repository's
GitHub [Actions workflow](https://github.com/stnolting/neorv32-riscof/blob/main/.github/workflows/main.yml)
takes care of installing all the required packages.

* [neorv32](https://github.com/stnolting/neorv32) submodule - the device under test (DUT)
* [riscv-arch-test](https://github.com/riscv-non-isa/riscv-arch-test) submodule - architecture test cases
* [RISC-V GCC toolchain](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack) - for compiling native `rv32` code
* [Sail RISC-V](https://github.com/riscv/sail-riscv) - the reference model (a pre-built binary can be found in
the [`bin`](https://github.com/stnolting/neorv32-riscof/tree/main/bin) folder)
* [RISCOF](https://github.com/riscv-software-src/riscof) - the architecture test framework (including
[riscv-isac](https://github.com/riscv-software-src/riscv-isac) and [riscv-config](https://github.com/riscv-software-src/riscv-config))
* [GHDL](https://github.com/ghdl/ghdl) - the _awesome_ VHDL simulator for simulating the DUT

> [!IMPORTANT]
> The `riscv-arch-test` submodule is pinned to a specific commit and ignored by _dependabot_. The source repository
is under continuous development. Unfortunately, sometimes non-compatible modifications (i.e. test cases that forget
to check for actually configured ISA extensions; see https://github.com/riscv-non-isa/riscv-arch-test/issues/552)
sneak into the main branch.

The framework (running all tests) is invoked via a single shell script
[`run.sh`](https://github.com/stnolting/neorv32-riscof/blob/main/run.sh) that returns 0 if all tests were executed
successfully or 1 if there were any errors. The exit code of this script is used to determine the overall success
of the GitHub Actions workflow.


## Setup Configuration

The RISCOF [config.ini](https://github.com/stnolting/neorv32-riscof/blob/main/config.ini) file is used to configure
the plugins to be used: the device-under-test ("DUT") and the reference model ("REF"). The ISA, debug and platform
specifications, which define target-specific configurations like available ISA extensions, ISA spec. versions and
platform modules, are defined by `YAML` files in the according plugin folders.

* DUT: `neorv32` in [`plugin-neorv32`](https://github.com/stnolting/neorv32-riscof/tree/main/plugin-neorv32)
* REF: `sail_cSim` in [`plugin-sail_cSim`](https://github.com/stnolting/neorv32-riscof/tree/main/plugin-sail_cSim)

Each plugin folder also provides low-level _environment_ files like linker scripts (to generate an executable
image matching the target's memory layout) as well as platform-specific code wrapped within environment macros
(for example to initialize the target and to dump the final test signatures/results).

The official [RISC-V architecture tests](https://github.com/riscv-non-isa/riscv-arch-test) repository provides the
individual test cases for all (ratified) RISC-V ISA extensions (user and privilege ISA) that are currently supported
by the DUT.

The "golden reference" data is generated by the **Sail RISC-V Model**. This data is compared
against the results of the DUT. The CSS-flavored HTML test report is available as
[GitHib actions artifact](https://github.com/stnolting/neorv32-riscof/actions).


## Device-Under-Test (DUT)

The [`sim`](https://github.com/stnolting/neorv32-riscof/tree/main/sim) folder provides a plain-VHDL testbench
and shell scripts to simulate the NEORV32 processor using **GHDL**. The testbench provides generics to configure the
DUT's RISC-V ISA extensions and also to pass a plain ASCII HEX file, which represents the _memory image_ containing
the actual executable. This file generated from the test-case-specific ELF file. The makefile in the `sim` folder
takes care of compilation and will also convert the final memory image into a plain HEX file. Note that this makefile
uses the default software framework from the NEORV32 submodule.

The testbench implements a CPU-external memory module that get initialized with the actual memory image provided by the
test framework. This memory is attached to the processor via its external Wishbone bus interface and is mapped to the core's
reset address that is set to `0x80000000`. Additionally, an environment interface module is connected to the processor's
external bus interface. It provides several functions mapped to distinct addresses:

* `0xF0000000`: write any value to quit the simulation (vie VHDL's `finish;`)
* `0xF0000004`: written data (32-bit) is converted to a 8 HEX char string that is written to the test's signature output file
* `0xF0000008`: the data in the lowest byte of the write data is printed to the simulator console
* `0xF000000C`: write 1 to the according bit to set the core's interrupt lines (`3 -> MSI, 7 -> MTI, 11 -> MEI`)

The simulation scripts and the makefile for generating the memory initialization file are invoked and orchestrated from
a DUT-specific Python script in the DUT's plugin folder
(-> [`plugin-neorv32/riscof_neorv32.py`](https://github.com/stnolting/neorv32-riscof/blob/main/plugin-neorv32/riscof_neorv32.py)).
This Python script makes extensive use of shell commands to move and execute files and scripts.

> [!IMPORTANT]
> The Python scripts of **both plugins** override the default `SET_REL_TVAL_MSK` macro from
`riscv-arch-test/riscv-test-suite/env/arch_test.h` to remove the BREAK exception cause from the relocation list as the
NEORV32 sets `mtval` to zero for this type of exception. This is **explicitly permitted** by the RISC-V priv. spec.

# NEORV32 Core Verification using RISCOF

[![neorv32-riscof](https://img.shields.io/github/workflow/status/stnolting/neorv32-riscof/NEORV32%20RISCOF%20Verification/main?longCache=true&style=flat-square&label=neorv32-riscof&logo=Github%20Actions&logoColor=fff)](https://github.com/stnolting/neorv32-riscof/actions/workflows/main.yml)
[![License](https://img.shields.io/github/license/stnolting/neorv32-riscof?longCache=true&style=flat-square&label=License)](https://github.com/stnolting/neorv32-riscof/blob/main/LICENSE)
[![Gitter](https://img.shields.io/badge/Chat-on%20gitter-4db797.svg?longCache=true&style=flat-square&logo=gitter&logoColor=e8ecef)](https://gitter.im/neorv32/community)

1. [Prerequisites](#Prerequisites)
2. [Setup Configuration](#Setup-Configuration)
3. [Device-Under-Test (DUT)](#Device-Under-Test-DUT)
4. [Compatibility Issues](#Compatibility-Issues)

This repository is a port of the "**RISCOF** RISC-V Architectural Test Framework" to test the
[NEORV32 RISC-V Processor](https://github.com/stnolting/neorv32) for compatibility to the RISC-V
user and privileged ISA specifications. The **Sail RISC-V** model is used as reference model.
Currently, the following tests are implemented:

- [x] `rv32i_m\B` - bit-manipulation
- [x] `rv32i_m\C` - compressed instructions
- [x] `rv32i_m\I` - base integer ISA
- [x] `rv32i_m\M` - hardware multiplication and division
- [x] `rv32i_m\privilege` - privileged machine architecture
- [x] `rv32i_m\Zifencei` - instruction stream synchronization

:bulb: The general structure of this repository was setup according to the
[RISCOF installation guide](https://riscof.readthedocs.io/en/stable/installation.html).


## Prerequisites

Several tools and submodules are required to run this port of the architecture test framework.
The repository's GitHub [workflow](https://github.com/stnolting/neorv32-riscof/blob/main/.github/workflows/main.yml)
takes care of installing all the required packages.

* [neorv32](https://github.com/stnolting/neorv32) submodule - the device under test (DUT)
* [riscv-arch-test](https://github.com/riscv-non-isa/riscv-arch-test) submodule - architecture test cases
* [RISC-V GCC toolchain](https://github.com/stnolting/riscv-gcc-prebuilt) - for compiling native `rv32` code
* [Sail RISC-V](https://github.com/riscv/sail-riscv) - the reference model
* [RISCOF](https://github.com/riscv-software-src/riscof) - the architecture test framework
* [GHDL](https://github.com/ghdl/ghdl) - the _awesome_ VHDL simulator for simulating the DUT

The framework (running all tests) is invoked via a single shell script
[`run.sh`](https://github.com/stnolting/neorv32-riscof/blob/main/run.sh) that returns 0 if all tests were executed
successfully and 1 if there were any errors. The exit code of this script is used to determine the overall success
of the GitHub action and thus, defines the workflow's badge status.

[[back to top](#NEORV32-Core-Verification-using-RISCOF)]


## Setup Configuration

The RISCOF [config.ini](https://github.com/stnolting/neorv32-riscof/blob/main/config.ini) is used to configure
the plugins to be used: the device-under-test ("DUT") and the reference model ("REF").
The ISA, debug and platform specifications, which define target specific configurations like available ISA
extensions, platform modules like MTIME and ISA spec. versions, are defined via `YAML` files in the DUT's
plugin folder.

* DUT: `neorv32` in [`plugin-neorv32`](https://github.com/stnolting/neorv32-riscof/tree/main/plugin-neorv32)
* REF: `sail_cSim` in [`plugin-sail_cSim`](https://github.com/stnolting/neorv32-riscof/tree/main/plugin-sail_cSim)

According to the plugin, each plugin folder also provides low-level _environment_ files like linker scripts
(to generate an executable matching the target's memory layout) and platform-specific code (for example to
initialize the target and to dump test results).

The official [RISC-V architecture tests](https://github.com/riscv-non-isa/riscv-arch-test) repository
provides test cases for all (ratified) RISC-V ISA extensions (user and privilege ISA). Each test case tests
a single instruction or core feature and is compiled into a plugin-specific executable
using a [prebuilt RISC-V GCC toolchain](https://github.com/stnolting/riscv-gcc-prebuilt).

The "golden" reference data is generated using the **Sail RISC-V Model** and
compared to the results of the DUT. The final test report is available as CSS-flavored HTML file via the
[GitHib actions artifact](https://github.com/stnolting/neorv32-riscof/actions).

:bulb: Prebuilt _sail-riscv_ binaries for 64-bit Linux are available in the
[`bin`](https://github.com/stnolting/neorv32-riscof/tree/main/bin) folder.

[[back to top](#NEORV32-Core-Verification-using-RISCOF)]


## Device-Under-Test (DUT)

The [`sim`](https://github.com/stnolting/neorv32-riscof/tree/main/sim) folder provides a simple testbench and
shell scripts to simulate the NEORV32 processor using **GHDL**. The testbench provides generics to configure the
DUT's RISC-V ISA extensions and also to pass a plain ASCII HEX file, which represents the actual executable
to be executed ("memory initialization file") that is generated by the folder's makefile from a test-specific
ELF file.The makefile uses the default software framework from the NEORV32 submodule (more specific: the image
generator) to generate a memory initialization file from a compiled ELF file.

:warning: The testbench implements _four_ CPU-external memory modules that get initialized with the actual executable.
The memories are coupled using the processor's Wishbone external bus interface and are mapped to
the core's reset address at `0x00000000`.
Each memory module implements a physical memory size of 512kB resulting in a total memory size of 2MB (the
largest test case executable comes from the `I/jal` test case with approx. 1.7MB). This "splitting" is required as GHDL has
problems handling large objects (see https://github.com/ghdl/ghdl/issues/1592).

:books: The "simulation mode" of the processor's UART0 module is used to _dump_ the test result data (= the
_test signature_) to a file. More information regarding the UART simulation mode can be found in the
[NEORV32 online data sheet](https://stnolting.github.io/neorv32/).

The testbench also provides a "trigger mechanism" to quit the current simulation using VHDL08's `finish`
statement. Quitting the simulation is triggered by writing `0xCAFECAFE` to address `0xF0000000`, which
is implemented (software) by the DUT's plugin environment module. A maximum simulation timeout of 2ms is
provided to terminate faulty simulations that might end up in an infinite loop.

The simulation scripts and the makefile for generating the memory initialization file are invoked from DUT-
specific Python script in the DUT's plugin folder
(-> [`plugin-neorv32/riscof_neorv32.py`](https://github.com/stnolting/neorv32-riscof/blob/main/plugin-neorv32/riscof_neorv32.py)).
This Python script makes extensive use of shell commands to move and execute files and scripts
(my Python skills are still quite limited 😅).

[[back to top](#NEORV32-Core-Verification-using-RISCOF)]


## Compatibility Issues

:warning: :warning: :warning:

The current version of the Sail RISC-V model does not support a target-specific configuration of the
core's events that update the `mtval` trap value CSR: the NEORV32 writes zero to this CSR when encountering an `ebreak`
(breakpoint) exception while the original Sail model writes the address of the triggering `ebreak` instruction
to `mtval`. However, constraining platform-specific events that write (or not) to `mtval` is explicitly
allowed by the RISC-V ISA specification
(see [riscv-software-src/riscv-config/issues/16](https://github.com/riscv-software-src/riscv-config/issues/16)).

To circumvent this, a [patch](https://github.com/stnolting/neorv32-riscof/blob/main/riscv-arch-test.mtval_ebreak.patch)
is applied to the default `riscv-arch-test` submodule, which adds code to set the `mtval` portion of the test
signature to all-zero if a breakpoint exception occurs.
This is only relevant for the `privilege/ebreak.S` and `C/cebreak-01.S` test cases.

This "hack" might be abandoned with future versions of RISCOF/sail.

[[back to top](#NEORV32-Core-Verification-using-RISCOF)]

# Prebuilt Sail-C-RISCV Model Binaries

The binaries were built according to the official
[RISCOF instructions](https://riscof.readthedocs.io/en/stable/installation.html#install-plugin-models)
on a **64bit Ubuntu** machine (actually on Ubuntu on 64-bit x86 Windows 10 WSL).
For more information see the official [sail-riscv](https://github.com/riscv/sail-riscv) and
[RISCOF](https://github.com/riscv-software-src/riscof) GitHub repositories.

Included simulator binaries:
* `riscv_sim_RV32`
* `riscv_sim_RV64`

To run the simulator(s) on your system decompress the archive into a new
folder (e.g. `opt/sail-riscv`; might require elevated privileges):

```bash
sudo mkdir opt/sail-riscv
sudo tar -xzf $sail-riscv.18.09.22.tar.gz -C opt/sail-riscv
```

Add this folder to your system's `PATH` environment variable:

```bash
export PATH=$PATH:/opt/sail-riscv
```

Built and published on September 18th, 2022.

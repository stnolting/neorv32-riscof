# Prebuilt Sail-C-RISCV Model Binaries

Included simulator binaries:
* `riscv_sim_RV32`
* `riscv_sim_RV64`

The binaries were built according to the official
[RISCOF instructions](https://riscof.readthedocs.io/en/stable/installation.html#install-plugin-models).
For more information visit the official [sail-riscv](https://github.com/riscv/sail-riscv) and
[RISCOF](https://github.com/riscv-software-src/riscof) GitHub repositories.

To run the simulators on your system decompress the archive into a new folder (e.g. `opt/sail-riscv`):

```bash
sudo mkdir opt/sail-riscv
sudo tar -xzf $sail-riscv.18.09.22.tar.gz -C opt/sail-riscv
```

Add the folder to your `.bashrc` (to your system's `PATH` environment variable):

```bash
export PATH=$PATH:/opt/sail-riscv
```

Built and published on September 18th, 2022.
  
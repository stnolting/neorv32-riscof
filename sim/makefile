# Convert main.elf into an executable memory initialization file main.hex

current_dir = $(shell pwd)

# Path to NEORV32 executable generator
NEORV32_EXG_PATH = ../neorv32/sw/image_gen

# RISC-V GCC
RISCV_PREFIX ?= riscv-none-elf-
OBJCOPY = $(RISCV_PREFIX)objcopy
OBJDUMP = $(RISCV_PREFIX)objdump
READELF = $(RISCV_PREFIX)readelf

# Host native compiler
CC_X86 = gcc -Wall -O -g

# NEORV32 executable image generator
IMAGE_GEN = $(NEORV32_EXG_PATH)/image_gen

# install/compile tools
$(IMAGE_GEN): $(NEORV32_EXG_PATH)/image_gen.c
	@echo Compiling $(IMAGE_GEN)
	@$(CC_X86) $< -o $(IMAGE_GEN)

# Generate final executable from .text (defined by platform-specific linker script)
main.bin: $(current_dir)/main.elf
	@$(OBJCOPY) -I elf32-little $< -j .text -O binary $@

# Generate RAW executable image in plain hex format
main.hex: main.bin $(IMAGE_GEN)
	@set -e
	@$(IMAGE_GEN) -raw_hex $< $@ $(shell basename $(CURDIR))

# Generate assembly file (for debugging)
main.asm: $(current_dir)/main.elf
	@$(OBJDUMP) -d -S --section=.text $< > $@

# Generate NEORV32 executable VHDL boot image
main.vhd: main.bin $(IMAGE_GEN)
	@set -e
	@$(IMAGE_GEN) -app_vhd $< $@ $(shell basename $(CURDIR))

# Remove artifacts
clean:
	@rm -f *.o *.bin *.out *.hex *.asm *.signature

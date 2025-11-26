-- ================================================================================ --
-- neorv32_riscof_tb.vhd - Testbench for running RISCOF                             --
-- -------------------------------------------------------------------------------- --
-- https://github.com/stnolting/neorv32-riscof                                      --
-- Copyright (c) 2022 - 2025 Stephan Nolting. All rights reserved.                  --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library std;
use std.textio.all;
use std.env.finish;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_riscof_tb is
  generic (
    MEM_FILE : string := "" -- memory initialization file (max 4MB)
  );
end neorv32_riscof_tb;

architecture neorv32_riscof_tb_rtl of neorv32_riscof_tb is

  -- memory configuration --
  constant mem_size_c : natural := 4*1024*1024; -- bytes
  constant mem_base_c : std_ulogic_vector(31 downto 0) := x"80000000";

  -- memory type --
  type mem8_bv_t is array (natural range <>) of bit_vector(7 downto 0); -- bit_vector type for optimized system storage

  -- initialize mem8_bv_t array from plain ASCII HEX file  --
  impure function mem8_bv_init_f(file_name : string; num_words : natural; byte_sel : natural) return mem8_bv_t is
    file     text_file   : text open read_mode is file_name;
    variable text_line_v : line;
    variable mem8_bv_v   : mem8_bv_t(0 to num_words-1);
    variable index_v     : natural;
    variable word_v      : bit_vector(31 downto 0);
  begin
    mem8_bv_v := (others => (others => '0'));
    index_v   := 0;
    if (file_name /= "") then
      while (endfile(text_file) = false) and (index_v < num_words) loop
        readline(text_file, text_line_v);
        hread(text_line_v, word_v);
        case byte_sel is
          when 0      => mem8_bv_v(index_v) := word_v(07 downto 00);
          when 1      => mem8_bv_v(index_v) := word_v(15 downto 08);
          when 2      => mem8_bv_v(index_v) := word_v(23 downto 16);
          when others => mem8_bv_v(index_v) := word_v(31 downto 24);
        end case;
        index_v := index_v + 1;
      end loop;
    end if;
    return mem8_bv_v;
  end function mem8_bv_init_f;

  -- memory word address --
  signal mem_addr : integer range 0 to (mem_size_c/4)-1;

  -- generators --
  signal clk_gen, rst_gen : std_ulogic := '0';

  -- external bus interface --
  type xbus_t is record
    addr  : std_ulogic_vector(31 downto 0);
    wdata : std_ulogic_vector(31 downto 0);
    rdata : std_ulogic_vector(31 downto 0);
    we    : std_ulogic;
    sel   : std_ulogic_vector(03 downto 0);
    stb   : std_ulogic;
    cyc   : std_ulogic;
    ack   : std_ulogic;
  end record;
  signal xbus : xbus_t;

  signal mem_rdata : std_ulogic_vector(31 downto 0);
  signal mem_ack, env_ack : std_ulogic;
  signal msi, mei, mti : std_ulogic;

begin

  -- Clock/Reset Generator ------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  clk_gen <= not clk_gen after 5 ns;
  rst_gen <= '0', '1' after 100 ns;


  -- The Core of the Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst: neorv32_top
  generic map (
    -- Processor Clocking --
    CLOCK_FREQUENCY     => 100_000_000,
    -- Boot Configuration --
    BOOT_MODE_SELECT    => 1, -- boot from BOOT_ADDR_CUSTOM
    BOOT_ADDR_CUSTOM    => mem_base_c,
    -- RISC-V CPU Extensions --
    RISCV_ISA_C         => true,
    RISCV_ISA_M         => true,
    RISCV_ISA_U         => true,
    RISCV_ISA_Zaamo     => true,
    RISCV_ISA_Zcb       => true,
    RISCV_ISA_Zba       => true,
    RISCV_ISA_Zbb       => true,
    RISCV_ISA_Zbkb      => true,
    RISCV_ISA_Zbkc      => true,
    RISCV_ISA_Zbkx      => true,
    RISCV_ISA_Zbs       => true,
    RISCV_ISA_Zicntr    => true,
    RISCV_ISA_Zicond    => true,
    RISCV_ISA_Zknd      => true,
    RISCV_ISA_Zkne      => true,
    RISCV_ISA_Zknh      => true,
    RISCV_ISA_Zksed     => true,
    RISCV_ISA_Zksh      => true,
    -- Tuning Options --
    CPU_FAST_MUL_EN     => true,
    CPU_FAST_SHIFT_EN   => true,
    -- Physical Memory Protection --
    PMP_NUM_REGIONS     => 16,
    PMP_MIN_GRANULARITY => 4,
    PMP_TOR_MODE_EN     => true,
    PMP_NAP_MODE_EN     => true,
    -- Internal memories --
    IMEM_EN             => false,
    DMEM_EN             => false,
    -- External bus interface --
    XBUS_EN             => true,
    XBUS_REGSTAGE_EN    => false,
    -- Processor peripherals --
    IO_CLINT_EN         => true,
    IO_TRACER_EN        => true,
    IO_TRACER_BUFFER    => 1,
    IO_TRACER_SIMLOG_EN => true
  )
  port map (
    -- Global control --
    clk_i       => clk_gen,
    rstn_i      => rst_gen,
    -- External bus interface --
    xbus_adr_o  => xbus.addr,
    xbus_dat_i  => xbus.rdata,
    xbus_dat_o  => xbus.wdata,
    xbus_we_o   => xbus.we,
    xbus_sel_o  => xbus.sel,
    xbus_stb_o  => xbus.stb,
    xbus_cyc_o  => xbus.cyc,
    xbus_ack_i  => xbus.ack,
    xbus_err_i  => '0',
    -- CPU Interrupts --
    mtime_irq_i => mti,
    msw_irq_i   => msi,
    mext_irq_i  => mei
  );

  -- bus feedback --
  xbus.rdata <= mem_rdata;
  xbus.ack   <= mem_ack or env_ack;


  -- Main Memory [rwx] - Constructed from four parallel byte-wide memories ------------------
  -- -------------------------------------------------------------------------------------------
  main_mem: process(clk_gen)
    variable mem8_bv_b0_v : mem8_bv_t(0 to (mem_size_c/4)-1) := mem8_bv_init_f(MEM_FILE, mem_size_c/4, 0);
    variable mem8_bv_b1_v : mem8_bv_t(0 to (mem_size_c/4)-1) := mem8_bv_init_f(MEM_FILE, mem_size_c/4, 1);
    variable mem8_bv_b2_v : mem8_bv_t(0 to (mem_size_c/4)-1) := mem8_bv_init_f(MEM_FILE, mem_size_c/4, 2);
    variable mem8_bv_b3_v : mem8_bv_t(0 to (mem_size_c/4)-1) := mem8_bv_init_f(MEM_FILE, mem_size_c/4, 3);
  begin
    if rising_edge(clk_gen) then
      -- defaults --
      mem_rdata <= (others => '0');
      mem_ack   <= '0';
      -- bus access --
      if (xbus.cyc = '1') and (xbus.stb = '1') and (xbus.addr(31 downto 28) = mem_base_c(31 downto 28)) then
        mem_ack <= '1';
        if (xbus.we = '1') then
          if (xbus.sel(0) = '1') then mem8_bv_b0_v(mem_addr) := to_bitvector(xbus.wdata(07 downto 00)); end if;
          if (xbus.sel(1) = '1') then mem8_bv_b1_v(mem_addr) := to_bitvector(xbus.wdata(15 downto 08)); end if;
          if (xbus.sel(2) = '1') then mem8_bv_b2_v(mem_addr) := to_bitvector(xbus.wdata(23 downto 16)); end if;
          if (xbus.sel(3) = '1') then mem8_bv_b3_v(mem_addr) := to_bitvector(xbus.wdata(31 downto 24)); end if;
        else
          mem_rdata(07 downto 00) <= to_stdulogicvector(mem8_bv_b0_v(mem_addr));
          mem_rdata(15 downto 08) <= to_stdulogicvector(mem8_bv_b1_v(mem_addr));
          mem_rdata(23 downto 16) <= to_stdulogicvector(mem8_bv_b2_v(mem_addr));
          mem_rdata(31 downto 24) <= to_stdulogicvector(mem8_bv_b3_v(mem_addr));
        end if;
      end if;
    end if;
  end process main_mem;

  -- read/write address --
  mem_addr <= to_integer(unsigned(xbus.addr(index_size_f(mem_size_c/4)+1 downto 2)));


  -- Environment Control --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  env_ctrl: process(rst_gen, clk_gen)
    file     file_v : text open write_mode is "DUT-neorv32.signature";
    variable line_v : line;
    variable char_v : integer;
  begin
    if (rst_gen = '0') then
      env_ack <= '0';
      msi     <= '0';
      mti     <= '0';
      mei     <= '0';
    elsif rising_edge(clk_gen) then
      env_ack <= '0';
      if (xbus.cyc = '1') and (xbus.stb = '1') and (xbus.we = '1') then
        -- terminate simulation --
        if (xbus.addr = x"F0000000") then
          env_ack <= '1';
          assert false report "Finishing simulation." severity note;
          finish;
        -- write to log file --
        elsif (xbus.addr = x"F0000004") then
          env_ack <= '1';
          for i in 7 downto 0 loop -- write 32-bit as 8 lowercase HEX chars
            write(line_v, to_hexchar_f(xbus.wdata(3+i*4 downto 0+i*4)));
          end loop;
          writeline(file_v, line_v);
        -- write to console --
        elsif (xbus.addr = x"F0000008") then
          env_ack <= '1';
          char_v := to_integer(unsigned(xbus.wdata(7 downto 0)));
          if (char_v >= 128) then -- out of printable range?
            char_v := 0;
          end if;
          if (char_v = 10) then -- line break: flush to console
            writeline(output, line_v); -- console
          elsif (char_v /= 13) then
            write(line_v, character'val(char_v));
          end if;
        -- interrupt triggers --
        elsif (xbus.addr = x"F000000C") then
          env_ack <= '1';
          msi     <= xbus.wdata(3);
          mti     <= xbus.wdata(7);
          mei     <= xbus.wdata(11);
        end if;
      end if;
    end if;
  end process env_ctrl;


end neorv32_riscof_tb_rtl;

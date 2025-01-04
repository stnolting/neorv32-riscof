-- ================================================================================ --
-- neorv32_riscof_tb.vhd - Testbench for running RISCOF                             --
-- -------------------------------------------------------------------------------- --
-- A processor-external memory is initialized by a plain ASCII HEX file that        --
-- contains the executable and all relevant data. The memory is split into four     --
-- sub-modules using variables of type bit_vector to minimize the host's simulation --
-- RAM footprint. Test signature data is dumped to a file "DUT-neorv32.signature"   --
-- by writing to address 0xF0000004. The simulation is terminated by writing        --
-- 0xCAFECAFE to address 0xF0000000. Note that this testbench requires VHDL2008.    --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) 2020 - 2025 Stephan Nolting. All rights reserved.                  --
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

  -- total memory size in bytes --
  constant mem_size_c : natural := 4*1024*1024;

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
    mem8_bv_v := (others => (others => '0')); -- initialize to all-zero
    index_v   := 0;
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

  signal xmem_rdata, dump_rdata       : std_ulogic_vector(31 downto 0);
  signal xmem_ack, dump_ack, trig_ack : std_ulogic;

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
    CLOCK_FREQUENCY   => 100_000_000,
    -- Boot Configuration --
    BOOT_MODE_SELECT  => 1, -- boot from BOOT_ADDR_CUSTOM
    BOOT_ADDR_CUSTOM  => x"00000000",
    -- RISC-V CPU Extensions --
    RISCV_ISA_C       => true,
    RISCV_ISA_M       => true,
    RISCV_ISA_U       => true,
    RISCV_ISA_Zaamo   => true,
    RISCV_ISA_Zba     => true,
    RISCV_ISA_Zbb     => true,
    RISCV_ISA_Zbkb    => true,
    RISCV_ISA_Zbkc    => true,
    RISCV_ISA_Zbkx    => true,
    RISCV_ISA_Zbs     => true,
    RISCV_ISA_Zicntr  => true,
    RISCV_ISA_Zicond  => true,
    RISCV_ISA_Zknd    => true,
    RISCV_ISA_Zkne    => true,
    RISCV_ISA_Zknh    => true,
    RISCV_ISA_Zksed   => true,
    RISCV_ISA_Zksh    => true,
    -- Tuning Options --
    CPU_FAST_MUL_EN   => true,
    CPU_FAST_SHIFT_EN => true,
    -- Internal memories --
    MEM_INT_IMEM_EN   => false,
    MEM_INT_DMEM_EN   => false,
    -- External bus interface --
    XBUS_EN           => true,
    XBUS_TIMEOUT      => 7,
    XBUS_REGSTAGE_EN  => false
  )
  port map (
    -- Global control --
    clk_i      => clk_gen,
    rstn_i     => rst_gen,
    -- External bus interface (available if XBUS_EN = true) --
    xbus_adr_o => xbus.addr,
    xbus_dat_i => xbus.rdata,
    xbus_dat_o => xbus.wdata,
    xbus_we_o  => xbus.we,
    xbus_sel_o => xbus.sel,
    xbus_stb_o => xbus.stb,
    xbus_cyc_o => xbus.cyc,
    xbus_ack_i => xbus.ack,
    xbus_err_i => '0'
  );

  -- bus feedback --
  xbus.rdata <= xmem_rdata or dump_rdata;
  xbus.ack   <= xmem_ack   or dump_ack or trig_ack;


  -- External Main Memory [rwx] - Constructed from four parallel byte-wide memories ---------
  -- -------------------------------------------------------------------------------------------
  ext_mem_rw: process(clk_gen)
    variable mem8_bv_b0_v : mem8_bv_t(0 to (mem_size_c/4)-1) := mem8_bv_init_f(MEM_FILE, mem_size_c/4, 0);
    variable mem8_bv_b1_v : mem8_bv_t(0 to (mem_size_c/4)-1) := mem8_bv_init_f(MEM_FILE, mem_size_c/4, 1);
    variable mem8_bv_b2_v : mem8_bv_t(0 to (mem_size_c/4)-1) := mem8_bv_init_f(MEM_FILE, mem_size_c/4, 2);
    variable mem8_bv_b3_v : mem8_bv_t(0 to (mem_size_c/4)-1) := mem8_bv_init_f(MEM_FILE, mem_size_c/4, 3);
  begin
    if rising_edge(clk_gen) then
      -- defaults --
      xmem_rdata <= (others => '0');
      xmem_ack   <= '0';
      -- bus access --
      if (xbus.cyc = '1') and (xbus.stb = '1') and (xbus.addr(31 downto 28) = "0000") then
        xmem_ack <= '1';
        if (xbus.we = '1') then
          if (xbus.sel(0) = '1') then mem8_bv_b0_v(mem_addr) := to_bitvector(xbus.wdata(07 downto 00)); end if;
          if (xbus.sel(1) = '1') then mem8_bv_b1_v(mem_addr) := to_bitvector(xbus.wdata(15 downto 08)); end if;
          if (xbus.sel(2) = '1') then mem8_bv_b2_v(mem_addr) := to_bitvector(xbus.wdata(23 downto 16)); end if;
          if (xbus.sel(3) = '1') then mem8_bv_b3_v(mem_addr) := to_bitvector(xbus.wdata(31 downto 24)); end if;
        else
          xmem_rdata(07 downto 00) <= to_stdulogicvector(mem8_bv_b0_v(mem_addr));
          xmem_rdata(15 downto 08) <= to_stdulogicvector(mem8_bv_b1_v(mem_addr));
          xmem_rdata(23 downto 16) <= to_stdulogicvector(mem8_bv_b2_v(mem_addr));
          xmem_rdata(31 downto 24) <= to_stdulogicvector(mem8_bv_b3_v(mem_addr));
        end if;
      end if;
    end if;
  end process ext_mem_rw;

  -- read/write address --
  mem_addr <= to_integer(unsigned(xbus.addr(index_size_f(mem_size_c/4)+1 downto 2)));


  -- Terminate Simulation -------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  sim_terminate: process(rst_gen, clk_gen)
  begin
    if (rst_gen = '0') then
      trig_ack <= '0';
    elsif rising_edge(clk_gen) then
      trig_ack <= '0';
      if (xbus.cyc = '1') and (xbus.stb = '1') and (xbus.we = '1') and
         (xbus.addr = x"F0000000") and (xbus.wdata = x"CAFECAFE") then
        trig_ack <= '1';
        assert false report "Finishing simulation." severity note;
        finish;
      end if;
    end if;
  end process sim_terminate;


  -- Signature Dump -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  signature_dump: process(clk_gen)
    file     dump_file : text open write_mode is "DUT-neorv32.signature";
    variable line_v    : line;
  begin
    if rising_edge(clk_gen) then
      -- defaults --
      dump_rdata <= (others => '0');
      dump_ack   <= '0';
      -- bus access --
      if (xbus.cyc = '1') and (xbus.stb = '1') and (xbus.we = '1') and (xbus.addr = x"F0000004") then
        dump_ack <= '1';
        for i in 7 downto 0 loop -- write 32-bit as 8x lowercase HEX chars
          write(line_v, to_hexchar_f(xbus.wdata(3+i*4 downto 0+i*4)));
        end loop;
        writeline(dump_file, line_v);
      end if;
    end if;
  end process signature_dump;


end neorv32_riscof_tb_rtl;

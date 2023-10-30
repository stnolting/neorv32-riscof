-- #################################################################################################
-- # << neorv32-riscof - Testbench for running RISCOF >>                                           #
-- # ********************************************************************************************* #
-- # Minimal NEORV32 CPU testbench for running the RISCOF-based architecture test framework.       #
-- # The simulation mode of UART0 is used to dump processing data (test signatures) to a file.     #
-- #                                                                                               #
-- # An external memory (2MB, RAM) is initialized by a plain ASCII HEX file that contains the      #
-- # executable and all relevant data. The IMEM is split into four memory modules of 512kB each    #
-- # using variables of type bit_vector to minimize simulation memory footprint. These hacks are   #
-- # required since GHDL has problems with handling very large objects:                            #
-- # https://github.com/ghdl/ghdl/issues/1592                                                      #
-- #                                                                                               #
-- # Test signature data is dumped to a file "DUT-neorv32.signature" by writing to address         #
-- # 0xF0000004. Additional simulation triggers are implemented as memory-mapped registers:        #
-- # - trigger end of simulation using VHDL08's "finish" statement                                 #
-- # - trigger machine software interrupt (MSI)                                                    #
-- # - trigger machine external interrupt (MEI)                                                    #
-- #                                                                                               #
-- # This testbench uses VHDL2008!                                                                 #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2023, Stephan Nolting. All rights reserved.                                     #
-- #                                                                                               #
-- # Redistribution and use in source and binary forms, with or without modification, are          #
-- # permitted provided that the following conditions are met:                                     #
-- #                                                                                               #
-- # 1. Redistributions of source code must retain the above copyright notice, this list of        #
-- #    conditions and the following disclaimer.                                                   #
-- #                                                                                               #
-- # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
-- #    conditions and the following disclaimer in the documentation and/or other materials        #
-- #    provided with the distribution.                                                            #
-- #                                                                                               #
-- # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
-- #    endorse or promote products derived from this software without specific prior written      #
-- #    permission.                                                                                #
-- #                                                                                               #
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
-- # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
-- # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
-- # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
-- # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
-- # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
-- # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
-- # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
-- # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
-- # ********************************************************************************************* #
-- # https://github.com/stnolting/neorv32-riscof                               (c) Stephan Nolting #
-- #################################################################################################

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
    MEM_FILE : string;            -- memory initialization file
    MEM_SIZE : natural := 8*1024; -- total memory size in bytes
    RISCV_B  : boolean := false;  -- bit-manipulation ISA extension
    RISCV_C  : boolean := false;  -- compressed ISA extension
    RISCV_E  : boolean := false;  -- embedded ISA extension
    RISCV_M  : boolean := false   -- hardware mul/div ISA extension
  );
end neorv32_riscof_tb;

architecture neorv32_riscof_tb_rtl of neorv32_riscof_tb is

  -- maximum memory size in bytes --
  -- [NOTE] sizes >= 4MB are crashing GHDL in this setup; maximum still-OK-size = 3MB
  constant mem_size_max_c : natural := 2*1024*1024; -- just use 2MB as maximum to be safe ;)

  -- make sure actual memory size is a power of two (or <mem_size_max_c> for the rare case or very large images) --
  constant mem_size_c : natural := cond_sel_natural_f(boolean(MEM_SIZE >= mem_size_max_c), mem_size_max_c, 2**index_size_f(MEM_SIZE));

  -- memory type --
  type mem8_bv_t is array (natural range <>) of bit_vector(7 downto 0); -- bit_vector type for optimized system storage

  -- initialize mem8_bv_t array from ASCII HEX file  --
  impure function mem8_bv_init_f(file_name : string; num_bytes : natural; byte_sel : natural) return mem8_bv_t is
    file     text_file   : text open read_mode is file_name;
    variable text_line_v : line;
    variable mem8_bv_v   : mem8_bv_t(0 to num_bytes-1);
    variable index_v     : natural;
    variable word_v      : bit_vector(31 downto 0);
  begin
    mem8_bv_v := (others => (others => '0')); -- initialize to all-zero
    index_v   := 0;
    while (endfile(text_file) = false) and (index_v < num_bytes) loop
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

  -- memory read/write address --
  signal addr : integer range 0 to (mem_size_c/4)-1;

  -- generators/triggers --
  signal clk_gen, rst_gen : std_ulogic := '0';
  signal msi, mei, mti    : std_ulogic;

  -- wishbone bus --
  type wishbone_t is record
    addr  : std_ulogic_vector(31 downto 0);
    wdata : std_ulogic_vector(31 downto 0);
    rdata : std_ulogic_vector(31 downto 0);
    we    : std_ulogic;
    sel   : std_ulogic_vector(03 downto 0);
    stb   : std_ulogic;
    cyc   : std_ulogic;
    ack   : std_ulogic;
  end record;
  signal wb_cpu : wishbone_t;

begin

  -- Debug Info -----------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  assert false report "TB: actual memory size = " & integer'image(mem_size_c) & " bytes" severity warning;


  -- Clock/Reset Generator ------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  clk_gen <= not clk_gen after 5 ns;
  rst_gen <= '0', '1' after 100 ns;


  -- The Core of the Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst: neorv32_top
  generic map (
    -- General --
    CLOCK_FREQUENCY            => 100000000,
    INT_BOOTLOADER_EN          => false,
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_B      => RISCV_B,
    CPU_EXTENSION_RISCV_C      => RISCV_C,
    CPU_EXTENSION_RISCV_E      => RISCV_E,
    CPU_EXTENSION_RISCV_M      => RISCV_M,
    CPU_EXTENSION_RISCV_U      => true,
    CPU_EXTENSION_RISCV_Zicntr => true,
    -- Extension Options --
    FAST_MUL_EN                => true,
    FAST_SHIFT_EN              => true,
    -- Internal Instruction memory --
    MEM_INT_IMEM_EN            => false,
    -- Internal Data memory --
    MEM_INT_DMEM_EN            => false,
    -- Internal Instruction Cache (iCACHE) --
    ICACHE_EN                  => true,
    ICACHE_NUM_BLOCKS          => 4,
    ICACHE_BLOCK_SIZE          => 64,
    ICACHE_ASSOCIATIVITY       => 2,
    -- Internal Data Cache (dCACHE) --
    DCACHE_EN                  => true,
    DCACHE_NUM_BLOCKS          => 4,
    DCACHE_BLOCK_SIZE          => 64,
    -- External memory interface --
    MEM_EXT_EN                 => true,
    MEM_EXT_TIMEOUT            => 8,
    MEM_EXT_PIPE_MODE          => true,
    MEM_EXT_BIG_ENDIAN         => false,
    MEM_EXT_ASYNC_RX           => true,
    MEM_EXT_ASYNC_TX           => true
  )
  port map (
    -- Global control --
    clk_i       => clk_gen,
    rstn_i      => rst_gen,
    -- Wishbone bus interface (available if MEM_EXT_EN = true) --
    wb_tag_o    => open,
    wb_adr_o    => wb_cpu.addr,
    wb_dat_i    => wb_cpu.rdata,
    wb_dat_o    => wb_cpu.wdata,
    wb_we_o     => wb_cpu.we,
    wb_sel_o    => wb_cpu.sel,
    wb_stb_o    => wb_cpu.stb,
    wb_cyc_o    => wb_cpu.cyc,
    wb_ack_i    => wb_cpu.ack,
    wb_err_i    => '0',
    -- CPU Interrupts --
    mtime_irq_i => mti,
    msw_irq_i   => msi,
    mext_irq_i  => mei
  );


  -- External Main Memory [rwx] - Constructed from four parallel byte-wide memories ---------
  -- -------------------------------------------------------------------------------------------
  ext_mem_rw: process(clk_gen)
    variable mem8_bv_b0_v : mem8_bv_t(0 to (mem_size_c/4)-1) := mem8_bv_init_f(MEM_FILE, mem_size_c/4, 0); -- byte[0]
    variable mem8_bv_b1_v : mem8_bv_t(0 to (mem_size_c/4)-1) := mem8_bv_init_f(MEM_FILE, mem_size_c/4, 1); -- byte[1]
    variable mem8_bv_b2_v : mem8_bv_t(0 to (mem_size_c/4)-1) := mem8_bv_init_f(MEM_FILE, mem_size_c/4, 2); -- byte[2]
    variable mem8_bv_b3_v : mem8_bv_t(0 to (mem_size_c/4)-1) := mem8_bv_init_f(MEM_FILE, mem_size_c/4, 3); -- byte[3]
  begin
    if rising_edge(clk_gen) then
      wb_cpu.ack   <= wb_cpu.cyc and wb_cpu.stb;
      wb_cpu.rdata <= (others => '0');
      if (wb_cpu.cyc = '1') and (wb_cpu.stb = '1') then
        if (wb_cpu.we = '1') then -- byte-wide write access
          if (wb_cpu.sel(0) = '1') then mem8_bv_b0_v(addr) := to_bitvector(wb_cpu.wdata(07 downto 00)); end if;
          if (wb_cpu.sel(1) = '1') then mem8_bv_b1_v(addr) := to_bitvector(wb_cpu.wdata(15 downto 08)); end if;
          if (wb_cpu.sel(2) = '1') then mem8_bv_b2_v(addr) := to_bitvector(wb_cpu.wdata(23 downto 16)); end if;
          if (wb_cpu.sel(3) = '1') then mem8_bv_b3_v(addr) := to_bitvector(wb_cpu.wdata(31 downto 24)); end if;
        else -- word-aligned read access
          wb_cpu.rdata(07 downto 00) <= to_stdulogicvector(mem8_bv_b0_v(addr));
          wb_cpu.rdata(15 downto 08) <= to_stdulogicvector(mem8_bv_b1_v(addr));
          wb_cpu.rdata(23 downto 16) <= to_stdulogicvector(mem8_bv_b2_v(addr));
          wb_cpu.rdata(31 downto 24) <= to_stdulogicvector(mem8_bv_b3_v(addr));
        end if;
      end if;
    end if;
  end process ext_mem_rw;

  -- read/write address --
  addr <= to_integer(unsigned(wb_cpu.addr(index_size_f(mem_size_c/4)+1 downto 2)));


  -- Simulation Triggers --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  sim_triggers: process(rst_gen, clk_gen)
  begin
    if (rst_gen = '0') then
      msi <= '0';
      mei <= '0';
      mti <= '0';
    elsif rising_edge(clk_gen) then
      if (wb_cpu.cyc = '1') and (wb_cpu.stb = '1') and (wb_cpu.we = '1') and (wb_cpu.addr = x"F0000000") then
        case wb_cpu.wdata is
          when x"CAFECAFE" => -- end simulation
            assert false report "Finishing simulation." severity note;
            finish;
          when x"11111111" => -- set machine software interrupt (MSI)
            assert false report "Set MSI." severity note;
            msi <= '1';
          when x"22222222" => -- clear machine software interrupt (MSI)
            assert false report "Clear MSI." severity note;
            msi <= '0';
          when x"33333333" => -- set machine external interrupt (MEI)
            assert false report "Set MEI." severity note;
            mei <= '1';
          when x"44444444" => -- clear machine external interrupt (MEI)
            assert false report "Clear MEI." severity note;
            mei <= '0';
          when x"55555555" => -- set machine timer interrupt (MTI)
            assert false report "Set MTI." severity note;
            mti <= '1';
          when x"66666666" => -- clear machine timer interrupt (MTI)
            assert false report "Clear MTI." severity note;
            mti <= '0';
          when others =>
            NULL;
        end case;
      end if;
    end if;
  end process sim_triggers;


  -- Signature Dump -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  signature_dump: process(clk_gen)
    file     dump_file : text open write_mode is "DUT-neorv32.signature";
    variable line_v    : line;
  begin
    if rising_edge(clk_gen) then
      if (wb_cpu.cyc = '1') and (wb_cpu.stb = '1') and (wb_cpu.we = '1') and (wb_cpu.addr = x"F0000004") then
        for i in 7 downto 0 loop -- write 32-bit as 8x lowercase HEX chars
          write(line_v, to_hexchar_f(wb_cpu.wdata(3+i*4 downto 0+i*4)));
        end loop;
        writeline(dump_file, line_v);
      end if;
    end if;
  end process signature_dump;


end neorv32_riscof_tb_rtl;

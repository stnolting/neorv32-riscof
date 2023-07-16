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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;
use std.textio.all;
use std.env.finish;

entity neorv32_riscof_tb is
  generic (
    MEM_FILE : string;           -- memory initialization file
    RISCV_B  : boolean := false; -- bit-manipulation ISA extension
    RISCV_C  : boolean := false; -- compressed ISA extension
    RISCV_E  : boolean := false; -- embedded ISA extension
    RISCV_M  : boolean := false  -- hardware mul/div ISA extension
  );
end neorv32_riscof_tb;

architecture neorv32_riscof_tb_rtl of neorv32_riscof_tb is

  -- external memory type --
  type mem_t is array (natural range <>) of bit_vector(31 downto 0); -- memory with 32-bit entries

  -- initialize mem_t array from ASCII HEX file (starting at file offset 'start') --
  impure function init_mem_hex(file_name : string; start : natural; num_words : natural) return mem_t is
    file     text_file   : text open read_mode is file_name;
    variable text_line_v : line;
    variable mem_v       : mem_t(0 to num_words-1);
    variable i_abs_v     : natural;
    variable i_rel_v     : natural;
    variable char_v      : character;
    variable data_v      : std_ulogic_vector(31 downto 0);
  begin
    mem_v := (others => (others => '0')); -- initialize to all-zero
    i_abs_v := 0; -- offset inside <num_words>-sized block
    i_rel_v := 0; -- offset inside whole HEX initialization file
    while (endfile(text_file) = false) and (i_abs_v < ((start/4) + num_words)) loop
      readline(text_file, text_line_v);
      if (i_abs_v >= (start/4)) then -- begin initialization at defined start offset
        -- construct one 32-bit word --
        data_v := (others => '0');
        for i in 7 downto 0 loop -- 32-bit = 8 hex chars
          read(text_line_v, char_v); -- get one hex char
          data_v(i*4+3 downto i*4) := hexchar_to_stdulogicvector_f(char_v);
        end loop; -- i
        -- store according byte to memory image --
        mem_v(i_rel_v) := to_bitvector(data_v);
        i_rel_v := i_rel_v + 1; -- local pointer (for the current MEM module)
      end if;
      i_abs_v := i_abs_v + 1; -- global pointer (for the HEX source file)
    end loop; -- not end of file
    return mem_v;
  end function init_mem_hex;

  -- external memory (initialized from file); size of one module in bytes (experimental!) --
  constant mem_size_c : natural := 512*1024;

  -- generators/triggers --
  signal clk_gen, rst_gen : std_ulogic := '0';
  signal msi, mei, mti    : std_ulogic;

  -- Wishbone bus --
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

  -- Clock/Reset Generator ------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  clk_gen <= not clk_gen after 5 ns;
  rst_gen <= '0', '1' after 100 ns;


  -- The Core of the Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst: neorv32_top
  generic map (
    -- General --
    CLOCK_FREQUENCY              => 100000000,
    INT_BOOTLOADER_EN            => false,
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_B        => RISCV_B,
    CPU_EXTENSION_RISCV_C        => RISCV_C,
    CPU_EXTENSION_RISCV_E        => RISCV_E,
    CPU_EXTENSION_RISCV_M        => RISCV_M,
    CPU_EXTENSION_RISCV_U        => true,
    CPU_EXTENSION_RISCV_Zicntr   => true,
    CPU_EXTENSION_RISCV_Zifencei => true,
    -- Extension Options --
    FAST_MUL_EN                  => true,
    FAST_SHIFT_EN                => true,
    -- Internal Instruction memory --
    MEM_INT_IMEM_EN              => false,
    -- Internal Data memory --
    MEM_INT_DMEM_EN              => false,
    -- Internal Instruction Cache (iCACHE) --
    ICACHE_EN                    => true,
    ICACHE_NUM_BLOCKS            => 4,
    ICACHE_BLOCK_SIZE            => 64,
    ICACHE_ASSOCIATIVITY         => 2,
    -- Internal Data Cache (dCACHE) --
    DCACHE_EN                    => true,
    DCACHE_NUM_BLOCKS            => 4,
    DCACHE_BLOCK_SIZE            => 64,
    -- External memory interface --
    MEM_EXT_EN                   => true,
    MEM_EXT_TIMEOUT              => 8,
    MEM_EXT_PIPE_MODE            => true,
    MEM_EXT_BIG_ENDIAN           => false,
    MEM_EXT_ASYNC_RX             => true,
    MEM_EXT_ASYNC_TX             => true
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


  -- External Memory ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ext_mem_rw: process(clk_gen)
    -- initialize memory from HEX file - split into four individual byte-wide memory modules --
    variable mem0_v : mem_t(0 to mem_size_c/4-1) := init_mem_hex(MEM_FILE, 0*mem_size_c, mem_size_c/4);
    variable mem1_v : mem_t(0 to mem_size_c/4-1) := init_mem_hex(MEM_FILE, 1*mem_size_c, mem_size_c/4);
    variable mem2_v : mem_t(0 to mem_size_c/4-1) := init_mem_hex(MEM_FILE, 2*mem_size_c, mem_size_c/4);
    variable mem3_v : mem_t(0 to mem_size_c/4-1) := init_mem_hex(MEM_FILE, 3*mem_size_c, mem_size_c/4);
  begin
    if rising_edge(clk_gen) then
      wb_cpu.ack <= wb_cpu.cyc and wb_cpu.stb;
      if (wb_cpu.cyc = '1') and (wb_cpu.stb = '1') then
        if (wb_cpu.we = '1') then -- write access
          for i in 0 to 3 loop
            if (wb_cpu.sel(i) = '1') then -- byte-wide access
              case wb_cpu.addr(index_size_f(mem_size_c/4)+3 downto index_size_f(mem_size_c/4)+2) is
                when "00" => mem0_v(to_integer(unsigned(wb_cpu.addr(index_size_f(mem_size_c/4)+1 downto 2))))(7+i*8 downto 0+i*8) := to_bitvector(wb_cpu.wdata(7+i*8 downto 0+i*8));
                when "01" => mem1_v(to_integer(unsigned(wb_cpu.addr(index_size_f(mem_size_c/4)+1 downto 2))))(7+i*8 downto 0+i*8) := to_bitvector(wb_cpu.wdata(7+i*8 downto 0+i*8));
                when "10" => mem2_v(to_integer(unsigned(wb_cpu.addr(index_size_f(mem_size_c/4)+1 downto 2))))(7+i*8 downto 0+i*8) := to_bitvector(wb_cpu.wdata(7+i*8 downto 0+i*8));
                when "11" => mem3_v(to_integer(unsigned(wb_cpu.addr(index_size_f(mem_size_c/4)+1 downto 2))))(7+i*8 downto 0+i*8) := to_bitvector(wb_cpu.wdata(7+i*8 downto 0+i*8));
                when others => NULL;
              end case;
            end if;
          end loop; -- i
        else -- read access
          case wb_cpu.addr(index_size_f(mem_size_c/4)+3 downto index_size_f(mem_size_c/4)+2) is
            when "00" => wb_cpu.rdata <= to_stdulogicvector(mem0_v(to_integer(unsigned(wb_cpu.addr(index_size_f(mem_size_c/4)+1 downto 2))))); -- word aligned
            when "01" => wb_cpu.rdata <= to_stdulogicvector(mem1_v(to_integer(unsigned(wb_cpu.addr(index_size_f(mem_size_c/4)+1 downto 2))))); -- word aligned
            when "10" => wb_cpu.rdata <= to_stdulogicvector(mem2_v(to_integer(unsigned(wb_cpu.addr(index_size_f(mem_size_c/4)+1 downto 2))))); -- word aligned
            when "11" => wb_cpu.rdata <= to_stdulogicvector(mem3_v(to_integer(unsigned(wb_cpu.addr(index_size_f(mem_size_c/4)+1 downto 2))))); -- word aligned
            when others => NULL;
          end case;
        end if;
      end if;
    end if;
  end process ext_mem_rw;


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
            finish; -- VHDL08+ only!
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
    file data_file : text open write_mode is "DUT-neorv32.signature";
    variable line_data_v : line;
  begin
    if rising_edge(clk_gen) then
      if (wb_cpu.cyc = '1') and (wb_cpu.stb = '1') and (wb_cpu.we = '1') and (wb_cpu.addr = x"F0000004") then
        for x in 7 downto 0 loop -- write as 8x HEX chars
          write(line_data_v, to_hexchar_f(wb_cpu.wdata(3+x*4 downto 0+x*4)));
        end loop;
        writeline(data_file, line_data_v);
      end if;
    end if;
  end process signature_dump;


end neorv32_riscof_tb_rtl;

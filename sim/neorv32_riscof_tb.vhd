-- #################################################################################################
-- # << NEORV32 - RISCOF Testbench for risc-arch-test Verification >>                              #
-- # ********************************************************************************************* #
-- # Minimal NEORV32 CPU testbench for running the RISCOF-base architecture test framework.        #
-- # The simulation mode of UART0 is used to dump processing data to a file.                       #
-- #                                                                                               #
-- # An external IMEM (RAM!) is initialized by a plain ASCII HEX file. The IMEM is split into four #
-- # memory modules of 512kB each using variables of type bit_vector to minimize memory footprint. #
-- # These hacks are requires since GHDL has problems with handling large objects.                 #
-- # -> https://github.com/ghdl/ghdl/issues/1592                                                   #
-- # The maximum executable size currently comes from the JAL test (~1.7MB).                       #
-- #                                                                                               #
-- # Furthermore, the testbench features simulation triggers:                                      #
-- # - machine software interrupt (MSI)                                                            #
-- # - machine external interrupt (MEI)                                                            #
-- # - most important: trigger end of simulation using VHDL08's "finish" statement                 #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2022, Stephan Nolting. All rights reserved.                                     #
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
-- # The NEORV32 Processor - https://github.com/stnolting/neorv32              (c) Stephan Nolting #
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
    IMEM_FILE : string;           -- memory initialization file (*.hex)
    RISCV_B   : boolean := false; -- bit-manipulation ISA extension
    RISCV_C   : boolean := false; -- compressed ISA extension
    RISCV_E   : boolean := false; -- embedded ISA extension
    RISCV_M   : boolean := false; -- hardware mul/div ISA extension
    RISCV_U   : boolean := false  -- user-mode ISA extension
  );
end neorv32_riscof_tb;

architecture neorv32_riscof_tb_rtl of neorv32_riscof_tb is

  -- IMEM memory type --
  type imem_t is array (natural range <>) of bit_vector(31 downto 0); -- memory with 32-bit entries

  -- Initialize imem_t array from ASCII HEX file (starting at file offset 'start') --
  impure function init_imem_hex(file_name : string; start : natural; num_words : natural) return imem_t is
    file     text_file   : text open read_mode is file_name;
    variable text_line_v : line;
    variable mem_v       : imem_t(0 to num_words-1);
    variable i_abs_v     : natural;
    variable i_rel_v     : natural;
    variable char_v      : character;
    variable data_v      : std_ulogic_vector(31 downto 0);
  begin
    mem_v := (others => (others => '0'));
    i_abs_v := 0;
    i_rel_v := 0;
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
        i_rel_v := i_rel_v + 1; -- local pointer (for the current IMEM module)
      end if;
      i_abs_v := i_abs_v + 1; -- global pointer (for the HEX source file)
    end loop; -- not end of file
    return mem_v;
  end function init_imem_hex;

  -- external IMEM (initialized from file); size of one module --
  constant imem_size_c : natural := 512*1024; -- size in bytes (experimental maximum for GHDL)

  -- generators --
  signal clk_gen, rst_gen : std_ulogic := '0';

  -- Wishbone bus --
  type wishbone_t is record
    addr  : std_ulogic_vector(31 downto 0); -- address
    wdata : std_ulogic_vector(31 downto 0); -- master write data
    rdata : std_ulogic_vector(31 downto 0); -- master read data
    we    : std_ulogic; -- write enable
    sel   : std_ulogic_vector(03 downto 0); -- byte enable
    stb   : std_ulogic; -- strobe
    cyc   : std_ulogic; -- valid cycle
    ack   : std_ulogic; -- transfer acknowledge
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
    CLOCK_FREQUENCY              => 100000000, -- clock frequency of clk_i in Hz
    HW_THREAD_ID                 => 0,         -- hardware thread id (hartid) (32-bit)
    INT_BOOTLOADER_EN            => false,     -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_B        => RISCV_B,   -- implement bit-manipulation extension?
    CPU_EXTENSION_RISCV_C        => RISCV_C,   -- implement compressed extension?
    CPU_EXTENSION_RISCV_E        => RISCV_E,   -- implement embedded RF extension?
    CPU_EXTENSION_RISCV_M        => RISCV_M,   -- implement mul/div extension?
    CPU_EXTENSION_RISCV_U        => RISCV_U,   -- implement user mode extension?
    CPU_EXTENSION_RISCV_Zicsr    => true,      -- implement CSR system?
    CPU_EXTENSION_RISCV_Zicntr   => true,      -- implement base counters?
    CPU_EXTENSION_RISCV_Zihpm    => true,      -- implement hardware performance monitors?
    CPU_EXTENSION_RISCV_Zifencei => true,      -- implement instruction stream sync.?
    -- Extension Options --
    FAST_MUL_EN                  => true,      -- use DSPs for M extension's multiplier
    FAST_SHIFT_EN                => false,      -- use barrel shifter for shift operations
    -- Physical Memory Protection (PMP) --
    PMP_NUM_REGIONS              => 0,         -- number of regions (0..16)
    PMP_MIN_GRANULARITY          => 4,         -- minimal region granularity in bytes, has to be a power of 2, min 4 bytes
    -- Hardware Performance Monitors (HPM) --
    HPM_NUM_CNTS                 => 12,        -- number of implemented HPM counters (0..29)
    HPM_CNT_WIDTH                => 40,        -- total size of HPM counters (0..64)
    -- Internal Instruction memory --
    MEM_INT_IMEM_EN              => false,     -- implement processor-internal instruction memory
    -- Internal Data memory --
    MEM_INT_DMEM_EN              => false,     -- implement processor-internal data memory
    -- External memory interface --
    MEM_EXT_EN                   => true,      -- implement external memory bus interface?
    MEM_EXT_TIMEOUT              => 32,        -- cycles after a pending bus access auto-terminates (0 = disabled)
    MEM_EXT_PIPE_MODE            => true,      -- protocol: false=classic/standard wishbone mode, true=pipelined wishbone mode
    MEM_EXT_BIG_ENDIAN           => false,     -- byte order: true=big-endian, false=little-endian
    MEM_EXT_ASYNC_RX             => true,      -- use register buffer for RX data when false
    MEM_EXT_ASYNC_TX             => true,      -- use register buffer for TX data when false
    -- Processor peripherals --
    IO_MTIME_EN                  => true,      -- implement machine system timer (MTIME)?
    IO_UART0_EN                  => true       -- implement primary universal asynchronous receiver/transmitter (UART0)?
  )
  port map (
    -- Global control --
    clk_i    => clk_gen,                       -- global clock, rising edge
    rstn_i   => rst_gen,                       -- global reset, low-active, async
    -- Wishbone bus interface (available if MEM_EXT_EN = true) --
    wb_tag_o => open,                          -- request tag
    wb_adr_o => wb_cpu.addr,                   -- address
    wb_dat_i => wb_cpu.rdata,                  -- read data
    wb_dat_o => wb_cpu.wdata,                  -- write data
    wb_we_o  => wb_cpu.we,                     -- read/write
    wb_sel_o => wb_cpu.sel,                    -- byte enable
    wb_stb_o => wb_cpu.stb,                    -- strobe
    wb_cyc_o => wb_cpu.cyc,                    -- valid cycle
    wb_ack_i => wb_cpu.ack,                    -- transfer acknowledge
    wb_err_i => '0'                            -- transfer error
  );


  -- External IMEM --------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ext_imem_rw: process(clk_gen)
    -- initialize memory modules from HEX file --
    variable imem0_v : imem_t(0 to imem_size_c/4-1) := init_imem_hex(IMEM_FILE, 0*imem_size_c, imem_size_c/4);
    variable imem1_v : imem_t(0 to imem_size_c/4-1) := init_imem_hex(IMEM_FILE, 1*imem_size_c, imem_size_c/4);
    variable imem2_v : imem_t(0 to imem_size_c/4-1) := init_imem_hex(IMEM_FILE, 2*imem_size_c, imem_size_c/4);
    variable imem3_v : imem_t(0 to imem_size_c/4-1) := init_imem_hex(IMEM_FILE, 3*imem_size_c, imem_size_c/4);
  begin
    if rising_edge(clk_gen) then
      -- handshake --
      wb_cpu.ack <= wb_cpu.cyc and wb_cpu.stb;

      -- write access --
      if ((wb_cpu.cyc and wb_cpu.stb and wb_cpu.we) = '1') then
--assert false report "[0x" & to_hstring32_f(wb_cpu.addr) & "] <= 0x" & to_hstring32_f(wb_cpu.wdata) severity note;
        for i in 0 to 3 loop
          if (wb_cpu.sel(i) = '1') then -- byte-wide access
            case wb_cpu.addr(index_size_f(imem_size_c/4)+3 downto index_size_f(imem_size_c/4)+2) is -- split logical IMEM into 4 *physical* memories
              when "00" => imem0_v(to_integer(unsigned(wb_cpu.addr(index_size_f(imem_size_c/4)+1 downto 2))))(7+i*8 downto 0+i*8) := to_bitvector(wb_cpu.wdata(7+i*8 downto 0+i*8));
              when "01" => imem1_v(to_integer(unsigned(wb_cpu.addr(index_size_f(imem_size_c/4)+1 downto 2))))(7+i*8 downto 0+i*8) := to_bitvector(wb_cpu.wdata(7+i*8 downto 0+i*8));
              when "10" => imem2_v(to_integer(unsigned(wb_cpu.addr(index_size_f(imem_size_c/4)+1 downto 2))))(7+i*8 downto 0+i*8) := to_bitvector(wb_cpu.wdata(7+i*8 downto 0+i*8));
              when "11" => imem3_v(to_integer(unsigned(wb_cpu.addr(index_size_f(imem_size_c/4)+1 downto 2))))(7+i*8 downto 0+i*8) := to_bitvector(wb_cpu.wdata(7+i*8 downto 0+i*8));
              when others => NULL;
            end case;
          end if;
        end loop; -- i
      end if;

      -- read access --
      if ((wb_cpu.cyc and wb_cpu.stb and (not wb_cpu.we)) = '1') then
--assert false report "[0x" & to_hstring32_f(wb_cpu.addr) & "] = 0x" & to_hstring32_f(to_stdulogicvector(imem_v(to_integer(unsigned(wb_cpu.addr(index_size_f(imem_size_c/4)+1 downto 2)))))) severity note;
        case wb_cpu.addr(index_size_f(imem_size_c/4)+3 downto index_size_f(imem_size_c/4)+2) is -- split logical IMEM into 4 *physical* memories
          when "00" => wb_cpu.rdata <= to_stdulogicvector(imem0_v(to_integer(unsigned(wb_cpu.addr(index_size_f(imem_size_c/4)+1 downto 2))))); -- word aligned
          when "01" => wb_cpu.rdata <= to_stdulogicvector(imem1_v(to_integer(unsigned(wb_cpu.addr(index_size_f(imem_size_c/4)+1 downto 2))))); -- word aligned
          when "10" => wb_cpu.rdata <= to_stdulogicvector(imem2_v(to_integer(unsigned(wb_cpu.addr(index_size_f(imem_size_c/4)+1 downto 2))))); -- word aligned
          when "11" => wb_cpu.rdata <= to_stdulogicvector(imem3_v(to_integer(unsigned(wb_cpu.addr(index_size_f(imem_size_c/4)+1 downto 2))))); -- word aligned
          when others => NULL;
        end case;
      end if;
    end if;
  end process ext_imem_rw;


  -- Simulation Triggers --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  sim_triggers: process(clk_gen)
  begin
    if rising_edge(clk_gen) then
      if (wb_cpu.cyc = '1') and (wb_cpu.stb = '1') and (wb_cpu.we = '1') and (wb_cpu.addr = x"F0000000") then
        -- end simulation --
        if (wb_cpu.wdata = x"CAFECAFE") then
          assert false report "Finishing Simulation." severity warning;
          finish; -- VHDL08+ only!
        -- machine software interrupt (MSI) --
        elsif (wb_cpu.wdata = x"55555555") then
          NULL; -- TODO
        -- machine external interrupt (MEI) --
        elsif (wb_cpu.wdata = x"EEEEEEEE") then
          NULL; -- TODO
        end if;
      end if;
    end if;
  end process sim_triggers;


end neorv32_riscof_tb_rtl;

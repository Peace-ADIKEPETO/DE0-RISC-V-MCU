-- cpu_ram_tb.vhd  
-- Simulate PicoRV32 + RAM in isolation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_ram_tb is
end entity;

architecture sim of cpu_ram_tb is

    component picorv32 is
        generic (
            ENABLE_COUNTERS      : integer := 0;
            CATCH_MISALIGN       : integer := 0;
            CATCH_ILLINSN        : integer := 0;
            ENABLE_IRQ           : integer := 0;
            BARREL_SHIFTER       : integer := 0;
            COMPRESSED_ISA       : integer := 0;
            STACKADDR            : std_logic_vector(31 downto 0) := x"00003FFC"
        );
        port (
            clk         : in  std_logic;
            resetn      : in  std_logic;
            trap        : out std_logic;
            mem_valid   : out std_logic;
            mem_instr   : out std_logic;
            mem_ready   : in  std_logic;
            mem_addr    : out std_logic_vector(31 downto 0);
            mem_wdata   : out std_logic_vector(31 downto 0);
            mem_wstrb   : out std_logic_vector(3 downto 0);
            mem_rdata   : in  std_logic_vector(31 downto 0)
        );
    end component;

    component ram_16kb is
        port (
            clk   : in  std_logic;
            addr  : in  std_logic_vector(11 downto 0);
            wdata : in  std_logic_vector(31 downto 0);
            wstrb : in  std_logic_vector(3 downto 0);
            rdata : out std_logic_vector(31 downto 0);
            we    : in  std_logic
        );
    end component;

    signal clk         : std_logic := '0';
    signal resetn      : std_logic := '0';
    signal trap        : std_logic;
    signal mem_valid   : std_logic;
    signal mem_instr   : std_logic;
    signal mem_ready   : std_logic;
    signal mem_addr    : std_logic_vector(31 downto 0);
    signal mem_wdata   : std_logic_vector(31 downto 0);
    signal mem_wstrb   : std_logic_vector(3 downto 0);
    signal mem_rdata   : std_logic_vector(31 downto 0);
    signal ram_addr    : std_logic_vector(11 downto 0);
    signal ram_we      : std_logic;
    signal ram_rdata   : std_logic_vector(31 downto 0);
    signal mem_ready_d : std_logic := '0';

    constant CLK_PERIOD : time := 20 ns;

begin

    cpu: picorv32
        generic map (
            ENABLE_COUNTERS    => 0,
            CATCH_MISALIGN     => 0,
            CATCH_ILLINSN      => 0,
            ENABLE_IRQ         => 0,
            BARREL_SHIFTER     => 0,
            COMPRESSED_ISA     => 0,
            STACKADDR          => x"00003FFC"
        )
        port map (
            clk       => clk,
            resetn    => resetn,
            trap      => trap,
            mem_valid => mem_valid,
            mem_instr => mem_instr,
            mem_ready => mem_ready,
            mem_addr  => mem_addr,
            mem_wdata => mem_wdata,
            mem_wstrb => mem_wstrb,
            mem_rdata => mem_rdata
        );

    ram_addr <= mem_addr(13 downto 2);
    ram_we   <= mem_valid and (mem_wstrb(0) or mem_wstrb(1) or mem_wstrb(2) or mem_wstrb(3));

    ram: ram_16kb
        port map (
            clk   => clk,
            addr  => ram_addr,
            wdata => mem_wdata,
            wstrb => mem_wstrb,
            rdata => ram_rdata,
            we    => ram_we
        );

    -- 1-cycle read latency: mem_ready fires one cycle after mem_valid
    process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                mem_ready_d <= '0';
            else
                mem_ready_d <= mem_valid;
            end if;
        end if;
    end process;
    mem_ready <= mem_ready_d;

    -- Bus mux: RAM read data to CPU
    mem_rdata <= ram_rdata;

    -- 50MHz clock
    p_clk : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus
    p_stim : process
    begin
        -- Power-on reset: 16 cycles
        resetn <= '0';
        wait for CLK_PERIOD * 20;
        resetn <= '1';
        report "CPU released from reset";
        
        -- Run for many cycles
        wait for CLK_PERIOD * 200;
        
        report "Simulation complete. Check waveform:";
        report "  trap = " & std_logic'image(trap);
        report "  mem_valid should pulse regularly";
        report "  mem_addr should cycle 0,4,8,12,16,20,0...";
        wait;
    end process;

end architecture sim;
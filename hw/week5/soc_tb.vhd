-- soc_tb.vhd
-- Full system testbench: CPU + RAM + GPIO

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity soc_tb is
end entity;

architecture sim of soc_tb is

    component soc_top is
        port (
            clk     : in  std_logic;
            reset_n : in  std_logic;
            led     : out std_logic_vector(7 downto 0);
            sw      : in  std_logic_vector(3 downto 0)
        );
    end component;

    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';
    signal led     : std_logic_vector(7 downto 0);
    signal sw      : std_logic_vector(3 downto 0) := (others => '0');

    constant CLK_PERIOD : time := 20 ns;  -- 50MHz

begin

    uut: soc_top
        port map (
            clk     => clk,
            reset_n => reset_n,
            led     => led,
            sw      => sw
        );

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
        -- Hold reset low for 100ns
        reset_n <= '0';
        wait for 100 ns;
        
        -- Release reset
        reset_n <= '1';
        report "Reset released. CPU should start executing.";
        
        -- Run for enough cycles to see several loop iterations
        -- The loop is 6 instructions. At ~1 CPI, ~6 cycles per loop.
        -- 1000 cycles = plenty
        wait for 20000 ns;  -- 1000 clock cycles
        
        report "Simulation finished. Check waveform for:";
        report "  - cpu_mem_valid toggling";
        report "  - cpu_mem_addr cycling 0,4,8,12,16,20...";
        report "  - gpio_out_reg toggling";
        report "  - cpu_trap = 0 (no trap)";
        
        wait;
    end process;

end architecture sim;
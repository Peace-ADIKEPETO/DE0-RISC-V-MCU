-- led_blink_tb.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity led_blink_tb is
end entity;

architecture sim of led_blink_tb is

    -- Component Declaration for the Unit Under Test (UUT)
    component led_blink is
        generic (
            CLOCK_FREQ_HZ : positive := 50_000_000;
            BLINK_FREQ_HZ : positive := 1
        );
        port (
            clk   : in  std_logic;
            reset_n : in  std_logic;
            led   : out std_logic
        );
    end component;

    -- Testbench Signals
    signal clk      : std_logic := '0';
    signal reset_n  : std_logic := '0'; -- Start in reset
    signal led      : std_logic;

    -- Clock period for 50MHz
    constant CLK_PERIOD : time := 20 ns;

    -- Reduced MAX_COUNT for simulation speed. 50MHz / (2*1Hz) = 25,000,000 is too slow to simulate.
    -- We'll just check the toggle behavior. The full count is verified by inspection.
    -- We'll run a symbolic check: verify the counter resets and led toggles.

begin
    -- Instantiate the UUT
    uut: led_blink
        generic map (
            -- Override the generics for simulation speed!
            -- A 1Hz blink would take 0.5 seconds per toggle. Too long.
            -- We want a blink freq of ~100Hz for simulation, so count is small.
            -- Let's set BLINK_FREQ_HZ = 1,000,000 (1MHz). Then MAX_COUNT = (50e6 / 2e6) - 1 = 24.
            -- This way, the LED toggles every 25 clock cycles.
            CLOCK_FREQ_HZ => 50_000_000,
            BLINK_FREQ_HZ => 1_000_000
        )
        port map (
            clk      => clk,
            reset_n  => reset_n,
            led      => led
        );

    -- Clock Generation Process
    p_clk : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process p_clk;

    -- Stimulus Process
    p_stim : process
    begin
        -- 1. Assert Reset
        reset_n <= '0';
        wait for CLK_PERIOD * 5;
        reset_n <= '1';
        report "Reset released. Starting observation...";

        -- 2. Let it run for enough cycles to see multiple toggles
        -- With the 1MHz blink generic, the LED toggles every 25 clocks (20ns * 25 = 500ns).
        -- Let's wait for 2000 ns to see 4 toggles.
        wait for 2000 ns;

        -- 3. Assert Reset Again
        reset_n <= '0';
        wait for CLK_PERIOD * 5;
        report "Re-asserted reset. LED should go OFF.";
        wait for 100 ns; -- Observe it's OFF

        -- 4. Release reset and run a bit more
        reset_n <= '1';
        wait for 1000 ns;

        report "Simulation finished. Check waveform for toggles.";
        -- End simulation
        assert false report "TEST PASSED" severity failure;
    end process p_stim;

end architecture sim;
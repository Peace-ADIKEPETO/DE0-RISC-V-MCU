-- gpio_top_tb.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gpio_top_tb is
end entity;

architecture sim of gpio_top_tb is

    component gpio_top is
        port (
            clk : in  std_logic;
            btn : in  std_logic_vector(1 downto 0);
            sw  : in  std_logic_vector(3 downto 0);
            led : out std_logic_vector(7 downto 0)
        );
    end component;

    signal clk  : std_logic := '0';
    signal btn  : std_logic_vector(1 downto 0) := "11";  -- Not pressed
    signal sw   : std_logic_vector(3 downto 0) := "1111"; -- All off
    signal led  : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 20 ns;

begin

    uut: gpio_top
        port map (
            clk => clk,
            btn => btn,
            sw  => sw,
            led => led
        );

    -- Clock generation
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
        -- Initial: all LEDs off
        wait for 100 ns;

        -- Test 1: DIP switches control LEDs
        sw <= "1010";  -- Expect LED[3:0] = "1010"
        wait for 100 ns;
        assert led(3 downto 0) = "1010"
            report "DIP switch test failed" severity error;

        -- Test 2: Button press (active low, with bounce simulation)
        -- Simulate bounce: 5 rapid toggles then stable press
        for i in 0 to 4 loop
            btn(0) <= '0';
            wait for CLK_PERIOD;
            btn(0) <= '1';
            wait for CLK_PERIOD;
        end loop;
        -- Now hold button stable for >20ms
        btn(0) <= '0';
        wait for 25 ms;

        -- After debounce, LED7 should toggle once
        wait for 100 ns;

        -- Release button
        btn(0) <= '1';
        wait for 100 ns;

        -- Test 3: Press again
        btn(0) <= '0';
        wait for 25 ms;
        btn(0) <= '1';
        wait for 100 ns;
        -- LED7 should toggle again (back to original state)

        report "Simulation complete" severity note;
        wait;
    end process;

end architecture sim;
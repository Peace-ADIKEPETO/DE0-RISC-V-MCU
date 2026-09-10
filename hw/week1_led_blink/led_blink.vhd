-- led_blink.vhd
-- Week 1: 1Hz LED Blink with Clock Enable
-- Target: Terasic DE0-Nano, Cyclone IV EP4CE22F17C6N

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- For ceil, log2

entity led_blink is
    generic (
        CLOCK_FREQ_HZ : positive := 50_000_000; -- 50 MHz onboard clock
        BLINK_FREQ_HZ : positive := 1           -- Desired 1 Hz blink rate
    );
    port (
        clk   : in  std_logic; -- 50MHz input clock, PIN_R8
        reset_n : in  std_logic; -- Active-low reset (optional, can tie to '1')
        led   : out std_logic  -- LED output, PIN_A15 (active low)
    );
end entity led_blink;

architecture rtl of led_blink is

    -- Calculate the number of bits needed for the counter.
    -- We need to count from 0 to (CLOCK_FREQ_HZ / (2 * BLINK_FREQ_HZ)) - 1.
    -- The factor of 2 is because we toggle the LED, meaning one full ON-OFF cycle
    -- requires two toggles (one period).
    constant MAX_COUNT : positive := (CLOCK_FREQ_HZ / (2 * BLINK_FREQ_HZ)) - 1;
    -- Example: 50,000,000 / (2 * 1) - 1 = 24,999,999.
    -- This requires 25 bits (log2(25,000,000) ≈ 24.6).

    -- Calculate number of bits for the counter
    constant COUNTER_BITS : positive := integer(ceil(log2(real(MAX_COUNT + 1))));
    -- For MAX_COUNT = 24,999,999, COUNTER_BITS = 25.

    signal counter     : unsigned(COUNTER_BITS - 1 downto 0) := (others => '0');
    signal led_state   : std_logic := '1'; -- Start with LED OFF ('1' is off for active-low)

begin

    -- Main synchronous process
    p_led_blink : process (clk, reset_n) is
    begin
        if reset_n = '0' then
            -- Asynchronous, active-low reset
            counter   <= (others => '0');
            led_state <= '1'; -- LED OFF ('1' = off)
        elsif rising_edge(clk) then
            -- Default: No change. This is a good habit.
            -- All changes happen inside this synchronous block.

            if counter = to_unsigned(MAX_COUNT, counter'length) then
                -- Time to toggle the LED
                counter   <= (others => '0');       -- Reset the counter
                led_state <= not led_state;        -- Toggle the LED state
            else
                -- Just keep counting
                counter <= counter + 1;
            end if;

        end if;
    end process p_led_blink;

    -- Output assignment
    led <= led_state;

end architecture rtl;
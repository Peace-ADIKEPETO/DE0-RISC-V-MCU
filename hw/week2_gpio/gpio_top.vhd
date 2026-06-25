-- gpio_top.vhd
-- Week 2: GPIO Module for DE0-Nano
-- 8 LEDs (out), 4 DIP Switches (in), 2 Buttons (in)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gpio_top is
    port (
        clk   : in  std_logic;          -- 50MHz clock, PIN_R8
        btn   : in  std_logic_vector(1 downto 0);  -- Active low buttons
        sw    : in  std_logic_vector(3 downto 0);  -- DIP switches
        led   : out std_logic_vector(7 downto 0)   -- Active low LEDs
    );
end entity gpio_top;

architecture rtl of gpio_top is

    -- Synchronizer chains for buttons (metastability protection)
    signal btn0_sync : std_logic_vector(2 downto 0) := (others => '1');
    signal btn1_sync : std_logic_vector(2 downto 0) := (others => '1');

    -- Debounce counter: 50MHz * 20ms = 1,000,000 cycles ≈ 2^20
    constant DEBOUNCE_MAX : unsigned(19 downto 0) := (others => '1');

    signal btn0_db_cnt : unsigned(19 downto 0) := (others => '0');
    signal btn1_db_cnt : unsigned(19 downto 0) := (others => '0');
    signal btn0_stable : std_logic := '1';  -- '1' = not pressed (active low)
    signal btn1_stable : std_logic := '1';

    -- LED state registers
    signal led_reg : std_logic_vector(7 downto 0) := (others => '0'); -- All off

begin

    -- =============================================
    -- BUTTON SYNCHRONIZER (3-stage, avoids metastability)
    -- =============================================
    p_btn_sync : process(clk)
    begin
        if rising_edge(clk) then
            btn0_sync <= btn0_sync(1 downto 0) & btn(0);
            btn1_sync <= btn1_sync(1 downto 0) & btn(1);
        end if;
    end process p_btn_sync;

    -- =============================================
    -- BUTTON DEBOUNCE (20ms saturation counter)
    -- =============================================
    p_btn0_debounce : process(clk)
    begin
        if rising_edge(clk) then
            if btn0_sync(2) /= btn0_stable then
                -- Input changed, start/resume counting
                if btn0_db_cnt = DEBOUNCE_MAX then
                    -- Button state confirmed stable for 20ms
                    btn0_stable <= btn0_sync(2);
                    btn0_db_cnt <= (others => '0');
                else
                    btn0_db_cnt <= btn0_db_cnt + 1;
                end if;
            else
                -- Input stable, reset counter
                btn0_db_cnt <= (others => '0');
            end if;
        end if;
    end process p_btn0_debounce;

    p_btn1_debounce : process(clk)
    begin
        if rising_edge(clk) then
            if btn1_sync(2) /= btn1_stable then
                if btn1_db_cnt = DEBOUNCE_MAX then
                    btn1_stable <= btn1_sync(2);
                    btn1_db_cnt <= (others => '0');
                else
                    btn1_db_cnt <= btn1_db_cnt + 1;
                end if;
            else
                btn1_db_cnt <= (others => '0');
            end if;
        end if;
    end process p_btn1_debounce;

    -- =============================================
    -- LED LOGIC: DIP switches control LED[3:0]
    --            Buttons control LED[7] and LED[6]
    -- =============================================
    p_led_logic : process(clk)
    begin
        if rising_edge(clk) then
            -- Lower 4 LEDs mirror DIP switches (sw '0' = ON → led '0' = ON)
            led_reg(3 downto 0) <= sw;

            -- LED7 toggles on BTN0 press (active low: pressed = '0')
            if btn0_stable = '0' then
                led_reg(7) <= not led_reg(7);
            end if;

            -- LED6 toggles on BTN1 press
            if btn1_stable = '0' then
                led_reg(6) <= not led_reg(6);
            end if;

            -- LED5 and LED4 show button state (ON when pressed)
            led_reg(5) <= btn0_stable;  -- '0' = ON when button pressed
            led_reg(4) <= btn1_stable;
        end if;
    end process p_led_logic;

    -- Output assignment
    led <= led_reg;

end architecture rtl;
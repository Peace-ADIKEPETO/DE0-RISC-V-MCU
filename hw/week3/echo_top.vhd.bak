-- echo_top.vhd
-- Week 4: UART Echo - type a character, FPGA echoes it back

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity echo_top is
    port (
        clk     : in  std_logic;
        reset_n : in  std_logic;
        rx      : in  std_logic;
        tx      : out std_logic
    );
end entity echo_top;

architecture rtl of echo_top is

    component uart is
        generic (
            CLOCK_FREQ_HZ : positive := 50_000_000;
            BAUD_RATE     : positive := 115200
        );
        port (
            clk      : in  std_logic;
            reset_n  : in  std_logic;
            tx_data  : in  std_logic_vector(7 downto 0);
            tx_start : in  std_logic;
            tx       : out std_logic;
            tx_busy  : out std_logic;
            rx       : in  std_logic;
            rx_data  : out std_logic_vector(7 downto 0);
            rx_done  : out std_logic
        );
    end component;

    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_done  : std_logic;
    signal tx_data  : std_logic_vector(7 downto 0);
    signal tx_start : std_logic := '0';
    signal tx_busy  : std_logic;

begin

    u_uart : uart
        generic map (
            CLOCK_FREQ_HZ => 50_000_000,
            BAUD_RATE     => 115200
        )
        port map (
            clk      => clk,
            reset_n  => reset_n,
            tx_data  => tx_data,
            tx_start => tx_start,
            tx       => tx,
            tx_busy  => tx_busy,
            rx       => rx,
            rx_data  => rx_data,
            rx_done  => rx_done
        );

    -- Echo logic: when a byte is received, send it back
    process(clk)
    begin
        if rising_edge(clk) then
            tx_start <= '0';  -- Default: pulse for one cycle
            if rx_done = '1' and tx_busy = '0' then
                tx_data  <= rx_data;
                tx_start <= '1';
            end if;
        end if;
    end process;

end architecture rtl;
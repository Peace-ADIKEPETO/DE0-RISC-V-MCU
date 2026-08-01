-- uart_tb.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tb is
end entity;

architecture sim of uart_tb is

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

    signal clk      : std_logic := '0';
    signal reset_n  : std_logic := '0';
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start : std_logic := '0';
    signal tx       : std_logic;
    signal tx_busy  : std_logic;
    signal rx       : std_logic := '1';
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_done  : std_logic;

    constant CLK_PERIOD  : time := 20 ns;
    constant BIT_PERIOD  : time := 8680 ns;  -- 1/115200 ≈ 8.68 µs

    -- Procedure to send a byte via RX line (simulate external transmitter)
    procedure uart_send_byte(
        data : in std_logic_vector(7 downto 0);
        signal rx_line : out std_logic
    ) is
    begin
        -- Start bit
        rx_line <= '0';
        wait for BIT_PERIOD;
        -- Data bits (LSB first)
        for i in 0 to 7 loop
            rx_line <= data(i);
            wait for BIT_PERIOD;
        end loop;
        -- Stop bit
        rx_line <= '1';
        wait for BIT_PERIOD;
    end procedure;

begin

    uut: uart
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
        -- Reset
        reset_n <= '0';
        rx      <= '1';
        wait for 100 ns;
        reset_n <= '1';
        wait for 1 us;

        -- Send byte 0x41 ('A')
        uart_send_byte(x"41", rx);
        wait for 10 us;

        -- Send byte 0x42 ('B')
        uart_send_byte(x"42", rx);
        wait for 10 us;

        -- Send byte 0x55 ('U')
        uart_send_byte(x"55", rx);
        wait for 10 us;

        -- Now test TX: send 0x5A ('Z') from FPGA
        wait until tx_busy = '0';
        tx_data  <= x"5A";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';
        wait for 200 us;

        report "Simulation complete" severity note;
        wait;
    end process;

end architecture sim;
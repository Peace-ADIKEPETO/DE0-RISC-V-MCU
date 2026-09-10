-- bootloader_tb.vhd
-- Sends a real UART bit stream (start bit, 8 data bits LSB-first, stop bit)
-- at 115200 baud into the uart module, through the bootloader, and checks
-- that the correct word lands on the RAM write bus, and that cpu_reset_n
-- releases after the EOF record.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity bootloader_tb is
end entity bootloader_tb;

architecture sim of bootloader_tb is

    constant CLK_PERIOD : time := 20 ns;      -- 50 MHz
    constant BIT_PERIOD : time := 8.681 us;   -- 1 / 115200 Hz

    constant CR : character := character'val(13);
    constant LF : character := character'val(10);

    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';

    -- UART
    signal rx       : std_logic := '1';  -- idle high
    signal tx       : std_logic;
    signal tx_busy  : std_logic;
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_done  : std_logic;
    signal bl_tx_data  : std_logic_vector(7 downto 0);
    signal bl_tx_start : std_logic;

    -- Bootloader -> RAM bus (directly observable, no hierarchy needed)
    signal ram_addr  : std_logic_vector(11 downto 0);
    signal ram_wdata : std_logic_vector(31 downto 0);
    signal ram_we    : std_logic;
    signal cpu_reset_n : std_logic;
    signal bl_led       : std_logic_vector(1 downto 0);

    -- RAM readback
    signal ram_rdata : std_logic_vector(31 downto 0);

	 signal captured_addr  : std_logic_vector(11 downto 0) := (others => '0');
    signal captured_wdata : std_logic_vector(31 downto 0) := (others => '0');
    signal write_seen     : std_logic := '0';

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

    component bootloader is
        port (
            clk         : in  std_logic;
            reset_n     : in  std_logic;
            rx_data     : in  std_logic_vector(7 downto 0);
            rx_done     : in  std_logic;
            tx_data     : out std_logic_vector(7 downto 0);
            tx_start    : out std_logic;
            tx_busy     : in  std_logic;
            ram_addr    : out std_logic_vector(11 downto 0);
            ram_wdata   : out std_logic_vector(31 downto 0);
            ram_we      : out std_logic;
            cpu_reset_n : out std_logic;
            led_status  : out std_logic_vector(1 downto 0)
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

    -- Sends one UART byte, LSB first, onto the rx line
    procedure uart_send_byte(signal rx_line : out std_logic; data : in std_logic_vector(7 downto 0)) is
    begin
        rx_line <= '0';                  -- start bit
        wait for BIT_PERIOD;
        for i in 0 to 7 loop
            rx_line <= data(i);
            wait for BIT_PERIOD;
        end loop;
        rx_line <= '1';                  -- stop bit
        wait for BIT_PERIOD;
    end procedure;

    -- Sends an ASCII string over UART, one byte at a time
    procedure uart_send_string(signal rx_line : out std_logic; s : in string) is
    begin
        for i in s'range loop
            uart_send_byte(rx_line, std_logic_vector(to_unsigned(character'pos(s(i)), 8)));
        end loop;
    end procedure;

begin

    clk <= not clk after CLK_PERIOD / 2;

    u_uart: uart
        generic map (
            CLOCK_FREQ_HZ => 50_000_000,
            BAUD_RATE     => 115200
        )
        port map (
            clk      => clk,
            reset_n  => reset_n,
            tx_data  => bl_tx_data,
            tx_start => bl_tx_start,
            tx       => tx,
            tx_busy  => tx_busy,
            rx       => rx,
            rx_data  => rx_data,
            rx_done  => rx_done
        );

    u_boot: bootloader
        port map (
            clk         => clk,
            reset_n     => reset_n,
            rx_data     => rx_data,
            rx_done     => rx_done,
            tx_data     => bl_tx_data,
            tx_start    => bl_tx_start,
            tx_busy     => tx_busy,
            ram_addr    => ram_addr,
            ram_wdata   => ram_wdata,
            ram_we      => ram_we,
            cpu_reset_n => cpu_reset_n,
            led_status  => bl_led
        );

    u_ram: ram_16kb
        port map (
            clk   => clk,
            addr  => ram_addr,
            wdata => ram_wdata,
            wstrb => "1111",   -- bootloader always writes full words
            rdata => ram_rdata,
            we    => ram_we
        );
	monitor: process(clk)
begin
    if rising_edge(clk) then
        if ram_we = '1' then
            captured_addr  <= ram_addr;
            captured_wdata <= ram_wdata;
            write_seen     <= '1';
        end if;
    end if;
end process;

    stim: process
    begin
        reset_n <= '0';
        wait for 200 ns;
        reset_n <= '1';
        wait for 5 us;

        -- Data record: writes 0x400000B7 to address 0
        uart_send_string(rx, ":04000000B7000040B7" & CR & LF);

        -- Check the write bus at the moment ram_we pulses
        uart_send_string(rx, ":04000000B7000040B7" & CR & LF);

        assert write_seen = '1'
        report "FAIL: no RAM write was ever seen for the first line"
        severity error;
        assert captured_addr = x"000"
        report "FAIL: ram_addr mismatch, expected 0x000, got " & to_hstring(captured_addr)
        severity error;
        assert captured_wdata = x"400000B7"
        report "FAIL: ram_wdata mismatch, expected 0x400000B7, got " & to_hstring(captured_wdata)
        severity error;
        report "PASS: first word write = " & to_hstring(captured_wdata);

        write_seen <= '0';  -- reset for any subsequent checks
        uart_send_string(rx, ":00000001FF" & CR & LF);

        wait until cpu_reset_n = '1' for 200 us;
        assert cpu_reset_n = '1'
        report "FAIL: cpu_reset_n never released after EOF record"
        severity error;
        report "PASS: cpu_reset_n released - boot sequence complete";

        report "Testbench finished";
        wait;
    end process;

end architecture sim;
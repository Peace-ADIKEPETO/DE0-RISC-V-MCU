-- uart_tx_tb.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx_tb is
end entity;

architecture sim of uart_tx_tb is

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

    constant CLK_PERIOD : time := 20 ns;   -- 50 MHz clock
    constant BIT_PERIOD : time := 8.68 us; -- 1 bit period at 115200 baud
	 
	 --- Unused 
	 signal rx : std_logic;
	 signal rx_done : std_logic;
	 signal rx_data : std_logic_vector(7 downto 0);

begin

    -- Unit Under Test (UUT)
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

    -- Clock Generator Process
    p_clk : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus Process
    p_stim : process
    begin
        -- Assert Reset safely across multiple clock cycles
        reset_n <= '0';
        wait for 4 * CLK_PERIOD; -- 80 ns reset duration
        reset_n <= '1';
        
        -- Align stimulus to a clean clock boundary
        wait until rising_edge(clk);
        wait for 2 ns; -- Small offset to avoid delta-cycle setup issues

        -- Send character 'A' (0x41 = 01000001)
        tx_data  <= x"41";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        -- Wait for transmission to complete
        wait until tx_busy = '0';
        wait for 1 us;

        -- Send character 'B' (0x42 = 01000010)
        wait until rising_edge(clk);
        tx_data  <= x"42";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        wait until tx_busy = '0';
        wait for 1 us;

        -- Send character 'Z' (0x5A = 01011010)
        wait until rising_edge(clk);
        tx_data  <= x"5A";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        wait until tx_busy = '0';
        wait for 5 us;

        report "Simulation complete successfully" severity note;
        wait; -- Stop simulation
    end process;

end architecture sim;

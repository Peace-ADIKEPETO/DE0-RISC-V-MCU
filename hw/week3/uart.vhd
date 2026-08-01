library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
    generic (
        CLOCK_FREQ_HZ : positive := 50_000_000;
        BAUD_RATE     : positive := 115200
    );
    port (
        clk      : in  std_logic;
        reset_n  : in  std_logic;   --- Active low
		  ---- Tx 
        tx_data  : in  std_logic_vector(7 downto 0);
        tx_start : in  std_logic;
        tx       : out std_logic;
        tx_busy  : out std_logic;
		  --- RX
		  rx       : in  std_logic;
        rx_data  : out std_logic_vector(7 downto 0);
        rx_done  : out std_logic  -- Pulse: '1' for one cycle when byte received
    );
end entity uart;

architecture rtl of uart is
    -- =============================================
    -- BAUD GENERATION
    -- =============================================
    constant BIT_PERIOD    : integer := CLOCK_FREQ_HZ / BAUD_RATE;
    constant HALF_PERIOD   : integer := BIT_PERIOD / 2;

    -- =============================================
    -- TRANSMITTER SIGNALS
    -- =============================================
    signal tx_clk_cnt   : integer range 0 to BIT_PERIOD - 1 := 0;
    signal tx_bit_cnt   : integer range 0 to 10 := 0;
    signal tx_reg       : std_logic_vector(9 downto 0) := (others => '1');
    signal tx_busy_int  : std_logic := '0';
	 
	  -- =============================================
    -- RECEIVER SIGNALS
    -- =============================================
    type rx_state_type is (IDLE, WAIT_HALF, R_DATA, STOP_BIT);
    signal rx_state     : rx_state_type := IDLE;
    signal rx_clk_cnt   : integer range 0 to BIT_PERIOD - 1 := 0;
    signal rx_bit_cnt   : integer range 0 to 7 := 0;
    signal rx_shift     : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_done_int  : std_logic := '0';

    -- Synchronizer for async RX input
    signal rx_sync      : std_logic_vector(2 downto 0) := (others => '1');
	 
	 
begin

  -- Outputs
    tx      <= tx_reg(0);
    tx_busy <= tx_busy_int;
    rx_data <= rx_shift;
    rx_done <= rx_done_int;

    -- =============================================
    -- RX SYNCHRONIZER (3-stage, metastability protection)
    -- =============================================
	 process(clk)
    begin
        if rising_edge(clk) then
            rx_sync <= rx_sync(1 downto 0) & rx;
        end if;
    end process;

    -- =============================================
    -- TRANSMITTER (single-register shifter)
    -- =============================================
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            tx_clk_cnt <= 0;
            tx_bit_cnt <= 0;
            tx_reg  <= (others => '1');
            tx_busy_int    <= '0';
        elsif rising_edge(clk) then
            
            if tx_busy_int = '0' then
                -- IDLE State (Waiting for trigger)
                tx_clk_cnt <= 0;
                tx_bit_cnt <= 0;
                if tx_start = '1' then
                    -- Instantly load the complete frame: '1' (Stop) + Data + '0' (Start)
                    tx_reg  <= '1' & tx_data & '0';
                    tx_busy_int    <= '1';
                end if;
            else
                -- TRANSMISSION State: Manage timing (Baud rate generator)
                if tx_clk_cnt < BIT_PERIOD - 1 then
                    tx_clk_cnt <= tx_clk_cnt + 1;
                else
                    tx_clk_cnt <= 0; -- One full bit period has elapsed
                    
                    if tx_bit_cnt < 9 then
                        -- Shift right to present the next serial bit at tx_reg(0)
                        tx_reg  <= '1' & tx_reg(9 downto 1); -- [STOP, D7..D0, START]
                        tx_bit_cnt <= tx_bit_cnt + 1;
                    else
                        -- End of the 10th bit (Stop bit completed), release transmitter
                        tx_busy_int <= '0';
                    end if;
                end if;
            end if;
            
        end if;
    end process;
	 
	 -- =============================================
    -- RECEIVER STATE MACHINE
    -- =============================================
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            rx_state    <= IDLE;
            rx_clk_cnt  <= 0;
            rx_bit_cnt  <= 0;
            rx_shift    <= (others => '0');
            rx_done_int <= '0';
        elsif rising_edge(clk) then
		  -- Default: rx_done is a single-cycle pulse
            rx_done_int <= '0';

            case rx_state is

                when IDLE =>
                    -- Wait for start bit (line goes low)
                    if rx_sync(2) = '0' then
                        rx_state   <= WAIT_HALF;
                        rx_clk_cnt <= 0;
                    end if;
						    when WAIT_HALF =>
                    -- Wait half a bit period to sample at center
                    if rx_clk_cnt = HALF_PERIOD - 1 then
                        rx_clk_cnt <= 0;
                        rx_bit_cnt <= 0;
                        rx_state   <= R_DATA;
                    else
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end if;

                when R_DATA =>
                    -- Sample at center of each data bit
                    if rx_clk_cnt = BIT_PERIOD - 1 then
						     rx_clk_cnt <= 0;
                        rx_shift   <= rx_sync(2) & rx_shift(7 downto 1);  -- Shift right, LSB first
                        if rx_bit_cnt = 7 then
                            rx_state <= STOP_BIT;
                        else
                            rx_bit_cnt <= rx_bit_cnt + 1;
                        end if;
                    else
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end if;

                when STOP_BIT =>
                    -- Wait one full bit period for stop bit
						   if rx_clk_cnt = BIT_PERIOD - 1 then
                        rx_clk_cnt  <= 0;
                        rx_done_int <= '1';  -- Pulse: byte received
                        rx_state    <= IDLE;
                    else
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end if;

            end case;
        end if;
    end process;

end architecture rtl;

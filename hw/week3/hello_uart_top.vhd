library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hello_uart_top is
    port (
        clk       : in  std_logic;  -- 50MHz (PIN_R8 on DE0-Nano)
        reset_n   : in  std_logic;  -- KEY0, active low (PIN_J15)
        tx        : out std_logic;  -- UART TX Output (PIN_D3 to Arduino RX)
        led_debug : out std_logic_vector(3 downto 0)
    );
end entity hello_uart_top;

architecture rtl of hello_uart_top is

    -- Component declaration for the simplified UART transmitter
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

    -- Message ROM: "Hello World!\r\n" (Exactly 14 bytes)
    constant MSG_LENGTH : positive := 14;
    type msg_array is array (0 to MSG_LENGTH - 1) of std_logic_vector(7 downto 0);
    constant MESSAGE : msg_array := (
        x"48",  -- H
        x"65",  -- e
        x"6C",  -- l
        x"6C",  -- l
        x"6F",  -- o
        x"20",  -- (space)
        x"57",  -- W
        x"6F",  -- o
        x"72",  -- r
        x"6C",  -- l
        x"64",  -- d
        x"21",  -- !
        x"0D",  -- \r (carriage return)
        x"0A"   -- \n (newline)
    );

    signal tx_data     : std_logic_vector(7 downto 0);
    signal tx_start    : std_logic := '0';
    signal tx_busy     : std_logic;

    -- Counter for ~1-second delay between full message bursts (50,000,000 clock cycles)
    constant DELAY_MAX : unsigned(25 downto 0) := to_unsigned(49_999_999, 26);
    signal delay_cnt   : unsigned(25 downto 0) := (others => '0');
    
    signal msg_idx     : integer range 0 to MSG_LENGTH := 0;
    signal debug_state : std_logic_vector(3 downto 0);

    -- State machine simplified to 3 states (no GAP state required due to synchronous design)
    type ctrl_state_type is (INTER_MSG_DELAY, SEND_CHAR, WAIT_UART_READY);
    signal ctrl_state : ctrl_state_type := INTER_MSG_DELAY;
	 
	 signal rx : std_logic;
	 signal rx_done : std_logic;
	 signal rx_data : std_logic_vector(7 downto 0);

begin

    -- Instantiation of the ultra-simplified UART module
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

    -- =============================================
    -- MESSAGE SENDER STATE MACHINE
    -- =============================================
    p_sender : process(clk, reset_n)
    begin
        if reset_n = '0' then
            ctrl_state  <= INTER_MSG_DELAY;
            msg_idx     <= 0;
            tx_data     <= (others => '0');
            tx_start    <= '0';
            delay_cnt   <= (others => '0');
            debug_state <= "0000";
        elsif rising_edge(clk) then
            
            -- Safety: Ensure the start pulse lasts exactly one clock cycle
            tx_start <= '0';

            case ctrl_state is

                when INTER_MSG_DELAY =>
                    debug_state <= "0001";
                    tx_start    <= '0';
                    msg_idx     <= 0;
                    
                    -- Wait for 1 second before sending the complete sentence again
                    if delay_cnt = DELAY_MAX then
                        delay_cnt  <= (others => '0');
                        ctrl_state <= SEND_CHAR;
                    else
                        delay_cnt <= delay_cnt + 1;
                    end if;

                when SEND_CHAR =>
                    debug_state <= "0010";
                    
                    -- Check if there are still characters left to transmit
                    if msg_idx < MSG_LENGTH then
                        tx_data    <= MESSAGE(msg_idx);
                        tx_start   <= '1'; -- Signal the UART module to begin
                        ctrl_state <= WAIT_UART_READY;
                    else
                        -- All 14 characters have been sent, enter the 1-second pause
                        ctrl_state <= INTER_MSG_DELAY;
                    end if;

                when WAIT_UART_READY =>
                    debug_state <= "0100";
                    
                    -- Wait until the UART module finishes transmission and goes idle (tx_busy = '0')
                    -- The internal UART timing handles boundaries; no explicit gap state needed
                    if tx_busy = '0' and tx_start = '0' then
                        msg_idx    <= msg_idx + 1; -- Move to the next character in the ROM
                        ctrl_state <= SEND_CHAR;
                    end if;

                when others =>
                    ctrl_state <= INTER_MSG_DELAY;
            end case;
        end if;
    end process p_sender;
	 
    led_debug <= debug_state;

end architecture rtl;

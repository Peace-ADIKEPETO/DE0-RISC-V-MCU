library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
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
        tx_busy  : out std_logic
    );
end entity uart_tx;

architecture behavioral of uart_tx is
    -- Fixed divider calculation: 50_000_000 / 115200 = 434 clock cycles
    constant BIT_PERIOD : integer := CLOCK_FREQ_HZ / BAUD_RATE;

    signal clk_cnt   : integer range 0 to BIT_PERIOD - 1 := 0;
    signal bit_cnt   : integer range 0 to 11 := 0; -- Counts the 10 bits of the frame
    
    -- 10-bit Shift Register: [STOP (1) | D7..D0 | START (0)]
    signal tx_reg    : std_logic_vector(9 downto 0) := (others => '1');
    signal busy      : std_logic := '0';
begin

    tx_busy <= busy;
    tx      <= tx_reg(0); -- The rightmost bit (LSB) is always driven directly to the TX pin

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            clk_cnt <= 0;
            bit_cnt <= 0;
            tx_reg  <= (others => '1');
            busy    <= '0';
        elsif rising_edge(clk) then
            
            if busy = '0' then
                -- IDLE State (Waiting for trigger)
                clk_cnt <= 0;
                bit_cnt <= 0;
                if tx_start = '1' then
                    -- Instantly load the complete frame: '1' (Stop) + Data + '0' (Start)
                    tx_reg  <= '1' & tx_data & '0';
                    busy    <= '1';
                end if;
            else
                -- TRANSMISSION State: Manage timing (Baud rate generator)
                if clk_cnt < BIT_PERIOD - 1 then
                    clk_cnt <= clk_cnt + 1;
                else
                    clk_cnt <= 0; -- One full bit period has elapsed
                    
                    if bit_cnt < 9 then
                        -- Shift right to present the next serial bit at tx_reg(0)
                        tx_reg  <= '1' & tx_reg(9 downto 1);
                        bit_cnt <= bit_cnt + 1;
                    else
                        -- End of the 10th bit (Stop bit completed), release transmitter
                        busy <= '0';
                    end if;
                end if;
            end if;
            
        end if;
    end process;

end architecture behavioral;

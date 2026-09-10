-- bootloader.vhd
-- Week 6: UART Bootloader - receives Intel HEX (ASCII), writes to RAM, boots CPU
-- Fixed: byte/word assembly using a variable to avoid signal delta-cycle
-- read-before-update bugs (data_byte and word_buffer were both being read
-- one clock edge before their new value actually landed).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bootloader is
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        -- UART interface
        rx_data     : in  std_logic_vector(7 downto 0);
        rx_done     : in  std_logic;  -- Pulse: byte received
        tx_data     : out std_logic_vector(7 downto 0);
        tx_start    : out std_logic;
        tx_busy     : in  std_logic;
        -- RAM interface
        ram_addr    : out std_logic_vector(11 downto 0);
        ram_wdata   : out std_logic_vector(31 downto 0);
        ram_we      : out std_logic;
        -- CPU control
        cpu_reset_n : out std_logic;
        -- Status
        led_status  : out std_logic_vector(1 downto 0)
    );
end entity bootloader;

architecture rtl of bootloader is

    -- =============================================
    -- ASCII TO NIBBLE FUNCTION
    -- =============================================
    function ascii_to_nibble(ascii : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable nibble : std_logic_vector(3 downto 0);
    begin
        case ascii is
            when x"30" => nibble := x"0";  -- '0'
            when x"31" => nibble := x"1";  -- '1'
            when x"32" => nibble := x"2";  -- '2'
            when x"33" => nibble := x"3";  -- '3'
            when x"34" => nibble := x"4";  -- '4'
            when x"35" => nibble := x"5";  -- '5'
            when x"36" => nibble := x"6";  -- '6'
            when x"37" => nibble := x"7";  -- '7'
            when x"38" => nibble := x"8";  -- '8'
            when x"39" => nibble := x"9";  -- '9'
            when x"41" | x"61" => nibble := x"A";  -- 'A' or 'a'
            when x"42" | x"62" => nibble := x"B";  -- 'B' or 'b'
            when x"43" | x"63" => nibble := x"C";  -- 'C' or 'c'
            when x"44" | x"64" => nibble := x"D";  -- 'D' or 'd'
            when x"45" | x"65" => nibble := x"E";  -- 'E' or 'e'
            when x"46" | x"66" => nibble := x"F";  -- 'F' or 'f'
            when others   => nibble := x"0";
        end case;
        return nibble;
    end function;

    -- =============================================
    -- HEX PARSING STATES
    -- =============================================
    type hex_state_type is (
        WAIT_COLON,       -- Wait for ':'
        READ_LENGTH_H,    -- Read byte count high nibble
        READ_LENGTH_L,    -- Read byte count low nibble
        READ_ADDR3,       -- Address byte 3 (bits 15:12)
        READ_ADDR2,       -- Address byte 2 (bits 11:8)
        READ_ADDR1,       -- Address byte 1 (bits 7:4)
        READ_ADDR0,       -- Address byte 0 (bits 3:0)
        READ_TYPE_H,      -- Record type high nibble
        READ_TYPE_L,      -- Record type low nibble
        READ_DATA,        -- Read data bytes (2 hex chars = 1 byte)
        PROCESS_RECORD,   -- Write to RAM or boot CPU
        SEND_ACK,         -- Send 'O' acknowledgement
        FLUSH_LINE        -- Ignore characters until end of line
    );
    signal hex_state : hex_state_type := WAIT_COLON;

    -- Parsing registers
    signal byte_count    : integer range 0 to 255 := 0;
    signal byte_idx      : integer range 0 to 255 := 0;
    signal address       : unsigned(15 downto 0) := (others => '0');
    signal rec_type      : std_logic_vector(7 downto 0) := (others => '0');
    signal data_byte     : std_logic_vector(7 downto 0) := (others => '0');  -- kept for waveform visibility only
    signal high_nibble   : std_logic_vector(3 downto 0) := (others => '0');
    signal nibble_count  : std_logic := '0';  -- '0' = high nibble, '1' = low nibble

    -- Word assembly (4 bytes → 1 word)
    signal word_pos      : integer range 0 to 3 := 0;

    -- CPU reset control
    signal cpu_reset_int : std_logic := '0';

    -- ACK signal
    signal ack_sent      : std_logic := '0';
	 
begin

    cpu_reset_n <= cpu_reset_int;
    led_status(0) <= cpu_reset_int;
    led_status(1) <= not cpu_reset_int;

    -- =============================================
    -- BOOTLOADER STATE MACHINE
    -- =============================================
    process(clk)
        -- Holds the fully-assembled byte within the SAME clock edge it's
        -- completed on. A variable updates immediately (no delta-cycle
        -- delay), unlike data_byte (a signal), so it's safe to use right
        -- away when building word_buffer / ram_wdata below.
        variable completed_byte : std_logic_vector(7 downto 0);
		  variable word_buffer   : std_logic_vector(31 downto 0) := (others => '0');
    begin
	     if rising_edge(clk) then
        if reset_n = '0' then
            hex_state    <= WAIT_COLON;
            byte_count   <= 0;
            byte_idx     <= 0;
            address      <= (others => '0');
            rec_type     <= (others => '0');
            data_byte    <= (others => '0');
            high_nibble  <= (others => '0');
            nibble_count <= '0';
            word_buffer  := (others => '0');
            word_pos     <= 0;
            ram_addr     <= (others => '0');
            ram_wdata    <= (others => '0');
            ram_we       <= '0';
            cpu_reset_int <= '0';
            tx_data      <= (others => '0');
            tx_start     <= '0';
            ack_sent     <= '0';
        else
            -- Defaults
            ram_we   <= '0';
            tx_start <= '0';

            case hex_state is

                -- =============================================
                -- WAIT FOR START OF LINE (':')
                -- =============================================
                when WAIT_COLON =>
                    if rx_done = '1' then
                        if rx_data = x"3A" then  -- ':'
                            hex_state    <= READ_LENGTH_H;
                            nibble_count <= '0';
                            byte_idx     <= 0;
                            word_pos     <= 0;
                        end if;
                        -- Non-colon characters are ignored
                    end if;

                -- =============================================
                -- READ BYTE COUNT (2 hex chars)
                -- =============================================
                when READ_LENGTH_H =>
                    if rx_done = '1' then
                        high_nibble  <= ascii_to_nibble(rx_data);
                        nibble_count <= '1';
                        hex_state    <= READ_LENGTH_L;
                    end if;

                when READ_LENGTH_L =>
                    if rx_done = '1' then
                        byte_count   <= to_integer(unsigned(
                            high_nibble & ascii_to_nibble(rx_data)
                            ));
                        nibble_count <= '0';
                        hex_state    <= READ_ADDR3;
                    end if;

                -- =============================================
                -- READ ADDRESS (4 bytes = 8 hex chars)
                -- =============================================
                when READ_ADDR3 =>
                    if rx_done = '1' then
                        address(15 downto 12) <= unsigned(ascii_to_nibble(rx_data));
                        hex_state <= READ_ADDR2;
                    end if;

                when READ_ADDR2 =>
                    if rx_done = '1' then
                        address(11 downto 8) <= unsigned(ascii_to_nibble(rx_data));
                        hex_state <= READ_ADDR1;
                    end if;

                when READ_ADDR1 =>
                    if rx_done = '1' then
                        address(7 downto 4) <= unsigned(ascii_to_nibble(rx_data));
                        hex_state <= READ_ADDR0;
                    end if;

                when READ_ADDR0 =>
                    if rx_done = '1' then
                        address(3 downto 0) <= unsigned(ascii_to_nibble(rx_data));
                        nibble_count <= '0';
                        hex_state    <= READ_TYPE_H;
                    end if;

                -- =============================================
                -- READ RECORD TYPE (2 hex chars)
                -- =============================================
                when READ_TYPE_H =>
                    if rx_done = '1' then
                        rec_type(7 downto 4) <= ascii_to_nibble(rx_data);
                        hex_state <= READ_TYPE_L;
                    end if;

                when READ_TYPE_L =>
                    if rx_done = '1' then
                        rec_type(3 downto 0) <= ascii_to_nibble(rx_data);
                        nibble_count <= '0';
                        if byte_count = 0 then
                            hex_state <= FLUSH_LINE;  -- No data, skip to checksum
                        else
                            byte_idx  <= 0;
                            hex_state <= READ_DATA;
                        end if;
                    end if;

                -- =============================================
                -- READ DATA BYTES (2 hex chars per byte) -- FIXED
                -- =============================================
                when READ_DATA =>
                    if rx_done = '1' then
                        if nibble_count = '0' then
                            -- High nibble: park it in the signal for the
                            -- next cycle's low-nibble phase to read.
                            data_byte(7 downto 4) <= ascii_to_nibble(rx_data);
                            nibble_count <= '1';
                        else
                            -- Low nibble: assemble the COMPLETE byte in the
                            -- variable right now -- data_byte(7 downto 4)
                            -- is safe to read here because it was written
                            -- on the PREVIOUS clock edge and has already
                            -- settled; only the freshly-parsed low nibble
                            -- needs to come from this cycle's rx_data.
                            data_byte(3 downto 0) <= ascii_to_nibble(rx_data);  -- signal, for waveform visibility only
                            completed_byte := data_byte(7 downto 4) & ascii_to_nibble(rx_data);
                            nibble_count <= '0';

                            -- Assemble into 32-bit word (little-endian)
                            -- using the variable for bytes 0-2. Byte 3 is
                            -- handled directly into ram_wdata below instead
                            -- of via word_buffer, since word_buffer itself
                            -- would suffer the same one-cycle-stale read
                            -- if we tried to read it back in this same
                            -- clock edge right after writing to it.
                            case word_pos is
                               when 0 => word_buffer(7 downto 0)   := completed_byte;
                               when 1 => word_buffer(15 downto 8)  := completed_byte;
                               when 2 => word_buffer(23 downto 16) := completed_byte;
                               when 3 => null;  -- handled below
                            end case;

                            if word_pos = 3 then
                                -- Write word to RAM: assemble the final
                                -- word directly here using the fresh
                                -- completed_byte for the top byte, and the
                                -- already-settled word_buffer for the
                                -- other three (they were written on
                                -- earlier clock edges, so they're valid).
                                ram_addr  <= std_logic_vector(address(13 downto 2));
                                ram_wdata <= completed_byte & word_buffer(23 downto 0);
                                ram_we    <= '1';
                                word_pos  <= 0;
                                address   <= address + 4;
										
                            else
                                word_pos <= word_pos + 1;
                            end if;

                            if byte_idx = byte_count - 1 then
                                hex_state <= FLUSH_LINE;
                            else
                                byte_idx <= byte_idx + 1;
                            end if;
                        end if;
                    end if;

                -- =============================================
                -- FLUSH REMAINING LINE (checksum + \r\n)
                -- =============================================			 
                when FLUSH_LINE =>
                    if rx_done = '1' then
                        if rx_data = x"0A" then  -- \n = end of line
                            hex_state <= PROCESS_RECORD;
                        end if;
                        -- All other characters (checksum, \r) are ignored
                    end if;

                -- =============================================
                -- PROCESS RECORD TYPE
                -- =============================================
                when PROCESS_RECORD =>
                    if rec_type = x"01" then  -- EOF
                        if ack_sent = '0' then
                            cpu_reset_int <= '1';
                            hex_state <= SEND_ACK;
                        else
                            hex_state <= WAIT_COLON;
                        end if;
                    else  -- Data record (00) or other
                        hex_state <= WAIT_COLON;
                    end if;

                -- =============================================
                -- SEND ACKNOWLEDGEMENT
                -- =============================================
                when SEND_ACK =>
                    if tx_busy = '0' then
                        tx_data  <= x"4F";  -- 'O'
                        tx_start <= '1';
                        ack_sent <= '1';
                        hex_state <= WAIT_COLON;
                   end if;
						  

                -- =============================================
                -- DEFAULT
                -- =============================================
                when others =>
                    hex_state <= WAIT_COLON;

            end case;
        end if;
		  end if;
    end process;

end architecture rtl;
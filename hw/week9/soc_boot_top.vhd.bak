-- soc_boot_top.vhd
-- Week 6: SoC with UART Bootloader
-- Fix: added ram_wstrb mux -- bootloader writes full words and needs
-- wstrb = "1111" to actually land in the byte-lane RAM; previously this
-- was tied to cpu_mem_wstrb, which is meaningless while the CPU is held
-- in reset during bootloading.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity soc_boot_top is
    port (
        clk     : in  std_logic;
        reset_n : in  std_logic := '0';  -- BTN0
        -- UART
        rx      : in  std_logic;
        tx      : out std_logic;
        -- GPIO
        led     : out std_logic_vector(7 downto 0);
        sw      : in  std_logic_vector(3 downto 0) := (others => '0')
    );
end entity soc_boot_top;

architecture rtl of soc_boot_top is

    -- UART
    component uart is
        generic (
            CLOCK_FREQ_HZ : positive := 50_000_000;
            BAUD_RATE     : positive := 9600
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

    -- Bootloader
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

    -- RAM
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

    -- PicoRV32
    component picorv32 is
        generic (
            ENABLE_COUNTERS      : integer := 0;
            CATCH_MISALIGN       : integer := 0;
            CATCH_ILLINSN        : integer := 0;
            ENABLE_IRQ           : integer := 0;
            BARREL_SHIFTER       : integer := 0;
            COMPRESSED_ISA       : integer := 0;
            STACKADDR            : std_logic_vector(31 downto 0) := x"00003FFC"
        );
        port (
            clk         : in  std_logic;
            resetn      : in  std_logic;
            trap        : out std_logic;
            mem_valid   : out std_logic;
            mem_instr   : out std_logic;
            mem_ready   : in  std_logic;
            mem_addr    : out std_logic_vector(31 downto 0);
            mem_wdata   : out std_logic_vector(31 downto 0);
            mem_wstrb   : out std_logic_vector(3 downto 0);
            mem_rdata   : in  std_logic_vector(31 downto 0)
        );
    end component;

    -- UART signals
    signal rx_data     : std_logic_vector(7 downto 0);
    signal rx_done     : std_logic;
    signal tx_data     : std_logic_vector(7 downto 0);
    signal tx_start    : std_logic;
    signal tx_busy     : std_logic;
    signal bl_tx_data  : std_logic_vector(7 downto 0);
    signal bl_tx_start : std_logic;

    -- Bootloader signals
    signal bl_ram_addr  : std_logic_vector(11 downto 0);
    signal bl_ram_wdata : std_logic_vector(31 downto 0);
    signal bl_ram_we    : std_logic;
    signal cpu_reset_n  : std_logic;
    signal bl_led       : std_logic_vector(1 downto 0);

    -- CPU signals
    signal cpu_mem_valid : std_logic;
    signal cpu_mem_instr : std_logic;
    signal cpu_mem_ready : std_logic;
    signal cpu_mem_addr  : std_logic_vector(31 downto 0);
    signal cpu_mem_wdata : std_logic_vector(31 downto 0);
    signal cpu_mem_wstrb : std_logic_vector(3 downto 0);
    signal cpu_mem_rdata : std_logic_vector(31 downto 0);
    signal cpu_trap      : std_logic;

    -- RAM signals
    signal ram_rdata     : std_logic_vector(31 downto 0);
    signal ram_addr      : std_logic_vector(11 downto 0);
    signal ram_wdata     : std_logic_vector(31 downto 0);
    signal ram_wstrb     : std_logic_vector(3 downto 0);  -- NEW
    signal ram_we        : std_logic;

    -- Memory map
    signal is_ram        : std_logic;
    signal is_gpio_out   : std_logic;
    signal is_gpio_in    : std_logic;
    signal gpio_out_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_in_reg   : std_logic_vector(31 downto 0);

    -- POR and reset
    signal por_counter   : unsigned(4 downto 0) := (others => '0');  -- widened (5 bits) to actually reach 16
    signal por_reset_n   : std_logic := '0';
    signal sys_reset_n   : std_logic;
	 
	 signal cpu_uart_tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal cpu_uart_tx_start : std_logic := '0';
    signal is_uart_tx        : std_logic;
    signal is_uart_tx_status : std_logic;
    signal is_uart_rx        : std_logic;
    signal uart_rx_hold      : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_rx_valid     : std_logic := '0';
    signal bl_rx_done        : std_logic;  -- gated version bootloader actually sees
	 
begin

    -- =============================================
    -- POWER-ON-RESET
    -- =============================================	 
	 
    process(clk)
    begin
        if rising_edge(clk) then
            if por_counter < 16 then
                por_counter <= por_counter + 1;
                por_reset_n <= '0';
            else
                por_reset_n <= '1';
            end if;
        end if;
    end process;
    sys_reset_n <= por_reset_n and reset_n;

    -- =============================================
    -- UART (shared between bootloader and CPU)
    -- =============================================
    u_uart: uart
        generic map (
            CLOCK_FREQ_HZ => 50_000_000,
            BAUD_RATE     => 9600
        )
        port map (
            clk      => clk,
            reset_n  => sys_reset_n,
            tx_data  => tx_data,
            tx_start => tx_start,
            tx       => tx,
            tx_busy  => tx_busy,
            rx       => rx,
            rx_data  => rx_data,
            rx_done  => rx_done
        );

    tx_data  <= bl_tx_data  when cpu_reset_n = '0' else cpu_uart_tx_data;
    tx_start <= bl_tx_start when cpu_reset_n = '0' else cpu_uart_tx_start;
	 
	 is_uart_tx        <= '1' when cpu_mem_addr = x"40001000" else '0';
    is_uart_tx_status <= '1' when cpu_mem_addr = x"40001004" else '0';
    is_uart_rx         <= '1' when cpu_mem_addr = x"40001008" else '0';
	 

    -- =============================================
    -- BOOTLOADER
    -- =============================================
    u_boot: bootloader
        port map (
            clk         => clk,
            reset_n     => sys_reset_n,
            rx_data     => rx_data,
            rx_done     => bl_rx_done,
            tx_data     => bl_tx_data,
            tx_start    => bl_tx_start,
            tx_busy     => tx_busy,
            ram_addr    => bl_ram_addr,
            ram_wdata   => bl_ram_wdata,
            ram_we      => bl_ram_we,
            cpu_reset_n => cpu_reset_n,
            led_status  => bl_led
        );
		  
	 -- Bootloader only sees UART bytes while it actually owns the bus.
    -- Prevents a typed ':' during normal CPU operation from being
    -- misinterpreted as the start of a new (and potentially corrupting)
    -- Intel HEX record while the CPU is running.
        bl_rx_done <= rx_done when cpu_reset_n = '0' else '0';

    -- =============================================
    -- RAM (shared: bootloader writes, CPU reads/writes)
    -- =============================================
	 --ram_addr <= bl_ram_addr when cpu_reset_n = '0' else (others => '0');
    ram_addr  <= bl_ram_addr  when cpu_reset_n = '0' else cpu_mem_addr(13 downto 2);
    ram_wdata <= bl_ram_wdata when cpu_reset_n = '0' else cpu_mem_wdata;
    ram_we    <= bl_ram_we    when cpu_reset_n = '0' else
                 (cpu_mem_valid and is_ram and (cpu_mem_wstrb(0) or cpu_mem_wstrb(1) or cpu_mem_wstrb(2) or cpu_mem_wstrb(3)));

    -- NEW: bootloader always writes full 32-bit words, so force all four
    -- byte lanes enabled while it owns the bus; CPU uses its own per-byte
    -- wstrb once it's running.
    ram_wstrb <= "1111" when cpu_reset_n = '0' else cpu_mem_wstrb;

    u_ram: ram_16kb
        port map (
            clk   => clk,
            addr  => ram_addr,
            wdata => ram_wdata,
            wstrb => ram_wstrb,   -- was: cpu_mem_wstrb (bug)
            rdata => ram_rdata,
            we    => ram_we
        );

    -- =============================================
    -- MEMORY MAP DECODER
    -- =============================================
    is_ram      <= '1' when cpu_mem_addr(31 downto 14) = "000000000000000000" else '0';
    is_gpio_out <= '1' when cpu_mem_addr = x"40000000" else '0';
    is_gpio_in  <= '1' when cpu_mem_addr = x"40000004" else '0';
	 
	 
    cpu_mem_rdata <= ram_rdata                                            when is_ram = '1'         else
                  gpio_in_reg                                          when is_gpio_in = '1'     else
                  gpio_out_reg                                         when is_gpio_out = '1'    else
                  (x"0000000" & "000" & tx_busy)                       when is_uart_tx_status = '1' else
                  (x"00000" & "000" & uart_rx_valid & uart_rx_hold) when is_uart_rx = '1'    else
                  (others => '0');

    process(clk)
    begin
        if rising_edge(clk) then
            if sys_reset_n = '0' or cpu_reset_n = '0' then
                cpu_mem_ready <= '0';
            else
                cpu_mem_ready <= cpu_mem_valid;
            end if;
        end if;
    end process;

    -- =============================================
    -- GPIO OUTPUT REGISTER
    -- =============================================
	 
    process(clk)
    begin
        if rising_edge(clk) then
            if sys_reset_n = '0' then
                gpio_out_reg <= (others => '0');
            elsif is_gpio_out = '1' and cpu_mem_valid = '1' and cpu_mem_wstrb(0) = '1' then
                gpio_out_reg <= cpu_mem_wdata;
            end if;
        end if;
    end process;
	 
	 -- TX Register
	 
	 process(clk)
      begin
    if rising_edge(clk) then
        if sys_reset_n = '0' then
            cpu_uart_tx_data  <= (others => '0');
            cpu_uart_tx_start <= '0';
        else
            cpu_uart_tx_start <= '0';  -- default: pulses exactly one cycle
            if is_uart_tx = '1' and cpu_mem_valid = '1' and cpu_mem_wstrb(0) = '1' then
                cpu_uart_tx_data  <= cpu_mem_wdata(7 downto 0);
                cpu_uart_tx_start <= '1';
            end if;
        end if;
    end if;
    end process;
	 
 -- RX capture
	 
	 process(clk)
      begin
      if rising_edge(clk) then
        if sys_reset_n = '0' then
            uart_rx_hold  <= (others => '0');
            uart_rx_valid <= '0';
        else
            -- New byte arrives: latch it (only matters when CPU owns the
            -- bus; rx_done still fires from the shared uart module
            -- regardless of who's listening, so this simply captures
            -- whatever comes in while the CPU is running).
            if rx_done = '1' and cpu_reset_n = '1' then
                uart_rx_hold  <= rx_data;
                uart_rx_valid <= '1';
            -- CPU reads the RX register: clear valid on the same cycle
            -- the read is issued (mem_valid + wstrb="0000" = a read),
            -- not on mem_ready, to match the 1-cycle latency already
            -- used elsewhere in this design.
            elsif is_uart_rx = '1' and cpu_mem_valid = '1' and cpu_mem_wstrb = "0000" then
                uart_rx_valid <= '0';
            end if;
         end if;
       end if;
    end process;

    gpio_in_reg <= x"000000" & "0000" & sw;

    -- =============================================
    -- CPU
    -- =============================================
    u_cpu: picorv32
        generic map (
            ENABLE_COUNTERS    => 0,
            CATCH_MISALIGN     => 0,
            CATCH_ILLINSN      => 0,
            ENABLE_IRQ         => 0,
            BARREL_SHIFTER     => 0,
            COMPRESSED_ISA     => 0,
            STACKADDR          => x"00003FFC"
        )
        port map (
            clk         => clk,
            resetn      => cpu_reset_n,
            trap        => cpu_trap,
            mem_valid   => cpu_mem_valid,
            mem_instr   => cpu_mem_instr,
            mem_ready   => cpu_mem_ready,
            mem_addr    => cpu_mem_addr,
            mem_wdata   => cpu_mem_wdata,
            mem_wstrb   => cpu_mem_wstrb,
            mem_rdata   => cpu_mem_rdata
        );

  -- LEDS
-- Show RAM word at addr 0
    led(1 downto 0) <= bl_led when cpu_reset_n = '0' else gpio_out_reg(1 downto 0);
    led(7 downto 2) <= (others => '0') when cpu_reset_n = '0' else gpio_out_reg(7 downto 2);
	 --Debug: show what RAM outputs during CPU fetch

   --led <= ram_rdata(7 downto 0);  -- Show RAM data during CPU access


end architecture rtl;
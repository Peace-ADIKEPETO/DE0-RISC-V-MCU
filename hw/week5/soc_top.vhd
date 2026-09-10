-- soc_top.vhd
-- Week 5: PicoRV32 CPU + 16KB Block RAM + GPIO

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity soc_top is
    port (
        clk     : in  std_logic;
        reset_n : in  std_logic;
        -- GPIO (for testing)
        led     : out std_logic_vector(7 downto 0);
        sw      : in  std_logic_vector(3 downto 0)
    );
end entity soc_top;

architecture rtl of soc_top is

    -- =============================================
    -- PicoRV32 Component Declaration (Verilog)
    -- =============================================

    component picorv32 is
        generic (
            ENABLE_COUNTERS      : integer := 1;
            ENABLE_COUNTERS64    : integer := 1;
            ENABLE_REGS_16_31    : integer := 1;
            ENABLE_REGS_DUALPORT : integer := 1;
            LATCHED_MEM_RDATA    : integer := 0;
            TWO_STAGE_SHIFT      : integer := 1;
            BARREL_SHIFTER       : integer := 0;
            TWO_CYCLE_COMPARE    : integer := 0;
            TWO_CYCLE_ALU        : integer := 0;
            COMPRESSED_ISA       : integer := 0;
            CATCH_MISALIGN       : integer := 1;
            CATCH_ILLINSN        : integer := 1;
            ENABLE_PCPI          : integer := 0;
            ENABLE_MUL           : integer := 0;
            ENABLE_FAST_MUL      : integer := 0;
            ENABLE_DIV           : integer := 0;
            ENABLE_IRQ           : integer := 0;
            ENABLE_IRQ_QREGS     : integer := 1;
            ENABLE_IRQ_TIMER     : integer := 1;
            ENABLE_TRACE         : integer := 0;
            REGS_INIT_ZERO       : integer := 0;
            MASKED_IRQ           : std_logic_vector(31 downto 0) := (others => '0');
            LATCHED_IRQ          : std_logic_vector(31 downto 0) := (others => '1');
            PROGADDR_RESET       : std_logic_vector(31 downto 0) := x"00000000";
            PROGADDR_IRQ         : std_logic_vector(31 downto 0) := x"00000010";
            STACKADDR            : std_logic_vector(31 downto 0) := x"ffffffff"
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

    -- =============================================
    -- Block RAM Component (16KB = 4096 x 32-bit)
    -- =============================================
    component ram_16kb is
        port (
            clk     : in  std_logic;
            addr    : in  std_logic_vector(11 downto 0);  -- 12-bit = 4096 words
            wdata   : in  std_logic_vector(31 downto 0);
            wstrb   : in  std_logic_vector(3 downto 0);
            rdata   : out std_logic_vector(31 downto 0);
            we      : in  std_logic
        );
    end component;

    -- CPU signals
    signal cpu_mem_valid   : std_logic;
    signal cpu_mem_instr   : std_logic;
    signal cpu_mem_ready   : std_logic;
    signal cpu_mem_addr    : std_logic_vector(31 downto 0);
    signal cpu_mem_wdata   : std_logic_vector(31 downto 0);
    signal cpu_mem_wstrb   : std_logic_vector(3 downto 0);
    signal cpu_mem_rdata   : std_logic_vector(31 downto 0);
    signal cpu_trap        : std_logic;

    -- Bus signals
    signal ram_rdata       : std_logic_vector(31 downto 0);
    signal ram_we          : std_logic;
    signal ram_addr        : std_logic_vector(11 downto 0);

    -- Memory map decoding
    signal is_ram          : std_logic;
    signal is_gpio_out     : std_logic;
    signal is_gpio_in      : std_logic;

    -- GPIO registers
    signal gpio_out_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_in_reg     : std_logic_vector(31 downto 0);

    -- mem_ready tracking: RAM has 1 cycle of read latency (registered read),
    -- so ready must fire exactly one cycle after valid, not the same cycle.
    signal mem_ready_reg    : std_logic := '0';
	 
	 -- Power-on-reset: holds CPU in reset for 16 cycles after configuration
    signal por_counter : unsigned(3 downto 0) := (others => '0');
    signal por_reset_n : std_logic := '0';
    signal cpu_reset_n : std_logic;

begin

    -- =============================================
    -- MEMORY MAP DECODING
    -- =============================================
    -- RAM:    0x00000000 - 0x00003FFF
    -- GPIO OUT: 0x40000000
    -- GPIO IN:  0x40000004
    is_ram      <= '1' when cpu_mem_addr(31 downto 14) = "000000000000000000" else '0';
    is_gpio_out <= '1' when cpu_mem_addr = x"40000000" else '0';
    is_gpio_in  <= '1' when cpu_mem_addr = x"40000004" else '0';

    -- RAM address: use lower 12 bits of CPU address (4K words)
    ram_addr <= cpu_mem_addr(13 downto 2);  -- Word-aligned addresses
    ram_we   <= cpu_mem_valid and is_ram and (cpu_mem_wstrb(0) or cpu_mem_wstrb(1) or cpu_mem_wstrb(2) or cpu_mem_wstrb(3));

    -- =============================================
    -- BUS MULTIPLEXER (CPU reads from RAM or GPIO)
    -- =============================================
    cpu_mem_rdata <= ram_rdata      when is_ram = '1'     else
                      gpio_in_reg   when is_gpio_in = '1' else
                      (others => '0');
	 
	 -- POR generator: 16-cycle reset pulse at power-up
    process(clk)
    begin
    if rising_edge(clk) then
        if por_counter < 15 then
            por_counter <= por_counter + 1;
            por_reset_n <= '0';
        else
            por_reset_n <= '1';
        end if;
    end if;
    end process;

   -- Combine POR with button reset (either can reset the CPU)
   cpu_reset_n <= por_reset_n and reset_n;  -- BTN0 also resets
	 
    process(clk, cpu_reset_n)
    begin
        if cpu_reset_n = '0' then
            mem_ready_reg <= '0';
        elsif rising_edge(clk) then
            mem_ready_reg <= cpu_mem_valid and not mem_ready_reg;
        end if;
    end process;

    cpu_mem_ready <= mem_ready_reg;

    -- =============================================
    -- GPIO OUTPUT REGISTER
    -- =============================================
    process(clk, cpu_reset_n)
    begin
        if cpu_reset_n = '0' then
            gpio_out_reg <= (others => '0');
        elsif rising_edge(clk) then
            if is_gpio_out = '1' and cpu_mem_valid = '1' and cpu_mem_wstrb(0) = '1' then
                gpio_out_reg <= cpu_mem_wdata;
            end if;
        end if;
    end process;

    -- GPIO input: connect switches
    gpio_in_reg <= x"000000" & "0000" & sw;

    -- Drive LEDs from GPIO output register (active low)
    led <=  gpio_out_reg(7 downto 0);
	 -- Drive LEDs: LED[0] shows trap state, LED[1] shows gpio_out[0]   (for debug)
    ---led(0) <= cpu_trap;        -- ON if CPU trapped
    ---led(1) <= gpio_out_reg(0); -- ON if GPIO bit 0 = '1'
    ---led(7 downto 2) <= (others => '0'); -- OFF

    -- =============================================
    -- PicoRV32 INSTANTIATION
    -- =============================================
    cpu: picorv32
        generic map (
            ENABLE_COUNTERS      => 0,
            ENABLE_COUNTERS64    => 0,
            CATCH_MISALIGN       => 0,
            CATCH_ILLINSN        => 0,
            ENABLE_IRQ           => 0,
            ENABLE_IRQ_QREGS     => 0,
            ENABLE_IRQ_TIMER     => 0,
            BARREL_SHIFTER       => 0,
            ENABLE_MUL           => 0,
            ENABLE_DIV           => 0,
            COMPRESSED_ISA       => 0,
            STACKADDR            => x"00003FFC"  -- top of 16KB RAM
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

    -- =============================================
    -- 16KB BLOCK RAM
    -- =============================================
    ram: ram_16kb
        port map (
            clk   => clk,
            addr  => ram_addr,
            wdata => cpu_mem_wdata,
            wstrb => cpu_mem_wstrb,
            rdata => ram_rdata,
            we    => ram_we
        );

end architecture rtl;
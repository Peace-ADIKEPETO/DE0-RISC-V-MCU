library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer is
    port (
        clk     : in  std_logic;
        reset_n : in  std_logic;
        cs      : in  std_logic;
        we      : in  std_logic;
        addr    : in  std_logic_vector(3 downto 0);
        wdata   : in  std_logic_vector(31 downto 0);
        rdata   : out std_logic_vector(31 downto 0);
        irq     : out std_logic
    );
end entity;

architecture rtl of timer is
    signal count   : unsigned(31 downto 0) := (others => '0');
    signal compare : unsigned(31 downto 0) := to_unsigned(50_000, 32);
    signal enable  : std_logic := '0';
    signal pending : std_logic := '0';
begin

    irq <= pending;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                count   <= (others => '0');
                compare <= to_unsigned(50_000, 32);
                enable  <= '0';
                pending <= '0';
                rdata   <= (others => '0');
            else
                rdata <= (others => '0');  -- default

                -- Counter: hardware sets pending on wrap. This runs every
                -- cycle regardless of bus activity.
                if enable = '1' then
                    if count >= compare - 1 then
                        count   <= (others => '0');
                        pending <= '1';
                    else
                        count <= count + 1;
                    end if;
                end if;

                -- Bus access: software clear takes priority if it happens
                -- the same cycle as a hardware set (rare, but defined).
                if cs = '1' then
                    if we = '1' then
                        case addr is
                            when "0000" =>
                                enable <= wdata(0);
                                if wdata(1) = '1' then
                                    pending <= '0';
                                end if;
                            when "0001" =>
                                compare <= unsigned(wdata);
                            when "0010" =>
                                count <= (others => '0');
                            when others => null;
                        end case;
                    else
                        case addr is
                            when "0000" =>
                                rdata <= (31 downto 2 => '0') & pending & enable;
                            when "0001" =>
                                rdata <= std_logic_vector(compare);
                            when "0010" =>
                                rdata <= std_logic_vector(count);
                            when others =>
                                rdata <= (others => '0');
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture;
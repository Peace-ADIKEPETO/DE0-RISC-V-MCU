-- ram_16kb.vhd
-- 16KB Block RAM using altsyncram primitive

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity ram_16kb is
    port (
        clk   : in  std_logic;
        addr  : in  std_logic_vector(11 downto 0);
        wdata : in  std_logic_vector(31 downto 0);
        wstrb : in  std_logic_vector(3 downto 0);
        rdata : out std_logic_vector(31 downto 0);
        we    : in  std_logic
    );
end entity ram_16kb;

architecture rtl of ram_16kb is

    -- Four 8-bit-wide M9K blocks, one per byte lane
    -- This is EXACTLY how the M9K hardware works
    
    signal byteena : std_logic_vector(3 downto 0);
    signal rdata_0, rdata_1, rdata_2, rdata_3 : std_logic_vector(7 downto 0);

begin

    -- Combine write enable with byte strobes
    byteena(0) <= we and wstrb(0);
    byteena(1) <= we and wstrb(1);
    byteena(2) <= we and wstrb(2);
    byteena(3) <= we and wstrb(3);

    -- Reassemble 32-bit read data
    rdata <= rdata_3 & rdata_2 & rdata_1 & rdata_0;

    -- =============================================
    -- BYTE LANE 0 (bits 7:0)
    -- =============================================
    ram_byte0 : altsyncram
        generic map (
            operation_mode         => "SINGLE_PORT",
            width_a                => 8,
            widthad_a              => 12,
            numwords_a             => 4096,
            init_file              => "ram_byte0.mif",
            init_file_layout       => "PORT_A",
            outdata_reg_a          => "UNREGISTERED",
            intended_device_family => "Cyclone IV E",
            lpm_type               => "altsyncram"
        )
        port map (
            clock0    => clk,
            address_a => addr,
            data_a    => wdata(7 downto 0),
            wren_a    => byteena(0),
            q_a       => rdata_0
        );

    -- =============================================
    -- BYTE LANE 1 (bits 15:8)
    -- =============================================
    ram_byte1 : altsyncram
        generic map (
            operation_mode         => "SINGLE_PORT",
            width_a                => 8,
            widthad_a              => 12,
            numwords_a             => 4096,
            init_file              => "ram_byte1.mif",
            init_file_layout       => "PORT_A",
            outdata_reg_a          => "UNREGISTERED",
            intended_device_family => "Cyclone IV E",
            lpm_type               => "altsyncram"
        )
        port map (
            clock0    => clk,
            address_a => addr,
            data_a    => wdata(15 downto 8),
            wren_a    => byteena(1),
            q_a       => rdata_1
        );

    -- =============================================
    -- BYTE LANE 2 (bits 23:16)
    -- =============================================
    ram_byte2 : altsyncram
        generic map (
            operation_mode         => "SINGLE_PORT",
            width_a                => 8,
            widthad_a              => 12,
            numwords_a             => 4096,
            init_file              => "ram_byte2.mif",
            init_file_layout       => "PORT_A",
            outdata_reg_a          => "UNREGISTERED",
            intended_device_family => "Cyclone IV E",
            lpm_type               => "altsyncram"
        )
        port map (
            clock0    => clk,
            address_a => addr,
            data_a    => wdata(23 downto 16),
            wren_a    => byteena(2),
            q_a       => rdata_2
        );

    -- =============================================
    -- BYTE LANE 3 (bits 31:24)
    -- =============================================
    ram_byte3 : altsyncram
        generic map (
            operation_mode         => "SINGLE_PORT",
            width_a                => 8,
            widthad_a              => 12,
            numwords_a             => 4096,
            init_file              => "ram_byte3.mif",
            init_file_layout       => "PORT_A",
            outdata_reg_a          => "UNREGISTERED",
            intended_device_family => "Cyclone IV E",
            lpm_type               => "altsyncram"
        )
        port map (
            clock0    => clk,
            address_a => addr,
            data_a    => wdata(31 downto 24),
            wren_a    => byteena(3),
            q_a       => rdata_3
        );

end architecture rtl;
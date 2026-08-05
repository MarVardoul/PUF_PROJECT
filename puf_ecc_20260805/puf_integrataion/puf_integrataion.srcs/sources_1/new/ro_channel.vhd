----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/10/2026 08:28:27 PM
-- Design Name: 
-- Module Name: ro_channel - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ro_channel is
    generic (
        COUNTER_WIDTH : positive := 24
    );
    port (
        RO_EN     : in  std_logic;
        CNT_EN    : in  std_logic;
        CNT_RST   : in  std_logic;

        COUNT_OUT : out std_logic_vector(COUNTER_WIDTH-1 downto 0);
        OSC_OUT   : out std_logic
    );
end ro_channel;

architecture Structural of ro_channel is

    component osc is
        Port (
            EN      : in  STD_LOGIC;
            OSC_OUT : out STD_LOGIC
        );
    end component osc;
    
    component Cntr is
        generic (
            COUNTER_WIDTH : positive := 24
        );
        port (
            CLK       : in  STD_LOGIC;
            EN        : in  STD_LOGIC;
            RST       : in  STD_LOGIC;
            count_out : out STD_LOGIC_VECTOR(COUNTER_WIDTH-1 downto 0)
        );
    end component Cntr;
    signal osc_clk : STD_LOGIC;

begin
    OSC_COMP : osc
        port map (
            EN      => RO_EN,
            OSC_OUT => osc_clk
        );
    CNT_COMP : Cntr
        generic map (
            COUNTER_WIDTH => COUNTER_WIDTH
        )
        port map (
            CLK       => osc_clk,
            EN        => CNT_EN,
            RST       => CNT_RST,
            count_out => COUNT_OUT
        );
    OSC_OUT <= osc_clk;

end architecture Structural;
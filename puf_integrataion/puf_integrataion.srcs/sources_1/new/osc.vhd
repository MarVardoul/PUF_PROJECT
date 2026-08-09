----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/10/2026 08:14:39 PM
-- Design Name: 
-- Module Name: osc - Behavioral
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
library UNISIM;
use UNISIM.VComponents.all;

entity osc is
    Port ( EN : in STD_LOGIC;
           osc_out : out STD_LOGIC);
end osc;

architecture Structural of osc is

    signal ro_feedback    : std_logic;
    signal ro_counter_clk : std_logic;
    signal stage_0        : std_logic;
    signal stage_1        : std_logic;

    attribute KEEP       : string;
    attribute DONT_TOUCH : string;

    attribute KEEP of ro_feedback    : signal is "TRUE";
    attribute KEEP of ro_counter_clk : signal is "TRUE";
    attribute KEEP of stage_0        : signal is "TRUE";
    attribute KEEP of stage_1        : signal is "TRUE";

    attribute DONT_TOUCH of Structural  : architecture is "TRUE";
    attribute DONT_TOUCH of NAND_STAGE  : label is "TRUE";
    attribute DONT_TOUCH of INV_STAGE_1 : label is "TRUE";
    attribute DONT_TOUCH of INV_STAGE_2 : label is "TRUE";
    attribute DONT_TOUCH of TAP_BUFFER  : label is "TRUE";

begin

    NAND_STAGE : LUT2
        generic map (
            INIT => X"7"
        )
        port map (
            I0 => EN,
            I1 => ro_feedback,
            O  => stage_0
        );

    INV_STAGE_1 : LUT1
        generic map (
            INIT => "01"
        )
        port map (
            I0 => stage_0,
            O  => stage_1
        );

    INV_STAGE_2 : LUT1
        generic map (
            INIT => "01"
        )
        port map (
            I0 => stage_1,
            O  => ro_feedback
        );

    TAP_BUFFER : LUT1
        generic map (
            INIT => "10"
        )
        port map (
            I0 => ro_feedback,
            O  => ro_counter_clk
        );

    osc_out <= ro_counter_clk;

end Structural;


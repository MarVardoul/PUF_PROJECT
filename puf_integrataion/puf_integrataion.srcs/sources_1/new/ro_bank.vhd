----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/11/2026 06:04:17 PM
-- Design Name: 
-- Module Name: ro_bank - Structural
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
--array of 16 channels

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ro_bank is
    generic(
    NUM_ROS : positive := 16; --16 channels
    COUNTER_WIDTH : POSITIVE :=24);
    Port ( RO_EN : in STD_LOGIC_VECTOR(NUM_ROS-1 downto 0);
           CNT_EN : in STD_LOGIC;
           CNT_RST : in STD_LOGIC;
           COUNT_OUT : out STD_LOGIC_VECTOR ( NUM_ROS * COUNTER_WIDTH - 1 downto 0);
           OSC_OUT : out STD_LOGIC_VECTOR (NUM_ROS-1 downto 0)
           );
end ro_bank;

architecture Structural of ro_bank is

    component ro_channel is
        generic (
            COUNTER_WIDTH : positive := 24
        );

        port (
            RO_EN     : in  STD_LOGIC;
            CNT_EN    : in  STD_LOGIC;
            CNT_RST   : in  STD_LOGIC;

            COUNT_OUT : out STD_LOGIC_VECTOR(
                COUNTER_WIDTH-1 downto 0
            );

            OSC_OUT   : out STD_LOGIC
        );

    end component ro_channel;
    
begin

    GEN_CHANNELS : for i in 0 to NUM_ROS-1 generate
    begin

        CHANNEL_COMP : ro_channel
            generic map (
                COUNTER_WIDTH => COUNTER_WIDTH
            )

            port map (
                RO_EN   => RO_EN(i),
                CNT_EN  => CNT_EN,
                CNT_RST => CNT_RST,

                COUNT_OUT => COUNT_OUT(
                    (i+1)*COUNTER_WIDTH-1
                    downto
                    i*COUNTER_WIDTH
                ),

                OSC_OUT => OSC_OUT(i)
            );

    end generate GEN_CHANNELS;

end Structural;

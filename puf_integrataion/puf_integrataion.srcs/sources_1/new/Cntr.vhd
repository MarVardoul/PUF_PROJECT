----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/10/2026 07:33:24 PM
-- Design Name: 
-- Module Name: Cntr - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Cntr is
    generic (
        COUNTER_WIDTH : positive := 24
    );
    Port ( CLK : in STD_LOGIC;
           EN : in STD_LOGIC;
           RST: in std_logic;
           count_out : out std_logic_vector(COUNTER_WIDTH-1 downto 0)
           );
end Cntr;

architecture Behavioral of Cntr is

signal count_reg:unsigned(COUNTER_WIDTH-1 downto 0):= (others => '0');

begin
 process(CLK, RST)
 begin 
    if RST='1' then
        count_reg<=(others=>'0');
        
   elsif rising_edge(CLK) then
      if EN='1' then
        count_reg<=count_reg+1;
     end if;
     
   end if;
 end process;
count_out<=std_logic_vector(count_reg);
end Behavioral;

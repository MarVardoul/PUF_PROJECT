----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/13/2026 12:35:34 PM
-- Design Name: 
-- Module Name: count_selector - Behavioral
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

entity count_selector is
    Port ( count_bank : in STD_LOGIC_VECTOR (383 downto 0);
           SEL: in STD_LOGIC_VECTOR (3 downto 0);
           SELECTED_COUNT : out STD_LOGIC_VECTOR (23 downto 0));
end count_selector;

architecture Behavioral of count_selector is
begin

    process(count_bank, SEL)
    begin

        case SEL is

            when "0000" =>
                SELECTED_COUNT <= count_bank(23 downto 0);

            when "0001" =>
                SELECTED_COUNT <= count_bank(47 downto 24);

            when "0010" =>
                SELECTED_COUNT <= count_bank(71 downto 48);

            when "0011" =>
                SELECTED_COUNT <= count_bank(95 downto 72);

            when "0100" =>
                SELECTED_COUNT <= count_bank(119 downto 96);

            when "0101" =>
                SELECTED_COUNT <= count_bank(143 downto 120);

            when "0110" =>
                SELECTED_COUNT <= count_bank(167 downto 144);

            when "0111" =>
                SELECTED_COUNT <= count_bank(191 downto 168);

            when "1000" =>
                SELECTED_COUNT <= count_bank(215 downto 192);

            when "1001" =>
                SELECTED_COUNT <= count_bank(239 downto 216);

            when "1010" =>
                SELECTED_COUNT <= count_bank(263 downto 240);

            when "1011" =>
                SELECTED_COUNT <= count_bank(287 downto 264);

            when "1100" =>
                SELECTED_COUNT <= count_bank(311 downto 288);

            when "1101" =>
                SELECTED_COUNT <= count_bank(335 downto 312);

            when "1110" =>
                SELECTED_COUNT <= count_bank(359 downto 336);

            when "1111" =>
                SELECTED_COUNT <= count_bank(383 downto 360);

            when others =>
                SELECTED_COUNT <= (others => '0');

        end case;

    end process;

end Behavioral;

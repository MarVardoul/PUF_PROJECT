library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity comparator is
    Port (
        COUNT_A  : in  STD_LOGIC_VECTOR(23 downto 0);
        COUNT_B  : in  STD_LOGIC_VECTOR(23 downto 0);
        RESPONSE : out STD_LOGIC;
        VALID    : out STD_LOGIC;
        DELTA    : out STD_LOGIC_VECTOR(24 downto 0)
    );
end comparator;

architecture Behavioral of comparator is

    constant MARGIN : unsigned(24 downto 0) := to_unsigned(100, 25);

begin

    process(COUNT_A, COUNT_B)
        variable A_value    : unsigned(24 downto 0);
        variable B_value    : unsigned(24 downto 0);
        variable difference : unsigned(24 downto 0);
    begin

        A_value := unsigned('0' & COUNT_A);
        B_value := unsigned('0' & COUNT_B);

        if A_value > B_value then
            difference := A_value - B_value;
            RESPONSE   <= '1';
        else
            difference := B_value - A_value;
            RESPONSE   <= '0';
        end if;

        if difference < MARGIN then
            VALID <= '0';
        else
            VALID <= '1';
        end if;

        DELTA <= std_logic_vector(difference);

    end process;

end Behavioral;
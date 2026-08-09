library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ro_pair_decoder is
    Port (
        SEL_A      : in  STD_LOGIC_VECTOR(3 downto 0);
        SEL_B      : in  STD_LOGIC_VECTOR(3 downto 0);
        ENABLE     : in  STD_LOGIC;
        RO_EN      : out STD_LOGIC_VECTOR(15 downto 0);
        PAIR_VALID : out STD_LOGIC
    );
end ro_pair_decoder;

architecture RTL of ro_pair_decoder is
begin

    process(SEL_A, SEL_B, ENABLE)
    begin

        RO_EN      <= (others => '0');
        PAIR_VALID <= '0';

        if SEL_A /= SEL_B then

            PAIR_VALID <= '1';

            if ENABLE = '1' then
                RO_EN(to_integer(unsigned(SEL_A))) <= '1';
                RO_EN(to_integer(unsigned(SEL_B))) <= '1';
            end if;

        end if;

    end process;

end RTL;
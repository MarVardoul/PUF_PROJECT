library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity count_selector_tb is
end count_selector_tb;

architecture Behavioral of count_selector_tb is

    component count_selector is
        Port (
            count_bank     : in  STD_LOGIC_VECTOR(383 downto 0);
            SEL            : in  STD_LOGIC_VECTOR(3 downto 0);
            SELECTED_COUNT : out STD_LOGIC_VECTOR(23 downto 0)
        );
    end component;

    -- Initialize SEL so that it never starts as "UUUU".
    signal count_bank     : STD_LOGIC_VECTOR(383 downto 0) := (others => '0');
    signal SEL            : STD_LOGIC_VECTOR(3 downto 0)   := (others => '0');
    signal SELECTED_COUNT : STD_LOGIC_VECTOR(23 downto 0);

begin

    DUT : count_selector
        port map (
            count_bank     => count_bank,
            SEL            => SEL,
            SELECTED_COUNT => SELECTED_COUNT
        );

    stimulus_process : process

        variable temp_bank : STD_LOGIC_VECTOR(383 downto 0);
        variable expected  : STD_LOGIC_VECTOR(23 downto 0);

    begin

        --------------------------------------------------------------
        -- Initialize all 16 counter positions with different values.
        --
        -- Counter 0  = 7
        -- Counter 1  = 107
        -- Counter 2  = 207
        -- ...
        -- Counter 15 = 1507
        --------------------------------------------------------------

        temp_bank := (others => '0');

        for i in 0 to 15 loop

            temp_bank(
                (i * 24) + 23 downto i * 24
            ) := std_logic_vector(to_unsigned((i * 100) + 7, 24));

        end loop;

        count_bank <= temp_bank;

        -- Allow the signal assignment to take effect.
        wait for 10 ns;

        --------------------------------------------------------------
        -- Test all possible selector values.
        --------------------------------------------------------------

        for i in 0 to 15 loop

            SEL <= std_logic_vector(to_unsigned(i, 4));

            wait for 10 ns;

            expected :=
                std_logic_vector(to_unsigned((i * 100) + 7, 24));

            assert SELECTED_COUNT = expected
                report "ERROR: Incorrect output for SEL = "
                       & integer'image(i)
                severity error;

        end loop;

        --------------------------------------------------------------
        -- Simulation completed successfully.
        --------------------------------------------------------------

        assert false
            report "All count_selector tests completed."
            severity note;

        wait;

    end process;

end Behavioral;
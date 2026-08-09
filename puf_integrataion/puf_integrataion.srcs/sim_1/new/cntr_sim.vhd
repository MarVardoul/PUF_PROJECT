----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 07/10/2026 07:50:43 PM
-- Design Name:
-- Module Name: cntr_sim - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: Testbench for Cntr
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cntr_sim is
end cntr_sim;

architecture Behavioral of cntr_sim is

    constant COUNTER_WIDTH : positive := 24;
    constant CLK_PERIOD    : time := 10 ns;

    signal CLK       : std_logic := '0';
    signal EN        : std_logic := '0';
    signal RST       : std_logic := '0';
    signal count_out : std_logic_vector(COUNTER_WIDTH-1 downto 0);

begin

    ------------------------------------------------------------------
    -- Instantiate counter
    ------------------------------------------------------------------

    UUT : entity work.Cntr
        generic map (
            COUNTER_WIDTH => COUNTER_WIDTH
        )
        port map (
            CLK       => CLK,
            EN        => EN,
            RST       => RST,
            count_out => count_out
        );


    ------------------------------------------------------------------
    -- Clock generation
    ------------------------------------------------------------------

    CLK_process : process
    begin

        CLK <= '0';
        wait for CLK_PERIOD / 2;

        CLK <= '1';
        wait for CLK_PERIOD / 2;

    end process;


    ------------------------------------------------------------------
    -- Stimulus
    ------------------------------------------------------------------

    stimulus_process : process
    begin

        --------------------------------------------------------------
        -- Reset counter
        --------------------------------------------------------------

        RST <= '1';
        EN  <= '0';

        wait for 20 ns;

        RST <= '0';


        --------------------------------------------------------------
        -- Enable counter
        --------------------------------------------------------------

        wait for 10 ns;

        EN <= '1';

        wait for 100 ns;


        --------------------------------------------------------------
        -- Stop counting
        --------------------------------------------------------------

        EN <= '0';

        wait for 50 ns;


        --------------------------------------------------------------
        -- Continue counting
        --------------------------------------------------------------

        EN <= '1';

        wait for 50 ns;


        --------------------------------------------------------------
        -- Reset counter again
        --------------------------------------------------------------

        RST <= '1';

        wait for 20 ns;

        RST <= '0';


        --------------------------------------------------------------
        -- Count again
        --------------------------------------------------------------

        wait for 10 ns;

        EN <= '1';

        wait for 50 ns;


        --------------------------------------------------------------
        -- Stop simulation activity
        --------------------------------------------------------------

        EN <= '0';

        wait;

    end process;

end Behavioral;
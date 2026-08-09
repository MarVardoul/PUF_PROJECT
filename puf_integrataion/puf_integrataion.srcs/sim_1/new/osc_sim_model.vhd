library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

architecture Simulation of osc is

begin

    OSC_PROCESS : process
    begin

        -- Oscillator disabled
        OSC_OUT <= '1';

        -- Wait until enabled
        wait until EN = '1';

        -- Simulated 100 MHz oscillator
        while EN = '1' loop

            OSC_OUT <= '0';
            wait for 5 ns;

            exit when EN = '0';

            OSC_OUT <= '1';
            wait for 5 ns;

        end loop;

    end process OSC_PROCESS;

end architecture Simulation;
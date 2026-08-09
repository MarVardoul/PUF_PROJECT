library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ro_puf_top_tb is
end ro_puf_top_tb;

architecture Behavioral of ro_puf_top_tb is

    constant RESET_CYCLES_TB   : positive := 3;
    constant SETTLE_CYCLES_TB  : positive := 4;
    constant MEASURE_CYCLES_TB : positive := 10;
    constant STOP_CYCLES_TB    : positive := 3;

    signal SYS_CLK    : STD_LOGIC := '0';
    signal RST        : STD_LOGIC := '1';
    signal START      : STD_LOGIC := '0';
    signal SEL_A      : STD_LOGIC_VECTOR(3 downto 0) := "0011";
    signal SEL_B      : STD_LOGIC_VECTOR(3 downto 0) := "1100";

    signal RESPONSE   : STD_LOGIC;
    signal VALID      : STD_LOGIC;
    signal PAIR_VALID : STD_LOGIC;
    signal DELTA      : STD_LOGIC_VECTOR(24 downto 0);
    signal BUSY       : STD_LOGIC;
    signal DONE       : STD_LOGIC;

    signal SIM_DONE   : boolean := false;

begin

    DUT : configuration work.ro_puf_top_sim_cfg
        generic map (
            RESET_CYCLES   => RESET_CYCLES_TB,
            SETTLE_CYCLES  => SETTLE_CYCLES_TB,
            MEASURE_CYCLES => MEASURE_CYCLES_TB,
            STOP_CYCLES    => STOP_CYCLES_TB
        )
        port map (
            SYS_CLK    => SYS_CLK,
            RST        => RST,
            START      => START,
            SEL_A      => SEL_A,
            SEL_B      => SEL_B,
            RESPONSE   => RESPONSE,
            VALID      => VALID,
            PAIR_VALID => PAIR_VALID,
            DELTA      => DELTA,
            BUSY       => BUSY,
            DONE       => DONE
        );

    clock_process : process
    begin
        while not SIM_DONE loop
            SYS_CLK <= '0';
            wait for 5 ns;

            SYS_CLK <= '1';
            wait for 5 ns;
        end loop;

        wait;
    end process;

    stimulus_process : process
    begin

        RST   <= '1';
        START <= '0';
        SEL_A <= "0011";
        SEL_B <= "1100";

        wait until rising_edge(SYS_CLK);
        wait until rising_edge(SYS_CLK);
        wait until rising_edge(SYS_CLK);
        wait for 1 ns;

        RST <= '0';

        wait until rising_edge(SYS_CLK);
        wait for 1 ns;

        assert PAIR_VALID = '1'
            report "Error: Pair 3 and 12 should be valid"
            severity error;

        START <= '1';

        wait until DONE = '1';
        wait for 1 ns;

        assert PAIR_VALID = '1'
            report "Error: PAIR_VALID should be 1"
            severity error;

        assert BUSY = '0'
            report "Error: BUSY should be 0 when DONE is 1"
            severity error;

        assert RESPONSE = '0'
            report "Error: Equal simulated frequencies should produce RESPONSE = 0"
            severity error;

        assert VALID = '0'
            report "Error: Equal simulated frequencies should produce VALID = 0"
            severity error;

        assert unsigned(DELTA) = to_unsigned(0, 25)
            report "Error: Equal simulated frequencies should produce DELTA = 0"
            severity error;

        START <= '0';

        wait until rising_edge(SYS_CLK);
        wait for 1 ns;

        assert DONE = '0'
            report "Error: DONE should return to 0"
            severity error;

        assert BUSY = '0'
            report "Error: Controller should return to IDLE"
            severity error;

        SEL_A <= "0101";
        SEL_B <= "0101";

        wait for 10 ns;

        assert PAIR_VALID = '0'
            report "Error: Equal selectors should produce PAIR_VALID = 0"
            severity error;

        START <= '1';

        wait for 100 ns;

        assert BUSY = '0'
            report "Error: Invalid pair should not start measurement"
            severity error;

        assert DONE = '0'
            report "Error: Invalid pair should not produce DONE"
            severity error;

        START <= '0';

        wait until rising_edge(SYS_CLK);
        wait for 1 ns;

        SEL_A <= "0000";
        SEL_B <= "1111";

        wait for 10 ns;

        assert PAIR_VALID = '1'
            report "Error: Pair 0 and 15 should be valid"
            severity error;

        START <= '1';

        wait until DONE = '1';
        wait for 1 ns;

        assert BUSY = '0'
            report "Error: BUSY should be 0 after second measurement"
            severity error;

        assert RESPONSE = '0'
            report "Error: Equal simulated frequencies should produce RESPONSE = 0"
            severity error;

        assert VALID = '0'
            report "Error: Equal simulated frequencies should produce VALID = 0"
            severity error;

        assert unsigned(DELTA) = to_unsigned(0, 25)
            report "Error: Second measurement should produce DELTA = 0"
            severity error;

        START <= '0';

        wait until rising_edge(SYS_CLK);
        wait for 1 ns;

        assert DONE = '0'
            report "Error: Controller did not return to IDLE"
            severity error;

        assert false
            report "All ro_puf_top tests completed successfully"
            severity note;

        SIM_DONE <= true;

        wait;

    end process;

end Behavioral;
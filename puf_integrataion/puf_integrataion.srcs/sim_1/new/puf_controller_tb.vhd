library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity puf_controller_tb is
end puf_controller_tb;

architecture Behavioral of puf_controller_tb is

    constant RESET_CYCLES_TB   : positive := 3;
    constant SETTLE_CYCLES_TB  : positive := 4;
    constant MEASURE_CYCLES_TB : positive := 5;
    constant STOP_CYCLES_TB    : positive := 3;

    component puf_controller is
        generic (
            RESET_CYCLES   : positive := 4;
            SETTLE_CYCLES  : positive := 100;
            MEASURE_CYCLES : positive := 100000;
            STOP_CYCLES    : positive := 4
        );
        Port (
            SYS_CLK    : in  STD_LOGIC;
            RST        : in  STD_LOGIC;
            START      : in  STD_LOGIC;
            PAIR_VALID : in  STD_LOGIC;
            RO_ENABLE  : out STD_LOGIC;
            CNT_EN     : out STD_LOGIC;
            CNT_RST    : out STD_LOGIC;
            CAPTURE    : out STD_LOGIC;
            BUSY       : out STD_LOGIC;
            DONE       : out STD_LOGIC
        );
    end component;

    signal SYS_CLK    : STD_LOGIC := '0';
    signal RST        : STD_LOGIC := '1';
    signal START      : STD_LOGIC := '0';
    signal PAIR_VALID : STD_LOGIC := '0';

    signal RO_ENABLE  : STD_LOGIC;
    signal CNT_EN     : STD_LOGIC;
    signal CNT_RST    : STD_LOGIC;
    signal CAPTURE    : STD_LOGIC;
    signal BUSY       : STD_LOGIC;
    signal DONE       : STD_LOGIC;

    signal SIM_DONE   : boolean := false;

begin

    DUT : puf_controller
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
            PAIR_VALID => PAIR_VALID,
            RO_ENABLE  => RO_ENABLE,
            CNT_EN     => CNT_EN,
            CNT_RST    => CNT_RST,
            CAPTURE    => CAPTURE,
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

        procedure check_cycle (
            constant expected_ro_enable : in STD_LOGIC;
            constant expected_cnt_en    : in STD_LOGIC;
            constant expected_cnt_rst   : in STD_LOGIC;
            constant expected_capture   : in STD_LOGIC;
            constant expected_busy      : in STD_LOGIC;
            constant expected_done      : in STD_LOGIC;
            constant test_name          : in string
        ) is
        begin

            wait until rising_edge(SYS_CLK);
            wait for 1 ns;

            assert RO_ENABLE = expected_ro_enable
                report test_name & ": incorrect RO_ENABLE"
                severity error;

            assert CNT_EN = expected_cnt_en
                report test_name & ": incorrect CNT_EN"
                severity error;

            assert CNT_RST = expected_cnt_rst
                report test_name & ": incorrect CNT_RST"
                severity error;

            assert CAPTURE = expected_capture
                report test_name & ": incorrect CAPTURE"
                severity error;

            assert BUSY = expected_busy
                report test_name & ": incorrect BUSY"
                severity error;

            assert DONE = expected_done
                report test_name & ": incorrect DONE"
                severity error;

        end procedure;

    begin

        RST        <= '1';
        START      <= '0';
        PAIR_VALID <= '0';

        check_cycle('0', '0', '0', '0', '0', '0', "Reset cycle 1");
        check_cycle('0', '0', '0', '0', '0', '0', "Reset cycle 2");

        RST        <= '0';
        START      <= '1';
        PAIR_VALID <= '0';

        check_cycle('0', '0', '0', '0', '0', '0', "Invalid pair cycle 1");
        check_cycle('0', '0', '0', '0', '0', '0', "Invalid pair cycle 2");

        PAIR_VALID <= '1';

        check_cycle('0', '0', '1', '0', '1', '0', "Reset counters cycle 1");

        for i in 2 to RESET_CYCLES_TB loop
            check_cycle('0', '0', '1', '0', '1', '0',
                        "Reset counters cycle " & integer'image(i));
        end loop;

        check_cycle('1', '0', '0', '0', '1', '0', "Start ROs");

        for i in 1 to SETTLE_CYCLES_TB loop
            check_cycle('1', '0', '0', '0', '1', '0',
                        "Settle cycle " & integer'image(i));
        end loop;

        for i in 1 to MEASURE_CYCLES_TB loop
            check_cycle('1', '1', '0', '0', '1', '0',
                        "Measure cycle " & integer'image(i));
        end loop;

        check_cycle('1', '0', '0', '0', '1', '0', "Stop counting");

        for i in 1 to STOP_CYCLES_TB loop
            check_cycle('0', '0', '0', '0', '1', '0',
                        "Stop cycle " & integer'image(i));
        end loop;

        check_cycle('0', '0', '0', '1', '1', '0', "Capture result");

        check_cycle('0', '0', '0', '0', '0', '1', "Done cycle 1");
        check_cycle('0', '0', '0', '0', '0', '1', "Done cycle 2");

        START <= '0';

        check_cycle('0', '0', '0', '0', '0', '0', "Return to idle");

        assert false
            report "All puf_controller tests completed successfully"
            severity note;

        SIM_DONE <= true;

        wait;

    end process;

end Behavioral;
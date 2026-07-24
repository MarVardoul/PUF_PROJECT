library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity puf_controller is
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
end puf_controller;

architecture RTL of puf_controller is

    type state_type is (
        IDLE,
        RESET_COUNTERS,
        START_ROS,
        SETTLE_ROS,
        MEASURE,
        STOP_COUNTING,
        STOP_ROS,
        CAPTURE_RESULT,
        DONE_STATE
    );

    function maximum (
        A : positive;
        B : positive;
        C : positive;
        D : positive
    ) return positive is
        variable result_value : positive := A;
    begin
        if B > result_value then
            result_value := B;
        end if;

        if C > result_value then
            result_value := C;
        end if;

        if D > result_value then
            result_value := D;
        end if;

        return result_value;
    end function;

    constant MAX_CYCLES : positive :=
        maximum(
            RESET_CYCLES,
            SETTLE_CYCLES,
            MEASURE_CYCLES,
            STOP_CYCLES
        );

    signal current_state : state_type := IDLE;
    signal next_state    : state_type := IDLE;

    signal cycle_count : integer range 0 to MAX_CYCLES-1 := 0;

begin

    state_register : process(SYS_CLK, RST)
    begin
        if RST = '1' then
            current_state <= IDLE;
            cycle_count   <= 0;

        elsif rising_edge(SYS_CLK) then
            current_state <= next_state;

            case current_state is

                when RESET_COUNTERS =>
                    if cycle_count = RESET_CYCLES-1 then
                        cycle_count <= 0;
                    else
                        cycle_count <= cycle_count + 1;
                    end if;

                when SETTLE_ROS =>
                    if cycle_count = SETTLE_CYCLES-1 then
                        cycle_count <= 0;
                    else
                        cycle_count <= cycle_count + 1;
                    end if;

                when MEASURE =>
                    if cycle_count = MEASURE_CYCLES-1 then
                        cycle_count <= 0;
                    else
                        cycle_count <= cycle_count + 1;
                    end if;

                when STOP_ROS =>
                    if cycle_count = STOP_CYCLES-1 then
                        cycle_count <= 0;
                    else
                        cycle_count <= cycle_count + 1;
                    end if;

                when others =>
                    cycle_count <= 0;

            end case;
        end if;
    end process;

    next_state_logic : process(
        current_state,
        cycle_count,
        START,
        PAIR_VALID
    )
    begin

        next_state <= current_state;

        case current_state is

            when IDLE =>
                if START = '1' and PAIR_VALID = '1' then
                    next_state <= RESET_COUNTERS;
                end if;

            when RESET_COUNTERS =>
                if cycle_count = RESET_CYCLES-1 then
                    next_state <= START_ROS;
                end if;

            when START_ROS =>
                next_state <= SETTLE_ROS;

            when SETTLE_ROS =>
                if cycle_count = SETTLE_CYCLES-1 then
                    next_state <= MEASURE;
                end if;

            when MEASURE =>
                if cycle_count = MEASURE_CYCLES-1 then
                    next_state <= STOP_COUNTING;
                end if;

            when STOP_COUNTING =>
                next_state <= STOP_ROS;

            when STOP_ROS =>
                if cycle_count = STOP_CYCLES-1 then
                    next_state <= CAPTURE_RESULT;
                end if;

            when CAPTURE_RESULT =>
                next_state <= DONE_STATE;

            when DONE_STATE =>
                if START = '0' then
                    next_state <= IDLE;
                end if;

        end case;

    end process;

    output_logic : process(current_state)
    begin

        RO_ENABLE <= '0';
        CNT_EN    <= '0';
        CNT_RST   <= '0';
        CAPTURE   <= '0';
        BUSY      <= '0';
        DONE      <= '0';

        case current_state is

            when IDLE =>
                null;

            when RESET_COUNTERS =>
                CNT_RST <= '1';
                BUSY    <= '1';

            when START_ROS =>
                RO_ENABLE <= '1';
                BUSY      <= '1';

            when SETTLE_ROS =>
                RO_ENABLE <= '1';
                BUSY      <= '1';

            when MEASURE =>
                RO_ENABLE <= '1';
                CNT_EN    <= '1';
                BUSY      <= '1';

            when STOP_COUNTING =>
                RO_ENABLE <= '1';
                BUSY      <= '1';

            when STOP_ROS =>
                BUSY <= '1';

            when CAPTURE_RESULT =>
                CAPTURE <= '1';
                BUSY    <= '1';

            when DONE_STATE =>
                DONE <= '1';

        end case;

    end process;

end RTL;
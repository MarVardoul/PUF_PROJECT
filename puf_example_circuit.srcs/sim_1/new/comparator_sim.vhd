library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity comparator_tb is
end comparator_tb;

architecture Behavioral of comparator_tb is

    component comparator
        Port (
            COUNT_A  : in  STD_LOGIC_VECTOR(23 downto 0);
            COUNT_B  : in  STD_LOGIC_VECTOR(23 downto 0);
            RESPONSE : out STD_LOGIC;
            VALID    : out STD_LOGIC;
            DELTA    : out STD_LOGIC_VECTOR(24 downto 0)
        );
    end component;

    signal COUNT_A  : STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
    signal COUNT_B  : STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
    signal RESPONSE : STD_LOGIC;
    signal VALID    : STD_LOGIC;
    signal DELTA    : STD_LOGIC_VECTOR(24 downto 0);

begin

    -- Device under test
    DUT : comparator
        port map (
            COUNT_A  => COUNT_A,
            COUNT_B  => COUNT_B,
            RESPONSE => RESPONSE,
            VALID    => VALID,
            DELTA    => DELTA
        );

    stimulus : process

        procedure test_comparator (
            constant test_name         : in string;
            constant input_a           : in natural;
            constant input_b           : in natural;
            constant expected_response : in std_logic;
            constant expected_valid    : in std_logic;
            constant expected_delta    : in natural
        ) is
        begin

            COUNT_A <= std_logic_vector(to_unsigned(input_a, COUNT_A'length));
            COUNT_B <= std_logic_vector(to_unsigned(input_b, COUNT_B'length));

            -- Allow combinational circuit to update
            wait for 10 ns;

            assert RESPONSE = expected_response
                report test_name & ": incorrect RESPONSE"
                severity error;

            assert VALID = expected_valid
                report test_name & ": incorrect VALID"
                severity error;

            assert unsigned(DELTA) = to_unsigned(expected_delta, DELTA'length)
                report test_name &
                       ": incorrect DELTA. Expected " &
                       integer'image(expected_delta) &
                       ", received " &
                       integer'image(to_integer(unsigned(DELTA)))
                severity error;

            report test_name & " passed"
                severity note;

        end procedure;

    begin

        -- Test 1: A is clearly larger than B
        test_comparator(
            test_name         => "Test 1: A larger than B",
            input_a           => 1250,
            input_b           => 1000,
            expected_response => '1',
            expected_valid    => '1',
            expected_delta    => 250
        );

        -- Test 2: B is clearly larger than A
        test_comparator(
            test_name         => "Test 2: B larger than A",
            input_a           => 1000,
            input_b           => 1250,
            expected_response => '0',
            expected_valid    => '1',
            expected_delta    => 250
        );

        -- Test 3: A is larger, but difference is below margin
        test_comparator(
            test_name         => "Test 3: A larger but invalid",
            input_a           => 1050,
            input_b           => 1000,
            expected_response => '1',
            expected_valid    => '0',
            expected_delta    => 50
        );

        -- Test 4: B is larger, but difference is below margin
        test_comparator(
            test_name         => "Test 4: B larger but invalid",
            input_a           => 1000,
            input_b           => 1050,
            expected_response => '0',
            expected_valid    => '0',
            expected_delta    => 50
        );

        -- Test 5: Counts are equal
        test_comparator(
            test_name         => "Test 5: Equal counters",
            input_a           => 1000,
            input_b           => 1000,
            expected_response => '0',
            expected_valid    => '0',
            expected_delta    => 0
        );

        -- Test 6: Difference is 99, just below the margin
        test_comparator(
            test_name         => "Test 6: Just below margin",
            input_a           => 1099,
            input_b           => 1000,
            expected_response => '1',
            expected_valid    => '0',
            expected_delta    => 99
        );

        -- Test 7: Difference is exactly 100
        -- Your comparator uses difference < MARGIN,
        -- so exactly 100 should be valid.
        test_comparator(
            test_name         => "Test 7: Exactly at margin",
            input_a           => 1100,
            input_b           => 1000,
            expected_response => '1',
            expected_valid    => '1',
            expected_delta    => 100
        );

        -- Test 8: Difference is just above the margin
        test_comparator(
            test_name         => "Test 8: Just above margin",
            input_a           => 1101,
            input_b           => 1000,
            expected_response => '1',
            expected_valid    => '1',
            expected_delta    => 101
        );

        -- Test 9: Zero compared with a large value
        test_comparator(
            test_name         => "Test 9: Zero and large count",
            input_a           => 0,
            input_b           => 5000,
            expected_response => '0',
            expected_valid    => '1',
            expected_delta    => 5000
        );

        -- Test 10: Maximum 24-bit counter value
        test_comparator(
            test_name         => "Test 10: Maximum count",
            input_a           => 16777215,
            input_b           => 0,
            expected_response => '1',
            expected_valid    => '1',
            expected_delta    => 16777215
        );

        report "All comparator tests completed successfully"
            severity note;

        wait;

    end process;

end Behavioral;
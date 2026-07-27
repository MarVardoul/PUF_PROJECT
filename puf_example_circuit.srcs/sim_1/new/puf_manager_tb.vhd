library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity puf_manager_tb is
end puf_manager_tb;

architecture Behavioral of puf_manager_tb is

    signal CLK          : STD_LOGIC := '0';
    signal RST          : STD_LOGIC := '1';

    signal START        : STD_LOGIC := '0';
    signal SEL_A_IN     : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal SEL_B_IN     : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

    signal PUF_DONE     : STD_LOGIC := '0';
    signal PUF_COUNT_A  : STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
    signal PUF_COUNT_B  : STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
    signal PUF_DELTA    : STD_LOGIC_VECTOR(24 downto 0) := (others => '0');
    signal PUF_RESPONSE : STD_LOGIC := '0';
    signal PUF_VALID    : STD_LOGIC := '0';

    signal PUF_START    : STD_LOGIC;
    signal SEL_A_PUF    : STD_LOGIC_VECTOR(3 downto 0);
    signal SEL_B_PUF    : STD_LOGIC_VECTOR(3 downto 0);

    signal BUSY         : STD_LOGIC;
    signal DONE         : STD_LOGIC;

    signal COUNT_A_OUT  : STD_LOGIC_VECTOR(23 downto 0);
    signal COUNT_B_OUT  : STD_LOGIC_VECTOR(23 downto 0);
    signal DELTA_OUT    : STD_LOGIC_VECTOR(24 downto 0);
    signal RESPONSE_OUT : STD_LOGIC;
    signal VALID_OUT    : STD_LOGIC;

    signal countdown : integer range 0 to 10 := 0;

begin

    DUT : entity work.puf_manager
        port map (
            CLK          => CLK,
            RST          => RST,

            START        => START,
            SEL_A_IN     => SEL_A_IN,
            SEL_B_IN     => SEL_B_IN,

            PUF_DONE     => PUF_DONE,
            PUF_COUNT_A  => PUF_COUNT_A,
            PUF_COUNT_B  => PUF_COUNT_B,
            PUF_DELTA    => PUF_DELTA,
            PUF_RESPONSE => PUF_RESPONSE,
            PUF_VALID    => PUF_VALID,

            PUF_START    => PUF_START,
            SEL_A_PUF    => SEL_A_PUF,
            SEL_B_PUF    => SEL_B_PUF,

            BUSY         => BUSY,
            DONE         => DONE,

            COUNT_A_OUT  => COUNT_A_OUT,
            COUNT_B_OUT  => COUNT_B_OUT,
            DELTA_OUT    => DELTA_OUT,
            RESPONSE_OUT => RESPONSE_OUT,
            VALID_OUT    => VALID_OUT
        );


    CLK_PROCESS : process
    begin

        while now < 2 us loop

            CLK <= '0';
            wait for 5 ns;

            CLK <= '1';
            wait for 5 ns;

        end loop;

        wait;

    end process;


    PUF_MODEL : process(CLK)

        variable a_count : integer;
        variable b_count : integer;
        variable diff    : integer;

    begin

        if rising_edge(CLK) then

            if RST = '1' then

                countdown    <= 0;
                PUF_DONE     <= '0';
                PUF_COUNT_A  <= (others => '0');
                PUF_COUNT_B  <= (others => '0');
                PUF_DELTA    <= (others => '0');
                PUF_RESPONSE <= '0';
                PUF_VALID    <= '0';

            else

                PUF_DONE <= '0';

                if PUF_START = '1' then

                    countdown <= 4;

                elsif countdown > 0 then

                    if countdown = 1 then

                        a_count := 100000 +
                                   1000 * to_integer(unsigned(SEL_A_PUF));

                        b_count := 100000 +
                                   1000 * to_integer(unsigned(SEL_B_PUF)) +
                                   500;

                        if a_count > b_count then
                            diff := a_count - b_count;
                            PUF_RESPONSE <= '1';
                        else
                            diff := b_count - a_count;
                            PUF_RESPONSE <= '0';
                        end if;

                        PUF_COUNT_A <=
                            std_logic_vector(to_unsigned(a_count, 24));

                        PUF_COUNT_B <=
                            std_logic_vector(to_unsigned(b_count, 24));

                        PUF_DELTA <=
                            std_logic_vector(to_unsigned(diff, 25));

                        if diff >= 100 then
                            PUF_VALID <= '1';
                        else
                            PUF_VALID <= '0';
                        end if;

                        PUF_DONE <= '1';

                        countdown <= 0;

                    else

                        countdown <= countdown - 1;

                    end if;

                end if;

            end if;

        end if;

    end process;


    STIMULUS : process
    begin

        RST <= '1';

        wait for 30 ns;
        wait until rising_edge(CLK);

        RST <= '0';

        wait until rising_edge(CLK);

        SEL_A_IN <= "0000";
        SEL_B_IN <= "0001";

        START <= '1';

        wait until rising_edge(CLK);

        START <= '0';

        wait until BUSY = '1';

        SEL_A_IN <= "0111";
        SEL_B_IN <= "0111";

        wait for 20 ns;

        assert SEL_A_PUF = "0000"
            report "SEL_A was not latched correctly"
            severity error;

        assert SEL_B_PUF = "0001"
            report "SEL_B was not latched correctly"
            severity error;

        wait until DONE = '1';

        wait for 1 ns;

        assert to_integer(unsigned(COUNT_A_OUT)) = 100000
            report "Incorrect COUNT_A for first measurement"
            severity error;

        assert to_integer(unsigned(COUNT_B_OUT)) = 101500
            report "Incorrect COUNT_B for first measurement"
            severity error;

        assert to_integer(unsigned(DELTA_OUT)) = 1500
            report "Incorrect DELTA for first measurement"
            severity error;

        assert RESPONSE_OUT = '0'
            report "Incorrect RESPONSE for first measurement"
            severity error;

        assert VALID_OUT = '1'
            report "Incorrect VALID for first measurement"
            severity error;


        wait until rising_edge(CLK);

        SEL_A_IN <= "0101";
        SEL_B_IN <= "0010";

        START <= '1';

        wait until rising_edge(CLK);

        START <= '0';

        wait until DONE = '1';

        wait for 1 ns;

        assert to_integer(unsigned(COUNT_A_OUT)) = 105000
            report "Incorrect COUNT_A for second measurement"
            severity error;

        assert to_integer(unsigned(COUNT_B_OUT)) = 102500
            report "Incorrect COUNT_B for second measurement"
            severity error;

        assert to_integer(unsigned(DELTA_OUT)) = 2500
            report "Incorrect DELTA for second measurement"
            severity error;

        assert RESPONSE_OUT = '1'
            report "Incorrect RESPONSE for second measurement"
            severity error;

        assert VALID_OUT = '1'
            report "Incorrect VALID for second measurement"
            severity error;

        report "PUF manager test completed successfully"
            severity note;

        wait;

    end process;

end Behavioral;
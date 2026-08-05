library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity puf_manager is
    Port (
        CLK          : in  STD_LOGIC;
        RST          : in  STD_LOGIC;
        START        : in  STD_LOGIC;

        SEL_A_IN     : in  STD_LOGIC_VECTOR(3 downto 0);
        SEL_B_IN     : in  STD_LOGIC_VECTOR(3 downto 0);

        PUF_DONE     : in  STD_LOGIC;
        PUF_COUNT_A  : in  STD_LOGIC_VECTOR(23 downto 0);
        PUF_COUNT_B  : in  STD_LOGIC_VECTOR(23 downto 0);
        PUF_DELTA    : in  STD_LOGIC_VECTOR(24 downto 0);
        PUF_RESPONSE : in  STD_LOGIC;
        PUF_VALID    : in  STD_LOGIC;

        BUSY         : out STD_LOGIC;
        DONE         : out STD_LOGIC;

        SEL_A_PUF    : out STD_LOGIC_VECTOR(3 downto 0);
        SEL_B_PUF    : out STD_LOGIC_VECTOR(3 downto 0);
        PUF_START    : out STD_LOGIC;

        COUNT_A_OUT  : out STD_LOGIC_VECTOR(23 downto 0);
        COUNT_B_OUT  : out STD_LOGIC_VECTOR(23 downto 0);
        DELTA_OUT    : out STD_LOGIC_VECTOR(24 downto 0);
        RESPONSE_OUT : out STD_LOGIC;
        VALID_OUT    : out STD_LOGIC
    );
end puf_manager;

architecture Behavioral of puf_manager is

    type state_type is (
        IDLE,
        START_PUF_STATE,
        WAIT_PUF,
        CAPTURE_RESULT,
        WAIT_START_LOW
    );

    signal state : state_type := IDLE;

    signal sel_a_reg : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal sel_b_reg : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

    signal count_a_reg  : STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
    signal count_b_reg  : STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
    signal delta_reg    : STD_LOGIC_VECTOR(24 downto 0) := (others => '0');
    signal response_reg : STD_LOGIC := '0';
    signal valid_reg    : STD_LOGIC := '0';

    signal puf_start_reg : STD_LOGIC := '0';
    signal busy_reg      : STD_LOGIC := '0';
    signal done_reg      : STD_LOGIC := '0';
    
    attribute MARK_DEBUG : string;

attribute MARK_DEBUG of count_a_reg  : signal is "TRUE";
attribute MARK_DEBUG of count_b_reg  : signal is "TRUE";
attribute MARK_DEBUG of delta_reg    : signal is "TRUE";
attribute MARK_DEBUG of response_reg : signal is "TRUE";
attribute MARK_DEBUG of valid_reg    : signal is "TRUE";
attribute MARK_DEBUG of done_reg     : signal is "TRUE";
attribute MARK_DEBUG of busy_reg     : signal is "TRUE";

begin

    SEL_A_PUF <= sel_a_reg;
    SEL_B_PUF <= sel_b_reg;

    PUF_START <= puf_start_reg;

    BUSY <= busy_reg;
    DONE <= done_reg;

    COUNT_A_OUT  <= count_a_reg;
    COUNT_B_OUT  <= count_b_reg;
    DELTA_OUT    <= delta_reg;
    RESPONSE_OUT <= response_reg;
    VALID_OUT    <= valid_reg;

    process(CLK)
    begin

        if rising_edge(CLK) then

            if RST = '1' then

                state <= IDLE;

                sel_a_reg <= (others => '0');
                sel_b_reg <= (others => '0');

                count_a_reg  <= (others => '0');
                count_b_reg  <= (others => '0');
                delta_reg    <= (others => '0');
                response_reg <= '0';
                valid_reg    <= '0';

                puf_start_reg <= '0';
                busy_reg      <= '0';
                done_reg      <= '0';

            else

                puf_start_reg <= '0';
                done_reg      <= '0';

                case state is

                    when IDLE =>

                        busy_reg <= '0';

                        if START = '1' then

                            sel_a_reg <= SEL_A_IN;
                            sel_b_reg <= SEL_B_IN;

                            busy_reg <= '1';

                            state <= START_PUF_STATE;

                        end if;


                    when START_PUF_STATE =>

                        busy_reg <= '1';

                        puf_start_reg <= '1';

                        state <= WAIT_PUF;


                    when WAIT_PUF =>

                        busy_reg <= '1';

                        if PUF_DONE = '1' then

                            state <= CAPTURE_RESULT;

                        end if;


                    when CAPTURE_RESULT =>

                        count_a_reg  <= PUF_COUNT_A;
                        count_b_reg  <= PUF_COUNT_B;
                        delta_reg    <= PUF_DELTA;
                        response_reg <= PUF_RESPONSE;
                        valid_reg    <= PUF_VALID;

                        busy_reg <= '0';
                        done_reg <= '1';

                        state <= WAIT_START_LOW;


                    when WAIT_START_LOW =>

                        busy_reg <= '0';

                        if START = '0' then

                            state <= IDLE;

                        end if;


                    when others =>

                        state <= IDLE;

                        busy_reg      <= '0';
                        puf_start_reg <= '0';
                        done_reg      <= '0';

                end case;

            end if;

        end if;

    end process;

end Behavioral;
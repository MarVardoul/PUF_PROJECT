library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ro_puf_top is
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
        SEL_A      : in  STD_LOGIC_VECTOR(3 downto 0);
        SEL_B      : in  STD_LOGIC_VECTOR(3 downto 0);
        RESPONSE   : out STD_LOGIC;
        VALID      : out STD_LOGIC;
        PAIR_VALID : out STD_LOGIC;
        DELTA      : out STD_LOGIC_VECTOR(24 downto 0);
        COUNT_A    : out STD_LOGIC_VECTOR(23 downto 0);
        COUNT_B    : out STD_LOGIC_VECTOR(23 downto 0);
        BUSY       : out STD_LOGIC;
        DONE       : out STD_LOGIC
    );
end ro_puf_top;

architecture Structural of ro_puf_top is

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

    component ro_puf_core is
        Port (
            SEL_A      : in  STD_LOGIC_VECTOR(3 downto 0);
            SEL_B      : in  STD_LOGIC_VECTOR(3 downto 0);
            ENABLE     : in  STD_LOGIC;
            CNT_EN     : in  STD_LOGIC;
            CNT_RST    : in  STD_LOGIC;
            RESPONSE   : out STD_LOGIC;
            VALID      : out STD_LOGIC;
            PAIR_VALID : out STD_LOGIC;
            DELTA      : out STD_LOGIC_VECTOR(24 downto 0);
            COUNT_A    : out STD_LOGIC_VECTOR(23 downto 0);
            COUNT_B    : out STD_LOGIC_VECTOR(23 downto 0)
        );
    end component;

    signal ro_enable_internal  : STD_LOGIC;
    signal cnt_en_internal     : STD_LOGIC;
    signal cnt_rst_internal    : STD_LOGIC;
    signal capture_internal    : STD_LOGIC;

    signal response_internal   : STD_LOGIC;
    signal valid_internal      : STD_LOGIC;
    signal pair_valid_internal : STD_LOGIC;
    signal delta_internal      : STD_LOGIC_VECTOR(24 downto 0);
    signal count_a_internal    : STD_LOGIC_VECTOR(23 downto 0);
    signal count_b_internal    : STD_LOGIC_VECTOR(23 downto 0);

    signal response_reg : STD_LOGIC := '0';
    signal valid_reg    : STD_LOGIC := '0';
    signal delta_reg    : STD_LOGIC_VECTOR(24 downto 0) := (others => '0');
    signal count_a_reg  : STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
    signal count_b_reg  : STD_LOGIC_VECTOR(23 downto 0) := (others => '0');

begin

    CONTROLLER_COMP : puf_controller
        generic map (
            RESET_CYCLES   => RESET_CYCLES,
            SETTLE_CYCLES  => SETTLE_CYCLES,
            MEASURE_CYCLES => MEASURE_CYCLES,
            STOP_CYCLES    => STOP_CYCLES
        )
        port map (
            SYS_CLK    => SYS_CLK,
            RST        => RST,
            START      => START,
            PAIR_VALID => pair_valid_internal,
            RO_ENABLE  => ro_enable_internal,
            CNT_EN     => cnt_en_internal,
            CNT_RST    => cnt_rst_internal,
            CAPTURE    => capture_internal,
            BUSY       => BUSY,
            DONE       => DONE
        );

    CORE_COMP : ro_puf_core
        port map (
            SEL_A      => SEL_A,
            SEL_B      => SEL_B,
            ENABLE     => ro_enable_internal,
            CNT_EN     => cnt_en_internal,
            CNT_RST    => cnt_rst_internal,
            RESPONSE   => response_internal,
            VALID      => valid_internal,
            PAIR_VALID => pair_valid_internal,
            DELTA      => delta_internal,
            COUNT_A    => count_a_internal,
            COUNT_B    => count_b_internal
        );

    result_register : process(SYS_CLK, RST)
    begin
        if RST = '1' then
            response_reg <= '0';
            valid_reg    <= '0';
            delta_reg    <= (others => '0');
            count_a_reg  <= (others => '0');
            count_b_reg  <= (others => '0');

        elsif rising_edge(SYS_CLK) then
            if capture_internal = '1' then
                response_reg <= response_internal;
                valid_reg    <= valid_internal;
                delta_reg    <= delta_internal;
                count_a_reg  <= count_a_internal;
                count_b_reg  <= count_b_internal;
            end if;
        end if;
    end process;

    RESPONSE   <= response_reg;
    VALID      <= valid_reg;
    DELTA      <= delta_reg;
    COUNT_A    <= count_a_reg;
    COUNT_B    <= count_b_reg;
    PAIR_VALID <= pair_valid_internal;

end Structural;
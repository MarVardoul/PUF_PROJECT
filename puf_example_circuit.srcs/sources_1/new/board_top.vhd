library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity ro_puf_board_top is
    Port (
        SYS_CLK_P   : in  STD_LOGIC;
        SYS_CLK_N   : in  STD_LOGIC;
        PL_USER_SW  : in  STD_LOGIC_VECTOR(7 downto 0);
        PL_USER_PB  : in  STD_LOGIC_VECTOR(1 downto 0);
        PL_USER_LED : out STD_LOGIC_VECTOR(4 downto 0)
    );
end ro_puf_board_top;

architecture Structural of ro_puf_board_top is

    component ro_puf_top is
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
    end component;

    component puf_manager is
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

            PUF_START    : out STD_LOGIC;
            SEL_A_PUF    : out STD_LOGIC_VECTOR(3 downto 0);
            SEL_B_PUF    : out STD_LOGIC_VECTOR(3 downto 0);

            BUSY         : out STD_LOGIC;
            DONE         : out STD_LOGIC;

            COUNT_A_OUT  : out STD_LOGIC_VECTOR(23 downto 0);
            COUNT_B_OUT  : out STD_LOGIC_VECTOR(23 downto 0);
            DELTA_OUT    : out STD_LOGIC_VECTOR(24 downto 0);
            RESPONSE_OUT : out STD_LOGIC;
            VALID_OUT    : out STD_LOGIC
        );
    end component;

    signal sys_clk_internal : STD_LOGIC;

    signal puf_start_internal : STD_LOGIC;
    signal sel_a_puf_internal : STD_LOGIC_VECTOR(3 downto 0);
    signal sel_b_puf_internal : STD_LOGIC_VECTOR(3 downto 0);

    signal puf_response_internal   : STD_LOGIC;
    signal puf_valid_internal      : STD_LOGIC;
    signal pair_valid_internal     : STD_LOGIC;
    signal puf_busy_internal       : STD_LOGIC;
    signal puf_done_internal       : STD_LOGIC;
    signal puf_delta_internal      : STD_LOGIC_VECTOR(24 downto 0);
    signal puf_count_a_internal    : STD_LOGIC_VECTOR(23 downto 0);
    signal puf_count_b_internal    : STD_LOGIC_VECTOR(23 downto 0);

    signal manager_response_internal : STD_LOGIC;
    signal manager_valid_internal    : STD_LOGIC;
    signal manager_busy_internal     : STD_LOGIC;
    signal manager_done_internal     : STD_LOGIC;
    signal manager_delta_internal    : STD_LOGIC_VECTOR(24 downto 0);
    signal manager_count_a_internal  : STD_LOGIC_VECTOR(23 downto 0);
    signal manager_count_b_internal  : STD_LOGIC_VECTOR(23 downto 0);

begin

    CLK_BUFFER : IBUFDS
        port map (
            I  => SYS_CLK_P,
            IB => SYS_CLK_N,
            O  => sys_clk_internal
        );

    MANAGER_COMP : puf_manager
        port map (
            CLK          => sys_clk_internal,
            RST          => PL_USER_PB(0),

            START        => PL_USER_PB(1),
            SEL_A_IN     => PL_USER_SW(3 downto 0),
            SEL_B_IN     => PL_USER_SW(7 downto 4),

            PUF_DONE     => puf_done_internal,
            PUF_COUNT_A  => puf_count_a_internal,
            PUF_COUNT_B  => puf_count_b_internal,
            PUF_DELTA    => puf_delta_internal,
            PUF_RESPONSE => puf_response_internal,
            PUF_VALID    => puf_valid_internal,

            PUF_START    => puf_start_internal,
            SEL_A_PUF    => sel_a_puf_internal,
            SEL_B_PUF    => sel_b_puf_internal,

            BUSY         => manager_busy_internal,
            DONE         => manager_done_internal,

            COUNT_A_OUT  => manager_count_a_internal,
            COUNT_B_OUT  => manager_count_b_internal,
            DELTA_OUT    => manager_delta_internal,
            RESPONSE_OUT => manager_response_internal,
            VALID_OUT    => manager_valid_internal
        );

    PUF_COMP : ro_puf_top
        port map (
            SYS_CLK    => sys_clk_internal,
            RST        => PL_USER_PB(0),
            START      => puf_start_internal,
            SEL_A      => sel_a_puf_internal,
            SEL_B      => sel_b_puf_internal,
            RESPONSE   => puf_response_internal,
            VALID      => puf_valid_internal,
            PAIR_VALID => pair_valid_internal,
            DELTA      => puf_delta_internal,
            COUNT_A    => puf_count_a_internal,
            COUNT_B    => puf_count_b_internal,
            BUSY       => puf_busy_internal,
            DONE       => puf_done_internal
        );

    PL_USER_LED(0) <= manager_response_internal;
    PL_USER_LED(1) <= manager_valid_internal;
    PL_USER_LED(2) <= pair_valid_internal;
    PL_USER_LED(3) <= manager_busy_internal;
    PL_USER_LED(4) <= manager_done_internal;

end Structural;
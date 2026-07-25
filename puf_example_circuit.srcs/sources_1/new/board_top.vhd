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
            BUSY       : out STD_LOGIC;
            DONE       : out STD_LOGIC
        );
    end component;

    signal sys_clk_internal   : STD_LOGIC;
    signal response_internal  : STD_LOGIC;
    signal valid_internal     : STD_LOGIC;
    signal pair_valid_internal : STD_LOGIC;
    signal busy_internal      : STD_LOGIC;
    signal done_internal      : STD_LOGIC;
    signal delta_internal     : STD_LOGIC_VECTOR(24 downto 0);

begin

    CLK_BUFFER : IBUFDS
        port map (
            I  => SYS_CLK_P,
            IB => SYS_CLK_N,
            O  => sys_clk_internal
        );

    PUF_COMP : ro_puf_top
        port map (
            SYS_CLK    => sys_clk_internal,
            RST        => PL_USER_PB(0),
            START      => PL_USER_PB(1),
            SEL_A      => PL_USER_SW(3 downto 0),
            SEL_B      => PL_USER_SW(7 downto 4),
            RESPONSE   => response_internal,
            VALID      => valid_internal,
            PAIR_VALID => pair_valid_internal,
            DELTA      => delta_internal,
            BUSY       => busy_internal,
            DONE       => done_internal
        );

    PL_USER_LED(0) <= response_internal;
    PL_USER_LED(1) <= valid_internal;
    PL_USER_LED(2) <= pair_valid_internal;
    PL_USER_LED(3) <= busy_internal;
    PL_USER_LED(4) <= done_internal;

end Structural;
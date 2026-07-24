library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ro_puf_core is
    Port (
        SEL_A      : in  STD_LOGIC_VECTOR(3 downto 0);
        SEL_B      : in  STD_LOGIC_VECTOR(3 downto 0);
        ENABLE     : in  STD_LOGIC;
        CNT_EN     : in  STD_LOGIC;
        CNT_RST    : in  STD_LOGIC;
        RESPONSE   : out STD_LOGIC;
        VALID      : out STD_LOGIC;
        PAIR_VALID : out STD_LOGIC;
        DELTA      : out STD_LOGIC_VECTOR(24 downto 0)
    );
end ro_puf_core;

architecture Structural of ro_puf_core is

    component ro_pair_decoder is
        Port (
            SEL_A      : in  STD_LOGIC_VECTOR(3 downto 0);
            SEL_B      : in  STD_LOGIC_VECTOR(3 downto 0);
            ENABLE     : in  STD_LOGIC;
            RO_EN      : out STD_LOGIC_VECTOR(15 downto 0);
            PAIR_VALID : out STD_LOGIC
        );
    end component;

    component ro_bank is
        generic (
            NUM_ROS       : positive := 16;
            COUNTER_WIDTH : positive := 24
        );
        Port (
            RO_EN     : in  STD_LOGIC_VECTOR(NUM_ROS-1 downto 0);
            CNT_EN    : in  STD_LOGIC;
            CNT_RST   : in  STD_LOGIC;
            COUNT_OUT : out STD_LOGIC_VECTOR(
                NUM_ROS * COUNTER_WIDTH - 1 downto 0
            );
            OSC_OUT   : out STD_LOGIC_VECTOR(NUM_ROS-1 downto 0)
        );
    end component;

    component count_selector is
        Port (
            count_bank     : in  STD_LOGIC_VECTOR(383 downto 0);
            SEL            : in  STD_LOGIC_VECTOR(3 downto 0);
            SELECTED_COUNT : out STD_LOGIC_VECTOR(23 downto 0)
        );
    end component;

    component comparator is
        Port (
            COUNT_A  : in  STD_LOGIC_VECTOR(23 downto 0);
            COUNT_B  : in  STD_LOGIC_VECTOR(23 downto 0);
            RESPONSE : out STD_LOGIC;
            VALID    : out STD_LOGIC;
            DELTA    : out STD_LOGIC_VECTOR(24 downto 0)
        );
    end component;

    signal ro_en_internal            : STD_LOGIC_VECTOR(15 downto 0);
    signal count_bank_internal       : STD_LOGIC_VECTOR(383 downto 0);
    signal osc_out_internal          : STD_LOGIC_VECTOR(15 downto 0);
    signal count_a_internal          : STD_LOGIC_VECTOR(23 downto 0);
    signal count_b_internal          : STD_LOGIC_VECTOR(23 downto 0);
    signal pair_valid_internal       : STD_LOGIC;
    signal comparator_valid_internal : STD_LOGIC;

begin

    DECODER_COMP : ro_pair_decoder
        port map (
            SEL_A      => SEL_A,
            SEL_B      => SEL_B,
            ENABLE     => ENABLE,
            RO_EN      => ro_en_internal,
            PAIR_VALID => pair_valid_internal
        );

    BANK_COMP : ro_bank
        generic map (
            NUM_ROS       => 16,
            COUNTER_WIDTH => 24
        )
        port map (
            RO_EN     => ro_en_internal,
            CNT_EN    => CNT_EN,
            CNT_RST   => CNT_RST,
            COUNT_OUT => count_bank_internal,
            OSC_OUT   => osc_out_internal
        );

    SELECTOR_A_COMP : count_selector
        port map (
            count_bank     => count_bank_internal,
            SEL            => SEL_A,
            SELECTED_COUNT => count_a_internal
        );

    SELECTOR_B_COMP : count_selector
        port map (
            count_bank     => count_bank_internal,
            SEL            => SEL_B,
            SELECTED_COUNT => count_b_internal
        );

    COMPARATOR_COMP : comparator
        port map (
            COUNT_A  => count_a_internal,
            COUNT_B  => count_b_internal,
            RESPONSE => RESPONSE,
            VALID    => comparator_valid_internal,
            DELTA    => DELTA
        );

    PAIR_VALID <= pair_valid_internal;
    VALID      <= comparator_valid_internal and pair_valid_internal;

end Structural;
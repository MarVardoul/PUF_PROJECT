library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.parameters.all;


entity ro_puf_board_top is
    port (
        SYS_CLK_P   : in  std_logic;
        SYS_CLK_N   : in  std_logic;
        PL_USER_SW  : in  std_logic_vector(7 downto 0);
        PL_USER_PB  : in  std_logic_vector(1 downto 0);
        PL_USER_LED : out std_logic_vector(4 downto 0)
    );
end entity ro_puf_board_top;


architecture Structural of ro_puf_board_top is

    --adding vio
    component vio_1 is
        port (
            clk        : in  std_logic;
            probe_out0 : out std_logic_vector(0 downto 0)
        );
    end component;


    component puf_signature_generator is
        port (
            CLK   : in std_logic;
            RST   : in std_logic;
            START : in std_logic;

            MANAGER_DONE     : in std_logic;
            MANAGER_RESPONSE : in std_logic;
            MANAGER_VALID    : in std_logic;

            MANAGER_START : out std_logic;
            SEL_A         : out std_logic_vector(3 downto 0);
            SEL_B         : out std_logic_vector(3 downto 0);

            SIGNATURE  : out std_logic_vector(119 downto 0);
            VALID_MASK : out std_logic_vector(119 downto 0);

            BUSY            : out std_logic;
            DONE            : out std_logic;
            SIGNATURE_READY : out std_logic
        );
    end component;


    component ro_puf_top is
        generic (
            RESET_CYCLES   : positive := 4;
            SETTLE_CYCLES  : positive := 100;
            MEASURE_CYCLES : positive := 100000;
            STOP_CYCLES    : positive := 4
        );
        port (
            SYS_CLK    : in  std_logic;
            RST        : in  std_logic;
            START      : in  std_logic;
            SEL_A      : in  std_logic_vector(3 downto 0);
            SEL_B      : in  std_logic_vector(3 downto 0);
            RESPONSE   : out std_logic;
            VALID      : out std_logic;
            PAIR_VALID : out std_logic;
            DELTA      : out std_logic_vector(24 downto 0);
            COUNT_A    : out std_logic_vector(23 downto 0);
            COUNT_B    : out std_logic_vector(23 downto 0);
            BUSY       : out std_logic;
            DONE       : out std_logic
        );
    end component;


    component puf_manager is
        port (
            CLK : in std_logic;
            RST : in std_logic;

            START    : in std_logic;
            SEL_A_IN : in std_logic_vector(3 downto 0);
            SEL_B_IN : in std_logic_vector(3 downto 0);

            PUF_DONE     : in std_logic;
            PUF_COUNT_A  : in std_logic_vector(23 downto 0);
            PUF_COUNT_B  : in std_logic_vector(23 downto 0);
            PUF_DELTA    : in std_logic_vector(24 downto 0);
            PUF_RESPONSE : in std_logic;
            PUF_VALID    : in std_logic;

            PUF_START : out std_logic;
            SEL_A_PUF : out std_logic_vector(3 downto 0);
            SEL_B_PUF : out std_logic_vector(3 downto 0);

            BUSY : out std_logic;
            DONE : out std_logic;

            COUNT_A_OUT  : out std_logic_vector(23 downto 0);
            COUNT_B_OUT  : out std_logic_vector(23 downto 0);
            DELTA_OUT    : out std_logic_vector(24 downto 0);
            RESPONSE_OUT : out std_logic;
            VALID_OUT    : out std_logic
        );
    end component;


    type integration_state_type is (
        WAIT_FOR_SIGNATURE,
        START_ECC,
        WAIT_FOR_ECC
    );


    constant C_HELPER_DATA :
        t_helper_data :=
        x"D465D685CB52F081E2543530F1DDFC";


    signal sys_clk_internal :
        std_logic;


    signal puf_start_internal :
        std_logic;

    signal sel_a_puf_internal :
        std_logic_vector(3 downto 0);

    signal sel_b_puf_internal :
        std_logic_vector(3 downto 0);

    signal puf_response_internal :
        std_logic;

    signal puf_valid_internal :
        std_logic;

    signal pair_valid_internal :
        std_logic;

    signal puf_busy_internal :
        std_logic;

    signal puf_done_internal :
        std_logic;

    signal puf_delta_internal :
        std_logic_vector(24 downto 0);

    signal puf_count_a_internal :
        std_logic_vector(23 downto 0);

    signal puf_count_b_internal :
        std_logic_vector(23 downto 0);


    signal manager_response_internal :
        std_logic;

    signal manager_valid_internal :
        std_logic;

    signal manager_busy_internal :
        std_logic;

    signal manager_done_internal :
        std_logic;

    signal manager_delta_internal :
        std_logic_vector(24 downto 0);

    signal manager_count_a_internal :
        std_logic_vector(23 downto 0);

    signal manager_count_b_internal :
        std_logic_vector(23 downto 0);


    signal signature_manager_start :
        std_logic;

    signal signature_sel_a :
        std_logic_vector(3 downto 0);

    signal signature_sel_b :
        std_logic_vector(3 downto 0);

    signal signature_internal :
        std_logic_vector(119 downto 0);

    signal signature_valid_mask :
        std_logic_vector(119 downto 0);

    signal signature_busy_internal :
        std_logic;

    signal signature_done_internal :
        std_logic;

    signal signature_ready_internal :
        std_logic;


    --vio signal
    signal vio_start :
        std_logic_vector(0 downto 0);

    signal signature_start_request :
        std_logic;

    signal signature_start_internal :
        std_logic;


    signal integration_state :
        integration_state_type := WAIT_FOR_SIGNATURE;

    signal puf_response_latched :
        t_puf_response := (others => '0');

    signal ecc_start_internal :
        std_logic := '0';

    signal ecc_busy_internal :
        std_logic := '0';

    signal ecc_done_internal :
        std_logic := '0';

    signal ecc_decoder_success_internal :
        std_logic := '0';

    signal ecc_post_syndromes_zero_internal :
        std_logic := '0';

    signal ecc_success_latched :
        std_logic := '0';


    signal ecc_noisy_codeword_internal :
        t_shortened_codeword := (others => '0');

    signal ecc_corrected_codeword_internal :
        t_shortened_codeword := (others => '0');

    signal ecc_decoded_secret_internal :
        t_secret := (others => '0');


    signal ecc_error_count_internal :
        unsigned(2 downto 0) := (others => '0');

    signal ecc_error_position_0_internal :
        unsigned(6 downto 0) := (others => '0');

    signal ecc_error_position_1_internal :
        unsigned(6 downto 0) := (others => '0');

    signal ecc_error_position_2_internal :
        unsigned(6 downto 0) := (others => '0');


    signal ecc_decoder_state_debug_internal :
        unsigned(3 downto 0) := (others => '0');

    signal ecc_cycle_count_debug_internal :
        unsigned(9 downto 0) := (others => '0');

    signal ecc_chien_position_debug_internal :
        unsigned(6 downto 0) := (others => '0');

    signal ecc_chien_cycle_debug_internal :
        unsigned(7 downto 0) := (others => '0');


    attribute MARK_DEBUG : string;

    attribute MARK_DEBUG of signature_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of signature_valid_mask :
        signal is "TRUE";

    attribute MARK_DEBUG of signature_busy_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of signature_ready_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of puf_response_latched :
        signal is "TRUE";

    attribute MARK_DEBUG of ecc_start_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of ecc_busy_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of ecc_done_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of ecc_decoder_success_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of ecc_post_syndromes_zero_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of ecc_noisy_codeword_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of ecc_corrected_codeword_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of ecc_decoded_secret_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of ecc_error_count_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of ecc_error_position_0_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of ecc_error_position_1_internal :
        signal is "TRUE";

    attribute MARK_DEBUG of ecc_error_position_2_internal :
        signal is "TRUE";


begin

    signature_start_request <=
        PL_USER_PB(1) or vio_start(0);

    signature_start_internal <=
        signature_start_request
        when integration_state = WAIT_FOR_SIGNATURE
        and ecc_busy_internal = '0'
        else '0';


    CLK_BUFFER :
        IBUFDS
        port map (
            I  => SYS_CLK_P,
            IB => SYS_CLK_N,
            O  => sys_clk_internal
        );


    --instantiating vio core
    VIO_START_COMP :
        vio_1
        port map (
            clk        => sys_clk_internal,
            probe_out0 => vio_start
        );


    MANAGER_COMP :
        puf_manager
        port map (
            CLK => sys_clk_internal,
            RST => PL_USER_PB(0),

            START    => signature_manager_start,
            SEL_A_IN => signature_sel_a,
            SEL_B_IN => signature_sel_b,

            PUF_DONE     => puf_done_internal,
            PUF_COUNT_A  => puf_count_a_internal,
            PUF_COUNT_B  => puf_count_b_internal,
            PUF_DELTA    => puf_delta_internal,
            PUF_RESPONSE => puf_response_internal,
            PUF_VALID    => puf_valid_internal,

            PUF_START => puf_start_internal,
            SEL_A_PUF => sel_a_puf_internal,
            SEL_B_PUF => sel_b_puf_internal,

            BUSY => manager_busy_internal,
            DONE => manager_done_internal,

            COUNT_A_OUT  => manager_count_a_internal,
            COUNT_B_OUT  => manager_count_b_internal,
            DELTA_OUT    => manager_delta_internal,
            RESPONSE_OUT => manager_response_internal,
            VALID_OUT    => manager_valid_internal
        );


    SIGNATURE_GEN_COMP :
        puf_signature_generator
        port map (
            CLK => sys_clk_internal,
            RST => PL_USER_PB(0),

            START => signature_start_internal, --for vio

            MANAGER_DONE     => manager_done_internal,
            MANAGER_RESPONSE => manager_response_internal,
            MANAGER_VALID    => manager_valid_internal,

            MANAGER_START => signature_manager_start,
            SEL_A         => signature_sel_a,
            SEL_B         => signature_sel_b,

            SIGNATURE  => signature_internal,
            VALID_MASK => signature_valid_mask,

            BUSY            => signature_busy_internal,
            DONE            => signature_done_internal,
            SIGNATURE_READY => signature_ready_internal
        );


    PUF_COMP :
        ro_puf_top
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


    ECC_COMP :
        entity work.puf_ecc_reconstruction
        port map (
            clk   => sys_clk_internal,
            rst   => PL_USER_PB(0),
            start => ecc_start_internal,

            puf_response =>
                puf_response_latched,

            helper_data =>
                C_HELPER_DATA,

            noisy_codeword =>
                ecc_noisy_codeword_internal,

            corrected_codeword =>
                ecc_corrected_codeword_internal,

            decoded_secret =>
                ecc_decoded_secret_internal,

            busy =>
                ecc_busy_internal,

            done =>
                ecc_done_internal,

            decoder_success =>
                ecc_decoder_success_internal,

            post_syndromes_zero =>
                ecc_post_syndromes_zero_internal,

            error_count =>
                ecc_error_count_internal,

            error_position_0 =>
                ecc_error_position_0_internal,

            error_position_1 =>
                ecc_error_position_1_internal,

            error_position_2 =>
                ecc_error_position_2_internal,

            decoder_state_debug =>
                ecc_decoder_state_debug_internal,

            cycle_count_debug =>
                ecc_cycle_count_debug_internal,

            chien_position_debug =>
                ecc_chien_position_debug_internal,

            chien_cycle_debug =>
                ecc_chien_cycle_debug_internal
        );


    INTEGRATION_CONTROLLER :
        process (sys_clk_internal)
        begin
            if rising_edge(sys_clk_internal) then

                if PL_USER_PB(0) = '1' then

                    integration_state <=
                        WAIT_FOR_SIGNATURE;

                    puf_response_latched <=
                        (others => '0');

                    ecc_start_internal <=
                        '0';

                    ecc_success_latched <=
                        '0';

                else

                    ecc_start_internal <=
                        '0';

                    case integration_state is

                        when WAIT_FOR_SIGNATURE =>

                            if signature_done_internal = '1' then

                                puf_response_latched <=
                                    signature_internal;

                                ecc_success_latched <=
                                    '0';

                                integration_state <=
                                    START_ECC;

                            end if;


                        when START_ECC =>

                            if ecc_busy_internal = '0' then

                                ecc_start_internal <=
                                    '1';

                                integration_state <=
                                    WAIT_FOR_ECC;

                            end if;


                        when WAIT_FOR_ECC =>

                            if ecc_done_internal = '1' then

                                ecc_success_latched <=
                                    ecc_decoder_success_internal
                                    and
                                    ecc_post_syndromes_zero_internal;

                                integration_state <=
                                    WAIT_FOR_SIGNATURE;

                            end if;


                        when others =>

                            integration_state <=
                                WAIT_FOR_SIGNATURE;

                    end case;

                end if;

            end if;
        end process;


    PL_USER_LED(0) <=
        manager_response_internal;

    PL_USER_LED(1) <=
        manager_valid_internal;

    PL_USER_LED(2) <=
        pair_valid_internal;

    PL_USER_LED(3) <=
        signature_busy_internal;

    PL_USER_LED(4) <=
        ecc_success_latched;

end architecture Structural;
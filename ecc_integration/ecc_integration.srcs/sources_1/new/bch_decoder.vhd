library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.parameters.all;
use work.gf128_pkg.all;

entity bch_decoder is
    port (
        clk : in std_logic;
        rst : in std_logic;

        start : in std_logic;

        received_codeword : in t_shortened_codeword;

        corrected_codeword : out t_shortened_codeword;
        decoded_secret     : out t_secret;

        busy : out std_logic;
        done : out std_logic;

        decoder_success     : out std_logic;
        post_syndromes_zero : out std_logic;

        error_count : out unsigned(2 downto 0);

        error_position_0 : out unsigned(6 downto 0);
        error_position_1 : out unsigned(6 downto 0);
        error_position_2 : out unsigned(6 downto 0);
        error_position_3 : out unsigned(6 downto 0);
        error_position_4 : out unsigned(6 downto 0);
        error_position_5 : out unsigned(6 downto 0);
        error_position_6 : out unsigned(6 downto 0);

        decoder_state_debug : out unsigned(3 downto 0);
        cycle_count_debug   : out unsigned(9 downto 0);

        chien_position_debug : out unsigned(6 downto 0);
        chien_cycle_debug    : out unsigned(7 downto 0)
    );
end entity bch_decoder;


architecture rtl of bch_decoder is

    type t_decoder_state is (
        IDLE,
        LAUNCH_PRE_SYNDROME,
        WAIT_PRE_SYNDROME,
        LAUNCH_LOCATOR,
        WAIT_LOCATOR,
        LAUNCH_CHIEN,
        WAIT_CHIEN,
        LAUNCH_CORRECTOR,
        WAIT_CORRECTOR,
        LAUNCH_POST_SYNDROME,
        WAIT_POST_SYNDROME
    );

    signal state_reg : t_decoder_state := IDLE;

    signal received_codeword_reg :
        t_shortened_codeword := (others => '0');

    signal syndrome_start_reg : std_logic := '0';

    signal syndrome_codeword_reg :
        t_shortened_codeword := (others => '0');

    signal syndrome_busy_int : std_logic;
    signal syndrome_done_int : std_logic;

    signal syndrome_1_int  : t_gf128;
    signal syndrome_2_int  : t_gf128;
    signal syndrome_3_int  : t_gf128;
    signal syndrome_4_int  : t_gf128;
    signal syndrome_5_int  : t_gf128;
    signal syndrome_6_int  : t_gf128;
    signal syndrome_7_int  : t_gf128;
    signal syndrome_8_int  : t_gf128;
    signal syndrome_9_int  : t_gf128;
    signal syndrome_10_int : t_gf128;
    signal syndrome_11_int : t_gf128;
    signal syndrome_12_int : t_gf128;
    signal syndrome_13_int : t_gf128;
    signal syndrome_14_int : t_gf128;

    signal syndromes_zero_int : std_logic;

    signal locator_start_reg : std_logic := '0';

    signal locator_busy_int : std_logic;
    signal locator_done_int : std_logic;

    signal locator_0_int : t_gf128;
    signal locator_1_int : t_gf128;
    signal locator_2_int : t_gf128;
    signal locator_3_int : t_gf128;
    signal locator_4_int : t_gf128;
    signal locator_5_int : t_gf128;
    signal locator_6_int : t_gf128;
    signal locator_7_int : t_gf128;

    signal locator_degree_int :
        unsigned(3 downto 0);

    signal locator_valid_int :
        std_logic;

    signal chien_start_reg : std_logic := '0';

    signal chien_busy_int : std_logic;
    signal chien_done_int : std_logic;

    signal chien_error_position_0_int :
        unsigned(6 downto 0);

    signal chien_error_position_1_int :
        unsigned(6 downto 0);

    signal chien_error_position_2_int :
        unsigned(6 downto 0);

    signal chien_error_position_3_int :
        unsigned(6 downto 0);

    signal chien_error_position_4_int :
        unsigned(6 downto 0);

    signal chien_error_position_5_int :
        unsigned(6 downto 0);

    signal chien_error_position_6_int :
        unsigned(6 downto 0);

    signal chien_error_count_int :
        unsigned(2 downto 0);

    signal chien_root_match_int :
        std_logic;

    signal chien_shortened_error_int :
        std_logic;

    signal chien_search_success_int :
        std_logic;

    signal chien_current_position_int :
        unsigned(6 downto 0);

    signal chien_cycle_count_int :
        unsigned(7 downto 0);

    signal corrector_start_reg : std_logic := '0';

    signal corrector_busy_int : std_logic;
    signal corrector_done_int : std_logic;

    signal corrector_codeword_int :
        t_shortened_codeword;

    signal corrector_secret_int :
        t_secret;

    signal corrector_success_int :
        std_logic;

    signal corrected_codeword_reg :
        t_shortened_codeword := (others => '0');

    signal decoded_secret_reg :
        t_secret := (others => '0');

    signal correction_success_latched_reg :
        std_logic := '0';

    signal post_syndromes_zero_reg :
        std_logic := '0';

    signal decoder_success_reg :
        std_logic := '0';

    signal error_count_reg :
        unsigned(2 downto 0) := (others => '0');

    signal error_position_0_reg :
        unsigned(6 downto 0) := (others => '0');

    signal error_position_1_reg :
        unsigned(6 downto 0) := (others => '0');

    signal error_position_2_reg :
        unsigned(6 downto 0) := (others => '0');

    signal error_position_3_reg :
        unsigned(6 downto 0) := (others => '0');

    signal error_position_4_reg :
        unsigned(6 downto 0) := (others => '0');

    signal error_position_5_reg :
        unsigned(6 downto 0) := (others => '0');

    signal error_position_6_reg :
        unsigned(6 downto 0) := (others => '0');

    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';

    signal cycle_count_reg :
        natural range 0 to 1023 := 0;

begin

    corrected_codeword <= corrected_codeword_reg;
    decoded_secret <= decoded_secret_reg;

    busy <= busy_reg;
    done <= done_reg;

    decoder_success <= decoder_success_reg;
    post_syndromes_zero <= post_syndromes_zero_reg;

    error_count <= error_count_reg;

    error_position_0 <= error_position_0_reg;
    error_position_1 <= error_position_1_reg;
    error_position_2 <= error_position_2_reg;
    error_position_3 <= error_position_3_reg;
    error_position_4 <= error_position_4_reg;
    error_position_5 <= error_position_5_reg;
    error_position_6 <= error_position_6_reg;

    cycle_count_debug <=
        to_unsigned(
            cycle_count_reg,
            cycle_count_debug'length
        );

    chien_position_debug <=
        chien_current_position_int;

    chien_cycle_debug <=
        chien_cycle_count_int;

    with state_reg select
        decoder_state_debug <=
            "0000" when IDLE,
            "0001" when LAUNCH_PRE_SYNDROME,
            "0010" when WAIT_PRE_SYNDROME,
            "0011" when LAUNCH_LOCATOR,
            "0100" when WAIT_LOCATOR,
            "0101" when LAUNCH_CHIEN,
            "0110" when WAIT_CHIEN,
            "0111" when LAUNCH_CORRECTOR,
            "1000" when WAIT_CORRECTOR,
            "1001" when LAUNCH_POST_SYNDROME,
            "1010" when WAIT_POST_SYNDROME;

    u_syndrome_calculator :
        entity work.bch_syndrome_calculator
        port map (
            clk => clk,
            rst => rst,

            start => syndrome_start_reg,

            received_codeword =>
                syndrome_codeword_reg,

            busy => syndrome_busy_int,
            done => syndrome_done_int,

            syndrome_1  => syndrome_1_int,
            syndrome_2  => syndrome_2_int,
            syndrome_3  => syndrome_3_int,
            syndrome_4  => syndrome_4_int,
            syndrome_5  => syndrome_5_int,
            syndrome_6  => syndrome_6_int,
            syndrome_7  => syndrome_7_int,
            syndrome_8  => syndrome_8_int,
            syndrome_9  => syndrome_9_int,
            syndrome_10 => syndrome_10_int,
            syndrome_11 => syndrome_11_int,
            syndrome_12 => syndrome_12_int,
            syndrome_13 => syndrome_13_int,
            syndrome_14 => syndrome_14_int,

            syndromes_zero =>
                syndromes_zero_int
        );

    u_error_locator :
        entity work.bch_error_locator
        port map (
            clk => clk,
            rst => rst,

            start => locator_start_reg,

            syndrome_1  => syndrome_1_int,
            syndrome_2  => syndrome_2_int,
            syndrome_3  => syndrome_3_int,
            syndrome_4  => syndrome_4_int,
            syndrome_5  => syndrome_5_int,
            syndrome_6  => syndrome_6_int,
            syndrome_7  => syndrome_7_int,
            syndrome_8  => syndrome_8_int,
            syndrome_9  => syndrome_9_int,
            syndrome_10 => syndrome_10_int,
            syndrome_11 => syndrome_11_int,
            syndrome_12 => syndrome_12_int,
            syndrome_13 => syndrome_13_int,
            syndrome_14 => syndrome_14_int,

            busy => locator_busy_int,
            done => locator_done_int,

            locator_0 => locator_0_int,
            locator_1 => locator_1_int,
            locator_2 => locator_2_int,
            locator_3 => locator_3_int,
            locator_4 => locator_4_int,
            locator_5 => locator_5_int,
            locator_6 => locator_6_int,
            locator_7 => locator_7_int,

            locator_degree =>
                locator_degree_int,

            locator_valid =>
                locator_valid_int
        );

    u_chien_search :
        entity work.bch_chien_search
        port map (
            clk => clk,
            rst => rst,

            start => chien_start_reg,

            locator_0 => locator_0_int,
            locator_1 => locator_1_int,
            locator_2 => locator_2_int,
            locator_3 => locator_3_int,
            locator_4 => locator_4_int,
            locator_5 => locator_5_int,
            locator_6 => locator_6_int,
            locator_7 => locator_7_int,

            locator_degree =>
                locator_degree_int,

            busy => chien_busy_int,
            done => chien_done_int,

            error_position_0 =>
                chien_error_position_0_int,

            error_position_1 =>
                chien_error_position_1_int,

            error_position_2 =>
                chien_error_position_2_int,

            error_position_3 =>
                chien_error_position_3_int,

            error_position_4 =>
                chien_error_position_4_int,

            error_position_5 =>
                chien_error_position_5_int,

            error_position_6 =>
                chien_error_position_6_int,

            error_count =>
                chien_error_count_int,

            root_count_matches_degree =>
                chien_root_match_int,

            shortened_position_error =>
                chien_shortened_error_int,

            search_success =>
                chien_search_success_int,

            current_position =>
                chien_current_position_int,

            cycle_count =>
                chien_cycle_count_int
        );

    u_error_corrector :
        entity work.bch_error_corrector
        port map (
            clk => clk,
            rst => rst,

            start => corrector_start_reg,

            received_codeword =>
                received_codeword_reg,

            error_position_0 =>
                chien_error_position_0_int,

            error_position_1 =>
                chien_error_position_1_int,

            error_position_2 =>
                chien_error_position_2_int,

            error_position_3 =>
                chien_error_position_3_int,

            error_position_4 =>
                chien_error_position_4_int,

            error_position_5 =>
                chien_error_position_5_int,

            error_position_6 =>
                chien_error_position_6_int,

            error_count =>
                chien_error_count_int,

            search_success =>
                chien_search_success_int,

            corrected_codeword =>
                corrector_codeword_int,

            decoded_secret =>
                corrector_secret_int,

            busy => corrector_busy_int,
            done => corrector_done_int,

            correction_success =>
                corrector_success_int
        );

    process (clk)
    begin

        if rising_edge(clk) then

            syndrome_start_reg <= '0';
            locator_start_reg <= '0';
            chien_start_reg <= '0';
            corrector_start_reg <= '0';

            done_reg <= '0';

            if rst = '1' then

                state_reg <= IDLE;

                received_codeword_reg <=
                    (others => '0');

                syndrome_codeword_reg <=
                    (others => '0');

                corrected_codeword_reg <=
                    (others => '0');

                decoded_secret_reg <=
                    (others => '0');

                correction_success_latched_reg <=
                    '0';

                post_syndromes_zero_reg <=
                    '0';

                decoder_success_reg <=
                    '0';

                error_count_reg <=
                    (others => '0');

                error_position_0_reg <=
                    (others => '0');

                error_position_1_reg <=
                    (others => '0');

                error_position_2_reg <=
                    (others => '0');

                error_position_3_reg <=
                    (others => '0');

                error_position_4_reg <=
                    (others => '0');

                error_position_5_reg <=
                    (others => '0');

                error_position_6_reg <=
                    (others => '0');

                busy_reg <= '0';
                done_reg <= '0';

                cycle_count_reg <= 0;

            else

                if busy_reg = '1' then

                    if cycle_count_reg < 1023 then
                        cycle_count_reg <=
                            cycle_count_reg + 1;
                    end if;

                end if;

                case state_reg is

                    when IDLE =>

                        busy_reg <= '0';

                        if start = '1' then

                            received_codeword_reg <=
                                received_codeword;

                            corrected_codeword_reg <=
                                (others => '0');

                            decoded_secret_reg <=
                                (others => '0');

                            correction_success_latched_reg <=
                                '0';

                            post_syndromes_zero_reg <=
                                '0';

                            decoder_success_reg <=
                                '0';

                            error_count_reg <=
                                (others => '0');

                            error_position_0_reg <=
                                (others => '0');

                            error_position_1_reg <=
                                (others => '0');

                            error_position_2_reg <=
                                (others => '0');

                            error_position_3_reg <=
                                (others => '0');

                            error_position_4_reg <=
                                (others => '0');

                            error_position_5_reg <=
                                (others => '0');

                            error_position_6_reg <=
                                (others => '0');

                            cycle_count_reg <= 0;
                            busy_reg <= '1';

                            state_reg <=
                                LAUNCH_PRE_SYNDROME;

                        end if;


                    when LAUNCH_PRE_SYNDROME =>

                        syndrome_codeword_reg <=
                            received_codeword_reg;

                        syndrome_start_reg <= '1';

                        state_reg <=
                            WAIT_PRE_SYNDROME;


                    when WAIT_PRE_SYNDROME =>

                        if syndrome_done_int = '1' then

                            state_reg <=
                                LAUNCH_LOCATOR;

                        end if;


                    when LAUNCH_LOCATOR =>

                        locator_start_reg <= '1';

                        state_reg <=
                            WAIT_LOCATOR;


                    when WAIT_LOCATOR =>

                        if locator_done_int = '1' then

                            state_reg <=
                                LAUNCH_CHIEN;

                        end if;


                    when LAUNCH_CHIEN =>

                        chien_start_reg <= '1';

                        state_reg <=
                            WAIT_CHIEN;


                    when WAIT_CHIEN =>

                        if chien_done_int = '1' then

                            error_count_reg <=
                                chien_error_count_int;

                            error_position_0_reg <=
                                chien_error_position_0_int;

                            error_position_1_reg <=
                                chien_error_position_1_int;

                            error_position_2_reg <=
                                chien_error_position_2_int;

                            error_position_3_reg <=
                                chien_error_position_3_int;

                            error_position_4_reg <=
                                chien_error_position_4_int;

                            error_position_5_reg <=
                                chien_error_position_5_int;

                            error_position_6_reg <=
                                chien_error_position_6_int;

                            state_reg <=
                                LAUNCH_CORRECTOR;

                        end if;


                    when LAUNCH_CORRECTOR =>

                        corrector_start_reg <= '1';

                        state_reg <=
                            WAIT_CORRECTOR;


                    when WAIT_CORRECTOR =>

                        if corrector_done_int = '1' then

                            corrected_codeword_reg <=
                                corrector_codeword_int;

                            decoded_secret_reg <=
                                corrector_secret_int;

                            correction_success_latched_reg <=
                                corrector_success_int;

                            state_reg <=
                                LAUNCH_POST_SYNDROME;

                        end if;


                    when LAUNCH_POST_SYNDROME =>

                        syndrome_codeword_reg <=
                            corrected_codeword_reg;

                        syndrome_start_reg <= '1';

                        state_reg <=
                            WAIT_POST_SYNDROME;


                    when WAIT_POST_SYNDROME =>

                        if syndrome_done_int = '1' then

                            post_syndromes_zero_reg <=
                                syndromes_zero_int;

                            if
                                correction_success_latched_reg = '1'
                                and
                                syndromes_zero_int = '1'
                            then

                                decoder_success_reg <= '1';

                            else

                                decoder_success_reg <= '0';

                            end if;

                            busy_reg <= '0';
                            done_reg <= '1';

                            state_reg <= IDLE;

                        end if;

                end case;

            end if;

        end if;

    end process;

end architecture rtl;
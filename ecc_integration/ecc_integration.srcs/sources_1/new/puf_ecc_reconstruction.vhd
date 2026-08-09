library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.parameters.all;


entity puf_ecc_reconstruction is
    port (
        clk   : in std_logic;
        rst   : in std_logic;
        start : in std_logic;

        puf_response : in t_puf_response;
        helper_data  : in t_helper_data;

        noisy_codeword : out t_shortened_codeword;

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

        decoder_state_debug : out unsigned(3 downto 0);
        cycle_count_debug   : out unsigned(9 downto 0);

        chien_position_debug : out unsigned(6 downto 0);
        chien_cycle_debug    : out unsigned(7 downto 0)
    );
end entity puf_ecc_reconstruction;


architecture rtl of puf_ecc_reconstruction is

    signal noisy_codeword_int :
        t_shortened_codeword := (others => '0');

    signal corrected_codeword_int :
        t_shortened_codeword := (others => '0');

    signal decoded_secret_int :
        t_secret := (others => '0');

    signal busy_int :
        std_logic := '0';

    signal done_int :
        std_logic := '0';

    signal decoder_success_int :
        std_logic := '0';

    signal post_syndromes_zero_int :
        std_logic := '0';

    signal error_count_int :
        unsigned(2 downto 0) := (others => '0');

    signal error_position_0_int :
        unsigned(6 downto 0) := (others => '0');

    signal error_position_1_int :
        unsigned(6 downto 0) := (others => '0');

    signal error_position_2_int :
        unsigned(6 downto 0) := (others => '0');

    signal decoder_state_debug_int :
        unsigned(3 downto 0) := (others => '0');

    signal cycle_count_debug_int :
        unsigned(9 downto 0) := (others => '0');

    signal chien_position_debug_int :
        unsigned(6 downto 0) := (others => '0');

    signal chien_cycle_debug_int :
        unsigned(7 downto 0) := (others => '0');

begin

    noisy_codeword <= noisy_codeword_int;

    corrected_codeword <= corrected_codeword_int;
    decoded_secret     <= decoded_secret_int;

    busy <= busy_int;
    done <= done_int;

    decoder_success     <= decoder_success_int;
    post_syndromes_zero <= post_syndromes_zero_int;

    error_count <= error_count_int;

    error_position_0 <= error_position_0_int;
    error_position_1 <= error_position_1_int;
    error_position_2 <= error_position_2_int;

    decoder_state_debug <= decoder_state_debug_int;
    cycle_count_debug   <= cycle_count_debug_int;

    chien_position_debug <= chien_position_debug_int;
    chien_cycle_debug    <= chien_cycle_debug_int;


    u_hd_xor :
        entity work.hd_xor
        port map (
            puf_response   => puf_response,
            helper_data    => helper_data,
            noisy_codeword => noisy_codeword_int
        );


    u_bch_decoder :
        entity work.bch_decoder
        port map (
            clk   => clk,
            rst   => rst,
            start => start,

            received_codeword =>
                noisy_codeword_int,

            corrected_codeword =>
                corrected_codeword_int,

            decoded_secret =>
                decoded_secret_int,

            busy =>
                busy_int,

            done =>
                done_int,

            decoder_success =>
                decoder_success_int,

            post_syndromes_zero =>
                post_syndromes_zero_int,

            error_count =>
                error_count_int,

            error_position_0 =>
                error_position_0_int,

            error_position_1 =>
                error_position_1_int,

            error_position_2 =>
                error_position_2_int,

            decoder_state_debug =>
                decoder_state_debug_int,

            cycle_count_debug =>
                cycle_count_debug_int,

            chien_position_debug =>
                chien_position_debug_int,

            chien_cycle_debug =>
                chien_cycle_debug_int
        );

end architecture rtl;
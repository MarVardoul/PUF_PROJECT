library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.parameters.all;


entity bch_error_corrector is
    port (
        clk : in std_logic;
        rst : in std_logic;

        start : in std_logic;

        ----------------------------------------------------------------
        -- Noisy shortened BCH codeword
        ----------------------------------------------------------------
        received_codeword : in t_shortened_codeword;

        ----------------------------------------------------------------
        -- Error positions found by the Chien search
        ----------------------------------------------------------------
        error_position_0 : in unsigned(6 downto 0);
        error_position_1 : in unsigned(6 downto 0);
        error_position_2 : in unsigned(6 downto 0);

        error_count : in unsigned(2 downto 0);

        ----------------------------------------------------------------
        -- Must come from the Chien-search search_success output.
        ----------------------------------------------------------------
        search_success : in std_logic;

        ----------------------------------------------------------------
        -- Result
        ----------------------------------------------------------------
        corrected_codeword : out t_shortened_codeword;
        decoded_secret     : out t_secret;

        busy : out std_logic;
        done : out std_logic;

        ----------------------------------------------------------------
        -- Algebraic correction status only.
        --
        -- This does not prove that the reconstructed secret is the
        -- enrolled secret. A later verification hash is still required.
        ----------------------------------------------------------------
        correction_success : out std_logic
    );
end entity bch_error_corrector;


architecture rtl of bch_error_corrector is

    --------------------------------------------------------------------
    -- BCH(127,106) has 21 parity bits.
    --
    -- The shortened BCH(120,99) codeword is:
    --
    --     bits 119 downto 21 : 99-bit secret
    --     bits 20 downto 0   : 21 parity bits
    --------------------------------------------------------------------
    constant C_PARITY_BITS : natural :=
        C_BCH_PARENT_N - C_BCH_PARENT_K;

    type t_state is (
        IDLE,
        CORRECT
    );

    signal state_reg : t_state := IDLE;

    --------------------------------------------------------------------
    -- Captured inputs
    --------------------------------------------------------------------
    signal codeword_reg :
        t_shortened_codeword := (others => '0');

    signal position_0_reg :
        unsigned(6 downto 0) := (others => '0');

    signal position_1_reg :
        unsigned(6 downto 0) := (others => '0');

    signal position_2_reg :
        unsigned(6 downto 0) := (others => '0');

    signal error_count_reg :
        unsigned(2 downto 0) := (others => '0');

    signal search_success_reg :
        std_logic := '0';

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------
    signal corrected_codeword_reg :
        t_shortened_codeword := (others => '0');

    signal decoded_secret_reg :
        t_secret := (others => '0');

    signal correction_success_reg :
        std_logic := '0';

    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Parameter consistency check
    --------------------------------------------------------------------
    assert
        C_PUF_BITS - C_PARITY_BITS = C_SECRET_BITS
        report
            "BCH parameter mismatch: secret width is inconsistent"
        severity failure;


    --------------------------------------------------------------------
    -- Output assignments
    --------------------------------------------------------------------
    corrected_codeword <= corrected_codeword_reg;
    decoded_secret     <= decoded_secret_reg;

    correction_success <= correction_success_reg;

    busy <= busy_reg;
    done <= done_reg;


    --------------------------------------------------------------------
    -- Correction controller
    --------------------------------------------------------------------
    process (clk)

        variable corrected_word :
            t_shortened_codeword;

        variable result_valid :
            boolean;

        variable count_value :
            natural range 0 to 7;

        variable position_0_value :
            natural range 0 to 127;

        variable position_1_value :
            natural range 0 to 127;

        variable position_2_value :
            natural range 0 to 127;

    begin

        if rising_edge(clk) then

            -- done is a one-clock pulse.
            done_reg <= '0';

            if rst = '1' then

                state_reg <= IDLE;

                codeword_reg <= (others => '0');

                position_0_reg <= (others => '0');
                position_1_reg <= (others => '0');
                position_2_reg <= (others => '0');

                error_count_reg <= (others => '0');
                search_success_reg <= '0';

                corrected_codeword_reg <= (others => '0');
                decoded_secret_reg     <= (others => '0');

                correction_success_reg <= '0';

                busy_reg <= '0';
                done_reg <= '0';

            else

                case state_reg is

                    ----------------------------------------------------
                    -- Wait for a new request
                    ----------------------------------------------------
                    when IDLE =>

                        busy_reg <= '0';

                        if start = '1' then

                            codeword_reg <= received_codeword;

                            position_0_reg <= error_position_0;
                            position_1_reg <= error_position_1;
                            position_2_reg <= error_position_2;

                            error_count_reg <= error_count;
                            search_success_reg <= search_success;

                            correction_success_reg <= '0';

                            busy_reg <= '1';
                            state_reg <= CORRECT;

                        end if;


                    ----------------------------------------------------
                    -- Validate positions and correct the codeword
                    ----------------------------------------------------
                    when CORRECT =>

                        corrected_word := codeword_reg;

                        count_value :=
                            to_integer(error_count_reg);

                        position_0_value :=
                            to_integer(position_0_reg);

                        position_1_value :=
                            to_integer(position_1_reg);

                        position_2_value :=
                            to_integer(position_2_reg);

                        ------------------------------------------------
                        -- Begin with the Chien-search status.
                        ------------------------------------------------
                        result_valid :=
                            search_success_reg = '1';

                        ------------------------------------------------
                        -- The selected BCH code corrects at most
                        -- three errors.
                        ------------------------------------------------
                        if count_value > C_BCH_T then
                            result_valid := false;
                        end if;

                        ------------------------------------------------
                        -- Check active error positions.
                        --
                        -- Valid shortened-code positions are 0..119.
                        ------------------------------------------------
                        if count_value >= 1 then

                            if position_0_value >= C_PUF_BITS then
                                result_valid := false;
                            end if;

                        end if;

                        if count_value >= 2 then

                            if position_1_value >= C_PUF_BITS then
                                result_valid := false;
                            end if;

                            if position_1_value = position_0_value then
                                result_valid := false;
                            end if;

                        end if;

                        if count_value >= 3 then

                            if position_2_value >= C_PUF_BITS then
                                result_valid := false;
                            end if;

                            if
                                position_2_value = position_0_value
                                or
                                position_2_value = position_1_value
                            then
                                result_valid := false;
                            end if;

                        end if;

                        ------------------------------------------------
                        -- Flip the located error positions.
                        ------------------------------------------------
                        if result_valid then

                            if count_value >= 1 then

                                corrected_word(position_0_value) :=
                                    not corrected_word(
                                        position_0_value
                                    );

                            end if;

                            if count_value >= 2 then

                                corrected_word(position_1_value) :=
                                    not corrected_word(
                                        position_1_value
                                    );

                            end if;

                            if count_value >= 3 then

                                corrected_word(position_2_value) :=
                                    not corrected_word(
                                        position_2_value
                                    );

                            end if;

                            corrected_codeword_reg <=
                                corrected_word;

                            decoded_secret_reg <=
                                corrected_word(
                                    C_PUF_BITS - 1
                                    downto
                                    C_PARITY_BITS
                                );

                            correction_success_reg <= '1';

                        else

                            ------------------------------------------------
                            -- On failure, preserve the received word for
                            -- debugging but do not release a secret.
                            ------------------------------------------------
                            corrected_codeword_reg <=
                                codeword_reg;

                            decoded_secret_reg <=
                                (others => '0');

                            correction_success_reg <= '0';

                        end if;

                        busy_reg <= '0';
                        done_reg <= '1';

                        state_reg <= IDLE;

                end case;

            end if;

        end if;

    end process;

end architecture rtl;
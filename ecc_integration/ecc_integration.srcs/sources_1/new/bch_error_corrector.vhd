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

        received_codeword : in t_shortened_codeword;

        error_position_0 : in unsigned(6 downto 0);
        error_position_1 : in unsigned(6 downto 0);
        error_position_2 : in unsigned(6 downto 0);
        error_position_3 : in unsigned(6 downto 0);
        error_position_4 : in unsigned(6 downto 0);
        error_position_5 : in unsigned(6 downto 0);
        error_position_6 : in unsigned(6 downto 0);

        error_count : in unsigned(2 downto 0);

        search_success : in std_logic;

        corrected_codeword : out t_shortened_codeword;
        decoded_secret     : out t_secret;

        busy : out std_logic;
        done : out std_logic;

        correction_success : out std_logic
    );
end entity bch_error_corrector;


architecture rtl of bch_error_corrector is

    constant C_PARITY_BITS : natural :=
        C_BCH_PARENT_N - C_BCH_PARENT_K;

    type t_state is (
        IDLE,
        CORRECT
    );

    type t_position_array is
        array (0 to C_BCH_T - 1) of unsigned(6 downto 0);

    type t_position_value_array is
        array (0 to C_BCH_T - 1) of natural range 0 to 127;

    signal state_reg : t_state := IDLE;

    signal codeword_reg :
        t_shortened_codeword := (others => '0');

    signal position_reg :
        t_position_array := (others => (others => '0'));

    signal error_count_reg :
        unsigned(2 downto 0) := (others => '0');

    signal search_success_reg :
        std_logic := '0';

    signal corrected_codeword_reg :
        t_shortened_codeword := (others => '0');

    signal decoded_secret_reg :
        t_secret := (others => '0');

    signal correction_success_reg :
        std_logic := '0';

    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';

begin

    assert C_PUF_BITS - C_PARITY_BITS = C_SECRET_BITS
        report "BCH parameter mismatch: secret width is inconsistent"
        severity failure;

    assert C_BCH_T = 7
        report "bch_error_corrector requires C_BCH_T = 7"
        severity failure;

    corrected_codeword <= corrected_codeword_reg;
    decoded_secret <= decoded_secret_reg;

    correction_success <= correction_success_reg;

    busy <= busy_reg;
    done <= done_reg;


    process (clk)

        variable corrected_word :
            t_shortened_codeword;

        variable result_valid :
            boolean;

        variable count_value :
            natural range 0 to C_BCH_T;

        variable position_value :
            t_position_value_array;

    begin

        if rising_edge(clk) then

            done_reg <= '0';

            if rst = '1' then

                state_reg <= IDLE;

                codeword_reg <=
                    (others => '0');

                position_reg <=
                    (others => (others => '0'));

                error_count_reg <=
                    (others => '0');

                search_success_reg <= '0';

                corrected_codeword_reg <=
                    (others => '0');

                decoded_secret_reg <=
                    (others => '0');

                correction_success_reg <= '0';

                busy_reg <= '0';
                done_reg <= '0';


            else

                case state_reg is

                    when IDLE =>

                        busy_reg <= '0';

                        if start = '1' then

                            codeword_reg <=
                                received_codeword;

                            position_reg(0) <=
                                error_position_0;

                            position_reg(1) <=
                                error_position_1;

                            position_reg(2) <=
                                error_position_2;

                            position_reg(3) <=
                                error_position_3;

                            position_reg(4) <=
                                error_position_4;

                            position_reg(5) <=
                                error_position_5;

                            position_reg(6) <=
                                error_position_6;

                            error_count_reg <=
                                error_count;

                            search_success_reg <=
                                search_success;

                            correction_success_reg <=
                                '0';

                            busy_reg <= '1';

                            state_reg <= CORRECT;

                        end if;


                    when CORRECT =>

                        corrected_word :=
                            codeword_reg;

                        count_value :=
                            to_integer(error_count_reg);

                        for i in 0 to C_BCH_T - 1 loop

                            position_value(i) :=
                                to_integer(position_reg(i));

                        end loop;

                        result_valid :=
                            search_success_reg = '1';

                        if count_value > C_BCH_T then
                            result_valid := false;
                        end if;


                        for i in 0 to C_BCH_T - 1 loop

                            if i < count_value then

                                if position_value(i) >= C_PUF_BITS then

                                    result_valid := false;

                                end if;


                                for j in 0 to C_BCH_T - 1 loop

                                    if
                                        j < i
                                        and
                                        j < count_value
                                    then

                                        if
                                            position_value(i)
                                            =
                                            position_value(j)
                                        then

                                            result_valid := false;

                                        end if;

                                    end if;

                                end loop;

                            end if;

                        end loop;


                        if result_valid then

                            for i in 0 to C_BCH_T - 1 loop

                                if i < count_value then

                                    corrected_word(
                                        position_value(i)
                                    ) :=
                                        not corrected_word(
                                            position_value(i)
                                        );

                                end if;

                            end loop;

                            corrected_codeword_reg <=
                                corrected_word;

                            decoded_secret_reg <=
                                corrected_word(
                                    C_PUF_BITS - 1
                                    downto
                                    C_PARITY_BITS
                                );

                            correction_success_reg <=
                                '1';

                        else

                            corrected_codeword_reg <=
                                codeword_reg;

                            decoded_secret_reg <=
                                (others => '0');

                            correction_success_reg <=
                                '0';

                        end if;

                        busy_reg <= '0';
                        done_reg <= '1';

                        state_reg <= IDLE;

                end case;

            end if;

        end if;

    end process;

end architecture rtl;
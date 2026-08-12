library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.parameters.all;
use work.gf128_pkg.all;

entity bch_error_locator is
    port (
        clk : in std_logic;
        rst : in std_logic;

        start : in std_logic;

        syndrome_1  : in t_gf128;
        syndrome_2  : in t_gf128;
        syndrome_3  : in t_gf128;
        syndrome_4  : in t_gf128;
        syndrome_5  : in t_gf128;
        syndrome_6  : in t_gf128;
        syndrome_7  : in t_gf128;
        syndrome_8  : in t_gf128;
        syndrome_9  : in t_gf128;
        syndrome_10 : in t_gf128;
        syndrome_11 : in t_gf128;
        syndrome_12 : in t_gf128;
        syndrome_13 : in t_gf128;
        syndrome_14 : in t_gf128;

        busy : out std_logic;
        done : out std_logic;

        locator_0 : out t_gf128;
        locator_1 : out t_gf128;
        locator_2 : out t_gf128;
        locator_3 : out t_gf128;
        locator_4 : out t_gf128;
        locator_5 : out t_gf128;
        locator_6 : out t_gf128;
        locator_7 : out t_gf128;

        locator_degree : out unsigned(3 downto 0);
        locator_valid  : out std_logic
    );
end entity bch_error_locator;


architecture rtl of bch_error_locator is

    type t_gf_array is
        array (0 to C_BCH_T) of t_gf128;

    type t_syndrome_array is
        array (0 to C_BCH_SYNDROMES - 1) of t_gf128;

    type t_state is (
        IDLE,
        DISC_START,
        DISC_ACCUM,
        DISC_CHECK,
        UPDATE_C,
        UPDATE_DONE,
        INVERSE_B,
        ADVANCE_ITERATION
    );

    signal state_reg : t_state := IDLE;

    signal syndrome_reg : t_syndrome_array :=
        (others => C_GF_ZERO);

    signal c_reg : t_gf_array := (
        0      => C_GF_ONE,
        others => C_GF_ZERO
    );

    signal b_reg : t_gf_array := (
        0      => C_GF_ONE,
        others => C_GF_ZERO
    );

    signal old_c_reg : t_gf_array := (
        0      => C_GF_ONE,
        others => C_GF_ZERO
    );

    signal locator_degree_reg :
        natural range 0 to C_BCH_SYNDROMES := 0;

    signal pending_degree_reg :
        natural range 0 to C_BCH_T := 0;

    signal degree_update_pending_reg :
        std_logic := '0';

    signal shift_reg :
        natural range 1 to C_BCH_SYNDROMES + 1 := 1;

    signal iteration_reg :
        natural range 0 to C_BCH_SYNDROMES - 1 := 0;

    signal coefficient_index_reg :
        natural range 1 to C_BCH_T := 1;

    signal update_index_reg :
        natural range 0 to C_BCH_T := 0;

    signal discrepancy_reg :
        t_gf128 := C_GF_ZERO;

    signal current_discrepancy_reg :
        t_gf128 := C_GF_ZERO;

    signal previous_discrepancy_inverse_reg :
        t_gf128 := C_GF_ONE;

    signal scale_reg :
        t_gf128 := C_GF_ZERO;

    signal inverse_acc_reg :
        t_gf128 := C_GF_ONE;

    signal inverse_count_reg :
        natural range 0 to 125 := 0;

    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';

begin

    assert C_BCH_T = 7
        report "bch_error_locator requires C_BCH_T = 7"
        severity failure;

    assert C_BCH_SYNDROMES = 14
        report "bch_error_locator requires C_BCH_SYNDROMES = 14"
        severity failure;

    locator_0 <= c_reg(0);
    locator_1 <= c_reg(1);
    locator_2 <= c_reg(2);
    locator_3 <= c_reg(3);
    locator_4 <= c_reg(4);
    locator_5 <= c_reg(5);
    locator_6 <= c_reg(6);
    locator_7 <= c_reg(7);

    locator_degree <=
        to_unsigned(
            locator_degree_reg,
            locator_degree'length
        );

    locator_valid <= '1'
        when locator_degree_reg <= C_BCH_T
        else '0';

    busy <= busy_reg;
    done <= done_reg;


    process (clk)

        variable product_value :
            t_gf128;

        variable inverse_next :
            t_gf128;

        variable new_degree :
            natural range 0 to C_BCH_SYNDROMES;

        variable target_index :
            natural range 0 to
            C_BCH_T + C_BCH_SYNDROMES + 1;

    begin

        if rising_edge(clk) then

            done_reg <= '0';

            if rst = '1' then

                state_reg <= IDLE;

                syndrome_reg <=
                    (others => C_GF_ZERO);

                c_reg <= (
                    0      => C_GF_ONE,
                    others => C_GF_ZERO
                );

                b_reg <= (
                    0      => C_GF_ONE,
                    others => C_GF_ZERO
                );

                old_c_reg <= (
                    0      => C_GF_ONE,
                    others => C_GF_ZERO
                );

                locator_degree_reg <= 0;
                pending_degree_reg <= 0;

                degree_update_pending_reg <= '0';

                shift_reg <= 1;
                iteration_reg <= 0;

                coefficient_index_reg <= 1;
                update_index_reg <= 0;

                discrepancy_reg <= C_GF_ZERO;
                current_discrepancy_reg <= C_GF_ZERO;

                previous_discrepancy_inverse_reg <=
                    C_GF_ONE;

                scale_reg <= C_GF_ZERO;

                inverse_acc_reg <= C_GF_ONE;
                inverse_count_reg <= 0;

                busy_reg <= '0';
                done_reg <= '0';


            else

                case state_reg is

                    when IDLE =>

                        busy_reg <= '0';

                        if start = '1' then

                            syndrome_reg(0)  <= syndrome_1;
                            syndrome_reg(1)  <= syndrome_2;
                            syndrome_reg(2)  <= syndrome_3;
                            syndrome_reg(3)  <= syndrome_4;
                            syndrome_reg(4)  <= syndrome_5;
                            syndrome_reg(5)  <= syndrome_6;
                            syndrome_reg(6)  <= syndrome_7;
                            syndrome_reg(7)  <= syndrome_8;
                            syndrome_reg(8)  <= syndrome_9;
                            syndrome_reg(9)  <= syndrome_10;
                            syndrome_reg(10) <= syndrome_11;
                            syndrome_reg(11) <= syndrome_12;
                            syndrome_reg(12) <= syndrome_13;
                            syndrome_reg(13) <= syndrome_14;

                            c_reg <= (
                                0      => C_GF_ONE,
                                others => C_GF_ZERO
                            );

                            b_reg <= (
                                0      => C_GF_ONE,
                                others => C_GF_ZERO
                            );

                            old_c_reg <= (
                                0      => C_GF_ONE,
                                others => C_GF_ZERO
                            );

                            locator_degree_reg <= 0;
                            pending_degree_reg <= 0;

                            degree_update_pending_reg <= '0';

                            shift_reg <= 1;
                            iteration_reg <= 0;

                            previous_discrepancy_inverse_reg <=
                                C_GF_ONE;

                            busy_reg <= '1';

                            state_reg <= DISC_START;

                        end if;


                    when DISC_START =>

                        discrepancy_reg <=
                            syndrome_reg(iteration_reg);

                        coefficient_index_reg <= 1;

                        if
                            locator_degree_reg = 0
                            or
                            iteration_reg = 0
                        then

                            state_reg <= DISC_CHECK;

                        else

                            state_reg <= DISC_ACCUM;

                        end if;


                    when DISC_ACCUM =>

                        product_value :=
                            gf_multiply(
                                c_reg(coefficient_index_reg),
                                syndrome_reg(
                                    iteration_reg
                                    - coefficient_index_reg
                                )
                            );

                        discrepancy_reg <=
                            discrepancy_reg xor product_value;

                        if
                            coefficient_index_reg
                                >= locator_degree_reg
                            or
                            coefficient_index_reg
                                >= iteration_reg
                        then

                            state_reg <= DISC_CHECK;

                        else

                            coefficient_index_reg <=
                                coefficient_index_reg + 1;

                        end if;


                    when DISC_CHECK =>

                        if discrepancy_reg = C_GF_ZERO then

                            shift_reg <= shift_reg + 1;

                            state_reg <=
                                ADVANCE_ITERATION;

                        else

                            if
                                2 * locator_degree_reg
                                <= iteration_reg
                            then

                                new_degree :=
                                    iteration_reg
                                    + 1
                                    - locator_degree_reg;

                                if new_degree > C_BCH_T then

                                    locator_degree_reg <=
                                        new_degree;

                                    busy_reg <= '0';
                                    done_reg <= '1';

                                    state_reg <= IDLE;

                                else

                                    pending_degree_reg <=
                                        new_degree;

                                    degree_update_pending_reg <=
                                        '1';

                                    current_discrepancy_reg <=
                                        discrepancy_reg;

                                    scale_reg <=
                                        gf_multiply(
                                            discrepancy_reg,
                                            previous_discrepancy_inverse_reg
                                        );

                                    old_c_reg <= c_reg;

                                    update_index_reg <= 0;

                                    state_reg <= UPDATE_C;

                                end if;

                            else

                                degree_update_pending_reg <=
                                    '0';

                                current_discrepancy_reg <=
                                    discrepancy_reg;

                                scale_reg <=
                                    gf_multiply(
                                        discrepancy_reg,
                                        previous_discrepancy_inverse_reg
                                    );

                                old_c_reg <= c_reg;

                                update_index_reg <= 0;

                                state_reg <= UPDATE_C;

                            end if;

                        end if;


                    when UPDATE_C =>

                        target_index :=
                            update_index_reg + shift_reg;

                        if
                            target_index <= C_BCH_T
                            and
                            b_reg(update_index_reg)
                                /= C_GF_ZERO
                        then

                            product_value :=
                                gf_multiply(
                                    scale_reg,
                                    b_reg(update_index_reg)
                                );

                            c_reg(target_index) <=
                                c_reg(target_index)
                                xor product_value;

                        end if;

                        if update_index_reg = C_BCH_T then

                            state_reg <= UPDATE_DONE;

                        else

                            update_index_reg <=
                                update_index_reg + 1;

                        end if;


                    when UPDATE_DONE =>

                        if degree_update_pending_reg = '1' then

                            locator_degree_reg <=
                                pending_degree_reg;

                            b_reg <= old_c_reg;

                            shift_reg <= 1;

                            inverse_acc_reg <= C_GF_ONE;
                            inverse_count_reg <= 0;

                            state_reg <= INVERSE_B;

                        else

                            shift_reg <= shift_reg + 1;

                            state_reg <=
                                ADVANCE_ITERATION;

                        end if;


                    when INVERSE_B =>

                        inverse_next :=
                            gf_multiply(
                                inverse_acc_reg,
                                current_discrepancy_reg
                            );

                        if inverse_count_reg = 125 then

                            previous_discrepancy_inverse_reg <=
                                inverse_next;

                            state_reg <=
                                ADVANCE_ITERATION;

                        else

                            inverse_acc_reg <=
                                inverse_next;

                            inverse_count_reg <=
                                inverse_count_reg + 1;

                        end if;


                    when ADVANCE_ITERATION =>

                        if
                            iteration_reg
                            = C_BCH_SYNDROMES - 1
                        then

                            busy_reg <= '0';
                            done_reg <= '1';

                            state_reg <= IDLE;

                        else

                            iteration_reg <=
                                iteration_reg + 1;

                            state_reg <= DISC_START;

                        end if;

                end case;

            end if;

        end if;

    end process;

end architecture rtl;
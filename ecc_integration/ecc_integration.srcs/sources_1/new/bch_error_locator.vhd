library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gf128_pkg.all;


entity bch_error_locator is
    port (
        clk : in std_logic;
        rst : in std_logic;

        start : in std_logic;

        syndrome_1 : in t_gf128;
        syndrome_2 : in t_gf128;
        syndrome_3 : in t_gf128;
        syndrome_4 : in t_gf128;
        syndrome_5 : in t_gf128;
        syndrome_6 : in t_gf128;

        busy : out std_logic;
        done : out std_logic;

        -- Error-locator polynomial:
        --
        -- Lambda(x) =
        --     locator_0
        --   + locator_1*x
        --   + locator_2*x^2
        --   + locator_3*x^3
        locator_0 : out t_gf128;
        locator_1 : out t_gf128;
        locator_2 : out t_gf128;
        locator_3 : out t_gf128;

        -- Three bits allow representation of degrees 0 through 6.
        locator_degree : out unsigned(2 downto 0);

        -- High only when the locator degree is within BCH t = 3.
        locator_valid : out std_logic
    );
end entity bch_error_locator;


architecture rtl of bch_error_locator is

    --------------------------------------------------------------------
    -- Arrays use ascending polynomial-coefficient order:
    --
    -- polynomial(0) = constant coefficient
    -- polynomial(1) = coefficient of x
    -- ...
    --------------------------------------------------------------------

    type t_gf_array_7 is array (0 to 6) of t_gf128;
    type t_syndrome_array is array (0 to 5) of t_gf128;

    signal syndrome_reg : t_syndrome_array :=
        (others => C_GF_ZERO);

    --------------------------------------------------------------------
    -- Berlekamp-Massey variables
    --
    -- C(x): current locator polynomial
    -- B(x): previous locator polynomial
    -- L:    current locator degree
    -- m:    number of iterations since last degree update
    -- b:    discrepancy from the previous degree update
    --------------------------------------------------------------------

    signal c_reg : t_gf_array_7 :=
        (
            0      => C_GF_ONE,
            others => C_GF_ZERO
        );

    signal b_reg : t_gf_array_7 :=
        (
            0      => C_GF_ONE,
            others => C_GF_ZERO
        );

    signal locator_degree_reg :
        natural range 0 to 6 := 0;

    signal shift_reg :
        natural range 1 to 7 := 1;

    signal previous_discrepancy_reg :
        t_gf128 := C_GF_ONE;

    signal iteration_reg :
        natural range 0 to 5 := 0;

    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------

    locator_0 <= c_reg(0);
    locator_1 <= c_reg(1);
    locator_2 <= c_reg(2);
    locator_3 <= c_reg(3);

    locator_degree <= to_unsigned(
        locator_degree_reg,
        locator_degree'length
    );

    locator_valid <= '1'
        when locator_degree_reg <= 3
        else '0';

    busy <= busy_reg;
    done <= done_reg;


    --------------------------------------------------------------------
    -- Berlekamp-Massey processing
    --
    -- Six syndromes are processed in six clock cycles.
    --------------------------------------------------------------------

    process (clk)

        variable discrepancy : t_gf128;
        variable scale       : t_gf128;

        variable c_next : t_gf_array_7;
        variable b_next : t_gf_array_7;
        variable old_c  : t_gf_array_7;

        variable degree_next :
            natural range 0 to 6;

        variable shift_next :
            natural range 1 to 7;

        variable previous_discrepancy_next :
            t_gf128;

    begin

        if rising_edge(clk) then

            -- done is a one-clock pulse
            done_reg <= '0';

            if rst = '1' then

                syndrome_reg <= (others => C_GF_ZERO);

                c_reg <= (
                    0      => C_GF_ONE,
                    others => C_GF_ZERO
                );

                b_reg <= (
                    0      => C_GF_ONE,
                    others => C_GF_ZERO
                );

                locator_degree_reg <= 0;
                shift_reg          <= 1;

                previous_discrepancy_reg <= C_GF_ONE;

                iteration_reg <= 0;

                busy_reg <= '0';
                done_reg <= '0';

            elsif busy_reg = '0' then

                --------------------------------------------------------
                -- Accept a new set of syndromes
                --------------------------------------------------------

                if start = '1' then

                    syndrome_reg(0) <= syndrome_1;
                    syndrome_reg(1) <= syndrome_2;
                    syndrome_reg(2) <= syndrome_3;
                    syndrome_reg(3) <= syndrome_4;
                    syndrome_reg(4) <= syndrome_5;
                    syndrome_reg(5) <= syndrome_6;

                    c_reg <= (
                        0      => C_GF_ONE,
                        others => C_GF_ZERO
                    );

                    b_reg <= (
                        0      => C_GF_ONE,
                        others => C_GF_ZERO
                    );

                    locator_degree_reg <= 0;
                    shift_reg          <= 1;

                    previous_discrepancy_reg <= C_GF_ONE;

                    iteration_reg <= 0;
                    busy_reg      <= '1';

                end if;

            else

                --------------------------------------------------------
                -- Copy current state into variables.
                --------------------------------------------------------

                c_next := c_reg;
                b_next := b_reg;
                old_c  := c_reg;

                degree_next := locator_degree_reg;
                shift_next  := shift_reg;

                previous_discrepancy_next :=
                    previous_discrepancy_reg;

                --------------------------------------------------------
                -- Calculate discrepancy:
                --
                -- d_n =
                --     S_(n+1)
                --   + sum C_i * S_(n+1-i)
                --
                -- Syndrome array index zero corresponds to S1.
                --------------------------------------------------------

                discrepancy :=
                    syndrome_reg(iteration_reg);

                for coefficient_index in 1 to 6 loop

                    if coefficient_index <=
                       locator_degree_reg
                    then

                        discrepancy :=
                            discrepancy xor
                            gf_multiply(
                                c_reg(coefficient_index),
                                syndrome_reg(
                                    iteration_reg
                                    - coefficient_index
                                )
                            );

                    end if;

                end loop;

                --------------------------------------------------------
                -- Zero discrepancy:
                --
                -- Locator polynomial does not change.
                --------------------------------------------------------

                if discrepancy = C_GF_ZERO then

                    shift_next := shift_reg + 1;

                else

                    ----------------------------------------------------
                    -- Preserve old C(x), then calculate:
                    --
                    -- scale = discrepancy / previous_discrepancy
                    ----------------------------------------------------

                    old_c := c_reg;

                    scale := gf_divide(
                        discrepancy,
                        previous_discrepancy_reg
                    );

                    ----------------------------------------------------
                    -- C(x) =
                    --     C(x)
                    --   + scale * x^m * B(x)
                    ----------------------------------------------------

                    for coefficient_index in 0 to 6 loop

                        if
                            b_reg(coefficient_index)
                            /= C_GF_ZERO
                            and
                            coefficient_index + shift_reg <= 6
                        then

                            c_next(
                                coefficient_index
                                + shift_reg
                            ) :=
                                c_next(
                                    coefficient_index
                                    + shift_reg
                                )
                                xor
                                gf_multiply(
                                    scale,
                                    b_reg(
                                        coefficient_index
                                    )
                                );

                        end if;

                    end loop;

                    ----------------------------------------------------
                    -- Update degree and reference polynomial when:
                    --
                    --     2L <= n
                    ----------------------------------------------------

                    if
                        2 * locator_degree_reg
                        <= iteration_reg
                    then

                        degree_next :=
                            iteration_reg
                            + 1
                            - locator_degree_reg;

                        b_next := old_c;

                        previous_discrepancy_next :=
                            discrepancy;

                        shift_next := 1;

                    else

                        shift_next := shift_reg + 1;

                    end if;

                end if;

                --------------------------------------------------------
                -- Register the updated state.
                --------------------------------------------------------

                c_reg <= c_next;
                b_reg <= b_next;

                locator_degree_reg <= degree_next;
                shift_reg          <= shift_next;

                previous_discrepancy_reg <=
                    previous_discrepancy_next;

                --------------------------------------------------------
                -- Six Berlekamp-Massey iterations are required.
                --------------------------------------------------------

                if iteration_reg = 5 then

                    busy_reg <= '0';
                    done_reg <= '1';

                else

                    iteration_reg <= iteration_reg + 1;

                end if;

            end if;

        end if;

    end process;

end architecture rtl;
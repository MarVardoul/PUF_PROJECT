library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.parameters.all;
use work.gf128_pkg.all;


entity bch_chien_search is
    port (
        clk : in std_logic;
        rst : in std_logic;

        start : in std_logic;

        locator_0 : in t_gf128;
        locator_1 : in t_gf128;
        locator_2 : in t_gf128;
        locator_3 : in t_gf128;

        locator_degree : in unsigned(2 downto 0);

        busy : out std_logic;
        done : out std_logic;

        error_position_0 : out unsigned(6 downto 0);
        error_position_1 : out unsigned(6 downto 0);
        error_position_2 : out unsigned(6 downto 0);

        error_count : out unsigned(2 downto 0);

        root_count_matches_degree : out std_logic;
        shortened_position_error  : out std_logic;
        search_success             : out std_logic;

        current_position : out unsigned(6 downto 0);
        cycle_count      : out unsigned(7 downto 0)
    );
end entity bch_chien_search;


architecture rtl of bch_chien_search is

    --------------------------------------------------------------------
    -- alpha^-1 = alpha^126 = hexadecimal 44 in GF(2^7)
    --
    -- Primitive polynomial:
    --
    --     x^7 + x^3 + 1
    --------------------------------------------------------------------
    constant C_ALPHA_INVERSE : t_gf128 :=
        std_logic_vector(to_unsigned(16#44#, 7));

    --------------------------------------------------------------------
    -- Captured locator polynomial
    --------------------------------------------------------------------
    signal locator_0_reg : t_gf128 := C_GF_ONE;
    signal locator_1_reg : t_gf128 := C_GF_ZERO;
    signal locator_2_reg : t_gf128 := C_GF_ZERO;
    signal locator_3_reg : t_gf128 := C_GF_ZERO;

    signal locator_degree_reg :
        natural range 0 to 7 := 0;

    --------------------------------------------------------------------
    -- x_reg contains alpha^(-position_reg).
    --
    -- At position zero:
    --
    --     x_reg = alpha^0 = 1
    --
    -- After each position:
    --
    --     x_reg = x_reg * alpha^-1
    --------------------------------------------------------------------
    signal x_reg : t_gf128 := C_GF_ONE;

    --------------------------------------------------------------------
    -- Search progress
    --------------------------------------------------------------------
    signal position_reg :
        natural range 0 to C_BCH_PARENT_N - 1 := 0;

    signal cycle_count_reg :
        natural range 0 to C_BCH_PARENT_N := 0;

    --------------------------------------------------------------------
    -- Located roots
    --------------------------------------------------------------------
    signal error_position_0_reg :
        unsigned(6 downto 0) := (others => '0');

    signal error_position_1_reg :
        unsigned(6 downto 0) := (others => '0');

    signal error_position_2_reg :
        unsigned(6 downto 0) := (others => '0');

    signal error_count_reg :
        natural range 0 to 7 := 0;

    signal root_count_matches_degree_reg :
        std_logic := '0';

    signal shortened_position_error_reg :
        std_logic := '0';

    signal search_success_reg :
        std_logic := '0';

    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------
    busy <= busy_reg;
    done <= done_reg;

    error_position_0 <= error_position_0_reg;
    error_position_1 <= error_position_1_reg;
    error_position_2 <= error_position_2_reg;

    error_count <= to_unsigned(
        error_count_reg,
        error_count'length
    );

    root_count_matches_degree <=
        root_count_matches_degree_reg;

    shortened_position_error <=
        shortened_position_error_reg;

    search_success <= search_success_reg;

    current_position <= to_unsigned(
        position_reg,
        current_position'length
    );

    cycle_count <= to_unsigned(
        cycle_count_reg,
        cycle_count'length
    );


    --------------------------------------------------------------------
    -- Chien search
    --------------------------------------------------------------------
    process (clk)

        variable x2_value :
            t_gf128;

        variable x3_value :
            t_gf128;

        variable locator_result :
            t_gf128;

        variable root_count_next :
            natural range 0 to 7;

        variable position_0_next :
            unsigned(6 downto 0);

        variable position_1_next :
            unsigned(6 downto 0);

        variable position_2_next :
            unsigned(6 downto 0);

        variable shortened_error_next :
            std_logic;

        variable roots_match_next :
            std_logic;

        variable search_success_next :
            std_logic;

    begin

        if rising_edge(clk) then

            ----------------------------------------------------------------
            -- done is a one-clock pulse.
            ----------------------------------------------------------------
            done_reg <= '0';

            if rst = '1' then

                locator_0_reg <= C_GF_ONE;
                locator_1_reg <= C_GF_ZERO;
                locator_2_reg <= C_GF_ZERO;
                locator_3_reg <= C_GF_ZERO;

                locator_degree_reg <= 0;

                x_reg <= C_GF_ONE;

                position_reg    <= 0;
                cycle_count_reg <= 0;

                error_position_0_reg <= (others => '0');
                error_position_1_reg <= (others => '0');
                error_position_2_reg <= (others => '0');

                error_count_reg <= 0;

                root_count_matches_degree_reg <= '0';
                shortened_position_error_reg  <= '0';
                search_success_reg             <= '0';

                busy_reg <= '0';
                done_reg <= '0';

            elsif busy_reg = '0' then

                ----------------------------------------------------------------
                -- Accept a new locator polynomial.
                ----------------------------------------------------------------
                if start = '1' then

                    locator_0_reg <= locator_0;
                    locator_1_reg <= locator_1;
                    locator_2_reg <= locator_2;
                    locator_3_reg <= locator_3;

                    locator_degree_reg <=
                        to_integer(locator_degree);

                    ----------------------------------------------------------------
                    -- Position zero is evaluated at alpha^0 = 1.
                    ----------------------------------------------------------------
                    x_reg <= C_GF_ONE;

                    position_reg    <= 0;
                    cycle_count_reg <= 0;

                    error_position_0_reg <= (others => '0');
                    error_position_1_reg <= (others => '0');
                    error_position_2_reg <= (others => '0');

                    error_count_reg <= 0;

                    root_count_matches_degree_reg <= '0';
                    shortened_position_error_reg  <= '0';
                    search_success_reg             <= '0';

                    busy_reg <= '1';

                end if;

            else

                ----------------------------------------------------------------
                -- Evaluate:
                --
                -- Lambda(x) =
                --     locator_0
                --   + locator_1*x
                --   + locator_2*x^2
                --   + locator_3*x^3
                --
                -- where x = alpha^(-position_reg).
                ----------------------------------------------------------------
                x2_value := gf_multiply(
                    x_reg,
                    x_reg
                );

                x3_value := gf_multiply(
                    x2_value,
                    x_reg
                );

                locator_result := locator_0_reg;

                if locator_degree_reg >= 1 then

                    locator_result :=
                        locator_result xor
                        gf_multiply(
                            locator_1_reg,
                            x_reg
                        );

                end if;

                if locator_degree_reg >= 2 then

                    locator_result :=
                        locator_result xor
                        gf_multiply(
                            locator_2_reg,
                            x2_value
                        );

                end if;

                if locator_degree_reg >= 3 then

                    locator_result :=
                        locator_result xor
                        gf_multiply(
                            locator_3_reg,
                            x3_value
                        );

                end if;


                ----------------------------------------------------------------
                -- Copy current results into variables.
                ----------------------------------------------------------------
                root_count_next :=
                    error_count_reg;

                position_0_next :=
                    error_position_0_reg;

                position_1_next :=
                    error_position_1_reg;

                position_2_next :=
                    error_position_2_reg;

                shortened_error_next :=
                    shortened_position_error_reg;


                ----------------------------------------------------------------
                -- A zero result indicates a root.
                ----------------------------------------------------------------
                if locator_result = C_GF_ZERO then

                    case root_count_next is

                        when 0 =>

                            position_0_next := to_unsigned(
                                position_reg,
                                position_0_next'length
                            );

                        when 1 =>

                            position_1_next := to_unsigned(
                                position_reg,
                                position_1_next'length
                            );

                        when 2 =>

                            position_2_next := to_unsigned(
                                position_reg,
                                position_2_next'length
                            );

                        when others =>

                            null;

                    end case;


                    if root_count_next < 7 then

                        root_count_next :=
                            root_count_next + 1;

                    end if;


                    ----------------------------------------------------------------
                    -- Positions 120 through 126 are omitted shortening
                    -- positions and must never contain errors.
                    ----------------------------------------------------------------
                    if position_reg >= C_PUF_BITS then

                        shortened_error_next := '1';

                    end if;

                end if;


                ----------------------------------------------------------------
                -- Save updated root information.
                ----------------------------------------------------------------
                error_position_0_reg <=
                    position_0_next;

                error_position_1_reg <=
                    position_1_next;

                error_position_2_reg <=
                    position_2_next;

                error_count_reg <=
                    root_count_next;

                shortened_position_error_reg <=
                    shortened_error_next;


                ----------------------------------------------------------------
                -- Final position: 126.
                ----------------------------------------------------------------
                if position_reg = C_BCH_PARENT_N - 1 then

                    cycle_count_reg <=
                        C_BCH_PARENT_N;

                    busy_reg <= '0';
                    done_reg <= '1';


                    if root_count_next =
                       locator_degree_reg
                    then

                        roots_match_next := '1';

                    else

                        roots_match_next := '0';

                    end if;

                    root_count_matches_degree_reg <=
                        roots_match_next;


                    if
                        locator_degree_reg <= C_BCH_T
                        and
                        roots_match_next = '1'
                        and
                        shortened_error_next = '0'
                    then

                        search_success_next := '1';

                    else

                        search_success_next := '0';

                    end if;

                    search_success_reg <=
                        search_success_next;

                else

                    ----------------------------------------------------------------
                    -- Move to the next position.
                    --
                    -- alpha^(-(i+1)) =
                    --     alpha^(-i) * alpha^-1
                    ----------------------------------------------------------------
                    x_reg <= gf_multiply(
                        x_reg,
                        C_ALPHA_INVERSE
                    );

                    position_reg <=
                        position_reg + 1;

                    cycle_count_reg <=
                        cycle_count_reg + 1;

                end if;

            end if;

        end if;

    end process;

end architecture rtl;
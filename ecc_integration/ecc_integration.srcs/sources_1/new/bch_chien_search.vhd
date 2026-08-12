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
        locator_4 : in t_gf128;
        locator_5 : in t_gf128;
        locator_6 : in t_gf128;
        locator_7 : in t_gf128;

        locator_degree : in unsigned(3 downto 0);

        busy : out std_logic;
        done : out std_logic;

        error_position_0 : out unsigned(6 downto 0);
        error_position_1 : out unsigned(6 downto 0);
        error_position_2 : out unsigned(6 downto 0);
        error_position_3 : out unsigned(6 downto 0);
        error_position_4 : out unsigned(6 downto 0);
        error_position_5 : out unsigned(6 downto 0);
        error_position_6 : out unsigned(6 downto 0);

        error_count : out unsigned(2 downto 0);

        root_count_matches_degree : out std_logic;
        shortened_position_error  : out std_logic;
        search_success             : out std_logic;

        current_position : out unsigned(6 downto 0);
        cycle_count      : out unsigned(7 downto 0)
    );
end entity bch_chien_search;


architecture rtl of bch_chien_search is

    type t_locator_array is
        array (0 to C_BCH_T) of t_gf128;

    type t_position_array is
        array (0 to C_BCH_T - 1) of unsigned(6 downto 0);

    constant C_ALPHA_INVERSE_POWER : t_locator_array := (
        0 => C_GF_ONE,
        1 => gf_alpha_power(126),
        2 => gf_alpha_power(125),
        3 => gf_alpha_power(124),
        4 => gf_alpha_power(123),
        5 => gf_alpha_power(122),
        6 => gf_alpha_power(121),
        7 => gf_alpha_power(120)
    );

    signal term_reg : t_locator_array := (
        0      => C_GF_ONE,
        others => C_GF_ZERO
    );

    signal locator_degree_reg :
        natural range 0 to 15 := 0;

    signal position_reg :
        natural range 0 to C_BCH_PARENT_N - 1 := 0;

    signal cycle_count_reg :
        natural range 0 to C_BCH_PARENT_N := 0;

    signal error_position_reg :
        t_position_array := (others => (others => '0'));

    signal error_count_reg :
        natural range 0 to C_BCH_T := 0;

    signal root_count_matches_degree_reg :
        std_logic := '0';

    signal shortened_position_error_reg :
        std_logic := '0';

    signal search_success_reg :
        std_logic := '0';

    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';

begin

    assert C_BCH_T = 7
        report "bch_chien_search requires C_BCH_T = 7"
        severity failure;

    busy <= busy_reg;
    done <= done_reg;

    error_position_0 <= error_position_reg(0);
    error_position_1 <= error_position_reg(1);
    error_position_2 <= error_position_reg(2);
    error_position_3 <= error_position_reg(3);
    error_position_4 <= error_position_reg(4);
    error_position_5 <= error_position_reg(5);
    error_position_6 <= error_position_reg(6);

    error_count <=
        to_unsigned(
            error_count_reg,
            error_count'length
        );

    root_count_matches_degree <=
        root_count_matches_degree_reg;

    shortened_position_error <=
        shortened_position_error_reg;

    search_success <=
        search_success_reg;

    current_position <=
        to_unsigned(
            position_reg,
            current_position'length
        );

    cycle_count <=
        to_unsigned(
            cycle_count_reg,
            cycle_count'length
        );


    process (clk)

        variable locator_result :
            t_gf128;

        variable root_count_next :
            natural range 0 to C_BCH_T;

        variable position_next :
            t_position_array;

        variable shortened_error_next :
            std_logic;

        variable roots_match_next :
            std_logic;

    begin

        if rising_edge(clk) then

            done_reg <= '0';

            if rst = '1' then

                term_reg <= (
                    0      => C_GF_ONE,
                    others => C_GF_ZERO
                );

                locator_degree_reg <= 0;

                position_reg <= 0;
                cycle_count_reg <= 0;

                error_position_reg <=
                    (others => (others => '0'));

                error_count_reg <= 0;

                root_count_matches_degree_reg <= '0';
                shortened_position_error_reg <= '0';
                search_success_reg <= '0';

                busy_reg <= '0';
                done_reg <= '0';


            elsif busy_reg = '0' then

                if start = '1' then

                    if to_integer(locator_degree) > C_BCH_T then

                        locator_degree_reg <=
                            to_integer(locator_degree);

                        error_position_reg <=
                            (others => (others => '0'));

                        error_count_reg <= 0;

                        root_count_matches_degree_reg <= '0';
                        shortened_position_error_reg <= '0';
                        search_success_reg <= '0';

                        position_reg <= 0;
                        cycle_count_reg <= 0;

                        busy_reg <= '0';
                        done_reg <= '1';

                    else

                        term_reg(0) <= locator_0;
                        term_reg(1) <= locator_1;
                        term_reg(2) <= locator_2;
                        term_reg(3) <= locator_3;
                        term_reg(4) <= locator_4;
                        term_reg(5) <= locator_5;
                        term_reg(6) <= locator_6;
                        term_reg(7) <= locator_7;

                        locator_degree_reg <=
                            to_integer(locator_degree);

                        position_reg <= 0;
                        cycle_count_reg <= 0;

                        error_position_reg <=
                            (others => (others => '0'));

                        error_count_reg <= 0;

                        root_count_matches_degree_reg <= '0';
                        shortened_position_error_reg <= '0';
                        search_success_reg <= '0';

                        busy_reg <= '1';

                    end if;

                end if;


            else

                locator_result := C_GF_ZERO;

                for j in 0 to C_BCH_T loop

                    if j <= locator_degree_reg then

                        locator_result :=
                            locator_result xor term_reg(j);

                    end if;

                end loop;


                root_count_next :=
                    error_count_reg;

                position_next :=
                    error_position_reg;

                shortened_error_next :=
                    shortened_position_error_reg;


                if locator_result = C_GF_ZERO then

                    if position_reg >= C_PUF_BITS then

                        shortened_error_next := '1';

                    elsif root_count_next < C_BCH_T then

                        position_next(root_count_next) :=
                            to_unsigned(
                                position_reg,
                                7
                            );

                        root_count_next :=
                            root_count_next + 1;

                    end if;

                end if;


                error_position_reg <=
                    position_next;

                error_count_reg <=
                    root_count_next;

                shortened_position_error_reg <=
                    shortened_error_next;


                if position_reg = C_BCH_PARENT_N - 1 then

                    cycle_count_reg <=
                        C_BCH_PARENT_N;

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
                        roots_match_next = '1'
                        and
                        shortened_error_next = '0'
                    then

                        search_success_reg <= '1';

                    else

                        search_success_reg <= '0';

                    end if;

                    busy_reg <= '0';
                    done_reg <= '1';


                else

                    for j in 1 to C_BCH_T loop

                        term_reg(j) <=
                            gf_multiply(
                                term_reg(j),
                                C_ALPHA_INVERSE_POWER(j)
                            );

                    end loop;

                    position_reg <=
                        position_reg + 1;

                    cycle_count_reg <=
                        cycle_count_reg + 1;

                end if;

            end if;

        end if;

    end process;

end architecture rtl;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.parameters.all;
use work.gf128_pkg.all;

entity bch_syndrome_calculator is
    port (
        clk : in std_logic;
        rst : in std_logic;

        start : in std_logic;

        received_codeword : in t_shortened_codeword;

        busy : out std_logic;
        done : out std_logic;

        syndrome_1  : out t_gf128;
        syndrome_2  : out t_gf128;
        syndrome_3  : out t_gf128;
        syndrome_4  : out t_gf128;
        syndrome_5  : out t_gf128;
        syndrome_6  : out t_gf128;
        syndrome_7  : out t_gf128;
        syndrome_8  : out t_gf128;
        syndrome_9  : out t_gf128;
        syndrome_10 : out t_gf128;
        syndrome_11 : out t_gf128;
        syndrome_12 : out t_gf128;
        syndrome_13 : out t_gf128;
        syndrome_14 : out t_gf128;

        syndromes_zero : out std_logic
    );
end entity bch_syndrome_calculator;


architecture rtl of bch_syndrome_calculator is

    type t_gf_array is
        array (1 to C_BCH_SYNDROMES) of t_gf128;

    constant C_ALPHA : t_gf_array := (
        1  => gf_alpha_power(1),
        2  => gf_alpha_power(2),
        3  => gf_alpha_power(3),
        4  => gf_alpha_power(4),
        5  => gf_alpha_power(5),
        6  => gf_alpha_power(6),
        7  => gf_alpha_power(7),
        8  => gf_alpha_power(8),
        9  => gf_alpha_power(9),
        10 => gf_alpha_power(10),
        11 => gf_alpha_power(11),
        12 => gf_alpha_power(12),
        13 => gf_alpha_power(13),
        14 => gf_alpha_power(14)
    );

    signal codeword_reg : t_shortened_codeword :=
        (others => '0');

    signal bit_index :
        natural range 0 to C_PUF_BITS - 1 := 0;

    signal syndrome_reg : t_gf_array :=
        (others => C_GF_ZERO);

    signal power_reg : t_gf_array :=
        (others => C_GF_ONE);

    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';

    signal syndromes_zero_reg : std_logic := '0';

begin

    assert C_BCH_SYNDROMES = 14
        report "bch_syndrome_calculator requires C_BCH_SYNDROMES = 14"
        severity failure;

    syndrome_1  <= syndrome_reg(1);
    syndrome_2  <= syndrome_reg(2);
    syndrome_3  <= syndrome_reg(3);
    syndrome_4  <= syndrome_reg(4);
    syndrome_5  <= syndrome_reg(5);
    syndrome_6  <= syndrome_reg(6);
    syndrome_7  <= syndrome_reg(7);
    syndrome_8  <= syndrome_reg(8);
    syndrome_9  <= syndrome_reg(9);
    syndrome_10 <= syndrome_reg(10);
    syndrome_11 <= syndrome_reg(11);
    syndrome_12 <= syndrome_reg(12);
    syndrome_13 <= syndrome_reg(13);
    syndrome_14 <= syndrome_reg(14);

    busy <= busy_reg;
    done <= done_reg;
    syndromes_zero <= syndromes_zero_reg;

    process (clk)

        variable next_syndrome : t_gf_array;
        variable all_zero      : std_logic;

    begin

        if rising_edge(clk) then

            done_reg <= '0';

            if rst = '1' then

                codeword_reg <= (others => '0');
                bit_index <= 0;

                syndrome_reg <=
                    (others => C_GF_ZERO);

                power_reg <=
                    (others => C_GF_ONE);

                busy_reg <= '0';
                done_reg <= '0';

                syndromes_zero_reg <= '0';

            elsif busy_reg = '0' then

                if start = '1' then

                    codeword_reg <= received_codeword;
                    bit_index <= 0;

                    syndrome_reg <=
                        (others => C_GF_ZERO);

                    power_reg <=
                        (others => C_GF_ONE);

                    busy_reg <= '1';
                    syndromes_zero_reg <= '0';

                end if;

            else

                next_syndrome := syndrome_reg;

                if codeword_reg(bit_index) = '1' then

                    for j in 1 to C_BCH_SYNDROMES loop

                        next_syndrome(j) :=
                            next_syndrome(j)
                            xor power_reg(j);

                    end loop;

                end if;

                syndrome_reg <= next_syndrome;

                if bit_index = C_PUF_BITS - 1 then

                    busy_reg <= '0';
                    done_reg <= '1';

                    all_zero := '1';

                    for j in 1 to C_BCH_SYNDROMES loop

                        if next_syndrome(j) /= C_GF_ZERO then
                            all_zero := '0';
                        end if;

                    end loop;

                    syndromes_zero_reg <= all_zero;

                else

                    bit_index <= bit_index + 1;

                    for j in 1 to C_BCH_SYNDROMES loop

                        power_reg(j) <=
                            gf_multiply(
                                power_reg(j),
                                C_ALPHA(j)
                            );

                    end loop;

                end if;

            end if;

        end if;

    end process;

end architecture rtl;
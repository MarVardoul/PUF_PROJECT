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

        syndrome_1 : out t_gf128;
        syndrome_2 : out t_gf128;
        syndrome_3 : out t_gf128;
        syndrome_4 : out t_gf128;
        syndrome_5 : out t_gf128;
        syndrome_6 : out t_gf128;

        syndromes_zero : out std_logic
    );
end entity bch_syndrome_calculator;


architecture rtl of bch_syndrome_calculator is

    --------------------------------------------------------------------
    -- One syndrome is calculated for each root alpha^j,
    -- where j = 1, 2, ..., 6.
    --
    -- For received polynomial:
    --
    --     r(x) = r_0 + r_1*x + ... + r_119*x^119
    --
    -- syndrome j is:
    --
    --     S_j = sum r_i * alpha^(i*j)
    --------------------------------------------------------------------

    constant C_ALPHA_1 : t_gf128 := gf_alpha_power(1);
    constant C_ALPHA_2 : t_gf128 := gf_alpha_power(2);
    constant C_ALPHA_3 : t_gf128 := gf_alpha_power(3);
    constant C_ALPHA_4 : t_gf128 := gf_alpha_power(4);
    constant C_ALPHA_5 : t_gf128 := gf_alpha_power(5);
    constant C_ALPHA_6 : t_gf128 := gf_alpha_power(6);

    signal codeword_reg : t_shortened_codeword :=
        (others => '0');

    signal bit_index :
        natural range 0 to C_PUF_BITS - 1 := 0;

    signal syndrome_1_reg : t_gf128 := C_GF_ZERO;
    signal syndrome_2_reg : t_gf128 := C_GF_ZERO;
    signal syndrome_3_reg : t_gf128 := C_GF_ZERO;
    signal syndrome_4_reg : t_gf128 := C_GF_ZERO;
    signal syndrome_5_reg : t_gf128 := C_GF_ZERO;
    signal syndrome_6_reg : t_gf128 := C_GF_ZERO;

    --------------------------------------------------------------------
    -- At bit position i, these registers contain:
    --
    -- power_1 = alpha^(i*1)
    -- power_2 = alpha^(i*2)
    -- ...
    -- power_6 = alpha^(i*6)
    --------------------------------------------------------------------

    signal power_1_reg : t_gf128 := C_GF_ONE;
    signal power_2_reg : t_gf128 := C_GF_ONE;
    signal power_3_reg : t_gf128 := C_GF_ONE;
    signal power_4_reg : t_gf128 := C_GF_ONE;
    signal power_5_reg : t_gf128 := C_GF_ONE;
    signal power_6_reg : t_gf128 := C_GF_ONE;

    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';

    signal syndromes_zero_reg : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------

    syndrome_1 <= syndrome_1_reg;
    syndrome_2 <= syndrome_2_reg;
    syndrome_3 <= syndrome_3_reg;
    syndrome_4 <= syndrome_4_reg;
    syndrome_5 <= syndrome_5_reg;
    syndrome_6 <= syndrome_6_reg;

    busy <= busy_reg;
    done <= done_reg;

    syndromes_zero <= syndromes_zero_reg;


    --------------------------------------------------------------------
    -- Sequential syndrome calculation
    --
    -- One codeword bit is processed per clock cycle.
    --
    -- Total calculation time:
    --
    --     120 clock cycles after start is accepted
    --------------------------------------------------------------------

    process (clk)

        variable next_syndrome_1 : t_gf128;
        variable next_syndrome_2 : t_gf128;
        variable next_syndrome_3 : t_gf128;
        variable next_syndrome_4 : t_gf128;
        variable next_syndrome_5 : t_gf128;
        variable next_syndrome_6 : t_gf128;

    begin

        if rising_edge(clk) then

            -- done is a one-clock pulse
            done_reg <= '0';

            if rst = '1' then

                codeword_reg <= (others => '0');
                bit_index    <= 0;

                syndrome_1_reg <= C_GF_ZERO;
                syndrome_2_reg <= C_GF_ZERO;
                syndrome_3_reg <= C_GF_ZERO;
                syndrome_4_reg <= C_GF_ZERO;
                syndrome_5_reg <= C_GF_ZERO;
                syndrome_6_reg <= C_GF_ZERO;

                power_1_reg <= C_GF_ONE;
                power_2_reg <= C_GF_ONE;
                power_3_reg <= C_GF_ONE;
                power_4_reg <= C_GF_ONE;
                power_5_reg <= C_GF_ONE;
                power_6_reg <= C_GF_ONE;

                busy_reg <= '0';
                done_reg <= '0';

                syndromes_zero_reg <= '0';

            elsif busy_reg = '0' then

                --------------------------------------------------------
                -- Accept a new calculation request
                --------------------------------------------------------

                if start = '1' then

                    codeword_reg <= received_codeword;
                    bit_index    <= 0;

                    syndrome_1_reg <= C_GF_ZERO;
                    syndrome_2_reg <= C_GF_ZERO;
                    syndrome_3_reg <= C_GF_ZERO;
                    syndrome_4_reg <= C_GF_ZERO;
                    syndrome_5_reg <= C_GF_ZERO;
                    syndrome_6_reg <= C_GF_ZERO;

                    -- At bit position zero:
                    --
                    -- alpha^(0*j) = 1
                    power_1_reg <= C_GF_ONE;
                    power_2_reg <= C_GF_ONE;
                    power_3_reg <= C_GF_ONE;
                    power_4_reg <= C_GF_ONE;
                    power_5_reg <= C_GF_ONE;
                    power_6_reg <= C_GF_ONE;

                    busy_reg <= '1';

                    syndromes_zero_reg <= '0';

                end if;

            else

                --------------------------------------------------------
                -- Begin with current accumulated syndromes
                --------------------------------------------------------

                next_syndrome_1 := syndrome_1_reg;
                next_syndrome_2 := syndrome_2_reg;
                next_syndrome_3 := syndrome_3_reg;
                next_syndrome_4 := syndrome_4_reg;
                next_syndrome_5 := syndrome_5_reg;
                next_syndrome_6 := syndrome_6_reg;

                --------------------------------------------------------
                -- In a binary BCH code, the coefficient is either
                -- zero or one.
                --
                -- When r_i = 1, add alpha^(i*j) to syndrome j.
                -- Addition in GF(2^7) is XOR.
                --------------------------------------------------------

                if codeword_reg(bit_index) = '1' then

                    next_syndrome_1 :=
                        next_syndrome_1 xor power_1_reg;

                    next_syndrome_2 :=
                        next_syndrome_2 xor power_2_reg;

                    next_syndrome_3 :=
                        next_syndrome_3 xor power_3_reg;

                    next_syndrome_4 :=
                        next_syndrome_4 xor power_4_reg;

                    next_syndrome_5 :=
                        next_syndrome_5 xor power_5_reg;

                    next_syndrome_6 :=
                        next_syndrome_6 xor power_6_reg;

                end if;

                syndrome_1_reg <= next_syndrome_1;
                syndrome_2_reg <= next_syndrome_2;
                syndrome_3_reg <= next_syndrome_3;
                syndrome_4_reg <= next_syndrome_4;
                syndrome_5_reg <= next_syndrome_5;
                syndrome_6_reg <= next_syndrome_6;

                --------------------------------------------------------
                -- Final input bit
                --------------------------------------------------------

                if bit_index = C_PUF_BITS - 1 then

                    busy_reg <= '0';
                    done_reg <= '1';

                    if
                        next_syndrome_1 = C_GF_ZERO and
                        next_syndrome_2 = C_GF_ZERO and
                        next_syndrome_3 = C_GF_ZERO and
                        next_syndrome_4 = C_GF_ZERO and
                        next_syndrome_5 = C_GF_ZERO and
                        next_syndrome_6 = C_GF_ZERO
                    then
                        syndromes_zero_reg <= '1';
                    else
                        syndromes_zero_reg <= '0';
                    end if;

                else

                    ----------------------------------------------------
                    -- Advance to the next codeword bit
                    ----------------------------------------------------

                    bit_index <= bit_index + 1;

                    -- alpha^(i*j) becomes alpha^((i+1)*j)
                    power_1_reg <= gf_multiply(
                        power_1_reg,
                        C_ALPHA_1
                    );

                    power_2_reg <= gf_multiply(
                        power_2_reg,
                        C_ALPHA_2
                    );

                    power_3_reg <= gf_multiply(
                        power_3_reg,
                        C_ALPHA_3
                    );

                    power_4_reg <= gf_multiply(
                        power_4_reg,
                        C_ALPHA_4
                    );

                    power_5_reg <= gf_multiply(
                        power_5_reg,
                        C_ALPHA_5
                    );

                    power_6_reg <= gf_multiply(
                        power_6_reg,
                        C_ALPHA_6
                    );

                end if;

            end if;

        end if;

    end process;

end architecture rtl;
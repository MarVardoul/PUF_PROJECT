library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package gf128_pkg is

    --------------------------------------------------------------------
    -- GF(2^7) element
    --
    -- Primitive polynomial:
    --
    --     p(x) = x^7 + x^3 + 1
    --
    -- Polynomial representation:
    --
    --     element(0) = coefficient of x^0
    --     element(6) = coefficient of x^6
    --------------------------------------------------------------------
    subtype t_gf128 is std_logic_vector(6 downto 0);

    constant C_GF_ZERO : t_gf128 := "0000000";
    constant C_GF_ONE  : t_gf128 := "0000001";

    --------------------------------------------------------------------
    -- Function declarations only
    --------------------------------------------------------------------
    function gf_add (
        a : t_gf128;
        b : t_gf128
    ) return t_gf128;

    function gf_xtime (
        a : t_gf128
    ) return t_gf128;

    function gf_multiply (
        a : t_gf128;
        b : t_gf128
    ) return t_gf128;

    function gf_alpha_power (
        exponent : integer
    ) return t_gf128;

    function gf_power (
        a        : t_gf128;
        exponent : natural
    ) return t_gf128;

    function gf_inverse (
        a : t_gf128
    ) return t_gf128;

    function gf_divide (
        numerator   : t_gf128;
        denominator : t_gf128
    ) return t_gf128;

end package gf128_pkg;


package body gf128_pkg is

    --------------------------------------------------------------------
    -- Addition in GF(2^7)
    --------------------------------------------------------------------
    function gf_add (
        a : t_gf128;
        b : t_gf128
    ) return t_gf128 is
    begin
        return a xor b;
    end function gf_add;


    --------------------------------------------------------------------
    -- Multiply by alpha = x.
    --
    -- When the x^7 coefficient appears, reduce using:
    --
    --     x^7 = x^3 + 1
    --
    -- Therefore the reduction vector is:
    --
    --     0001001
    --------------------------------------------------------------------
    function gf_xtime (
        a : t_gf128
    ) return t_gf128 is

        variable shifted_result : t_gf128;

    begin

        shifted_result := a(5 downto 0) & '0';

        if a(6) = '1' then
            shifted_result :=
                shifted_result xor "0001001";
        end if;

        return shifted_result;

    end function gf_xtime;


    --------------------------------------------------------------------
    -- General GF multiplication
    --
    -- Fixed seven-iteration loop, suitable for synthesis.
    --------------------------------------------------------------------
    function gf_multiply (
        a : t_gf128;
        b : t_gf128
    ) return t_gf128 is

        variable result_value :
            t_gf128 := C_GF_ZERO;

        variable multiplicand :
            t_gf128 := a;

        variable multiplier :
            t_gf128 := b;

    begin

        for iteration in 0 to 6 loop

            if multiplier(0) = '1' then
                result_value :=
                    result_value xor multiplicand;
            end if;

            multiplicand :=
                gf_xtime(multiplicand);

            multiplier :=
                '0' & multiplier(6 downto 1);

        end loop;

        return result_value;

    end function gf_multiply;


    --------------------------------------------------------------------
    -- Calculate alpha^exponent.
    --
    -- The nonzero elements of GF(2^7) have period 127.
    --
    -- The loop has fixed bounds so that Vivado can synthesize it.
    --------------------------------------------------------------------
    function gf_alpha_power (
        exponent : integer
    ) return t_gf128 is

        variable reduced_exponent :
            integer range 0 to 126;

        variable result_value :
            t_gf128 := C_GF_ONE;

    begin

        reduced_exponent := exponent mod 127;

        for iteration in 0 to 126 loop

            if iteration < reduced_exponent then
                result_value :=
                    gf_xtime(result_value);
            end if;

        end loop;

        return result_value;

    end function gf_alpha_power;


    --------------------------------------------------------------------
    -- General exponentiation.
    --
    -- This implementation uses repeated squaring and always performs
    -- seven iterations.
    --
    -- Exponents used by this BCH implementation are in the range
    -- 0 through 127.
    --------------------------------------------------------------------
    function gf_power (
        a        : t_gf128;
        exponent : natural
    ) return t_gf128 is

        variable result_value :
            t_gf128 := C_GF_ONE;

        variable base_value :
            t_gf128 := a;

        variable exponent_bits :
            unsigned(6 downto 0);

    begin

        assert exponent <= 127
            report
                "gf_power exponent exceeds supported range 0..127"
            severity failure;

        exponent_bits :=
            to_unsigned(exponent, exponent_bits'length);

        for bit_index in 0 to 6 loop

            if exponent_bits(bit_index) = '1' then

                result_value := gf_multiply(
                    result_value,
                    base_value
                );

            end if;

            base_value := gf_multiply(
                base_value,
                base_value
            );

        end loop;

        return result_value;

    end function gf_power;


    --------------------------------------------------------------------
    -- Multiplicative inverse
    --
    -- For a nonzero element a:
    --
    --     a^-1 = a^126
    --------------------------------------------------------------------
    function gf_inverse (
        a : t_gf128
    ) return t_gf128 is
    begin

        assert a /= C_GF_ZERO
            report
                "gf_inverse called with zero"
            severity failure;

        return gf_power(a, 126);

    end function gf_inverse;


    --------------------------------------------------------------------
    -- GF division
    --------------------------------------------------------------------
    function gf_divide (
        numerator   : t_gf128;
        denominator : t_gf128
    ) return t_gf128 is
    begin

        assert denominator /= C_GF_ZERO
            report
                "gf_divide called with zero denominator"
            severity failure;

        if numerator = C_GF_ZERO then

            return C_GF_ZERO;

        else

            return gf_multiply(
                numerator,
                gf_inverse(denominator)
            );

        end if;

    end function gf_divide;

end package body gf128_pkg;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package parameters is

    constant C_PUF_BITS     : positive := 120;
    constant C_SECRET_BITS  : positive := 99;

    constant C_BCH_PARENT_N : positive := 127;
    constant C_BCH_PARENT_K : positive := 106;
    constant C_BCH_T        : positive := 3;

    constant C_SHORTENED_BITS : positive :=
        C_BCH_PARENT_N - C_PUF_BITS;

    subtype t_puf_response is
        std_logic_vector(C_PUF_BITS - 1 downto 0);

    subtype t_helper_data is
        std_logic_vector(C_PUF_BITS - 1 downto 0);

    subtype t_shortened_codeword is
        std_logic_vector(C_PUF_BITS - 1 downto 0);

    subtype t_secret is
        std_logic_vector(C_SECRET_BITS - 1 downto 0);

end package;

package body parameters is
end package body;
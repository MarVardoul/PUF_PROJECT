library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package parameters is

    ----------------------------------------------------------------
    -- PUF size
    ----------------------------------------------------------------
    constant C_PUF_BITS : positive := 120;

    ----------------------------------------------------------------
    -- BCH parameters
    --
    -- Parent code:
    --     BCH(127,78), t = 7
    --
    -- Shortened by 7 bits:
    --     BCH(120,71), t = 7
    ----------------------------------------------------------------
    constant C_BCH_PARENT_N : positive := 127;
    constant C_BCH_PARENT_K : positive := 78;

    constant C_BCH_T : positive := 7;

    -- Number of syndromes required by a t-error BCH decoder
    constant C_BCH_SYNDROMES : positive :=
        2 * C_BCH_T;

    ----------------------------------------------------------------
    -- Shortening
    ----------------------------------------------------------------
    constant C_SHORTENED_BITS : positive :=
        C_BCH_PARENT_N - C_PUF_BITS;

    -- 78 - 7 = 71 useful secret bits
    constant C_SECRET_BITS : positive :=
        C_BCH_PARENT_K - C_SHORTENED_BITS;

    ----------------------------------------------------------------
    -- Common types
    ----------------------------------------------------------------
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
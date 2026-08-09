library ieee;
use ieee.std_logic_1164.all;

library work;
use work.parameters.all;

entity hd_xor is
    port (
        puf_response   : in  t_puf_response;
        helper_data    : in  t_helper_data;
        noisy_codeword : out t_shortened_codeword
    );
end entity hd_xor;

architecture rtl of hd_xor is
begin

    noisy_codeword <= puf_response xor helper_data;

end architecture rtl;
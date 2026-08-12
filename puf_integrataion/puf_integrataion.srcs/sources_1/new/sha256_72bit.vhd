library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sha256_72bit is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        start     : in  std_logic;
        secret_in : in  std_logic_vector(70 downto 0);
        digest    : out std_logic_vector(255 downto 0);
        busy      : out std_logic;
        done      : out std_logic
    );
end entity sha256_72bit;

architecture rtl of sha256_72bit is

    subtype word32_t is unsigned(31 downto 0);
    type word_array_t is array (0 to 63) of word32_t;

    type state_t is (
        IDLE,
        EXPAND,
        ROUND_STATE,
        FINISH
    );

    constant K : word_array_t := (
        unsigned'(x"428A2F98"), unsigned'(x"71374491"),
        unsigned'(x"B5C0FBCF"), unsigned'(x"E9B5DBA5"),
        unsigned'(x"3956C25B"), unsigned'(x"59F111F1"),
        unsigned'(x"923F82A4"), unsigned'(x"AB1C5ED5"),
        unsigned'(x"D807AA98"), unsigned'(x"12835B01"),
        unsigned'(x"243185BE"), unsigned'(x"550C7DC3"),
        unsigned'(x"72BE5D74"), unsigned'(x"80DEB1FE"),
        unsigned'(x"9BDC06A7"), unsigned'(x"C19BF174"),
        unsigned'(x"E49B69C1"), unsigned'(x"EFBE4786"),
        unsigned'(x"0FC19DC6"), unsigned'(x"240CA1CC"),
        unsigned'(x"2DE92C6F"), unsigned'(x"4A7484AA"),
        unsigned'(x"5CB0A9DC"), unsigned'(x"76F988DA"),
        unsigned'(x"983E5152"), unsigned'(x"A831C66D"),
        unsigned'(x"B00327C8"), unsigned'(x"BF597FC7"),
        unsigned'(x"C6E00BF3"), unsigned'(x"D5A79147"),
        unsigned'(x"06CA6351"), unsigned'(x"14292967"),
        unsigned'(x"27B70A85"), unsigned'(x"2E1B2138"),
        unsigned'(x"4D2C6DFC"), unsigned'(x"53380D13"),
        unsigned'(x"650A7354"), unsigned'(x"766A0ABB"),
        unsigned'(x"81C2C92E"), unsigned'(x"92722C85"),
        unsigned'(x"A2BFE8A1"), unsigned'(x"A81A664B"),
        unsigned'(x"C24B8B70"), unsigned'(x"C76C51A3"),
        unsigned'(x"D192E819"), unsigned'(x"D6990624"),
        unsigned'(x"F40E3585"), unsigned'(x"106AA070"),
        unsigned'(x"19A4C116"), unsigned'(x"1E376C08"),
        unsigned'(x"2748774C"), unsigned'(x"34B0BCB5"),
        unsigned'(x"391C0CB3"), unsigned'(x"4ED8AA4A"),
        unsigned'(x"5B9CCA4F"), unsigned'(x"682E6FF3"),
        unsigned'(x"748F82EE"), unsigned'(x"78A5636F"),
        unsigned'(x"84C87814"), unsigned'(x"8CC70208"),
        unsigned'(x"90BEFFFA"), unsigned'(x"A4506CEB"),
        unsigned'(x"BEF9A3F7"), unsigned'(x"C67178F2")
    );

    constant H0 : word32_t := unsigned'(x"6A09E667");
    constant H1 : word32_t := unsigned'(x"BB67AE85");
    constant H2 : word32_t := unsigned'(x"3C6EF372");
    constant H3 : word32_t := unsigned'(x"A54FF53A");
    constant H4 : word32_t := unsigned'(x"510E527F");
    constant H5 : word32_t := unsigned'(x"9B05688C");
    constant H6 : word32_t := unsigned'(x"1F83D9AB");
    constant H7 : word32_t := unsigned'(x"5BE0CD19");

    function rotr(
        x : word32_t;
        n : natural
    ) return word32_t is
    begin
        return rotate_right(x, n);
    end function;

    function ch(
        x : word32_t;
        y : word32_t;
        z : word32_t
    ) return word32_t is
    begin
        return (x and y) xor ((not x) and z);
    end function;

    function maj(
        x : word32_t;
        y : word32_t;
        z : word32_t
    ) return word32_t is
    begin
        return (x and y) xor
               (x and z) xor
               (y and z);
    end function;

    function big_sigma_0(
        x : word32_t
    ) return word32_t is
    begin
        return rotr(x, 2) xor
               rotr(x, 13) xor
               rotr(x, 22);
    end function;

    function big_sigma_1(
        x : word32_t
    ) return word32_t is
    begin
        return rotr(x, 6) xor
               rotr(x, 11) xor
               rotr(x, 25);
    end function;

    function small_sigma_0(
        x : word32_t
    ) return word32_t is
    begin
        return rotr(x, 7) xor
               rotr(x, 18) xor
               shift_right(x, 3);
    end function;

    function small_sigma_1(
        x : word32_t
    ) return word32_t is
    begin
        return rotr(x, 17) xor
               rotr(x, 19) xor
               shift_right(x, 10);
    end function;

    signal state_reg : state_t := IDLE;

    signal w_reg : word_array_t :=
        (others => (others => '0'));

    signal expand_index :
        integer range 16 to 63 := 16;

    signal round_index :
        integer range 0 to 63 := 0;

    signal a_reg : word32_t := (others => '0');
    signal b_reg : word32_t := (others => '0');
    signal c_reg : word32_t := (others => '0');
    signal d_reg : word32_t := (others => '0');
    signal e_reg : word32_t := (others => '0');
    signal f_reg : word32_t := (others => '0');
    signal g_reg : word32_t := (others => '0');
    signal h_reg : word32_t := (others => '0');

    signal digest_reg :
        std_logic_vector(255 downto 0) :=
        (others => '0');

    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';

begin

    digest <= digest_reg;
    busy   <= busy_reg;
    done   <= done_reg;

    process(clk)

        variable message_72 :
            std_logic_vector(71 downto 0);

        variable t1 :
            word32_t;

        variable t2 :
            word32_t;

        variable new_a :
            word32_t;

        variable new_e :
            word32_t;

    begin

        if rising_edge(clk) then

            done_reg <= '0';

            if rst = '1' then

                state_reg <= IDLE;

                w_reg <=
                    (others => (others => '0'));

                expand_index <= 16;
                round_index  <= 0;

                a_reg <= (others => '0');
                b_reg <= (others => '0');
                c_reg <= (others => '0');
                d_reg <= (others => '0');
                e_reg <= (others => '0');
                f_reg <= (others => '0');
                g_reg <= (others => '0');
                h_reg <= (others => '0');

                digest_reg <= (others => '0');

                busy_reg <= '0';
                done_reg <= '0';

            else

                case state_reg is

                    when IDLE =>

                        busy_reg <= '0';

                        if start = '1' then

                            busy_reg <= '1';

                            message_72 :=
                                '0' & secret_in;

                            w_reg(0) <=
                                unsigned(
                                    message_72(71 downto 40)
                                );

                            w_reg(1) <=
                                unsigned(
                                    message_72(39 downto 8)
                                );

                            w_reg(2) <=
                                unsigned(
                                    message_72(7 downto 0)
                                    & '1'
                                    & "00000000000000000000000"
                                );

                            for i in 3 to 14 loop
                                w_reg(i) <=
                                    (others => '0');
                            end loop;

                            w_reg(15) <=
                                to_unsigned(72, 32);

                            a_reg <= H0;
                            b_reg <= H1;
                            c_reg <= H2;
                            d_reg <= H3;
                            e_reg <= H4;
                            f_reg <= H5;
                            g_reg <= H6;
                            h_reg <= H7;

                            expand_index <= 16;
                            round_index  <= 0;

                            state_reg <= EXPAND;

                        end if;

                    when EXPAND =>

                        w_reg(expand_index) <=
                            small_sigma_1(
                                w_reg(expand_index - 2)
                            )
                            +
                            w_reg(expand_index - 7)
                            +
                            small_sigma_0(
                                w_reg(expand_index - 15)
                            )
                            +
                            w_reg(expand_index - 16);

                        if expand_index = 63 then

                            round_index <= 0;
                            state_reg <= ROUND_STATE;

                        else

                            expand_index <=
                                expand_index + 1;

                        end if;

                    when ROUND_STATE =>

                        t1 :=
                            h_reg
                            +
                            big_sigma_1(e_reg)
                            +
                            ch(
                                e_reg,
                                f_reg,
                                g_reg
                            )
                            +
                            K(round_index)
                            +
                            w_reg(round_index);

                        t2 :=
                            big_sigma_0(a_reg)
                            +
                            maj(
                                a_reg,
                                b_reg,
                                c_reg
                            );

                        new_a :=
                            t1 + t2;

                        new_e :=
                            d_reg + t1;

                        h_reg <= g_reg;
                        g_reg <= f_reg;
                        f_reg <= e_reg;
                        e_reg <= new_e;

                        d_reg <= c_reg;
                        c_reg <= b_reg;
                        b_reg <= a_reg;
                        a_reg <= new_a;

                        if round_index = 63 then

                            digest_reg <=
                                std_logic_vector(
                                    H0 + new_a
                                )
                                &
                                std_logic_vector(
                                    H1 + a_reg
                                )
                                &
                                std_logic_vector(
                                    H2 + b_reg
                                )
                                &
                                std_logic_vector(
                                    H3 + c_reg
                                )
                                &
                                std_logic_vector(
                                    H4 + new_e
                                )
                                &
                                std_logic_vector(
                                    H5 + e_reg
                                )
                                &
                                std_logic_vector(
                                    H6 + f_reg
                                )
                                &
                                std_logic_vector(
                                    H7 + g_reg
                                );

                            state_reg <= FINISH;

                        else

                            round_index <=
                                round_index + 1;

                        end if;

                    when FINISH =>

                        busy_reg <= '0';
                        done_reg <= '1';

                        state_reg <= IDLE;

                end case;

            end if;

        end if;

    end process;

end architecture rtl;
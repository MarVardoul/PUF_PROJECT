library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity puf_egress_trailer is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;

        puf_enable   : in  std_logic;
        puf_id_valid : in  std_logic;
        puf_id       : in  std_logic_vector(255 downto 0);

        in_data      : in  std_logic_vector(7 downto 0);
        in_valid     : in  std_logic;
        in_last      : in  std_logic;
        in_ready     : out std_logic;

        out_data     : out std_logic_vector(7 downto 0);
        out_valid    : out std_logic;
        out_last     : out std_logic;
        out_ready    : in  std_logic
    );
end entity puf_egress_trailer;

architecture rtl of puf_egress_trailer is

    subtype byte_t is std_logic_vector(7 downto 0);
    subtype crc_t is unsigned(31 downto 0);

    type state_t is (
        IDLE,
        BYPASS,
        TAGGED,
        TRAILER,
        FCS,
        DRAIN
    );

    type holdback_t is array (0 to 3) of byte_t;

    signal state : state_t := IDLE;

    signal holdback :
        holdback_t := (others => (others => '0'));

    signal hold_count :
        integer range 0 to 4 := 0;

    signal puf_id_latched :
        std_logic_vector(255 downto 0) := (others => '0');

    signal crc_reg :
        crc_t := (others => '1');

    signal fcs_reg :
        crc_t := (others => '0');

    signal trailer_index :
        integer range 0 to 39 := 0;

    signal fcs_index :
        integer range 0 to 3 := 0;

    signal out_data_reg :
        byte_t := (others => '0');

    signal out_valid_reg :
        std_logic := '0';

    signal out_last_reg :
        std_logic := '0';

    signal out_slot_available :
        std_logic;

    signal in_ready_internal :
        std_logic;

    function crc32_update_byte(
        constant crc_in    : crc_t;
        constant data_byte : byte_t
    ) return crc_t is

        constant POLY_C :
            crc_t := x"EDB88320";

        variable crc :
            crc_t := crc_in;

        variable mix :
            std_logic;

    begin

        for b in 0 to 7 loop

            mix :=
                crc(0) xor data_byte(b);

            crc :=
                shift_right(crc, 1);

            if mix = '1' then

                crc :=
                    crc xor POLY_C;

            end if;

        end loop;

        return crc;

    end function;

    function trailer_byte(
        constant index    : natural;
        constant id_value : std_logic_vector(255 downto 0)
    ) return byte_t is

        variable result :
            byte_t := (others => '0');

    begin

        case index is

            when 0 =>
                result := x"50";

            when 1 =>
                result := x"55";

            when 2 =>
                result := x"46";

            when 3 =>
                result := x"31";

            when 4 =>
                result := x"01";

            when 5 =>
                result := x"01";

            when 6 =>
                result := x"00";

            when 7 =>
                result := x"20";

            when 8 to 39 =>

                result :=
                    id_value(
                        255 - 8 * (index - 8)
                        downto
                        248 - 8 * (index - 8)
                    );

            when others =>

                result :=
                    (others => '0');

        end case;

        return result;

    end function;

    function fcs_byte(
        constant fcs_value : crc_t;
        constant index     : natural
    ) return byte_t is

        variable result :
            byte_t := (others => '0');

    begin

        case index is

            when 0 =>

                result :=
                    std_logic_vector(
                        fcs_value(7 downto 0)
                    );

            when 1 =>

                result :=
                    std_logic_vector(
                        fcs_value(15 downto 8)
                    );

            when 2 =>

                result :=
                    std_logic_vector(
                        fcs_value(23 downto 16)
                    );

            when 3 =>

                result :=
                    std_logic_vector(
                        fcs_value(31 downto 24)
                    );

            when others =>

                result :=
                    (others => '0');

        end case;

        return result;

    end function;

begin

    out_slot_available <=
        '1'
        when
            out_valid_reg = '0'
            or
            out_ready = '1'
        else
        '0';

    process (
        state,
        hold_count,
        out_slot_available,
        out_valid_reg,
        rst
    )
    begin

        in_ready_internal <=
            '0';

        if rst = '0' then

            case state is

                when IDLE =>

                    if out_valid_reg = '0' then

                        in_ready_internal <=
                            '1';

                    end if;

                when BYPASS =>

                    in_ready_internal <=
                        out_slot_available;

                when TAGGED =>

                    if hold_count < 4 then

                        in_ready_internal <=
                            '1';

                    else

                        in_ready_internal <=
                            out_slot_available;

                    end if;

                when others =>

                    in_ready_internal <=
                        '0';

            end case;

        end if;

    end process;

    in_ready <=
        in_ready_internal;

    out_data <=
        out_data_reg;

    out_valid <=
        out_valid_reg;

    out_last <=
        out_last_reg;

    process (clk)

        variable crc_next :
            crc_t;

        variable trailer_data :
            byte_t;

    begin

        if rising_edge(clk) then

            if rst = '1' then

                state <=
                    IDLE;

                holdback <=
                    (others => (others => '0'));

                hold_count <=
                    0;

                puf_id_latched <=
                    (others => '0');

                crc_reg <=
                    (others => '1');

                fcs_reg <=
                    (others => '0');

                trailer_index <=
                    0;

                fcs_index <=
                    0;

                out_data_reg <=
                    (others => '0');

                out_valid_reg <=
                    '0';

                out_last_reg <=
                    '0';

            else

                if out_valid_reg = '1'
                   and out_ready = '1' then

                    out_valid_reg <=
                        '0';

                end if;

                case state is

                    when IDLE =>

                        hold_count <=
                            0;

                        if in_valid = '1'
                           and in_ready_internal = '1' then

                            if puf_enable = '1'
                               and puf_id_valid = '1' then

                                puf_id_latched <=
                                    puf_id;

                                crc_reg <=
                                    (others => '1');

                                if in_last = '1' then

                                    trailer_index <=
                                        0;

                                    state <=
                                        TRAILER;

                                else

                                    holdback(0) <=
                                        in_data;

                                    hold_count <=
                                        1;

                                    state <=
                                        TAGGED;

                                end if;

                            else

                                out_data_reg <=
                                    in_data;

                                out_valid_reg <=
                                    '1';

                                out_last_reg <=
                                    in_last;

                                if in_last = '1' then

                                    state <=
                                        DRAIN;

                                else

                                    state <=
                                        BYPASS;

                                end if;

                            end if;

                        end if;

                    when BYPASS =>

                        if in_valid = '1'
                           and in_ready_internal = '1' then

                            out_data_reg <=
                                in_data;

                            out_valid_reg <=
                                '1';

                            out_last_reg <=
                                in_last;

                            if in_last = '1' then

                                state <=
                                    DRAIN;

                            end if;

                        end if;

                    when TAGGED =>

                        if in_valid = '1'
                           and in_ready_internal = '1' then

                            if hold_count < 4 then

                                if in_last = '1' then

                                    hold_count <=
                                        0;

                                    trailer_index <=
                                        0;

                                    state <=
                                        TRAILER;

                                else

                                    holdback(hold_count) <=
                                        in_data;

                                    hold_count <=
                                        hold_count + 1;

                                end if;

                            else

                                out_data_reg <=
                                    holdback(0);

                                out_valid_reg <=
                                    '1';

                                out_last_reg <=
                                    '0';

                                crc_next :=
                                    crc32_update_byte(
                                        crc_reg,
                                        holdback(0)
                                    );

                                crc_reg <=
                                    crc_next;

                                holdback(0) <=
                                    holdback(1);

                                holdback(1) <=
                                    holdback(2);

                                holdback(2) <=
                                    holdback(3);

                                holdback(3) <=
                                    in_data;

                                if in_last = '1' then

                                    hold_count <=
                                        0;

                                    trailer_index <=
                                        0;

                                    state <=
                                        TRAILER;

                                end if;

                            end if;

                        end if;

                    when TRAILER =>

                        if out_slot_available = '1' then

                            trailer_data :=
                                trailer_byte(
                                    trailer_index,
                                    puf_id_latched
                                );

                            out_data_reg <=
                                trailer_data;

                            out_valid_reg <=
                                '1';

                            out_last_reg <=
                                '0';

                            crc_next :=
                                crc32_update_byte(
                                    crc_reg,
                                    trailer_data
                                );

                            crc_reg <=
                                crc_next;

                            if trailer_index = 39 then

                                fcs_reg <=
                                    not crc_next;

                                fcs_index <=
                                    0;

                                state <=
                                    FCS;

                            else

                                trailer_index <=
                                    trailer_index + 1;

                            end if;

                        end if;

                    when FCS =>

                        if out_slot_available = '1' then

                            out_data_reg <=
                                fcs_byte(
                                    fcs_reg,
                                    fcs_index
                                );

                            out_valid_reg <=
                                '1';

                            if fcs_index = 3 then

                                out_last_reg <=
                                    '1';

                                state <=
                                    DRAIN;

                            else

                                out_last_reg <=
                                    '0';

                                fcs_index <=
                                    fcs_index + 1;

                            end if;

                        end if;

                    when DRAIN =>

                        if out_valid_reg = '1'
                           and out_ready = '1' then

                            state <=
                                IDLE;

                        elsif out_valid_reg = '0' then

                            state <=
                                IDLE;

                        end if;

                    when others =>

                        state <=
                            IDLE;

                end case;

            end if;

        end if;

    end process;

end architecture rtl;
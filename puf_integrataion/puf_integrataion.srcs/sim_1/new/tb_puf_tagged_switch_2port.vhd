library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_puf_tagged_switch_2port is
end entity;

architecture sim of tb_puf_tagged_switch_2port is

    constant CLK_PERIOD_C         : time := 10 ns;
    constant MAX_CAPTURE_BYTES_C  : positive := 128;
    constant CAPTURE_WIDTH_C      : positive := MAX_CAPTURE_BYTES_C * 8;

    subtype byte_t   is std_logic_vector(7 downto 0);
    subtype frame_t  is std_logic_vector(511 downto 0);
    subtype puf_id_t is std_logic_vector(255 downto 0);
    subtype crc_t    is unsigned(31 downto 0);

    constant FRAME_A_C : frame_t :=
        x"020000000002"
      & x"020000000001"
      & x"88B5"
      & x"000102030405060708090A0B0C0D0E0F"
      & x"101112131415161718191A1B1C1D1E1F"
      & x"202122232425262728292A2B2C2D"
      & x"824A8FB4";

    constant FRAME_B_C : frame_t :=
        x"020000000001"
      & x"020000000002"
      & x"88B5"
      & x"808182838485868788898A8B8C8D8E8F"
      & x"909192939495969798999A9B9C9D9E9F"
      & x"A0A1A2A3A4A5A6A7A8A9AAABACAD"
      & x"5ECFE359";

    constant PUF_ID_C : puf_id_t :=
        x"56F3E37B10793CE963732744E11FE183"
      & x"2201A85C8EEA5A2C2F64A641335A3BD7";

    constant FRAME_A_CRC_C : crc_t := x"B48F4A82";
    constant FRAME_B_CRC_C : crc_t := x"59E3CF5E";

    signal core_clk     : std_logic := '0';
    signal reset_p      : std_logic := '1';

    signal puf_enable   : std_logic := '0';
    signal puf_id_valid : std_logic := '0';
    signal puf_id       : puf_id_t := (others => '0');

    signal rx_data_i    : std_logic_vector(15 downto 0) := (others => '0');
    signal rx_write_i   : std_logic_vector(1 downto 0) := (others => '0');
    signal rx_last_i    : std_logic_vector(1 downto 0) := (others => '0');
    signal rx_error_i   : std_logic_vector(1 downto 0) := (others => '0');

    signal tx_data_o    : std_logic_vector(15 downto 0);
    signal tx_valid_o   : std_logic_vector(1 downto 0);
    signal tx_last_o    : std_logic_vector(1 downto 0);
    signal tx_ready_i   : std_logic_vector(1 downto 0) := (others => '0');

    signal backpressure_port1 :
        std_logic := '0';

    signal mon_count_0 :
        integer range 0 to 255 := 0;

    signal mon_count_1 :
        integer range 0 to 255 := 0;

    signal mon_last_count_0 :
        integer range 0 to 255 := 0;

    signal mon_last_count_1 :
        integer range 0 to 255 := 0;

    signal mon_last_pos_0 :
        integer range -1 to 255 := -1;

    signal mon_last_pos_1 :
        integer range -1 to 255 := -1;

    signal mon_done_0 :
        std_logic := '0';

    signal mon_done_1 :
        std_logic := '0';

    signal mon_data_0 :
        std_logic_vector(CAPTURE_WIDTH_C-1 downto 0)
        := (others => '0');

    signal mon_data_1 :
        std_logic_vector(CAPTURE_WIDTH_C-1 downto 0)
        := (others => '0');

    function frame_byte(
        constant frame_data : frame_t;
        constant index      : natural
    ) return byte_t is

        variable result :
            byte_t;

    begin

        result :=
            frame_data(
                511 - 8 * index downto
                504 - 8 * index
            );

        return result;

    end function;

    function capture_byte(
        constant capture_data :
            std_logic_vector(CAPTURE_WIDTH_C-1 downto 0);
        constant index :
            natural
    ) return byte_t is

        variable result :
            byte_t;

    begin

        result :=
            capture_data(
                CAPTURE_WIDTH_C - 1 - 8 * index downto
                CAPTURE_WIDTH_C - 8 - 8 * index
            );

        return result;

    end function;

    function trailer_byte(
        constant index    : natural;
        constant id_value : puf_id_t
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
                        255 - 8 * (index - 8) downto
                        248 - 8 * (index - 8)
                    );

            when others =>

                result :=
                    (others => '0');

        end case;

        return result;

    end function;

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

    function crc32_first_60(
        constant frame_data : frame_t
    ) return crc_t is

        variable crc :
            crc_t := (others => '1');

    begin

        for i in 0 to 59 loop

            crc :=
                crc32_update_byte(
                    crc,
                    frame_byte(
                        frame_data,
                        i
                    )
                );

        end loop;

        return not crc;

    end function;

    function crc32_tagged(
        constant frame_data : frame_t;
        constant id_value   : puf_id_t
    ) return crc_t is

        variable crc :
            crc_t := (others => '1');

    begin

        for i in 0 to 59 loop

            crc :=
                crc32_update_byte(
                    crc,
                    frame_byte(
                        frame_data,
                        i
                    )
                );

        end loop;

        for i in 0 to 39 loop

            crc :=
                crc32_update_byte(
                    crc,
                    trailer_byte(
                        i,
                        id_value
                    )
                );

        end loop;

        return not crc;

    end function;

    function expected_tagged_byte(
        constant frame_data : frame_t;
        constant id_value   : puf_id_t;
        constant index      : natural
    ) return byte_t is

        variable crc :
            crc_t;

        variable result :
            byte_t;

    begin

        crc :=
            crc32_tagged(
                frame_data,
                id_value
            );

        if index <= 59 then

            result :=
                frame_byte(
                    frame_data,
                    index
                );

        elsif index <= 99 then

            result :=
                trailer_byte(
                    index - 60,
                    id_value
                );

        elsif index = 100 then

            result :=
                std_logic_vector(
                    crc(7 downto 0)
                );

        elsif index = 101 then

            result :=
                std_logic_vector(
                    crc(15 downto 8)
                );

        elsif index = 102 then

            result :=
                std_logic_vector(
                    crc(23 downto 16)
                );

        elsif index = 103 then

            result :=
                std_logic_vector(
                    crc(31 downto 24)
                );

        else

            result :=
                (others => '0');

        end if;

        return result;

    end function;

begin

    core_clk <=
        not core_clk after CLK_PERIOD_C / 2;

    DUT :
        entity work.puf_tagged_switch_2port
        generic map (
            CORE_CLK_HZ_G => 100_000_000
        )
        port map (
            core_clk     => core_clk,
            reset_p      => reset_p,

            puf_enable   => puf_enable,
            puf_id_valid => puf_id_valid,
            puf_id       => puf_id,

            rx_data_i    => rx_data_i,
            rx_write_i   => rx_write_i,
            rx_last_i    => rx_last_i,
            rx_error_i   => rx_error_i,

            tx_data_o    => tx_data_o,
            tx_valid_o   => tx_valid_o,
            tx_last_o    => tx_last_o,
            tx_ready_i   => tx_ready_i
        );

    READY_CONTROL :
        process (core_clk)

            variable count :
                integer range 0 to 9 := 0;

        begin

            if falling_edge(core_clk) then

                if reset_p = '1' then

                    tx_ready_i <=
                        (others => '0');

                    count := 0;

                else

                    tx_ready_i(0) <=
                        '1';

                    if backpressure_port1 = '0' then

                        tx_ready_i(1) <=
                            '1';

                        count := 0;

                    else

                        if count = 2 or
                           count = 3 or
                           count = 7 then

                            tx_ready_i(1) <=
                                '0';

                        else

                            tx_ready_i(1) <=
                                '1';

                        end if;

                        if count = 9 then

                            count := 0;

                        else

                            count :=
                                count + 1;

                        end if;

                    end if;

                end if;

            end if;

        end process;

    MONITOR :
        process (core_clk)
        begin

            if rising_edge(core_clk) then

                if reset_p = '1' then

                    mon_count_0 <=
                        0;

                    mon_count_1 <=
                        0;

                    mon_last_count_0 <=
                        0;

                    mon_last_count_1 <=
                        0;

                    mon_last_pos_0 <=
                        -1;

                    mon_last_pos_1 <=
                        -1;

                    mon_done_0 <=
                        '0';

                    mon_done_1 <=
                        '0';

                    mon_data_0 <=
                        (others => '0');

                    mon_data_1 <=
                        (others => '0');

                else

                    if tx_valid_o(0) = '1'
                       and tx_ready_i(0) = '1' then

                        if mon_count_0 <
                           MAX_CAPTURE_BYTES_C then

                            mon_data_0(
                                CAPTURE_WIDTH_C - 1 - 8 * mon_count_0
                                downto
                                CAPTURE_WIDTH_C - 8 - 8 * mon_count_0
                            ) <=
                                tx_data_o(7 downto 0);

                        end if;

                        if tx_last_o(0) = '1' then

                            mon_last_count_0 <=
                                mon_last_count_0 + 1;

                            mon_last_pos_0 <=
                                mon_count_0;

                            mon_done_0 <=
                                '1';

                        end if;

                        mon_count_0 <=
                            mon_count_0 + 1;

                    end if;

                    if tx_valid_o(1) = '1'
                       and tx_ready_i(1) = '1' then

                        if mon_count_1 <
                           MAX_CAPTURE_BYTES_C then

                            mon_data_1(
                                CAPTURE_WIDTH_C - 1 - 8 * mon_count_1
                                downto
                                CAPTURE_WIDTH_C - 8 - 8 * mon_count_1
                            ) <=
                                tx_data_o(15 downto 8);

                        end if;

                        if tx_last_o(1) = '1' then

                            mon_last_count_1 <=
                                mon_last_count_1 + 1;

                            mon_last_pos_1 <=
                                mon_count_1;

                            mon_done_1 <=
                                '1';

                        end if;

                        mon_count_1 <=
                            mon_count_1 + 1;

                    end if;

                end if;

            end if;

        end process;

    OUTPUT_PROTOCOL_CHECK :
        process (core_clk)

            variable stalled_0 :
                boolean := false;

            variable stalled_1 :
                boolean := false;

            variable held_data_0 :
                byte_t := (others => '0');

            variable held_data_1 :
                byte_t := (others => '0');

            variable held_last_0 :
                std_logic := '0';

            variable held_last_1 :
                std_logic := '0';

        begin

            if rising_edge(core_clk) then

                if reset_p = '1' then

                    stalled_0 :=
                        false;

                    stalled_1 :=
                        false;

                else

                    if stalled_0 then

                        assert tx_valid_o(0) = '1'
                            report
                                "Port 0 valid dropped while stalled"
                            severity failure;

                        assert tx_data_o(7 downto 0) =
                               held_data_0
                            report
                                "Port 0 data changed while stalled"
                            severity failure;

                        assert tx_last_o(0) =
                               held_last_0
                            report
                                "Port 0 last changed while stalled"
                            severity failure;

                    end if;

                    if stalled_1 then

                        assert tx_valid_o(1) = '1'
                            report
                                "Port 1 valid dropped while stalled"
                            severity failure;

                        assert tx_data_o(15 downto 8) =
                               held_data_1
                            report
                                "Port 1 data changed while stalled"
                            severity failure;

                        assert tx_last_o(1) =
                               held_last_1
                            report
                                "Port 1 last changed while stalled"
                            severity failure;

                    end if;

                    stalled_0 :=
                        tx_valid_o(0) = '1'
                        and
                        tx_ready_i(0) = '0';

                    stalled_1 :=
                        tx_valid_o(1) = '1'
                        and
                        tx_ready_i(1) = '0';

                    if stalled_0 then

                        held_data_0 :=
                            tx_data_o(7 downto 0);

                        held_last_0 :=
                            tx_last_o(0);

                    end if;

                    if stalled_1 then

                        held_data_1 :=
                            tx_data_o(15 downto 8);

                        held_last_1 :=
                            tx_last_o(1);

                    end if;

                end if;

            end if;

        end process;

    STIM :
        process

            procedure reset_dut is
            begin

                wait until falling_edge(core_clk);

                reset_p <=
                    '1';

                rx_data_i <=
                    (others => '0');

                rx_write_i <=
                    (others => '0');

                rx_last_i <=
                    (others => '0');

                rx_error_i <=
                    (others => '0');

                for i in 1 to 100 loop

                    wait until rising_edge(core_clk);

                end loop;

                wait until falling_edge(core_clk);

                reset_p <=
                    '0';

                for i in 1 to 200 loop

                    wait until rising_edge(core_clk);

                end loop;

            end procedure;

            procedure send_frame(
                constant port_number :
                    in integer;
                constant frame_data :
                    in frame_t
            ) is
            begin

                for i in 0 to 63 loop

                    wait until falling_edge(core_clk);

                    rx_data_i(
                        8 * port_number + 7
                        downto
                        8 * port_number
                    ) <=
                        frame_byte(
                            frame_data,
                            i
                        );

                    rx_write_i(port_number) <=
                        '1';

                    if i = 63 then

                        rx_last_i(port_number) <=
                            '1';

                    else

                        rx_last_i(port_number) <=
                            '0';

                    end if;

                    wait until rising_edge(core_clk);
                    wait until falling_edge(core_clk);

                    rx_write_i(port_number) <=
                        '0';

                    rx_last_i(port_number) <=
                        '0';

                    if i /= 63 then

                        for j in 1 to 7 loop

                            wait until rising_edge(core_clk);

                        end loop;

                    end if;

                end loop;

                rx_data_i(
                    8 * port_number + 7
                    downto
                    8 * port_number
                ) <=
                    (others => '0');

            end procedure;

            procedure wait_for_output(
                constant port_number :
                    in integer
            ) is
            begin

                for i in 1 to 20000 loop

                    wait until rising_edge(core_clk);

                    if port_number = 0 then

                        if mon_done_0 = '1' then

                            wait until rising_edge(core_clk);

                            return;

                        end if;

                    else

                        if mon_done_1 = '1' then

                            wait until rising_edge(core_clk);

                            return;

                        end if;

                    end if;

                end loop;

                assert false
                    report
                        "Timeout waiting for complete output frame"
                    severity failure;

            end procedure;

            procedure check_port1_bypass(
                constant frame_data :
                    in frame_t;
                constant test_name :
                    in string
            ) is
            begin

                assert mon_count_0 = 0
                    report
                        test_name &
                        ": unexpected output on Port 0"
                    severity failure;

                assert mon_count_1 = 64
                    report
                        test_name &
                        ": Port 1 bypass length was not 64 bytes"
                    severity failure;

                assert mon_last_count_1 = 1
                    report
                        test_name &
                        ": Port 1 did not contain exactly one last"
                    severity failure;

                assert mon_last_pos_1 = 63
                    report
                        test_name &
                        ": Port 1 last was not on byte 63"
                    severity failure;

                for i in 0 to 63 loop

                    assert
                        capture_byte(
                            mon_data_1,
                            i
                        ) =
                        frame_byte(
                            frame_data,
                            i
                        )
                    report
                        test_name &
                        ": Port 1 bypass mismatch at byte " &
                        integer'image(i)
                    severity failure;

                end loop;

                report
                    test_name &
                    ": PORT 0 TO PORT 1 BYPASS PASSED"
                    severity note;

            end procedure;

            procedure check_port1_tagged(
                constant frame_data :
                    in frame_t;
                constant id_value :
                    in puf_id_t;
                constant test_name :
                    in string
            ) is
            begin

                assert mon_count_0 = 0
                    report
                        test_name &
                        ": unexpected output on Port 0"
                    severity failure;

                assert mon_count_1 = 104
                    report
                        test_name &
                        ": tagged Port 1 length was not 104 bytes"
                    severity failure;

                assert mon_last_count_1 = 1
                    report
                        test_name &
                        ": tagged Port 1 did not contain exactly one last"
                    severity failure;

                assert mon_last_pos_1 = 103
                    report
                        test_name &
                        ": tagged Port 1 last was not on byte 103"
                    severity failure;

                for i in 0 to 103 loop

                    assert
                        capture_byte(
                            mon_data_1,
                            i
                        ) =
                        expected_tagged_byte(
                            frame_data,
                            id_value,
                            i
                        )
                    report
                        test_name &
                        ": tagged Port 1 mismatch at byte " &
                        integer'image(i)
                    severity failure;

                end loop;

                report
                    test_name &
                    ": PORT 0 TO PORT 1 TAGGED PASSED"
                    severity note;

            end procedure;

            procedure check_port0_bypass(
                constant frame_data :
                    in frame_t;
                constant test_name :
                    in string
            ) is
            begin

                assert mon_count_1 = 0
                    report
                        test_name &
                        ": unexpected output on Port 1"
                    severity failure;

                assert mon_count_0 = 64
                    report
                        test_name &
                        ": Port 0 output length was not 64 bytes"
                    severity failure;

                assert mon_last_count_0 = 1
                    report
                        test_name &
                        ": Port 0 did not contain exactly one last"
                    severity failure;

                assert mon_last_pos_0 = 63
                    report
                        test_name &
                        ": Port 0 last was not on byte 63"
                    severity failure;

                for i in 0 to 63 loop

                    assert
                        capture_byte(
                            mon_data_0,
                            i
                        ) =
                        frame_byte(
                            frame_data,
                            i
                        )
                    report
                        test_name &
                        ": Port 0 data mismatch at byte " &
                        integer'image(i)
                    severity failure;

                end loop;

                report
                    test_name &
                    ": PORT 1 TO PORT 0 UNCHANGED PASSED"
                    severity note;

            end procedure;

        begin

            puf_enable <=
                '0';

            puf_id_valid <=
                '0';

            puf_id <=
                PUF_ID_C;

            backpressure_port1 <=
                '0';

            assert
                crc32_first_60(FRAME_A_C) =
                FRAME_A_CRC_C
            report
                "Reference CRC model failed FRAME_A"
            severity failure;

            assert
                crc32_first_60(FRAME_B_C) =
                FRAME_B_CRC_C
            report
                "Reference CRC model failed FRAME_B"
            severity failure;

            report
                "REFERENCE CRC MODEL PASSED"
                severity note;

            reset_dut;

            puf_enable <=
                '0';

            puf_id_valid <=
                '1';

            puf_id <=
                PUF_ID_C;

            backpressure_port1 <=
                '0';

            wait until rising_edge(core_clk);

            report
                "TEST 1: PC1 TO PC2 PUF DISABLED"
                severity note;

            send_frame(
                0,
                FRAME_A_C
            );

            wait_for_output(1);

            check_port1_bypass(
                FRAME_A_C,
                "TEST 1"
            );

            reset_dut;

            puf_enable <=
                '1';

            puf_id_valid <=
                '1';

            puf_id <=
                PUF_ID_C;

            backpressure_port1 <=
                '1';

            wait until rising_edge(core_clk);

            report
                "TEST 2: PC1 TO PC2 PUF ENABLED"
                severity note;

            send_frame(
                0,
                FRAME_A_C
            );

            wait_for_output(1);

            check_port1_tagged(
                FRAME_A_C,
                PUF_ID_C,
                "TEST 2"
            );

            reset_dut;

            puf_enable <=
                '1';

            puf_id_valid <=
                '1';

            puf_id <=
                PUF_ID_C;

            backpressure_port1 <=
                '0';

            wait until rising_edge(core_clk);

            report
                "TEST 3: PC2 TO PC1 MUST REMAIN UNCHANGED"
                severity note;

            send_frame(
                1,
                FRAME_B_C
            );

            wait_for_output(0);

            check_port0_bypass(
                FRAME_B_C,
                "TEST 3"
            );

            report
                "ALL PUF TAGGED SWITCH INTEGRATION TESTS PASSED"
                severity note;

            wait;

        end process;

end architecture;
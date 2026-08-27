library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_puf_egress_trailer is
end entity;

architecture sim of tb_puf_egress_trailer is

    constant CLK_PERIOD_C        : time := 10 ns;
    constant MAX_CAPTURE_BYTES_C : positive := 128;
    constant CAPTURE_WIDTH_C     : positive := MAX_CAPTURE_BYTES_C * 8;

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

    constant PUF_ID_A_C : puf_id_t :=
        x"000102030405060708090A0B0C0D0E0F"
      & x"101112131415161718191A1B1C1D1E1F";

    constant PUF_ID_B_C : puf_id_t :=
        x"FFEEDDCCBBAA99887766554433221100"
      & x"FFEEDDCCBBAA99887766554433221100";

    constant FRAME_A_CRC_C : crc_t := x"B48F4A82";
    constant FRAME_B_CRC_C : crc_t := x"59E3CF5E";

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';

    signal puf_enable   : std_logic := '0';
    signal puf_id_valid : std_logic := '0';
    signal puf_id       : puf_id_t := (others => '0');

    signal in_data      : byte_t := (others => '0');
    signal in_valid     : std_logic := '0';
    signal in_last      : std_logic := '0';
    signal in_ready     : std_logic;

    signal out_data     : byte_t;
    signal out_valid    : std_logic;
    signal out_last     : std_logic;
    signal out_ready    : std_logic := '0';

    signal backpressure_enable : std_logic := '0';

    signal mon_clear      : std_logic := '0';
    signal mon_count      : integer range 0 to 255 := 0;
    signal mon_last_count : integer range 0 to 255 := 0;
    signal mon_last_pos   : integer range -1 to 255 := -1;
    signal mon_done       : std_logic := '0';

    signal mon_data :
        std_logic_vector(CAPTURE_WIDTH_C-1 downto 0)
        := (others => '0');

    function frame_byte(
        constant frame_data : frame_t;
        constant index      : natural
    ) return byte_t is
        variable result : byte_t;
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
        constant index : natural
    ) return byte_t is
        variable result : byte_t;
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
        variable result : byte_t;
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
                result := x"00";

        end case;

        return result;

    end function;

    function crc32_update_byte(
        constant crc_in    : crc_t;
        constant data_byte : byte_t
    ) return crc_t is

        constant POLY_C : crc_t := x"EDB88320";

        variable crc : crc_t := crc_in;
        variable mix : std_logic;

    begin

        for b in 0 to 7 loop

            mix := crc(0) xor data_byte(b);

            crc := shift_right(crc, 1);

            if mix = '1' then
                crc := crc xor POLY_C;
            end if;

        end loop;

        return crc;

    end function;

    function crc32_first_60(
        constant frame_data : frame_t
    ) return crc_t is

        variable crc : crc_t := (others => '1');

    begin

        for i in 0 to 59 loop

            crc :=
                crc32_update_byte(
                    crc,
                    frame_byte(frame_data, i)
                );

        end loop;

        return not crc;

    end function;

    function crc32_tagged(
        constant frame_data : frame_t;
        constant id_value   : puf_id_t
    ) return crc_t is

        variable crc : crc_t := (others => '1');

    begin

        for i in 0 to 59 loop

            crc :=
                crc32_update_byte(
                    crc,
                    frame_byte(frame_data, i)
                );

        end loop;

        for i in 0 to 39 loop

            crc :=
                crc32_update_byte(
                    crc,
                    trailer_byte(i, id_value)
                );

        end loop;

        return not crc;

    end function;

    function expected_tagged_byte(
        constant frame_data : frame_t;
        constant id_value   : puf_id_t;
        constant index      : natural
    ) return byte_t is

        variable crc    : crc_t;
        variable result : byte_t;

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

            result := x"00";

        end if;

        return result;

    end function;

begin

    clk <=
        not clk after CLK_PERIOD_C / 2;

    DUT :
        entity work.puf_egress_trailer
        port map (
            clk          => clk,
            rst          => rst,

            puf_enable   => puf_enable,
            puf_id_valid => puf_id_valid,
            puf_id       => puf_id,

            in_data      => in_data,
            in_valid     => in_valid,
            in_last      => in_last,
            in_ready     => in_ready,

            out_data     => out_data,
            out_valid    => out_valid,
            out_last     => out_last,
            out_ready    => out_ready
        );

    READY_CONTROL :
        process (clk)

            variable count :
                integer range 0 to 9 := 0;

        begin

            if falling_edge(clk) then

                if rst = '1' then

                    out_ready <= '0';
                    count := 0;

                elsif backpressure_enable = '0' then

                    out_ready <= '1';
                    count := 0;

                else

                    if count = 2 or
                       count = 3 or
                       count = 7 then

                        out_ready <= '0';

                    else

                        out_ready <= '1';

                    end if;

                    if count = 9 then
                        count := 0;
                    else
                        count := count + 1;
                    end if;

                end if;

            end if;

        end process;

    MONITOR :
        process (clk)
        begin

            if rising_edge(clk) then

                if rst = '1' or
                   mon_clear = '1' then

                    mon_count      <= 0;
                    mon_last_count <= 0;
                    mon_last_pos   <= -1;
                    mon_done       <= '0';
                    mon_data       <= (others => '0');

                else

                    if out_valid = '1' and
                       out_ready = '1' then

                        if mon_count < MAX_CAPTURE_BYTES_C then

                            mon_data(
                                CAPTURE_WIDTH_C - 1 - 8 * mon_count
                                downto
                                CAPTURE_WIDTH_C - 8 - 8 * mon_count
                            ) <= out_data;

                        end if;

                        if out_last = '1' then

                            mon_last_count <=
                                mon_last_count + 1;

                            mon_last_pos <=
                                mon_count;

                            mon_done <=
                                '1';

                        end if;

                        mon_count <=
                            mon_count + 1;

                    end if;

                end if;

            end if;

        end process;

    OUTPUT_PROTOCOL_CHECK :
        process (clk)

            variable stalled :
                boolean := false;

            variable held_data :
                byte_t := (others => '0');

            variable held_last :
                std_logic := '0';

        begin

            if rising_edge(clk) then

                if rst = '1' then

                    stalled := false;

                else

                    if stalled then

                        assert out_valid = '1'
                            report
                                "Output valid dropped while stalled"
                            severity failure;

                        assert out_data = held_data
                            report
                                "Output data changed while stalled"
                            severity failure;

                        assert out_last = held_last
                            report
                                "Output last changed while stalled"
                            severity failure;

                    end if;

                    stalled :=
                        out_valid = '1' and
                        out_ready = '0';

                    if stalled then

                        held_data := out_data;
                        held_last := out_last;

                    end if;

                end if;

            end if;

        end process;

    STIM :
        process

            procedure reset_dut is
            begin

                wait until falling_edge(clk);

                rst      <= '1';
                in_valid <= '0';
                in_last  <= '0';
                in_data  <= (others => '0');

                for i in 1 to 10 loop
                    wait until rising_edge(clk);
                end loop;

                wait until falling_edge(clk);

                rst <= '0';

                for i in 1 to 5 loop
                    wait until rising_edge(clk);
                end loop;

            end procedure;

            procedure clear_monitor is
            begin

                wait until falling_edge(clk);

                mon_clear <= '1';

                wait until rising_edge(clk);
                wait until falling_edge(clk);

                mon_clear <= '0';

                wait until rising_edge(clk);

            end procedure;

            procedure send_frame(
                constant frame_data : in frame_t
            ) is
            begin

                for i in 0 to 63 loop

                    wait until falling_edge(clk);

                    in_data <=
                        frame_byte(
                            frame_data,
                            i
                        );

                    in_valid <=
                        '1';

                    if i = 63 then
                        in_last <= '1';
                    else
                        in_last <= '0';
                    end if;

                    loop

                        wait until rising_edge(clk);

                        exit when in_ready = '1';

                    end loop;

                end loop;

                wait until falling_edge(clk);

                in_valid <= '0';
                in_last  <= '0';
                in_data  <= (others => '0');

            end procedure;

            procedure send_frame_with_control_change(
                constant frame_data : in frame_t;
                constant new_enable : in std_logic;
                constant new_valid  : in std_logic;
                constant new_id     : in puf_id_t
            ) is
            begin

                for i in 0 to 63 loop

                    wait until falling_edge(clk);

                    in_data <=
                        frame_byte(
                            frame_data,
                            i
                        );

                    in_valid <=
                        '1';

                    if i = 63 then
                        in_last <= '1';
                    else
                        in_last <= '0';
                    end if;

                    loop

                        wait until rising_edge(clk);

                        exit when in_ready = '1';

                    end loop;

                    if i = 20 then

                        puf_enable   <= new_enable;
                        puf_id_valid <= new_valid;
                        puf_id       <= new_id;

                    end if;

                end loop;

                wait until falling_edge(clk);

                in_valid <= '0';
                in_last  <= '0';
                in_data  <= (others => '0');

            end procedure;

            procedure wait_for_output is
            begin

                for i in 1 to 20000 loop

                    wait until rising_edge(clk);

                    if mon_done = '1' then

                        wait until rising_edge(clk);

                        return;

                    end if;

                end loop;

                assert false
                    report
                        "Timeout waiting for complete output frame"
                    severity failure;

            end procedure;

            procedure check_bypass(
                constant frame_data : in frame_t;
                constant test_name  : in string
            ) is
            begin

                assert mon_count = 64
                    report
                        test_name &
                        ": bypass output length was not 64 bytes"
                    severity failure;

                assert mon_last_count = 1
                    report
                        test_name &
                        ": bypass output did not contain exactly one last"
                    severity failure;

                assert mon_last_pos = 63
                    report
                        test_name &
                        ": bypass last was not on byte 63"
                    severity failure;

                for i in 0 to 63 loop

                    assert
                        capture_byte(
                            mon_data,
                            i
                        ) =
                        frame_byte(
                            frame_data,
                            i
                        )
                    report
                        test_name &
                        ": bypass data mismatch at byte " &
                        integer'image(i)
                    severity failure;

                end loop;

                report
                    test_name &
                    ": BYPASS PASSED"
                    severity note;

            end procedure;

            procedure check_tagged(
                constant frame_data : in frame_t;
                constant id_value   : in puf_id_t;
                constant test_name  : in string
            ) is
            begin

                assert mon_count = 104
                    report
                        test_name &
                        ": tagged output length was not 104 bytes"
                    severity failure;

                assert mon_last_count = 1
                    report
                        test_name &
                        ": tagged output did not contain exactly one last"
                    severity failure;

                assert mon_last_pos = 103
                    report
                        test_name &
                        ": tagged last was not on byte 103"
                    severity failure;

                for i in 0 to 103 loop

                    assert
                        capture_byte(
                            mon_data,
                            i
                        ) =
                        expected_tagged_byte(
                            frame_data,
                            id_value,
                            i
                        )
                    report
                        test_name &
                        ": tagged data mismatch at byte " &
                        integer'image(i)
                    severity failure;

                end loop;

                report
                    test_name &
                    ": TAGGED FRAME PASSED"
                    severity note;

            end procedure;

        begin

            puf_enable <= '0';
            puf_id_valid <= '0';
            puf_id <= (others => '0');
            backpressure_enable <= '0';

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
            clear_monitor;

            puf_enable <= '0';
            puf_id_valid <= '1';
            puf_id <= PUF_ID_A_C;
            backpressure_enable <= '0';

            wait until rising_edge(clk);

            report
                "TEST 1: PUF DISABLED BYPASS"
                severity note;

            send_frame(FRAME_A_C);

            wait_for_output;

            check_bypass(
                FRAME_A_C,
                "TEST 1"
            );

            reset_dut;
            clear_monitor;

            puf_enable <= '1';
            puf_id_valid <= '0';
            puf_id <= PUF_ID_A_C;
            backpressure_enable <= '0';

            wait until rising_edge(clk);

            report
                "TEST 2: INVALID PUF ID BYPASS"
                severity note;

            send_frame(FRAME_B_C);

            wait_for_output;

            check_bypass(
                FRAME_B_C,
                "TEST 2"
            );

            reset_dut;
            clear_monitor;

            puf_enable <= '1';
            puf_id_valid <= '1';
            puf_id <= PUF_ID_A_C;
            backpressure_enable <= '0';

            wait until rising_edge(clk);

            report
                "TEST 3: NORMAL TAGGED FRAME"
                severity note;

            send_frame(FRAME_A_C);

            wait_for_output;

            check_tagged(
                FRAME_A_C,
                PUF_ID_A_C,
                "TEST 3"
            );

            reset_dut;
            clear_monitor;

            puf_enable <= '1';
            puf_id_valid <= '1';
            puf_id <= PUF_ID_A_C;
            backpressure_enable <= '0';

            wait until rising_edge(clk);

            report
                "TEST 4: MID-FRAME CONTROL AND ID CHANGE"
                severity note;

            send_frame_with_control_change(
                FRAME_B_C,
                '0',
                '0',
                PUF_ID_B_C
            );

            wait_for_output;

            check_tagged(
                FRAME_B_C,
                PUF_ID_A_C,
                "TEST 4"
            );

            clear_monitor;

            wait until rising_edge(clk);

            report
                "TEST 5: CHANGED CONTROL APPLIES TO NEXT FRAME"
                severity note;

            send_frame(FRAME_A_C);

            wait_for_output;

            check_bypass(
                FRAME_A_C,
                "TEST 5"
            );

            reset_dut;
            clear_monitor;

            puf_enable <= '1';
            puf_id_valid <= '1';
            puf_id <= PUF_ID_B_C;
            backpressure_enable <= '1';

            wait until rising_edge(clk);

            report
                "TEST 6: TAGGED FRAME WITH BACKPRESSURE"
                severity note;

            send_frame(FRAME_B_C);

            wait_for_output;

            check_tagged(
                FRAME_B_C,
                PUF_ID_B_C,
                "TEST 6"
            );

            reset_dut;
            clear_monitor;

            puf_enable <= '0';
            puf_id_valid <= '1';
            puf_id <= PUF_ID_A_C;
            backpressure_enable <= '1';

            wait until rising_edge(clk);

            report
                "TEST 7: BYPASS WITH BACKPRESSURE"
                severity note;

            send_frame(FRAME_A_C);

            wait_for_output;

            check_bypass(
                FRAME_A_C,
                "TEST 7"
            );

            report
                "ALL PUF EGRESS TRAILER TESTS PASSED"
                severity note;

            wait;

        end process;

end architecture;
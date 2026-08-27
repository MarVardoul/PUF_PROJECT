library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.cfgbus_common.all;
use work.common_functions.all;
use work.ptp_types.all;
use work.switch_types.all;

entity tb_puf_rmii_switch_2port is
end entity tb_puf_rmii_switch_2port;

architecture tb of tb_puf_rmii_switch_2port is

    type byte_array_t is
        array (natural range <>) of std_logic_vector(7 downto 0);

    constant CRC_POLY_C :
        unsigned(31 downto 0) := x"EDB88320";

    constant PUF_ID_C :
        std_logic_vector(255 downto 0) :=
        x"000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F";

    function crc32_update(
        crc_in  : std_logic_vector(31 downto 0);
        data_in : std_logic_vector(7 downto 0)
    ) return std_logic_vector is

        variable c :
            unsigned(31 downto 0);

    begin

        c := unsigned(crc_in);

        for i in 0 to 7 loop

            if (c(0) xor data_in(i)) = '1' then

                c :=
                    shift_right(c, 1)
                    xor CRC_POLY_C;

            else

                c :=
                    shift_right(c, 1);

            end if;

        end loop;

        return std_logic_vector(c);

    end function;


    function make_frame
        return byte_array_t is

        variable f :
            byte_array_t(0 to 63);

        variable crc :
            std_logic_vector(31 downto 0);

    begin

        f :=
            (others => (others => '0'));

        f(0)  := x"FF";
        f(1)  := x"FF";
        f(2)  := x"FF";
        f(3)  := x"FF";
        f(4)  := x"FF";
        f(5)  := x"FF";

        f(6)  := x"02";
        f(7)  := x"00";
        f(8)  := x"00";
        f(9)  := x"00";
        f(10) := x"00";
        f(11) := x"01";

        f(12) := x"08";
        f(13) := x"00";

        for i in 14 to 59 loop

            f(i) :=
                std_logic_vector(
                    to_unsigned(i, 8)
                );

        end loop;

        crc :=
            x"FFFFFFFF";

        for i in 0 to 59 loop

            crc :=
                crc32_update(
                    crc,
                    f(i)
                );

        end loop;

        crc :=
            not crc;

        f(60) := crc(7 downto 0);
        f(61) := crc(15 downto 8);
        f(62) := crc(23 downto 16);
        f(63) := crc(31 downto 24);

        return f;

    end function;


    constant FRAME_C :
        byte_array_t(0 to 63) :=
        make_frame;


    function make_tagged_frame
        return byte_array_t is

        variable f :
            byte_array_t(0 to 103);

        variable crc :
            std_logic_vector(31 downto 0);

    begin

        f :=
            (others => (others => '0'));

        for i in 0 to 59 loop

            f(i) :=
                FRAME_C(i);

        end loop;

        f(60) := x"50";
        f(61) := x"55";
        f(62) := x"46";
        f(63) := x"31";
        f(64) := x"01";
        f(65) := x"01";
        f(66) := x"00";
        f(67) := x"20";

        for i in 0 to 31 loop

            f(68 + i) :=
                PUF_ID_C(
                    255 - 8 * i
                    downto
                    248 - 8 * i
                );

        end loop;

        crc :=
            x"FFFFFFFF";

        for i in 0 to 99 loop

            crc :=
                crc32_update(
                    crc,
                    f(i)
                );

        end loop;

        crc :=
            not crc;

        f(100) := crc(7 downto 0);
        f(101) := crc(15 downto 8);
        f(102) := crc(23 downto 16);
        f(103) := crc(31 downto 24);

        return f;

    end function;


    constant TAGGED_FRAME_C :
        byte_array_t(0 to 103) :=
        make_tagged_frame;


    signal core_clk :
        std_logic := '0';

    signal phy0_clk :
        std_logic := '0';

    signal phy1_clk :
        std_logic := '0';

    signal phy0_refclk_wire :
        std_logic;

    signal phy1_refclk_wire :
        std_logic;

    signal reset_p :
        std_logic := '1';

    signal puf_enable :
        std_logic := '0';

    signal puf_id_valid :
        std_logic := '0';

    signal puf_id :
        std_logic_vector(255 downto 0) :=
        PUF_ID_C;


    signal host0_to_dut_data :
        std_logic_vector(1 downto 0);

    signal host0_to_dut_en :
        std_logic;

    signal dut_to_host0_data :
        std_logic_vector(1 downto 0);

    signal dut_to_host0_en :
        std_logic;


    signal host1_to_dut_data :
        std_logic_vector(1 downto 0);

    signal host1_to_dut_en :
        std_logic;

    signal dut_to_host1_data :
        std_logic_vector(1 downto 0);

    signal dut_to_host1_en :
        std_logic;


    signal host0_rx_data :
        port_rx_m2s;

    signal host0_tx_data :
        port_tx_s2m;

    signal host0_tx_ctrl :
        port_tx_m2s;


    signal host1_rx_data :
        port_rx_m2s;

    signal host1_tx_data :
        port_tx_s2m;

    signal host1_tx_ctrl :
        port_tx_m2s;


    signal tap0_rx_data :
        port_rx_m2s;

    signal tap0_tx_data :
        port_tx_s2m;

    signal tap0_tx_ctrl :
        port_tx_m2s;


    constant PORT_COUNT_C :
        positive := 2;

    signal ref_ports_rx_data :
        array_rx_m2s(PORT_COUNT_C-1 downto 0);

    signal ref_ports_tx_data :
        array_tx_s2m(PORT_COUNT_C-1 downto 0);

    signal ref_ports_tx_ctrl :
        array_tx_m2s(PORT_COUNT_C-1 downto 0);


    signal source_bytes :
        natural := 0;

    signal source_frames :
        natural := 0;

    signal rmii_in_frames :
        natural := 0;

    signal rmii_in_symbols :
        natural := 0;

    signal tap_frames :
        natural := 0;

    signal tap_bytes :
        natural := 0;

    signal reference_frames :
        natural := 0;

    signal reference_bytes :
        natural := 0;

    signal dut_out_frames :
        natural := 0;

    signal dut_out_symbols :
        natural := 0;

    signal host1_frames :
        natural := 0;

    signal host1_bytes :
        natural := 0;

begin

    core_clk <=
        not core_clk after 5 ns;

    phy0_clk <=
        not phy0_clk after 10 ns;


    PHY1_CLOCK :
        process
        begin

            wait for 3 ns;

            loop

                phy1_clk <=
                    not phy1_clk;

                wait for 10 ns;

            end loop;

        end process;


    DUT :
        entity work.puf_rmii_switch_2port
        generic map (
            CORE_CLK_HZ_G =>
                100_000_000
        )
        port map (
            core_clk      => core_clk,
            reset_p       => reset_p,

            puf_enable    => puf_enable,
            puf_id_valid  => puf_id_valid,
            puf_id        => puf_id,

            phy0_refclk   => phy0_refclk_wire,
            phy0_rxd      => host0_to_dut_data,
            phy0_crs_dv   => host0_to_dut_en,
            phy0_txd      => dut_to_host0_data,
            phy0_tx_en    => dut_to_host0_en,

            phy1_refclk   => phy1_refclk_wire,
            phy1_rxd      => host1_to_dut_data,
            phy1_crs_dv   => host1_to_dut_en,
            phy1_txd      => dut_to_host1_data,
            phy1_tx_en    => dut_to_host1_en
        );


    HOST0_RMII :
        entity work.port_rmii
        generic map (
            MODE_CLKOUT =>
                true,

            MODE_CLKDDR =>
                true
        )
        port map (
            rmii_txd     => host0_to_dut_data,
            rmii_txen    => host0_to_dut_en,
            rmii_txer    => open,

            rmii_rxd     => dut_to_host0_data,
            rmii_rxen    => dut_to_host0_en,
            rmii_rxer    => '0',

            rmii_clkin   => phy0_clk,
            rmii_clkout  => phy0_refclk_wire,

            ref_time     => PORT_TIMEREF_NULL,

            rx_data      => host0_rx_data,
            tx_data      => host0_tx_data,
            tx_ctrl      => host0_tx_ctrl,

            force_10m    => '0',
            lock_refclk  => core_clk,
            reset_p      => reset_p
        );


    HOST1_RMII :
        entity work.port_rmii
        generic map (
            MODE_CLKOUT =>
                true,

            MODE_CLKDDR =>
                true
        )
        port map (
            rmii_txd     => host1_to_dut_data,
            rmii_txen    => host1_to_dut_en,
            rmii_txer    => open,

            rmii_rxd     => dut_to_host1_data,
            rmii_rxen    => dut_to_host1_en,
            rmii_rxer    => '0',

            rmii_clkin   => phy1_clk,
            rmii_clkout  => phy1_refclk_wire,

            ref_time     => PORT_TIMEREF_NULL,

            rx_data      => host1_rx_data,
            tx_data      => host1_tx_data,
            tx_ctrl      => host1_tx_ctrl,

            force_10m    => '0',
            lock_refclk  => core_clk,
            reset_p      => reset_p
        );


    TAP0_RMII :
        entity work.port_rmii
        generic map (
            MODE_CLKOUT =>
                false,

            MODE_CLKDDR =>
                true
        )
        port map (
            rmii_txd     => open,
            rmii_txen    => open,
            rmii_txer    => open,

            rmii_rxd     => host0_to_dut_data,
            rmii_rxen    => host0_to_dut_en,
            rmii_rxer    => '0',

            rmii_clkin   => phy0_refclk_wire,
            rmii_clkout  => open,

            ref_time     => PORT_TIMEREF_NULL,

            rx_data      => tap0_rx_data,
            tx_data      => tap0_tx_data,
            tx_ctrl      => tap0_tx_ctrl,

            force_10m    => '0',
            lock_refclk  => core_clk,
            reset_p      => reset_p
        );


    tap0_tx_data.data <=
        (others => '0');

    tap0_tx_data.valid <=
        '0';

    tap0_tx_data.last <=
        '0';


    host1_tx_data.data <=
        (others => '0');

    host1_tx_data.valid <=
        '0';

    host1_tx_data.last <=
        '0';


    ref_ports_rx_data(0) <=
        tap0_rx_data;


    ref_ports_rx_data(1).clk <=
        phy1_refclk_wire;

    ref_ports_rx_data(1).data <=
        (others => '0');

    ref_ports_rx_data(1).write <=
        '0';

    ref_ports_rx_data(1).last <=
        '0';

    ref_ports_rx_data(1).rxerr <=
        '0';

    ref_ports_rx_data(1).rate <=
        get_rate_word(100);

    ref_ports_rx_data(1).status <=
        STATUS_NULL;

    ref_ports_rx_data(1).tsof <=
        TSTAMP_DISABLED;

    ref_ports_rx_data(1).tfreq <=
        TFREQ_DISABLED;

    ref_ports_rx_data(1).reset_p <=
        reset_p;


    ref_ports_tx_ctrl(0).clk <=
        phy0_refclk_wire;

    ref_ports_tx_ctrl(0).ready <=
        '1';

    ref_ports_tx_ctrl(0).pstart <=
        '1';

    ref_ports_tx_ctrl(0).tnow <=
        TSTAMP_DISABLED;

    ref_ports_tx_ctrl(0).tfreq <=
        TFREQ_DISABLED;

    ref_ports_tx_ctrl(0).txerr <=
        '0';

    ref_ports_tx_ctrl(0).reset_p <=
        reset_p;


    ref_ports_tx_ctrl(1).clk <=
        phy1_refclk_wire;

    ref_ports_tx_ctrl(1).ready <=
        '1';

    ref_ports_tx_ctrl(1).pstart <=
        '1';

    ref_ports_tx_ctrl(1).tnow <=
        TSTAMP_DISABLED;

    ref_ports_tx_ctrl(1).tfreq <=
        TFREQ_DISABLED;

    ref_ports_tx_ctrl(1).txerr <=
        '0';

    ref_ports_tx_ctrl(1).reset_p <=
        reset_p;


    REFERENCE_SWITCH :
        entity work.switch_core
        generic map (
            DEV_ADDR        => CFGBUS_ADDR_NONE,
            CORE_CLK_HZ     => 100_000_000,

            SUPPORT_PAUSE   => false,
            SUPPORT_PTP     => false,
            SUPPORT_VLAN    => false,

            MISS_BCAST      => true,

            ALLOW_JUMBO     => false,
            ALLOW_RUNT      => false,
            ALLOW_PRECOMMIT => false,

            PORT_COUNT      => PORT_COUNT_C,
            PORTX_COUNT     => 0,

            DATAPATH_BYTES  => 4,

            IBUF_KBYTES     => 2,
            OBUF_KBYTES     => 4,
            IBUF_PACKETS    => 32,
            OBUF_PACKETS    => 32,

            MAC_TABLE_SIZE  => 64
        )
        port map (
            ports_rx_data =>
                ref_ports_rx_data,

            ports_tx_data =>
                ref_ports_tx_data,

            ports_tx_ctrl =>
                ref_ports_tx_ctrl,

            err_ports =>
                open,

            err_switch =>
                open,

            errvec_t =>
                open,

            cfg_cmd =>
                CFGBUS_CMD_NULL,

            cfg_ack =>
                open,

            log_txd =>
                open,

            scrub_req_t =>
                '0',

            core_clk =>
                core_clk,

            core_reset_p =>
                reset_p
        );


    SOURCE_MONITOR :
        process (host0_tx_ctrl.clk)
        begin

            if rising_edge(host0_tx_ctrl.clk) then

                if host0_tx_ctrl.reset_p = '1' then

                    source_bytes <=
                        0;

                    source_frames <=
                        0;

                elsif host0_tx_data.valid = '1'
                      and host0_tx_ctrl.ready = '1' then

                    source_bytes <=
                        source_bytes + 1;

                    if host0_tx_data.last = '1' then

                        source_frames <=
                            source_frames + 1;

                        report
                            "CHECK SOURCE PASS: HOST0 accepted complete 64-byte logical frame, frame=" &
                            integer'image(source_frames + 1);

                    end if;

                end if;

            end if;

        end process;


    RMII_INPUT_MONITOR :
        process (phy0_refclk_wire)

            variable active_v :
                boolean := false;

            variable symbols_v :
                natural := 0;

        begin

            if falling_edge(phy0_refclk_wire) then

                if host0_to_dut_en = '1' then

                    if not active_v then

                        active_v :=
                            true;

                        symbols_v :=
                            0;

                        report
                            "CHECK A: HOST0 -> DUT RMII frame START";

                    end if;

                    symbols_v :=
                        symbols_v + 1;

                elsif active_v then

                    active_v :=
                        false;

                    rmii_in_frames <=
                        rmii_in_frames + 1;

                    rmii_in_symbols <=
                        symbols_v;

                    report
                        "CHECK A: HOST0 -> DUT RMII frame END, symbols=" &
                        integer'image(symbols_v);

                    assert
                        symbols_v = 288
                        report
                        "CHECK A FAIL: Expected 288 RMII symbols, received " &
                        integer'image(symbols_v)
                        severity failure;

                    report
                        "CHECK A PASS: Physical RMII frame length is exactly 72 bytes";

                end if;

            end if;

        end process;


    TAP_MONITOR :
        process

            variable index_v :
                natural range 0 to 255 := 0;

        begin

            wait until
                falling_edge(tap0_rx_data.clk);

            wait for
                100 ps;

            if tap0_rx_data.reset_p = '1' then

                index_v :=
                    0;

            elsif tap0_rx_data.write = '1' then

                assert
                    tap0_rx_data.rxerr = '0'
                    report
                    "CHECK B FAIL: Passive RMII decoder asserted RX error"
                    severity failure;

                assert
                    index_v <= FRAME_C'high
                    report
                    "CHECK B FAIL: Passive decoder produced too many bytes"
                    severity failure;

                assert
                    tap0_rx_data.data = FRAME_C(index_v)
                    report
                    "CHECK B FAIL: Byte mismatch at index " &
                    integer'image(index_v) &
                    " received=" &
                    to_hstring(tap0_rx_data.data) &
                    " expected=" &
                    to_hstring(FRAME_C(index_v))
                    severity failure;

                tap_bytes <=
                    tap_bytes + 1;

                if tap0_rx_data.last = '1' then

                    assert
                        index_v = 63
                        report
                        "CHECK B FAIL: Passive decoder frame length=" &
                        integer'image(index_v + 1)
                        severity failure;

                    tap_frames <=
                        tap_frames + 1;

                    report
                        "CHECK B PASS: Independent port_rmii decoded exact 64-byte frame including FCS";

                    index_v :=
                        0;

                else

                    index_v :=
                        index_v + 1;

                end if;

            end if;

        end process;


    REFERENCE_SWITCH_MONITOR :
        process (ref_ports_tx_ctrl(1).clk)

            variable index_v :
                natural range 0 to 255 := 0;

        begin

            if rising_edge(ref_ports_tx_ctrl(1).clk) then

                if reset_p = '1' then

                    index_v :=
                        0;

                elsif ref_ports_tx_data(1).valid = '1'
                      and ref_ports_tx_ctrl(1).ready = '1' then

                    assert
                        index_v <= FRAME_C'high
                        report
                        "CHECK C FAIL: Reference switch produced too many bytes"
                        severity failure;

                    assert
                        ref_ports_tx_data(1).data = FRAME_C(index_v)
                        report
                        "CHECK C FAIL: Reference switch byte mismatch at index " &
                        integer'image(index_v) &
                        " received=" &
                        to_hstring(ref_ports_tx_data(1).data) &
                        " expected=" &
                        to_hstring(FRAME_C(index_v))
                        severity failure;

                    reference_bytes <=
                        reference_bytes + 1;

                    if ref_ports_tx_data(1).last = '1' then

                        assert
                            index_v = 63
                            report
                            "CHECK C FAIL: Reference switch frame length=" &
                            integer'image(index_v + 1)
                            severity failure;

                        reference_frames <=
                            reference_frames + 1;

                        report
                            "CHECK C PASS: Independent switch_core forwarded exact 64-byte frame to port 1";

                        index_v :=
                            0;

                    else

                        index_v :=
                            index_v + 1;

                    end if;

                end if;

            end if;

        end process;


    DUT_OUTPUT_MONITOR :
        process (phy1_refclk_wire)

            variable active_v :
                boolean := false;

            variable symbols_v :
                natural := 0;

            variable expected_symbols_v :
                natural := 0;

        begin

            if falling_edge(phy1_refclk_wire) then

                if dut_to_host1_en = '1' then

                    if not active_v then

                        active_v :=
                            true;

                        symbols_v :=
                            0;

                        report
                            "CHECK D: DUT -> HOST1 RMII frame START, frame=" &
                            integer'image(dut_out_frames + 1);

                    end if;

                    symbols_v :=
                        symbols_v + 1;

                elsif active_v then

                    active_v :=
                        false;

                    if dut_out_frames = 0 then

                        expected_symbols_v :=
                            288;

                    elsif dut_out_frames = 1 then

                        expected_symbols_v :=
                            448;

                    else

                        assert false
                            report
                            "CHECK D FAIL: Unexpected extra DUT output frame"
                            severity failure;

                    end if;

                    assert
                        symbols_v = expected_symbols_v
                        report
                        "CHECK D FAIL: RMII symbol count=" &
                        integer'image(symbols_v) &
                        " expected=" &
                        integer'image(expected_symbols_v)
                        severity failure;

                    dut_out_frames <=
                        dut_out_frames + 1;

                    dut_out_symbols <=
                        symbols_v;

                    report
                        "CHECK D PASS: DUT -> HOST1 RMII frame END, symbols=" &
                        integer'image(symbols_v);

                end if;

            end if;

        end process;


    HOST1_MONITOR :
        process

            variable index_v :
                natural range 0 to 255 := 0;

        begin

            wait until
                falling_edge(host1_rx_data.clk);

            wait for
                100 ps;

            if host1_rx_data.reset_p = '1' then

                index_v :=
                    0;

            elsif host1_rx_data.write = '1' then

                assert
                    host1_rx_data.rxerr = '0'
                    report
                    "HOST1 FAIL: RX error"
                    severity failure;

                if host1_frames = 0 then

                    assert
                        index_v <= FRAME_C'high
                        report
                        "CHECK D1 FAIL: PUF-disabled output produced too many bytes"
                        severity failure;

                    assert
                        host1_rx_data.data = FRAME_C(index_v)
                        report
                        "CHECK D1 FAIL: PUF-disabled byte mismatch at index " &
                        integer'image(index_v) &
                        " received=" &
                        to_hstring(host1_rx_data.data) &
                        " expected=" &
                        to_hstring(FRAME_C(index_v))
                        severity failure;

                elsif host1_frames = 1 then

                    assert
                        index_v <= TAGGED_FRAME_C'high
                        report
                        "CHECK D2 FAIL: PUF-enabled output produced too many bytes"
                        severity failure;

                    assert
                        host1_rx_data.data = TAGGED_FRAME_C(index_v)
                        report
                        "CHECK D2 FAIL: PUF-enabled byte mismatch at index " &
                        integer'image(index_v) &
                        " received=" &
                        to_hstring(host1_rx_data.data) &
                        " expected=" &
                        to_hstring(TAGGED_FRAME_C(index_v))
                        severity failure;

                    if index_v = 67 then

                        report
                            "CHECK E1 PASS: PUF1 trailer header is exact";

                    elsif index_v = 99 then

                        report
                            "CHECK E2 PASS: 32-byte PUF ID is exact";

                    end if;

                else

                    assert false
                        report
                        "HOST1 FAIL: Unexpected extra output frame"
                        severity failure;

                end if;

                host1_bytes <=
                    host1_bytes + 1;

                if host1_rx_data.last = '1' then

                    if host1_frames = 0 then

                        assert
                            index_v = FRAME_C'high
                            report
                            "CHECK D1 FAIL: PUF-disabled output length=" &
                            integer'image(index_v + 1)
                            severity failure;

                        report
                            "CHECK D1 PASS: PUF-disabled output is exact 64-byte original frame including original FCS";

                    elsif host1_frames = 1 then

                        assert
                            index_v = TAGGED_FRAME_C'high
                            report
                            "CHECK D2 FAIL: PUF-enabled output length=" &
                            integer'image(index_v + 1)
                            severity failure;

                        report
                            "CHECK E3 PASS: Regenerated Ethernet FCS is exact";

                        report
                            "CHECK D2 PASS: PUF-enabled output is exact 104-byte tagged frame";

                    end if;

                    host1_frames <=
                        host1_frames + 1;

                    index_v :=
                        0;

                else

                    index_v :=
                        index_v + 1;

                end if;

            end if;

        end process;


    STIMULUS :
        process

            procedure send_frame is

                variable wait_cycles :
                    natural;

            begin

                host0_tx_data.data <=
                    (others => '0');

                host0_tx_data.valid <=
                    '0';

                host0_tx_data.last <=
                    '0';

                wait until
                    rising_edge(host0_tx_ctrl.clk);

                for i in FRAME_C'range loop

                    host0_tx_data.data <=
                        FRAME_C(i);

                    host0_tx_data.valid <=
                        '1';

                    if i = FRAME_C'high then

                        host0_tx_data.last <=
                            '1';

                    else

                        host0_tx_data.last <=
                            '0';

                    end if;

                    wait_cycles :=
                        0;

                    loop

                        wait until
                            rising_edge(host0_tx_ctrl.clk);

                        exit when
                            host0_tx_ctrl.ready = '1';

                        wait_cycles :=
                            wait_cycles + 1;

                        assert
                            wait_cycles < 5000
                            report
                            "SOURCE FAIL: HOST0 stalled waiting for READY at byte " &
                            integer'image(i)
                            severity failure;

                    end loop;

                end loop;

                host0_tx_data.data <=
                    (others => '0');

                host0_tx_data.valid <=
                    '0';

                host0_tx_data.last <=
                    '0';

            end procedure;

        begin

            host0_tx_data.data <=
                (others => '0');

            host0_tx_data.valid <=
                '0';

            host0_tx_data.last <=
                '0';

            puf_enable <=
                '0';

            puf_id_valid <=
                '0';

            puf_id <=
                PUF_ID_C;

            reset_p <=
                '1';

            report
                "PHYSICAL PUF TRAILER TEST START";

            wait for
                2 us;

            reset_p <=
                '0';

            report
                "Global reset released";

            for n in 0 to 2000 loop

                exit when
                    host0_tx_ctrl.reset_p = '0'
                    and
                    host0_tx_ctrl.ready = '1'
                    and
                    host1_tx_ctrl.reset_p = '0'
                    and
                    host1_tx_ctrl.ready = '1'
                    and
                    tap0_rx_data.reset_p = '0';

                wait for
                    100 ns;

                assert
                    n < 2000
                    report
                    "FAIL: RMII ports did not leave reset"
                    severity failure;

            end loop;

            report
                "RMII ports READY";

            wait for
                2 us;

            puf_id_valid <=
                '1';

            wait for
                1 us;

            report
                "TEST 1: PUF disabled, expect exact 64-byte frame";

            send_frame;

            for n in 0 to 150 loop

                exit when
                    tap_frames >= 1
                    and
                    reference_frames >= 1
                    and
                    dut_out_frames >= 1
                    and
                    host1_frames >= 1;

                wait for
                    1 us;

            end loop;

            assert
                tap_frames >= 1
                report
                "TEST 1 FAIL: Passive RMII decoder did not receive frame"
                severity failure;

            assert
                reference_frames >= 1
                report
                "TEST 1 FAIL: Reference switch did not forward frame"
                severity failure;

            assert
                dut_out_frames >= 1
                report
                "TEST 1 FAIL: DUT produced no PHY1 RMII frame"
                severity failure;

            assert
                host1_frames >= 1
                report
                "TEST 1 FAIL: HOST1 did not reconstruct DUT output"
                severity failure;

            report
                "TEST 1 PASS: COMPLETE PUF-DISABLED PHYSICAL PATH";

            wait for
                2 us;

            puf_enable <=
                '1';

            wait for
                1 us;

            report
                "TEST 2: PUF enabled, expect exact 104-byte frame";

            send_frame;

            for n in 0 to 200 loop

                exit when
                    tap_frames >= 2
                    and
                    reference_frames >= 2
                    and
                    dut_out_frames >= 2
                    and
                    host1_frames >= 2;

                wait for
                    1 us;

            end loop;

            assert
                tap_frames >= 2
                report
                "TEST 2 FAIL: Passive RMII decoder did not receive second input frame"
                severity failure;

            assert
                reference_frames >= 2
                report
                "TEST 2 FAIL: Reference switch did not forward second input frame"
                severity failure;

            assert
                dut_out_frames >= 2
                report
                "TEST 2 FAIL: DUT produced no second PHY1 RMII frame"
                severity failure;

            assert
                host1_frames >= 2
                report
                "TEST 2 FAIL: HOST1 did not reconstruct tagged DUT output"
                severity failure;

            assert
                source_frames = 2
                report
                "FINAL FAIL: Expected exactly two source frames"
                severity failure;

            assert
                rmii_in_frames = 2
                report
                "FINAL FAIL: Expected exactly two HOST0-to-DUT RMII frames"
                severity failure;

            assert
                tap_frames = 2
                report
                "FINAL FAIL: Expected exactly two passive decoded input frames"
                severity failure;

            assert
                reference_frames = 2
                report
                "FINAL FAIL: Expected exactly two reference-switch output frames"
                severity failure;

            assert
                dut_out_frames = 2
                report
                "FINAL FAIL: Expected exactly two DUT output RMII frames"
                severity failure;

            assert
                host1_frames = 2
                report
                "FINAL FAIL: Expected exactly two HOST1 decoded frames"
                severity failure;

            report
                "TEST 2 PASS: COMPLETE PUF-ENABLED PHYSICAL PATH";

            report
                "FINAL PASS: 64-byte bypass and 104-byte PUF1 trailer paths are exact";

            stop;

            wait;

        end process;

end architecture tb;
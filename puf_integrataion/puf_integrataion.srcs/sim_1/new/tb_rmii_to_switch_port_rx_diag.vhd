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

entity tb_rmii_to_switch_port_rx_diag is
end entity tb_rmii_to_switch_port_rx_diag;

architecture tb of tb_rmii_to_switch_port_rx_diag is

    type byte_array_t is
        array (natural range <>) of std_logic_vector(7 downto 0);

    constant CRC_POLY_C :
        unsigned(31 downto 0) := x"EDB88320";

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
                c := shift_right(c, 1) xor CRC_POLY_C;
            else
                c := shift_right(c, 1);
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

        f := (others => (others => '0'));

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
            f(i) := std_logic_vector(to_unsigned(i, 8));
        end loop;

        crc := x"FFFFFFFF";

        for i in 0 to 59 loop
            crc := crc32_update(crc, f(i));
        end loop;

        crc := not crc;

        f(60) := crc(7 downto 0);
        f(61) := crc(15 downto 8);
        f(62) := crc(23 downto 16);
        f(63) := crc(31 downto 24);

        return f;

    end function;


    constant FRAME_C :
        byte_array_t(0 to 63) := make_frame;


    signal core_clk :
        std_logic := '0';

    signal phy_clk :
        std_logic := '0';

    signal refclk_wire :
        std_logic;

    signal reset_p :
        std_logic := '1';

    signal core_reset_sync :
        std_logic;


    signal host_to_rx_data :
        std_logic_vector(1 downto 0);

    signal host_to_rx_en :
        std_logic;


    signal host_rx_unused :
        port_rx_m2s;

    signal host_tx_data :
        port_tx_s2m;

    signal host_tx_ctrl :
        port_tx_m2s;


    signal receiver_rx_data :
        port_rx_m2s;

    signal receiver_tx_data :
        port_tx_s2m;

    signal receiver_tx_ctrl :
        port_tx_m2s;


    signal sprx_data :
        std_logic_vector(31 downto 0);

    signal sprx_meta :
        switch_meta_t;

    signal sprx_nlast :
        integer range 0 to 4;

    signal sprx_last :
        std_logic;

    signal sprx_valid :
        std_logic;

    signal sprx_ready :
        std_logic := '1';


    signal err_badfrm :
        std_logic;

    signal err_rxmac :
        std_logic;

    signal err_overflow :
        std_logic;


    signal decoded_frame_seen :
        std_logic := '0';

    signal switch_rx_frame_seen :
        std_logic := '0';

    signal decoded_byte_count :
        integer range 0 to 256 := 0;

    signal switch_word_count :
        integer range 0 to 256 := 0;

begin

    core_clk <=
        not core_clk after 5 ns;

    phy_clk <=
        not phy_clk after 10 ns;


    RESET_SYNC :
        entity work.sync_reset
        port map (
            in_reset_p  => reset_p,
            out_reset_p => core_reset_sync,
            out_clk     => core_clk
        );


    HOST_RMII :
        entity work.port_rmii
        generic map (
            MODE_CLKOUT => true,
            MODE_CLKDDR => true
        )
        port map (
            rmii_txd     => host_to_rx_data,
            rmii_txen    => host_to_rx_en,
            rmii_txer    => open,

            rmii_rxd     => "00",
            rmii_rxen    => '0',
            rmii_rxer    => '0',

            rmii_clkin   => phy_clk,
            rmii_clkout  => refclk_wire,

            ref_time     => PORT_TIMEREF_NULL,

            rx_data      => host_rx_unused,
            tx_data      => host_tx_data,
            tx_ctrl      => host_tx_ctrl,

            force_10m    => '0',
            lock_refclk  => core_clk,
            reset_p      => reset_p
        );


    RECEIVER_RMII :
        entity work.port_rmii
        generic map (
            MODE_CLKOUT => false,
            MODE_CLKDDR => true
        )
        port map (
            rmii_txd     => open,
            rmii_txen    => open,
            rmii_txer    => open,

            rmii_rxd     => host_to_rx_data,
            rmii_rxen    => host_to_rx_en,
            rmii_rxer    => '0',

            rmii_clkin   => refclk_wire,
            rmii_clkout  => open,

            ref_time     => PORT_TIMEREF_NULL,

            rx_data      => receiver_rx_data,
            tx_data      => receiver_tx_data,
            tx_ctrl      => receiver_tx_ctrl,

            force_10m    => '0',
            lock_refclk  => core_clk,
            reset_p      => reset_p
        );


    receiver_tx_data.data <=
        (others => '0');

    receiver_tx_data.valid <=
        '0';

    receiver_tx_data.last <=
        '0';


    SWITCH_RX :
        entity work.switch_port_rx
        generic map (
            DEV_ADDR        => CFGBUS_ADDR_NONE,
            CORE_CLK_HZ     => 100_000_000,
            PORT_COUNT      => 2,
            PORT_INDEX      => 0,
            PTP_DOPPLER     => false,
            STRIP_FCS       => false,
            SUPPORT_LOG     => false,
            SUPPORT_PAUSE   => false,
            SUPPORT_PTP     => false,
            SUPPORT_VLAN    => false,
            ALLOW_JUMBO     => false,
            ALLOW_RUNT      => false,
            INPUT_BYTES     => 1,
            OUTPUT_BYTES    => 4,
            IBUF_KBYTES     => 2,
            IBUF_PACKETS    => 32
        )
        port map (
            rx_clk          => receiver_rx_data.clk,
            rx_data         => receiver_rx_data.data,
            rx_nlast        => 0,
            rx_last         => receiver_rx_data.last,
            rx_write        => receiver_rx_data.write,
            rx_macerr       => receiver_rx_data.rxerr,
            rx_rate         => receiver_rx_data.rate,
            rx_tsof         => receiver_rx_data.tsof,
            rx_tfreq        => receiver_rx_data.tfreq,
            rx_reset_p      => receiver_rx_data.reset_p,

            out_data        => sprx_data,
            out_meta        => sprx_meta,
            out_nlast       => sprx_nlast,
            out_last        => sprx_last,
            out_valid       => sprx_valid,
            out_ready       => sprx_ready,

            pause_tx        => open,

            err_badfrm      => err_badfrm,
            err_rxmac       => err_rxmac,
            err_overflow    => err_overflow,
            err_log_data    => open,
            err_log_write   => open,

            cfg_cmd         => CFGBUS_CMD_NULL,
            cfg_ack         => open,

            core_clk        => core_clk,
            core_reset_p    => core_reset_sync
        );


    DECODE_MONITOR :
        process

            variable byte_index :
                integer range 0 to 255 := 0;

        begin

            wait until falling_edge(receiver_rx_data.clk);

            wait for 100 ps;

            if receiver_rx_data.reset_p = '1' then

                byte_index := 0;

                decoded_frame_seen <=
                    '0';

                decoded_byte_count <=
                    0;

            elsif receiver_rx_data.write = '1' then

                assert byte_index <= 63
                    report "CHECK R1 FAIL: too many decoded bytes"
                    severity failure;

                assert receiver_rx_data.data = FRAME_C(byte_index)
                    report "CHECK R1 FAIL: decoded byte mismatch"
                    severity failure;

                assert receiver_rx_data.rxerr = '0'
                    report "CHECK R1 FAIL: receiver asserted RX error"
                    severity failure;

                decoded_byte_count <=
                    decoded_byte_count + 1;

                if receiver_rx_data.last = '1' then

                    assert byte_index = 63
                        report "CHECK R1 FAIL: incorrect decoded frame length"
                        severity failure;

                    decoded_frame_seen <=
                        '1';

                    report
                        "CHECK R1 PASS: port_rmii decoded exact 64-byte frame";

                    byte_index :=
                        0;

                else

                    byte_index :=
                        byte_index + 1;

                end if;

            end if;

        end process;


    SWITCH_RX_MONITOR :
        process (core_clk)
        begin

            if rising_edge(core_clk) then

                if core_reset_sync = '1' then

                    switch_rx_frame_seen <=
                        '0';

                    switch_word_count <=
                        0;

                elsif sprx_valid = '1'
                      and sprx_ready = '1' then

                    switch_word_count <=
                        switch_word_count + 1;

                    if sprx_last = '1' then

                        switch_rx_frame_seen <=
                            '1';

                        report
                            "CHECK R2 PASS: switch_port_rx emitted complete frame";

                    end if;

                end if;

            end if;

        end process;


    ERROR_MONITOR :
        process (core_clk)
        begin

            if rising_edge(core_clk) then

                if core_reset_sync = '0' then

                    if err_badfrm = '1' then
                        report "CHECK R2 ERROR: bad frame";
                    end if;

                    if err_rxmac = '1' then
                        report "CHECK R2 ERROR: RX MAC error";
                    end if;

                    if err_overflow = '1' then
                        report "CHECK R2 ERROR: RX FIFO overflow";
                    end if;

                end if;

            end if;

        end process;


    STIMULUS :
        process

            procedure send_frame is

                variable wait_cycles :
                    integer := 0;

            begin

                host_tx_data.data <=
                    (others => '0');

                host_tx_data.valid <=
                    '0';

                host_tx_data.last <=
                    '0';

                wait until rising_edge(host_tx_ctrl.clk);

                for i in FRAME_C'range loop

                    host_tx_data.data <=
                        FRAME_C(i);

                    host_tx_data.valid <=
                        '1';

                    if i = FRAME_C'high then

                        host_tx_data.last <=
                            '1';

                    else

                        host_tx_data.last <=
                            '0';

                    end if;

                    wait_cycles :=
                        0;

                    loop

                        wait until rising_edge(host_tx_ctrl.clk);

                        exit when host_tx_ctrl.ready = '1';

                        wait_cycles :=
                            wait_cycles + 1;

                        assert wait_cycles < 5000
                            report "SOURCE FAIL: waiting for READY"
                            severity failure;

                    end loop;

                end loop;

                host_tx_data.data <=
                    (others => '0');

                host_tx_data.valid <=
                    '0';

                host_tx_data.last <=
                    '0';

            end procedure;

        begin

            host_tx_data.data <=
                (others => '0');

            host_tx_data.valid <=
                '0';

            host_tx_data.last <=
                '0';

            reset_p <=
                '1';

            report
                "DIAG: reset asserted";

            wait for 2 us;

            reset_p <=
                '0';

            report
                "DIAG: reset released";


            for n in 0 to 2000 loop

                exit when
                    host_tx_ctrl.reset_p = '0'
                    and
                    host_tx_ctrl.ready = '1'
                    and
                    receiver_rx_data.reset_p = '0';

                wait for 100 ns;

                assert n < 2000
                    report "FAIL: RMII ports did not leave reset"
                    severity failure;

            end loop;


            report
                "DIAG: RMII ports ready";

            wait for 2 us;


            report
                "DIAG: sending 64-byte Ethernet frame";

            send_frame;


            for n in 0 to 100 loop

                exit when decoded_frame_seen = '1';

                wait for 1 us;

            end loop;


            assert decoded_frame_seen = '1'
                report "CHECK R1 FAIL: port_rmii did not decode frame"
                severity failure;


            for n in 0 to 100 loop

                exit when switch_rx_frame_seen = '1';

                wait for 1 us;

            end loop;


            if switch_rx_frame_seen = '1' then

                report "CHECK R1 PASS";
                report "CHECK R2 PASS";
                report "DIAGNOSTIC RESULT: direct port_rmii to switch_port_rx path is healthy";
                report "DIAGNOSTIC RESULT: failure was caused by the intermediate RX clock signal path";

            else

                report "CHECK R1 PASS";
                report "CHECK R2 FAIL";
                report "DIAGNOSTIC RESULT: direct RX clock did not solve the failure";
                report "DIAGNOSTIC RESULT: next test must inspect what switch_port_rx samples on rising RX-clock edges";

                assert false
                    report "DIAGNOSTIC STOP R2"
                    severity failure;

            end if;


            stop;

            wait;

        end process;

end architecture tb;
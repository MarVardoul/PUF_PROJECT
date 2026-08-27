library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.cfgbus_common.all;
use work.common_functions.all;
use work.eth_frame_common.all;
use work.ptp_types.all;
use work.switch_types.all;

entity tb_switch_port_tx_diag is
end entity tb_switch_port_tx_diag;

architecture tb of tb_switch_port_tx_diag is

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


    signal rx_clk :
        std_logic := '0';

    signal core_clk :
        std_logic := '0';

    signal tx_clk :
        std_logic := '0';

    signal reset_p :
        std_logic := '1';

    signal core_reset_sync :
        std_logic;


    signal rx_data :
        std_logic_vector(7 downto 0) := (others => '0');

    signal rx_write :
        std_logic := '0';

    signal rx_last :
        std_logic := '0';


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


    signal rx_pause :
        std_logic;

    signal rx_err_badfrm :
        std_logic;

    signal rx_err_mac :
        std_logic;

    signal rx_err_overflow :
        std_logic;


    signal tx_data :
        std_logic_vector(7 downto 0);

    signal tx_last :
        std_logic;

    signal tx_valid :
        std_logic;

    signal tx_ready :
        std_logic := '1';


    signal tx_err_overflow :
        std_logic;

    signal tx_err_mac :
        std_logic;

    signal tx_err_ptp :
        std_logic;


    signal c2_frame_seen :
        std_logic := '0';

    signal c5_frame_seen :
        std_logic := '0';

    signal c2_word_count :
        integer range 0 to 256 := 0;

    signal c5_byte_count :
        integer range 0 to 256 := 0;

begin

    rx_clk <= not rx_clk after 10 ns;

    core_clk <= not core_clk after 5 ns;

    tx_clk <= not tx_clk after 10 ns;


    RESET_SYNC :
        entity work.sync_reset
        port map (
            in_reset_p  => reset_p,
            out_reset_p => core_reset_sync,
            out_clk     => core_clk
        );


    RX_STAGE :
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
            rx_clk          => rx_clk,
            rx_data         => rx_data,
            rx_nlast        => 0,
            rx_last         => rx_last,
            rx_write        => rx_write,
            rx_macerr       => '0',
            rx_rate         => get_rate_word(100),
            rx_tsof         => TSTAMP_DISABLED,
            rx_tfreq        => TFREQ_DISABLED,
            rx_reset_p      => reset_p,

            out_data        => sprx_data,
            out_meta        => sprx_meta,
            out_nlast       => sprx_nlast,
            out_last        => sprx_last,
            out_valid       => sprx_valid,
            out_ready       => sprx_ready,

            pause_tx        => rx_pause,

            err_badfrm      => rx_err_badfrm,
            err_rxmac       => rx_err_mac,
            err_overflow    => rx_err_overflow,
            err_log_data    => open,
            err_log_write   => open,

            cfg_cmd         => CFGBUS_CMD_NULL,
            cfg_ack         => open,

            core_clk        => core_clk,
            core_reset_p    => core_reset_sync
        );


    TX_STAGE :
        entity work.switch_port_tx
        generic map (
            DEV_ADDR        => CFGBUS_ADDR_NONE,
            PORT_INDEX      => 1,
            SUPPORT_PTP     => false,
            SUPPORT_VLAN    => false,
            ALLOW_JUMBO     => false,
            ALLOW_RUNT      => false,
            INPUT_HAS_FCS   => true,
            PTP_DOPPLER     => false,
            PTP_STRICT      => true,
            INPUT_BYTES     => 4,
            OUTPUT_BYTES    => 1,
            HBUF_KBYTES     => 0,
            OBUF_KBYTES     => 4,
            OBUF_PACKETS    => 32
        )
        port map (
            in_data         => sprx_data,
            in_meta         => sprx_meta,
            in_nlast        => sprx_nlast,
            in_precommit    => '0',
            in_keep         => sprx_last,
            in_hipri        => '0',
            in_write        => sprx_valid,

            tx_clk          => tx_clk,
            tx_data         => tx_data,
            tx_last         => tx_last,
            tx_valid        => tx_valid,
            tx_ready        => tx_ready,
            tx_pstart       => '1',
            tx_tnow         => TSTAMP_DISABLED,
            tx_tfreq        => TFREQ_DISABLED,
            tx_macerr       => '0',
            tx_reset_p      => reset_p,

            pause_tx        => '0',
            port_2step      => '0',

            err_overflow    => tx_err_overflow,
            err_txmac       => tx_err_mac,
            err_ptp         => tx_err_ptp,

            cfg_cmd         => CFGBUS_CMD_NULL,
            cfg_ack         => open,

            core_clk        => core_clk,
            core_reset_p    => core_reset_sync
        );


    C2_MONITOR :
        process (core_clk)
        begin

            if rising_edge(core_clk) then

                if core_reset_sync = '1' then

                    c2_frame_seen <= '0';
                    c2_word_count <= 0;

                elsif sprx_valid = '1' and sprx_ready = '1' then

                    c2_word_count <= c2_word_count + 1;

                    if sprx_last = '1' then

                        c2_frame_seen <= '1';

                        report "CHECK C2 PASS: switch_port_rx emitted complete frame";

                    end if;

                end if;

            end if;

        end process;


    C5_MONITOR :
        process

            variable byte_index :
                integer range 0 to 255 := 0;

        begin

            wait until rising_edge(tx_clk);

            if reset_p = '1' then

                byte_index := 0;
                c5_frame_seen <= '0';
                c5_byte_count <= 0;

            elsif tx_valid = '1' and tx_ready = '1' then

                assert byte_index <= 63
                    report "CHECK C5 FAIL: too many output bytes"
                    severity failure;

                assert tx_data = FRAME_C(byte_index)
                    report "CHECK C5 FAIL: output byte mismatch"
                    severity failure;

                c5_byte_count <= c5_byte_count + 1;

                if tx_last = '1' then

                    assert byte_index = 63
                        report "CHECK C5 FAIL: LAST asserted at wrong byte"
                        severity failure;

                    c5_frame_seen <= '1';

                    report "CHECK C5 PASS: switch_port_tx emitted exact 64-byte frame";

                    byte_index := 0;

                else

                    byte_index := byte_index + 1;

                end if;

            end if;

        end process;


    ERROR_MONITOR :
        process (core_clk)
        begin

            if rising_edge(core_clk) then

                if core_reset_sync = '0' then

                    if rx_err_badfrm = '1' then
                        report "ERROR: RX bad frame";
                    end if;

                    if rx_err_mac = '1' then
                        report "ERROR: RX MAC error";
                    end if;

                    if rx_err_overflow = '1' then
                        report "ERROR: RX FIFO overflow";
                    end if;

                    if tx_err_overflow = '1' then
                        report "ERROR: TX FIFO overflow";
                    end if;

                    if tx_err_mac = '1' then
                        report "ERROR: TX MAC error";
                    end if;

                    if tx_err_ptp = '1' then
                        report "ERROR: TX PTP error";
                    end if;

                end if;

            end if;

        end process;


    STIMULUS :
        process
        begin

            rx_data <= (others => '0');
            rx_write <= '0';
            rx_last <= '0';

            reset_p <= '1';

            report "DIAG: reset asserted";

            wait for 2 us;

            reset_p <= '0';

            report "DIAG: reset released";

            wait for 2 us;

            report "DIAG: injecting 64-byte frame";

            for i in FRAME_C'range loop

                wait until falling_edge(rx_clk);

                rx_data <= FRAME_C(i);
                rx_write <= '1';

                if i = FRAME_C'high then
                    rx_last <= '1';
                else
                    rx_last <= '0';
                end if;

            end loop;

            wait until falling_edge(rx_clk);

            rx_data <= (others => '0');
            rx_write <= '0';
            rx_last <= '0';

            report "DIAG: frame injection complete";

            wait for 30 us;


            if c2_frame_seen = '1' then

                report "CHECK C2 PASS";

            else

                report "CHECK C2 FAIL";

                assert false
                    report "DIAGNOSTIC STOP C2"
                    severity failure;

            end if;


            if c5_frame_seen = '1' then

                report "CHECK C5 PASS";
                report "DIAGNOSTIC RESULT: switch_port_tx is healthy";
                report "DIAGNOSTIC RESULT: 100-to-50 MHz TX FIFO CDC is healthy";
                report "NEXT BOUNDARY: switch_port_tx to port_rmii";

            else

                report "CHECK C5 FAIL";
                report "DIAGNOSTIC RESULT: switch_port_rx passed but switch_port_tx emitted no complete frame";

                assert false
                    report "DIAGNOSTIC STOP C5"
                    severity failure;

            end if;


            stop;

            wait;

        end process;

end architecture tb;
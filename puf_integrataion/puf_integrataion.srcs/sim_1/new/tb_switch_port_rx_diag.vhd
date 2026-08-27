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

entity tb_switch_port_rx_diag is
end entity tb_switch_port_rx_diag;

architecture tb of tb_switch_port_rx_diag is

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

    signal reset_p :
        std_logic := '1';


    signal rx_data :
        std_logic_vector(7 downto 0) := (others => '0');

    signal rx_write :
        std_logic := '0';

    signal rx_last :
        std_logic := '0';


    signal chk_data :
        std_logic_vector(7 downto 0);

    signal chk_nlast :
        integer range 0 to 1;

    signal chk_write :
        std_logic;

    signal chk_result :
        frm_result_t;


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


    signal pause_tx :
        std_logic;

    signal err_badfrm :
        std_logic;

    signal err_rxmac :
        std_logic;

    signal err_overflow :
        std_logic;

    signal err_log_data :
        log_meta_t;

    signal err_log_write :
        std_logic;

    signal cfg_ack :
        cfgbus_ack;


    signal c1_commit_seen :
        std_logic := '0';

    signal c1_revert_seen :
        std_logic := '0';

    signal c1_error_seen :
        std_logic := '0';

    signal c1_output_bytes :
        integer range 0 to 256 := 0;


    signal c2_frame_seen :
        std_logic := '0';

    signal c2_output_words :
        integer range 0 to 256 := 0;


    signal badfrm_seen :
        std_logic := '0';

    signal rxmac_seen :
        std_logic := '0';

    signal overflow_seen :
        std_logic := '0';

begin

    rx_clk <= not rx_clk after 10 ns;

    core_clk <= not core_clk after 5 ns;


    C1_FRAME_CHECK :
        entity work.eth_frame_check
        generic map (
            ALLOW_JUMBO => false,
            ALLOW_RUNT  => false,
            STRIP_FCS   => false,
            IO_BYTES    => 1
        )
        port map (
            in_data     => rx_data,
            in_nlast    => 0,
            in_last     => rx_last,
            in_write    => rx_write,

            out_data    => chk_data,
            out_nlast   => chk_nlast,
            out_write   => chk_write,
            out_result  => chk_result,

            clk         => rx_clk,
            reset_p     => reset_p
        );


    C2_SWITCH_PORT_RX :
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

            pause_tx        => pause_tx,

            err_badfrm      => err_badfrm,
            err_rxmac       => err_rxmac,
            err_overflow    => err_overflow,
            err_log_data    => err_log_data,
            err_log_write   => err_log_write,

            cfg_cmd         => CFGBUS_CMD_NULL,
            cfg_ack         => cfg_ack,

            core_clk        => core_clk,
            core_reset_p    => reset_p
        );


    C1_MONITOR :
        process
        begin

            wait until falling_edge(rx_clk);

            if reset_p = '1' then

                c1_commit_seen <= '0';
                c1_revert_seen <= '0';
                c1_error_seen <= '0';
                c1_output_bytes <= 0;

            elsif chk_write = '1' then

                c1_output_bytes <= c1_output_bytes + 1;

                if chk_result.commit = '1' then
                    c1_commit_seen <= '1';
                    report "CHECK C1: COMMIT detected";
                end if;

                if chk_result.revert = '1' then
                    c1_revert_seen <= '1';
                    report "CHECK C1: REVERT detected";
                end if;

                if chk_result.error = '1' then
                    c1_error_seen <= '1';
                    report "CHECK C1: ERROR detected";
                end if;

            end if;

        end process;


    C2_MONITOR :
        process
        begin

            wait until falling_edge(core_clk);

            if reset_p = '1' then

                c2_frame_seen <= '0';
                c2_output_words <= 0;

            elsif sprx_valid = '1' and sprx_ready = '1' then

                c2_output_words <= c2_output_words + 1;

                if sprx_last = '1' then
                    c2_frame_seen <= '1';
                    report "CHECK C2: complete frame emitted by switch_port_rx";
                end if;

            end if;

        end process;


    ERROR_MONITOR :
        process (core_clk)
        begin

            if rising_edge(core_clk) then

                if reset_p = '1' then

                    badfrm_seen <= '0';
                    rxmac_seen <= '0';
                    overflow_seen <= '0';

                else

                    if err_badfrm = '1' then
                        badfrm_seen <= '1';
                        report "CHECK C2: err_badfrm asserted";
                    end if;

                    if err_rxmac = '1' then
                        rxmac_seen <= '1';
                        report "CHECK C2: err_rxmac asserted";
                    end if;

                    if err_overflow = '1' then
                        overflow_seen <= '1';
                        report "CHECK C2: err_overflow asserted";
                    end if;

                end if;

            end if;

        end process;


    STIMULUS :
        process

            procedure send_frame is
            begin

                report "DIAG: frame injection starting";

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

                report "DIAG: frame injection finished";

            end procedure;

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

            send_frame;

            wait for 20 us;


            if c1_commit_seen = '1' then
                report "CHECK C1 PASS: eth_frame_check accepted the frame";
            else
                report "CHECK C1 FAIL: eth_frame_check did not commit the frame";
            end if;


            if c1_revert_seen = '1' then
                report "CHECK C1 INFO: revert was observed";
            end if;


            if c1_error_seen = '1' then
                report "CHECK C1 INFO: frame error was observed";
            end if;


            if c1_output_bytes = 64 then
                report "CHECK C1 PASS: frame checker emitted 64 bytes";
            else
                report "CHECK C1 FAIL: frame checker output length was not 64 bytes";
            end if;


            if badfrm_seen = '1' then
                report "CHECK C2 INFO: switch_port_rx reported bad frame";
            end if;


            if rxmac_seen = '1' then
                report "CHECK C2 INFO: switch_port_rx reported MAC receive error";
            end if;


            if overflow_seen = '1' then
                report "CHECK C2 INFO: switch_port_rx reported FIFO overflow";
            end if;


            if c1_commit_seen /= '1' then

                report "DIAGNOSTIC RESULT: failure is inside eth_frame_check";

                assert false
                    report "DIAGNOSTIC STOP C1"
                    severity failure;

            elsif c2_frame_seen /= '1' then

                report "DIAGNOSTIC RESULT: eth_frame_check passed";
                report "DIAGNOSTIC RESULT: switch_port_rx produced no output frame";
                report "DIAGNOSTIC RESULT: investigate ingress FIFO and clock-domain crossing";

                assert false
                    report "DIAGNOSTIC STOP C2"
                    severity failure;

            else

                report "CHECK C1 PASS";
                report "CHECK C2 PASS";
                report "DIAGNOSTIC RESULT: switch_port_rx ingress path is healthy";
                report "NEXT: investigate switch scheduler and MAC forwarding";

            end if;


            stop;

            wait;

        end process;

end architecture tb;
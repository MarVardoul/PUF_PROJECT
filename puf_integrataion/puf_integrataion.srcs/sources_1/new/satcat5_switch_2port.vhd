library ieee;
use ieee.std_logic_1164.all;

library work;
use work.cfgbus_common.all;
use work.common_functions.all;
use work.ptp_types.all;
use work.switch_types.all;

entity satcat5_switch_2port is
    generic (
        CORE_CLK_HZ_G : positive := 100_000_000
    );
    port (
        core_clk   : in  std_logic;
        reset_p    : in  std_logic;

        rx_data_i  : in  std_logic_vector(15 downto 0);
        rx_write_i : in  std_logic_vector(1 downto 0);
        rx_last_i  : in  std_logic_vector(1 downto 0);
        rx_error_i : in  std_logic_vector(1 downto 0);

        tx_data_o  : out std_logic_vector(15 downto 0);
        tx_valid_o : out std_logic_vector(1 downto 0);
        tx_last_o  : out std_logic_vector(1 downto 0);
        tx_ready_i : in  std_logic_vector(1 downto 0)
    );
end entity satcat5_switch_2port;

architecture rtl of satcat5_switch_2port is

    constant PORT_COUNT_C : positive := 2;

    signal ports_rx_data : array_rx_m2s(PORT_COUNT_C-1 downto 0);
    signal ports_tx_data : array_tx_s2m(PORT_COUNT_C-1 downto 0);
    signal ports_tx_ctrl : array_tx_m2s(PORT_COUNT_C-1 downto 0);

begin

    gen_ports : for n in 0 to PORT_COUNT_C-1 generate

        ports_rx_data(n).clk     <= core_clk;
        ports_rx_data(n).data    <= rx_data_i(8*n+7 downto 8*n);
        ports_rx_data(n).write   <= rx_write_i(n);
        ports_rx_data(n).last    <= rx_last_i(n);
        ports_rx_data(n).rxerr   <= rx_error_i(n);
        ports_rx_data(n).rate    <= get_rate_word(100);
        ports_rx_data(n).status  <= STATUS_NULL;
        ports_rx_data(n).tsof    <= TSTAMP_DISABLED;
        ports_rx_data(n).tfreq   <= TFREQ_DISABLED;
        ports_rx_data(n).reset_p <= reset_p;

        ports_tx_ctrl(n).clk     <= core_clk;
        ports_tx_ctrl(n).ready   <= tx_ready_i(n);
        ports_tx_ctrl(n).pstart  <= '1';
        ports_tx_ctrl(n).tnow    <= TSTAMP_DISABLED;
        ports_tx_ctrl(n).tfreq   <= TFREQ_DISABLED;
        ports_tx_ctrl(n).txerr   <= '0';
        ports_tx_ctrl(n).reset_p <= reset_p;

        tx_data_o(8*n+7 downto 8*n) <= ports_tx_data(n).data;
        tx_valid_o(n)                <= ports_tx_data(n).valid;
        tx_last_o(n)                 <= ports_tx_data(n).last;

    end generate;

    SWITCH_COMP : entity work.switch_core
        generic map (
            DEV_ADDR        => CFGBUS_ADDR_NONE,
            CORE_CLK_HZ     => CORE_CLK_HZ_G,

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
            ports_rx_data => ports_rx_data,
            ports_tx_data => ports_tx_data,
            ports_tx_ctrl => ports_tx_ctrl,

            err_ports     => open,
            err_switch    => open,
            errvec_t      => open,

            cfg_cmd       => CFGBUS_CMD_NULL,
            cfg_ack       => open,
            log_txd       => open,
            scrub_req_t   => '0',

            core_clk      => core_clk,
            core_reset_p  => reset_p
        );

end architecture rtl;
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.cfgbus_common.all;
use work.ptp_types.all;
use work.switch_types.all;

entity puf_rmii_switch_2port is
    generic (
        CORE_CLK_HZ_G : positive := 100_000_000
    );
    port (
        core_clk      : in  std_logic;
        reset_p       : in  std_logic;

        puf_enable    : in  std_logic;
        puf_id_valid  : in  std_logic;
        puf_id        : in  std_logic_vector(255 downto 0);

        phy0_refclk   : in  std_logic;
        phy0_rxd      : in  std_logic_vector(1 downto 0);
        phy0_crs_dv   : in  std_logic;
        phy0_txd      : out std_logic_vector(1 downto 0);
        phy0_tx_en    : out std_logic;

        phy1_refclk   : in  std_logic;
        phy1_rxd      : in  std_logic_vector(1 downto 0);
        phy1_crs_dv   : in  std_logic;
        phy1_txd      : out std_logic_vector(1 downto 0);
        phy1_tx_en    : out std_logic
    );
end entity puf_rmii_switch_2port;

architecture rtl of puf_rmii_switch_2port is

    constant PORT_COUNT_C :
        positive := 2;

    signal ports_rx_data :
        array_rx_m2s(PORT_COUNT_C-1 downto 0);

    signal ports_tx_data :
        array_tx_s2m(PORT_COUNT_C-1 downto 0);

    signal ports_tx_ctrl :
        array_tx_m2s(PORT_COUNT_C-1 downto 0);

    signal phy0_tx_data :
        port_tx_s2m;

    signal phy0_tx_ctrl :
        port_tx_m2s;

    signal phy1_tx_data :
        port_tx_s2m;

    signal phy1_tx_ctrl :
        port_tx_m2s;

    signal trailer_in_ready :
        std_logic;

    signal trailer_out_data :
        std_logic_vector(7 downto 0);

    signal trailer_out_valid :
        std_logic;

    signal trailer_out_last :
        std_logic;

    signal trailer_reset_p :
        std_logic;

    signal puf_enable_meta :
        std_logic := '0';

    signal puf_enable_sync :
        std_logic := '0';

    signal puf_id_valid_meta :
        std_logic := '0';

    signal puf_id_valid_sync :
        std_logic := '0';

begin

    phy0_tx_data <=
        ports_tx_data(0);

    ports_tx_ctrl(0) <=
        phy0_tx_ctrl;

    ports_tx_ctrl(1).clk <=
        phy1_tx_ctrl.clk;

    ports_tx_ctrl(1).ready <=
        trailer_in_ready;

    ports_tx_ctrl(1).pstart <=
        phy1_tx_ctrl.pstart;

    ports_tx_ctrl(1).tnow <=
        phy1_tx_ctrl.tnow;

    ports_tx_ctrl(1).tfreq <=
        phy1_tx_ctrl.tfreq;

    ports_tx_ctrl(1).txerr <=
        phy1_tx_ctrl.txerr;

    ports_tx_ctrl(1).reset_p <=
        phy1_tx_ctrl.reset_p;

    phy1_tx_data.data <=
        trailer_out_data;

    phy1_tx_data.valid <=
        trailer_out_valid;

    phy1_tx_data.last <=
        trailer_out_last;

    trailer_reset_p <=
        reset_p or phy1_tx_ctrl.reset_p;


    PUF_CONTROL_SYNC :
        process (phy1_tx_ctrl.clk)
        begin

            if rising_edge(phy1_tx_ctrl.clk) then

                if trailer_reset_p = '1' then

                    puf_enable_meta <=
                        '0';

                    puf_enable_sync <=
                        '0';

                    puf_id_valid_meta <=
                        '0';

                    puf_id_valid_sync <=
                        '0';

                else

                    puf_enable_meta <=
                        puf_enable;

                    puf_enable_sync <=
                        puf_enable_meta;

                    puf_id_valid_meta <=
                        puf_id_valid;

                    puf_id_valid_sync <=
                        puf_id_valid_meta;

                end if;

            end if;

        end process;


    PHY0_RMII_COMP :
        entity work.port_rmii
        generic map (
            MODE_CLKOUT => false,
            MODE_CLKDDR => true
        )
        port map (
            rmii_txd    => phy0_txd,
            rmii_txen   => phy0_tx_en,
            rmii_txer   => open,

            rmii_rxd    => phy0_rxd,
            rmii_rxen   => phy0_crs_dv,
            rmii_rxer   => '0',

            rmii_clkin  => phy0_refclk,
            rmii_clkout => open,

            ref_time    => PORT_TIMEREF_NULL,

            rx_data     => ports_rx_data(0),
            tx_data     => phy0_tx_data,
            tx_ctrl     => phy0_tx_ctrl,

            force_10m   => '0',
            lock_refclk => core_clk,
            reset_p     => reset_p
        );


    PHY1_RMII_COMP :
        entity work.port_rmii
        generic map (
            MODE_CLKOUT => false,
            MODE_CLKDDR => true
        )
        port map (
            rmii_txd    => phy1_txd,
            rmii_txen   => phy1_tx_en,
            rmii_txer   => open,

            rmii_rxd    => phy1_rxd,
            rmii_rxen   => phy1_crs_dv,
            rmii_rxer   => '0',

            rmii_clkin  => phy1_refclk,
            rmii_clkout => open,

            ref_time    => PORT_TIMEREF_NULL,

            rx_data     => ports_rx_data(1),
            tx_data     => phy1_tx_data,
            tx_ctrl     => phy1_tx_ctrl,

            force_10m   => '0',
            lock_refclk => core_clk,
            reset_p     => reset_p
        );


    TRAILER_COMP :
        entity work.puf_egress_trailer
        port map (
            clk          => phy1_tx_ctrl.clk,
            rst          => trailer_reset_p,

            puf_enable   => puf_enable_sync,
            puf_id_valid => puf_id_valid_sync,
            puf_id       => puf_id,

            in_data      => ports_tx_data(1).data,
            in_valid     => ports_tx_data(1).valid,
            in_last      => ports_tx_data(1).last,
            in_ready     => trailer_in_ready,

            out_data     => trailer_out_data,
            out_valid    => trailer_out_valid,
            out_last     => trailer_out_last,
            out_ready    => phy1_tx_ctrl.ready
        );


    SWITCH_COMP :
        entity work.switch_core
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
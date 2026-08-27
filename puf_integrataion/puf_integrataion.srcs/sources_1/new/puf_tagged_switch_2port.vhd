library ieee;
use ieee.std_logic_1164.all;

entity puf_tagged_switch_2port is
    generic (
        CORE_CLK_HZ_G : positive := 100_000_000
    );
    port (
        core_clk     : in  std_logic;
        reset_p      : in  std_logic;

        puf_enable   : in  std_logic;
        puf_id_valid : in  std_logic;
        puf_id       : in  std_logic_vector(255 downto 0);

        rx_data_i    : in  std_logic_vector(15 downto 0);
        rx_write_i   : in  std_logic_vector(1 downto 0);
        rx_last_i    : in  std_logic_vector(1 downto 0);
        rx_error_i   : in  std_logic_vector(1 downto 0);

        tx_data_o    : out std_logic_vector(15 downto 0);
        tx_valid_o   : out std_logic_vector(1 downto 0);
        tx_last_o    : out std_logic_vector(1 downto 0);
        tx_ready_i   : in  std_logic_vector(1 downto 0)
    );
end entity puf_tagged_switch_2port;

architecture rtl of puf_tagged_switch_2port is

    signal switch_tx_data :
        std_logic_vector(15 downto 0);

    signal switch_tx_valid :
        std_logic_vector(1 downto 0);

    signal switch_tx_last :
        std_logic_vector(1 downto 0);

    signal switch_tx_ready :
        std_logic_vector(1 downto 0);

    signal trailer_in_ready :
        std_logic;

    signal trailer_out_data :
        std_logic_vector(7 downto 0);

    signal trailer_out_valid :
        std_logic;

    signal trailer_out_last :
        std_logic;

begin

    SWITCH_COMP :
        entity work.satcat5_switch_2port
        generic map (
            CORE_CLK_HZ_G => CORE_CLK_HZ_G
        )
        port map (
            core_clk   => core_clk,
            reset_p    => reset_p,

            rx_data_i  => rx_data_i,
            rx_write_i => rx_write_i,
            rx_last_i  => rx_last_i,
            rx_error_i => rx_error_i,

            tx_data_o  => switch_tx_data,
            tx_valid_o => switch_tx_valid,
            tx_last_o  => switch_tx_last,
            tx_ready_i => switch_tx_ready
        );

    TRAILER_COMP :
        entity work.puf_egress_trailer
        port map (
            clk          => core_clk,
            rst          => reset_p,

            puf_enable   => puf_enable,
            puf_id_valid => puf_id_valid,
            puf_id       => puf_id,

            in_data      => switch_tx_data(15 downto 8),
            in_valid     => switch_tx_valid(1),
            in_last      => switch_tx_last(1),
            in_ready     => trailer_in_ready,

            out_data     => trailer_out_data,
            out_valid    => trailer_out_valid,
            out_last     => trailer_out_last,
            out_ready    => tx_ready_i(1)
        );

    switch_tx_ready(0) <=
        tx_ready_i(0);

    switch_tx_ready(1) <=
        trailer_in_ready;

    tx_data_o(7 downto 0) <=
        switch_tx_data(7 downto 0);

    tx_valid_o(0) <=
        switch_tx_valid(0);

    tx_last_o(0) <=
        switch_tx_last(0);

    tx_data_o(15 downto 8) <=
        trailer_out_data;

    tx_valid_o(1) <=
        trailer_out_valid;

    tx_last_o(1) <=
        trailer_out_last;

end architecture rtl;
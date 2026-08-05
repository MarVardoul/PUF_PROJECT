library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ro_channel_sim is
end ro_channel_sim;

architecture Behavioral of ro_channel_sim is

    constant COUNTER_WIDTH : positive := 24;


    signal RO_EN     : STD_LOGIC := '0';
    signal CNT_EN    : STD_LOGIC := '0';
    signal CNT_RST   : STD_LOGIC := '0';

    signal COUNT_OUT : STD_LOGIC_VECTOR(COUNTER_WIDTH-1 downto 0);
    signal OSC_OUT   : STD_LOGIC;

begin

    --------------------------------------------------------------
    -- Unit under test
    --------------------------------------------------------------

UUT : configuration work.ro_channel_sim_cfg
    generic map (
        COUNTER_WIDTH => COUNTER_WIDTH
    )
    port map (
        RO_EN     => RO_EN,
        CNT_EN    => CNT_EN,
        CNT_RST   => CNT_RST,
        COUNT_OUT => COUNT_OUT,
        OSC_OUT   => OSC_OUT
    );


    --------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------

    stimulus_process : process
    begin

        ----------------------------------------------------------
        -- Initial state and counter reset
        ----------------------------------------------------------

        RO_EN   <= '0';
        CNT_EN  <= '0';
        CNT_RST <= '1';

        wait for 100 ns;


        ----------------------------------------------------------
        -- Release counter reset
        ----------------------------------------------------------

        CNT_RST <= '0';

        wait for 100 ns;


        ----------------------------------------------------------
        -- Start ring oscillator
        ----------------------------------------------------------

        RO_EN <= '1';

        wait for 100 ns;


        ----------------------------------------------------------
        -- Start measurement
        ----------------------------------------------------------

        CNT_EN <= '1';

        wait for 1 us;


        ----------------------------------------------------------
        -- Stop counting
        ----------------------------------------------------------

        CNT_EN <= '0';

        wait for 200 ns;


        ----------------------------------------------------------
        -- Stop oscillator
        ----------------------------------------------------------

        RO_EN <= '0';

        wait for 200 ns;


        ----------------------------------------------------------
        -- Reset counter
        ----------------------------------------------------------

        CNT_RST <= '1';

        wait for 100 ns;

        CNT_RST <= '0';


        ----------------------------------------------------------
        -- End simulation
        ----------------------------------------------------------

        wait;

    end process;

end architecture Behavioral;
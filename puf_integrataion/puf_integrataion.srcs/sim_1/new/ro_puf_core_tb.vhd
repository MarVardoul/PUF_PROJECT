configuration ro_bank_sim_cfg of ro_bank is
    for Structural
        for GEN_CHANNELS(0 to 15)
            for CHANNEL_COMP : ro_channel
                use configuration work.ro_channel_sim_cfg;
            end for;
        end for;
    end for;
end configuration;


configuration ro_puf_core_sim_cfg of ro_puf_core is
    for Structural
        for BANK_COMP : ro_bank
            use configuration work.ro_bank_sim_cfg;
        end for;
    end for;
end configuration;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ro_puf_core_tb is
end ro_puf_core_tb;

architecture Behavioral of ro_puf_core_tb is

    signal SEL_A      : STD_LOGIC_VECTOR(3 downto 0) := "0011";
    signal SEL_B      : STD_LOGIC_VECTOR(3 downto 0) := "1100";
    signal ENABLE     : STD_LOGIC := '0';
    signal CNT_EN     : STD_LOGIC := '0';
    signal CNT_RST    : STD_LOGIC := '1';
    signal RESPONSE   : STD_LOGIC;
    signal VALID      : STD_LOGIC;
    signal PAIR_VALID : STD_LOGIC;
    signal DELTA      : STD_LOGIC_VECTOR(24 downto 0);

begin

    DUT : configuration work.ro_puf_core_sim_cfg
        port map (
            SEL_A      => SEL_A,
            SEL_B      => SEL_B,
            ENABLE     => ENABLE,
            CNT_EN     => CNT_EN,
            CNT_RST    => CNT_RST,
            RESPONSE   => RESPONSE,
            VALID      => VALID,
            PAIR_VALID => PAIR_VALID,
            DELTA      => DELTA
        );

    stimulus_process : process
    begin

        SEL_A   <= "0011";
        SEL_B   <= "1100";
        ENABLE  <= '0';
        CNT_EN  <= '0';
        CNT_RST <= '1';

        wait for 20 ns;

        CNT_RST <= '0';
        ENABLE  <= '1';
        CNT_EN  <= '1';

        wait for 1000 ns;

        CNT_EN <= '0';

        wait for 20 ns;

        ENABLE <= '0';

        wait for 10 ns;

        assert PAIR_VALID = '1'
            report "Error: Pair 3 and 12 should be valid"
            severity error;

        assert unsigned(DELTA) = 0
            report "Error: Equal simulated oscillator frequencies should produce DELTA = 0"
            severity error;

        assert VALID = '0'
            report "Error: Equal oscillator counts should produce VALID = 0"
            severity error;


        SEL_A   <= "0101";
        SEL_B   <= "0101";
        CNT_RST <= '1';

        wait for 20 ns;

        CNT_RST <= '0';
        ENABLE  <= '1';
        CNT_EN  <= '1';

        wait for 100 ns;

        CNT_EN <= '0';

        wait for 20 ns;

        ENABLE <= '0';

        wait for 10 ns;

        assert PAIR_VALID = '0'
            report "Error: Equal selectors should produce PAIR_VALID = 0"
            severity error;

        assert unsigned(DELTA) = 0
            report "Error: Equal selectors should produce DELTA = 0"
            severity error;

        assert VALID = '0'
            report "Error: Equal selectors should produce VALID = 0"
            severity error;


        SEL_A   <= "0000";
        SEL_B   <= "1111";
        CNT_RST <= '1';

        wait for 20 ns;

        CNT_RST <= '0';
        ENABLE  <= '1';
        CNT_EN  <= '1';

        wait for 500 ns;

        CNT_EN <= '0';

        wait for 20 ns;

        ENABLE <= '0';

        wait for 10 ns;

        assert PAIR_VALID = '1'
            report "Error: Pair 0 and 15 should be valid"
            severity error;

        assert unsigned(DELTA) = 0
            report "Error: Equal simulated oscillator frequencies should produce DELTA = 0"
            severity error;

        assert VALID = '0'
            report "Error: Equal oscillator counts should produce VALID = 0"
            severity error;

        assert false
            report "All ro_puf_core tests completed successfully"
            severity note;

        wait;

    end process;

end Behavioral;
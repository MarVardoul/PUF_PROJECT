library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ro_pair_decoder_tb is
end ro_pair_decoder_tb;

architecture Behavioral of ro_pair_decoder_tb is

    component ro_pair_decoder is
        Port (
            SEL_A      : in  STD_LOGIC_VECTOR(3 downto 0);
            SEL_B      : in  STD_LOGIC_VECTOR(3 downto 0);
            ENABLE     : in  STD_LOGIC;
            RO_EN      : out STD_LOGIC_VECTOR(15 downto 0);
            PAIR_VALID : out STD_LOGIC
        );
    end component;

    signal SEL_A      : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal SEL_B      : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal ENABLE     : STD_LOGIC := '0';
    signal RO_EN      : STD_LOGIC_VECTOR(15 downto 0);
    signal PAIR_VALID : STD_LOGIC;

begin

    DUT : ro_pair_decoder
        port map (
            SEL_A      => SEL_A,
            SEL_B      => SEL_B,
            ENABLE     => ENABLE,
            RO_EN      => RO_EN,
            PAIR_VALID => PAIR_VALID
        );

    stimulus_process : process

        variable expected_ro_en : STD_LOGIC_VECTOR(15 downto 0);

    begin

        SEL_A  <= "0101";
        SEL_B  <= "0101";
        ENABLE <= '1';

        wait for 10 ns;

        assert PAIR_VALID = '0'
            report "Error: Equal selectors should produce PAIR_VALID = 0"
            severity error;

        assert RO_EN = X"0000"
            report "Error: Equal selectors should disable all oscillators"
            severity error;


        SEL_A  <= "0011";
        SEL_B  <= "1100";
        ENABLE <= '0';

        wait for 10 ns;

        assert PAIR_VALID = '1'
            report "Error: Different selectors should produce PAIR_VALID = 1"
            severity error;

        assert RO_EN = X"0000"
            report "Error: ENABLE = 0 should disable all oscillators"
            severity error;


        SEL_A  <= "0011";
        SEL_B  <= "1100";
        ENABLE <= '1';

        expected_ro_en := (others => '0');
        expected_ro_en(3)  := '1';
        expected_ro_en(12) := '1';

        wait for 10 ns;

        assert PAIR_VALID = '1'
            report "Error: Pair 3 and 12 should be valid"
            severity error;

        assert RO_EN = expected_ro_en
            report "Error: RO3 and RO12 were not enabled correctly"
            severity error;


        SEL_A  <= "0000";
        SEL_B  <= "1111";
        ENABLE <= '1';

        expected_ro_en := (others => '0');
        expected_ro_en(0)  := '1';
        expected_ro_en(15) := '1';

        wait for 10 ns;

        assert PAIR_VALID = '1'
            report "Error: Pair 0 and 15 should be valid"
            severity error;

        assert RO_EN = expected_ro_en
            report "Error: RO0 and RO15 were not enabled correctly"
            severity error;


        ENABLE <= '0';

        wait for 10 ns;

        assert RO_EN = X"0000"
            report "Error: Oscillators remained enabled after ENABLE became 0"
            severity error;

        assert false
            report "All ro_pair_decoder tests completed successfully"
            severity note;

        wait;

    end process;

end Behavioral;
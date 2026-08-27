library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_satcat5_switch_2port is
end entity;

architecture sim of tb_satcat5_switch_2port is

    constant CLK_PERIOD_C : time := 10 ns;

    constant FRAME_BCAST_C : std_logic_vector(511 downto 0) :=
        x"FFFFFFFFFFFF"
      & x"020000000001"
      & x"88B5"
      & x"000102030405060708090A0B0C0D0E0F"
      & x"101112131415161718191A1B1C1D1E1F"
      & x"202122232425262728292A2B2C2D"
      & x"EA2A8CF8";

    constant FRAME_A_C : std_logic_vector(511 downto 0) :=
        x"020000000002"
      & x"020000000001"
      & x"88B5"
      & x"000102030405060708090A0B0C0D0E0F"
      & x"101112131415161718191A1B1C1D1E1F"
      & x"202122232425262728292A2B2C2D"
      & x"824A8FB4";

    constant FRAME_B_C : std_logic_vector(511 downto 0) :=
        x"020000000001"
      & x"020000000002"
      & x"88B5"
      & x"808182838485868788898A8B8C8D8E8F"
      & x"909192939495969798999A9B9C9D9E9F"
      & x"A0A1A2A3A4A5A6A7A8A9AAABACAD"
      & x"5ECFE359";

    signal core_clk   : std_logic := '0';
    signal reset_p    : std_logic := '1';

    signal rx_data_i  : std_logic_vector(15 downto 0) := (others => '0');
    signal rx_write_i : std_logic_vector(1 downto 0) := (others => '0');
    signal rx_last_i  : std_logic_vector(1 downto 0) := (others => '0');
    signal rx_error_i : std_logic_vector(1 downto 0) := (others => '0');

    signal tx_data_o  : std_logic_vector(15 downto 0);
    signal tx_valid_o : std_logic_vector(1 downto 0);
    signal tx_last_o  : std_logic_vector(1 downto 0);
    signal tx_ready_i : std_logic_vector(1 downto 0) := (others => '1');

    signal diag_clear : std_logic := '0';

    signal rx_count_0 : integer := 0;
    signal rx_count_1 : integer := 0;
    signal rx_last_0  : integer := 0;
    signal rx_last_1  : integer := 0;

    signal tx_valid_count_0 : integer := 0;
    signal tx_valid_count_1 : integer := 0;

    signal tx_count_0 : integer := 0;
    signal tx_count_1 : integer := 0;

    signal tx_last_count_0 : integer := 0;
    signal tx_last_count_1 : integer := 0;

    signal tx_last_pos_0 : integer := -1;
    signal tx_last_pos_1 : integer := -1;

    signal tx_capture_0 : std_logic_vector(511 downto 0) := (others => '0');
    signal tx_capture_1 : std_logic_vector(511 downto 0) := (others => '0');

begin

    core_clk <= not core_clk after CLK_PERIOD_C / 2;

    DUT : entity work.satcat5_switch_2port
        generic map (
            CORE_CLK_HZ_G => 100_000_000
        )
        port map (
            core_clk   => core_clk,
            reset_p    => reset_p,
            rx_data_i  => rx_data_i,
            rx_write_i => rx_write_i,
            rx_last_i  => rx_last_i,
            rx_error_i => rx_error_i,
            tx_data_o  => tx_data_o,
            tx_valid_o => tx_valid_o,
            tx_last_o  => tx_last_o,
            tx_ready_i => tx_ready_i
        );

    MONITOR : process(core_clk)
    begin

        if rising_edge(core_clk) then

            if diag_clear = '1' then

                rx_count_0 <= 0;
                rx_count_1 <= 0;
                rx_last_0  <= 0;
                rx_last_1  <= 0;

                tx_valid_count_0 <= 0;
                tx_valid_count_1 <= 0;

                tx_count_0 <= 0;
                tx_count_1 <= 0;

                tx_last_count_0 <= 0;
                tx_last_count_1 <= 0;

                tx_last_pos_0 <= -1;
                tx_last_pos_1 <= -1;

                tx_capture_0 <= (others => '0');
                tx_capture_1 <= (others => '0');

            else

                if rx_write_i(0) = '1' then

                    rx_count_0 <= rx_count_0 + 1;

                    if rx_last_i(0) = '1' then
                        rx_last_0 <= rx_last_0 + 1;
                    end if;

                end if;

                if rx_write_i(1) = '1' then

                    rx_count_1 <= rx_count_1 + 1;

                    if rx_last_i(1) = '1' then
                        rx_last_1 <= rx_last_1 + 1;
                    end if;

                end if;

                if tx_valid_o(0) = '1' then
                    tx_valid_count_0 <= tx_valid_count_0 + 1;
                end if;

                if tx_valid_o(1) = '1' then
                    tx_valid_count_1 <= tx_valid_count_1 + 1;
                end if;

                if tx_valid_o(0) = '1' and tx_ready_i(0) = '1' then

                    if tx_count_0 < 64 then

                        tx_capture_0(
                            511 - 8 * tx_count_0 downto
                            504 - 8 * tx_count_0
                        ) <= tx_data_o(7 downto 0);

                    end if;

                    if tx_last_o(0) = '1' then
                        tx_last_count_0 <= tx_last_count_0 + 1;
                        tx_last_pos_0 <= tx_count_0;
                    end if;

                    tx_count_0 <= tx_count_0 + 1;

                end if;

                if tx_valid_o(1) = '1' and tx_ready_i(1) = '1' then

                    if tx_count_1 < 64 then

                        tx_capture_1(
                            511 - 8 * tx_count_1 downto
                            504 - 8 * tx_count_1
                        ) <= tx_data_o(15 downto 8);

                    end if;

                    if tx_last_o(1) = '1' then
                        tx_last_count_1 <= tx_last_count_1 + 1;
                        tx_last_pos_1 <= tx_count_1;
                    end if;

                    tx_count_1 <= tx_count_1 + 1;

                end if;

            end if;

        end if;

    end process;

    STIM : process

        procedure clear_diagnostics is
        begin

            wait until falling_edge(core_clk);
            diag_clear <= '1';

            wait until rising_edge(core_clk);
            wait until falling_edge(core_clk);

            diag_clear <= '0';

        end procedure;

        procedure reset_dut is
        begin

            wait until falling_edge(core_clk);

            reset_p <= '1';
            rx_write_i <= (others => '0');
            rx_last_i <= (others => '0');
            rx_error_i <= (others => '0');
            tx_ready_i <= (others => '1');

            wait for 1 us;

            wait until falling_edge(core_clk);
            reset_p <= '0';

            wait for 2 us;

        end procedure;

        procedure send_frame(
            constant port_number : in integer;
            constant frame_data  : in std_logic_vector(511 downto 0)
        ) is
        begin

            for i in 0 to 63 loop

                wait until falling_edge(core_clk);

                rx_data_i(
                    8 * port_number + 7 downto
                    8 * port_number
                ) <= frame_data(
                    511 - 8 * i downto
                    504 - 8 * i
                );

                rx_write_i(port_number) <= '1';

                if i = 63 then
                    rx_last_i(port_number) <= '1';
                else
                    rx_last_i(port_number) <= '0';
                end if;

                wait until rising_edge(core_clk);
                wait until falling_edge(core_clk);

                rx_write_i(port_number) <= '0';
                rx_last_i(port_number) <= '0';

                if i /= 63 then
                    for j in 1 to 7 loop
                        wait until rising_edge(core_clk);
                    end loop;
                end if;

            end loop;

            rx_data_i(
                8 * port_number + 7 downto
                8 * port_number
            ) <= (others => '0');

        end procedure;

        procedure print_summary(
            constant test_number : in integer
        ) is
        begin

            report "========================================"
                severity note;

            report "DIAGNOSTIC TEST " &
                   integer'image(test_number)
                severity note;

            report "RX0 bytes = " &
                   integer'image(rx_count_0)
                severity note;

            report "RX0 last count = " &
                   integer'image(rx_last_0)
                severity note;

            report "RX1 bytes = " &
                   integer'image(rx_count_1)
                severity note;

            report "RX1 last count = " &
                   integer'image(rx_last_1)
                severity note;

            report "TX0 valid cycles = " &
                   integer'image(tx_valid_count_0)
                severity note;

            report "TX0 accepted bytes = " &
                   integer'image(tx_count_0)
                severity note;

            report "TX0 last count = " &
                   integer'image(tx_last_count_0)
                severity note;

            report "TX0 last position = " &
                   integer'image(tx_last_pos_0)
                severity note;

            report "TX1 valid cycles = " &
                   integer'image(tx_valid_count_1)
                severity note;

            report "TX1 accepted bytes = " &
                   integer'image(tx_count_1)
                severity note;

            report "TX1 last count = " &
                   integer'image(tx_last_count_1)
                severity note;

            report "TX1 last position = " &
                   integer'image(tx_last_pos_1)
                severity note;

            report "========================================"
                severity note;

        end procedure;

    begin

        reset_p <= '1';
        rx_data_i <= (others => '0');
        rx_write_i <= (others => '0');
        rx_last_i <= (others => '0');
        rx_error_i <= (others => '0');
        tx_ready_i <= (others => '1');

        wait for 1 us;

        reset_dut;
        clear_diagnostics;

        report "TEST 1: BROADCAST PORT 0 TO PORT 1"
            severity note;

        send_frame(
            port_number => 0,
            frame_data  => FRAME_BCAST_C
        );

        wait for 50 us;

        print_summary(1);

        assert rx_count_0 = 64
            report "TEST 1: Input monitor did not observe 64 bytes"
            severity error;

        assert rx_last_0 = 1
            report "TEST 1: Input monitor did not observe exactly one RX last"
            severity error;

        if tx_count_1 = 64 then

            assert tx_capture_1 = FRAME_BCAST_C
                report "TEST 1: Output frame data mismatch"
                severity error;

            assert tx_last_count_1 = 1
                report "TEST 1: Incorrect TX last count"
                severity error;

            assert tx_last_pos_1 = 63
                report "TEST 1: TX last not on byte 63"
                severity error;

            report "TEST 1: BROADCAST FORWARDING PASSED"
                severity note;

        elsif tx_count_1 = 0 then

            report "TEST 1: NO OUTPUT ACTIVITY ON EXPECTED PORT 1"
                severity error;

        else

            report "TEST 1: PARTIAL OUTPUT FRAME ON PORT 1"
                severity error;

        end if;

        if tx_count_0 /= 0 then
            report "TEST 1: FRAME APPEARED ON INGRESS PORT 0"
                severity error;
        end if;

        reset_dut;
        clear_diagnostics;

        report "TEST 2: UNKNOWN UNICAST PORT 0 TO PORT 1"
            severity note;

        send_frame(
            port_number => 0,
            frame_data  => FRAME_A_C
        );

        wait for 50 us;

        print_summary(2);

        assert rx_count_0 = 64
            report "TEST 2: Input monitor did not observe 64 bytes"
            severity error;

        assert rx_last_0 = 1
            report "TEST 2: Input monitor did not observe exactly one RX last"
            severity error;

        if tx_count_1 = 64 then

            assert tx_capture_1 = FRAME_A_C
                report "TEST 2: Output frame data mismatch"
                severity error;

            assert tx_last_count_1 = 1
                report "TEST 2: Incorrect TX last count"
                severity error;

            assert tx_last_pos_1 = 63
                report "TEST 2: TX last not on byte 63"
                severity error;

            report "TEST 2: UNKNOWN UNICAST FORWARDING PASSED"
                severity note;

        elsif tx_count_1 = 0 then

            report "TEST 2: NO OUTPUT ACTIVITY ON EXPECTED PORT 1"
                severity error;

        else

            report "TEST 2: PARTIAL OUTPUT FRAME ON PORT 1"
                severity error;

        end if;

        if tx_count_0 /= 0 then
            report "TEST 2: FRAME APPEARED ON INGRESS PORT 0"
                severity error;
        end if;

        reset_dut;
        clear_diagnostics;

        report "TEST 3: REVERSE UNKNOWN UNICAST PORT 1 TO PORT 0"
            severity note;

        send_frame(
            port_number => 1,
            frame_data  => FRAME_B_C
        );

        wait for 50 us;

        print_summary(3);

        assert rx_count_1 = 64
            report "TEST 3: Input monitor did not observe 64 bytes"
            severity error;

        assert rx_last_1 = 1
            report "TEST 3: Input monitor did not observe exactly one RX last"
            severity error;

        if tx_count_0 = 64 then

            assert tx_capture_0 = FRAME_B_C
                report "TEST 3: Output frame data mismatch"
                severity error;

            assert tx_last_count_0 = 1
                report "TEST 3: Incorrect TX last count"
                severity error;

            assert tx_last_pos_0 = 63
                report "TEST 3: TX last not on byte 63"
                severity error;

            report "TEST 3: REVERSE FORWARDING PASSED"
                severity note;

        elsif tx_count_0 = 0 then

            report "TEST 3: NO OUTPUT ACTIVITY ON EXPECTED PORT 0"
                severity error;

        else

            report "TEST 3: PARTIAL OUTPUT FRAME ON PORT 0"
                severity error;

        end if;

        if tx_count_1 /= 0 then
            report "TEST 3: FRAME APPEARED ON INGRESS PORT 1"
                severity error;
        end if;

        report "DIAGNOSTIC TESTBENCH COMPLETED"
            severity note;

        wait;

    end process;

end architecture;
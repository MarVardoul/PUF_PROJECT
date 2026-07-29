library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity puf_signature_generator is
    Port (
        CLK   : in  STD_LOGIC;
        RST   : in  STD_LOGIC;
        START : in  STD_LOGIC;

        -- Results coming from puf_manager
        MANAGER_DONE     : in  STD_LOGIC;
        MANAGER_RESPONSE : in  STD_LOGIC;
        MANAGER_VALID    : in  STD_LOGIC;

        -- Commands going to puf_manager
        MANAGER_START : out STD_LOGIC;
        SEL_A         : out STD_LOGIC_VECTOR(3 downto 0);
        SEL_B         : out STD_LOGIC_VECTOR(3 downto 0);

        -- Complete 120-pair PUF response
        SIGNATURE  : out STD_LOGIC_VECTOR(119 downto 0);
        VALID_MASK : out STD_LOGIC_VECTOR(119 downto 0);

        BUSY            : out STD_LOGIC;
        DONE            : out STD_LOGIC;
        SIGNATURE_READY : out STD_LOGIC
    );
end puf_signature_generator;


architecture Behavioral of puf_signature_generator is

    type state_type is (
        IDLE,
        START_MEASUREMENT,
        WAIT_FOR_DONE,
        WAIT_START_LOW
    );

    signal state : state_type := IDLE;

    -- Current oscillator pair
    signal a_index : integer range 0 to 14 := 0;
    signal b_index : integer range 1 to 15 := 1;

    -- Current signature bit
    signal bit_index : integer range 0 to 119 := 0;

    signal signature_reg  : STD_LOGIC_VECTOR(119 downto 0)
                          := (others => '0');

    signal valid_mask_reg : STD_LOGIC_VECTOR(119 downto 0)
                          := (others => '0');

    signal manager_start_reg : STD_LOGIC := '0';
    signal busy_reg          : STD_LOGIC := '0';
    signal done_reg          : STD_LOGIC := '0';
    signal ready_reg         : STD_LOGIC := '0';

begin

    MANAGER_START   <= manager_start_reg;
    BUSY            <= busy_reg;
    DONE            <= done_reg;
    SIGNATURE_READY <= ready_reg;

    SIGNATURE  <= signature_reg;
    VALID_MASK <= valid_mask_reg;

    SEL_A <= STD_LOGIC_VECTOR(to_unsigned(a_index, 4));
    SEL_B <= STD_LOGIC_VECTOR(to_unsigned(b_index, 4));


    process(CLK, RST)
    begin

        if RST = '1' then

            state <= IDLE;

            a_index   <= 0;
            b_index   <= 1;
            bit_index <= 0;

            signature_reg  <= (others => '0');
            valid_mask_reg <= (others => '0');

            manager_start_reg <= '0';
            busy_reg          <= '0';
            done_reg          <= '0';
            ready_reg         <= '0';


        elsif rising_edge(CLK) then

            -- Normally low. Asserted for one clock only.
            manager_start_reg <= '0';

            -- DONE is a one-clock pulse.
            done_reg <= '0';


            case state is

                --------------------------------------------------
                -- Wait for request
                --------------------------------------------------
                when IDLE =>

                    busy_reg <= '0';

                    if START = '1' then

                        -- Start a completely new signature
                        signature_reg  <= (others => '0');
                        valid_mask_reg <= (others => '0');

                        ready_reg <= '0';

                        a_index   <= 0;
                        b_index   <= 1;
                        bit_index <= 0;

                        busy_reg <= '1';

                        state <= START_MEASUREMENT;

                    end if;


                --------------------------------------------------
                -- Give puf_manager a one-clock START pulse
                --------------------------------------------------
                when START_MEASUREMENT =>

                    busy_reg <= '1';

                    manager_start_reg <= '1';

                    state <= WAIT_FOR_DONE;


                --------------------------------------------------
                -- Wait until manager finishes this pair
                --------------------------------------------------
                when WAIT_FOR_DONE =>

                    busy_reg <= '1';

                    if MANAGER_DONE = '1' then

                        -- Store this PUF response
                        signature_reg(bit_index)
                            <= MANAGER_RESPONSE;

                        valid_mask_reg(bit_index)
                            <= MANAGER_VALID;


                        -- Was this pair (14,15)?
                        if bit_index = 119 then

                            busy_reg  <= '0';
                            done_reg  <= '1';
                            ready_reg <= '1';

                            state <= WAIT_START_LOW;

                        else

                            -- Advance to next signature bit
                            bit_index <= bit_index + 1;

                            -- Generate pairs:
                            --
                            -- (0,1), (0,2), ... (0,15)
                            -- (1,2), (1,3), ... (1,15)
                            -- ...
                            -- (14,15)

                            if b_index = 15 then

                                a_index <= a_index + 1;

                                -- Uses the old value of a_index,
                                -- therefore new B = new A + 1
                                b_index <= a_index + 2;

                            else

                                b_index <= b_index + 1;

                            end if;

                            state <= START_MEASUREMENT;

                        end if;

                    end if;


                --------------------------------------------------
                -- Prevent held pushbutton from starting
                -- another complete sweep
                --------------------------------------------------
                when WAIT_START_LOW =>

                    busy_reg <= '0';

                    if START = '0' then
                        state <= IDLE;
                    end if;


                when others =>

                    state <= IDLE;

            end case;

        end if;

    end process;

end Behavioral;
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.types.all;

library unisim;
use unisim.vcomponents.all;

entity tmp05 is
    port (
        tmp05Pin      : inout std_logic;
        registerRead  : out   tmp05_registerRead_t;
        registerWrite : in    tmp05_registerWrite_t
        );
end tmp05;

architecture Behavioral of tmp05 is
    type tmp05_states_t is (sync1, sync2, sync3, countTL, countTH);
    signal nextState         : tmp05_states_t := sync1;
    signal TLcounter         : unsigned(23 downto 0);
    signal THcounter         : unsigned(23 downto 0);
    signal TlCounter_latched : std_logic_vector(15 downto 0);
    signal ThCounter_latched : std_logic_vector(15 downto 0);

    signal debugCounter : unsigned(23 downto 0);

    --    signal tmpClockCounter : integer range 0 to 255 := 0;
    --    signal tmpClock : std_logic := '0';
    --    signal tmpClockRisingEdge : std_logic := '0';

    --    constant actualClockRateMHz : integer range 0 to 255 := 119;

    signal tmp05In_sync : std_logic_vector(5 downto 0);

    signal tmp05In       : std_logic := '0';
    signal tmp05Tristate : std_logic := '0';

    signal conversionStart : std_logic := '0';
    signal busy            : std_logic := '0';

begin

    --a: IBUF port map(I => tmp05Pin, O => tmp05In);
    a : IOBUF port map(O => tmp05In, IO => tmp05Pin, I => '0', T => tmp05Tristate);

    registerRead.tl   <= TlCounter_latched;
    registerRead.th   <= ThCounter_latched;
    registerRead.busy <= busy;
    conversionStart   <= registerWrite.conversionStart;

    P0 : process (registerWrite.clock)
    begin
        if rising_edge(registerWrite.clock) then
            if (registerWrite.reset = '1') then
                tmp05In_sync <= (others => '0');
            else
                tmp05In_sync <= tmp05In & tmp05In_sync(tmp05In_sync'length - 1 downto 1);
            end if;
        end if;
    end process P0;

    P1 : process (registerWrite.clock)
    begin
        if rising_edge(registerWrite.clock) then
            tmp05Tristate <= '1';              -- autoreset
            busy          <= '1';              -- autoreset
            if (registerWrite.reset = '1') then
                nextState         <= sync1;
                TlCounter_latched <= x"1234";  -- ## debug
                ThCounter_latched <= x"4321";  -- ## debug
                debugCounter      <= x"000000";
            else
                case nextState is
                    when sync1 =>
                        busy <= '0';           -- autoreset
                        --if (tmp05In_sync(0) = '0') then
                        if (conversionStart = '1') then
                            nextState    <= sync2;
                            TLcounter    <= (others => '0');
                            THcounter    <= (others => '0');
                            debugCounter <= x"000000";
                        end if;

                    when sync2 =>
                        debugCounter  <= debugCounter + 1;
                        tmp05Tristate <= '0';            -- autoreset
                        THcounter     <= THcounter + 1;  -- dual use
                        if (THcounter = x"0010") then
                            nextState <= sync3;
                            THcounter <= (others => '0');
                        end if;

                    when sync3 =>
                        debugCounter <= debugCounter + 1;
                        if (tmp05In_sync(0) = '1') then
                            THcounter <= THcounter + 1;
                            nextState <= countTH;
                        end if;

                    when countTH =>
                        debugCounter <= debugCounter + 1;
                        if (tmp05In_sync(0) = '1') then
                            THcounter <= THcounter + 1;
                        else
                            nextState <= countTL;
                            TLcounter <= TLcounter + 1;
                        end if;

                    when countTL =>
                        debugCounter <= debugCounter + 1;
                        if (tmp05In_sync(0) = '0') then
                            TLcounter <= TLcounter + 1;
                        else
                            nextState                 <= sync1;
                            TlCounter_latched         <= std_logic_vector(TLcounter(23 downto 8));
                            ThCounter_latched         <= std_logic_vector(THcounter(23 downto 8));
                            registerRead.debugCounter <= std_logic_vector(debugCounter);
                            TLcounter                 <= (others => '0');
                            THcounter                 <= (others => '0');
                        end if;

                    when others => nextState <= sync1;
                end case;
            end if;
        end if;
    end process P1;

end Behavioral;

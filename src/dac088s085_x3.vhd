----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:24:53 03/15/2017 
-- Design Name: 
-- Module Name:    dac088s085_x3 - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity dac088s085_x3 is
    port (
        notSync       : out std_logic;
        mosi          : out std_logic;
        sclk          : out std_logic;
        registerRead  : out dac088s085_x3_registerRead_t;
        registerWrite : in  dac088s085_x3_registerWrite_t
        );
end dac088s085_x3;

architecture behavioral of dac088s085_x3 is
    constant spiNumberOfBits  : integer              := 3 * 16;
    constant sclkDivisor      : unsigned(3 downto 0) := x"3";  -- ((systemClock / spiClock) / 2) ... 3=~20MHz@118MHz
    constant sclkDefaultLevel : std_logic            := '0';
    constant mosiDefaultLevel : std_logic            := '0';
    --constant mosiValidEdge : std_logic := '0'; -- '0'=rising, '1'=falling
    --constant mosiMsbinitState : std_logic := '1'; -- '0'=LsbinitState, '1'=MsbinitState

    type spiState_t is (idle, init1, init2, load, prepare, transfer2, transfer3);
    signal spiState : spiState_t := init1;

    signal mosiBuffer_latched : std_logic_vector (spiNumberOfBits - 1 downto 0);

    signal spiCounter         : integer range 0 to spiNumberOfBits := 0;
    signal sclkDivisorCounter : unsigned (3 downto 0)              := x"0";
    signal sclk_i             : std_logic;
    signal sclkEnable         : std_logic;
    signal sclkEdgeRising     : std_logic;
    signal sclkEdgeFalling    : std_logic;

    signal busy : std_logic;

    signal nSync     : std_logic                    := '0';
    signal ss        : std_logic_vector(4 downto 0) := "00000";
    signal initState : integer range 0 to 2         := 2;
    signal chip      : std_logic_vector(4 downto 0) := "00000";

    signal i : integer range 0 to 7 := 0;
    signal j : integer range 0 to 7 := 0;
    signal k : integer range 0 to 7 := 0;

    signal valuesChangedChip0 : std_logic_vector(7 downto 0) := (others => '0');
    signal valuesChangedChip1 : std_logic_vector(7 downto 0) := (others => '0');
    signal valuesChangedChip2 : std_logic_vector(7 downto 0) := (others => '0');

begin

    mosi                 <= mosiBuffer_latched(mosiBuffer_latched'length - 1);
    sclk                 <= sclk_i;
    notSync              <= nSync;
    registerRead.dacBusy <= busy;

    registerRead.valuesChip0 <= registerWrite.valuesChip0;
    registerRead.valuesChip1 <= registerWrite.valuesChip1;
    registerRead.valuesChip2 <= registerWrite.valuesChip2;

    registerRead.valuesChangedChip0 <= valuesChangedChip0;
    registerRead.valuesChangedChip1 <= valuesChangedChip1;
    registerRead.valuesChangedChip2 <= valuesChangedChip2;

    P0 : process (registerWrite.clock)
    begin
        if rising_edge(registerWrite.clock) then
            sclkEdgeRising  <= '0';                  -- autoreset
            sclkEdgeFalling <= '0';                  -- autoreset
            if (registerWrite.reset = '1') then
                sclkDivisorCounter <= to_unsigned(0, sclkDivisorCounter'length);
                sclk_i             <= sclkDefaultLevel;
            else
                if (sclkEnable = '1') then
                    if (sclkDivisorCounter = sclkDivisor) then
                        sclkDivisorCounter <= to_unsigned(0, sclkDivisorCounter'length);
                        sclk_i             <= not sclk_i;
                        if ((sclk_i = '0')) then
                            sclkEdgeRising <= '1';   -- autoreset
                        end if;
                        if ((sclk_i = '1')) then
                            sclkEdgeFalling <= '1';  -- autoreset
                        end if;
                    else
                        sclkDivisorCounter <= sclkDivisorCounter + 1;
                    end if;
                else
                    sclk_i             <= sclkDefaultLevel;
                    sclkDivisorCounter <= to_unsigned(0, sclkDivisorCounter'length);
                end if;
            end if;
        end if;
    end process P0;

    spi2 : process (registerWrite.clock)
        variable tempChannl0 : std_logic_vector(2 downto 0) := "000";
        variable tempChannl1 : std_logic_vector(2 downto 0) := "000";
        variable tempChannl2 : std_logic_vector(2 downto 0) := "000";
        variable tempValue0  : std_logic_vector(7 downto 0) := x"00";
        variable tempValue1  : std_logic_vector(7 downto 0) := x"00";
        variable tempValue2  : std_logic_vector(7 downto 0) := x"00";
    begin
        if rising_edge(registerWrite.clock) then
            sclkEnable         <= '0';  -- autoreset
            busy               <= '0';  -- autoreset
            nSync              <= '1';  -- autoreset
            --registerRead.valuesChangedChip0Reset <= x"00"; -- autoreset
            --registerRead.valuesChangedChip1Reset <= x"00"; -- autoreset
            --registerRead.valuesChangedChip2Reset <= x"00"; -- autoreset
            valuesChangedChip0 <= valuesChangedChip0 or registerWrite.valuesChangedChip0;
            valuesChangedChip1 <= valuesChangedChip1 or registerWrite.valuesChangedChip1;
            valuesChangedChip2 <= valuesChangedChip2 or registerWrite.valuesChangedChip2;
            if (registerWrite.reset = '1') then
                spiState           <= idle;
                initState          <= 2;
                i                  <= 0;
                j                  <= 0;
                k                  <= 0;
                tempChannl0        := "000";
                tempChannl1        := "000";
                tempChannl2        := "000";
                tempValue0         := x"00";
                tempValue1         := x"00";
                tempValue2         := x"00";
                valuesChangedChip0 <= x"00";  -- init will be in register interface
                valuesChangedChip1 <= x"00";
                valuesChangedChip2 <= x"00";
            else

                if (registerWrite.init = '1') then
                    initState <= 2;
                end if;

                case spiState is
                    when init1 =>
                        mosiBuffer_latched <= x"9000" & x"9000" & x"9000";  -- mode: WTM
                        spiState           <= prepare;

                    when init2 =>
                        mosiBuffer_latched <= x"c000" & x"c000" & x"c100";  -- broadcast: set all dacs
                        spiState           <= prepare;

                    when idle =>
                        if ((valuesChangedChip0 /= x"00") or (valuesChangedChip1 /= x"00") or (valuesChangedChip2 /= x"00")) then
                            spiState <= load;
                            i        <= getFistOneFromRight8(valuesChangedChip0);
                            j        <= getFistOneFromRight8(valuesChangedChip1);
                            k        <= getFistOneFromRight8(valuesChangedChip2);
                        end if;

                        if (initState = 1) then
                            spiState  <= init2;
                            initState <= initState - 1;
                        end if;
                        if (initState = 2) then
                            spiState  <= init1;
                            initState <= initState - 1;
                        end if;

                    when load =>
                        busy        <= '1';  -- autoreset
                        tempChannl0 := std_logic_vector(to_unsigned(i, tempChannl0'length));
                        tempChannl1 := std_logic_vector(to_unsigned(j, tempChannl1'length));
                        tempChannl2 := std_logic_vector(to_unsigned(k, tempChannl2'length));
                        tempValue0  := registerWrite.valuesChip0(i);
                        tempValue1  := registerWrite.valuesChip1(j);
                        tempValue2  := registerWrite.valuesChip2(k);

                                        --registerRead.valuesChangedChip0Reset(i) <= '1'; -- autoreset
                                        --registerRead.valuesChangedChip1Reset(j) <= '1'; -- autoreset
                                        --registerRead.valuesChangedChip2Reset(k) <= '1'; -- autoreset
                        valuesChangedChip0(i) <= '0';
                        valuesChangedChip1(j) <= '0';
                        valuesChangedChip2(k) <= '0';

                        mosiBuffer_latched <= "0" & tempChannl2 & tempValue2 & "0000" & "0" & tempChannl1 & tempValue1 & "0000" & "0" & tempChannl0 & tempValue0 & "0000";
                        spiState           <= prepare;

                    when prepare =>
                        busy       <= '1';  -- autoreset
                        spiCounter <= mosiBuffer_latched'length - 1;
                        spiState   <= transfer2;

                    when transfer2 =>
                        nSync      <= '0';  -- autoreset
                        busy       <= '1';  -- autoreset
                        sclkEnable <= '1';  -- autoreset
                        if (sclkEdgeRising = '1') then
                            if (spiCounter /= mosiBuffer_latched'length - 1) then
                                mosiBuffer_latched(mosiBuffer_latched'length - 1 downto 0) <= mosiBuffer_latched(mosiBuffer_latched'length - 2 downto 0) & mosiDefaultLevel;
                            end if;
                            spiCounter <= spiCounter - 1;
                            if (spiCounter = 0) then
                                spiState <= transfer3;
                            end if;
                        end if;

                    when transfer3 =>
                        nSync      <= '0';  -- autoreset
                        busy       <= '1';  -- autoreset
                        sclkEnable <= '1';  -- autoreset
                        if (sclkEdgeFalling = '1') then
                            spiState <= idle;
                        end if;

                end case;
            end if;
        end if;
    end process spi2;

end behavioral;

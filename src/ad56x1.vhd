----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:24:30 03/24/2017 
-- Design Name: 
-- Module Name:    ad56x1 - Behavioral 
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

entity ad56x1 is
	port (
		notSync0      : out std_logic;
		notSync1      : out std_logic;
		mosi          : out std_logic;
		sclk          : out std_logic;
		registerRead  : out ad56x1_registerRead_t;
		registerWrite : in ad56x1_registerWrite_t
	);
end ad56x1;

architecture Behavioral of ad56x1 is
	constant spiNumberOfBits  : integer              := 16;
	constant sclkDivisor      : unsigned(3 downto 0) := x"3"; -- ((systemClock / spiClock) / 2) ... 3=~20MHz@118MHz
	constant sclkDefaultLevel : std_logic            := '0';
	constant mosiDefaultLevel : std_logic            := '0';
	--constant mosiValidEdge : std_logic := '0'; -- '0'=rising, '1'=falling
	--constant mosiMsbinitState : std_logic := '1'; -- '0'=LsbinitState, '1'=MsbinitState

	type spiState_t is (idle, initChip0, initChip1, loadChip0, loadChip1, prepare, prepareNSync, transfer1, transfer2);
	signal spiState : spiState_t := idle;

	signal mosiBuffer_latched : std_logic_vector (spiNumberOfBits - 1 downto 0);

	signal spiCounter         : integer range 0 to spiNumberOfBits := 0;
	signal sclkDivisorCounter : unsigned (3 downto 0)              := x"0";
	signal sclk_i             : std_logic;
	signal sclkEnable         : std_logic;
	signal sclkEdgeRising     : std_logic;
	signal sclkEdgeFalling    : std_logic;

	signal busy : std_logic;

	signal nSync     : std_logic            := '0';
	signal initState : integer range 0 to 2 := 2;
	signal chip      : std_logic            := '0';

	constant nSyncIdle    : std_logic            := '0';
	signal prepareCounter : integer range 0 to 7 := 0;
	signal activeChip     : std_logic_vector (1 downto 0);

	signal valueChangedChip0 : std_logic := '0';
	signal valueChangedChip1 : std_logic := '0';

begin

	mosi                 <= mosiBuffer_latched(mosiBuffer_latched'length - 1);
	sclk                 <= sclk_i;
	registerRead.dacBusy <= busy;

	registerRead.valueChip0 <= registerWrite.valueChip0;
	registerRead.valueChip1 <= registerWrite.valueChip1;

	P0 : process (registerWrite.clock)
	begin
		if rising_edge(registerWrite.clock) then
			sclkEdgeRising  <= '0'; -- autoreset
			sclkEdgeFalling <= '0'; -- autoreset
			if (registerWrite.reset = '1') then
				sclkDivisorCounter <= to_unsigned(0, sclkDivisorCounter'length);
				sclk_i             <= sclkDefaultLevel;
			else
				if (sclkEnable = '1') then
					if (sclkDivisorCounter = sclkDivisor) then
						sclkDivisorCounter <= to_unsigned(0, sclkDivisorCounter'length);
						sclk_i             <= not sclk_i;
						if ((sclk_i = '0')) then
							sclkEdgeRising <= '1'; -- autoreset
						end if;
						if ((sclk_i = '1')) then
							sclkEdgeFalling <= '1'; -- autoreset
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
	begin
		if rising_edge(registerWrite.clock) then
			sclkEnable <= '0';       -- autoreset
			busy       <= '0';       -- autoreset
			nSync      <= nSyncIdle; -- autoreset
			if (registerWrite.reset = '1') then
				spiState          <= idle;
				initState         <= 2;
				chip              <= '0';
				activeChip        <= "00";
				valueChangedChip0 <= '0';
				valueChangedChip1 <= '0';
			else
				valueChangedChip0 <= valueChangedChip0 or registerWrite.valueChangedChip0;
				valueChangedChip1 <= valueChangedChip1 or registerWrite.valueChangedChip1;

				--				if(registerWrite.init = '1') then
				--					initState <= 2;
				--				end if;

				case spiState is
						--					when initChip0 =>
						--						activeChip(0) <= '1';
						--						mosiBuffer_latched <= "00" & x"800" & "00"; -- value 50%
						--						spiState <= prepare;
						--					
						--					when initChip1 =>
						--						activeChip(1) <= '1';
						--						mosiBuffer_latched <= "00" & x"800" & "00"; -- value 50%
						--						spiState <= prepare;

					when idle =>
						activeChip <= "00";
						if ((valueChangedChip0 = '0') and (valueChangedChip1 = '1')) then
							spiState <= loadChip1;
						elsif ((valueChangedChip0 = '1') and (valueChangedChip1 = '0')) then
							spiState <= loadChip0;
						elsif ((valueChangedChip0 = '1') and (valueChangedChip1 = '1')) then
							chip <= not(chip);
							if (chip = '0') then
								spiState <= loadChip0;
							else
								spiState <= loadChip1;
							end if;
						end if;

						--						if(initState = 2) then
						--							spiState <= initChip1;
						--							initState <= initState - 1;
						--						end if;
						--						if(initState = 1) then
						--							spiState <= initChip0;
						--							initState <= initState - 1;
						--						end if;

					when loadChip0 =>
						activeChip(0)     <= '1';
						busy              <= '1'; -- autoreset
						valueChangedChip0 <= '0'; -- autoreset

						mosiBuffer_latched <= "00" & registerWrite.valueChip0 & "00";
						spiState           <= prepare;

					when loadChip1 =>
						activeChip(1)     <= '1';
						busy              <= '1'; -- autoreset
						valueChangedChip1 <= '0'; -- autoreset

						mosiBuffer_latched <= "00" & registerWrite.valueChip1 & "00";
						spiState           <= prepare;

					when prepare =>
						nSync          <= '1'; -- autoreset
						busy           <= '1'; -- autoreset
						spiCounter     <= mosiBuffer_latched'length - 1;
						prepareCounter <= 4; -- minimum active time for nSync
						spiState       <= prepareNSync;

					when prepareNSync =>
						nSync          <= '1'; -- autoreset
						busy           <= '1'; -- autoreset
						prepareCounter <= prepareCounter - 1;
						if (prepareCounter = 0) then
							spiState <= transfer1;
						end if;

					when transfer1 =>
						nSync      <= '0'; -- autoreset
						busy       <= '1'; -- autoreset
						sclkEnable <= '1'; -- autoreset
						if (sclkEdgeRising = '1') then
							if (spiCounter /= mosiBuffer_latched'length - 1) then
								mosiBuffer_latched(mosiBuffer_latched'length - 1 downto 0) <= mosiBuffer_latched(mosiBuffer_latched'length - 2 downto 0) & mosiDefaultLevel;
							end if;
							spiCounter <= spiCounter - 1;
							if (spiCounter = 0) then
								spiState <= transfer2;
							end if;
						end if;

					when transfer2 =>
						nSync      <= '0'; -- autoreset
						busy       <= '1'; -- autoreset
						sclkEnable <= '1'; -- autoreset
						if (sclkEdgeFalling = '1') then
							spiState <= idle;
						end if;

					when others => spiState <= idle;

				end case;
			end if;
		end if;
	end process spi2;

	notSync0 <= nSync when activeChip(0) = '1' else
		nSyncIdle;
	notSync1 <= nSync when activeChip(1) = '1' else
		nSyncIdle;

end Behavioral;

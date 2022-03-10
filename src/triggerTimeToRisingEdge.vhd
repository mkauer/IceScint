----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    20:41:43 03/08/2017 
-- Design Name: 
-- Module Name:    triggerTimeToRisingEdge - Behavioral 
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

entity triggerTimeToRisingEdge is
	generic (
		--		subAddress : std_logic_vector(15 downto 0) := x"0000";
		--		subAddressMask : std_logic_vector(15 downto 0) := x"FF00";
		--		moduleEnabled : integer := 1
		numberOfChannels : integer := 8
	);
	port (
		--		clock : in std_logic;
		--		reset : in std_logic;
		triggerPixelIn : in std_logic_vector(8 * numberOfChannels - 1 downto 0);
		trigger        : in std_logic;
		dataOut        : out std_logic_vector(16 * numberOfChannels - 1 downto 0);
		dataReady      : out std_logic;
		registerRead   : out triggerTimeToRisingEdge_registerRead_t;
		registerWrite  : in triggerTimeToRisingEdge_registerWrite_t;
		triggerTiming  : out triggerTiming_t
	);
end triggerTimeToRisingEdge;

architecture behavioral of triggerTimeToRisingEdge is
	type state_t is (idle, sample, latch, prepare);
	signal state1 : state_t := idle;
	type counter_t is array (0 to numberOfChannels - 1) of unsigned(15 downto 0);
	signal pixelCounter        : counter_t := (others => (others => '0'));
	signal pixelCounterLatched : counter_t := (others => (others => '0'));
	signal pixelCounterStop    : std_logic_vector(numberOfChannels - 1 downto 0);
	signal timeoutCounter      : integer range 0 to 2 ** 16 - 1 := 0;
	constant timeout           : integer                        := 24; -- ~8ns*24 = 200ns
	signal dataValid           : std_logic                      := '0';

begin

	g : for i in 0 to numberOfChannels - 1 generate
		dataOut(i * 16 + 15 downto i * 16) <= std_logic_vector(pixelCounterLatched(i));
	end generate;

	P0 : process (registerWrite.clock)
	begin
		if rising_edge(registerWrite.clock) then
			if (registerWrite.reset = '1') then
				pixelCounter     <= (others => (others => '0'));
				pixelCounterStop <= (others => '0');
				dataValid        <= '0';
				state1           <= idle;
			else
				case state1 is
					when idle =>
						if (trigger = '1') then
							state1                <= sample;
							dataValid             <= '0';
							triggerTiming.newData <= '0';
						end if;
						pixelCounter     <= (others => (others => '0'));
						pixelCounterStop <= (others => '0');
						timeoutCounter   <= 0;

					when sample =>
						timeoutCounter <= timeoutCounter + 1;
						if (timeoutCounter > timeout) then
							state1 <= latch;
						end if;
						for i in 0 to numberOfChannels - 1 loop
							if (pixelCounterStop(i) = '0') then
								pixelCounter(i) <= pixelCounter(i) + countZerosFromRight8(triggerPixelIn(i * 8 + 7 downto i * 8));
								if (triggerPixelIn(i * 8 + 7 downto i * 8) /= x"00") then
									pixelCounterStop(i) <= '1';
								end if;
							end if;
						end loop;

					when latch =>
						pixelCounterLatched     <= pixelCounter;
						state1                  <= prepare;
						dataReady               <= '1';
						registerRead.channel(0) <= std_logic_vector(pixelCounter(0));
						registerRead.channel(1) <= std_logic_vector(pixelCounter(1));
						registerRead.channel(2) <= std_logic_vector(pixelCounter(2));
						registerRead.channel(3) <= std_logic_vector(pixelCounter(3));
						registerRead.channel(4) <= std_logic_vector(pixelCounter(4));
						registerRead.channel(5) <= std_logic_vector(pixelCounter(5));
						registerRead.channel(6) <= std_logic_vector(pixelCounter(6));
						registerRead.channel(7) <= std_logic_vector(pixelCounter(7));

						triggerTiming.channel(0) <= std_logic_vector(pixelCounter(0));
						triggerTiming.channel(1) <= std_logic_vector(pixelCounter(1));
						triggerTiming.channel(2) <= std_logic_vector(pixelCounter(2));
						triggerTiming.channel(3) <= std_logic_vector(pixelCounter(3));
						triggerTiming.channel(4) <= std_logic_vector(pixelCounter(4));
						triggerTiming.channel(5) <= std_logic_vector(pixelCounter(5));
						triggerTiming.channel(6) <= std_logic_vector(pixelCounter(6));
						triggerTiming.channel(7) <= std_logic_vector(pixelCounter(7));
						triggerTiming.newData    <= '1';

					when prepare =>
						if (trigger = '0') then
							state1 <= idle;
						end if;

				end case;
			end if;
		end if;
	end process P0;

end behavioral;

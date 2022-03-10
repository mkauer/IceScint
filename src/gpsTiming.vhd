----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:45:59 03/21/2017 
-- Design Name: 
-- Module Name:    gpsTiming - Behavioral 
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

entity gpsTiming is
	generic (
		ticksPerBit       : integer := 12370; --12370 => 9600baud@118.75MHz
		bitTimeSamlePoint : integer := 6000
		--globalClockRate : integer := 118750
	);
	port (
		gpsPps         : in std_logic;
		gpsTimepulse2  : in std_logic;
		gpsRx          : in std_logic;
		gpsTx          : out std_logic;
		gpsIrq         : out std_logic;
		gpsNotReset    : out std_logic;
		internalTiming : in internalTiming_t;
		gpsTiming      : out gpsTiming_t;
		registerRead   : out gpsTiming_registerRead_t;
		registerWrite  : in gpsTiming_registerWrite_t
	);
end gpsTiming;

architecture behavioral of gpsTiming is
	type stateGps_t is (sync, idle, startBit, sample, stopBit);
	signal stateGps : stateGps_t := sync;
	type stateGpsPps_t is (idle, sub);
	signal stateGpsPps : stateGpsPps_t := idle;

	signal differenceGpsToLocalClock        : signed(31 downto 0) := (others => '0');
	signal differenceGpsToLocalClockPPS     : signed(31 downto 0) := (others => '0');
	signal differenceGpsToLocalClockLatched : signed(31 downto 0) := (others => '0');
	signal localClockSubSecondCounter       : signed(31 downto 0) := (others => '0');
	signal gpsRx_now                        : std_logic           := '0';
	signal rx                               : std_logic           := '0';
	signal gpsPps_now                       : std_logic           := '0';
	signal gpsPps_old                       : std_logic           := '0';
	--signal rxBuffer : std_logic_vector(8*24-1 downto 0) := (others => '0');
	signal rxBuffer : std_logic_vector(14 * 8 - 1 downto 0) := (others => '0');
	--signal PacketTimTp : std_logic_vector(rxBuffer'length-1 downto 0) := (others => '0');
	--	alias MessageTimTp is PacketTimTp(18*8-1 downto 2*8);
	--		alias syncChar1 is PacketTimTp(1*8-1 downto 0*8);
	--		alias syncChar2 is PacketTimTp(2*8-1 downto 1*8);
	--		alias class is PacketTimTp(3*8-1 downto 2*8);
	--		alias id is PacketTimTp(4*8-1 downto 3*8);
	--		alias len is PacketTimTp(6*8-1 downto 4*8);
	--	
	--		alias towMS is PacketTimTp(10*8-1 downto 6*8); 
	--		alias towSubMS is PacketTimTp(14*8-1 downto 10*8); -- will be 0
	--		alias qErr is PacketTimTp(18*8-1 downto 14*8);
	--		alias week is PacketTimTp(20*8-1 downto 18*8);
	--		alias flags is PacketTimTp(21*8-1 downto 20*8);
	--			alias timebase is PacketTimTp(20*8+0);
	--			alias utc is PacketTimTp(20*8+1);
	--		alias reserved1 is PacketTimTp(22*8-1 downto 21*8);

	signal week     : std_logic_vector(15 downto 0) := (others => '0');
	signal qErr     : std_logic_vector(31 downto 0) := (others => '0');
	signal towMS    : std_logic_vector(31 downto 0) := (others => '0');
	signal towSubMS : std_logic_vector(31 downto 0) := (others => '0');

	signal tick_ms             : std_logic := '0';
	signal newData             : std_logic := '0';
	signal newDataLatched      : std_logic := '0';
	signal newDataLatchedReset : std_logic := '0';

	signal counter_ms : unsigned(15 downto 0)          := (others => '0');
	signal counter1   : integer range 0 to 2 ** 7 - 1  := 0;
	signal counter2   : integer range 0 to 2 ** 16 - 1 := 0;

	signal bitCounter  : integer range 0 to 15 := 0;
	signal byteCounter : integer range 0 to 31 := 0;

	signal realTimeCounter        : std_logic_vector(63 downto 0) := (others => '0');
	signal realTimeCounterLatched : std_logic_vector(63 downto 0) := (others => '0');

	signal ppsCounter     : unsigned(15 downto 0) := (others => '0');
	signal gpsDataReady   : std_logic             := '0';
	signal fakePps        : std_logic             := '0';
	signal fakePpsEnabled : std_logic             := '0';

begin
	gpsTiming.newData                   <= newData;
	gpsTiming.week                      <= week;
	gpsTiming.quantizationError         <= qErr;
	gpsTiming.timeOfWeekMilliSecond     <= towMS;
	gpsTiming.timeOfWeekSubMilliSecond  <= towSubMS;
	gpsTiming.differenceGpsToLocalClock <= std_logic_vector(resize(differenceGpsToLocalClockLatched, 16)); -- ## overflow / underflow
	gpsTiming.realTimeCounterLatched    <= realTimeCounterLatched;

	tick_ms         <= internalTiming.tick_ms;
	realTimeCounter <= internalTiming.realTimeCounter;

	registerRead.week                      <= week;
	registerRead.quantizationError         <= qErr;
	registerRead.timeOfWeekMilliSecond     <= towMS;
	registerRead.timeOfWeekSubMilliSecond  <= towSubMS;
	registerRead.differenceGpsToLocalClock <= std_logic_vector(resize(differenceGpsToLocalClockLatched, 16)); -- ## overflow / underflow

	registerRead.counterPeriod <= registerWrite.counterPeriod;

	registerRead.newDataLatched <= newDataLatched;
	newDataLatchedReset         <= registerWrite.newDataLatchedReset;
	registerRead.fakePpsEnabled <= registerWrite.fakePpsEnabled;
	fakePpsEnabled              <= registerWrite.fakePpsEnabled;

	gpsTx       <= '1';
	gpsIrq      <= '0';
	gpsNotReset <= '1';

	P0 : process (registerWrite.clock)
	begin
		if rising_edge(registerWrite.clock) then
			newData      <= '0'; -- autoreset
			gpsDataReady <= '0'; -- autoreset
			if (registerWrite.reset = '1') then
				localClockSubSecondCounter       <= to_signed(0, localClockSubSecondCounter'length);
				differenceGpsToLocalClock        <= to_signed(0, differenceGpsToLocalClock'length);
				differenceGpsToLocalClockPPS     <= to_signed(0, differenceGpsToLocalClockPPS'length);
				differenceGpsToLocalClockLatched <= to_signed(0, differenceGpsToLocalClockLatched'length);
				counter_ms                       <= (others => '0');
				stateGps                         <= sync;
				stateGpsPps                      <= idle;
				realTimeCounterLatched           <= (others => '0');
				ppsCounter                       <= x"0000";
				newDataLatched                   <= '0';
				week                             <= (others => '0');
				qErr                             <= (others => '0');
				towMS                            <= (others => '0');
				towSubMS                         <= (others => '0');
				fakePps                          <= '0';
			else
				gpsPps_now <= gpsPps; -- ## not in sync....
				gpsPps_old <= gpsPps_now;

				gpsRx_now <= gpsRx;
				rx        <= gpsRx_now;

				newDataLatched <= newDataLatched and not(newDataLatchedReset);

				localClockSubSecondCounter <= localClockSubSecondCounter + 1;

				case stateGpsPps is
					when idle =>
						if (((gpsPps_old = '0') and (gpsPps_now = '1')) or (fakePps = '1')) then
							localClockSubSecondCounter   <= to_signed(0, localClockSubSecondCounter'length); -- ## 0 or 1 !?!
							differenceGpsToLocalClockPPS <= to_signed(globalClockRate_Hz, differenceGpsToLocalClockPPS'length) - localClockSubSecondCounter;
							realTimeCounterLatched       <= realTimeCounter;
							ppsCounter                   <= ppsCounter + 1;
							stateGpsPps                  <= sub;
						end if;

					when sub =>
						stateGpsPps               <= idle;
						differenceGpsToLocalClock <= differenceGpsToLocalClock + differenceGpsToLocalClockPPS;
						fakePps                   <= '0';
						if (fakePps = '1') then
							gpsDataReady <= '1'; -- autoreset
						end if;

					when others => null;
				end case;

				if ((ppsCounter >= unsigned(registerWrite.counterPeriod)) and (gpsDataReady = '1')) then
					ppsCounter                       <= x"0000";
					newData                          <= '1'; -- autoreset
					newDataLatched                   <= '1';
					differenceGpsToLocalClockLatched <= differenceGpsToLocalClock;
					differenceGpsToLocalClock        <= to_signed(0, differenceGpsToLocalClock'length);
				end if;

				if (tick_ms = '1') then
					counter_ms <= counter_ms + 1;
				end if;
				if (counter_ms >= x"03e7") then
					counter_ms <= (others => '0');
					if (fakePpsEnabled = '1') then
						fakePps <= '1';
					end if;
				end if;

				case stateGps is
					when sync =>
						if (rx = '1') then
							if (tick_ms = '1') then
								counter1 <= counter1 + 1;
							end if;
							if (counter1 = 100) then
								stateGps    <= idle;
								byteCounter <= 0;
							end if;
						else
							counter1 <= 0;
						end if;

					when idle =>
						if (rx = '0') then -- startbit
							stateGps   <= startBit;
							bitCounter <= 0;
							counter2   <= 0;
						end if;

					when startBit =>
						counter2 <= counter2 + 1;
						if (counter2 = ticksPerBit) then
							counter2   <= 0;
							bitCounter <= 0;
							stateGps   <= sample;
						end if;

					when sample =>
						counter2 <= counter2 + 1;
						if (counter2 = bitTimeSamlePoint) then
							rxBuffer   <= rx & rxBuffer(rxBuffer'length - 1 downto 1);
							bitCounter <= bitCounter + 1;
						end if;
						if (counter2 = ticksPerBit) then
							counter2 <= 0;
							if (bitCounter = 8) then
								stateGps    <= stopBit;
								byteCounter <= byteCounter + 1;
							end if;
						end if;

					when stopBit =>
						if (rx = '1') then
							stateGps <= idle;
							if (byteCounter = 1) then
								if (rxBuffer(rxBuffer'length - 1 - 0 * 8 downto rxBuffer'length - 1 * 8) /= x"b5") then
									byteCounter <= 0;
								end if;
							elsif (byteCounter = 2) then
								if (rxBuffer(rxBuffer'length - 1 - 0 * 8 downto rxBuffer'length - 1 * 8) /= x"62") then
									byteCounter <= 0;
								end if;
							end if;

							if (byteCounter = 4) then
								if (rxBuffer(rxBuffer'length - 1 - 0 * 8 downto rxBuffer'length - 4 * 8) /= x"010d62b5") then
									byteCounter <= 0;
								end if;
							end if;
							--if(byteCounter = 24) then
							if (byteCounter = 20) then -- ## yes, we cut of the crc and some flags/refInfo...
								byteCounter <= 0;

								--PacketTimTp <= rxBuffer;

								--crc <= rxBuffer(18*8-1 downto 16*8);
								--refInfo <= rxBuffer(16*8-1 downto 15*8);
								--flags <= rxBuffer(15*8-1 downto 14*8);
								week     <= rxBuffer(14 * 8 - 1 downto 12 * 8); --rxBuffer(20*8-1 downto 18*8);
								qErr     <= rxBuffer(12 * 8 - 1 downto 8 * 8);  --rxBuffer(18*8-1 downto 14*8);
								towSubMS <= rxBuffer(8 * 8 - 1 downto 4 * 8);   --rxBuffer(14*8-1 downto 10*8);
								towMS    <= rxBuffer(4 * 8 - 1 downto 0 * 8);   --rxBuffer(10*8-1 downto 6*8);

								--if((counter_halfSec(16 downto 1) >= unsigned(registerWrite.counterPeriod)) or (ppsCounter >= unsigned(registerWrite.counterPeriod))) then
								gpsDataReady <= '1'; -- autoreset
								--if(ppsCounter >= unsigned(registerWrite.counterPeriod)) then
								--	ppsCounter <= x"0000";
								--	newData <= '1'; -- autoreset
								--	newDataLatched <= '1';
								--else
								--	ppsCounter <= ppsCounter + 1;
								--end if;
							end if;
						end if;

					when others => null;
				end case;

				if (newData = '1') then
					-- ## implement checksum algorithm RFC 1145 / page 86 in ublox protocol spec
				end if;

			end if;
		end if;
	end process P0;

end behavioral;

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

entity whiteRabbitTiming is
	--	generic(
	--		clockRate_Hz : integer := 0 
	--	);
	port (
		whiteRabbitPps    : in std_logic;
		whiteRabbitClock  : in std_logic;
		internalTiming    : in internalTiming_t;
		whiteRabbitTiming : out whiteRabbitTiming_t;
		registerRead      : out whiteRabbitTiming_registerRead_t;
		registerWrite     : in whiteRabbitTiming_registerWrite_t
	);
end whiteRabbitTiming;

architecture behavioral of whiteRabbitTiming is
	signal realTimeCounter        : std_logic_vector(63 downto 0) := (others => '0');
	signal realTimeCounterLatched : std_logic_vector(63 downto 0) := (others => '0');

	signal newData             : std_logic := '0';
	signal newDataLatched      : std_logic := '0';
	signal newDataLatchedReset : std_logic := '0';

	signal ppsSync   : std_logic_vector(5 downto 0) := (others => '0');
	signal clockSync : std_logic_vector(5 downto 0) := (others => '0');

	signal pps             : std_logic                     := '0';
	signal newSymbol       : std_logic                     := '0';
	signal symbolValue     : std_logic                     := '0';
	signal id              : std_logic                     := '0';
	signal irigData        : std_logic_vector(88 downto 0) := (others => '0');
	signal irigDataLatched : std_logic_vector(88 downto 0) := (others => '0');

	type stateWR1_t is (sync, low, high);
	signal stateWR1 : stateWR1_t := sync;
	type stateWR2_t is (sync0, sync1, sync2, readData);
	signal stateWR2 : stateWR2_t := sync0;
	type stateWR3_t is (idle, calc0, calc1, calc2, calc3, calc4, calc5);
	signal stateWR3 : stateWR3_t := idle;

	signal bitCounter        : integer range 0 to 255         := 0;
	signal bitCounterLatched : integer range 0 to 255         := 0;
	signal ppsCounter        : integer range 0 to 2 ** 22 - 1 := 0;

	-- all for 118.75MHz
	-- invalid \ 2ms \ 5ms \ 8ms \ invalid
	constant IDENTIFIER_MAX : integer := 1128125; -- 8ms+1.5ms 
	constant IDENTIFIER_MIN : integer := 771875;  -- 5ms+1.5ms
	constant ONE_MIN        : integer := 415625;  -- 2ms+1.5ms
	constant ZERO_MIN       : integer := 59375;   -- 2ms-1.5ms

	signal errorCounter : unsigned(15 downto 0) := (others => '0');
	signal idCounter    : integer range 0 to 15 := 0;
	signal idStart      : integer range 0 to 15 := 0;

	--signal counter0 : unsigned(10 downto 0) := (others => '0');
	signal counter0                 : integer range 0 to 1023       := 0;
	signal yearCounter              : unsigned(6 downto 0)          := (others => '0');
	signal dayCounter               : unsigned(8 downto 0)          := (others => '0');
	signal irigBinaryYearsLatched   : std_logic_vector(6 downto 0)  := (others => '0');
	signal irigBinaryDaysLatched    : std_logic_vector(8 downto 0)  := (others => '0');
	signal irigBinarySecondsLatched : std_logic_vector(16 downto 0) := (others => '0');
	signal calcData                 : std_logic                     := '0';

	signal counterPeriod : std_logic_vector(15 downto 0) := (others => '0');
	signal counter1      : unsigned(15 downto 0)         := (others => '0');

begin

	whiteRabbitTiming.newData                  <= newData;
	whiteRabbitTiming.realTimeCounterLatched   <= realTimeCounterLatched;
	whiteRabbitTiming.irigDataLatched          <= irigDataLatched;
	whiteRabbitTiming.irigBinaryYearsLatched   <= irigBinaryYearsLatched;
	whiteRabbitTiming.irigBinaryDaysLatched    <= irigBinaryDaysLatched;
	whiteRabbitTiming.irigBinarySecondsLatched <= irigBinarySecondsLatched;
	registerRead.irigDataLatched               <= irigDataLatched;
	registerRead.errorCounter                  <= std_logic_vector(errorCounter);
	registerRead.bitCounter                    <= std_logic_vector(to_unsigned(bitCounterLatched, 8));
	registerRead.irigBinaryYearsLatched        <= irigBinaryYearsLatched;
	registerRead.irigBinaryDaysLatched         <= irigBinaryDaysLatched;
	registerRead.irigBinarySecondsLatched      <= irigBinarySecondsLatched;

	registerRead.counterPeriod <= registerWrite.counterPeriod;
	counterPeriod              <= registerWrite.counterPeriod;

	registerRead.newDataLatched <= newDataLatched;
	newDataLatchedReset         <= registerWrite.newDataLatchedReset;

	P0 : process (registerWrite.clock)
	begin
		if rising_edge(registerWrite.clock) then
			newData   <= '0'; -- autoreset
			calcData  <= '0'; -- autoreset
			newSymbol <= '0'; -- autoreset
			id        <= '0'; -- autoreset
			if (registerWrite.reset = '1') then
				realTimeCounterLatched <= (others => '0');
				realTimeCounter        <= (others => '0');
				symbolValue            <= '0';
				irigData               <= (others => '0');
				irigDataLatched        <= (others => '0');
				stateWR2               <= sync0;
				stateWR1               <= sync;
				stateWR3               <= idle;
				errorCounter           <= (others => '0');
				idCounter              <= 0;
				idStart                <= 0;
				bitCounterLatched      <= 0;
				counter1               <= (others => '0');
				newDataLatched         <= '0';
			else
				ppsSync   <= ppsSync(ppsSync'left downto 1) & whiteRabbitPps;
				clockSync <= clockSync(clockSync'left downto 1) & whiteRabbitClock;

				pps <= whiteRabbitPps;
				--pps <= ppsSync(ppsSync'left);

				newDataLatched <= newDataLatched and not(newDataLatchedReset);

				case stateWR1 is
					when sync =>
						if (pps = '0') then
							stateWR1 <= low;
							idStart  <= 0;
						end if;

					when low =>
						if (pps = '1') then
							if (idStart = 1) then
								realTimeCounter <= std_logic_vector(internalTiming.realTimeCounter); -- ## plus diff from serdes...
							end if;
							stateWR1   <= high;
							ppsCounter <= 0;
						end if;

					when high =>
						ppsCounter <= ppsCounter + 1;
						if (pps = '0') then
							stateWR1 <= low;
							idStart  <= 0;
							--ppsCounterLatched <= ppsCounter;
							if (ppsCounter > IDENTIFIER_MAX) then
								errorCounter <= errorCounter + 1;
							elsif (ppsCounter > IDENTIFIER_MIN) then
								id      <= '1'; -- autoreset
								idStart <= idStart + 1;
							elsif (ppsCounter > ONE_MIN) then
								symbolValue <= '1';
								newSymbol   <= '1'; -- autoreset
							elsif (ppsCounter > ZERO_MIN) then
								symbolValue <= '0';
								newSymbol   <= '1'; -- autoreset
							else
								errorCounter <= errorCounter + 1;
							end if;
						end if;
				end case;

				case stateWR2 is
					when sync0 =>
						if (id = '1') then
							stateWR2 <= sync1;
						end if;

					when sync1 =>
						if (id = '1') then
							stateWR2 <= sync2;
						end if;
						if (symbolValue = '1') then
							stateWR2 <= sync0;
						end if;

					when sync2 =>
						stateWR2   <= readData;
						bitCounter <= 0;
						idCounter  <= 0;

					when readData =>
						if (newSymbol = '1') then
							bitCounter <= bitCounter + 1;
							--irigData <= irigData(irigData'length-2 downto 0) & symbolValue;
							irigData <= symbolValue & irigData(irigData'length - 1 downto 1);
						end if;
						--if((bitCounter >= irigDataLatched'length) or (idCountrt >= 10)) then
						--if(bitCounter >= irigDataLatched'length) then
						if (idCounter >= 10) then
							--newData <= '1'; -- autoreset
							calcData               <= '1'; -- autoreset
							realTimeCounterLatched <= realTimeCounter;
							irigDataLatched        <= irigData;
							irigData               <= (others => '0');
							bitCounterLatched      <= bitCounter;
							--stateWR2 <= sync0;
							stateWR2 <= sync1;
						end if;
						if (id = '1') then
							idCounter <= idCounter + 1;
						end if;
						if (idStart >= 2) then
							stateWR2 <= sync2;
						end if;
				end case;

				case stateWR3 is
					when idle =>
						if (calcData = '1') then
							stateWR3    <= calc0;
							counter0    <= 0;
							yearCounter <= (others => '0');
							dayCounter  <= (others => '0');
						end if;

					when calc0 => -- year
						if (counter0 < unsigned(irigDataLatched(52 downto 49))) then
							yearCounter <= yearCounter + to_unsigned(10, yearCounter'length);
							counter0    <= counter0 + 1;
						else
							stateWR3 <= calc1;
							counter0 <= 0;
						end if;

					when calc1 => -- year
						yearCounter <= yearCounter + unsigned(irigDataLatched(47 downto 44));
						stateWR3    <= calc2;

					when calc2 => -- day
						if (counter0 < unsigned(irigDataLatched(36 downto 35))) then
							dayCounter <= dayCounter + to_unsigned(100, dayCounter'length);
							counter0   <= counter0 + 1;
						else
							stateWR3 <= calc3;
							counter0 <= 0;
						end if;

					when calc3 => -- day
						if (counter0 < unsigned(irigDataLatched(34 downto 31))) then
							dayCounter <= dayCounter + to_unsigned(10, dayCounter'length);
							counter0   <= counter0 + 1;
						else
							stateWR3 <= calc4;
							counter0 <= 0;
						end if;

					when calc4 => -- day
						dayCounter <= dayCounter + unsigned(irigDataLatched(29 downto 26));
						counter1   <= counter1 + 1;
						stateWR3   <= calc5;

					when calc5 =>
						if (counter1 >= unsigned(counterPeriod)) then
							newData        <= '1'; -- autoreset
							newDataLatched <= '1';
							counter1       <= (others => '0');
						end if;
						irigBinaryYearsLatched   <= std_logic_vector(yearCounter);
						irigBinaryDaysLatched    <= std_logic_vector(dayCounter);
						irigBinarySecondsLatched <= irigDataLatched(87 downto 71);
						stateWR3                 <= idle;

				end case;
			end if;
		end if;
	end process P0;

end behavioral;

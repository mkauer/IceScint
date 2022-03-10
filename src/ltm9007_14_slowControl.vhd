----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:18:20 03/27/2017 
-- Design Name: 
-- Module Name:    ltm9007_14 - Behavioral 
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
library UNISIM;
use UNISIM.VComponents.all;

entity ltm9007_14_slowControl is
	port (
		clock : in std_logic;
		reset : in std_logic;

		nCSA : out std_logic;
		nCSB : out std_logic;
		mosi : out std_logic;
		sclk : out std_logic;

		init               : in std_logic;
		bitslipDone        : in std_logic;
		bitslipStart_p     : out std_logic;
		bitslipStartExtern : in std_logic;

		bitslipPattern : in std_logic_vector(6 downto 0);
		testMode       : in std_logic_vector(3 downto 0);
		testPattern    : in std_logic_vector(13 downto 0)
	);
end entity;

architecture Behavioral of ltm9007_14_slowControl is
	attribute keep : string;

	type stateAdcFifoData_t is (idle, skip, valid1, valid2);
	signal stateAdcFifoData : stateAdcFifoData_t := idle;
	type stateAdcFifo_t is (sync1, sync2, sample1, sample2);
	signal stateAdcFifo : stateAdcFifo_t := sync1;

	signal fifoWriteEnableA                : std_logic := '0';
	signal fifoWriteEnableB                : std_logic := '0';
	signal fifoReadEnableA                 : std_logic := '0';
	signal fifoReadEnableB                 : std_logic := '0';
	signal fifoReset                       : std_logic := '0';
	signal fifoReset_TPTHRU_TIG            : std_logic := '0';
	attribute keep of fifoReset_TPTHRU_TIG : signal is "true";
	signal fifoReset_sync                  : std_logic := '0';
	--signal fifoResetB : std_logic := '0';

	signal fifoEmptyA : std_logic := '0';
	signal fifoEmptyB : std_logic := '0';
	signal fifoValidA : std_logic := '0';
	signal fifoValidB : std_logic := '0';

	signal eventFifoOverflowA    : std_logic := '0';
	signal eventFifoOverflowA_66 : std_logic := '0';
	--signal eventFifoOverflowB : std_logic := '0';
	signal eventFifoUnderflowA : std_logic := '0';
	--signal eventFifoUnderflowB : std_logic := '0';
	signal eventFifoFullA            : std_logic := '0';
	signal eventFifoFullA_TPTHRU_TIG : std_logic := '0';
	signal eventFifoFullB            : std_logic := '0';

	signal eventFifoFullA_old         : std_logic             := '0';
	signal eventFifoOverflowA_old     : std_logic             := '0';
	signal eventFifoUnderflowA_old    : std_logic             := '0';
	signal eventFifoOverflowCounterA  : unsigned(15 downto 0) := (others => '0');
	signal eventFifoUnderflowCounterA : unsigned(15 downto 0) := (others => '0');
	signal eventFifoFullCounterA      : unsigned(15 downto 0) := (others => '0');

	constant spiNumberOfBits  : integer                            := 8;
	constant sclkDivisor      : unsigned(3 downto 0)               := x"3"; -- ((systemClock / spiClock) / 2) ... 2=~29.7MHz@118.75MHz
	constant sclkDefaultLevel : std_logic                          := '0';
	constant mosiDefaultLevel : std_logic                          := '0';
	signal spiBusy            : std_logic                          := '0';
	signal spiTransfer        : std_logic                          := '0';
	signal spiTransfer_old    : std_logic                          := '0';
	signal spiCounter         : integer range 0 to spiNumberOfBits := 0;
	signal sclkDivisorCounter : unsigned (3 downto 0)              := x"0";
	signal sclk_i             : std_logic                          := '0';
	signal sclkEnable         : std_logic                          := '0';
	signal sclkEdgeRising     : std_logic                          := '0';
	signal sclkEdgeFalling    : std_logic                          := '0';
	signal txBuffer           : std_logic_vector(15 downto 0);
	type stateSpi_t is (idle, transfer, transferEnd);
	signal stateSpi : stateSpi_t := idle;

	type spiTransferMode_t is (sampleNormalMode, sampleTransparentMode, standby, regionOfIntrest, fullReadout, readShiftRegister_write, writeShiftRegister_write, configRegister_write, writeConfigRegister_write);
	signal spiTransferMode : spiTransferMode_t     := sampleNormalMode;
	signal bitCounter      : integer range 0 to 31 := 0;
	signal spiDone         : std_logic             := '0';

	signal message                        : std_logic_vector(16 downto 0);
	constant MSG_write_softReset          : std_logic_vector(15 downto 0) := "0" & "0000000" & x"80";
	constant MSG_write_formatAndPower     : std_logic_vector(15 downto 0) := "0" & "0000001" & x"00"; -- "20" for 2'compliment
	constant MSG_write_outputMode         : std_logic_vector(15 downto 0) := "0" & "0000010" & x"85"; -- "85" 3.0mA + X
	constant MSG_write_testPatternOffHigh : std_logic_vector(15 downto 0) := "0" & "0000011" & "00000000";
	constant MSG_write_testPatternOffLow  : std_logic_vector(15 downto 0) := "0" & "0000011" & "00000000";
	--constant MSG_write_testPatternOnHigh : std_logic_vector(15 downto 0) := "0" & "0000011" & "10000011";
	--constant MSG_write_testPatternLow : std_logic_vector(15 downto 0) := "0" & "0000100" & "11001101";
	constant MSG_write_testPattern1High       : std_logic_vector(15 downto 0) := "0" & "0000011" & "10010101";
	constant MSG_write_testPattern1Low        : std_logic_vector(15 downto 0) := "0" & "0000100" & "01010101";
	constant MSG_write_testPattern2High       : std_logic_vector(15 downto 0) := "0" & "0000011" & "10000000";
	constant MSG_write_testPattern2Low        : std_logic_vector(15 downto 0) := "0" & "0000100" & "00000001";
	constant MSG_write_testPattern3High       : std_logic_vector(15 downto 0) := "0" & "0000011" & "10111111";
	constant MSG_write_testPattern3Low        : std_logic_vector(15 downto 0) := "0" & "0000100" & "11111111";
	constant MSG_write_testPattern4High       : std_logic_vector(15 downto 0) := "0" & "0000011" & "10000000";
	constant MSG_write_testPattern4Low        : std_logic_vector(15 downto 0) := "0" & "0000100" & "00000000";
	constant MSG_write_testPatternBitslipHigh : std_logic_vector(15 downto 0) := "0" & "0000011" & "10101001";
	constant MSG_write_testPatternBitslipLow  : std_logic_vector(15 downto 0) := "0" & "0000100" & "11010011";
	constant MSG_write_testPatternXHigh       : std_logic_vector(9 downto 0)  := "0" & "0000011" & "10";
	constant MSG_write_testPatternXLow        : std_logic_vector(7 downto 0)  := "0" & "0000100";
	type stateAdc_t is (idle, init1, init2, init3, init4, init5, init6, init7, init8, init9, init10, init11, init12, init13, init14, init15, init16, init17);
	signal stateAdc : stateAdc_t := init1;

	signal bitslipStart                              : std_logic := '0';
	signal bitslipStartLatched                       : std_logic := '0';
	signal bitslipStartLatched_TPTHRU_TIG            : std_logic := '0';
	attribute keep of bitslipStartLatched_TPTHRU_TIG : signal is "true";
	signal bitslipStartLatched_sync                  : std_logic                    := '0';
	signal bitslipStartInternal                      : std_logic                    := '0';
	signal bitslipFailed                             : std_logic_vector(1 downto 0) := (others => '0');
	signal bitslipFailed_TPTHRU_TIG                  : std_logic_vector(1 downto 0) := (others => '0');
	attribute keep of bitslipFailed_TPTHRU_TIG       : signal is "true";
	signal bitslipFailed_sync                        : std_logic_vector(1 downto 0) := (others => '0');
	--signal bitslipPattern : std_logic_vector(6 downto 0);
	signal bitslipPattern_TPTHRU_TIG : std_logic_vector(6 downto 0);
	signal bitslipPatternOverride    : std_logic := '0';
	--signal bitslipDone : std_logic_vector(1 downto 0) := (others=>'0');
	signal bitslipDone_TPTHRU_TIG            : std_logic; --_vector(1 downto 0) := (others=>'0');
	attribute keep of bitslipDone_TPTHRU_TIG : signal is "true";
	--signal bitslipDone_sync : std_logic_vector(1 downto 0) := (others=>'0');
	signal bitslipDoneSyncPipeline        : std_logic_vector(4 downto 0);
	signal bitslipDoneSyncPipelineLatched : std_logic             := '0';
	signal timeoutBitslip                 : unsigned(15 downto 0) := x"ffff";

	signal adcDataValid        : std_logic             := '0';
	signal adcDataSkipCounter  : integer range 0 to 31 := 0;
	signal adcDataValidCounter : unsigned(15 downto 0) := (others => '0');
	signal adcDataStart_old    : std_logic             := '0';

	signal numberOfSamplesToRead                       : std_logic_vector(15 downto 0);
	signal numberOfSamplesToRead_TPTHRU_TIG            : std_logic_vector(15 downto 0);
	attribute keep of numberOfSamplesToRead_TPTHRU_TIG : signal is "true";
	signal numberOfSamplesToRead_sync                  : std_logic_vector(15 downto 0);
	--	signal numberOfSamplesToRead2 : std_logic_vector(15 downto 0);
	signal numberOfSamplesToReadLatched : std_logic_vector(15 downto 0);
	signal adcDataFifoCounter           : unsigned(15 downto 0) := (others => '0');

	signal offsetCorrectionRamAddress : std_logic_vector(9 downto 0);
	signal offsetCorrectionRamData    : data8x16Bit_t;

	type stateFifoRead_t is (idle, read1, read2, done);
	signal stateFifoRead : stateFifoRead_t := idle;

	signal adcDataStartSync                      : std_logic_vector(3 downto 0);
	signal adcDataStartLatched                   : std_logic := '0';
	signal roiBufferReadyLatched                 : std_logic := '0';
	signal adcDataStart                          : std_logic := '0';
	signal adcDataStart_66                       : std_logic := '0';
	signal adcDataStart_66_TPTHRU_TIG            : std_logic := '0';
	attribute keep of adcDataStart_66_TPTHRU_TIG : signal is "true";

	signal notChipSelectA : std_logic := '0';
	signal notChipSelectB : std_logic := '0';
	--signal notChipSelectAB : std_logic := '0';

begin

	nCSA <= notChipSelectA;
	nCSB <= notChipSelectB;
	--i0: OBUF port map(O => nCSA, I => notChipSelectA);
	--i1: OBUF port map(O => nCSB, I => notChipSelectB);

	bitslipStart_p <= bitslipStart;

	fifoReset_TPTHRU_TIG <= fifoReset;
	fifoReset_sync       <= fifoReset_TPTHRU_TIG;

	bitslipDone_TPTHRU_TIG <= bitslipDone;

	bitslipStartLatched_TPTHRU_TIG <= bitslipStartLatched;
	bitslipStartLatched_sync       <= bitslipStartLatched_TPTHRU_TIG;

	bitslipStart <= bitslipStartExtern or bitslipStartInternal;

	sclk <= sclk_i;

	P0 : process (clock)
	begin
		if rising_edge(clock) then
			sclkEdgeRising  <= '0'; -- autoreset
			sclkEdgeFalling <= '0'; -- autoreset
			sclkEnable      <= '0'; -- autoreset
			spiDone         <= '0'; -- autoreset
			spiBusy         <= '0'; -- autoreset
			if (reset = '1') then
				sclkDivisorCounter <= to_unsigned(0, sclkDivisorCounter'length);
				sclk_i             <= sclkDefaultLevel;
				stateSpi           <= idle;
				notChipSelectA     <= '1';
				notChipSelectB     <= '1';
			else
				if (sclkEnable = '1') then
					if (sclkDivisorCounter = sclkDivisor) then
						sclkDivisorCounter <= to_unsigned(0, sclkDivisorCounter'length);

						sclk_i <= not sclk_i;
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

				spiTransfer_old <= spiTransfer;

				case stateSpi is
					when idle =>
						notChipSelectA <= '1';
						notChipSelectB <= '1';
						if ((spiTransfer_old = '0') and (spiTransfer = '1')) then
							txBuffer <= message(15 downto 0);
							if (message(16) = '0') then
								notChipSelectA <= '0';
							else
								notChipSelectB <= '0';
							end if;
							stateSpi   <= transfer;
							bitCounter <= 15;
						end if;

					when transfer =>
						sclkEnable <= '1'; -- autoreset
						spiBusy    <= '1'; -- autoreset

						--if (sclkEdgeRising = '1') then
						if (sclkEdgeFalling = '1') then
							--if((bitCounter /= 0) and (bitCounter /= 16)) then
							txBuffer <= txBuffer(txBuffer'length - 2 downto 0) & mosiDefaultLevel;
							--end if;
							bitCounter <= bitCounter - 1;
							if (bitCounter = 0) then
								stateSpi   <= transferEnd;
								bitCounter <= 0;
							end if;
						end if;

					when transferEnd =>
						spiBusy    <= '1'; -- autoreset
						bitCounter <= bitCounter + 1;
						if (bitCounter >= 4) then -- ## may be we dont have to wait at all ...
							--if (sclkEdgeRising = '1') then
							--registerRead.regionOfInterest <= roiBuffer;
							stateSpi <= idle;
							txBuffer <= (others => '0');
							spiDone  <= '1'; -- autoreset
						end if;

					when others => null;
				end case;
			end if;
		end if;
	end process P0;

	mosi <= txBuffer(txBuffer'length - 1);

	P1 : process (clock)
	begin
		if rising_edge(clock) then
			if (reset = '1') then
				bitslipDoneSyncPipeline        <= (others => '0');
				bitslipDoneSyncPipelineLatched <= '0';
			else
				bitslipDoneSyncPipeline <= bitslipDone_TPTHRU_TIG & bitslipDoneSyncPipeline(bitslipDoneSyncPipeline'length - 1 downto 1);

				bitslipDoneSyncPipelineLatched <= bitslipDoneSyncPipeline(0) or bitslipDoneSyncPipelineLatched;
			end if;
		end if;

		if rising_edge(clock) then
			spiTransfer               <= '0'; -- autoreset
			bitslipStartInternal      <= '0'; -- autoreset	
			bitslipStartLatched       <= bitslipStart;
			bitslipPattern_TPTHRU_TIG <= bitslipPattern;
			if (reset = '1') then
				stateAdc               <= init1;
				message                <= (others => '0');
				bitslipPatternOverride <= '0';
			else

				case stateAdc is
					when idle =>
						if (init = '1') then
							stateAdc <= init1;
						end if;

					when init1 =>
						if (spiBusy = '0') then
							stateAdc <= init2;
						end if;

					when init2 =>
						message     <= "0" & MSG_write_softReset;
						spiTransfer <= '1'; -- autoreset
						if (spiDone = '1') then
							stateAdc    <= init3;
							spiTransfer <= '0'; -- autoreset
						end if;

					when init3 =>
						message     <= "1" & MSG_write_softReset;
						spiTransfer <= '1'; -- autoreset
						if (spiDone = '1') then
							stateAdc    <= init4;
							spiTransfer <= '0'; -- autoreset
						end if;

					when init4 =>
						message     <= "0" & MSG_write_formatAndPower;
						spiTransfer <= '1'; -- autoreset
						if (spiDone = '1') then
							stateAdc    <= init5;
							spiTransfer <= '0'; -- autoreset
						end if;

					when init5 =>
						message     <= "1" & MSG_write_formatAndPower;
						spiTransfer <= '1'; -- autoreset
						if (spiDone = '1') then
							stateAdc    <= init6;
							spiTransfer <= '0'; -- autoreset
						end if;

					when init6 =>
						message     <= "0" & MSG_write_outputMode;
						spiTransfer <= '1'; -- autoreset
						if (spiDone = '1') then
							stateAdc    <= init7;
							spiTransfer <= '0'; -- autoreset
						end if;

					when init7 =>
						message     <= "1" & MSG_write_outputMode;
						spiTransfer <= '1'; -- autoreset
						if (spiDone = '1') then
							stateAdc    <= init8;
							spiTransfer <= '0'; -- autoreset
						end if;

					when init8 =>
						if (testMode = x"1") then
							message <= "0" & MSG_write_testPatternXLow & testPattern(7 downto 0);
						else
							--message <= "0" & MSG_write_testPatternOffLow;
							message <= "0" & MSG_write_testPatternBitslipLow;
						end if;
						spiTransfer <= '1'; -- autoreset
						if (spiDone = '1') then
							stateAdc    <= init9;
							spiTransfer <= '0'; -- autoreset
						end if;

					when init9 =>
						if (testMode = x"1") then
							message <= "1" & MSG_write_testPatternXLow & testPattern(7 downto 0);
						else
							--message <= "1" & MSG_write_testPatternOffLow;
							message <= "1" & MSG_write_testPatternBitslipLow;
						end if;
						spiTransfer <= '1'; -- autoreset
						if (spiDone = '1') then
							stateAdc    <= init10;
							spiTransfer <= '0'; -- autoreset
						end if;

					when init10 =>
						if (testMode = x"1") then
							message <= "0" & MSG_write_testPatternXHigh & testPattern(13 downto 8);
						else
							--message <= "0" & MSG_write_testPatternOffHigh;
							message <= "0" & MSG_write_testPatternBitslipHigh;
						end if;
						spiTransfer <= '1'; -- autoreset
						if (spiDone = '1') then
							stateAdc    <= init11;
							spiTransfer <= '0'; -- autoreset
						end if;

					when init11 =>
						if (testMode = x"1") then
							message <= "1" & MSG_write_testPatternXHigh & testPattern(13 downto 8);
						else
							--message <= "1" & MSG_write_testPatternOffHigh;
							message <= "1" & MSG_write_testPatternBitslipHigh;
						end if;
						spiTransfer <= '1'; -- autoreset
						if (spiDone = '1') then
							stateAdc    <= init12;
							spiTransfer <= '0'; -- autoreset
						end if;

					when init12 =>
						if (testMode = x"1") then
							stateAdc <= idle;
						else
							stateAdc       <= init13;
							timeoutBitslip <= x"0000";
						end if;

					when init13 =>
						bitslipPatternOverride <= '1';
						timeoutBitslip         <= timeoutBitslip + 1;
						if (timeoutBitslip = x"ffff") then
							stateAdc       <= init14;
							timeoutBitslip <= x"0000";
						end if;
						if (timeoutBitslip > x"fff9") then
							bitslipStartInternal           <= '1'; -- autoreset	
							bitslipDoneSyncPipelineLatched <= '0';
						end if;

					when init14 =>
						--bitslipStartInternal <= '1'; -- autoreset
						--bitslipDoneSyncPipelineLatched <= '0';
						stateAdc <= init15;

					when init15 =>
						timeoutBitslip <= timeoutBitslip + 1;
						if (timeoutBitslip = x"ffff") then
							stateAdc       <= init13;
							timeoutBitslip <= x"0000";
						end if;
						if (bitslipDoneSyncPipelineLatched = '1') then
							bitslipPatternOverride <= '0';
							stateAdc               <= init16;
							timeoutBitslip         <= x"0000";
						end if;

					when init16 =>
						message     <= "0" & MSG_write_testPatternOffHigh;
						spiTransfer <= '1'; -- autoreset
						if (spiDone = '1') then
							stateAdc    <= init17;
							spiTransfer <= '0'; -- autoreset
						end if;

					when init17 =>
						message     <= "1" & MSG_write_testPatternOffHigh;
						spiTransfer <= '1'; -- autoreset
						if (spiDone = '1') then
							stateAdc    <= idle;
							spiTransfer <= '0'; -- autoreset
						end if;

					when others => stateAdc <= idle;
				end case;
			end if;
		end if;
	end process P1;

end Behavioral;

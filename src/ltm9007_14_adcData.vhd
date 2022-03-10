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

entity ltm9007_14_adcData is
	port (
		--enc_p : out std_logic;
		--enc_n : out std_logic;
		enc_p      : out std_logic;
		adcDataA_p : in std_logic_vector(7 downto 0);
		adcDataA_n : in std_logic_vector(7 downto 0);

		bitslipStartLatched : in std_logic;
		bitslipDone_TIG     : out std_logic;

		ChannelID    : in std_logic_vector(1 downto 0);
		fifoemptyout : out std_logic_vector(1 downto 0);
		fifoemptyinA : in std_logic_vector(1 downto 0);
		fifoemptyinB : in std_logic_vector(1 downto 0);

		drs4_to_ltm9007_14            : in drs4_to_ltm9007_14_t;
		ltm9007_14_to_eventFifoSystem : out ltm9007_14_to_eventFifoSystem_t;
		adcClocks                     : in adcClocks_t;

		registerRead  : out ltm9007_14_registerRead_t;
		registerWrite : in ltm9007_14_registerWrite_t
	);
end entity;

architecture Behavioral of ltm9007_14_adcData is
	attribute keep : string;

	signal dataOutGroupA        : std_logic_vector(7 * 4 - 1 downto 0);
	signal dataOutGroupB        : std_logic_vector(7 * 4 - 1 downto 0);
	signal adcDataGroupA_p      : std_logic_vector(3 downto 0);
	signal adcDataGroupA_n      : std_logic_vector(3 downto 0);
	signal adcDataGroupB_p      : std_logic_vector(3 downto 0);
	signal adcDataGroupB_n      : std_logic_vector(3 downto 0);
	signal dataOutGroupA_buffer : std_logic_vector(14 * 4 - 1 downto 0);
	signal dataOutGroupB_buffer : std_logic_vector(14 * 4 - 1 downto 0);
	signal fifoOutA             : std_logic_vector(14 * 4 - 1 downto 0);
	signal fifoOutB             : std_logic_vector(14 * 4 - 1 downto 0);
	signal fifoWordsA           : std_logic_vector(4 downto 0);
	signal fifoWordsB           : std_logic_vector(4 downto 0);
	signal fifoReadClock        : std_logic;
	signal enc                  : std_logic;
	type channelTwist_t is array(7 downto 0) of integer range 0 to 7;
	constant adcChannelUntwist : channelTwist_t := (0, 4, 1, 5, 2, 6, 3, 7);

	type stateAdcFifoData_t is (idle, skip, valid1, valid2);
	signal stateAdcFifoData : stateAdcFifoData_t;
	type stateAdcFifo_t is (sync1, sync2, sample1, sample2);
	signal stateAdcFifo : stateAdcFifo_t;

	signal fifoWriteEnableA                : std_logic;
	signal fifoWriteEnableB                : std_logic;
	signal fifoReadEnableA                 : std_logic;
	signal fifoReadEnableB                 : std_logic;
	signal fifoReset                       : std_logic;
	signal fifoReset_TPTHRU_TIG            : std_logic;
	attribute keep of fifoReset_TPTHRU_TIG : signal is "true";
	signal fifoReset_sync                  : std_logic;
	--signal fifoResetB : std_logic;

	signal fifoEmptyA : std_logic;
	signal fifoEmptyB : std_logic;
	signal fifoEmptyC : std_logic;
	signal fifoValidA : std_logic;
	signal fifoValidB : std_logic;

	signal eventFifoOverflowA    : std_logic;
	signal eventFifoOverflowA_66 : std_logic;
	--signal eventFifoOverflowB : std_logic;
	signal eventFifoUnderflowA : std_logic;
	--signal eventFifoUnderflowB : std_logic;
	signal eventFifoFullA            : std_logic;
	signal eventFifoFullA_TPTHRU_TIG : std_logic;
	signal eventFifoFullB            : std_logic;

	signal eventFifoFullA_old         : std_logic;
	signal eventFifoOverflowA_old     : std_logic;
	signal eventFifoUnderflowA_old    : std_logic;
	signal eventFifoOverflowCounterA  : unsigned(15 downto 0);
	signal eventFifoUnderflowCounterA : unsigned(15 downto 0);
	signal eventFifoFullCounterA      : unsigned(15 downto 0);

	constant spiNumberOfBits  : integer              := 8;
	constant sclkDivisor      : unsigned(3 downto 0) := x"3"; -- ((systemClock / spiClock) / 2) ... 2=~29.7MHz@118.75MHz
	constant sclkDefaultLevel : std_logic            := '0';
	constant mosiDefaultLevel : std_logic            := '0';
	signal spiBusy            : std_logic;
	signal spiTransfer        : std_logic;
	signal spiTransfer_old    : std_logic;
	signal spiCounter         : integer range 0 to spiNumberOfBits := 0;
	signal sclkDivisorCounter : unsigned (3 downto 0);
	signal sclk_i             : std_logic;
	signal sclkEnable         : std_logic;
	signal sclkEdgeRising     : std_logic;
	signal sclkEdgeFalling    : std_logic;
	signal txBuffer           : std_logic_vector(15 downto 0);
	type stateSpi_t is (idle, transfer, transferEnd);
	signal stateSpi : stateSpi_t;

	type spiTransferMode_t is (sampleNormalMode, sampleTransparentMode, standby, regionOfIntrest, fullReadout, readShiftRegister_write, writeShiftRegister_write, configRegister_write, writeConfigRegister_write);
	signal spiTransferMode : spiTransferMode_t := sampleNormalMode;
	signal bitCounter      : integer range 0 to 31;
	signal spiDone         : std_logic;

	signal bitslipStart1 : std_logic;
	--signal bitslipStartLatched : std_logic;
	signal bitslipStartLatched_TPTHRU_TIG            : std_logic;
	attribute keep of bitslipStartLatched_TPTHRU_TIG : signal is "true";
	signal bitslipStartLatched_sync                  : std_logic;
	signal bitslipStart2                             : std_logic;
	signal bitslipFailed                             : std_logic_vector(1 downto 0);
	signal bitslipFailed_TPTHRU_TIG                  : std_logic_vector(1 downto 0);
	attribute keep of bitslipFailed_TPTHRU_TIG       : signal is "true";
	signal bitslipFailed_TIG                         : std_logic_vector(1 downto 0);
	signal bitslipPattern                            : std_logic_vector(6 downto 0);
	signal bitslipPattern_TPTHRU_TIG                 : std_logic_vector(6 downto 0);
	signal bitslipPatternOverride                    : std_logic;
	signal bitslipDone                               : std_logic_vector(1 downto 0);
	signal bitslipDoneAll                            : std_logic;
	signal bitslipDone_TPTHRU_TIG                    : std_logic; --_vector(1 downto 0);
	attribute keep of bitslipDone_TPTHRU_TIG         : signal is "true";
	--signal bitslipDone_sync : std_logic_vector(1 downto 0);
	signal bitslipDoneSync1        : std_logic_vector(4 downto 0);
	signal bitslipDoneSync2        : std_logic_vector(4 downto 0);
	signal bitslipDoneSyncLatched1 : std_logic;
	signal bitslipDoneSyncLatched2 : std_logic;
	signal bitslipDoneSync         : std_logic;

	signal adcDataValid        : std_logic;
	signal adcDataSkipCounter  : integer range 0 to 7;
	signal adcDataValidCounter : unsigned(15 downto 0);
	signal adcDataStart_old    : std_logic;

	signal numberOfSamplesToRead                       : std_logic_vector(15 downto 0);
	signal numberOfSamplesToRead_TPTHRU_TIG            : std_logic_vector(15 downto 0);
	attribute keep of numberOfSamplesToRead_TPTHRU_TIG : signal is "true";
	signal numberOfSamplesToRead_sync                  : std_logic_vector(15 downto 0);
	--	signal numberOfSamplesToRead2 : std_logic_vector(15 downto 0);
	signal numberOfSamplesToReadLatched : std_logic_vector(15 downto 0);
	signal adcDataFifoCounter           : unsigned(15 downto 0);

	signal offsetCorrectionRamAddress : std_logic_vector(9 downto 0);
	signal offsetCorrectionRamData    : data8x16Bit_t;

	type stateFifoRead_t is (idle, read1, read2, done);
	signal stateFifoRead : stateFifoRead_t;

	signal adcDataStartSync                      : std_logic_vector(3 downto 0);
	signal adcDataStartLatched                   : std_logic;
	signal roiBufferReadyLatched                 : std_logic;
	signal adcDataStart                          : std_logic;
	signal adcDataStart_66                       : std_logic;
	signal adcDataStart_66_TPTHRU_TIG            : std_logic;
	attribute keep of adcDataStart_66_TPTHRU_TIG : signal is "true";

	signal chargeBuffer   : data8x24Bit_t;
	signal baselineBuffer : data8x24Bit_t;
	signal baselineStart  : std_logic_vector(9 downto 0);
	signal baselineEnd    : std_logic_vector(9 downto 0);

	signal notChipSelectA : std_logic;
	signal notChipSelectB : std_logic;
	--signal notChipSelectAB : std_logic;

	signal debugChannelSelector  : std_logic_vector(2 downto 0);
	signal debugFifoOut          : std_logic_vector(15 downto 0);
	signal offsetCorrectionRamWr : std_logic_vector(7 downto 0);
	signal timer                 : std_logic_vector(1 downto 0);
	signal fiforeset_idle        : std_logic;

begin

	enc_p <= enc;

	--	i0: OBUF port map(O => nCSA, I => notChipSelectA);
	--	i1: OBUF port map(O => nCSB, I => notChipSelectB);
	--
	--	s: entity work.ltm9007_14_slowControl port map(
	--		registerWrite.clock, registerWrite.reset,
	--		notChipSelectA, notChipSelectB, mosi, sclk,
	--		registerWrite.init, bitslipDone_TPTHRU_TIG, bitslipStartLatched, registerWrite.bitslipStart,
	--		bitslipPattern, registerWrite.testMode, registerWrite.testPattern);

	process (registerWrite.clock) begin
		if rising_edge(registerWrite.clock) then
			numberOfSamplesToRead_TPTHRU_TIG <= registerWrite.numberOfSamplesToRead;
			registerRead.fifoWordsA          <= "000" & fifoWordsA;
			--			registerRead.bitslipFailed <= bitslipFailed_TIG;
			if ChannelID = "00" then
				registerRead.bitslipFailed(1 downto 0) <= bitslipFailed_TIG;
			end if;
			if ChannelID = "01" then
				registerRead.bitslipFailed(3 downto 2) <= bitslipFailed_TIG;
			end if;
			if ChannelID = "10" then
				registerRead.bitslipFailed(5 downto 4) <= bitslipFailed_TIG;
			end if;
		end if;
	end process;
	numberOfSamplesToRead_sync <= numberOfSamplesToRead_TPTHRU_TIG;

	--	fifoReset_TPTHRU_TIG <= fifoReset; 
	--	fifoReset_sync <= fifoReset_TPTHRU_TIG; -- removed _ Imm

	--	fifoReset_sync       <= fifoReset when registerWrite.debugFifoControl(13 downto 12) = "00" else
	fifoReset_TPTHRU_TIG <= fifoReset when registerWrite.debugFifoControl(13 downto 12) = "00" else
		'0' when registerWrite.debugFifoControl(13 downto 12) = "01" else
		'1' when registerWrite.debugFifoControl(13 downto 12) = "10" else
		'1' when fiforeset_idle = '1' else
		'0';

	fifoReset_sync <= fifoReset_TPTHRU_TIG;

	bitslipFailed_TPTHRU_TIG <= bitslipFailed;
	bitslipFailed_TIG        <= bitslipFailed_TPTHRU_TIG;

	bitslipDone_TPTHRU_TIG <= bitslipDoneAll;
	bitslipDone_TIG        <= bitslipDone_TPTHRU_TIG;

	bitslipStartLatched_TPTHRU_TIG <= bitslipStartLatched;
	bitslipStartLatched_sync       <= bitslipStartLatched_TPTHRU_TIG;

	adcDataStart_66_TPTHRU_TIG <= drs4_to_ltm9007_14.adcDataStart_66;
	adcDataStart_66            <= drs4_to_ltm9007_14.adcDataStart_66;

	adcDataGroupA_p <= adcDataA_p(6) & adcDataA_p(4) & adcDataA_p(2) & adcDataA_p(0);
	adcDataGroupA_n <= adcDataA_n(6) & adcDataA_n(4) & adcDataA_n(2) & adcDataA_n(0);
	adcDataGroupB_p <= adcDataA_p(7) & adcDataA_p(5) & adcDataA_p(3) & adcDataA_p(1);
	adcDataGroupB_n <= adcDataA_n(7) & adcDataA_n(5) & adcDataA_n(3) & adcDataA_n(1);

	bitslipPattern <= registerWrite.bitslipPattern when (bitslipPatternOverride = '0') else
		LTM9007_14_BITSLIPPATTERN; --"1100101";

	bitslipStart1 <= (registerWrite.bitslipStart(0) or bitslipStart2) when ChannelID = "00" else
		(registerWrite.bitslipStart(1) or bitslipStart2) when ChannelID = "01" else
		(registerWrite.bitslipStart(2) or bitslipStart2);
	--registerRead.bitslipFailed <= bitslipFailed; -- ## sync
	registerRead.bitslipPattern <= registerWrite.bitslipPattern;

	registerRead.testMode    <= registerWrite.testMode;
	registerRead.testPattern <= registerWrite.testPattern;

	registerRead.offsetCorrectionRamAddress <= registerWrite.offsetCorrectionRamAddress;
	registerRead.offsetCorrectionRamWrite   <= registerWrite.offsetCorrectionRamWrite;

	--ltm9007_14_to_eventFifoSystem.regionOfInterest <= drs4_to_ltm9007_14.regionOfInterest;
	--ltm9007_14_to_eventFifoSystem.regionOfInterestReady <= drs4_to_ltm9007_14.regionOfInterestReady;
	--ltm9007_14_to_eventFifoSystem.realTimeCounter_latched <= drs4_to_ltm9007_14.realTimeCounter_latched;
	--ltm9007_14_to_eventFifoSystem.cascadingData <= drs4_to_ltm9007_14.cascadingData;
	--ltm9007_14_to_eventFifoSystem.cascadingDataReady <= drs4_to_ltm9007_14.cascadingDataReady;
	--ltm9007_14_to_eventFifoSystem.drs4_to_eventFifoSystem <= drs4_to_ltm9007_14.drs4_to_eventFifoSystem;

	ltm9007_14_to_eventFifoSystem.maxValue <= (others => (others => '0')); -- ## debug for now...

	--sclk <= sclk_i;

	x6 : entity work.serdesIn_1to7 generic map(7, 4, true, "PER_CHANL") port map('1', adcDataGroupA_p, adcDataGroupA_n, adcClocks, bitslipStartLatched_sync, bitslipDone(0), bitslipFailed(0), LTM9007_14_BITSLIPPATTERN, "00", dataOutGroupA, open);
	x7 : entity work.serdesIn_1to7 generic map(7, 4, true, "PER_CHANL") port map('1', adcDataGroupB_p, adcDataGroupB_n, adcClocks, bitslipStartLatched_sync, bitslipDone(1), bitslipFailed(1), LTM9007_14_BITSLIPPATTERN, "00", dataOutGroupB, open);

	--bitslipFailed <= "00";
	bitslipDoneAll <= '1' when bitslipDone = (bitslipDone'range => '1') else
		'0';

	--x107: OBUFDS port map(O => enc_p, OB => enc_n, I => enc);

	x108 : entity work.drs4FrontEndFifo port map(
		rst           => fifoReset_sync,            -- 66 ??
		wr_clk        => adcClocks.clk_66_serdes_div7,  -- 66 ok --serdesDivClockA,
		rd_clk        => fifoReadClock,             -- 125 ok
		din           => dataOutGroupA_buffer,      -- 66 ok
		wr_en         => fifoWriteEnableA,          -- 66 ok
		rd_en         => fifoReadEnableA,           -- 125 ok
		dout          => fifoOutA,                  -- 125 ok 
		full          => eventFifoFullA_TPTHRU_TIG, -- 125 xx
		overflow      => eventFifoOverflowA_66,     -- 125 xx
		empty         => fifoEmptyA,                -- 125 ok
		valid         => fifoValidA,                -- 125 ok
		underflow     => eventFifoUnderflowA,       -- 125 ok
		rd_data_count => fifoWordsA(3 downto 0),    -- 125 ok
		wr_data_count => open                       --registerRead.fifoWordsA2(3 downto 0) -- 125 xx
		);
	x109 : entity work.drs4FrontEndFifo port map(
		rst           => fifoReset_sync,
		wr_clk        => adcClocks.clk_66_serdes_div7, --serdesDivClockB,
		rd_clk        => fifoReadClock,
		din           => dataOutGroupB_buffer,
		wr_en         => fifoWriteEnableB,
		rd_en         => fifoReadEnableB,
		dout          => fifoOutB,
		full          => eventFifoFullB,
		overflow      => open,       --eventFifoOverflowB,
		empty         => fifoEmptyB, --open,
		valid         => fifoValidB, --open,
		underflow     => open,       --eventFifoUnderflowB,
		rd_data_count => fifoWordsB(3 downto 0),
		wr_data_count => open
		);

	fifoReadClock              <= registerWrite.clock;
	fifoWordsA(4)              <= eventFifoFullA_TPTHRU_TIG;
	fifoWordsB(4)              <= eventFifoFullB;
	registerRead.fifoValidA    <= fifoValidA;
	registerRead.fifoEmptyA    <= fifoEmptyA;
	registerRead.baselineStart <= registerWrite.baselineStart;
	registerRead.baselineEnd   <= registerWrite.baselineEnd;

	offsetCorrectionRamWr <= registerWrite.offsetCorrectionRamWrite(7 downto 0) when (ChannelID = registerWrite.offsetCorrectionRamAddress(11 downto 10)) else
		"00000000";

	g110 : for i in 0 to 7 generate
		x110 : entity work.drs4OffsetCorrectionRam port map(
			registerWrite.clock,
			registerWrite.reset,
			--registerWrite.offsetCorrectionRamWrite(i downto i),
			offsetCorrectionRamWr(i downto i),
			registerWrite.offsetCorrectionRamAddress(9 downto 0),
			registerWrite.offsetCorrectionRamData,
			registerRead.offsetCorrectionRamData(i), -- ## implement mux here....
			registerWrite.clock,
			'0',
			"0",
			offsetCorrectionRamAddress,
			x"0000",
			offsetCorrectionRamData(i)
			);
	end generate;

	registerRead.debugChannelSelector <= registerWrite.debugChannelSelector;
	debugChannelSelector              <= registerWrite.debugChannelSelector;

	P02 : process (registerWrite.clock)
	begin
		if rising_edge(registerWrite.clock) then
			adcDataStartSync <= adcDataStart_66_TPTHRU_TIG & adcDataStartSync(adcDataStartSync'length - 1 downto 1);
			--			adcDataStartSync <= adcDataStart_66 & adcDataStartSync(adcDataStartSync'length-1 downto 1);
			if (registerWrite.reset = '1') then
				adcDataStart <= '0';
			else
				if ((adcDataStartSync(1) = '1') and (adcDataStartSync(0) = '0')) then
					adcDataStart <= '1';
				else
					adcDataStart <= '0';
				end if;
			end if;
		end if;
	end process P02;

	P9 : process (adcClocks.clk_66_serdes_div7) -- ~66 MHz
	begin
		if rising_edge(adcClocks.clk_66_serdes_div7) then
			adcDataValid <= '0'; -- autoreset
			--if (registerWrite.reset = '1') then -- ## sync?!
			if (adcClocks.rst_div7 = '1') then
				stateAdcFifoData      <= idle;
				adcDataStart_old      <= '0';
				numberOfSamplesToRead <= (others => '0');
				--numberOfSamplesToRead2 <= (others=>'0'); 
			else
				adcDataStart_old      <= adcDataStart_66;
				numberOfSamplesToRead <= numberOfSamplesToRead_sync; -- ## inconsistent naming... 
				--numberOfSamplesToRead2 <= numberOfSamplesToRead1;

				case stateAdcFifoData is
					when idle =>
						adcDataSkipCounter <= 1;
						if (adcDataStart_old = '0' and adcDataStart_66 = '1') then
							stateAdcFifoData <= skip;
							fiforeset_idle   <= '1';
						end if;

					when skip =>
						adcDataSkipCounter <= adcDataSkipCounter + 1;
						if (adcDataSkipCounter = 2) then
							fiforeset_idle <= '0';
						end if;
						if (adcDataSkipCounter >= 6) then
							stateAdcFifoData    <= valid1;
							adcDataValidCounter <= unsigned(numberOfSamplesToRead);
						end if;

					when valid1 =>
						adcDataValid        <= '1'; -- autoreset
						stateAdcFifoData    <= valid2;
						adcDataValidCounter <= adcDataValidCounter - 1;

					when valid2 =>
						adcDataValid <= '1'; -- autoreset
						--fifoWriteEnableA <= adcDataValid; -- autoreset		
						--fifoWriteEnableB <= adcDataValid; -- autoreset		
						stateAdcFifoData <= valid1;
						if (adcDataValidCounter = 0) then
							stateAdcFifoData <= idle;
						end if;

					when others => null;
				end case;
			end if;
		end if;
	end process P9;

	P10 : process (adcClocks.clk_66_serdes_div7) -- ~66 MHz
	begin
		if rising_edge(adcClocks.clk_66_serdes_div7) then
			fifoWriteEnableA <= '0'; -- autoreset
			fifoWriteEnableB <= '0'; -- autoreset
			fifoReset        <= '0'; -- autoreset
			--fifoResetB <= '0'; -- autoreset
			--if (registerWrite.reset = '1') then -- ## sync?!
			if (adcClocks.rst_div7 = '1') then
				stateAdcFifo <= sync1;
			else
				case stateAdcFifo is
					when sync1 =>
						-- set testbytes in adc ?!
						-- find start of values ?!
						fifoReset <= '1'; -- autoreset
						--fifoResetB <= '1'; -- autoreset
						stateAdcFifo <= sync2;

					when sync2 =>
						-- timeout for fifo reset...
						stateAdcFifo <= sample1;

					when sample1 =>
						stateAdcFifo <= sample2;
						for i in 0 to 3 loop
							dataOutGroupA_buffer(13 + i * 14 downto 7 + i * 14) <= reverse_vector(dataOutGroupA(6 + i * 7 downto 0 + i * 7));
							dataOutGroupB_buffer(13 + i * 14 downto 7 + i * 14) <= reverse_vector(dataOutGroupB(6 + i * 7 downto 0 + i * 7));
						end loop;

					when sample2 =>
						stateAdcFifo <= sample1;
						for i in 0 to 3 loop
							dataOutGroupA_buffer(6 + i * 14 downto 0 + i * 14) <= reverse_vector(dataOutGroupA(6 + i * 7 downto 0 + i * 7));
							dataOutGroupB_buffer(6 + i * 14 downto 0 + i * 14) <= reverse_vector(dataOutGroupB(6 + i * 7 downto 0 + i * 7));
						end loop;
						fifoWriteEnableA <= adcDataValid; -- autoreset		
						fifoWriteEnableB <= adcDataValid; -- autoreset		

					when others => null;
				end case;
			end if;
		end if;
	end process P10;

	fifoemptyout(0) <= fifoEmptyA;

	P4 : process (registerWrite.clock)
		--	variable sampleBufferTwisted : data8x16Bit_t; 
		variable sampleBuffer   : data8x16Bit_t;
		variable fifoOutTwisted : data8x16Bit_t;
	begin
		if rising_edge(registerWrite.clock) then
			fifoReadEnableA                            <= '0'; -- autoreset
			fifoReadEnableB                            <= '0'; -- autoreset
			ltm9007_14_to_eventFifoSystem.newData      <= '0'; -- autoreset
			ltm9007_14_to_eventFifoSystem.samplingDone <= '0'; -- autoreset
			ltm9007_14_to_eventFifoSystem.chargeDone   <= '0'; -- autoreset
			ltm9007_14_to_eventFifoSystem.baselineDone <= '0'; -- autoreset
			fifoemptyout(1)                            <= '0';

			if registerWrite.debugFifoControl(1 downto 0) = "01" then
				fifoEmptyC <= fifoEmptyA;
			else
				fifoEmptyC <= fifoEmptyA or fifoemptyinA(0) or fifoemptyinB(0);
			end if;
			if (registerWrite.reset = '1') then
				eventFifoFullCounterA      <= to_unsigned(0, eventFifoFullCounterA'length);
				eventFifoOverflowCounterA  <= to_unsigned(0, eventFifoOverflowCounterA'length);
				eventFifoUnderflowCounterA <= to_unsigned(0, eventFifoUnderflowCounterA'length);
				eventFifoOverflowA_old     <= '0';
				eventFifoUnderflowA_old    <= '0';
				eventFifoFullA_old         <= '0';
				stateFifoRead              <= idle;
				adcDataStartLatched        <= '0';
				roiBufferReadyLatched      <= '0';
			else
				eventFifoOverflowA      <= eventFifoOverflowA_66;
				eventFifoOverflowA_old  <= eventFifoOverflowA;
				eventFifoUnderflowA_old <= eventFifoUnderflowA;
				eventFifoFullA          <= eventFifoFullA_TPTHRU_TIG;
				eventFifoFullA_old      <= eventFifoFullA;

				if ((eventFifoOverflowA_old = '0') and (eventFifoOverflowA = '1')) then
					eventFifoOverflowCounterA <= eventFifoOverflowCounterA + 1;
				end if;

				if ((eventFifoUnderflowA_old = '0') and (eventFifoUnderflowA = '1')) then
					eventFifoUnderflowCounterA <= eventFifoUnderflowCounterA + 1;
				end if;

				if ((eventFifoFullA_old = '0') and (eventFifoFullA = '1')) then
					eventFifoFullCounterA <= eventFifoFullCounterA + 1;
				end if;

				--if(fifoWordsA > "11100") then
				--	fifoReadEnableA <= '1'; -- autoreset
				--	fifoReadEnableB <= '1'; -- autoreset
				--	-- error++
				--end if;
				--
				--if(drs4_to_ltm9007_14.drs4RoiValid = '1') then
				--	fifoReadEnableA <= '1'; -- autoreset
				--	fifoReadEnableB <= '1'; -- autoreset
				--end if;

				--debugA <= fifoReadEnableA;
				--debugB <= debugA;
				--debugC <= debugB;

				--registerRead.fifoA <= fifoOutA;
				--registerRead.fifoB <= fifoOutB;
				registerRead.debugFifoOut                  <= debugFifoOut;
				ltm9007_14_to_eventFifoSystem.debugFifoOut <= debugFifoOut;

				adcDataStartLatched   <= adcDataStartLatched or adcDataStart;
				roiBufferReadyLatched <= roiBufferReadyLatched or drs4_to_ltm9007_14.regionOfInterestReady;

				case stateFifoRead is
					when idle =>
						if ((adcDataStartLatched = '1') and (roiBufferReadyLatched = '1')) then
							stateFifoRead                <= read1;
							numberOfSamplesToReadLatched <= registerWrite.numberOfSamplesToRead;
							offsetCorrectionRamAddress   <= drs4_to_ltm9007_14.regionOfInterest;
							adcDataFifoCounter           <= (others => '0');
							chargeBuffer                 <= (others => (others => '0'));
							baselineBuffer               <= (others => (others => '0'));
							baselineStart                <= registerWrite.baselineStart;
							baselineEnd                  <= registerWrite.baselineEnd;
							timer                        <= registerWrite.debugFifoControl(9 downto 8);-- wait 0 to 3 clocks for first read.
						end if;

					when read1 =>
						--if(fifoWordsA /= "00000") then
						if (((fifoEmptyA = '0') and (registerWrite.debugFifoControl(1 downto 0) = "00"))
							or ((fifoEmptyC = '0') and not(registerWrite.debugFifoControl(1 downto 0) = "00")))
							and ((timer = "11") or (registerWrite.debugFifoControl(4) = '0')) then
							fifoReadEnableA <= '1'; -- autoreset
							fifoReadEnableB <= '1'; -- autoreset
							stateFifoRead   <= read2;
							timer           <= "01";
						else
							if (timer = "00") then
								timer <= "01";
							elsif (timer = "01") then
								timer <= "10";
							elsif (timer = "10") then
								timer <= "11";
							end if;
						end if;

						if (adcDataFifoCounter >= unsigned(numberOfSamplesToReadLatched))
							or ((registerWrite.debugFifoControl(5) = '1') and ((fifoemptyinA(1) or fifoemptyinB(1)) = '1')) then --
							stateFifoRead <= done;
						end if;

						--if(adcDataFifoCounter > unsigned(baselineEnd)) then
						--	ltm9007_14_to_eventFifoSystem.baseline <= baselineBuffer;
						--	ltm9007_14_to_eventFifoSystem.baselineDone <= '1'; -- autoreset
						--end if;	

					when read2 =>
						if (timer = "00") then
							timer <= "01";
						elsif (timer = "01") then
							timer <= "10";
						elsif (timer = "10") then
							timer <= "11";
						end if;
						if (fifoValidA = '1') then -- ## fifo B is allways the same...
							l0 : for i in 0 to 3 loop
								fifoOutTwisted(i)     := "00" & fifoOutA(13 + i * 14 downto 0 + i * 14);
								fifoOutTwisted(i + 4) := "00" & fifoOutB(13 + i * 14 downto 0 + i * 14);
							end loop;

							l1 : for i in 0 to 7 loop
								sampleBuffer(i) := std_logic_vector(unsigned(fifoOutTwisted(adcChannelUntwist(i))) + resize(unsigned(offsetCorrectionRamData(i)), 16));
							end loop;

							l2 : for i in 0 to 7 loop
								ltm9007_14_to_eventFifoSystem.channel(i) <= sampleBuffer(i);
								chargeBuffer(i)                          <= std_logic_vector(unsigned(chargeBuffer(i)) + unsigned(sampleBuffer(i)));
							end loop;

							if ((adcDataFifoCounter >= unsigned(baselineStart)) and (adcDataFifoCounter <= unsigned(baselineEnd))) then
								l3 : for i in 0 to 7 loop
									baselineBuffer(i) <= std_logic_vector(unsigned(baselineBuffer(i)) + unsigned(sampleBuffer(i)));
								end loop;
							end if;

							debugFifoOut <= sampleBuffer(to_integer(unsigned((debugChannelSelector))));

							ltm9007_14_to_eventFifoSystem.newData <= '1'; -- autoreset
							offsetCorrectionRamAddress            <= std_logic_vector(unsigned(offsetCorrectionRamAddress) + 1);
							adcDataFifoCounter                    <= adcDataFifoCounter + 1;
							stateFifoRead                         <= read1;
						end if;
					when done =>
						stateFifoRead                              <= idle;
						adcDataStartLatched                        <= '0';
						roiBufferReadyLatched                      <= '0';
						ltm9007_14_to_eventFifoSystem.samplingDone <= '1'; -- autoreset
						ltm9007_14_to_eventFifoSystem.charge       <= chargeBuffer;
						ltm9007_14_to_eventFifoSystem.chargeDone   <= '1'; -- autoreset
						ltm9007_14_to_eventFifoSystem.baseline     <= baselineBuffer;
						ltm9007_14_to_eventFifoSystem.baselineDone <= '1'; -- autoreset
						fifoemptyout(1)                            <= '1'; -- autoreset
					when others => null;
				end case;

			end if;
		end if;
	end process P4;
	P5 : process (adcClocks.clk_66_serdes_div7) -- 66MHz
	begin
		if rising_edge(adcClocks.clk_66_serdes_div7) then
			if (adcClocks.rst_div7 = '1') then -- ## sync?!
				enc <= '0';
			else
				enc <= not(enc);
			end if;
		end if;
	end process P5;

end Behavioral;

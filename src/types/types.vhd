--
--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 
--
--   To use any of the example code shown below, uncomment the lines and modify as necessary
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.types_platformSpecific.all;

package types is
	attribute keep       : string;
	attribute DONT_TOUCH : string;

	type u8_array_t is array (natural range <>) of unsigned(7 downto 0);
	type slv8_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

	constant numberOfChannels : integer := numberOfChannels_platformSpecific;
	--constant numberOfChannels : integer := 8, 24 or may be 16;
	constant globalClockRate_Hz  : integer := globalClockRate_platformSpecific_hz;
	constant globalClockRate_kHz : integer := globalClockRate_platformSpecific_hz/1000;

	constant LTM9007_14_BITSLIPPATTERN : std_logic_vector(6 downto 0) := "1100101";

	type dataNumberOfChannelsX8Bit_t is array (0 to numberOfChannels - 1) of std_logic_vector(7 downto 0);
	type dataNumberOfChannelsX11Bit_t is array (0 to numberOfChannels - 1) of std_logic_vector(10 downto 0);
	type dataNumberOfChannelsX12Bit_t is array (0 to numberOfChannels - 1) of std_logic_vector(11 downto 0);
	type dataNumberOfChannelsX16Bit_t is array (0 to numberOfChannels - 1) of std_logic_vector(15 downto 0);
	type dataNumberOfChannelsX24Bit_t is array (0 to numberOfChannels - 1) of std_logic_vector(23 downto 0);
	type dataNumberOfChannelsX32Bit_t is array (0 to numberOfChannels - 1) of std_logic_vector(31 downto 0);
	type data8x8Bit_t is array (0 to 7) of std_logic_vector(7 downto 0);
	type data8x12Bit_t is array (0 to 7) of std_logic_vector(11 downto 0);
	type data8x16Bit_t is array (0 to 7) of std_logic_vector(15 downto 0);
	type data8x24Bit_t is array (0 to 7) of std_logic_vector(23 downto 0);
	type data8x32Bit_t is array (0 to 7) of std_logic_vector(31 downto 0);
	--subtype data_v_1xNumberOfChannels_t is std_logic_vector(numberOfChannels-1 downto 0);
	subtype std_logic_vector_xCannel_t is std_logic_vector(numberOfChannels - 1 downto 0);
	-------------------------------------------------------------------------------
	type std_logic_vector_array_channelsX8Bit_t is array (0 to numberOfChannels - 1) of std_logic_vector(7 downto 0);
	type std_logic_vector_array_channelsX16Bit_t is array (0 to numberOfChannels - 1) of std_logic_vector(15 downto 0);
	type std_logic_vector_array_channelsX32Bit_t is array (0 to numberOfChannels - 1) of std_logic_vector(31 downto 0);

	type smc_bus is record
		clock       : std_logic;
		reset       : std_logic;
		chipSelect  : std_logic;
		address     : std_logic_vector(23 downto 0);
		read        : std_logic;
		readStrobe  : std_logic;
		writeStrobe : std_logic;
	end record;
	function smc_vectorToBus(inputVector : std_logic_vector) return smc_bus;
	function smc_busToVector(inputBus    : smc_bus) return std_logic_vector;

	type smc_asyncBus is record
		chipSelect : std_logic;
		address    : std_logic_vector(23 downto 0);
		read       : std_logic;
		write      : std_logic;
		asyncReset : std_logic;
	end record;
	function smc_asyncVectorToBus(inputVector : std_logic_vector) return smc_asyncBus;
	function smc_busToAsyncVector(inputBus    : smc_asyncBus) return std_logic_vector;

	type adc4channel_r is record
		data  : std_logic_vector(3 downto 0);
		frame : std_logic;
		clock : std_logic;
	end record;

	function countZerosFromLeft8(patternIn  : std_logic_vector) return unsigned;
	function countZerosFromRight8(patternIn : std_logic_vector) return unsigned;
	function getFistOneFromRight8(patternIn : std_logic_vector) return integer;

	--function fillZerosFromLeft8(patternIn : std_logic_vector) return std_logic_vector;
	--function fillZerosFromRight8(patternIn : std_logic_vector) return std_logic_vector;
	--function fillOnesFromLeft8(patternIn : std_logic_vector) return std_logic_vector;
	--function fillOnesFromRight8(patternIn : std_logic_vector) return std_logic_vector;
	--	function fillXFromY8(value : string; direction : string; patternIn : std_logic_vector) return std_logic_vector;

	function reverse_vector (a : in std_logic_vector) return std_logic_vector;

	function findFallingEdgeFromRight9(patternIn : std_logic_vector) return unsigned;

	function capValue(value : unsigned; newSize : integer) return unsigned;
	function capValue(value : std_logic_vector; newSize : integer) return std_logic_vector;

	function std_logic_TIG(value        : std_logic) return std_logic;
	function std_logic_vector_TIG(value : std_logic_vector) return std_logic_vector;

	procedure std_logic_TIG_p(signal i : in std_logic; signal o : out std_logic);

	function i2v(value : integer; width : integer) return std_logic_vector;
	function i2u(value : integer; width : integer) return unsigned;

	-------------------------------------------------------------------------------

	--	type drs4Clocks_t is record
	--		drs4Clock_125MHz : std_logic;
	--		drs4RefClock : std_logic;
	--		adcSerdesDivClockPhase : std_logic;
	--		--drs4SamplingClock : std_logic;
	--		--AdcSamplingClock : std_logic;
	--	end record;

	type triggerSerdesClocks_t is record
		rst_div8 : std_logic;
		clk_118_serdes_div8      : std_logic;
		clk_800_serdes_io       : std_logic;
		serdes_strobe_800        : std_logic;
		asyncReset          : std_logic; -- ## remove
	end record;
	-------------------------------------------------------------------------------

	type triggerTiming_t is record
		channel      : dataNumberOfChannelsX16Bit_t;
		newData      : std_logic;
		newDataValid : std_logic;
	end record;

	-------------------------------------------------------------------------------

	type eventFifoSystem_registerRead_t is record
		dmaBuffer                 : std_logic_vector(15 downto 0);
		eventFifoWordsDma         : std_logic_vector(15 downto 0);
		eventFifoWordsDmaAligned  : std_logic_vector(15 downto 0);
		eventFifoWordsDma32       : std_logic_vector(31 downto 0);
		eventFifoWordsDmaSlice    : std_logic_vector(3 downto 0);
		eventFifoWordsPerSlice    : std_logic_vector(15 downto 0);
		eventFifoFullCounter      : std_logic_vector(15 downto 0);
		eventFifoOverflowCounter  : std_logic_vector(15 downto 0);
		eventFifoUnderflowCounter : std_logic_vector(15 downto 0);
		eventFifoErrorCounter     : std_logic_vector(15 downto 0);
		eventFifoWords            : std_logic_vector(15 downto 0);
		eventFifoFlags            : std_logic_vector(15 downto 0);
		numberOfSamplesToRead     : std_logic_vector(15 downto 0);
		packetConfig              : std_logic_vector(15 downto 0);
		eventsPerIrq              : std_logic_vector(15 downto 0);
		enableIrq                 : std_logic;
		irqStall                  : std_logic;
		irqAtEventFifoWords       : std_logic_vector(15 downto 0);
		eventRateCounter          : std_logic_vector(15 downto 0);
		eventLostRateCounter      : std_logic_vector(15 downto 0);
		deviceId                  : std_logic_vector(15 downto 0);
		drs4ChipSelector          : std_logic_vector(15 downto 0);
		debugFifoOut              : std_logic_vector(15 downto 0);
	end record;
	type eventFifoSystem_registerWrite_t is record
		clock                 : std_logic;
		reset                 : std_logic;
		nextWord              : std_logic;
		eventFifoClear        : std_logic;
		clearEventCounter     : std_logic;
		numberOfSamplesToRead : std_logic_vector(15 downto 0);
		packetConfig          : std_logic_vector(15 downto 0);
		eventsPerIrq          : std_logic_vector(15 downto 0);
		enableIrq             : std_logic;
		irqStall              : std_logic;
		irqAtEventFifoWords   : std_logic_vector(15 downto 0);
		forceIrq              : std_logic;
		forceMiscData         : std_logic;
		deviceId              : std_logic_vector(15 downto 0);
		miscSlotA             : data8x16Bit_t;
		miscSlotB             : data8x16Bit_t;
		drs4ChipSelector      : std_logic_vector(15 downto 0);
	end record;

	-------------------------------------------------------------------------------

	type triggerTimeToRisingEdge_registerRead_t is record
		--channel : data8x16Bit_t;
		channel : dataNumberOfChannelsX16Bit_t;
		timeout : std_logic_vector(15 downto 0);
	end record;
	type triggerTimeToRisingEdge_registerWrite_t is record
		clock   : std_logic;
		reset   : std_logic;
		timeout : std_logic_vector(15 downto 0);
	end record;

	type triggerDataDelay_registerRead_t is record
		numberOfDelayCycles : std_logic_vector(15 downto 0);
	end record;
	type triggerDataDelay_registerWrite_t is record
		clock               : std_logic;
		reset               : std_logic;
		numberOfDelayCycles : std_logic_vector(15 downto 0);
		resetDelay          : std_logic;
	end record;

	---------------------------------------------------------------------------
	type triggerTimeToEdge_registerRead_t is record
		timeToRisingEdge  : std_logic_vector_array_channelsX16Bit_t;
		timeToFallingEdge : std_logic_vector_array_channelsX16Bit_t;
		maxSearchTime     : std_logic_vector(11 downto 0);
	end record;

	type triggerTimeToEdge_registerWrite_t is record
		clock         : std_logic;
		reset         : std_logic;
		maxSearchTime : std_logic_vector(11 downto 0);
	end record;

	type triggerTimeToEdge_t is record
		timeToRisingEdge       : std_logic_vector_array_channelsX16Bit_t;
		timeToFallingEdge      : std_logic_vector_array_channelsX16Bit_t;
		newData                : std_logic;
		realTimeCounterLatched : std_logic_vector(63 downto 0);
	end record;

	-------------------------------------------------------------------------------

	type dac_array_t is array (0 to 7) of std_logic_vector(7 downto 0);
	type dac088s085_x3_registerRead_t is record
		dacBusy            : std_logic;
		valuesChip0        : dac_array_t;
		valuesChip1        : dac_array_t;
		valuesChip2        : dac_array_t;
		valuesChangedChip0 : std_logic_vector(7 downto 0);
		valuesChangedChip1 : std_logic_vector(7 downto 0);
		valuesChangedChip2 : std_logic_vector(7 downto 0);
	end record;
	type dac088s085_x3_registerWrite_t is record
		clock              : std_logic;
		reset              : std_logic;
		init               : std_logic;
		valuesChip0        : dac_array_t;
		valuesChip1        : dac_array_t;
		valuesChip2        : dac_array_t;
		valuesChangedChip0 : std_logic_vector(7 downto 0);
		valuesChangedChip1 : std_logic_vector(7 downto 0);
		valuesChangedChip2 : std_logic_vector(7 downto 0);
	end record;

	-------------------------------------------------------------------------------

	type ad56x1_registerRead_t is record
		dacBusy    : std_logic;
		valueChip0 : std_logic_vector(11 downto 0);
		valueChip1 : std_logic_vector(11 downto 0);
	end record;
	type ad56x1_registerWrite_t is record
		clock             : std_logic;
		reset             : std_logic;
		valueChip0        : std_logic_vector(11 downto 0);
		valueChip1        : std_logic_vector(11 downto 0);
		valueChangedChip0 : std_logic;
		valueChangedChip1 : std_logic;
	end record;

	-------------------------------------------------------------------------------

	type internalTiming_t is record
		tick_ms         : std_logic;
		tick_sec        : std_logic;
		tick_min        : std_logic;
		realTimeCounter : std_logic_vector(63 downto 0);
	end record;

	type internalTiming_registerRead_t is record
		unused : std_logic;
	end record;

	type internalTiming_registerWrite_t is record
		clock : std_logic;
		reset : std_logic;
	end record;

	-------------------------------------------------------------------------------

	type gpsTiming_registerRead_t is record
		week                      : std_logic_vector(15 downto 0);
		quantizationError         : std_logic_vector(31 downto 0);
		timeOfWeekMilliSecond     : std_logic_vector(31 downto 0);
		timeOfWeekSubMilliSecond  : std_logic_vector(31 downto 0);
		differenceGpsToLocalClock : std_logic_vector(15 downto 0);
		counterPeriod             : std_logic_vector(15 downto 0);
		newDataLatched            : std_logic;
		fakePpsEnabled            : std_logic;
	end record;

	type gpsTiming_registerWrite_t is record
		clock               : std_logic;
		reset               : std_logic;
		counterPeriod       : std_logic_vector(15 downto 0);
		newDataLatchedReset : std_logic;
		fakePpsEnabled      : std_logic;
	end record;

	type gpsTiming_t is record
		week                      : std_logic_vector(15 downto 0);
		quantizationError         : std_logic_vector(31 downto 0);
		timeOfWeekMilliSecond     : std_logic_vector(31 downto 0);
		timeOfWeekSubMilliSecond  : std_logic_vector(31 downto 0);
		differenceGpsToLocalClock : std_logic_vector(15 downto 0);
		newData                   : std_logic;
		--realTimeCounter: std_logic_vector(63 downto 0);
		realTimeCounterLatched : std_logic_vector(63 downto 0);
	end record;

	-------------------------------------------------------------------------------

	type whiteRabbitTiming_registerRead_t is record
		counterPeriod            : std_logic_vector(15 downto 0);
		irigDataLatched          : std_logic_vector(88 downto 0);
		errorCounter             : std_logic_vector(15 downto 0);
		bitCounter               : std_logic_vector(7 downto 0);
		irigBinaryYearsLatched   : std_logic_vector(6 downto 0);
		irigBinaryDaysLatched    : std_logic_vector(8 downto 0);
		irigBinarySecondsLatched : std_logic_vector(16 downto 0);
		newDataLatched           : std_logic;
	end record;

	type whiteRabbitTiming_registerWrite_t is record
		clock               : std_logic;
		reset               : std_logic;
		counterPeriod       : std_logic_vector(15 downto 0);
		newDataLatchedReset : std_logic;
	end record;

	type whiteRabbitTiming_t is record
		newData                  : std_logic;
		realTimeCounterLatched   : std_logic_vector(63 downto 0);
		irigDataLatched          : std_logic_vector(88 downto 0);
		irigBinaryYearsLatched   : std_logic_vector(6 downto 0);
		irigBinaryDaysLatched    : std_logic_vector(8 downto 0);
		irigBinarySecondsLatched : std_logic_vector(16 downto 0);
	end record;

	-------------------------------------------------------------------------------

	type pixelRateCounter_registerRead_t is record
		newData                                 : std_logic;
		pixelCounterAllEdgesLatched             : dataNumberOfChannelsX16Bit_t;
		pixelCounterPreventedDoublePulseLatched : dataNumberOfChannelsX16Bit_t;
		pixelCounterLatched                     : dataNumberOfChannelsX16Bit_t;
		pixelCounterInsideDeadTimeLatched       : dataNumberOfChannelsX16Bit_t;
		pixelCounterDebugLatched                : dataNumberOfChannelsX16Bit_t;
		counterPeriod                           : std_logic_vector(15 downto 0);
		doublePulsePrevention                   : std_logic;
		doublePulseTime                         : std_logic_vector(7 downto 0);
	end record;

	type pixelRateCounter_registerWrite_t is record
		clock         : std_logic;
		reset         : std_logic;
		newDataReset  : std_logic;
		counterPeriod : std_logic_vector(15 downto 0);
		--resetCounter : std_logic_vector(15 downto 0);
		resetCounter          : std_logic_vector_xCannel_t;
		doublePulsePrevention : std_logic;
		doublePulseTime       : std_logic_vector(7 downto 0);
	end record;

	type pixelRateCounter_t is record
		newData                     : std_logic;
		counterPeriod               : std_logic_vector(15 downto 0);
		channelLatched              : dataNumberOfChannelsX16Bit_t;
		channelDeadTimeLatched      : dataNumberOfChannelsX16Bit_t;
		realTimeCounterLatched      : std_logic_vector(63 downto 0);
		realTimeDeltaCounterLatched : std_logic_vector(63 downto 0); -- more or less like counterPeriod 
	end record;

	-------------------------------------------------------------------------------

	type pixelRateCounter_v2_registerRead_t is record
		newData                             : std_logic;
		rateAllEdgesLatched                 : dataNumberOfChannelsX16Bit_t;
		rateFirstHitsDuringGateLatched      : dataNumberOfChannelsX16Bit_t;
		rateAdditionalHitsDuringGateLatched : dataNumberOfChannelsX16Bit_t;
		rateCounterPeriod                   : std_logic_vector(15 downto 0);
		--	gateTimeout : std_logic_vector(15 downto 0);
		--	doublePulsePrevention : std_logic;
		--	doublePulseTime : std_logic_vector(7 downto 0);
	end record;

	type pixelRateCounter_v2_registerWrite_t is record
		clock             : std_logic;
		reset             : std_logic;
		newDataReset      : std_logic;
		rateCounterPeriod : std_logic_vector(15 downto 0);
		--	gateTimeout : std_logic_vector(15 downto 0);
		resetCounter : std_logic_vector_xCannel_t;
		--	doublePulsePrevention : std_logic;
		--	doublePulseTime : std_logic_vector(7 downto 0);
	end record;

	type pixelRateCounter_v2_t is record
		newData                             : std_logic;
		rateCounterPeriod                   : std_logic_vector(15 downto 0);
		rateAllEdgesLatched                 : dataNumberOfChannelsX16Bit_t;
		rateFirstHitsDuringGateLatched      : dataNumberOfChannelsX16Bit_t;
		rateAdditionalHitsDuringGateLatched : dataNumberOfChannelsX16Bit_t;
		realTimeCounterLatched              : std_logic_vector(63 downto 0);
		realTimeDeltaCounterLatched         : std_logic_vector(63 downto 0); -- more or less like counterPeriod 
	end record;

	----------------------------------

	type pixelRateCounter_polarstern_registerRead_t is record
		pixelCounterAllEdgesLatched : std_logic_vector_array_channelsX16Bit_t;
		--pixelCounterPreventedDoublePulseLatched : dataNumberOfChannelsX16Bit_t;
		--pixelCounterLatched : dataNumberOfChannelsX16Bit_t;
		--pixelCounterInsideDeadTimeLatched : dataNumberOfChannelsX16Bit_t;
		--pixelCounterDebugLatched : dataNumberOfChannelsX16Bit_t;
		counterPeriod : std_logic_vector(15 downto 0);
		--doublePulsePrevention : std_logic;
		--doublePulseTime : std_logic_vector(7 downto 0);
		newDataLatched : std_logic;
	end record;

	type pixelRateCounter_polarstern_registerWrite_t is record
		clock            : std_logic;
		reset            : std_logic;
		resetCounterTime : std_logic;
		resetAllCounter  : std_logic;
		counterPeriod    : std_logic_vector(15 downto 0);
		resetCounter     : std_logic_vector_xCannel_t;
		--doublePulsePrevention : std_logic;
		--doublePulseTime : std_logic_vector(7 downto 0);
		newDataLatchedReset : std_logic;
	end record;
	type pixelRateCounter_polarstern_t is record
		newData                     : std_logic;
		counterPeriod               : std_logic_vector(15 downto 0);
		channelLatched              : std_logic_vector_array_channelsX16Bit_t;
		channelDeadTimeLatched      : dataNumberOfChannelsX16Bit_t;
		realTimeCounterLatched      : std_logic_vector(63 downto 0);
		realTimeDeltaCounterLatched : std_logic_vector(63 downto 0); -- more or less like counterPeriod 
	end record;

	-------------------------------------------------------------------------------

	type drs4_to_ltm9007_14_old_t is record
		adcDataStart_66         : std_logic;
		roiBuffer               : std_logic_vector(9 downto 0);
		roiBufferReady          : std_logic;
		realTimeCounter_latched : std_logic_vector(63 downto 0);
	end record;

	type drs4_to_eventFifoSystem_t is record
		cascadingData           : std_logic_vector(7 downto 0);
		cascadingDataShort      : std_logic_vector(3 downto 0);
		cascadingDataReady      : std_logic;
		realTimeCounter_latched : std_logic_vector(63 downto 0);
		regionOfInterest        : std_logic_vector(9 downto 0);
		regionOfInterestReady   : std_logic;
	end record;

	type drs4_to_eventFifoSystem_vector_t is array (0 to 2) of drs4_to_eventFifoSystem_t;

	type drs4_to_ltm9007_14_t is record
		adcDataStart_66       : std_logic;
		regionOfInterest      : std_logic_vector(9 downto 0);
		regionOfInterestReady : std_logic;
		--drs4_to_eventFifoSystem : drs4_to_eventFifoSystem_t;
	end record;

	type drs4_to_ltm9007_14_vector_t is array (0 to 2) of drs4_to_ltm9007_14_t;

	type drs4_registerRead_t is record
		regionOfInterest      : std_logic_vector(9 downto 0); -- ## debug
		numberOfSamplesToRead : std_logic_vector(15 downto 0);
		sampleMode            : std_logic_vector(3 downto 0);
		readoutMode           : std_logic_vector(3 downto 0);
		writeShiftRegister    : std_logic_vector(7 downto 0);
		cascadingDataDebug    : std_logic_vector(7 downto 0);
	end record;

	type drs4_registerWrite_t is record
		clock                   : std_logic;
		reset                   : std_logic;
		resetStates             : std_logic;
		numberOfSamplesToRead   : std_logic_vector(15 downto 0);
		sampleMode              : std_logic_vector(3 downto 0);
		readoutMode             : std_logic_vector(3 downto 0);
		offsetCorrectionRamData : std_logic_vector(15 downto 0);
		writeShiftRegister      : std_logic_vector(7 downto 0);
	end record;

	type drs4_pins_A_t is record
		notReset     : std_logic;
		address      : std_logic_vector(3 downto 0);
		denable      : std_logic;
		dwrite       : std_logic;
		dwriteSerdes : std_logic_vector(7 downto 0);
		rsrload      : std_logic;
		mosi         : std_logic;
		sclk         : std_logic;
		wsrin        : std_logic;
	end record;
	type drs4_pins_B_t is record
		miso   : std_logic;
		dtap   : std_logic;
		plllck : std_logic;
		wsrout : std_logic;
	end record;

	-------------------------------------------------------------------------------

	type ltm9007_14_to_eventFifoSystem_old_t is record
		realTimeCounter_latched : std_logic_vector(63 downto 0);
		channel                 : data8x16Bit_t;
		newData                 : std_logic;
		samplingDone            : std_logic;
		roiBuffer               : std_logic_vector(9 downto 0);
		roiBufferReady          : std_logic;
		charge                  : data8x24Bit_t;
		maxValue                : data8x16Bit_t;
		chargeDone              : std_logic;
		baseline                : data8x24Bit_t;
		baselineDone            : std_logic;
	end record;

	type ltm9007_14_to_eventFifoSystem_t is record
		channel      : data8x16Bit_t;
		newData      : std_logic;
		samplingDone : std_logic;
		charge       : data8x24Bit_t;
		maxValue     : data8x16Bit_t;
		chargeDone   : std_logic;
		baseline     : data8x24Bit_t;
		baselineDone : std_logic;
		debugFifoOut : std_logic_vector(15 downto 0);
		--cascadingData : std_logic_vector(7 downto 0);
		--cascadingDataReady : std_logic;
		--realTimeCounter_latched : std_logic_vector(63 downto 0);
		--roiBuffer : std_logic_vector(9 downto 0);
		--roiBufferReady : std_logic;

		--drs4_to_eventFifoSystem : drs4_to_eventFifoSystem_t;
	end record;

	type adcClocks_t is record
		clk_462_serdes_io            : std_logic;
		serdes_strobe_462             : std_logic;
		clk_66_serdes_div7           : std_logic;
		clk_66_serdes_div7_second      : std_logic;
		rst_div7      : std_logic;
		rst_div7_second : std_logic;
	end record;
	type adcFifo_t is record
		fifoOutA   : std_logic_vector(55 downto 0);
		fifoWordsA : std_logic_vector(4 downto 0);
		fifoOutB   : std_logic_vector(55 downto 0);
		fifoWordsB : std_logic_vector(4 downto 0);
		channel    : data8x16Bit_t;
	end record;

	-------------------------------------------------------------------------------

	type drs4AndAdcData_t is record
		adcData  : ltm9007_14_to_eventFifoSystem_t;
		drs4Data : drs4_to_eventFifoSystem_t;
	end record;
	type drs4AndAdcData_vector_t is array (0 to 2) of drs4AndAdcData_t;

	-------------------------------------------------------------------------------

	type ltm9007_14_registerRead_t is record
		--fifoA : std_logic_vector(4*14-1 downto 0);
		--fifoB : std_logic_vector(4*14-1 downto 0);
		testMode                   : std_logic_vector(3 downto 0);
		testPattern                : std_logic_vector(13 downto 0);
		bitslipPattern             : std_logic_vector(6 downto 0);
		bitslipFailed              : std_logic_vector(5 downto 0);
		offsetCorrectionRamAddress : std_logic_vector(11 downto 0);
		offsetCorrectionRamData    : data8x16Bit_t;
		offsetCorrectionRamWrite   : std_logic_vector(7 downto 0);
		fifoEmptyA                 : std_logic;
		fifoValidA                 : std_logic;
		fifoWordsA                 : std_logic_vector(7 downto 0);
		--fifoWordsA2 : std_logic_vector(7 downto 0);
		baselineStart        : std_logic_vector(9 downto 0);
		baselineEnd          : std_logic_vector(9 downto 0);
		debugChannelSelector : std_logic_vector(2 downto 0);
		debugFifoControl     : std_logic_vector(15 downto 0);
		debugFifoOut         : std_logic_vector(15 downto 0);
	end record;
	type ltm9007_14_registerWrite_t is record
		clock                      : std_logic;
		reset                      : std_logic;
		init                       : std_logic;
		testMode                   : std_logic_vector(3 downto 0);
		testPattern                : std_logic_vector(13 downto 0);
		bitslipPattern             : std_logic_vector(6 downto 0);
		numberOfSamplesToRead      : std_logic_vector(15 downto 0);
		bitslipStart               : std_logic_vector(2 downto 0);
		offsetCorrectionRamAddress : std_logic_vector(11 downto 0);
		offsetCorrectionRamData    : std_logic_vector(15 downto 0);
		offsetCorrectionRamWrite   : std_logic_vector(7 downto 0);
		baselineStart              : std_logic_vector(9 downto 0);
		baselineEnd                : std_logic_vector(9 downto 0);
		debugChannelSelector       : std_logic_vector(2 downto 0);
		debugFifoControl           : std_logic_vector(15 downto 0);
	end record;

	-------------------------------------------------------------------------------

	type triggerLogic_registerRead_t is record
		triggerSerdesDelay      : std_logic_vector(9 downto 0);
		triggerMask             : std_logic_vector(7 downto 0);
		singleSeq               : std_logic;
		triggerGeneratorEnabled : std_logic;
		triggerGeneratorPeriod  : unsigned(31 downto 0);

		drs4TriggerDelay : std_logic_vector(8 downto 0);

		drs4Decimator : std_logic_vector(15 downto 0);

		rate                : std_logic_vector(15 downto 0); -- dataNumberOfChannelsX16Bit_t;
		rateLatched         : std_logic_vector(15 downto 0); -- dataNumberOfChannelsX16Bit_t;
		rateDeadTimeLatched : std_logic_vector(15 downto 0); -- dataNumberOfChannelsX16Bit_t;
		counterPeriod       : std_logic_vector(15 downto 0);
		sameEventTime       : std_logic_vector(11 downto 0);

		gateTime : std_logic_vector(15 downto 0);
	end record;

	type triggerLogic_registerWrite_t is record
		clock                   : std_logic;
		reset                   : std_logic;
		triggerSerdesDelayInit  : std_logic;
		triggerSerdesDelay      : std_logic_vector(9 downto 0);
		triggerMask             : std_logic_vector(7 downto 0);
		triggerSum              : std_logic_vector(7 downto 0);
		triggerSec              : std_logic_vector(7 downto 0);
		singleSoftTrigger       : std_logic;
		singleSeq               : std_logic;
		triggerGeneratorEnabled : std_logic;
		triggerGeneratorPeriod  : unsigned(31 downto 0);

		drs4TriggerDelay      : std_logic_vector(8 downto 0);
		drs4TriggerDelayReset : std_logic;

		drs4Decimator : std_logic_vector(15 downto 0);

		counterPeriod : std_logic_vector(15 downto 0);
		resetCounter  : std_logic; --_vector(15 downto 0);
		sameEventTime : std_logic_vector(11 downto 0);
		softTrigger   : std_logic;

		gateTime : std_logic_vector(15 downto 0);
	end record;

	type triggerLogic_t is record
		triggerSerdesDelayed    : std_logic_vector(7 downto 0);
		triggerSerdesNotDelayed : std_logic_vector(7 downto 0);
		triggerDelayed          : std_logic;
		triggerNotDelayed       : std_logic;

		softTrigger : std_logic;
		--singleSoftTrigger : std_logic;
		sumTriggerSameEvent : std_logic;

		flasherTrigger     : std_logic;
		flasherTriggerGate : std_logic;

		timingAndDrs4 : std_logic;
		timingOnly    : std_logic;

		newData             : std_logic;
		counterPeriod       : std_logic_vector(15 downto 0);
		rateLatched         : std_logic_vector(15 downto 0);
		rateDeadTimeLatched : std_logic_vector(15 downto 0);
		--realTimeCounterLatched : std_logic_vector(63 downto 0);
		--realTimeDeltaCounterLatched : std_logic_vector(63 downto 0); -- more or less like counterPeriod 
	end record;

	-------------------------------------------------------------------------------

	type iceTad_registerRead_t is record
		powerOn : std_logic_vector(7 downto 0);
		--rs485Data : data8x8Bit_t;
		rs485RxBusy    : std_logic_vector(7 downto 0);
		rs485TxBusy    : std_logic_vector(7 downto 0);
		rs485FifoData  : dataNumberOfChannelsX8Bit_t;
		rs485FifoWords : dataNumberOfChannelsX11Bit_t;
		--rs485FifoFull : dataNumberOfChannels_t;
		rs485FifoFull  : std_logic_vector(7 downto 0);
		rs485FifoEmpty : std_logic_vector(7 downto 0);
		softTxEnable   : std_logic_vector(7 downto 0);
		softTxMask     : std_logic_vector(7 downto 0);
	end record;
	type iceTad_registerWrite_t is record
		clock   : std_logic;
		reset   : std_logic;
		powerOn : std_logic_vector(7 downto 0);
		--rs485Data : dataNumberOfChannelsX8Bit_t;
		rs485Data      : data8x8Bit_t;
		rs485TxStart   : std_logic_vector(7 downto 0);
		rs485FifoRead  : std_logic_vector(7 downto 0);
		rs485FifoClear : std_logic_vector(7 downto 0);
		softTxEnable   : std_logic_vector(7 downto 0);
		softTxMask     : std_logic_vector(7 downto 0);
	end record;

	-------------------------------------------------------------------------------

	type panelPower_registerRead_t is record
		dummy : std_logic;
	end record;
	type panelPower_registerWrite_t is record
		clock  : std_logic;
		reset  : std_logic;
		init   : std_logic;
		enable : std_logic;
	end record;

	-------------------------------------------------------------------------------

	type tmp05_registerRead_t is record
		tl           : std_logic_vector(15 downto 0);
		th           : std_logic_vector(15 downto 0);
		debugCounter : std_logic_vector(23 downto 0);
		busy         : std_logic;
	end record;
	type tmp05_registerWrite_t is record
		clock           : std_logic;
		reset           : std_logic;
		conversionStart : std_logic;
	end record;

	-------------------------------------------------------------------------------

	type clockConfig_debug_t is record
		drs4RefClockPeriod : std_logic_vector(7 downto 0);
	end record;

	-------------------------------------------------------------------------------

	type uv_loggerClocks_t is record
		communicationClock      : std_logic;
		communicationClockReset : std_logic;
	end record;

	-------------------------------------------------------------------------------

	type clocks_t is record
		triggerSerdesClocks : triggerSerdesClocks_t;
		adcClocks           : adcClocks_t;
		drs4RefClock        : std_logic;
		asyncReset          : std_logic;
	end record;

	-------------------------------------------------------------------------------

	type dac1_uvLogger_registerRead_t is record
		channelA       : dataNumberOfChannelsX12Bit_t;
		valuesChangedA : std_logic_vector(7 downto 0);
		channelB       : dataNumberOfChannelsX12Bit_t;
		valuesChangedB : std_logic_vector(7 downto 0);
		debug          : std_logic_vector(3 downto 0);
	end record;
	type dac1_uvLogger_registerWrite_t is record
		clock          : std_logic;
		reset          : std_logic;
		channelA       : dataNumberOfChannelsX12Bit_t;
		valuesChangedA : std_logic_vector(7 downto 0);
		channelB       : dataNumberOfChannelsX12Bit_t;
		valuesChangedB : std_logic_vector(7 downto 0);
		debug2         : std_logic;
	end record;
	type dac1_uvLogger_stats_t is record
		channelA : dataNumberOfChannelsX12Bit_t;
		channelB : dataNumberOfChannelsX12Bit_t;
	end record;

	-------------------------------------------------------------------------------

	type tmp10x_uvLogger_registerRead_t is record
		temperature : std_logic_vector(15 downto 0);
		busy        : std_logic;
	end record;
	type tmp10x_uvLogger_registerWrite_t is record
		clock           : std_logic;
		reset           : std_logic;
		startConversion : std_logic;
	end record;

	-------------------------------------------------------------------------------

	type i2c_genericBus_registerRead_t is record
		data : std_logic_vector(7 downto 0);
		busy : std_logic;
	end record;
	type i2c_genericBus_registerWrite_t is record
		clock               : std_logic;
		reset               : std_logic;
		startTransfer       : std_logic;
		direction           : std_logic;
		sendStartBeforeData : std_logic;
		sendStopAfterData   : std_logic;
		waitForAckAfterData : std_logic;
		sendAckAfterData    : std_logic;
		data                : std_logic_vector(7 downto 0);
	end record;

	-------------------------------------------------------------------------------

	type ledFlasher_registerRead_t is record
		enableGenerator     : std_logic_vector(1 downto 0);
		useNegativePolarity : std_logic_vector(1 downto 0);
		pulseWidth0         : std_logic_vector(7 downto 0);
		pulseWidth1         : std_logic_vector(7 downto 0);
		generatorPeriod0    : std_logic_vector(31 downto 0);
		generatorPeriod1    : std_logic_vector(31 downto 0);
	end record;
	type ledFlasher_registerWrite_t is record
		clock               : std_logic;
		reset               : std_logic;
		doSingleShot        : std_logic_vector(1 downto 0);
		enableGenerator     : std_logic_vector(1 downto 0);
		useNegativePolarity : std_logic_vector(1 downto 0);
		pulseWidth0         : std_logic_vector(7 downto 0);
		pulseWidth1         : std_logic_vector(7 downto 0);
		generatorPeriod0    : std_logic_vector(31 downto 0);
		generatorPeriod1    : std_logic_vector(31 downto 0);
	end record;

	-------------------------------------------------------------------------------

	type houseKeeping_registerRead_t is record
		enablePcbLeds     : std_logic;
		enablePcbLedGreen : std_logic;
		enablePcbLedRed   : std_logic;
		enableJ24TestPins : std_logic;
	end record;
	type houseKeeping_registerWrite_t is record
		clock             : std_logic;
		reset             : std_logic;
		enablePcbLeds     : std_logic;
		enablePcbLedGreen : std_logic;
		enablePcbLedRed   : std_logic;
		enableJ24TestPins : std_logic;
	end record;

	-------------------------------------------------------------------------------

	type commDebug_registerRead_t is record
		tx_baud_div : std_logic_vector(15 downto 0);
		dU_1mV      : std_logic_vector(15 downto 0);
		com_adc_thr : std_logic_vector(15 downto 0);
	end record;
	type commDebug_registerWrite_t is record
		clock                     : std_logic;
		reset                     : std_logic;
		tx_baud_div               : std_logic_vector(15 downto 0);
		dU_1mV                    : std_logic_vector(15 downto 0);
		com_adc_thr               : std_logic_vector(15 downto 0);
		dac_valueIdle             : std_logic_vector(11 downto 0);
		dac_valueLow              : std_logic_vector(11 downto 0);
		dac_valueHigh             : std_logic_vector(11 downto 0);
		dac_incDacValue           : std_logic_vector(11 downto 0);
		dac_time1                 : std_logic_vector(15 downto 0);
		dac_time2                 : std_logic_vector(15 downto 0);
		dac_time3                 : std_logic_vector(15 downto 0);
		dac_clkTime               : std_logic_vector(15 downto 0);
		com_thr_adj               : std_logic_vector(2 downto 0);
		adc_deadTime              : std_logic_vector(11 downto 0);
		adc_syncTimeout           : std_logic_vector(15 downto 0);
		adc_baselineAveragingTime : std_logic_vector(15 downto 0);
		jumper                    : std_logic_vector(15 downto 0);
		adc_threshold_p           : std_logic_vector(15 downto 0);
		adc_threshold_n           : std_logic_vector(15 downto 0);
		fifo_avrFactor            : std_logic_vector(3 downto 0);
		decoder2frameWidth        : std_logic_vector(15 downto 0);

		uartDebugLoop0Enable : std_logic;
		uartDebugLoop1Enable : std_logic;

		adc_decoder_t1   : std_logic_vector(15 downto 0);
		adc_decoder_t2   : std_logic_vector(15 downto 0);
		adc_decoder_t3   : std_logic_vector(15 downto 0);
		adc_decoder_t4   : std_logic_vector(15 downto 0);
		adc_decoder_bits : std_logic_vector(15 downto 0);
		adc_debug        : std_logic_vector(15 downto 0);
	end record;

	-------------------------------------------------------------------------------
	-- polarstern
	-------------------------------------------------------------------------------

	type p_triggerSerdes_t is array (0 to 2) of std_logic_vector(8 * 8 - 1 downto 0);

	type p_triggerPathCounter_t is array (0 to 2) of std_logic_vector(15 downto 0);

	type p_triggerLogic_registerRead_t is record
		mode : std_logic_vector(3 downto 0);
		--rateCounter : p_triggerPathCounter_t;
		rateCounterLatched       : p_triggerPathCounter_t;
		rateCounterSectorLatched : std_logic_vector_array_channelsX16Bit_t;
	end record;

	type p_triggerLogic_registerWrite_t is record
		clock            : std_logic;
		reset            : std_logic;
		mode             : std_logic_vector(3 downto 0);
		counterPeriod    : std_logic_vector(15 downto 0);
		resetCounter     : std_logic_vector(15 downto 0);
		resetCounterTime : std_logic;
		resetAllCounter  : std_logic;
	end record;

	type p_triggerRateCounter_t is record
		newData                  : std_logic;
		rateCounterLatched       : p_triggerPathCounter_t;
		rateCounterSectorLatched : std_logic_vector_array_channelsX16Bit_t;
	end record;

	-------------------------------------------------------------------------------
	type i2c_registerRead_t is record
		readdata : std_logic_vector(15 downto 0);
		idle     : std_logic;
	end record;

	type i2c_registerWrite_t is record
		start  : std_logic;
		comand : std_logic_vector(47 downto 0);
	end record;
	-----------------------------------------------------------------------------

	-------------------------------------------------------------------------------

	-------------------------------------------------------------------------------

end types;

package body types is

	--constant numberOfChannels : integer := numberOfChannels_platformSpecific;

	function smc_vectorToBus(inputVector : std_logic_vector) return smc_bus is
		variable temp                        : smc_bus;
	begin
		temp.address := inputVector(23 downto 0);
		--	temp.write := inputVector(24);
		temp.writeStrobe := inputVector(25);
		temp.read        := inputVector(26);
		temp.readStrobe  := inputVector(27);
		temp.chipSelect  := inputVector(28);
		temp.reset       := inputVector(29);
		temp.clock       := inputVector(30);
		return temp;
	end;

	function smc_busToVector(inputBus : smc_bus) return std_logic_vector is
		variable temp                     : std_logic_vector(31 downto 0);
	begin
		temp(23 downto 0) := inputBus.address;
		--	temp(24) := inputBus.write;
		temp(25) := inputBus.writeStrobe;
		temp(26) := inputBus.read;
		temp(27) := inputBus.readStrobe;
		temp(28) := inputBus.chipSelect;
		temp(29) := inputBus.reset;
		temp(30) := inputBus.clock;
		return temp;
	end;

	function smc_replaceCs(inputBus : smc_bus; cs_new : std_logic) return smc_bus is
		variable temp : smc_bus;
	begin
		temp.clock      := inputBus.clock;
		temp.reset      := inputBus.reset;
		temp.chipSelect := cs_new;
		temp.address    := inputBus.address;
		temp.read       := inputBus.read;
		temp.readStrobe := inputBus.readStrobe;
		--	temp.write := inputBus.write;
		temp.writeStrobe := inputBus.writeStrobe;
		return temp;
	end;

	function smc_asyncVectorToBus(inputVector : std_logic_vector) return smc_asyncBus is
		variable temp                             : smc_asyncBus;
	begin
		temp.address    := inputVector(23 downto 0);
		temp.write      := inputVector(24);
		temp.read       := inputVector(25);
		temp.chipSelect := inputVector(26);
		temp.asyncReset := inputVector(27);
		return temp;
	end;

	function smc_busToAsyncVector(inputBus : smc_asyncBus) return std_logic_vector is
		variable temp                          : std_logic_vector(27 downto 0);
	begin
		temp(23 downto 0) := inputBus.address;
		temp(24)          := inputBus.write;
		temp(25)          := inputBus.read;
		temp(26)          := inputBus.chipSelect;
		temp(27)          := inputBus.asyncReset;
		return temp;
	end;

	function countZerosFromLeft8(patternIn : std_logic_vector) return unsigned is
		variable temp                          : unsigned(3 downto 0) := "0000";
	begin
		if (std_match(patternIn, "1-------")) then
			temp := "0000";
		elsif (std_match(patternIn, "01------")) then
			temp := "0001";
		elsif (std_match(patternIn, "001-----")) then
			temp := "0010";
		elsif (std_match(patternIn, "0001----")) then
			temp := "0011";
		elsif (std_match(patternIn, "00001---")) then
			temp := "0100";
		elsif (std_match(patternIn, "000001--")) then
			temp := "0101";
		elsif (std_match(patternIn, "0000001-")) then
			temp := "0110";
		elsif (std_match(patternIn, "00000001")) then
			temp := "0111";
		elsif (std_match(patternIn, "00000000")) then
			temp := "1000";
		else
			temp := "0000";
		end if;
		return temp;
	end;

	function countZerosFromRight8(patternIn : std_logic_vector) return unsigned is
		variable temp                           : unsigned(3 downto 0) := "0000";
	begin
		if (std_match(patternIn, "-------1")) then
			temp := "0000";
		elsif (std_match(patternIn, "------10")) then
			temp := "0001";
		elsif (std_match(patternIn, "-----100")) then
			temp := "0010";
		elsif (std_match(patternIn, "----1000")) then
			temp := "0011";
		elsif (std_match(patternIn, "---10000")) then
			temp := "0100";
		elsif (std_match(patternIn, "--100000")) then
			temp := "0101";
		elsif (std_match(patternIn, "-1000000")) then
			temp := "0110";
		elsif (std_match(patternIn, "10000000")) then
			temp := "0111";
		elsif (std_match(patternIn, "00000000")) then
			temp := "1000";
		else
			temp := "0000";
		end if;
		return temp;
	end;

	-- user has to make shure that inpus has at least one '1' / is not x"00"
	function getFistOneFromRight8(patternIn : std_logic_vector) return integer is
		variable temp                           : integer range 0 to 7 := 0;
	begin
		if (std_match(patternIn, "-------1")) then
			temp := 0;
		elsif (std_match(patternIn, "------10")) then
			temp := 1;
		elsif (std_match(patternIn, "-----100")) then
			temp := 2;
		elsif (std_match(patternIn, "----1000")) then
			temp := 3;
		elsif (std_match(patternIn, "---10000")) then
			temp := 4;
		elsif (std_match(patternIn, "--100000")) then
			temp := 5;
		elsif (std_match(patternIn, "-1000000")) then
			temp := 6;
		elsif (std_match(patternIn, "10000000")) then
			temp := 7;
		else
			temp := 0; -- illegal
		end if;
		return temp;
	end;

	--	function fillXFromY8(value : string; direction : string; patternIn : std_logic_vector) return std_logic_vector is
	--		variable temp : std_logic_vector(patternIn'range);
	--		variable v : std_logic;
	--		variable nv : std_logic;
	--	begin
	--		if(value = "ONES") then
	--			v := '1';	
	--			nv := '0';	
	--			if(direction = "FROM_RIGHT") then
	--				if(std_match(patternIn, "-------1")) then
	--					temp := (others=>v);
	--				elsif(std_match(patternIn, "------10")) then
	--					temp := (0=>nv,others=>v);
	--				elsif(std_match(patternIn, "-----100")) then
	--					temp := (0|1=>nv,others=>v);
	--				elsif(std_match(patternIn, "----1000")) then
	--					temp := (0|1|2=>nv,others=>v);
	--				elsif(std_match(patternIn, "---10000")) then
	--					temp := (0|1|2|3=>nv,others=>v);
	--				elsif(std_match(patternIn, "--100000")) then
	--					temp := (0|1|2|3|4=>nv,others=>v);
	--				elsif(std_match(patternIn, "-1000000")) then
	--					temp := (0|1|2|3|4|5=>nv,others=>v);
	--				elsif(std_match(patternIn, "10000000")) then
	--					temp := (0|1|2|3|4|5|6=>nv,others=>v);
	--				elsif(std_match(patternIn, "00000000")) then
	--					temp := (others=>nv);
	--				else
	--					temp := (others=>nv); -- illegal
	--				end if;
	--			elsif(direction = "FROM_LEFT") then
	--				if(std_match(patternIn, "1-------")) then
	--					temp := (others=>v);
	--				elsif(std_match(patternIn, "01------")) then
	--					temp := (7=>nv,others=>v);
	--				elsif(std_match(patternIn, "001-----")) then
	--					temp := (6|7=>nv,others=>v);
	--				elsif(std_match(patternIn, "0001----")) then
	--					temp := (5|6|7=>nv,others=>v);
	--				elsif(std_match(patternIn, "00001---")) then
	--					temp := (4|5|6|7=>nv,others=>v);
	--				elsif(std_match(patternIn, "000001--")) then
	--					temp := (3|4|5|6|7=>nv,others=>v);
	--				elsif(std_match(patternIn, "0000001-")) then
	--					temp := (2|3|4|5|6|7=>nv,others=>v);
	--				elsif(std_match(patternIn, "00000001")) then
	--					temp := (1|2|3|4|5|6|7=>nv,others=>v);
	--				elsif(std_match(patternIn, "00000000")) then
	--					temp := (others=>nv);
	--				else
	--					temp := (others=>nv); -- illegal
	--				end if;
	--			else
	--				temp := (others=>'0'); -- illegal
	--			end if;
	--		elsif(value = "ZEROS") then
	--			if(direction = "FROM_RIGHT") then
	--				if(std_match(patternIn, "-------0")) then
	--					temp := "00000000";
	--				elsif(std_match(patternIn, "------01")) then
	--					temp := "00000001";
	--				elsif(std_match(patternIn, "-----011")) then
	--					temp := "00000011";
	--				elsif(std_match(patternIn, "----0111")) then
	--					temp := "00000111";
	--				elsif(std_match(patternIn, "---01111")) then
	--					temp := "00001111";
	--				elsif(std_match(patternIn, "--011111")) then
	--					temp := "00011111";
	--				elsif(std_match(patternIn, "-0111111")) then
	--					temp := "00111111";
	--				elsif(std_match(patternIn, "01111111")) then
	--					temp := "01111111";
	--				elsif(std_match(patternIn, "11111111")) then
	--					temp := "11111111";
	--				else
	--					temp := "11111111"; -- illegal
	--				end if;
	--			elsif(direction = "FROM_LEFT") then
	--				if(std_match(patternIn, "0-------")) then
	--					temp := "00000000";
	--				elsif(std_match(patternIn, "10------")) then
	--					temp := "10000000";
	--				elsif(std_match(patternIn, "110-----")) then
	--					temp := "11000000";
	--				elsif(std_match(patternIn, "1110----")) then
	--					temp := "11100000";
	--				elsif(std_match(patternIn, "11110---")) then
	--					temp := "11110000";
	--				elsif(std_match(patternIn, "111110--")) then
	--					temp := "11111000";
	--				elsif(std_match(patternIn, "1111110-")) then
	--					temp := "11111100";
	--				elsif(std_match(patternIn, "11111110")) then
	--					temp := "11111110";
	--				elsif(std_match(patternIn, "11111111")) then
	--					temp := "11111111";
	--				else
	--					temp := "11111111";
	--				end if;
	--			else
	--				temp := (others=>'1'); -- illegal
	--			end if;
	--		else
	--			temp := (others=>'0'); -- illegal
	--		end if;
	--
	--		return temp;
	--	end;

	function reverse_vector (a : in std_logic_vector) return std_logic_vector is
		variable result            : std_logic_vector(a'range);
		alias aa                   : std_logic_vector(a'REVERSE_RANGE) is a;
	begin
		for i in aa'range loop
			result(i) := aa(i);
		end loop;
		return result;
	end;

	function findFallingEdgeFromRight9(patternIn : std_logic_vector) return unsigned is
		variable temp                                : unsigned(3 downto 0) := "0000";
	begin
		if (std_match(patternIn, "-------01")) then
			temp := "0000";
		elsif (std_match(patternIn, "------01-")) then
			temp := "0001";
		elsif (std_match(patternIn, "-----01--")) then
			temp := "0010";
		elsif (std_match(patternIn, "----01---")) then
			temp := "0011";
		elsif (std_match(patternIn, "---01----")) then
			temp := "0100";
		elsif (std_match(patternIn, "--01-----")) then
			temp := "0101";
		elsif (std_match(patternIn, "-01------")) then
			temp := "0110";
		elsif (std_match(patternIn, "01-------")) then
			temp := "0111";
			--elsif(std_match(patternIn, "00000000")) then
			--	temp := "1000";
			--elsif(std_match(patternIn, "11111111")) then
			--	temp := "1000";
		else
			temp := "1000";
		end if;
		return temp;
	end;

	function capValue(value : unsigned; newSize : integer) return unsigned is
		variable zero : unsigned(value'length - 1 downto newSize) := (others => '0');
		variable temp : unsigned(newSize - 1 downto 0)            := (others => '0');
	begin
		if (value(value'length - 1 downto newSize) /= zero) then
			temp := (others => '1');
		else
			temp := value(newSize - 1 downto 0);
		end if;

		return temp;
	end;

	function capValue(value : std_logic_vector; newSize : integer) return std_logic_vector is
	begin
		return std_logic_vector(capValue(unsigned(value), newSize));
	end;

	function std_logic_TIG(value            : std_logic) return std_logic is
		variable temp_TPTHRU_TIG                : std_logic;
		attribute keep of temp_TPTHRU_TIG       : variable is "true";
		attribute DONT_TOUCH of temp_TPTHRU_TIG : variable is "true";
	begin
		temp_TPTHRU_TIG := value;
		return temp_TPTHRU_TIG;
	end;

	function std_logic_vector_TIG(value : std_logic_vector) return std_logic_vector is
		--variable temp_TPTHRU_TIG : std_logic_vector(value'length-1 downto 0);
		variable temp : std_logic_vector(value'range);
		--attribute keep of temp_TPTHRU_TIG: variable is "true";
	begin
		--temp_TPTHRU_TIG := value;
		for i in value'range loop
			temp(i) := std_logic_TIG(value(i));
		end loop;
		return temp;
	end;

	procedure std_logic_TIG_p(signal i : in std_logic; signal o : out std_logic) is
		variable temp_TPTHRU_TIG                : std_logic;
		attribute keep of temp_TPTHRU_TIG       : variable is "true";
		attribute DONT_TOUCH of temp_TPTHRU_TIG : variable is "true";
	begin
		temp_TPTHRU_TIG := i;
		o <= temp_TPTHRU_TIG;
	end;

	function i2v(value : integer; width : integer) return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(value, width));
	end;

	function i2u(value : integer; width : integer) return unsigned is
	begin
		return to_unsigned(value, width);
	end;

	---- Example 1
	--  function <function_name>  (signal <signal_name> : in <type_declaration>  ) return <type_declaration> is
	--    variable <variable_name>     : <type_declaration>;
	--  begin
	--    <variable_name> := <signal_name> xor <signal_name>;
	--    return <variable_name>; 
	--  end <function_name>;

	---- Example 2
	--  function <function_name>  (signal <signal_name> : in <type_declaration>;
	--                         signal <signal_name>   : in <type_declaration>  ) return <type_declaration> is
	--  begin
	--    if (<signal_name> = '1') then
	--      return <signal_name>;
	--    else
	--      return 'Z';
	--    end if;
	--  end <function_name>;

	---- Procedure Example
	--  procedure <procedure_name>  (<type_declaration> <constant_name>  : in <type_declaration>) is
	--    
	--  begin
	--    
	--  end <procedure_name>;

end types;

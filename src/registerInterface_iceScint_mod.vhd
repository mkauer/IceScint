----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:05:09 03/01/2017 
-- Design Name: 
-- Module Name:    registerInterface_iceScint - Behavioral 
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
use ieee.std_logic_unsigned.all;

use work.types.all;

entity registerInterface_iceScint is
	generic (
		subAddress     : std_logic_vector(15 downto 0) := x"0000";
		subAddressMask : std_logic_vector(15 downto 0) := x"0000";
		moduleEnabled  : integer                       := 1
	);
	port (
		addressAndControlBus : in std_logic_vector(31 downto 0);
		dataBusIn            : in std_logic_vector(15 downto 0);
		dataBusOut           : out std_logic_vector(15 downto 0);

		triggerTimeToRisingEdge_0r : in triggerTimeToRisingEdge_registerRead_t;
		triggerTimeToRisingEdge_0w : out triggerTimeToRisingEdge_registerWrite_t;
		eventFifoSystem_0r         : in eventFifoSystem_registerRead_t;
		eventFifoSystem_0w         : out eventFifoSystem_registerWrite_t;
		triggerDataDelay_0r        : in triggerDataDelay_registerRead_t;
		triggerDataDelay_0w        : out triggerDataDelay_registerWrite_t;
		triggerDataDelay_1r        : in triggerDataDelay_registerRead_t;
		triggerDataDelay_1w        : out triggerDataDelay_registerWrite_t;
		pixelRateCounter_0r_p0     : in pixelRateCounter_registerRead_t;
		pixelRateCounter_0w        : out pixelRateCounter_registerWrite_t;
		dac088s085_x3_0r           : in dac088s085_x3_registerRead_t;
		dac088s085_x3_0w           : out dac088s085_x3_registerWrite_t;
		gpsTiming_0r               : in gpsTiming_registerRead_t;
		gpsTiming_0w               : out gpsTiming_registerWrite_t;
		whiteRabbitTiming_0r       : in whiteRabbitTiming_registerRead_t;
		whiteRabbitTiming_0w       : out whiteRabbitTiming_registerWrite_t;
		internalTiming_0r          : in internalTiming_registerRead_t;
		internalTiming_0w          : out internalTiming_registerWrite_t;
		ad56x1_0r                  : in ad56x1_registerRead_t;
		ad56x1_0w                  : out ad56x1_registerWrite_t;
		drs4_0r                    : in drs4_registerRead_t;
		drs4_0w                    : out drs4_registerWrite_t;
		ltm9007_14_0r              : in ltm9007_14_registerRead_t;
		ltm9007_14_0w              : out ltm9007_14_registerWrite_t;
		triggerLogic_0r_p          : in triggerLogic_registerRead_t;
		triggerLogic_0w            : out triggerLogic_registerWrite_t;
		iceTad_0r                  : in iceTad_registerRead_t;
		iceTad_0w                  : out iceTad_registerWrite_t;
		panelPower_0r              : in panelPower_registerRead_t;
		panelPower_0w              : out panelPower_registerWrite_t;
		tmp05_0r                   : in tmp05_registerRead_t;
		tmp05_0w                   : out tmp05_registerWrite_t;
		i2c_control_r              : in i2c_registerRead_t;
		i2c_control_w              : out i2c_registerWrite_t;
		clockConfig_debug_0w       : out clockConfig_debug_t
	);
end registerInterface_iceScint;

architecture behavior of registerInterface_iceScint is

	signal chipSelectInternal : std_logic                     := '0';
	signal readDataBuffer     : std_logic_vector(15 downto 0) := (others => '0');

	signal registerA            : std_logic_vector(7 downto 0)  := (others => '0');
	signal registerb, registerc : std_logic_vector(15 downto 0) := (others => '0');

	signal controlBus : smc_bus;

	signal debugReset     : std_logic := '0';
	signal eventFifoClear : std_logic := '0';

	signal numberOfSamplesToRead          : std_logic_vector(15 downto 0) := (others => '0');

	signal eventFifoWordsDmaSlice_latched                : std_logic_vector(3 downto 0)  := (others => '0');
	signal whiteRabbitTiming_0r_irigDataLatched          : std_logic_vector(88 downto 0) := (others => '0');
	signal whiteRabbitTiming_0r_irigBinaryYearsLatched   : std_logic_vector(6 downto 0)  := (others => '0');
	signal whiteRabbitTiming_0r_irigBinaryDaysLatched    : std_logic_vector(8 downto 0)  := (others => '0');
	signal whiteRabbitTiming_0r_irigBinarySecondsLatched : std_logic_vector(16 downto 0) := (others => '0');
	signal tmp05_0r_thLatched : std_logic_vector(15 downto 0) := (others => '0');

	signal pixelRateCounter_0r    : pixelRateCounter_registerRead_t;
	signal pixelRateCounter_0r_p1 : pixelRateCounter_registerRead_t;
	signal pixelRateCounter_0r_p2 : pixelRateCounter_registerRead_t;
	signal triggerLogic_0r        : triggerLogic_registerRead_t;

	signal modus, dummycnt, writemsbs : std_logic_vector(7 downto 0)  := (others => '0');
	signal databusbuf                 : std_logic_vector(15 downto 0) := (others => '0');

	signal swapreaddata, inccnt : std_logic;

begin
	process (controlBus.clock)
	begin
		if rising_edge(controlBus.clock) then
			pixelRateCounter_0r    <= pixelRateCounter_0r_p2;
			pixelRateCounter_0r_p2 <= pixelRateCounter_0r_p1;
			pixelRateCounter_0r_p1 <= pixelRateCounter_0r_p0;
			triggerLogic_0r        <= triggerLogic_0r_p;
			if inccnt = '1' then
				dummycnt <= dummycnt + "00000001";
			end if;
		end if;
	end process;

	dataBusbuf <= databusin when (modus(1) = '0') else
		(writemsbs & databusin(7 downto 0));

	g0 : if moduleEnabled /= 0 generate
		controlBus         <= smc_vectorToBus(addressAndControlBus);
		chipSelectInternal <= '1' when ((controlBus.chipSelect = '1') and (((controlBus.address(15 downto 1) & "0") and subAddressMask) = subAddress)) else
			'0';
		dataBusOut <= readDataBuffer when swapreaddata = '0' else
			(readDataBuffer(7 downto 0) & readDataBuffer(15 downto 8));

		triggerTimeToRisingEdge_0w.clock  <= controlBus.clock;
		triggerTimeToRisingEdge_0w.reset  <= controlBus.reset;
		eventFifoSystem_0w.clock          <= controlBus.clock;
		eventFifoSystem_0w.reset          <= controlBus.reset or debugReset;
		eventFifoSystem_0w.eventFifoClear <= eventFifoClear;
		triggerDataDelay_0w.clock         <= controlBus.clock;
		triggerDataDelay_0w.reset         <= controlBus.reset;
		triggerDataDelay_1w.clock         <= controlBus.clock;
		triggerDataDelay_1w.reset         <= controlBus.reset;
		pixelRateCounter_0w.clock         <= controlBus.clock;
		pixelRateCounter_0w.reset         <= controlBus.reset;
		dac088s085_x3_0w.clock            <= controlBus.clock;
		dac088s085_x3_0w.reset            <= controlBus.reset;
		gpsTiming_0w.clock                <= controlBus.clock;
		gpsTiming_0w.reset                <= controlBus.reset;
		whiteRabbitTiming_0w.clock        <= controlBus.clock;
		whiteRabbitTiming_0w.reset        <= controlBus.reset;
		internalTiming_0w.clock           <= controlBus.clock;
		internalTiming_0w.reset           <= controlBus.reset;
		ad56x1_0w.clock                   <= controlBus.clock;
		ad56x1_0w.reset                   <= controlBus.reset;
		drs4_0w.clock                     <= controlBus.clock;
		drs4_0w.reset                     <= controlBus.reset;
		ltm9007_14_0w.clock               <= controlBus.clock;
		ltm9007_14_0w.reset               <= controlBus.reset;
		triggerLogic_0w.clock             <= controlBus.clock;
		triggerLogic_0w.reset             <= controlBus.reset;
		iceTad_0w.clock                   <= controlBus.clock;
		iceTad_0w.reset                   <= controlBus.reset;
		panelPower_0w.clock               <= controlBus.clock;
		panelPower_0w.reset               <= controlBus.reset;
		tmp05_0w.clock                    <= controlBus.clock;
		tmp05_0w.reset                    <= controlBus.reset;

		drs4_0w.numberOfSamplesToRead            <= numberOfSamplesToRead;
		ltm9007_14_0w.numberOfSamplesToRead      <= numberOfSamplesToRead;
		eventFifoSystem_0w.numberOfSamplesToRead <= numberOfSamplesToRead;

		P0 : process (controlBus.clock)
		begin
			if rising_edge(controlBus.clock) then
				eventFifoSystem_0w.nextWord          <= '0';             -- autoreset  --read befehl
				inccnt                               <= '0';             -- autoreset  --read befehl
				eventFifoSystem_0w.forceIrq          <= '0';             -- autoreset
				eventFifoSystem_0w.clearEventCounter <= '0';             -- autoreset
				triggerDataDelay_0w.resetDelay       <= '0';             -- autoreset
				triggerDataDelay_1w.resetDelay       <= '0';             -- autoreset
				pixelRateCounter_0w.resetCounter     <= (others => '0'); -- autoreset
				debugReset                           <= '0';             -- autoreset
				eventFifoClear                       <= '0';             -- autoreset
				dac088s085_x3_0w.init                <= '0';             -- autoreset
				ad56x1_0w.valueChangedChip0 <= '0'; -- autoreset
				ad56x1_0w.valueChangedChip1 <= '0'; -- autoreset
				drs4_0w.resetStates                      <= '0';             -- autoreset
				ltm9007_14_0w.init                       <= '0';             --autoreset
				ltm9007_14_0w.bitslipStart               <= "000";           --autoreset
				triggerLogic_0w.triggerSerdesDelayInit   <= '0';             --autoreset
				triggerLogic_0w.softTrigger              <= '0';             --autoreset
				triggerLogic_0w.resetCounter             <= '0';             -- autoreset
				panelPower_0w.init                       <= '0';             -- autoreset
				ltm9007_14_0w.offsetCorrectionRamWrite   <= (others => '0'); -- autoreset
				iceTad_0w.rs485TxStart                   <= (others => '0'); -- autoreset
				iceTad_0w.rs485FifoClear                 <= (others => '0'); -- autoreset
				iceTad_0w.rs485FifoRead                  <= (others => '0'); -- autoreset
				gpsTiming_0w.newDataLatchedReset         <= '0';             -- autoreset
				whiteRabbitTiming_0w.newDataLatchedReset <= '0';             -- autoreset
				tmp05_0w.conversionStart                 <= '0';             -- autoreset
				dac088s085_x3_0w.valuesChangedChip0      <= x"00";           -- autoreset
				dac088s085_x3_0w.valuesChangedChip1      <= x"00";           -- autoreset
				dac088s085_x3_0w.valuesChangedChip2      <= x"00";           -- autoreset
				eventFifoSystem_0w.forceMiscData         <= '0';             -- autoreset
				i2c_control_w.start                      <= '0';             -- autoreset;
				if (controlBus.reset = '1') then
					registerA                               <= (others => '0');
					registerb                               <= (others => '0');
					registerC                               <= (others => '0');
					triggerDataDelay_0w.numberOfDelayCycles <= x"0004";
					triggerDataDelay_0w.resetDelay          <= '1';
					triggerDataDelay_1w.numberOfDelayCycles <= x"0005";
					triggerDataDelay_1w.resetDelay          <= '1';
					ad56x1_0w.valueChip0                    <= x"800";
					ad56x1_0w.valueChip1                    <= x"800";
					ad56x1_0w.valueChangedChip0            <= '1'; -- autoreset
					ad56x1_0w.valueChangedChip1            <= '1'; -- autoreset
					eventFifoSystem_0w.packetConfig        <= x"0006";
					eventFifoSystem_0w.eventsPerIrq        <= x"0001";
					eventFifoSystem_0w.irqAtEventFifoWords <= x"0100";
					eventFifoSystem_0w.enableIrq           <= '0';
					eventFifoSystem_0w.irqStall            <= '0';
					eventFifoSystem_0w.deviceId            <= x"0000";
					eventFifoSystem_0w.drs4ChipSelector    <= x"0026";
					numberOfSamplesToRead                  <= x"0020";
					drs4_0w.sampleMode                     <= x"1";
					drs4_0w.readoutMode                    <= x"5";
					drs4_0w.writeShiftRegister             <= "11111111";
					ltm9007_14_0w.testMode                 <= x"0";
					ltm9007_14_0w.init                     <= '1'; --autoreset
					ltm9007_14_0w.debugChannelSelector     <= "000";
					ltm9007_14_0w.debugFifoControl         <= x"3032";
					triggerLogic_0w.triggerMask            <= x"ff"; -- ## debug
					triggerLogic_0w.triggerSerdesDelayInit <= '1';   --autoreset
					triggerLogic_0w.triggerSerdesDelay     <= "00" & x"68";
					triggerLogic_0w.triggerGeneratorPeriod <= x"00c00000"; -- 0xc0000 ~ 10Hz
					triggerLogic_0w.sameEventTime          <= x"080";      -- like numberOfSamplesToRead/8  but different time per tick
					triggerLogic_0w.triggerSum             <= x"00";
					triggerLogic_0w.triggerSec             <= x"FF";
					panelPower_0w.enable                <= '0';
					dac088s085_x3_0w.valuesChip0        <= (others => x"30");
					dac088s085_x3_0w.valuesChip1        <= (others => x"00");
					dac088s085_x3_0w.valuesChip2        <= (others => x"00");
					dac088s085_x3_0w.valuesChangedChip0 <= x"ff";
					dac088s085_x3_0w.valuesChangedChip1 <= x"ff";
					dac088s085_x3_0w.valuesChangedChip2 <= x"ff";
					clockConfig_debug_0w.drs4RefClockPeriod   <= x"7f";
					eventFifoWordsDmaSlice_latched            <= (others => '0');
					pixelRateCounter_0w.doublePulsePrevention <= '1';
					pixelRateCounter_0w.doublePulseTime       <= x"80";   -- 0x30 ~ 400ns; 0x80 ~ like 1us; maybe it shoud be like 'sameEventTime' 
					pixelRateCounter_0w.counterPeriod         <= x"0001"; -- 1 sec
					whiteRabbitTiming_0w.counterPeriod        <= x"0001"; -- 1 sec
					triggerLogic_0w.counterPeriod             <= x"0001"; -- 1 sec
					iceTad_0w.rs485Data                       <= (others => (others => '0'));
					iceTad_0w.softTxEnable                    <= (others => '0');
					iceTad_0w.softTxMask                      <= (others => '0');
				else
					if ((controlBus.writeStrobe = '1') and (controlBus.readStrobe = '0') and (chipSelectInternal = '1')) then
						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
								-- address 0x0000-0x0fff has to be the same for all taxi based systems
								-- address 0x1000-0x1fff is used for icescint
								-- address 0x2000-0x2fff is used for polarstern
								-- address 0x3000-0x3fff is used for taxi classic (24ch. version)
							when x"0000" => registerA <= dataBusbuf(7 downto 0);
							when x"0002" => registerB <= dataBusbuf;

							when x"0010" => modus <= dataBusbuf(7 downto 0);

							when x"0020" => writemsbs <= dataBusbuf(7 downto 0);

							when x"0102" => eventFifoClear              <= '1'; -- autoreset
							when x"0108" => eventFifoSystem_0w.irqStall <= dataBusbuf(0);
							when x"010a" => eventFifoSystem_0w.deviceId <= dataBusbuf;

							when x"0200" => gpsTiming_0w.counterPeriod       <= dataBusbuf;
							when x"0202" => gpsTiming_0w.newDataLatchedReset <= '1'; -- autoreset

							when x"0300" => tmp05_0w.conversionStart <= dataBusbuf(0); -- autoreset
							when others  => null;
						end case;

						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
							when x"0310" => ad56x1_0w.valueChip0        <= dataBusbuf(11 downto 0);
								ad56x1_0w.valueChangedChip0                 <= '1'; -- autoreset
							when x"0312" => ad56x1_0w.valueChip1        <= dataBusbuf(11 downto 0);
								ad56x1_0w.valueChangedChip1                 <= '1'; -- autoreset
							when x"0314" => ad56x1_0w.valueChangedChip0 <= dataBusbuf(0);
								ad56x1_0w.valueChangedChip1                 <= dataBusbuf(1); -- autoreset
							when others => null;
						end case;

						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
							when x"0400" => dac088s085_x3_0w.init               <= '1';                    -- autoreset
							when x"0402" => dac088s085_x3_0w.valuesChangedChip0 <= dataBusbuf(7 downto 0); -- autoreset
							when x"0404" => dac088s085_x3_0w.valuesChangedChip1 <= dataBusbuf(7 downto 0); -- autoreset
							when x"0406" => dac088s085_x3_0w.valuesChangedChip2 <= dataBusbuf(7 downto 0); -- autoreset
							when x"0410" => dac088s085_x3_0w.valuesChip0(0)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip0(0)              <= '1';
							when x"0412" => dac088s085_x3_0w.valuesChip0(1)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip0(1)              <= '1';
							when x"0414" => dac088s085_x3_0w.valuesChip0(2)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip0(2)              <= '1';
							when x"0416" => dac088s085_x3_0w.valuesChip0(3)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip0(3)              <= '1';
							when x"0418" => dac088s085_x3_0w.valuesChip0(4)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip0(4)              <= '1';
							when x"041a" => dac088s085_x3_0w.valuesChip0(5)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip0(5)              <= '1';
							when x"041c" => dac088s085_x3_0w.valuesChip0(6)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip0(6)              <= '1';
							when x"041e" => dac088s085_x3_0w.valuesChip0(7)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip0(7)              <= '1';
							when x"0420" => dac088s085_x3_0w.valuesChip1(0)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip0(0)              <= '1';
							when x"0422" => dac088s085_x3_0w.valuesChip1(1)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip1(1)              <= '1';
							when x"0424" => dac088s085_x3_0w.valuesChip1(2)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip1(2)              <= '1';
							when x"0426" => dac088s085_x3_0w.valuesChip1(3)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip1(3)              <= '1';
							when x"0428" => dac088s085_x3_0w.valuesChip1(4)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip1(4)              <= '1';
							when x"042a" => dac088s085_x3_0w.valuesChip1(5)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip1(5)              <= '1';
							when x"042c" => dac088s085_x3_0w.valuesChip1(6)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip1(6)              <= '1';
							when x"042e" => dac088s085_x3_0w.valuesChip1(7)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip1(7)              <= '1';
							when x"0430" => dac088s085_x3_0w.valuesChip2(0)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip2(0)              <= '1';
							when x"0432" => dac088s085_x3_0w.valuesChip2(1)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip2(1)              <= '1';
							when x"0434" => dac088s085_x3_0w.valuesChip2(2)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip2(2)              <= '1';
							when x"0436" => dac088s085_x3_0w.valuesChip2(3)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip2(3)              <= '1';
							when x"0438" => dac088s085_x3_0w.valuesChip2(4)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip2(4)              <= '1';
							when x"043a" => dac088s085_x3_0w.valuesChip2(5)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip2(5)              <= '1';
							when x"043c" => dac088s085_x3_0w.valuesChip2(6)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip2(6)              <= '1';
							when x"043e" => dac088s085_x3_0w.valuesChip2(7)     <= dataBusbuf(7 downto 0);
								dac088s085_x3_0w.valuesChangedChip2(7)              <= '1';
							when others => null;
						end case;

						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
							when x"100a" => clockConfig_debug_0w.drs4RefClockPeriod <= dataBusbuf(7 downto 0);
							when x"100c" => triggerDataDelay_0w.numberOfDelayCycles <= dataBusbuf;
								triggerDataDelay_0w.resetDelay                          <= '1'; -- autoreset
							when x"100e" => triggerDataDelay_1w.numberOfDelayCycles <= dataBusbuf;
								triggerDataDelay_1w.resetDelay                          <= '1'; -- autoreset
							when others => null;
						end case;

						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
							when x"1040" => pixelRateCounter_0w.resetCounter          <= dataBusbuf(7 downto 0); -- autoreset
							when x"1042" => pixelRateCounter_0w.counterPeriod         <= dataBusbuf;             -- autoreset 
							when x"1044" => pixelRateCounter_0w.doublePulsePrevention <= dataBusbuf(0);
							when x"1046" => pixelRateCounter_0w.doublePulseTime       <= dataBusbuf(7 downto 0);
							when others  => null;
						end case;

						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is

							when x"10a4" => drs4_0w.resetStates        <= '1'; -- autoreset
							when x"10a6" => numberOfSamplesToRead      <= dataBusbuf;
							when x"10a8" => drs4_0w.sampleMode         <= dataBusbuf(3 downto 0);
							when x"10aa" => drs4_0w.readoutMode        <= dataBusbuf(3 downto 0);
							when x"10ac" => drs4_0w.writeShiftRegister <= dataBusIn(7 downto 0);
							when others  => null;
						end case;

						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
							when x"10b0" => ltm9007_14_0w.testMode       <= dataBusbuf(3 downto 0);
								ltm9007_14_0w.init                           <= '1'; -- autoreset
							when x"10b2" => ltm9007_14_0w.testPattern    <= dataBusbuf(13 downto 0);
							when x"10b4" => ltm9007_14_0w.bitslipStart   <= dataBusbuf(2 downto 0); -- autoreset 
							when x"10b6" => ltm9007_14_0w.bitslipPattern <= dataBusbuf(6 downto 0);

							when x"10e0" => ltm9007_14_0w.offsetCorrectionRamWrite <= dataBusbuf(7 downto 0); -- autoreset 
							when x"10e2" => ltm9007_14_0w.offsetCorrectionRamAddress <= dataBusbuf(11 downto 0);
							when x"10e4" => ltm9007_14_0w.offsetCorrectionRamData    <= dataBusbuf(15 downto 0);
							when x"10e6" => ltm9007_14_0w.baselineStart              <= dataBusbuf(9 downto 0);
							when x"10e8" => ltm9007_14_0w.baselineEnd                <= dataBusbuf(9 downto 0);
							when x"10ea" => ltm9007_14_0w.debugChannelSelector       <= dataBusbuf(2 downto 0);
							when x"10ee" => ltm9007_14_0w.debugFifoControl           <= dataBusbuf;
							when others  => null;
						end case;

						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
							when x"10f0" => iceTad_0w.powerOn    <= dataBusbuf(7 downto 0);
							when x"10f2" => panelPower_0w.init   <= '1'; -- autoreset 
							when x"10f4" => panelPower_0w.enable <= dataBusbuf(0);
							when others  => null;
						end case;

						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
							when x"1100" => eventFifoSystem_0w.packetConfig        <= dataBusbuf;
							when x"1102" => eventFifoSystem_0w.eventsPerIrq        <= dataBusbuf;
							when x"1104" => eventFifoSystem_0w.irqAtEventFifoWords <= dataBusbuf;
							when x"1106" => eventFifoSystem_0w.enableIrq           <= dataBusbuf(0);
							when x"1108" => eventFifoSystem_0w.forceIrq            <= dataBusbuf(0); -- autoreset
							when x"110a" => eventFifoSystem_0w.clearEventCounter   <= dataBusbuf(0); -- autoreset
							when x"110c" => eventFifoSystem_0w.forceMiscData       <= '1';           -- autoreset
							when x"1114" => eventFifoSystem_0w.drs4ChipSelector    <= dataBusbuf;
							when x"112c" => debugReset                             <= '1'; -- autoreset
							when others  => null;
						end case;

						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
							when x"11d0" => triggerLogic_0w.triggerSerdesDelay <= dataBusbuf(9 downto 0);
								triggerLogic_0w.triggerSerdesDelayInit             <= '1'; --autoreset
								triggerDataDelay_1w.numberOfDelayCycles            <= x"00" & dataBusbuf(7 downto 0);
								triggerDataDelay_1w.resetDelay                     <= '1'; -- autoreset

							when x"11d2" => triggerLogic_0w.softTrigger                          <= '1'; --autoreset
							when x"11d4" => triggerLogic_0w.triggerMask                          <= dataBusbuf(7 downto 0);
							when x"11d6" => triggerLogic_0w.singleSeq                            <= dataBusbuf(0);
							when x"11d8" => triggerLogic_0w.triggerGeneratorEnabled              <= dataBusbuf(0);
							when x"11da" => triggerLogic_0w.triggerGeneratorPeriod(15 downto 0)  <= unsigned(dataBusbuf);
							when x"11dc" => triggerLogic_0w.triggerGeneratorPeriod(31 downto 16) <= unsigned(dataBusbuf);
							when x"11de" => triggerLogic_0w.resetCounter                         <= dataBusbuf(0); -- autoreset
							when x"11e0" => triggerLogic_0w.counterPeriod                        <= dataBusbuf;    -- autoreset
							when x"11e8" => triggerLogic_0w.sameEventTime                        <= dataBusbuf(11 downto 0);
							when x"11ea" => triggerLogic_0w.triggerSum                           <= dataBusbuf(7 downto 0);
							when x"11ec" => triggerLogic_0w.triggerSec                           <= dataBusbuf(7 downto 0);
							when others  => null;
						end case;

						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
							when x"1300" => iceTad_0w.rs485Data(0)   <= dataBusbuf(7 downto 0);
							when x"1302" => iceTad_0w.rs485Data(1)   <= dataBusbuf(7 downto 0);
							when x"1304" => iceTad_0w.rs485Data(2)   <= dataBusbuf(7 downto 0);
							when x"1306" => iceTad_0w.rs485Data(3)   <= dataBusbuf(7 downto 0);
							when x"1308" => iceTad_0w.rs485Data(4)   <= dataBusbuf(7 downto 0);
							when x"130a" => iceTad_0w.rs485Data(5)   <= dataBusbuf(7 downto 0);
							when x"130c" => iceTad_0w.rs485Data(6)   <= dataBusbuf(7 downto 0);
							when x"130e" => iceTad_0w.rs485Data(7)   <= dataBusbuf(7 downto 0);
							when x"1310" => iceTad_0w.rs485TxStart   <= dataBusbuf(7 downto 0); -- autoreset
							when x"1318" => iceTad_0w.rs485FifoClear <= dataBusbuf(7 downto 0); -- autoreset
							when x"131a" => iceTad_0w.rs485FifoRead  <= dataBusbuf(7 downto 0); -- autoreset
							when x"131c" => iceTad_0w.softTxEnable   <= dataBusbuf(7 downto 0);
							when x"131e" => iceTad_0w.softTxMask     <= dataBusbuf(7 downto 0);
							when x"1330" => registerC                <= dataBusbuf(15 downto 0);
							when others  => null;
						end case;

						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
							when x"1400" => whiteRabbitTiming_0w.newDataLatchedReset <= '1'; -- autoreset
							when x"1420" => whiteRabbitTiming_0w.counterPeriod       <= dataBusbuf;
							when others  => null;
						end case;

						case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
							when x"1500" => i2c_control_w.comand(47 downto 32) <= dataBusbuf;
							when x"1502" => i2c_control_w.comand(31 downto 16) <= dataBusbuf;
							when x"1504" => i2c_control_w.comand(15 downto 0)  <= dataBusbuf;
							when x"1506" => i2c_control_w.start                <= '1'; -- autoreset;
							when others  => null;
						end case;

					end if;
				end if; -- jetzt ohne reset im readpath	
				if ((controlBus.readStrobe = '1') and (controlBus.writeStrobe = '0') and (chipSelectInternal = '1')) then
					swapreaddata <= controlBus.address(0);
					case ((controlBus.address(15 downto 1) & "0") and not(subAddressMask)) is
						when x"0000" => readDataBuffer <= x"00" & registerA;
						when x"0002" => readDataBuffer <= registerB;
						when x"0004" => readDataBuffer <= x"5555";-- test
						when x"0006" => readDataBuffer <= x"aaaa";-- test
						when x"0008" => readDataBuffer <= x"2021";-- jahr
						when x"000a" => readDataBuffer <= x"0005";-- monat
						when x"000c" => readDataBuffer <= x"0004";-- tag 
						when x"000e" => readDataBuffer <= x"0300";-- version
						when x"0010" => readDataBuffer <= x"00" & modus;--modusregister read&write
						when x"0012" => readDataBuffer <= (not dummycnt) & dummycnt;
							inccnt                         <= not controlBus.address(0) xor modus(0);
							-- wenn modus(0)=0 dann wird auf adresse "0012" getriggert
							-- wenn modus(0)=1 dann wird auf adresse "4012" getriggert

							--					when x"0100" => readDataBuffer <= eventFifoSystem_0r.dmaBuffer; eventFifoSystem_0w.nextWord <= '1'; -- autoreset
						when x"0100" => readDataBuffer <= eventFifoSystem_0r.dmaBuffer;
							eventFifoSystem_0w.nextWord    <= not controlBus.address(0) xor modus(0); -- autoreset
							-- wenn modus(0)=0 dann wird auf adresse "0100" getriggert
							-- wenn modus(0)=1 dann wird auf adresse "4100" getriggert
						when x"0104" => readDataBuffer <= eventFifoSystem_0r.eventFifoWordsDmaAligned;
						when x"0106" => readDataBuffer <= eventFifoSystem_0r.eventFifoWordsPerSlice;
						when x"0108" => readDataBuffer <= x"000" & "000" & eventFifoSystem_0r.irqStall;
						when x"010a" => readDataBuffer <= eventFifoSystem_0r.deviceId;

						when x"0200" => readDataBuffer <= gpsTiming_0r.counterPeriod;
						when x"0202" => readDataBuffer <= x"000" & "000" & gpsTiming_0r.newDataLatched;
						when x"0204" => readDataBuffer <= gpsTiming_0r.differenceGpsToLocalClock;
						when x"0206" => readDataBuffer <= gpsTiming_0r.week;
						when x"0208" => readDataBuffer <= gpsTiming_0r.quantizationError(31 downto 16); -- sync!
						when x"020a" => readDataBuffer <= gpsTiming_0r.quantizationError(15 downto 0);
						when x"020c" => readDataBuffer <= gpsTiming_0r.timeOfWeekMilliSecond(31 downto 16); -- sync!
						when x"020e" => readDataBuffer <= gpsTiming_0r.timeOfWeekMilliSecond(15 downto 0);

						when x"0300" => readDataBuffer <= x"000" & "000" & tmp05_0r.busy;
						when x"0302" => readDataBuffer <= tmp05_0r.tl;
							tmp05_0r_thLatched             <= tmp05_0r.th;
						when x"0304" => readDataBuffer <= tmp05_0r_thLatched;
						when x"0306" => readDataBuffer <= tmp05_0r.debugCounter(15 downto 0);
						when x"0308" => readDataBuffer <= x"00" & tmp05_0r.debugCounter(23 downto 16);

						when x"0310" => readDataBuffer <= x"0" & ad56x1_0r.valueChip0;
						when x"0312" => readDataBuffer <= x"0" & ad56x1_0r.valueChip1;
						when x"0314" => readDataBuffer <= x"000" & "000" & ad56x1_0r.dacBusy;

						when x"0402" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChangedChip0;
						when x"0404" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChangedChip1;
						when x"0406" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChangedChip2;
						when x"0408" => readDataBuffer <= x"000" & "000" & dac088s085_x3_0r.dacBusy;
						when x"0410" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip0(0);
						when x"0412" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip0(1);
						when x"0414" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip0(2);
						when x"0416" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip0(3);
						when x"0418" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip0(4);
						when x"041a" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip0(5);
						when x"041c" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip0(6);
						when x"041e" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip0(7);
						when x"0420" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip1(0);
						when x"0422" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip1(1);
						when x"0424" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip1(2);
						when x"0426" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip1(3);
						when x"0428" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip1(4);
						when x"042a" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip1(5);
						when x"042c" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip1(6);
						when x"042e" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip1(7);
						when x"0430" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip2(0);
						when x"0432" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip2(1);
						when x"0434" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip2(2);
						when x"0436" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip2(3);
						when x"0438" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip2(4);
						when x"043a" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip2(5);
						when x"043c" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip2(6);
						when x"043e" => readDataBuffer <= x"00" & dac088s085_x3_0r.valuesChip2(7);

						when x"100c" => readDataBuffer <= triggerDataDelay_0r.numberOfDelayCycles;
						when x"100e" => readDataBuffer <= triggerDataDelay_1r.numberOfDelayCycles;

						when x"1100" => readDataBuffer <= eventFifoSystem_0r.packetConfig;
						when x"1102" => readDataBuffer <= eventFifoSystem_0r.eventsPerIrq;
						when x"1104" => readDataBuffer <= eventFifoSystem_0r.irqAtEventFifoWords;
						when x"1106" => readDataBuffer <= x"000" & "000" & eventFifoSystem_0r.enableIrq;
						when x"110c" => readDataBuffer <= x"000" & "000" & eventFifoSystem_0r.irqStall;
						when x"110e" => readDataBuffer <= eventFifoSystem_0r.eventFifoErrorCounter;
						when x"1110" => readDataBuffer <= eventFifoSystem_0r.eventRateCounter;
						when x"1112" => readDataBuffer <= eventFifoSystem_0r.eventLostRateCounter;

						when x"1114" => readDataBuffer <= eventFifoSystem_0r.drs4ChipSelector;
						when x"1116" => readDataBuffer <= eventFifoSystem_0r.debugFifoOut;

						when x"1010" => readDataBuffer <= triggerTimeToRisingEdge_0r.channel(0);
						when x"1012" => readDataBuffer <= triggerTimeToRisingEdge_0r.channel(1);
						when x"1014" => readDataBuffer <= triggerTimeToRisingEdge_0r.channel(2);
						when x"1016" => readDataBuffer <= triggerTimeToRisingEdge_0r.channel(3);
						when x"1018" => readDataBuffer <= triggerTimeToRisingEdge_0r.channel(4);
						when x"101a" => readDataBuffer <= triggerTimeToRisingEdge_0r.channel(5);
						when x"101c" => readDataBuffer <= triggerTimeToRisingEdge_0r.channel(6);
						when x"101e" => readDataBuffer <= triggerTimeToRisingEdge_0r.channel(7);

						when x"1126" => readDataBuffer <= eventFifoSystem_0r.eventFifoFullCounter;
						when x"1128" => readDataBuffer <= eventFifoSystem_0r.eventFifoOverflowCounter;
						when x"112a" => readDataBuffer <= eventFifoSystem_0r.eventFifoUnderflowCounter;
						when x"112c" => readDataBuffer <= eventFifoSystem_0r.eventFifoWords;
						when x"112e" => readDataBuffer <= eventFifoSystem_0r.eventFifoFlags;

						when x"1030" => readDataBuffer <= pixelRateCounter_0r.pixelCounterAllEdgesLatched(0);
						when x"1032" => readDataBuffer <= pixelRateCounter_0r.pixelCounterAllEdgesLatched(1);
						when x"1034" => readDataBuffer <= pixelRateCounter_0r.pixelCounterAllEdgesLatched(2);
						when x"1036" => readDataBuffer <= pixelRateCounter_0r.pixelCounterAllEdgesLatched(3);
						when x"1038" => readDataBuffer <= pixelRateCounter_0r.pixelCounterAllEdgesLatched(4);
						when x"103a" => readDataBuffer <= pixelRateCounter_0r.pixelCounterAllEdgesLatched(5);
						when x"103c" => readDataBuffer <= pixelRateCounter_0r.pixelCounterAllEdgesLatched(6);
						when x"103e" => readDataBuffer <= pixelRateCounter_0r.pixelCounterAllEdgesLatched(7);

						when x"1042" => readDataBuffer <= pixelRateCounter_0r.counterPeriod;
						when x"1044" => readDataBuffer <= x"000" & "000" & pixelRateCounter_0r.doublePulsePrevention;
						when x"1046" => readDataBuffer <= x"00" & pixelRateCounter_0r.doublePulseTime;

						when x"10a2" => readDataBuffer <= x"0" & "00" & drs4_0r.regionOfInterest;
						when x"10a6" => readDataBuffer <= drs4_0r.numberOfSamplesToRead;
						when x"10a8" => readDataBuffer <= x"000" & drs4_0r.sampleMode;
						when x"10aa" => readDataBuffer <= x"000" & drs4_0r.readoutMode;

						when x"10ac" => readDataBuffer <= x"00" & drs4_0r.writeShiftRegister;
						when x"10ae" => readDataBuffer <= x"00" & drs4_0r.cascadingDataDebug;
						when x"10b0" => readDataBuffer <= x"000" & ltm9007_14_0r.testMode;
						when x"10b2" => readDataBuffer <= "00" & ltm9007_14_0r.testPattern;
						when x"10b4" => readDataBuffer <= x"00" & "00" & ltm9007_14_0r.bitslipFailed;
						when x"10b6" => readDataBuffer <= x"00" & "0" & ltm9007_14_0r.bitslipPattern;

						when x"11d0" => readDataBuffer <= x"0" & "00" & triggerLogic_0r.triggerSerdesDelay;
						when x"11d4" => readDataBuffer <= x"00" & triggerLogic_0r.triggerMask;
						when x"11d6" => readDataBuffer <= x"000" & "000" & triggerLogic_0r.singleSeq;
						when x"11d8" => readDataBuffer <= x"000" & "000" & triggerLogic_0r.triggerGeneratorEnabled;
						when x"11da" => readDataBuffer <= std_logic_vector(triggerLogic_0r.triggerGeneratorPeriod(15 downto 0));
						when x"11dc" => readDataBuffer <= std_logic_vector(triggerLogic_0r.triggerGeneratorPeriod(31 downto 16));
						when x"11e0" => readDataBuffer <= triggerLogic_0r.counterPeriod;
						when x"11e4" => readDataBuffer <= triggerLogic_0r.rateLatched;
						when x"11e6" => readDataBuffer <= triggerLogic_0r.rateDeadTimeLatched;
						when x"11e8" => readDataBuffer <= x"0" & triggerLogic_0r.sameEventTime;

						when x"10e2" => readDataBuffer <= "0000" & ltm9007_14_0r.offsetCorrectionRamAddress;
						when x"10e4" => readDataBuffer <= ltm9007_14_0r.offsetCorrectionRamData(0); -- ## and 1..7 ?!
						when x"10e6" => readDataBuffer <= "000000" & ltm9007_14_0r.baselineStart;
						when x"10e8" => readDataBuffer <= "000000" & ltm9007_14_0r.baselineEnd;

						when x"10ea" => readDataBuffer <= x"000" & "0" & ltm9007_14_0r.debugChannelSelector;
						when x"10ec" => readDataBuffer <= ltm9007_14_0r.debugFifoOut;

						when x"10f0" => readDataBuffer                <= x"00" & iceTad_0r.powerOn;
						when x"1300" => readDataBuffer                <= x"00" & iceTad_0r.rs485FifoData(0);
						when x"1302" => readDataBuffer                <= x"00" & iceTad_0r.rs485FifoData(1);
						when x"1304" => readDataBuffer                <= x"00" & iceTad_0r.rs485FifoData(2);
						when x"1306" => readDataBuffer                <= x"00" & iceTad_0r.rs485FifoData(3);
						when x"1308" => readDataBuffer                <= x"00" & iceTad_0r.rs485FifoData(4);
						when x"130a" => readDataBuffer                <= x"00" & iceTad_0r.rs485FifoData(5);
						when x"130c" => readDataBuffer                <= x"00" & iceTad_0r.rs485FifoData(6);
						when x"130e" => readDataBuffer                <= x"00" & iceTad_0r.rs485FifoData(7);
						when x"1310" => readDataBuffer                <= x"00" & iceTad_0r.rs485TxBusy;
						when x"1312" => readDataBuffer                <= x"00" & iceTad_0r.rs485RxBusy;
						when x"1314" => readDataBuffer                <= x"00" & iceTad_0r.rs485FifoFull;
						when x"1316" => readDataBuffer                <= x"00" & iceTad_0r.rs485FifoEmpty;
						when x"131c" => readDataBuffer                <= x"00" & iceTad_0r.softTxEnable;
						when x"131e" => readDataBuffer                <= x"00" & iceTad_0r.softTxMask;
						when x"1320" => readDataBuffer                <= "00000" & iceTad_0r.rs485FifoWords(0);
						when x"1322" => readDataBuffer                <= "00000" & iceTad_0r.rs485FifoWords(1);
						when x"1324" => readDataBuffer                <= "00000" & iceTad_0r.rs485FifoWords(2);
						when x"1326" => readDataBuffer                <= "00000" & iceTad_0r.rs485FifoWords(3);
						when x"1328" => readDataBuffer                <= "00000" & iceTad_0r.rs485FifoWords(4);
						when x"132a" => readDataBuffer                <= "00000" & iceTad_0r.rs485FifoWords(5);
						when x"132c" => readDataBuffer                <= "00000" & iceTad_0r.rs485FifoWords(6);
						when x"132e" => readDataBuffer                <= "00000" & iceTad_0r.rs485FifoWords(7);
						when x"1330" => readDataBuffer                <= registerC;
						when x"1400" => readDataBuffer                <= x"000" & "000" & whiteRabbitTiming_0r.newDataLatched;
							whiteRabbitTiming_0r_irigDataLatched          <= whiteRabbitTiming_0r.irigDataLatched;
							whiteRabbitTiming_0r_irigBinaryYearsLatched   <= whiteRabbitTiming_0r.irigBinaryYearsLatched;
							whiteRabbitTiming_0r_irigBinaryDaysLatched    <= whiteRabbitTiming_0r.irigBinaryDaysLatched;
							whiteRabbitTiming_0r_irigBinarySecondsLatched <= whiteRabbitTiming_0r.irigBinarySecondsLatched;
						when x"1402" => readDataBuffer                <= "0" & whiteRabbitTiming_0r_irigDataLatched(15 downto 13)
							& whiteRabbitTiming_0r_irigDataLatched(11 downto 8) -- min
							& "0" & whiteRabbitTiming_0r_irigDataLatched(7 downto 5)
							& whiteRabbitTiming_0r_irigDataLatched(3 downto 0); -- sec
						when x"1404" => readDataBuffer <= x"00" & "00" & whiteRabbitTiming_0r_irigDataLatched(23 downto 22)
							& whiteRabbitTiming_0r_irigDataLatched(20 downto 17); -- hour
						when x"1406" => readDataBuffer <= x"0" & "00" & whiteRabbitTiming_0r_irigDataLatched(36 downto 35)
							& whiteRabbitTiming_0r_irigDataLatched(34 downto 31)
							& whiteRabbitTiming_0r_irigDataLatched(29 downto 26); -- day
						when x"1408" => readDataBuffer <= x"00" & whiteRabbitTiming_0r_irigDataLatched(52 downto 49)
							& whiteRabbitTiming_0r_irigDataLatched(47 downto 44);                                         --year
						when x"140a" => readDataBuffer <= whiteRabbitTiming_0r_irigBinarySecondsLatched(15 downto 0); -- binary sec of day
						when x"140c" => readDataBuffer <= whiteRabbitTiming_0r_irigBinarySecondsLatched(16) & x"0" & "00" & whiteRabbitTiming_0r_irigBinaryDaysLatched;
						when x"140e" => readDataBuffer <= x"00" & "0" & whiteRabbitTiming_0r_irigBinaryYearsLatched;

						when x"1410" => readDataBuffer <= whiteRabbitTiming_0r_irigDataLatched(15 downto 0);
						when x"1412" => readDataBuffer <= whiteRabbitTiming_0r_irigDataLatched(31 downto 16);
						when x"1414" => readDataBuffer <= whiteRabbitTiming_0r_irigDataLatched(47 downto 32);
						when x"1416" => readDataBuffer <= whiteRabbitTiming_0r_irigDataLatched(63 downto 48);
						when x"1418" => readDataBuffer <= whiteRabbitTiming_0r_irigDataLatched(79 downto 64);
						when x"141a" => readDataBuffer <= "0000000" & whiteRabbitTiming_0r_irigDataLatched(88 downto 80);
						when x"141c" => readDataBuffer <= x"00" & whiteRabbitTiming_0r.bitCounter;
						when x"141e" => readDataBuffer <= whiteRabbitTiming_0r.errorCounter;
						when x"1420" => readDataBuffer <= whiteRabbitTiming_0r.counterPeriod;

						when x"1508" => readDataBuffer <= i2c_control_r.readdata;
						when x"150a" => readDataBuffer <= x"000" & "000" & i2c_control_r.idle;

						when x"f000" => readDataBuffer <= x"000" & "000" & ltm9007_14_0r.fifoEmptyA;
						when x"f002" => readDataBuffer <= x"000" & "000" & ltm9007_14_0r.fifoValidA;
						when x"f004" => readDataBuffer <= x"00" & ltm9007_14_0r.fifoWordsA;
						when others => readDataBuffer <= x"dead";
					end case;
				end if;
			end if;
		end process P0;
	end generate g0;
end behavior;

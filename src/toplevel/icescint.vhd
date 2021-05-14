-------------------------------------------------------
-- Design Name      : taxi_003_top
-- File Name        : taxi_003_top.vhd
-- Device           : Spartan 6, XC6SLX45FGG484-2
-- Migration Device : Spartan 6, XC6SLX100FGG484-2
-- Function         : taxi top level test design rev-005
-- Coder(s)         : K.-H. Sulanke & S. Kunwar & M. Kossatz, DESY, 2016
-------------------------------------------------------
-- compiling duration = min
-- QOSC1_OUT, 25 MHz, 3.3V CMOS 2.5 ppm

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;
use work.types_platformSpecific.all;

library unisim;
use unisim.vcomponents.all;

entity icescint is
	generic(
		NUM_RADIO : natural := 3;
		NUM_UDAQ  : natural := 8
	);
	port(
		i_rst_ext             : in    std_logic;
		i_clk_10m_0           : in    std_logic;
		i_clk_10m_1           : in    std_logic;
		i_clk_10m_sel         : in    std_logic;
		o_radio_drs4_resetn   : out   std_logic                           := '0'; -- chip reset
		o_radio_drs4_refclock : out   std_logic                           := '0'; -- 1 GHz / 2048 reference clock,
		i_radio_drs4_plllock  : in    std_logic_vector(0 to NUM_RADIO - 1);
		o_radio_drs4_denable  : out   std_logic                           := '0';
		o_radio_drs4_dwrite   : out   std_logic                           := '0';
		o_radio_drs4_rsrload  : out   std_logic                           := '0';
		o_radio_drs4_address  : out   std_logic_vector(3 downto 0)        := x"0";
		i_radio_drs4_dtap     : in    std_logic_vector(0 to NUM_RADIO - 1);
		i_radio_drs4_srout    : in    std_logic_vector(0 to NUM_RADIO - 1); -- SPI interface
		o_radio_drs4_srin     : out   std_logic                           := '0';
		o_radio_drs4_srclk    : out   std_logic                           := '0';
		i_radio_adc_data_p    : in    slv8_array_t(0 to NUM_RADIO - 1); -- ADC SERDES data TODO: move differential receivers to toplevel
		i_radio_adc_data_n    : in    slv8_array_t(0 to NUM_RADIO - 1);
		o_radio_adc_csan      : out   std_logic                           := '0';
		o_radio_adc_csbn      : out   std_logic                           := '0';
		o_radio_adc_sdi       : out   std_logic                           := '0';
		o_radio_adc_sck       : out   std_logic                           := '0';
		o_radio_adc_refclk    : out   std_logic                           := '0'; -- ENC
		-- DAC for radio thresholds and offset
		o_radio_dac_syncn     : out   std_logic                           := '0';
		o_radio_dac_do        : out   std_logic                           := '0';
		o_radio_dac_sck       : out   std_logic                           := '0';
		o_radio_power24n      : out   std_logic                           := '0'; -- 24V power for fanout board

		i_ebi_select          : in    std_logic;
		i_ebi_write           : in    std_logic;
		i_ebi_read            : in    std_logic;
		i_ebi_address         : in    std_logic_vector(15 downto 0);
		i_ebi_data_in         : in    std_logic_vector(15 downto 0);
		o_ebi_data_out        : out   std_logic_vector(15 downto 0)       := x"0000";
		o_ebi_irq             : out   std_logic                           := '0';
		i_gps_pps             : in    std_logic;
		i_gps_uart_in         : in    std_logic;
		i_wr_pps              : in    std_logic;
		i_wr_clock            : in    std_logic;
		i_panel_trigger       : in    std_logic_vector(0 to NUM_UDAQ - 1);
		o_panel_24v_on_n      : out   std_logic_vector(0 to NUM_UDAQ - 1) := (others => '0'); -- nP24VOn
		o_panel_24v_tri       : out   std_logic_vector(0 to NUM_UDAQ - 1) := (others => '1'); -- nP24VOnTristate
		i_panel_rs485_in      : in    std_logic_vector(0 to NUM_UDAQ - 1); -- rs485DataIn
		o_panel_rs485_out     : out   std_logic_vector(0 to NUM_UDAQ - 1) := (others => '0'); -- rs485DataOut
		o_panel_rs485_en      : out   std_logic_vector(0 to NUM_UDAQ - 1) := (others => '0'); -- rs485DataEnable

		io_pin_tmp05          : inout std_logic                           := '0';
		o_vcxo_25_syncn       : out   std_logic                           := '0';
		o_vcxo_10_syncn       : out   std_logic                           := '0';
		o_vcxo_25_do          : out   std_logic                           := '0';
		o_vcxo_25_sck         : out   std_logic                           := '0';
		o_scl                 : out   std_logic                           := '1';
		o_sda_out             : out   std_logic                           := '1';
		i_sda_in              : in    std_logic;
		ignore                : out   bit                                 := '0' -- because VDHL does not allow trailing commas
	);
end icescint;

architecture behaviour of icescint is
	attribute keep : string;

	constant SYS_CLOCK_PERIOD : time := 10.0 ns;
	signal sys_clk            : std_logic;
	signal sys_rst            : std_logic;
	signal sys_pll_feedback   : std_logic;
	signal sys_pll_locked     : std_logic;

	constant ADC_CLOCK_PERIOD : time := 33.33333 ns;
	signal adc_clk            : std_logic;
	signal adc_clk_serdes     : std_logic;
	signal adc_refclk         : std_logic;
	signal adc_rst            : std_logic;

	signal user2regs : user2regs_t;
	signal regs2user : regs2user_t;

	----------------------------------------------------------------------------
	-- LEGACY BELOW
	----------------------------------------------------------------------------

	signal addressAndControlBus : std_logic_vector(31 downto 0);

	signal eventFifoSystem_0r   : eventFifoSystem_registerRead_t;
	signal eventFifoSystem_0w   : eventFifoSystem_registerWrite_t;
	signal dac088s085_x3_0r     : dac088s085_x3_registerRead_t;
	signal dac088s085_x3_0w     : dac088s085_x3_registerWrite_t;
	signal internalTiming_0r    : internalTiming_registerRead_t;
	signal internalTiming_0w    : internalTiming_registerWrite_t;
	signal whiteRabbitTiming_0r : whiteRabbitTiming_registerRead_t;
	signal whiteRabbitTiming_0w : whiteRabbitTiming_registerWrite_t;
	signal ad56x1_0r            : ad56x1_registerRead_t;
	signal ad56x1_0w            : ad56x1_registerWrite_t;
	signal drs4_0r              : drs4_registerRead_t;
	signal drs4_0w              : drs4_registerWrite_t;
	signal drs4_1r              : drs4_registerRead_t;
	signal drs4_1w              : drs4_registerWrite_t;
	signal drs4_2r              : drs4_registerRead_t;
	signal drs4_2w              : drs4_registerWrite_t;
	signal ltm9007_14r          : ltm9007_14_registerRead_t;
	signal ltm9007_14_0r        : ltm9007_14_registerRead_t;
	signal ltm9007_14_0w        : ltm9007_14_registerWrite_t;
	signal ltm9007_14_1r        : ltm9007_14_registerRead_t;
	signal ltm9007_14_1w        : ltm9007_14_registerWrite_t;
	signal ltm9007_14_2r        : ltm9007_14_registerRead_t;
	signal ltm9007_14_2w        : ltm9007_14_registerWrite_t;
	signal triggerLogic_0r      : triggerLogic_registerRead_t;
	signal triggerLogic_0w      : triggerLogic_registerWrite_t;
	signal iceTad_0r            : iceTad_registerRead_t;
	signal iceTad_0w            : iceTad_registerWrite_t;
	signal panelPower_0r        : panelPower_registerRead_t;
	signal panelPower_0w        : panelPower_registerWrite_t;
	signal tmp05_0r             : tmp05_registerRead_t;
	signal tmp05_0w             : tmp05_registerWrite_t;
	signal i2c_control_r        : i2c_registerRead_t;
	signal i2c_control_w        : i2c_registerWrite_t;
	signal triggerSerdesClocks  : triggerSerdesClocks_t;
	signal triggerTiming        : triggerTiming_t;
	signal adcData              : ltm9007_14_to_eventFifoSystem_old_t;
	signal adcData2             : ltm9007_14_to_eventFifoSystem_old_t;
	signal adcData3             : ltm9007_14_to_eventFifoSystem_old_t;
	signal internalTiming       : internalTiming_t;
	signal whiteRabbitTiming    : whiteRabbitTiming_t;
	signal adcFifo              : adcFifo_t;
	signal adcClocks            : adcClocks_t;
	signal trigger              : triggerLogic_t;
	signal triggerDRS4          : std_logic;
	signal pixelRates           : pixelRateCounter_t;
	signal clockConfig_debug    : clockConfig_debug_t;

	signal fifo : std_logic_vector(5 downto 0);

	constant numberOfDsr : integer := 3;
	type drsChannel_t is array (0 to numberOfDsr - 1) of std_logic_vector(7 downto 0);
	signal discriminator : drsChannel_t;

	signal deadTime           : std_logic;
	signal rateCounterTimeOut : std_logic;

	signal edgeData      : std_logic_vector(8 * 16 - 1 downto 0);
	signal edgeDataReady : std_logic;

	signal drs4AndAdcData          : drs4AndAdcData_vector_t;
	signal drs4_to_eventFifoSystem : drs4_to_eventFifoSystem_t;

begin

	pll_sys : PLL_ADV
		generic map(
			BANDWIDTH              => "OPTIMIZED",
			CLKFBOUT_DESKEW_ADJUST => "NONE",
			CLKFBOUT_MULT          => 50, -- VCO: 500 MHz
			CLKFBOUT_PHASE         => 0.0,
			CLKIN1_PERIOD          => 100.0,
			CLKIN2_PERIOD          => 100.0,
			CLKOUT0_DIVIDE         => 5, -- 100 MHz system clock 
			CLKOUT1_DIVIDE         => 7, -- 70 MHz ADC data clock
			CLKOUT2_DIVIDE         => 1, -- 500 MHz ADC SERDES clock
			CLKOUT3_DIVIDE         => 14, -- 35 MHz ADC reference clock
			CLKOUT4_DIVIDE         => 1, -- NOT USED
			CLKOUT5_DIVIDE         => 1, -- NOT USED
			CLK_FEEDBACK           => "CLKFBOUT",
			COMPENSATION           => "SYSTEM_SYNCHRONOUS",
			DIVCLK_DIVIDE          => 1
		)
		port map(
			REL      => '0',
			CLKFBOUT => sys_pll_feedback,
			CLKOUT0  => sys_clk,
			CLKOUT1  => adc_clk,
			CLKOUT2  => adc_clk_serdes,
			CLKOUT3  => adc_refclk,
			CLKOUT4  => open,
			CLKOUT5  => open,
			LOCKED   => sys_pll_locked,
			CLKFBIN  => sys_pll_feedback,
			CLKIN1   => i_clk_10m_0,
			CLKIN2   => i_clk_10m_1,
			CLKINSEL => i_clk_10m_sel,
			DADDR    => "00000",
			DCLK     => '0',
			DEN      => '0',
			DI       => x"0000",
			DWE      => '0',
			RST      => i_rst_ext
		);

	registers : entity work.registers_icescint
		port map(
			i_clk       => sys_clk,
			i_rst       => sys_rst,
			i_read      => i_ebi_read,
			i_write     => i_ebi_write,
			i_ebi_addr  => i_ebi_address,
			i_ebi_data  => i_ebi_data_in,
			o_ebi_data  => o_ebi_data_out,
			i_user2regs => user2regs,
			o_regs2user => regs2user
		);

		--	x1 : entity work.smcBusWrapper
		--		port map(
		--			chipSelect           => i_ebi_select,
		--			addressAsync         => i_ebi_address,
		--			controlRead          => i_ebi_read,
		--			controlWrite         => i_ebi_write,
		--			reset                => triggerSerdesClocks.rst_div8,
		--			busClock             => triggerSerdesClocks.clk_118_serdes_div8,
		--			addressAndControlBus => addressAndControlBus
		--		);
		--
		--	x11 : entity work.eventFifoSystem
		--		port map(
		--			trigger            => trigger,
		--			rateCounterTimeOut => rateCounterTimeOut,
		--			irq2arm            => o_ebi_irq,
		--			triggerTiming      => triggerTiming,
		--			drs4AndAdcData     => drs4AndAdcData,
		--			internalTiming     => internalTiming,
		--			gpsTiming          => gpsTiming,
		--			whiteRabbitTiming  => whiteRabbitTiming,
		--			pixelRateCounter   => pixelRates,
		--			registerRead       => eventFifoSystem_0r,
		--			registerWrite      => eventFifoSystem_0w
		--		);
		--
		--	x14a : entity work.internalTiming
		--		generic map(globalClockRate_kHz)
		--		port map(
		--			clock_enables => internalTiming,
		--			registerRead  => internalTiming_0r,
		--			registerWrite => internalTiming_0w
		--		);
		--
		--	x14c : entity work.whiteRabbitTiming
		--		generic map(
		--			G_CLOCK_PERIOD => 8.333333333 ns
		--		)
		--		port map(
		--			i_wr_pps          => i_wr_pps,
		--			i_wr_clock        => '0',
		--			internalTiming    => internalTiming,
		--			whiteRabbitTiming => whiteRabbitTiming,
		--			registerRead      => whiteRabbitTiming_0r,
		--			registerWrite     => whiteRabbitTiming_0w
		--		);
		--
		--	triggerDRS4 <= trigger.triggerDelayed or trigger.softTrigger;
		--
		--	x16 : entity work.drs4adc
		--		port map(
		--			address        => o_radio_drs4_address,
		--			notReset0      => o_radio_drs4_resetn,
		--			denable0       => o_radio_drs4_denable,
		--			dwrite0        => o_radio_drs4_dwrite,
		--			rsrload0       => o_radio_drs4_rsrload,
		--			miso0          => i_radio_drs4_srout(0),
		--			mosi0          => o_radio_drs4_srin,
		--			srclk0         => o_radio_drs4_srclk,
		--			dtap0          => i_radio_drs4_dtap(0),
		--			plllck0        => i_radio_drs4_plllock(0),
		--			deadTime       => deadTime,
		--			trigger        => triggerDRS4,
		--			internalTiming => internalTiming,
		--			adcClocks      => adcClocks,
		--			drs4_0r        => drs4_0r,
		--			drs4_0w        => drs4_0w,
		--			nCSA0          => o_radio_adc_csan,
		--			nCSB0          => o_radio_adc_csbn,
		--			mosi           => o_radio_adc_sdi,
		--			sclk           => o_radio_adc_sck,
		--			enc0           => o_radio_adc_refclk,
		--			adcDataA_p0    => i_radio_adc_data_p(0),
		--			adcDataA_n0    => i_radio_adc_data_n(0),
		--			drs4AndAdcData => drs4AndAdcData(0),
		--			ChannelID      => "00",
		--			fifoemptyout   => fifo(1 downto 0),
		--			fifoemptyinA   => fifo(3 downto 2),
		--			fifoemptyinB   => fifo(5 downto 4),
		--			registerRead   => ltm9007_14_0r,
		--			registerWrite  => ltm9007_14_0w
		--		);
		--
		--	x16b : entity work.drs4adc
		--		port map(
		--			address        => open,
		--			notReset0      => open,
		--			denable0       => open,
		--			dwrite0        => open,
		--			rsrload0       => open,
		--			miso0          => i_radio_drs4_srout(1),
		--			mosi0          => open,
		--			srclk0         => open,
		--			dtap0          => i_radio_drs4_dtap(1),
		--			plllck0        => i_radio_drs4_plllock(1),
		--			deadTime       => open,
		--			trigger        => triggerDRS4,
		--			internalTiming => internalTiming,
		--			adcClocks      => adcClocks,
		--			drs4_0r        => drs4_1r,
		--			drs4_0w        => drs4_0w,
		--			nCSA0          => open,
		--			nCSB0          => open,
		--			mosi           => open,
		--			sclk           => open,
		--			enc0           => open,
		--			adcDataA_p0    => i_radio_adc_data_p(1),
		--			adcDataA_n0    => i_radio_adc_data_n(1),
		--			drs4AndAdcData => drs4AndAdcData(1),
		--			ChannelID      => "01",
		--			fifoemptyout   => fifo(3 downto 2),
		--			fifoemptyinA   => fifo(1 downto 0),
		--			fifoemptyinB   => fifo(5 downto 4),
		--			registerRead   => ltm9007_14_1r,
		--			registerWrite  => ltm9007_14_0w
		--		);
		--
		--	x16c : entity work.drs4adc
		--		port map(
		--			address        => open,
		--			notReset0      => open,
		--			denable0       => open,
		--			dwrite0        => open,
		--			rsrload0       => open,
		--			miso0          => i_radio_drs4_srout(2),
		--			mosi0          => open,
		--			srclk0         => open,
		--			dtap0          => i_radio_drs4_dtap(2),
		--			plllck0        => i_radio_drs4_plllock(2),
		--			deadTime       => open,
		--			trigger        => triggerDRS4,
		--			internalTiming => internalTiming,
		--			adcClocks      => adcClocks,
		--			drs4_0r        => drs4_2r,
		--			drs4_0w        => drs4_0w,
		--			nCSA0          => open,
		--			nCSB0          => open,
		--			mosi           => open,
		--			sclk           => open,
		--			enc0           => open,
		--			adcDataA_p0    => i_radio_adc_data_p(2),
		--			adcDataA_n0    => i_radio_adc_data_n(2),
		--			drs4AndAdcData => drs4AndAdcData(2),
		--			ChannelID      => "10",
		--			fifoemptyout   => fifo(5 downto 4),
		--			fifoemptyinA   => fifo(3 downto 2),
		--			fifoemptyinB   => fifo(1 downto 0),
		--			registerRead   => ltm9007_14_2r,
		--			registerWrite  => ltm9007_14_0w
		--		);
		--
		--	x13 : entity work.dac088s085_x3
		--		port map(
		--			notSync       => o_radio_dac_syncn,
		--			mosi          => o_radio_dac_do,
		--			sclk          => o_radio_dac_sck,
		--			registerRead  => dac088s085_x3_0r,
		--			registerWrite => dac088s085_x3_0w
		--		);
		--
		--	x15 : entity work.ad56x1
		--		port map(
		--			notSync0      => o_vcxo_25_syncn,
		--			notSync1      => o_vcxo_10_syncn,
		--			mosi          => o_vcxo_25_do,
		--			sclk          => o_vcxo_25_sck,
		--			registerRead  => ad56x1_0r,
		--			registerWrite => ad56x1_0w
		--		);
		--
		--	x18 : entity work.iceTad
		--		port map(
		--			nP24VOn           => o_panel_24v_on_n,
		--			nP24VOnTristate   => o_panel_24v_tri,
		--			rs485In           => i_panel_rs485_in,
		--			rs485Out          => o_panel_rs485_out,
		--			rs485DataTristate => open,
		--			rs485DataEnable   => o_panel_rs485_en,
		--			registerRead      => iceTad_0r,
		--			registerWrite     => iceTad_0w
		--		);
		--
		--	x19 : entity work.panelPower
		--		port map(
		--			nPowerOn      => o_radio_power24n,
		--			registerRead  => panelPower_0r,
		--			registerWrite => panelPower_0w
		--		);
		--
		--	x20 : entity work.tmp05
		--		port map(
		--			tmp05Pin      => io_pin_tmp05,
		--			registerRead  => tmp05_0r,
		--			registerWrite => tmp05_0w
		--		);
		--
		--	---  Read fast aller daten von Kanal 0 
		--	ltm9007_14r.testMode                   <= ltm9007_14_0r.testMode;
		--	ltm9007_14r.testPattern                <= ltm9007_14_0r.testPattern;
		--	ltm9007_14r.bitslipPattern             <= ltm9007_14_0r.bitslipPattern;
		--	ltm9007_14r.bitslipFailed              <= ltm9007_14_0r.bitslipFailed or ltm9007_14_1r.bitslipFailed or ltm9007_14_2r.bitslipFailed; -- alle 3 Kan�le verodert...
		--	ltm9007_14r.offsetCorrectionRamAddress <= ltm9007_14_0r.offsetCorrectionRamAddress;
		--	ltm9007_14r.offsetCorrectionRamData    <= ltm9007_14_0r.offsetCorrectionRamData;
		--	ltm9007_14r.offsetCorrectionRamWrite   <= ltm9007_14_0r.offsetCorrectionRamWrite;
		--	ltm9007_14r.fifoEmptyA                 <= ltm9007_14_0r.fifoEmptyA;
		--	ltm9007_14r.fifoValidA                 <= ltm9007_14_0r.fifoValidA;
		--	ltm9007_14r.fifoWordsA                 <= ltm9007_14_0r.fifoWordsA;
		--	ltm9007_14r.baselineStart              <= ltm9007_14_0r.baselineStart;
		--	ltm9007_14r.baselineEnd                <= ltm9007_14_0r.baselineEnd;
		--	ltm9007_14r.debugChannelSelector       <= ltm9007_14_0r.debugChannelSelector;
		--	ltm9007_14r.debugFifoControl           <= ltm9007_14_0r.debugFifoControl;
		--	ltm9007_14r.testMode                   <= ltm9007_14_0r.testMode;
		--	ltm9007_14r.debugFifoOut               <= ltm9007_14_0r.debugFifoOut;
		--
		--	x3 : entity work.registerInterface_iceScint
		--		port map(
		--			addressAndControlBus       => addressAndControlBus,
		--			dataBusIn                  => i_ebi_data_in,
		--			dataBusOut                 => o_ebi_data_out,
		--			triggerTimeToRisingEdge_0r => triggerTimeToRisingEdge_0r,
		--			triggerTimeToRisingEdge_0w => triggerTimeToRisingEdge_0w,
		--			eventFifoSystem_0r         => eventFifoSystem_0r,
		--			eventFifoSystem_0w         => eventFifoSystem_0w,
		--			triggerDataDelay_0r        => triggerDataDelay_0r,
		--			triggerDataDelay_0w        => triggerDataDelay_0w,
		--			triggerDataDelay_1r        => triggerDataDelay_1r,
		--			triggerDataDelay_1w        => triggerDataDelay_1w,
		--			pixelRateCounter_0r_p0     => pixelRateCounter_0r,
		--			pixelRateCounter_0w        => pixelRateCounter_0w,
		--			dac088s085_x3_0r           => dac088s085_x3_0r,
		--			dac088s085_x3_0w           => dac088s085_x3_0w,
		--			gpsTiming_0r               => gpsTiming_0r,
		--			gpsTiming_0w               => gpsTiming_0w,
		--			whiteRabbitTiming_0r       => whiteRabbitTiming_0r,
		--			whiteRabbitTiming_0w       => whiteRabbitTiming_0w,
		--			internalTiming_0r          => internalTiming_0r,
		--			internalTiming_0w          => internalTiming_0w,
		--			ad56x1_0r                  => ad56x1_0r,
		--			ad56x1_0w                  => ad56x1_0w,
		--			drs4_0r                    => drs4_0r,
		--			drs4_0w                    => drs4_0w,
		--			ltm9007_14_0r              => ltm9007_14r,
		--			ltm9007_14_0w              => ltm9007_14_0w,
		--			triggerLogic_0r_p          => triggerLogic_0r,
		--			triggerLogic_0w            => triggerLogic_0w,
		--			iceTad_0r                  => iceTad_0r,
		--			iceTad_0w                  => iceTad_0w,
		--			panelPower_0r              => panelPower_0r,
		--			panelPower_0w              => panelPower_0w,
		--			tmp05_0r                   => tmp05_0r,
		--			tmp05_0w                   => tmp05_0w,
		--			i2c_control_r              => i2c_control_r,
		--			i2c_control_w              => i2c_control_w,
		--			clockConfig_debug_0w       => clockConfig_debug
		--		);
		--
		--	Inst_I2CModule : entity work.I2CModule
		--		port map(
		--			clk           => triggerSerdesClocks.clk_118_serdes_div8,
		--			scl           => o_scl,
		--			sdaout        => o_sda_out,
		--			sdaint        => i_sda_in,
		--			registerRead  => i2c_control_r,
		--			registerWrite => i2c_control_w
		--		);
end behaviour;

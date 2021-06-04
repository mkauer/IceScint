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
		EBI_SIGNAL_INVERT : boolean := true;
		NUM_RADIO         : natural := 3;
		NUM_UDAQ          : natural := 8
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
		o_timing_signal       : out   std_logic                           := '0';
		ignore                : out   bit                                 := '0' -- because VDHL does not allow trailing commas
	);
end icescint;

architecture behaviour of icescint is
	attribute keep : string;

	signal clk_10m_selected : std_logic;
	signal dcm_clk          : std_logic;
	signal dcm_locked       : std_logic;
	signal pll_reset        : std_logic;

	constant SYS_CLOCK_PERIOD : time := 10.0 ns;
	signal sys_clk            : std_logic;
	signal sys_rst_input      : std_logic;
	signal sys_rst            : std_logic;
	signal sys_pll_feedback   : std_logic;
	signal sys_pll_locked     : std_logic;

	constant ADC_CLOCK_PERIOD : time := 33.33333 ns;
	signal adc_clk            : std_logic;
	signal adc_clk_serdes     : std_logic;
	signal adc_refclk         : std_logic;
	signal adc_rst            : std_logic;

	signal irigb_sync : std_logic;
	signal irigb_pps  : std_logic;

	-- registers
	signal sys_reg_reading : std_logic;
	signal sys_reg_read    : std_logic;
	signal sys_reg_write   : std_logic;
	signal sys_reg_addr    : std_logic_vector(i_ebi_address'range);
	signal sys_reg_data    : std_logic_vector(i_ebi_data_in'range);

	signal user2regs : user2regs_t;
	signal regs2user : regs2user_t;

	component irig is
		port(
			clk_10mhz  : in  std_logic;
			rst        : in  std_logic;
			irigb      : in  std_logic;
			pps        : out std_logic;
			ts_second  : out std_logic_vector(5 downto 0);
			ts_minute  : out std_logic_vector(5 downto 0);
			ts_hour    : out std_logic_vector(4 downto 0);
			ts_day     : out std_logic_vector(8 downto 0);
			ts_year    : out std_logic_vector(6 downto 0);
			ts_sec_day : out std_logic_vector(16 downto 0)
		);
	end component;

	----------------------------------------------------------------------------
	-- LEGACY BELOW
	----------------------------------------------------------------------------

	signal addressAndControlBus : std_logic_vector(31 downto 0);

	--	signal eventFifoSystem_0r   : eventFifoSystem_registerRead_t;
	--	signal eventFifoSystem_0w   : eventFifoSystem_registerWrite_t;
	--	signal dac088s085_x3_0r     : dac088s085_x3_registerRead_t;
	--	signal dac088s085_x3_0w     : dac088s085_x3_registerWrite_t;
	--	signal internalTiming_0r    : internalTiming_registerRead_t;
	--	signal internalTiming_0w    : internalTiming_registerWrite_t;
	--	signal whiteRabbitTiming_0r : whiteRabbitTiming_registerRead_t;
	--	signal whiteRabbitTiming_0w : whiteRabbitTiming_registerWrite_t;
	--	signal ad56x1_0r            : ad56x1_registerRead_t;
	--	signal ad56x1_0w            : ad56x1_registerWrite_t;
	--	signal drs4_0r              : drs4_registerRead_t;
	--	signal drs4_0w              : drs4_registerWrite_t;
	--	signal drs4_1r              : drs4_registerRead_t;
	--	signal drs4_1w              : drs4_registerWrite_t;
	--	signal drs4_2r              : drs4_registerRead_t;
	--	signal drs4_2w              : drs4_registerWrite_t;
	--	signal ltm9007_14r          : ltm9007_14_registerRead_t;
	--	signal ltm9007_14_0r        : ltm9007_14_registerRead_t;
	--	signal ltm9007_14_0w        : ltm9007_14_registerWrite_t;
	--	signal ltm9007_14_1r        : ltm9007_14_registerRead_t;
	--	signal ltm9007_14_1w        : ltm9007_14_registerWrite_t;
	--	signal ltm9007_14_2r        : ltm9007_14_registerRead_t;
	--	signal ltm9007_14_2w        : ltm9007_14_registerWrite_t;
	--	signal triggerLogic_0r      : triggerLogic_registerRead_t;
	--	signal triggerLogic_0w      : triggerLogic_registerWrite_t;
	--	signal iceTad_0r            : iceTad_registerRead_t;
	--	signal iceTad_0w            : iceTad_registerWrite_t;
	--	signal panelPower_0r        : panelPower_registerRead_t;
	--	signal panelPower_0w        : panelPower_registerWrite_t;
	--	signal tmp05_0r             : tmp05_registerRead_t;
	--	signal tmp05_0w             : tmp05_registerWrite_t;
	--	signal i2c_control_r        : i2c_registerRead_t;
	--	signal i2c_control_w        : i2c_registerWrite_t;
	--	signal triggerSerdesClocks  : triggerSerdesClocks_t;
	--	signal triggerTiming        : triggerTiming_t;
	--	signal adcData              : ltm9007_14_to_eventFifoSystem_old_t;
	--	signal adcData2             : ltm9007_14_to_eventFifoSystem_old_t;
	--	signal adcData3             : ltm9007_14_to_eventFifoSystem_old_t;
	--	signal internalTiming       : internalTiming_t;
	--	signal whiteRabbitTiming    : whiteRabbitTiming_t;
	--	signal adcFifo              : adcFifo_t;
	--	signal adcClocks            : adcClocks_t;
	--	signal trigger              : triggerLogic_t;
	--	signal triggerDRS4          : std_logic;
	--	signal pixelRates           : pixelRateCounter_t;
	--	signal clockConfig_debug    : clockConfig_debug_t;

	--	signal fifo : std_logic_vector(5 downto 0);
	--
	--	constant numberOfDsr : integer := 3;
	--	type drsChannel_t is array (0 to numberOfDsr - 1) of std_logic_vector(7 downto 0);
	--	signal discriminator : drsChannel_t;
	--
	--	signal deadTime           : std_logic;
	--	signal rateCounterTimeOut : std_logic;
	--
	--	signal edgeData      : std_logic_vector(8 * 16 - 1 downto 0);
	--	signal edgeDataReady : std_logic;

	--	signal drs4AndAdcData          : drs4AndAdcData_vector_t;
	--	signal drs4_to_eventFifoSystem : drs4_to_eventFifoSystem_t;
begin

	----------------------------------------------------------------------------
	-- Clock Selection and Synthesis
	----------------------------------------------------------------------------

	user2regs.sys_clock_source <= i_clk_10m_sel;

	-- select between external clocks
	p_clock_sel : process(i_clk_10m_0, i_clk_10m_1, i_clk_10m_sel)
	begin
		if i_clk_10m_sel = '1' then
			clk_10m_selected <= i_clk_10m_1;
		else
			clk_10m_selected <= i_clk_10m_0;
		end if;
	end process;

	-- convert 10 MHz input clock to 50 MHz for PLL (19 MHz minimum input frequency)
	dcm_1 : DCM_CLKGEN
		generic map(
			CLKFX_MD_MAX   => 5.0,
			CLKFX_MULTIPLY => 5,
			CLKIN_PERIOD   => 100.0
		)
		port map(
			CLKFX     => dcm_clk,
			CLKIN     => clk_10m_selected,
			FREEZEDCM => '0',
			PROGCLK   => '0',
			PROGDATA  => '0',
			PROGEN    => '0',
			LOCKED    => dcm_locked,
			RST       => i_rst_ext
		);

	pll_reset <= not dcm_locked or i_rst_ext;

	pll_sys : PLL_BASE
		generic map(
			CLKFBOUT_MULT  => 10,       -- VCO: 500 MHz
			CLKFBOUT_PHASE => 0.0,
			CLKIN_PERIOD   => 20.0,
			CLKOUT0_DIVIDE => 4,        -- 125 MHz system clock (100 MHz is too slow for registers)
			CLKOUT1_DIVIDE => 7,        -- 70 MHz ADC data clock
			CLKOUT2_DIVIDE => 1,        -- 500 MHz ADC SERDES clock
			CLKOUT3_DIVIDE => 14,       -- 35 MHz ADC reference clock
			CLKOUT4_DIVIDE => 1,        -- NOT USED
			CLKOUT5_DIVIDE => 1,        -- NOT USED
			CLK_FEEDBACK   => "CLKFBOUT",
			COMPENSATION   => "SYSTEM_SYNCHRONOUS",
			DIVCLK_DIVIDE  => 1
		)
		port map(
			CLKFBOUT => sys_pll_feedback,
			CLKOUT0  => sys_clk,
			CLKOUT1  => adc_clk,
			CLKOUT2  => adc_clk_serdes,
			CLKOUT3  => adc_refclk,
			CLKOUT4  => open,
			CLKOUT5  => open,
			LOCKED   => sys_pll_locked,
			CLKFBIN  => sys_pll_feedback,
			CLKIN    => dcm_clk,
			RST      => pll_reset
		);

	sys_rst_input <= i_rst_ext or (not sys_pll_locked) or (not dcm_locked);

	sys_rst_sync : entity work.reset_synchronizer
		generic map(
			G_RELEASE_DELAY_CYCLES => 5
		)
		port map(
			i_reset => sys_rst_input,
			i_clk   => sys_clk,
			o_reset => sys_rst
		);

	----------------------------------------------------------------------------
	-- uDAQs
	----------------------------------------------------------------------------

	--	gen_udaq_tx : for i in 0 to NUM_UDAQ - 1 generate
	--		signal uart : std_logic;
	--	begin
	--		udaq_rs485 : entity work.udaq_rs485
	--			generic map(
	--				G_CLK_FREQ  => 100000000,
	--				G_BAUD_RATE => 30000000
	--			)
	--			port map(
	--				i_clk         => sys_clk,
	--				i_rst         => sys_rst,
	--				i_tx_data     => regs2user.udaq_tx_data,
	--				i_tx_valid    => regs2user.udaq_tx_valid(i),
	--				o_tx_ready    => user2regs.udaq_tx_ready(i),
	--				o_rx_data     => user2regs.udaq_rx_data(i),
	--				o_rx_valid    => user2regs.udaq_rx_valid(i),
	--				i_rx_ready    => regs2user.udaq_rx_ready(i),
	--				o_rx_overflow => user2regs.udaq_rx_overflow(i),
	--				i_loopback_en => regs2user.udaq_loopback(i),
	--				o_rs485_tx    => uart,
	--				o_rs485_en    => o_panel_rs485_en(i),
	--				i_rs485_rx    => uart
	--				--				o_rs485_tx    => o_panel_rs485_out(i),
	--				--				o_rs485_en    => o_panel_rs485_en(i),
	--				--				i_rs485_rx    => i_panel_rs485_in(i)
	--			);
	--	end generate;

	----------------------------------------------------------------------------
	-- IRIG-B timing
	----------------------------------------------------------------------------

	irig_sync : entity work.synchronizer
		generic map(
			G_INIT_VALUE    => '0',
			G_NUM_GUARD_FFS => 2
		)
		port map(
			i_reset => sys_rst,
			i_clk   => sys_clk,
			i_data  => i_wr_pps,
			o_data  => irigb_sync
		);

	irig_decoder : irig
		port map(
			clk_10mhz  => sys_clk,
			rst        => sys_rst,
			irigb      => irigb_sync,
			pps        => irigb_pps,
			ts_sec_day => user2regs.irigb_sec_of_day
		);

	timing_gen : entity work.timing_gen
		port map(
			i_clk     => sys_clk,
			i_rst     => sys_rst,
			i_pps     => irigb_pps,
			i_sec_day => user2regs.irigb_sec_of_day,
			o_timing  => o_timing_signal
		);

	----------------------------------------------------------------------------
	-- Register Interface
	----------------------------------------------------------------------------

	register_sync : entity work.register_sync
		generic map(
			G_INVERT_RWCS => EBI_SIGNAL_INVERT,
			G_DATA_WIDTH  => 16,
			G_ADDR_WIDTH  => 16,
			G_GUARD_FFS   => 1
		)
		port map(
			i_clk       => sys_clk,
			i_rst       => sys_rst,
			i_ebi_read  => i_ebi_read,
			i_ebi_write => i_ebi_write,
			i_ebi_cs    => i_ebi_select,
			i_ebi_addr  => i_ebi_address,
			i_ebi_data  => i_ebi_data_in,
			o_reading   => sys_reg_reading,
			o_read      => sys_reg_read,
			o_write     => sys_reg_write,
			o_addr      => sys_reg_addr,
			o_data      => sys_reg_data
		);

	registers : entity work.registers_icescint
		port map(
			i_clk       => sys_clk,
			i_rst       => sys_rst,
			i_reading   => sys_reg_reading,
			i_read      => sys_reg_read,
			i_write     => sys_reg_write,
			i_ebi_addr  => sys_reg_addr,
			i_ebi_data  => sys_reg_data,
			o_ebi_data  => o_ebi_data_out,
			i_user2regs => user2regs,
			o_regs2user => regs2user
		);
end behaviour;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;
use work.types_platformSpecific.all;

library unisim;
use unisim.vcomponents.all;

entity icescint_io is
	port (
		I_PON_RESETn : in std_logic; -- 2.5V CMOS with pullup, reset (active low, by power monitor LTC2903-A1)
		-- 200 ms after all power lines are settled, might be useless due to race condition
		-- with FPGA configuration time

		-- all oscillators use 2.5V CMOS I/O
		I_QOSC1_OUT       : in std_logic; -- NOT USED
		O_QOSC1_DAC_SYNCn : out std_logic;

		I_QOSC2_OUT       : in std_logic;
		O_QOSC2_ENA       : out std_logic; -- NOT USED, QOSC2 does not have enable input
		O_QOSC2_DAC_SYNCn : out std_logic;
		O_QOSC2_DAC_SCKL  : out std_logic;
		O_QOSC2_DAC_SDIN  : out std_logic;

		-- EXT_CLK used for white rabbit
		I_EXT_CLK_P      : in std_logic;  -- LVDS
		I_EXT_CLK_N      : in std_logic;  -- LVDS
		I_EXT_PPS_P      : in std_logic;  -- LVDS
		I_EXT_PPS_N      : in std_logic;  -- LVDS

		I_EXT_TRIG_IN_P  : in std_logic;  -- LVDS
		I_EXT_TRIG_IN_N  : in std_logic;  -- LVDS
		O_EXT_TRIG_OUT_P : out std_logic; -- LVDS
		O_EXT_TRIG_OUT_N : out std_logic; -- LVDS

		-- scintillation panel interface (uDAQs)
		I_PANEL_TRIGGER : in std_logic_vector(7 downto 0);
		I_PANEL_RS485_RX : in std_logic_vector(7 downto 0);
		O_PANEL_RS485_TX : out std_logic_vector(7 downto 0);
		O_PANEL_RS485_DE : out std_logic_vector(7 downto 0);
		O_PANEL_NP24V_ON : out std_logic_vector(7 downto 0);

		-- trigger to be used by the AERA board
		O_AERA_TRIG_P : out std_logic; -- LVDS
		O_AERA_TRIG_N : out std_logic; -- LVDS

		-- ADC #1..3, LTM9007-14, 8 channel, ser out, 40 MSPS max., LVDS outputs
		-- the direction used for the pins is (0 to 7) but will be assigned to a (7 downto 0)
		-- we do this to compensate the non logical order in the pcb
		I_ADC_OUTA_1P : in std_logic_vector(0 to 7); -- LVDS, iserdes inputs
		I_ADC_OUTA_1N : in std_logic_vector(0 to 7);
		I_ADC_OUTA_2P : in std_logic_vector(0 to 7); -- LVDS, iserdes inputs
		I_ADC_OUTA_2N : in std_logic_vector(0 to 7);
		I_ADC_OUTA_3P : in std_logic_vector(0 to 7); -- LVDS, iserdes inputs
		I_ADC_OUTA_3N : in std_logic_vector(0 to 7);

		I_ADC_FRA_P    : in std_logic_vector(1 to 3); -- Frame Start for Channels 1, 4, 5 and 8
		I_ADC_FRA_N    : in std_logic_vector(1 to 3);
		I_ADC_FRB_P    : in std_logic_vector(1 to 3); -- Frame Start for Channels 2, 3, 6 and 7
		I_ADC_FRB_N    : in std_logic_vector(1 to 3);
		I_ADC_DCOA_P   : in std_logic_vector(1 to 3);-- Data Clock for Channels 1, 4, 5 and 8
		I_ADC_DCOA_N   : in std_logic_vector(1 to 3);
		I_ADC_DCOB_P   : in std_logic_vector(1 to 3);-- Data Clock for Channels 2, 3, 6 and 7
		I_ADC_DCOB_N   : in std_logic_vector(1 to 3);
		O_ADC_ENC_P    : out std_logic_vector(1 to 3); -- LVDS, conversion clock, conversion starts at rising edge
		O_ADC_ENC_N    : out std_logic_vector(1 to 3);
		O_ADC_PAR_SERn : out std_logic;                -- Incorrect signal removed completely from design. This Should be tied to ground.
		O_ADC_SDI      : out std_logic;                -- shared serial interface data input
		O_ADC_SCK      : out std_logic;                -- shared serial interface clock input
		O_ADC_CSA      : out std_logic_vector(1 to 3); -- serial interfacechip select, channels 1, 4, 5 and 8
		O_ADC_CSB      : out std_logic_vector(1 to 3); -- serial interfacechip select, channels 2, 3, 6 and 7

		-- NOT USED --
		-- ADC LTC2173-14, 4 channel, ser out, 80 MSPS max., LVDS outputs
		I_ADC_OUTA_4P : in std_logic_vector(0 to 3); -- LVDS, oserdes data outputs
		I_ADC_OUTA_4N : in std_logic_vector(0 to 3);
		I_ADC_FR_4P   : in std_logic;
		I_ADC_FR_4N   : in std_logic;
		I_ADC_DCO_4P  : in std_logic; -- Data Clock Outputs
		I_ADC_DCO_4N  : in std_logic;
		I_ADC_SDO_4   : in std_logic;  -- serial interface data readback output
		O_ADC_ENC_4P  : out std_logic; -- LVDS, conversion clock, conversion starts at rising edge
		O_ADC_ENC_4N  : out std_logic;
		O_ADC_CS_4    : out std_logic; -- serial interfacechip select

		-- Stamp9G45 1.8V signals
		I_EBI1_ADDR  : in std_logic_vector(20 downto 0);    -- up to 21 memory bus address signals
		IO_EBI1_D    : inout std_logic_vector(15 downto 0); -- memory bus data signals
		I_EBI1_NWE   : in std_logic;                        --EBI1_NWE/NWR0/CFWE, low active write strobe
		I_EBI1_NCS2  : in std_logic;                        --PC13/NCS2,             address (hex) 3000 0000, low active Chip Select 2
		I_EBI1_NRD   : in std_logic;                        --EBI1_NRD/CFOE, low active read strobe
		I_EBI1_MCK   : in std_logic; -- NOT USED            --PB31/ISI_MCK/PCK1, might be used as clock
		O_EBI1_NWAIT : out std_logic;                       --PC15/NWAIT, low active
		-- Stamp9G45 3.3V signals
		O_PC1_ARM_IRQ0 : out std_logic;   -- PIO port PC1, used as edge (both) triggered interrupt signal
		IO_ADDR_64BIT  : inout std_logic; -- NOT USED -- one wire serial EPROM DS2431P

		-- DRS4 (Domino Ring Sampler) chips #1..3
		I_DRS4_SROUT : in std_logic_vector(1 to 3); -- Multiplexed Shift Register Output
		I_DRS4_DTAP   : in std_logic_vector(1 to 3); -- Domino Tap Signal Output toggling on each domino revolution
		I_DRS4_PLLLCK : in std_logic_vector(1 to 3); -- PLL Lock Indicator Output
		O_DRS4_RESETn : out std_logic_vector(1 to 3);     -- external Reset, leave open when using internal ..
		O_DRS4_A      : out std_logic_vector(3 downto 0); -- shared address bits
		O_DRS4_SRIN   : out std_logic_vector(1 to 3);     -- Shared Shift Register Input
		O_DRS4_SRCLK  : out std_logic_vector(1 to 3);     -- Multiplexed Shift Register Clock Input
		O_DRS4_RSLOAD : out std_logic_vector(1 to 3);     -- Read Shift Register Load Input
		O_DRS4_DWRITE : out std_logic_vector(1 to 3);     -- Domino Write Input. Connects the Domino Wave Circuit to the
		O_DRS4_DENABLE : out std_logic_vector(1 to 3); -- Domino Enable Input. A low-to-high transition starts the Domino
		O_DRS4_REFCLK_P : out std_logic_vector(1 to 3); -- Reference Clock Input LVDS (+)
		O_DRS4_REFCLK_N : out std_logic_vector(1 to 3); -- Reference Clock Input LVDS (-)

		-- serial DAC to set the Discriminator thresholds
		O_DAC_DIN   : out std_logic_vector(1 to 3); -- 2.5V CMOS, serial DAC (discr. threshold)
		O_DAC_SCLK  : out std_logic_vector(1 to 3); -- 2.5V CMOS
		O_DAC_SYNCn : out std_logic_vector(1 to 3); -- 2.5V CMOS, low active

		-- paddle #1..3 control
		IO_I2C_CLK     : inout std_logic_vector(1 to 3); -- NOT USED -- I2C clock
		IO_I2C_DATA    : inout std_logic_vector(1 to 3); -- NOT USED -- SN65HVD1782D, bidirectional data
		I_CBL_PLGDn   : in std_logic_vector(1 to 3);        -- cable plugged, low active, needs pullup activated
		O_PON_PADDLEn : out std_logic_vector(1 to 3);       -- Paddle power on signal
		O_POW_SW_SCL  : out std_logic;                      -- paddle power switch monitoring ADC control
		O_POW_SW_SDA  : out std_logic;                      -- paddle power switch monitoring ADC control
		I_POW_ALERT   : in std_logic;                       -- ADC AD7997 open drain output, needs pullup,

		-- RS232 / RS485 ports, BOTH NOT USED
		O_RS232_TXD : out std_logic; -- 3.3V CMOS
		I_RS232_RXD : in std_logic;  -- 3.3V CMOS

		O_RS485_PV  : out std_logic; -- 3.3V CMOS power valid
		O_RS485_DE  : out std_logic; -- 3.3V CMOS
		O_RS485_REn : out std_logic; -- 3.3V CMOS
		O_RS485_TXD : out std_logic; -- 3.3V CMOS
		I_RS485_RXD : in std_logic;  -- 3.3V CMOS

		-- GPS module LEA-6T ?? check wether this is really 3.3V ..
		O_GPS_RESET_N    : out std_logic; -- 3.3V CMOS, GPS-module reset
		O_GPS_EXTINT0    : out std_logic; -- 3.3V CMOS, interrupt signal for time stamping an event
		I_GPS_TIMEPULSE  : in std_logic;  -- 3.3V CMOS, typical used as PPS pulse
		I_GPS_TIMEPULSE2 : in std_logic;  -- 3.3V CMOS, configurable, clock from 0.25 Hz to 10 MHz
		O_GPS_RXD1       : out std_logic; -- 3.3V CMOS,
		I_GPS_TXD1       : in std_logic;  -- 3.3V CMOS,

		-- test signals DACs
		IO_TEST_DAC_SCL : inout std_logic;              -- 2.5V CMOS, DAC for test pulse (chain saw) generation
		IO_TEST_DAC_SDA : inout std_logic;              -- 2.5V CMOS,
		O_TEST_GATE    : out std_logic_vector(1 to 3); -- 2.5V CMOS, to discharge the capacitor used for the chain saw signal
		O_TEST_PDn     : out std_logic;                -- 2.5V CMOS, to power down the test circuitry

		IO_TEMPERATURE : inout std_logic; -- bidir, tmp05 sensor

		IO_sda : inout std_logic;
		IO_scl : inout std_logic;
		-- test signals, NOT AVAILABLE for XC6SLX100FGG484-2 !!!
		IO_LVDS_IO_P : inout std_logic_vector(5 downto 0); -- LVDS bidir. test port
		IO_LVDS_IO_N : inout std_logic_vector(5 downto 0); -- LVDS bidir. test port
		O_NOT_USED_GND : out std_logic_vector(3 downto 0)
	);
end icescint_io;

architecture behaviour of icescint_io is
	attribute keep : string;

	signal radio_drs4_resetn   : std_logic;
	signal radio_drs4_refclock : std_logic;
	signal radio_drs4_plllock  : std_logic_vector(0 to 2);
	signal radio_drs4_denable  : std_logic;
	signal radio_drs4_dwrite   : std_logic;
	signal radio_drs4_rsrload  : std_logic;
	signal radio_drs4_address  : std_logic_vector(3 downto 0);
	signal radio_drs4_dtap     : std_logic_vector(0 to 2);
	signal radio_drs4_srout    : std_logic_vector(0 to 2);
	signal radio_drs4_srin     : std_logic;
	signal radio_drs4_srclk    : std_logic;
	signal radio_adc_data_p    : slv8_array_t(0 to 2);
	signal radio_adc_data_n    : slv8_array_t(0 to 2);
	signal radio_adc_csan      : std_logic;
	signal radio_adc_csbn      : std_logic;
	signal radio_adc_sdi       : std_logic;
	signal radio_adc_sck       : std_logic;
	signal radio_adc_refclk    : std_logic;
	signal radio_dac_syncn     : std_logic;
	signal radio_dac_do        : std_logic;
	signal radio_dac_sck       : std_logic;
	signal radio_power24n      : std_logic;

	signal ebi_address  : std_logic_vector(23 downto 0);
	signal ebi_data_in  : std_logic_vector(15 downto 0);
	signal ebi_data_out : std_logic_vector(15 downto 0);
	signal ebi_read  : std_logic;
	signal ebi_write : std_logic;
	signal ebi_select : std_logic;

	signal panel_24v_on_n  : std_logic_vector(0 to 7);
	signal panel_24v_tri : std_logic_vector(0 to 7);

	signal sclint : std_logic;
	signal sdaout : std_logic;
	signal sdaint : std_logic;

	signal wr_clock : std_logic;
	signal wr_pps : std_logic;
begin
	----------------------------------------------------------------------------
	-- IO buffers
	----------------------------------------------------------------------------

	-- RADIO
	O_DRS4_A <= radio_drs4_address;
	radio_adc_data_p(0) <= I_ADC_OUTA_1P;
	radio_adc_data_n(0) <= I_ADC_OUTA_1N;
	radio_adc_data_p(1) <= I_ADC_OUTA_2P;
	radio_adc_data_n(1) <= I_ADC_OUTA_2N;
	radio_adc_data_p(2) <= I_ADC_OUTA_3P;
	radio_adc_data_n(2) <= I_ADC_OUTA_3N;
	O_ADC_SDI <= radio_adc_sdi;
	O_ADC_SCK <= radio_adc_sck;
	gen_radio : for i in 1 to 3 generate
		-- one to many
		O_DRS4_RESETn(i)  <= radio_drs4_resetn;
		O_DRS4_DENABLE(i) <= radio_drs4_denable;
		O_DRS4_DWRITE(i)  <= radio_drs4_dwrite;
		O_DRS4_RSLOAD(i)  <= radio_drs4_rsrload;
		O_DRS4_SRIN(i)    <= radio_drs4_srin;
		O_DRS4_SRCLK(i)   <= radio_drs4_srclk;
		O_ADC_CSA(i)      <= radio_adc_csan;
		O_ADC_CSB(i)      <= radio_adc_csbn;
		O_DAC_SYNCn(i)    <= radio_dac_syncn;
		O_DAC_DIN(i)      <= radio_dac_do;
		O_DAC_SCLK(i)     <= radio_dac_sck;
		O_PON_PADDLEn(i)  <= radio_power24n;

		obuf_drs4_refclock : OBUFDS port map(
			O => O_DRS4_REFCLK_P(i),
			OB => O_DRS4_REFCLK_N(i),
			I => radio_drs4_refclock
		);

		obuf_adc_refclock : OBUFDS port map(
			O => O_ADC_ENC_P(i),
			OB => O_ADC_ENC_N(i),
			I => radio_adc_refclk
		);

		-- remap 1-3 to 0-2
		radio_drs4_dtap(i - 1) <= I_DRS4_DTAP(i);
		radio_drs4_plllock(i - 1) <= I_DRS4_PLLLCK(i);
		radio_drs4_srout(i - 1) <= I_DRS4_SROUT(i);

		-- termination for unused pins
		ibufds_adc_fra : IBUFDS generic map(
			DIFF_TERM => true
		) port map(
			I => I_ADC_FRA_P(i),
			IB => I_ADC_FRA_N(i),
			O => open
		);

		ibufds_adc_frb : IBUFDS generic map(
			DIFF_TERM => true
		) port map(
			I => I_ADC_FRB_P(i),
			IB => I_ADC_FRB_N(i),
			O => open
		);

		ibufds_adc_dcoa : IBUFDS generic map(
			DIFF_TERM => true
		) port map(
			I => I_ADC_DCOA_P(i),
			IB => I_ADC_DCOA_N(i),
			O => open
		);

		ibufds_adc_dcob : IBUFDS generic map(
			DIFF_TERM => true
		) port map(
			I => I_ADC_DCOB_P(i),
			IB => I_ADC_DCOB_N(i),
			O => open
		);
	end generate;

	-- EBI
	ebi_read   <= not I_EBI1_NRD;
	ebi_write  <= not I_EBI1_NWE;
	ebi_select <= not I_EBI1_NCS2;
	ebi_address <= "000" & I_EBI1_ADDR;
	O_EBI1_NWAIT <= '1';
	gen_ebi_data : for i in 0 to 15 generate
		iobuf_inst : IOBUF generic map(
			DRIVE => 2,
			IBUF_DELAY_VALUE => "0",
			IFD_DELAY_VALUE => "AUTO",
			IOSTANDARD => "DEFAULT",
			SLEW => "SLOW"
		)
		port map(
			IO => IO_EBI1_D(i),
			O  => ebi_data_in(i),
			I  => ebi_data_out(i), 
			T  => I_EBI1_NRD
		);
	end generate;

	-- SCINTILLATOR PANELS
	gen_scint_panels : for i in 0 to 7 generate
		obuft_power : OBUFT port map(
			O => O_PANEL_NP24V_ON(i),
			I => panel_24v_on_n(i),
			T => panel_24v_tri(i)
		);
	end generate;

	-- GROUND
	O_NOT_USED_GND <= (others => '0');
	
	-- WHITE RABBIT
	ibufds_wr_clk : IBUFDS generic map(DIFF_TERM => true) port map(
		I => I_EXT_CLK_P,
		IB => I_EXT_CLK_N,
		O => wr_clock
	);
	ibufds_wr_pps : IBUFDS generic map(DIFF_TERM => true) port map(
		I => I_EXT_PPS_P,
		IB => I_EXT_PPS_N,
		O => wr_pps
	);

	-- AUX ADC, unused
	O_ADC_CS_4 <= '1';

	gen_aux_adc : for i in 0 to 3 generate
		ibufds_out_term : IBUFDS generic map(
			DIFF_TERM => true
		) port map(
			I => I_ADC_OUTA_4P(i),
			IB => I_ADC_OUTA_4N(i),
			O => open
		);
	end generate;

	gen_aux_adc_fr : IBUFDS generic map(
		DIFF_TERM => true
	) port map(
		I => I_ADC_FR_4P,
		IB => I_ADC_FR_4N,
		O => open
	);

	gen_aux_adc_dco : IBUFDS generic map(
		DIFF_TERM => true
	) port map(
		I => I_ADC_DCO_4P,
		IB => I_ADC_DCO_4N,
		O => open
	);
	
	obufds_aux_adc_enc : OBUFDS port map(
		O => O_ADC_ENC_4P,
		OB => O_ADC_ENC_4N,
		I => '0'
	);

	-- MISC
	O_QOSC2_ENA    <= '0'; -- QOSC2 has no enable input
	O_ADC_PAR_SERn <= '0'; -- unconnected according to schematic

	ibufds_ext_trig_in : IBUFDS generic map(
		DIFF_TERM => true
	) port map(
		I => I_EXT_TRIG_IN_P,
		IB => I_EXT_TRIG_IN_N,
		O => open
	);

	obufds_ext_trig_out : OBUFDS port map(
		O => O_EXT_TRIG_OUT_P,
		OB => O_EXT_TRIG_OUT_N,
		I => '0'
	);

	obufds_area_trig : OBUFDS port map(
		O => O_AERA_TRIG_P,
		OB => O_AERA_TRIG_N,
		I => '0'
	);

	O_POW_SW_SCL <= '1';
	O_POW_SW_SDA <= '1';

	O_RS232_TXD <= '1';
	O_RS485_PV <= '0';
	O_RS485_DE <= '0';
	O_RS485_REn <= '0';
	O_RS485_TXD <= '0';

	O_GPS_RESET_N <= '1';
	O_GPS_EXTINT0 <= '0';
	O_GPS_RXD1 <= '1';

	O_TEST_GATE <= (others => '0');
	O_TEST_PDn <= '0';

	--	sda <= '0' when sdaout = '0' else 'Z';
	--	sdaint <= sda; 
	--- zweites paralelles i2c Interface:
	--clocks:
	IO_scl          <= sclint;
	IO_test_dac_scl <= sclint;
	--sdaout
	IO_sda <= '0' when sdaout = '0' else
		'Z';
	IO_test_dac_sda <= '0' when sdaout = '0' else
		'Z';
	-- sda in:
	sdaint <= IO_sda and IO_test_dac_sda;

	----------------------------------------------------------------------------
	-- toplevel
	----------------------------------------------------------------------------

	icescint_inst : entity work.icescint port map (
		i_clk_10m => I_QOSC2_OUT,
		i_rst_ext => "not"(I_PON_RESETn),

		o_radio_drs4_resetn   => radio_drs4_resetn,
		o_radio_drs4_refclock => radio_drs4_refclock,
		i_radio_drs4_plllock  => radio_drs4_plllock,
		o_radio_drs4_denable  => radio_drs4_denable,
		o_radio_drs4_dwrite   => radio_drs4_dwrite,
		o_radio_drs4_rsrload  => radio_drs4_rsrload,
		o_radio_drs4_address  => radio_drs4_address,
		i_radio_drs4_dtap     => radio_drs4_dtap,
		i_radio_drs4_srout    => radio_drs4_srout,
		o_radio_drs4_srin     => radio_drs4_srin,
		o_radio_drs4_srclk    => radio_drs4_srclk,
		i_radio_adc_data_p    => radio_adc_data_p,
		i_radio_adc_data_n    => radio_adc_data_n,
		o_radio_adc_csan      => radio_adc_csan,
		o_radio_adc_csbn      => radio_adc_csbn,
		o_radio_adc_sdi       => radio_adc_sdi,
		o_radio_adc_sck       => radio_adc_sck,
		o_radio_adc_refclk    => radio_adc_refclk,
		-- DAC for radio thresholds and offset
		o_radio_dac_syncn => radio_dac_syncn,
		o_radio_dac_do    => radio_dac_do,
		o_radio_dac_sck   => radio_dac_sck,
		o_radio_power24n  => radio_power24n,
		
		i_ebi_select   => ebi_select,
		i_ebi_write    => ebi_write,
		i_ebi_read     => ebi_read,
		i_ebi_address  => ebi_address,
		i_ebi_data_in  => ebi_data_in,
		o_ebi_data_out => ebi_data_out,
		o_ebi_irq      => O_PC1_ARM_IRQ0,

		i_gps_pps     => I_GPS_TIMEPULSE,
		i_gps_uart_in => I_GPS_TXD1,

		i_wr_clock => wr_clock,
		i_wr_pps   => wr_pps,

		i_panel_trigger   => I_PANEL_TRIGGER,
		o_panel_24v_on_n  => panel_24v_on_n,
		o_panel_24v_tri   => panel_24v_tri,
		o_panel_rs485_in  => I_PANEL_RS485_RX,
		o_panel_rs485_out => O_PANEL_RS485_TX,
		o_panel_rs485_en  => O_PANEL_RS485_DE,

		io_pin_tmp05 => IO_TEMPERATURE,

		o_vcxo_25_syncn => O_QOSC1_DAC_SYNCn,
		o_vcxo_10_syncn => O_QOSC2_DAC_SYNCn,
		o_vcxo_25_do    => O_QOSC2_DAC_SDIN,
		o_vcxo_25_sck   => O_QOSC2_DAC_SCKL,

		o_scl     => sclint,
		o_sda_out => sdaout,
		i_sda_in  => sdaint,

		ignore => open
	);
end behaviour;

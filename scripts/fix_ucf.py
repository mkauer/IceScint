#!/usr/bin/python

portstring = '''
		I_PON_RESETn : in std_logic; -- 2.5V CMOS with pullup, reset (active low, by power monitor LTC2903-A1)
		-- 200 ms after all power lines are settled, might be useless due to race condition
		-- with FPGA configuration time

		I_QOSC1_OUT       : in std_logic;  -- 2.5V CMOS, local CMOS clock osc.
		O_QOSC1_DAC_SYNCn : out std_logic; -- 2.5V CMOS, local CMOS clock

		I_QOSC2_OUT       : in std_logic;  -- 2.5V CMOS, local CMOS clock osc.
		O_QOSC2_ENA       : out std_logic; -- 2.5V CMOS, local CMOS clock
		O_QOSC2_DAC_SYNCn : out std_logic; -- 2.5V CMOS,
		O_QOSC2_DAC_SCKL  : out std_logic; -- 2.5V CMOS,
		O_QOSC2_DAC_SDIN  : out std_logic; -- 2.5V CMOS,

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
		I_ADC_DCOA_P   : in std_logic_vector(1 to 3); -- Data Clock for Channels 1, 4, 5 and 8
		I_ADC_DCOA_N   : in std_logic_vector(1 to 3);
		I_ADC_DCOB_P   : in std_logic_vector(1 to 3); -- Data Clock for Channels 2, 3, 6 and 7
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
		I_EBI1_MCK   : in std_logic;                        --PB31/ISI_MCK/PCK1, might be used as clock
		O_EBI1_NWAIT : out std_logic;                       --PC15/NWAIT, low active
		-- Stamp9G45 3.3V signals
		O_PC1_ARM_IRQ0 : out std_logic;   -- PIO port PC1, used as edge (both) triggered interrupt signal
		IO_ADDR_64BIT  : inout std_logic; -- one wire serial EPROM DS2431P

		-- DRS4 (Domino Ring Sampler) chips #1..3, 2.5V CMOS outputs
		I_DRS4_SROUT : in std_logic_vector(1 to 3); -- Multiplexed Shift Register Output
		-- Output if DWRITE=1, Read Shift Register Output if DWRITE=0
		I_DRS4_DTAP   : in std_logic_vector(1 to 3); -- Domino Tap Signal Output toggling on each domino revolution
		I_DRS4_PLLLCK : in std_logic_vector(1 to 3); -- PLL Lock Indicator Output
		-- DRS4 (Domino Ring Sampler) chips #1..3, 2.5V CMOS inputs
		O_DRS4_RESETn : out std_logic_vector(1 to 3);     -- external Reset, leave open when using internal ..
		O_DRS4_A      : out std_logic_vector(3 downto 0); -- shared address bits
		O_DRS4_SRIN   : out std_logic_vector(1 to 3);     -- Shared Shift Register Input
		O_DRS4_SRCLK  : out std_logic_vector(1 to 3);     -- Multiplexed Shift Register Clock Input
		O_DRS4_RSLOAD : out std_logic_vector(1 to 3);     -- Read Shift Register Load Input
		O_DRS4_DWRITE : out std_logic_vector(1 to 3);     -- Domino Write Input. Connects the Domino Wave Circuit to the
		-- Sampling Cells to enable sampling if high
		O_DRS4_DENABLE : out std_logic_vector(1 to 3); -- Domino Enable Input. A low-to-high transition starts the Domino
		-- Wave. Setting this input low stops the Domino Wave
		-- DRS4 clock, LVDS
		O_DRS4_REFCLK_P : out std_logic_vector(1 to 3); -- Reference Clock Input LVDS (+)
		O_DRS4_REFCLK_N : out std_logic_vector(1 to 3); -- Reference Clock Input LVDS (-)

		-- serial DAC to set the Discriminator thresholds
		O_DAC_DIN   : out std_logic_vector(3 downto 1); -- 2.5V CMOS, serial DAC (discr. threshold)
		O_DAC_SCLK  : out std_logic_vector(3 downto 1); -- 2.5V CMOS
		O_DAC_SYNCn : out std_logic_vector(3 downto 1); -- 2.5V CMOS, low active

		-- paddle #1..3 control
		IO_I2C_CLK     : inout std_logic_vector(3 downto 1); -- I2C clock
		IO_I2C_DATA    : inout std_logic_vector(3 downto 1); -- SN65HVD1782D, bidirectional data
		I_CBL_PLGDn   : in std_logic_vector(1 to 3);        -- cable plugged, low active, needs pullup activated
		O_PON_PADDLEn : out std_logic_vector(1 to 3);       -- Paddle power on signal
		O_POW_SW_SCL  : out std_logic;                      -- paddle power switch monitoring ADC control
		O_POW_SW_SDA  : out std_logic;                      -- paddle power switch monitoring ADC control
		I_POW_ALERT   : in std_logic;                       -- ADC AD7997 open drain output, needs pullup,

		-- RS232 / RS485 ports
		O_RS232_TXD : out std_logic; -- 3.3V CMOS
		I_RS232_RXD : in std_logic;  -- 3.3V CMOS

		O_RS485_PV  : out std_logic; -- 3.3V CMOS
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
'''

ports = {}
for line in portstring.splitlines():
    line = line.strip().split('--')[0].strip()
    if not line:
        continue
    port = line.split(':')[0].strip()
    _, name = port.split('_', maxsplit=1)
    ports[name] = port

for line in open('/home/martin/workspaceSigasi/IceScint/ucf/taxi.ucf'):
    line = line.strip()
    if not line.startswith('NET "'):
        print(line)
        continue
    i_end = line.index('"', 5)
    if '<' in line:
        i_end = min(line.index('<'), i_end)
    port = line[5:i_end]
    if not port in ports:
        print(line)
        continue
    line = line[:5] + ports[port] + line[i_end:]
    print(line)

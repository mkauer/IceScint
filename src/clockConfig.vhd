----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:51:16 03/07/2017 
-- Design Name: 
-- Module Name:    iSerdesPll - Behavioral 
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
use IEEE.NUMERIC_STD.all;
use work.types.all;
use work.types_platformSpecific.all;

library UNISIM;
use UNISIM.VComponents.all;

entity clockConfig is
	port (
		i_clk_10m_ext            : in std_logic;
		i_rst_ext          : in std_logic;
		triggerSerdesClocks : out triggerSerdesClocks_t;
		adcClocks           : out adcClocks_t;
		--commClock : out std_logic;
		--commClockReset : out std_logic;
		uv_loggerClocks : out uv_loggerClocks_t;
		clockValid      : out std_logic;
		debug           : in clockConfig_debug_t; -- remove me !!
		drs4RefClock    : out std_logic
	);
end clockConfig;

architecture Behavioral of clockConfig is

	signal clk_10m_ext_buffered : std_logic                    := '0';
	signal dcm1_clko_25   : std_logic                    := '0';
	signal dcm1_locked       : std_logic                    := '0';
	signal dcm1_status       : std_logic_vector(7 downto 0) := x"00";
	signal dcm1_feedback       : std_logic                    := '0';
	signal dcm1Reset        : std_logic                    := '0';
	signal pllFeedBack1     : std_logic                    := '0';
	--signal pllReset1 : std_logic := '0';
	signal pllLocked1                         : std_logic                    := '1';
	signal discriminatorSerdesFastClock       : std_logic                    := '0';
	signal discriminatorSerdesSlowClock       : std_logic                    := '0';
	signal discriminatorSerdesSlowClockGlobal : std_logic                    := '0';
	signal clockDcm3ToPll                     : std_logic                    := '0';
	signal dcm3Locked                         : std_logic                    := '0';
	signal dcm3Status                         : std_logic_vector(7 downto 0) := x"00";
	signal dcm3Clock0                         : std_logic                    := '0';
	signal dcm3Reset                          : std_logic                    := '0';
	signal pllFeedBack3                       : std_logic                    := '0';
	--signal pllReset3 : std_logic := '0';
	signal pllLocked3               : std_logic := '1';
	signal adcSerdesFastClock       : std_logic := '0';
	signal adcSerdesSlowClock       : std_logic := '0';
	signal adcSerdesSlowClockPhase  : std_logic := '0';
	signal adcSerdesSlowClockGlobal : std_logic := '0';

	signal bufpllLocked1 : std_logic := '1';
	signal bufpllLocked3 : std_logic := '1';
	--	signal serdesStrobe_i : std_logic := '0';
	signal reset_i0          : std_logic_vector(7 downto 0) := x"ff";
	signal reset_i1          : std_logic_vector(7 downto 0) := x"ff";
	signal reset_i2          : std_logic_vector(7 downto 0) := x"ff";
	signal reset_i3          : std_logic_vector(7 downto 0) := x"ff";
	signal clockErrorTrigger : std_logic                    := '0';
	signal clockErrorAdc     : std_logic                    := '0';
	--	signal clockErrorAll : std_logic := '0';

	--	signal pllFeedBack2 : std_logic := '0';
	--	signal pllReset2 : std_logic := '0';
	--	signal pllLocked2 : std_logic := '0';

	signal dcm2Locked : std_logic                    := '0';
	signal dcm2Status : std_logic_vector(7 downto 0) := x"00";
	signal dcm2Clock0 : std_logic                    := '0';
	--signal dcm2Reset : std_logic := '0';
	signal dcm2FxClock : std_logic := '0';

	--signal refClockCounter : integer range 0 to 255 := 0;
	signal refClockCounter : unsigned(7 downto 0) := x"00";
	signal refClock        : std_logic            := '0';

	signal debugSync1 : clockConfig_debug_t;
	signal debugSync2 : clockConfig_debug_t;

	signal commClock_i : std_logic := '0';

begin
	drs4RefClock <= refClock;
	clockValid <= dcm1_locked and bufpllLocked1 and pllLocked1;

	BUFIO2_inst : BUFIO2
	generic map(
		DIVIDE        => 1,   -- The DIVCLK divider divide-by value
		DIVIDE_BYPASS => TRUE -- DIVCLK output sourced from Divider (FALSE) or from I input, by-passing Divider (TRUE); default TRUE
	)
	port map(
		I            => i_clk_10m_ext,         -- from GCLK input pin
		IOCLK        => open,             -- Output Clock to IO
		DIVCLK       => clk_10m_ext_buffered, -- to PLL/DCM
		SERDESSTROBE => open              -- Output strobe for IOSERDES2
	);

	-------------------------------------------------------------------------------
	DCM_SP_inst : DCM_SP
	generic map(
		CLKDV_DIVIDE       => 2.0,                  -- CLKDV divide value (1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5,7,7.5,8,9,10,11,12,13,14,15,16).
		CLKFX_DIVIDE       => 2,                    -- Divide value on CLKFX outputs - D - (1-32)
		CLKFX_MULTIPLY     => 5,                    -- Multiply value on CLKFX outputs - M - (2-32)
		CLKIN_DIVIDE_BY_2  => FALSE,                -- CLKIN divide by two (TRUE/FALSE)
		CLKIN_PERIOD       => 100.0,                -- Input clock period specified in nS
		CLKOUT_PHASE_SHIFT => "NONE",               -- Output phase shift (NONE, FIXED, VARIABLE)
		CLK_FEEDBACK       => "1X",                 -- Feedback source (NONE, 1X, 2X)
		DESKEW_ADJUST      => "SOURCE_SYNCHRONOUS", -- SYSTEM_SYNCHRNOUS or SOURCE_SYNCHRONOUS
		PHASE_SHIFT        => 0,                    -- Amount of fixed phase shift (-255 to 255)
		STARTUP_WAIT       => FALSE                 -- Delay config DONE until DCM_SP LOCKED (TRUE/FALSE)
	)
	port map(
		CLK0     => dcm1_feedback,       -- 1-bit output: 0 degree clock output
		CLK180   => open,             -- 1-bit output: 180 degree clock output
		CLK270   => open,             -- 1-bit output: 270 degree clock output
		CLK2X    => open,             -- 1-bit output: 2X clock frequency clock output
		CLK2X180 => open,             -- 1-bit output: 2X clock frequency, 180 degree clock output
		CLK90    => open,             -- 1-bit output: 90 degree clock output
		CLKDV    => open,             -- 1-bit output: Divided clock output
		CLKFX    => dcm1_clko_25,   -- 1-bit output: Digital Frequency Synthesizer output (DFS)
		CLKFX180 => open,             -- 1-bit output: 180 degree CLKFX output
		LOCKED   => dcm1_locked,       -- 1-bit output: DCM_SP Lock Output
		PSDONE   => open,             -- 1-bit output: Phase shift done output
		STATUS   => dcm1_status,       -- 8-bit output: DCM_SP status output
		CLKFB    => dcm1_feedback,       -- 1-bit input: Clock feedback input
		CLKIN    => clk_10m_ext_buffered, -- 1-bit input: Clock input
		DSSEN    => '0',              -- 1-bit input: Unsupported, specify to GND.
		PSCLK    => '0',              -- 1-bit input: Phase shift clock input
		PSEN     => '0',              -- 1-bit input: Phase shift enable
		PSINCDEC => '0',              -- 1-bit input: Phase shift increment/decrement input
		RST      => i_rst_ext         -- 1-bit input: Active high reset input
	);

	dcm1Reset <= ((not(dcm1_locked) and dcm1_status(2)) or i_rst_ext);
	
	-------------------------------------------------------------------------------
	pll_base_inst : PLL_BASE
	generic map(
		BANDWIDTH          => "OPTIMIZED",
		CLK_FEEDBACK       => "CLKFBOUT",
		COMPENSATION       => "DCM2PLL",
		CLKIN_PERIOD       => 40.000,
		REF_JITTER         => 0.100,
		DIVCLK_DIVIDE      => 1,
		CLKFBOUT_MULT      => 38,
		CLKFBOUT_PHASE     => 0.000,
		CLKOUT0_DIVIDE     => 1,
		CLKOUT0_PHASE      => 0.000,
		CLKOUT0_DUTY_CYCLE => 0.500,
		CLKOUT1_DIVIDE     => 1,
		CLKOUT1_PHASE      => 0.000,
		CLKOUT1_DUTY_CYCLE => 0.500,
		CLKOUT2_DIVIDE     => 8,
		CLKOUT2_PHASE      => 0.000,
		CLKOUT2_DUTY_CYCLE => 0.500,
		CLKOUT3_DIVIDE     => 1,
		CLKOUT3_PHASE      => 0.000,
		CLKOUT3_DUTY_CYCLE => 0.500,
		CLKOUT4_DIVIDE     => 1,
		CLKOUT4_PHASE      => 0.000,
		CLKOUT4_DUTY_CYCLE => 0.500,
		CLKOUT5_DIVIDE     => 16,
		CLKOUT5_PHASE      => 0.000,
		CLKOUT5_DUTY_CYCLE => 0.500
	)
	port map(
		CLKFBOUT => pllFeedBack1,
		CLKOUT0  => discriminatorSerdesFastClock,
		CLKOUT1  => open,
		CLKOUT2  => discriminatorSerdesSlowClock,
		CLKOUT3  => open,
		CLKOUT4  => open,
		CLKOUT5  => commClock_i,
		LOCKED   => pllLocked1,
		RST      => '0', --pllReset1,
		CLKFBIN  => pllFeedBack1,
		CLKIN    => dcm1_clko_25
	);

	bufg_inst1 : BUFG port map(I => discriminatorSerdesSlowClock, O => discriminatorSerdesSlowClockGlobal);

	bufpll_inst1 : BUFPLL
	generic map(
		DIVIDE => 8
	)
	port map(
		PLLIN        => discriminatorSerdesFastClock,       -- PLL Clock input
		GCLK         => discriminatorSerdesSlowClockGlobal, -- Global Clock input
		LOCKED       => pllLocked1,                         -- Clock0 locked input
		IOCLK        => triggerSerdesClocks.serdesIoClock,  -- Output PLL Clock
		LOCK         => bufpllLocked1,                      -- BUFPLL Clock and strobe locked
		serdesstrobe => triggerSerdesClocks.serdesStrobe    -- Output SERDES strobe
	);


	--	p1: process(clockDcm1ToPll)
	--		variable dcmResetCounter : integer range 0 to 65535 := 0; -- time to lock is 5 ms max. !!!
	--	begin
	--		if(rising_edge(dcm1Clock0)) then
	--			if(((dcm1Status(2 downto 1) /= "00") or (dcm1Locked = '0')) and (dcmResetCounter = 0)) then
	--				dcmResetCounter := 65535;
	--				dcm1Reset <= '1'; -- active for 3 clock cycles min.
	--         elsif(dcmResetCounter /= 0) then  
	--				dcmResetCounter := dcmResetCounter - 1;
	--				if(dcmResetCounter = 65525) then 
	--					dcm1Reset <= '0';
	--				end if;  
	--			end if;
	--		end if;
	--	end process;

	--clockError <= '1' when ((dcm1Locked = '0') or (dcm2Locked = '0') or (dcm3Locked = '0') or (bufpllLocked1 = '0') or (pllLocked1 = '0') or (bufpllLocked3 = '0') or (pllLocked3 = '0') or (asyncReset = '1')) else '0';
	--clockErrorTrigger <= '1' when ((bufpllLocked1 = '0') or (pllLocked1 = '0') or (asyncReset = '1')) else '0';
	clockErrorTrigger <= '1' when ((pllLocked1 = '0') or (i_rst_ext = '1')) else
		'0';
	--clockErrorAdc <= '1' when ((bufpllLocked3 = '0') or (pllLocked3 = '0') or (asyncReset = '1')) else '0';
	clockErrorAdc <= '1' when ((pllLocked3 = '0') or (i_rst_ext = '1')) else
		'0';
	--	clockErrorAll <= clockErrorTrigger or clockErrorAdc;
	--	clockError <= '1' when ((dcm1Locked = '0') or (bufpllLocked1 = '0') or (bufpllLocked2 = '0') or (pllLocked1 = '0') or (pllLocked2 = '0')) else '0';

	-------------------------------------------------------------------------------

	g3a : if SYSTEM_TYPE = ICE_SCINT generate
		DCM_SP_inst3 : DCM_SP
		generic map(
			CLKDV_DIVIDE       => 2.0,                  -- CLKDV divide value (1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5,7,7.5,8,9,10,11,12,13,14,15,16).
			CLKFX_DIVIDE       => 1,                    -- Divide value on CLKFX outputs - D - (1-32)
			CLKFX_MULTIPLY     => 3,                    -- Multiply value on CLKFX outputs - M - (2-32)
			CLKIN_DIVIDE_BY_2  => FALSE,                -- CLKIN divide by two (TRUE/FALSE)
			CLKIN_PERIOD       => 100.0,                -- Input clock period specified in nS
			CLKOUT_PHASE_SHIFT => "NONE",               -- Output phase shift (NONE, FIXED, VARIABLE)
			CLK_FEEDBACK       => "1X",                 -- Feedback source (NONE, 1X, 2X)
			DESKEW_ADJUST      => "SOURCE_SYNCHRONOUS", -- SYSTEM_SYNCHRNOUS or SOURCE_SYNCHRONOUS
			PHASE_SHIFT        => 0,                    -- Amount of fixed phase shift (-255 to 255)
			STARTUP_WAIT       => FALSE                 -- Delay config DONE until DCM_SP LOCKED (TRUE/FALSE)
		)
		port map(
			CLK0     => dcm3Clock0,       -- 1-bit output: 0 degree clock output
			CLK180   => open,             -- 1-bit output: 180 degree clock output
			CLK270   => open,             -- 1-bit output: 270 degree clock output
			CLK2X    => open,             -- 1-bit output: 2X clock frequency clock output
			CLK2X180 => open,             -- 1-bit output: 2X clock frequency, 180 degree clock output
			CLK90    => open,             -- 1-bit output: 90 degree clock output
			CLKDV    => open,             -- 1-bit output: Divided clock output
			CLKFX    => clockDcm3ToPll,   -- 1-bit output: Digital Frequency Synthesizer output (DFS)
			CLKFX180 => open,             -- 1-bit output: 180 degree CLKFX output
			LOCKED   => dcm3Locked,       -- 1-bit output: DCM_SP Lock Output
			PSDONE   => open,             -- 1-bit output: Phase shift done output
			STATUS   => dcm3Status,       -- 8-bit output: DCM_SP status output
			CLKFB    => dcm3Clock0,       -- 1-bit input: Clock feedback input
			CLKIN    => clk_10m_ext_buffered, -- 1-bit input: Clock input
			DSSEN    => '0',              -- 1-bit input: Unsupported, specify to GND.
			PSCLK    => '0',              -- 1-bit input: Phase shift clock input
			PSEN     => '0',              -- 1-bit input: Phase shift enable
			PSINCDEC => '0',              -- 1-bit input: Phase shift increment/decrement input
			RST      => dcm3Reset         -- 1-bit input: Active high reset input
		);
	end generate;
	g3b : if SYSTEM_TYPE = UV_LOGGER generate
		DCM_SP_inst3 : DCM_SP
		generic map(
			CLKDV_DIVIDE       => 2.0,                  -- CLKDV divide value (1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5,7,7.5,8,9,10,11,12,13,14,15,16).
			CLKFX_DIVIDE       => 5,                    -- Divide value on CLKFX outputs - D - (1-32)
			CLKFX_MULTIPLY     => 6,                    -- Multiply value on CLKFX outputs - M - (2-32)
			CLKIN_DIVIDE_BY_2  => FALSE,                -- CLKIN divide by two (TRUE/FALSE)
			CLKIN_PERIOD       => 40.0,                 -- Input clock period specified in nS
			CLKOUT_PHASE_SHIFT => "NONE",               -- Output phase shift (NONE, FIXED, VARIABLE)
			CLK_FEEDBACK       => "1X",                 -- Feedback source (NONE, 1X, 2X)
			DESKEW_ADJUST      => "SOURCE_SYNCHRONOUS", -- SYSTEM_SYNCHRNOUS or SOURCE_SYNCHRONOUS
			PHASE_SHIFT        => 0,                    -- Amount of fixed phase shift (-255 to 255)
			STARTUP_WAIT       => FALSE                 -- Delay config DONE until DCM_SP LOCKED (TRUE/FALSE)
		)
		port map(
			CLK0     => dcm3Clock0,       -- 1-bit output: 0 degree clock output
			CLK180   => open,             -- 1-bit output: 180 degree clock output
			CLK270   => open,             -- 1-bit output: 270 degree clock output
			CLK2X    => open,             -- 1-bit output: 2X clock frequency clock output
			CLK2X180 => open,             -- 1-bit output: 2X clock frequency, 180 degree clock output
			CLK90    => open,             -- 1-bit output: 90 degree clock output
			CLKDV    => open,             -- 1-bit output: Divided clock output
			CLKFX    => clockDcm3ToPll,   -- 1-bit output: Digital Frequency Synthesizer output (DFS)
			CLKFX180 => open,             -- 1-bit output: 180 degree CLKFX output
			LOCKED   => dcm3Locked,       -- 1-bit output: DCM_SP Lock Output
			PSDONE   => open,             -- 1-bit output: Phase shift done output
			STATUS   => dcm3Status,       -- 8-bit output: DCM_SP status output
			CLKFB    => dcm3Clock0,       -- 1-bit input: Clock feedback input
			CLKIN    => clk_10m_ext_buffered, -- 1-bit input: Clock input
			DSSEN    => '0',              -- 1-bit input: Unsupported, specify to GND.
			PSCLK    => '0',              -- 1-bit input: Phase shift clock input
			PSEN     => '0',              -- 1-bit input: Phase shift enable
			PSINCDEC => '0',              -- 1-bit input: Phase shift increment/decrement input
			RST      => dcm3Reset         -- 1-bit input: Active high reset input
		);
	end generate;

	pll_base_inst3 : PLL_BASE
	generic map(
		BANDWIDTH          => "OPTIMIZED",
		CLK_FEEDBACK       => "CLKFBOUT",
		COMPENSATION       => "DCM2PLL",
		CLKIN_PERIOD       => 33.333333,
		REF_JITTER         => 0.100,
		DIVCLK_DIVIDE      => 1,
		CLKFBOUT_MULT      => 14,
		CLKFBOUT_PHASE     => 0.000,
		CLKOUT0_DIVIDE     => 1,
		CLKOUT0_PHASE      => 0.000,
		CLKOUT0_DUTY_CYCLE => 0.500,
		CLKOUT1_DIVIDE     => 1,
		CLKOUT1_PHASE      => 0.000,
		CLKOUT1_DUTY_CYCLE => 0.500,
		CLKOUT2_DIVIDE     => 7,
		CLKOUT2_PHASE      => 0.000,
		CLKOUT2_DUTY_CYCLE => 0.500,
		CLKOUT3_DIVIDE     => 7,
		CLKOUT3_PHASE      => 0.000, --
		CLKOUT3_DUTY_CYCLE => 0.500,
		CLKOUT4_DIVIDE     => 1,
		CLKOUT4_PHASE      => 0.000,
		CLKOUT4_DUTY_CYCLE => 0.500,
		CLKOUT5_DIVIDE     => 1,
		CLKOUT5_PHASE      => 0.000,
		CLKOUT5_DUTY_CYCLE => 0.500
	)
	port map(
		CLKFBOUT => pllFeedBack3,
		CLKOUT0  => adcSerdesFastClock,
		CLKOUT1  => open,
		CLKOUT2  => adcSerdesSlowClock,
		CLKOUT3  => adcSerdesSlowClockPhase,
		CLKOUT4  => open,
		CLKOUT5  => open,
		LOCKED   => pllLocked3,
		RST      => '0', --pllReset3,
		CLKFBIN  => pllFeedBack3,
		CLKIN    => clockDcm3ToPll
	);

	bufg_inst3 : BUFG port map(I => adcSerdesSlowClock, O => adcSerdesSlowClockGlobal);

	bufpll_inst3 : BUFPLL
	generic map(
		DIVIDE => 7
	)
	port map(
		PLLIN        => adcSerdesFastClock,       -- PLL Clock input
		GCLK         => adcSerdesSlowClockGlobal, -- Global Clock input
		LOCKED       => pllLocked3,               -- Clock0 locked input
		IOCLK        => adcClocks.serdesIoClock,  -- Output PLL Clock
		LOCK         => bufpllLocked3,            -- BUFPLL Clock and strobe locked
		serdesstrobe => adcClocks.serdesStrobe    -- Output SERDES strobe
	);

	dcm3Reset <= ((not(dcm3Locked) and dcm3Status(2)) or i_rst_ext);

	-------------------------------------------------------------------------------

	g2a : if SYSTEM_TYPE = ICE_SCINT generate
		DCM_SP_inst_2 : DCM_SP
		generic map(
			CLKDV_DIVIDE       => 2.0,                  -- CLKDV divide value (1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5,7,7.5,8,9,10,11,12,13,14,15,16).
			CLKFX_DIVIDE       => 2,                    -- Divide value on CLKFX outputs - D - (1-32)
			CLKFX_MULTIPLY     => 25,                   -- Multiply value on CLKFX outputs - M - (2-32)
			CLKIN_DIVIDE_BY_2  => FALSE,                -- CLKIN divide by two (TRUE/FALSE)
			CLKIN_PERIOD       => 100.0,                -- Input clock period specified in nS
			CLKOUT_PHASE_SHIFT => "NONE",               -- Output phase shift (NONE, FIXED, VARIABLE)
			CLK_FEEDBACK       => "1X",                 -- Feedback source (NONE, 1X, 2X)
			DESKEW_ADJUST      => "SOURCE_SYNCHRONOUS", -- SYSTEM_SYNCHRNOUS or SOURCE_SYNCHRONOUS
			PHASE_SHIFT        => 0,                    -- Amount of fixed phase shift (-255 to 255)
			STARTUP_WAIT       => FALSE                 -- Delay config DONE until DCM_SP LOCKED (TRUE/FALSE)
		)
		port map(
			CLK0     => dcm2Clock0,       -- 1-bit output: 0 degree clock output
			CLK180   => open,             -- 1-bit output: 180 degree clock output
			CLK270   => open,             -- 1-bit output: 270 degree clock output
			CLK2X    => open,             -- 1-bit output: 2X clock frequency clock output
			CLK2X180 => open,             -- 1-bit output: 2X clock frequency, 180 degree clock output
			CLK90    => open,             -- 1-bit output: 90 degree clock output
			CLKDV    => open,             -- 1-bit output: Divided clock output
			CLKFX    => dcm2FxClock,      -- 1-bit output: Digital Frequency Synthesizer output (DFS)
			CLKFX180 => open,             -- 1-bit output: 180 degree CLKFX output
			LOCKED   => dcm2Locked,       -- 1-bit output: DCM_SP Lock Output
			PSDONE   => open,             -- 1-bit output: Phase shift done output
			STATUS   => dcm2Status,       -- 8-bit output: DCM_SP status output
			CLKFB    => dcm2Clock0,       -- 1-bit input: Clock feedback input
			CLKIN    => clk_10m_ext_buffered, -- 1-bit input: Clock input
			DSSEN    => '0',              -- 1-bit input: Unsupported, specify to GND.
			PSCLK    => '0',              -- 1-bit input: Phase shift clock input
			PSEN     => '0',              -- 1-bit input: Phase shift enable
			PSINCDEC => '0',              -- 1-bit input: Phase shift increment/decrement input
			RST      => '0'               --dcm2Reset        		-- 1-bit input: Active high reset input
		);
	end generate;
	g2b : if SYSTEM_TYPE = UV_LOGGER generate
		DCM_SP_inst_2 : DCM_SP
		generic map(
			CLKDV_DIVIDE       => 2.0,                  -- CLKDV divide value (1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5,7,7.5,8,9,10,11,12,13,14,15,16).
			CLKFX_DIVIDE       => 1,                    -- Divide value on CLKFX outputs - D - (1-32)
			CLKFX_MULTIPLY     => 5,                    -- Multiply value on CLKFX outputs - M - (2-32)
			CLKIN_DIVIDE_BY_2  => FALSE,                -- CLKIN divide by two (TRUE/FALSE)
			CLKIN_PERIOD       => 40.0,                 -- Input clock period specified in nS
			CLKOUT_PHASE_SHIFT => "NONE",               -- Output phase shift (NONE, FIXED, VARIABLE)
			CLK_FEEDBACK       => "1X",                 -- Feedback source (NONE, 1X, 2X)
			DESKEW_ADJUST      => "SOURCE_SYNCHRONOUS", -- SYSTEM_SYNCHRNOUS or SOURCE_SYNCHRONOUS
			PHASE_SHIFT        => 0,                    -- Amount of fixed phase shift (-255 to 255)
			STARTUP_WAIT       => FALSE                 -- Delay config DONE until DCM_SP LOCKED (TRUE/FALSE)
		)
		port map(
			CLK0     => dcm2Clock0,       -- 1-bit output: 0 degree clock output
			CLK180   => open,             -- 1-bit output: 180 degree clock output
			CLK270   => open,             -- 1-bit output: 270 degree clock output
			CLK2X    => open,             -- 1-bit output: 2X clock frequency clock output
			CLK2X180 => open,             -- 1-bit output: 2X clock frequency, 180 degree clock output
			CLK90    => open,             -- 1-bit output: 90 degree clock output
			CLKDV    => open,             -- 1-bit output: Divided clock output
			CLKFX    => dcm2FxClock,      -- 1-bit output: Digital Frequency Synthesizer output (DFS)
			CLKFX180 => open,             -- 1-bit output: 180 degree CLKFX output
			LOCKED   => dcm2Locked,       -- 1-bit output: DCM_SP Lock Output
			PSDONE   => open,             -- 1-bit output: Phase shift done output
			STATUS   => dcm2Status,       -- 8-bit output: DCM_SP status output
			CLKFB    => dcm2Clock0,       -- 1-bit input: Clock feedback input
			CLKIN    => clk_10m_ext_buffered, -- 1-bit input: Clock input
			DSSEN    => '0',              -- 1-bit input: Unsupported, specify to GND.
			PSCLK    => '0',              -- 1-bit input: Phase shift clock input
			PSEN     => '0',              -- 1-bit input: Phase shift enable
			PSINCDEC => '0',              -- 1-bit input: Phase shift increment/decrement input
			RST      => '0'               --dcm2Reset        		-- 1-bit input: Active high reset input
		);
	end generate;

	p3 : process (dcm2FxClock)
	begin
		if (rising_edge(dcm2FxClock)) then
			debugSync1 <= debug;
			debugSync2 <= debugSync1;
			if (clockErrorAdc = '0') then
				refClockCounter <= refClockCounter + 1;
				--if(refClockCounter >= 127) then
				if (refClockCounter >= unsigned(debugSync2.drs4RefClockPeriod)) then
					refClockCounter <= x"00";
					refClock        <= not(refClock); -- from 125MHz: refClock will be 488.28125 kHz to get 1.000GS 	
				end if;
			else
				refClockCounter <= x"00";
				refClock        <= '0';
			end if;
		end if;
	end process;

	-------------------------------------------------------------------------------
	process (discriminatorSerdesSlowClockGlobal, clockErrorTrigger)
	begin
		if (rising_edge(discriminatorSerdesSlowClockGlobal)) then
			reset_i0 <= '0' & reset_i0(reset_i0'length - 1 downto 1);
		end if;
		if (clockErrorTrigger = '1') then
			reset_i0(reset_i0'length - 1 downto 3) <= (others => '1');
		end if;
	end process;

	process (adcSerdesSlowClockGlobal, clockErrorAdc)
	begin
		if (rising_edge(adcSerdesSlowClockGlobal)) then
			reset_i1 <= '0' & reset_i1(reset_i1'length - 1 downto 1);
		end if;
		if (clockErrorAdc = '1') then
			reset_i1(reset_i1'length - 1 downto 3) <= (others => '1');
		end if;
	end process;

	process (adcSerdesSlowClockPhase, clockErrorAdc)
	begin
		if (rising_edge(adcSerdesSlowClockPhase)) then
			reset_i2 <= '0' & reset_i2(reset_i2'length - 1 downto 1);
		end if;
		if (clockErrorAdc = '1') then
			reset_i2(reset_i2'length - 1 downto 3) <= (others => '1');
		end if;
	end process;

	adcClocks.serdesDivClock           <= adcSerdesSlowClockGlobal;
	adcClocks.serdesDivClockPhase      <= adcSerdesSlowClockPhase;
	adcClocks.serdesDivClockReset      <= reset_i1(0);
	adcClocks.serdesDivClockPhaseReset <= reset_i2(0);

	triggerSerdesClocks.serdesDivClock      <= discriminatorSerdesSlowClockGlobal;
	triggerSerdesClocks.serdesDivClockReset <= reset_i0(0);
	--triggerSerdesClocks.asyncReset <= clockErrorAll;
	triggerSerdesClocks.asyncReset <= clockErrorTrigger;
	process (commClock_i, clockErrorTrigger)
	begin
		if (rising_edge(commClock_i)) then
			reset_i3 <= '0' & reset_i3(reset_i3'length - 1 downto 1);
		end if;
		if (clockErrorTrigger = '1') then
			reset_i3(reset_i3'length - 1 downto 3) <= (others => '1');
		end if;
	end process;

	uv_loggerClocks.communicationClock      <= commClock_i;
	uv_loggerClocks.communicationClockReset <= reset_i3(0);

end Behavioral;

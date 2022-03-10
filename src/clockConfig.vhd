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
	port(
		i_clk_10m_ext       : in  std_logic;
		i_rst_ext           : in  std_logic;
		triggerSerdesClocks : out triggerSerdesClocks_t;
		adcClocks           : out adcClocks_t;
		clockValid          : out std_logic;
		debug               : in  clockConfig_debug_t; -- remove me !!
		drs4RefClock        : out std_logic;
		o_clk125            : out std_logic
	);
end clockConfig;

architecture Behavioral of clockConfig is

	signal clk_10m_ext_buffered      : std_logic                    := '0';
	signal dcm1_clko_30              : std_logic                    := '0';
	signal dcm1_locked               : std_logic                    := '0';
	signal dcm1_status               : std_logic_vector(7 downto 0) := x"00";
	signal dcm1_feedback             : std_logic                    := '0';
	signal dcm1Reset                 : std_logic                    := '0';
	signal pll1_feedback             : std_logic                    := '0';
	--signal pllReset1 : std_logic := '0';
	signal pll1_locked               : std_logic                    := '1';
	signal pll1_clko_960             : std_logic                    := '0';
	signal pll1_clk0_div8_120        : std_logic                    := '0';
	signal pll1_clk0_div8_120_global : std_logic                    := '0';
        -- 2022-03-09 mbk added pll1_clko_div16_60
	signal pll1_clko_div16_60        : std_logic                    := '0';
	signal dcm3_clko_30              : std_logic                    := '0';
	signal dcm3_locked               : std_logic                    := '0';
	signal dcm3_status               : std_logic_vector(7 downto 0) := x"00";
	signal dcm3_feedback             : std_logic                    := '0';
	signal dcm3_reset                : std_logic                    := '0';
	signal pll3_feedback             : std_logic                    := '0';
	--signal pllReset3 : std_logic := '0';
	signal pll3_locked               : std_logic                    := '1';
	signal pll3_clko_462             : std_logic                    := '0';
	signal pll3_clko_div7_66         : std_logic                    := '0';
	signal pll3_clko_div7_66_second  : std_logic                    := '0';
	signal pll3_clko_div7_66_global  : std_logic                    := '0';

	signal pll1_locked_buf   : std_logic                    := '1';
	signal pll3_locked_buf   : std_logic                    := '1';
	--	signal serdesStrobe_i : std_logic := '0';
	signal reset_i0          : std_logic_vector(7 downto 0) := x"ff";
	signal reset_i1          : std_logic_vector(7 downto 0) := x"ff";
	signal reset_i2          : std_logic_vector(7 downto 0) := x"ff";
        -- 2022-03-09 mbk added reset_i3
	signal reset_i3          : std_logic_vector(7 downto 0) := x"ff";
	signal clockErrorTrigger : std_logic                    := '0';
	signal clockErrorAdc     : std_logic                    := '0';
	--	signal clockErrorAll : std_logic := '0';

	--	signal pllFeedBack2 : std_logic := '0';
	--	signal pllReset2 : std_logic := '0';
	--	signal pllLocked2 : std_logic := '0';

	signal dcm2_locked   : std_logic                    := '0';
	signal dcm2_status   : std_logic_vector(7 downto 0) := x"00";
	signal dcm2_feedback : std_logic                    := '0';
	--signal dcm2Reset : std_logic := '0';
	signal dcm2_clko_125 : std_logic                    := '0';

	--signal refClockCounter : integer range 0 to 255 := 0;
	signal refClockCounter : unsigned(7 downto 0) := x"00";
	signal refClock        : std_logic            := '0';

	signal debugSync1 : clockConfig_debug_t;
	signal debugSync2 : clockConfig_debug_t;
begin
	drs4RefClock <= refClock;
	clockValid   <= dcm1_locked and pll1_locked_buf and pll1_locked;

	BUFIO2_inst : BUFIO2
		generic map(
			DIVIDE        => 1,         -- The DIVCLK divider divide-by value
			DIVIDE_BYPASS => TRUE       -- DIVCLK output sourced from Divider (FALSE) or from I input, by-passing Divider (TRUE); default TRUE
		)
		port map(
			I            => i_clk_10m_ext, -- from GCLK input pin
			IOCLK        => open,       -- Output Clock to IO
			DIVCLK       => clk_10m_ext_buffered, -- to PLL/DCM
			SERDESSTROBE => open        -- Output strobe for IOSERDES2
		);

	-------------------------------------------------------------------------------
	DCM_SP_inst : DCM_SP
		generic map(
			CLKDV_DIVIDE       => 2.0,  -- CLKDV divide value (1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5,7,7.5,8,9,10,11,12,13,14,15,16).
			CLKFX_DIVIDE       => 2,    -- Divide value on CLKFX outputs - D - (1-32)
			CLKFX_MULTIPLY     => 6,    -- Multiply value on CLKFX outputs - M - (2-32)
			CLKIN_DIVIDE_BY_2  => FALSE, -- CLKIN divide by two (TRUE/FALSE)
			CLKIN_PERIOD       => 100.0, -- Input clock period specified in nS
			CLKOUT_PHASE_SHIFT => "NONE", -- Output phase shift (NONE, FIXED, VARIABLE)
			CLK_FEEDBACK       => "1X", -- Feedback source (NONE, 1X, 2X)
			DESKEW_ADJUST      => "SOURCE_SYNCHRONOUS", -- SYSTEM_SYNCHRNOUS or SOURCE_SYNCHRONOUS
			PHASE_SHIFT        => 0,    -- Amount of fixed phase shift (-255 to 255)
			STARTUP_WAIT       => FALSE -- Delay config DONE until DCM_SP LOCKED (TRUE/FALSE)
		)
		port map(
			CLK0     => dcm1_feedback,  -- 1-bit output: 0 degree clock output
			CLK180   => open,           -- 1-bit output: 180 degree clock output
			CLK270   => open,           -- 1-bit output: 270 degree clock output
			CLK2X    => open,           -- 1-bit output: 2X clock frequency clock output
			CLK2X180 => open,           -- 1-bit output: 2X clock frequency, 180 degree clock output
			CLK90    => open,           -- 1-bit output: 90 degree clock output
			CLKDV    => open,           -- 1-bit output: Divided clock output
			CLKFX    => dcm1_clko_30,   -- 1-bit output: Digital Frequency Synthesizer output (DFS)
			CLKFX180 => open,           -- 1-bit output: 180 degree CLKFX output
			LOCKED   => dcm1_locked,    -- 1-bit output: DCM_SP Lock Output
			PSDONE   => open,           -- 1-bit output: Phase shift done output
			STATUS   => dcm1_status,    -- 8-bit output: DCM_SP status output
			CLKFB    => dcm1_feedback,  -- 1-bit input: Clock feedback input
			CLKIN    => clk_10m_ext_buffered, -- 1-bit input: Clock input
			DSSEN    => '0',            -- 1-bit input: Unsupported, specify to GND.
			PSCLK    => '0',            -- 1-bit input: Phase shift clock input
			PSEN     => '0',            -- 1-bit input: Phase shift enable
			PSINCDEC => '0',            -- 1-bit input: Phase shift increment/decrement input
			RST      => i_rst_ext       -- 1-bit input: Active high reset input
		);

	dcm1Reset <= ((not (dcm1_locked) and dcm1_status(2)) or i_rst_ext);

	-------------------------------------------------------------------------------
	pll_base_inst : PLL_BASE
		generic map(
			BANDWIDTH          => "OPTIMIZED",
			CLK_FEEDBACK       => "CLKFBOUT",
			COMPENSATION       => "DCM2PLL",
			CLKIN_PERIOD       => 40.000,
			REF_JITTER         => 0.100,
			DIVCLK_DIVIDE      => 1,
			CLKFBOUT_MULT      => 32,
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
			CLKFBOUT => pll1_feedback,
			CLKOUT0  => pll1_clko_960,
			CLKOUT1  => open,
			CLKOUT2  => pll1_clk0_div8_120,
			CLKOUT3  => open,
			CLKOUT4  => open,
			CLKOUT5  => pll1_clko_div16_60,
			LOCKED   => pll1_locked,
			CLKFBIN  => pll1_feedback,
			CLKIN    => dcm1_clko_30,
			RST      => '0'
		);

	bufg_inst1 : BUFG
		port map(
			O => pll1_clk0_div8_120_global,
			I => pll1_clk0_div8_120
		);


	bufpll_inst1 : BUFPLL
		generic map(
			ENABLE_SYNC => true,
			DIVIDE      => 8
		)
		port map(
			IOCLK        => triggerSerdesClocks.clk_950_serdes_io, -- Output PLL Clock
			LOCK         => pll1_locked_buf, -- BUFPLL Clock and strobe locked
			serdesstrobe => triggerSerdesClocks.serdes_strobe_950, -- Output SERDES strobe
			GCLK         => pll1_clk0_div8_120_global, -- Global Clock input
			LOCKED       => pll1_locked, -- Clock0 locked input
			PLLIN        => pll1_clko_960 -- PLL Clock input
		);

	clockErrorTrigger <= '1' when ((pll1_locked = '0') or (i_rst_ext = '1')) else '0';
	clockErrorAdc     <= '1' when ((pll3_locked = '0') or (i_rst_ext = '1')) else '0';

	-------------------------------------------------------------------------------

	DCM_SP_inst3 : DCM_SP
		generic map(
			CLKDV_DIVIDE       => 2.0,  -- CLKDV divide value (1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5,7,7.5,8,9,10,11,12,13,14,15,16).
			CLKFX_DIVIDE       => 1,    -- Divide value on CLKFX outputs - D - (1-32)
			CLKFX_MULTIPLY     => 3,    -- Multiply value on CLKFX outputs - M - (2-32)
			CLKIN_DIVIDE_BY_2  => FALSE, -- CLKIN divide by two (TRUE/FALSE)
			CLKIN_PERIOD       => 100.0, -- Input clock period specified in nS
			CLKOUT_PHASE_SHIFT => "NONE", -- Output phase shift (NONE, FIXED, VARIABLE)
			CLK_FEEDBACK       => "1X", -- Feedback source (NONE, 1X, 2X)
			DESKEW_ADJUST      => "SOURCE_SYNCHRONOUS", -- SYSTEM_SYNCHRNOUS or SOURCE_SYNCHRONOUS
			PHASE_SHIFT        => 0,    -- Amount of fixed phase shift (-255 to 255)
			STARTUP_WAIT       => FALSE -- Delay config DONE until DCM_SP LOCKED (TRUE/FALSE)
		)
		port map(
			CLK0     => dcm3_feedback,  -- 1-bit output: 0 degree clock output
			CLK180   => open,           -- 1-bit output: 180 degree clock output
			CLK270   => open,           -- 1-bit output: 270 degree clock output
			CLK2X    => open,           -- 1-bit output: 2X clock frequency clock output
			CLK2X180 => open,           -- 1-bit output: 2X clock frequency, 180 degree clock output
			CLK90    => open,           -- 1-bit output: 90 degree clock output
			CLKDV    => open,           -- 1-bit output: Divided clock output
			CLKFX    => dcm3_clko_30,   -- 1-bit output: Digital Frequency Synthesizer output (DFS)
			CLKFX180 => open,           -- 1-bit output: 180 degree CLKFX output
			LOCKED   => dcm3_locked,    -- 1-bit output: DCM_SP Lock Output
			PSDONE   => open,           -- 1-bit output: Phase shift done output
			STATUS   => dcm3_status,    -- 8-bit output: DCM_SP status output
			CLKFB    => dcm3_feedback,  -- 1-bit input: Clock feedback input
			CLKIN    => clk_10m_ext_buffered, -- 1-bit input: Clock input
			DSSEN    => '0',            -- 1-bit input: Unsupported, specify to GND.
			PSCLK    => '0',            -- 1-bit input: Phase shift clock input
			PSEN     => '0',            -- 1-bit input: Phase shift enable
			PSINCDEC => '0',            -- 1-bit input: Phase shift increment/decrement input
			RST      => dcm3_reset      -- 1-bit input: Active high reset input
		);

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
			CLKFBOUT => pll3_feedback,
			CLKOUT0  => pll3_clko_462,
			CLKOUT1  => open,
			CLKOUT2  => pll3_clko_div7_66,
			CLKOUT3  => pll3_clko_div7_66_second,
			CLKOUT4  => open,
			CLKOUT5  => open,
			LOCKED   => pll3_locked,
			RST      => '0',
			CLKFBIN  => pll3_feedback,
			CLKIN    => dcm3_clko_30
		);

	bufg_inst3 : BUFG
		port map(
			O => pll3_clko_div7_66_global,
			I => pll3_clko_div7_66
		);

	bufpll_inst3 : BUFPLL
		generic map(
			DIVIDE => 7
		)
		port map(
			PLLIN        => pll3_clko_462, -- PLL Clock input
			GCLK         => pll3_clko_div7_66_global, -- Global Clock input
			LOCKED       => pll3_locked, -- Clock0 locked input
			IOCLK        => adcClocks.clk_462_serdes_io, -- Output PLL Clock
			LOCK         => pll3_locked_buf, -- BUFPLL Clock and strobe locked
			serdesstrobe => adcClocks.serdes_strobe_462 -- Output SERDES strobe
		);

	dcm3_reset <= ((not (dcm3_locked) and dcm3_status(2)) or i_rst_ext);

	-------------------------------------------------------------------------------

	DCM_SP_inst_2 : DCM_SP
		generic map(
			CLKDV_DIVIDE       => 2.0,  -- CLKDV divide value (1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5,7,7.5,8,9,10,11,12,13,14,15,16).
			CLKFX_DIVIDE       => 2,    -- Divide value on CLKFX outputs - D - (1-32)
			CLKFX_MULTIPLY     => 25,   -- Multiply value on CLKFX outputs - M - (2-32)
			CLKIN_DIVIDE_BY_2  => FALSE, -- CLKIN divide by two (TRUE/FALSE)
			CLKIN_PERIOD       => 100.0, -- Input clock period specified in nS
			CLKOUT_PHASE_SHIFT => "NONE", -- Output phase shift (NONE, FIXED, VARIABLE)
			CLK_FEEDBACK       => "1X", -- Feedback source (NONE, 1X, 2X)
			DESKEW_ADJUST      => "SOURCE_SYNCHRONOUS", -- SYSTEM_SYNCHRNOUS or SOURCE_SYNCHRONOUS
			PHASE_SHIFT        => 0,    -- Amount of fixed phase shift (-255 to 255)
			STARTUP_WAIT       => FALSE -- Delay config DONE until DCM_SP LOCKED (TRUE/FALSE)
		)
		port map(
			CLK0     => dcm2_feedback,  -- 1-bit output: 0 degree clock output
			CLK180   => open,           -- 1-bit output: 180 degree clock output
			CLK270   => open,           -- 1-bit output: 270 degree clock output
			CLK2X    => open,           -- 1-bit output: 2X clock frequency clock output
			CLK2X180 => open,           -- 1-bit output: 2X clock frequency, 180 degree clock output
			CLK90    => open,           -- 1-bit output: 90 degree clock output
			CLKDV    => open,           -- 1-bit output: Divided clock output
			CLKFX    => dcm2_clko_125,  -- 1-bit output: Digital Frequency Synthesizer output (DFS)
			CLKFX180 => open,           -- 1-bit output: 180 degree CLKFX output
			LOCKED   => dcm2_locked,    -- 1-bit output: DCM_SP Lock Output
			PSDONE   => open,           -- 1-bit output: Phase shift done output
			STATUS   => dcm2_status,    -- 8-bit output: DCM_SP status output
			CLKFB    => dcm2_feedback,  -- 1-bit input: Clock feedback input
			CLKIN    => clk_10m_ext_buffered, -- 1-bit input: Clock input
			DSSEN    => '0',            -- 1-bit input: Unsupported, specify to GND.
			PSCLK    => '0',            -- 1-bit input: Phase shift clock input
			PSEN     => '0',            -- 1-bit input: Phase shift enable
			PSINCDEC => '0',            -- 1-bit input: Phase shift increment/decrement input
			RST      => '0'             --dcm2Reset        		-- 1-bit input: Active high reset input
		);

	o_clk125 <= dcm2_clko_125;

	DCM_CLKGEN_inst : DCM_CLKGEN
		generic map(
			CLKFX_MULTIPLY  => 2,
			CLKFX_DIVIDE    => 8,
			CLKFXDV_DIVIDE  => 16,
			SPREAD_SPECTRUM => "NONE",
			CLKIN_PERIOD    => 33.333333
		)
		port map(
			CLKIN     => dcm1_clko_30,
			RST       => '0',
			FREEZEDCM => '0',           -- ?
			CLKFX     => refClock,
			PROGDATA  => '0',
			PROGEN    => '0',
			PROGCLK   => '0'
		);

	-- p3 : process (dcm2_clko_125)
	-- begin
	-- 	if (rising_edge(dcm2_clko_125)) then
	-- 		debugSync1 <= debug;
	-- 		debugSync2 <= debugSync1;
	-- 		if (clockErrorAdc = '0') then
	-- 			refClockCounter <= refClockCounter + 1;
	-- 			--if(refClockCounter >= 127) then
	-- 			if (refClockCounter >= unsigned(debugSync2.drs4RefClockPeriod)) then
	-- 				refClockCounter <= x"00";
	-- 				-- refClock        <= not(refClock); -- from 125MHz: refClock will be 488.28125 kHz to get 1.000GS 	
	-- 			end if;
	-- 		else
	-- 			refClockCounter <= x"00";
	-- 			-- refClock        <= '0';
	-- 		end if;
	-- 	end if;
	-- end process;

	-------------------------------------------------------------------------------
	process(pll1_clk0_div8_120_global, clockErrorTrigger)
	begin
		if (rising_edge(pll1_clk0_div8_120_global)) then
			reset_i0 <= '0' & reset_i0(reset_i0'length - 1 downto 1);
		end if;
		if (clockErrorTrigger = '1') then
			reset_i0(reset_i0'length - 1 downto 3) <= (others => '1');
		end if;
	end process;

	process(pll3_clko_div7_66_global, clockErrorAdc)
	begin
		if (rising_edge(pll3_clko_div7_66_global)) then
			reset_i1 <= '0' & reset_i1(reset_i1'length - 1 downto 1);
		end if;
		if (clockErrorAdc = '1') then
			reset_i1(reset_i1'length - 1 downto 3) <= (others => '1');
		end if;
	end process;

	process(pll3_clko_div7_66_second, clockErrorAdc)
	begin
		if (rising_edge(pll3_clko_div7_66_second)) then
			reset_i2 <= '0' & reset_i2(reset_i2'length - 1 downto 1);
		end if;
		if (clockErrorAdc = '1') then
			reset_i2(reset_i2'length - 1 downto 3) <= (others => '1');
		end if;
	end process;

	adcClocks.clk_66_serdes_div7        <= pll3_clko_div7_66_global;
	adcClocks.clk_66_serdes_div7_second <= pll3_clko_div7_66_second;
	adcClocks.rst_div7                  <= reset_i1(0);
	adcClocks.rst_div7_second           <= reset_i2(0);

	triggerSerdesClocks.clk_118_serdes_div8 <= pll1_clk0_div8_120_global;
	triggerSerdesClocks.rst_div8            <= reset_i0(0);
	triggerSerdesClocks.asyncReset          <= clockErrorTrigger;
	process(pll1_clko_div16_60, clockErrorTrigger)
	begin
		if (rising_edge(pll1_clko_div16_60)) then
			reset_i3 <= '0' & reset_i3(reset_i3'length - 1 downto 1);
		end if;
		if (clockErrorTrigger = '1') then
			reset_i3(reset_i3'length - 1 downto 3) <= (others => '1');
		end if;
	end process;

end Behavioral;

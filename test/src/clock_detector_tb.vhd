library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity clock_detector_tb is
	generic (runner_cfg : string);
end entity;

architecture RTL of clock_detector_tb is
	constant CLK_PERIOD : time := 100 ns;
	constant EXI_PERIOD : time := 20 ns;
	
	signal i_clk : std_logic := '0';
	signal i_rst : std_logic := '1';

	signal i_detect : std_logic := '0';
	signal o_stable : std_logic; -- @suppress "signal o_stable is never read"
begin
	i_clk <= not i_clk after CLK_PERIOD / 2;
	
	clock_detector : entity work.clock_detector
		generic map(
			G_DETECT_DIV    => 16,
			G_TIMEOUT       => 10,
			G_STABLE_THRESH => 3
		)
		port map(
			i_clk    => i_clk,
			i_rst    => i_rst,
			i_detect => i_detect,
			o_stable => o_stable
		); 
	
	main : process
	begin
		test_runner_setup(runner, runner_cfg);
		
		i_rst <= '1';
		wait for CLK_PERIOD * 10;
		i_rst <= '0';
		wait for CLK_PERIOD * 100;
		
		for j in 0 to 1000 loop
			i_detect <= not i_detect;
			wait for EXI_PERIOD / 2;
		end loop;
		
		wait for CLK_PERIOD * 500;
		
		test_runner_cleanup(runner);
	end process;
end architecture RTL;

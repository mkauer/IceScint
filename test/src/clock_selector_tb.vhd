library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity clock_selector_tb is
	generic(runner_cfg : string);
end entity;

architecture RTL of clock_selector_tb is
	constant CLK_PERIOD : time := 100 ns;

	signal i_clk : std_logic := '0';
	signal i_rst : std_logic := '1';

	signal i_detect : std_logic := '0';
	signal o_select : std_logic;
	signal o_rst    : std_logic;
begin
	i_clk <= not i_clk after CLK_PERIOD / 2;

	clock_selector : entity work.clock_selector
		generic map(
			G_RESET_CYCLES => 15
		)
		port map(
			i_clk    => i_clk,
			i_rst    => i_rst,
			i_detect => i_detect,
			o_select => o_select,
			o_rst    => o_rst
		);

	main : process
	begin
		test_runner_setup(runner, runner_cfg);

		i_rst <= '1';
		wait for CLK_PERIOD * 10;
		i_rst <= '0';
		wait for CLK_PERIOD * 100;

		i_detect <= not i_detect;
		wait for CLK_PERIOD * 50;
		i_detect <= not i_detect;
		wait for CLK_PERIOD * 50;
		i_detect <= not i_detect;
		wait for CLK_PERIOD * 50;

		wait for CLK_PERIOD * 500;

		test_runner_cleanup(runner);
	end process;
end architecture RTL;

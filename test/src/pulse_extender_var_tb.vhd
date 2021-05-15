library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity pulse_extender_var_tb is
	generic(runner_cfg : string);
end entity;

architecture RTL of pulse_extender_var_tb is
	constant CLK_PERIOD : time := 100 ns;

	signal i_clk : std_logic := '1';
	signal i_rst : std_logic := '1';

	signal i_data  : std_logic                    := '0';
	signal i_delay : std_logic_vector(7 downto 0) := x"10";
	signal o_data  : std_logic;
begin
	i_clk <= not i_clk after CLK_PERIOD / 2;

	pulse_extender_var_inst : entity work.pulse_extender_var
		port map(
			i_clk    => i_clk,
			i_rst    => i_rst,
			i_clk_en => '1',
			i_delay  => i_delay,
			i_data   => i_data,
			o_data   => o_data
		);

	main : process
	begin
		test_runner_setup(runner, runner_cfg);

		i_rst <= '1';
		wait for CLK_PERIOD * 10;
		i_rst <= '0';
		wait for CLK_PERIOD * 40;

		i_data <= '1';
		wait for CLK_PERIOD * 3;
		i_data <= '0';

		wait for CLK_PERIOD * 100;

		i_delay <= x"50";
		wait for CLK_PERIOD * 10;

		i_data <= '1';
		wait for CLK_PERIOD * 1;
		i_data <= '0';

		wait for CLK_PERIOD * 100;

		test_runner_cleanup(runner);
	end process;
end architecture RTL;

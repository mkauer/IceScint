library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity timing_gen_tb is
	generic(runner_cfg : string);
end entity;

architecture RTL of timing_gen_tb is
	constant CLK_PERIOD : time := 8 ns;

	signal i_clk     : std_logic                     := '1';
	signal i_rst     : std_logic                     := '1';
	signal i_pps     : std_logic                     := '0';
	signal i_sec_day : std_logic_vector(16 downto 0) := "10010010010101010";
	signal o_timing  : std_logic;
begin
	i_clk <= not i_clk after CLK_PERIOD / 2;

	timing_gen_inst : entity work.timing_gen
		port map(
			i_clk     => i_clk,
			i_rst     => i_rst,
			i_pps     => i_pps,
			i_sec_day => i_sec_day,
			o_timing  => o_timing
		);

	main : process
	begin
		test_runner_setup(runner, runner_cfg);

		i_rst <= '1';
		wait for CLK_PERIOD * 10;
		i_rst <= '0';

		wait for CLK_PERIOD * 5000;

		test_runner_cleanup(runner);
	end process;
end architecture RTL;

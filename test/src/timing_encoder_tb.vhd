library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity timing_encoder_tb is
	generic(runner_cfg : string);
end entity;

architecture RTL of timing_encoder_tb is
	constant CLK_PERIOD : time := 10 ns;

	signal i_clk     : std_logic := '1';
	signal i_rst     : std_logic := '1';
	signal i_data    : std_logic := '0';
	signal i_valid   : std_logic := '0';
	signal o_ready   : std_logic;
	signal o_encoded : std_logic;
begin
	i_clk <= not i_clk after CLK_PERIOD / 2;

	timing_gen_inst : entity work.timing_encoder
		generic map(
			G_OVERSAMPLING => 4,
			G_REGULAR      => 4
		)
		port map(
			i_clk     => i_clk,
			i_rst     => i_rst,
			i_data    => i_data,
			i_valid   => i_valid,
			o_ready   => o_ready,
			o_encoded => o_encoded
		);

	main : process
		variable message : std_logic_vector(15 downto 0) := "0110101101101011";
		variable counter : natural                       := 0;
	begin
		test_runner_setup(runner, runner_cfg);

		i_rst <= '1';
		wait for CLK_PERIOD * 10;
		i_rst <= '0';
		wait for CLK_PERIOD * 10;

		i_valid <= '1';
		while counter <= message'high loop
			i_data <= message(counter);
			wait for CLK_PERIOD;
			if o_ready then
				counter := counter + 1;
			end if;
		end loop;
		i_valid <= '0';
		wait for CLK_PERIOD * 50;

		test_runner_cleanup(runner);
	end process;
end architecture RTL;

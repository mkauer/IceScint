library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity udaq_uart_tb is
	generic(runner_cfg : string);
end entity;

architecture RTL of udaq_uart_tb is
	constant CLK_PERIOD : time := 10 ns;

	signal i_clk : std_logic := '1';
	signal i_rst : std_logic := '1';

	signal i_tx_valid    : std_logic                    := '0';
	signal i_tx_data     : std_logic_vector(7 downto 0) := x"XX";
	signal o_tx_ready    : std_logic;
	signal o_rx_data     : std_logic_vector(7 downto 0);
	signal o_rx_valid    : std_logic;
	signal i_rx_ready    : std_logic                    := '1';
	signal o_rx_overflow : std_logic;
	signal i_loopback_en : std_logic                    := '1';
	signal uart          : std_logic;
	signal o_rs485_en    : std_logic;
begin
	i_clk <= not i_clk after CLK_PERIOD / 2;

	udaq_rs485 : entity work.udaq_rs485
		generic map(
			G_CLK_FREQ  => 100000000,
			G_BAUD_RATE => 3000000
		)
		port map(
			i_clk         => i_clk,
			i_rst         => i_rst,
			i_tx_data     => i_tx_data,
			i_tx_valid    => i_tx_valid,
			o_tx_ready    => o_tx_ready,
			o_rx_data     => o_rx_data,
			o_rx_valid    => o_rx_valid,
			i_rx_ready    => i_rx_ready,
			o_rx_overflow => o_rx_overflow,
			i_loopback_en => i_loopback_en,
			o_rs485_tx    => uart,
			o_rs485_en    => o_rs485_en,
			i_rs485_rx    => uart
		);

	main : process
	begin
		test_runner_setup(runner, runner_cfg);

		i_rst <= '1';
		wait for CLK_PERIOD * 10;
		i_rst <= '0';
		wait for CLK_PERIOD * 40;

		i_tx_valid <= '1';
		i_tx_data  <= x"55";
		wait for CLK_PERIOD * 5;
		i_tx_valid <= '0';
		i_tx_data  <= x"XX";

		wait for CLK_PERIOD * 5000;

		test_runner_cleanup(runner);
	end process;
end architecture RTL;

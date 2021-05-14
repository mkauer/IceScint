library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.types.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity registers_icescint_tb is
	generic(runner_cfg : string);
end entity;

architecture RTL of registers_icescint_tb is
	constant CLK_PERIOD : time := 10.0 ns;
	constant STROBE     : time := 60.0 ns;

	signal i_clk : std_logic := '0';
	signal i_rst : std_logic := '1';

	signal read  : std_logic := '1';
	signal write : std_logic := '1';
	signal cs    : std_logic := '1';

	signal reg_reading, reg_read, reg_write : std_logic;
	signal reg_addr, reg_data               : std_logic_vector(15 downto 0);

	signal regs2user : regs2user_t;
	signal user2regs : user2regs_t;

	signal addr : std_logic_vector(15 downto 0) := x"XXXX";
	signal data : std_logic_vector(15 downto 0) := x"XXXX";
begin
	i_clk <= not i_clk after CLK_PERIOD / 2;

	sync_inst : entity work.register_sync
		generic map(
			G_INVERT_RWCS => true,
			G_DATA_WIDTH  => 16,
			G_ADDR_WIDTH  => 16,
			G_GUARD_FFS   => 1
		)
		port map(
			o_reading   => reg_reading,
			o_read      => reg_read,
			o_write     => reg_write,
			o_addr      => reg_addr,
			o_data      => reg_data,
			i_clk       => i_clk,
			i_rst       => i_rst,
			i_ebi_read  => read,
			i_ebi_write => write,
			i_ebi_cs    => cs,
			i_ebi_addr  => addr,
			i_ebi_data  => data
		);

	reg_inst : entity work.registers_icescint
		port map(
			i_clk       => i_clk,
			i_rst       => i_rst,
			i_reading   => reg_reading,
			i_read      => reg_read,
			i_write     => reg_write,
			i_ebi_addr  => reg_addr,
			i_ebi_data  => reg_data,
			i_user2regs => user2regs,
			o_regs2user => regs2user
		);

	main : process
		procedure write_register(p_addr : register_t; p_data : register_t) is
		begin
			addr  <= p_addr;
			data  <= p_data;
			cs    <= '0';
			write <= '0';
			wait for STROBE;
			addr  <= x"XXXX";
			data  <= x"XXXX";
			cs    <= '1';
			write <= '1';
			wait for STROBE;
		end procedure;

		procedure read_register(p_addr : register_t) is
		begin
			addr <= p_addr;
			cs   <= '0';
			read <= '0';
			wait for STROBE;
			addr <= x"XXXX";
			cs   <= '1';
			read <= '1';
			wait for STROBE;
		end procedure;
	begin
		test_runner_setup(runner, runner_cfg);

		user2regs.udaq_tx_ready    <= x"ff";
		user2regs.udaq_rx_valid    <= x"00";
		user2regs.udaq_rx_overflow <= x"00";

		i_rst <= '1';
		wait for CLK_PERIOD * 10;
		i_rst <= '0';
		wait for CLK_PERIOD * 30;

		user2regs.udaq_rx_data(0) <= x"50";
		user2regs.udaq_rx_valid   <= x"01";
		wait for CLK_PERIOD;
		user2regs.udaq_rx_valid   <= x"00";

		write_register(x"0102", x"0355");

		read_register(x"0110");
		read_register(x"0110");

		wait for CLK_PERIOD * 50;

		test_runner_cleanup(runner);
	end process;
end architecture RTL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity register_timing_tb is
	generic(runner_cfg : string);
end entity;

architecture RTL of register_timing_tb is
	constant CLK_PERIOD : time := 10.0 ns;
	constant STROBE     : time := 60.0 ns;

	signal i_clk : std_logic := '0';
	signal i_rst : std_logic := '1';

	signal read  : std_logic := '1';
	signal write : std_logic := '1';
	signal cs    : std_logic := '1';

	signal addr : std_logic_vector(5 downto 0) := "XXXXXX";
	signal data : std_logic_vector(3 downto 0) := "XXXX";
begin
	i_clk <= not i_clk after CLK_PERIOD / 2;

	sync_inst : entity work.register_sync
		generic map(
			G_INVERT_RWCS => true,
			G_DATA_WIDTH  => 4,
			G_ADDR_WIDTH  => 4,
			G_GUARD_FFS   => 1,
			G_BANK        => "00"
		)
		port map(
			i_clk       => i_clk,
			i_rst       => i_rst,
			i_ebi_read  => read,
			i_ebi_write => write,
			i_ebi_cs    => cs,
			i_ebi_addr  => addr(3 downto 0),
			i_ebi_data  => data,
			i_ebi_bank  => addr(5 downto 4)
		);

	main : process
	begin
		test_runner_setup(runner, runner_cfg);

		i_rst <= '1';
		wait for CLK_PERIOD * 10;
		i_rst <= '0';
		wait for CLK_PERIOD * 30.5;

		-- write to this bank
		addr  <= "001010";
		data  <= "1010";
		cs    <= '1';
		write <= '1';
		wait for STROBE;
		addr  <= "XXXXXX";
		data  <= "XXXX";
		cs    <= '0';
		write <= '0';

		wait for CLK_PERIOD * 10;

		-- write to other bank
		addr  <= "011010";
		data  <= "1010";
		cs    <= '1';
		write <= '1';
		wait for STROBE;
		addr  <= "XXXXXX";
		data  <= "XXXX";
		cs    <= '0';
		write <= '0';

		wait for CLK_PERIOD * 10;

		-- read from this bank
		addr <= "001010";
		cs   <= '1';
		read <= '1';
		wait for STROBE;
		addr <= "XXXXXX";
		cs   <= '0';
		read <= '0';

		wait for CLK_PERIOD * 10;

		-- read from other bank
		addr <= "011010";
		cs   <= '1';
		read <= '1';
		wait for STROBE;
		addr <= "XXXXXX";
		cs   <= '0';
		read <= '0';

		wait for CLK_PERIOD * 50;

		test_runner_cleanup(runner);
	end process;
end architecture RTL;

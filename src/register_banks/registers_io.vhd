library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.types.regs2user_io_t;
use work.types.user2regs_io_t;
use work.types.register_t;

entity registers_io is
	port(
		i_clk       : in  std_logic;
		i_rst       : in  std_logic;
		-- EBI interface
		i_read      : in  std_logic;    -- synchronized to clock
		i_write     : in  std_logic;
		i_ebi_addr  : in  std_logic_vector(15 downto 0);
		i_ebi_data  : in  std_logic_vector(15 downto 0);
		o_ebi_data  : out std_logic_vector(15 downto 0);
		-- user interface
		i_user2regs : in  user2regs_io_t;
		o_regs2user : out regs2user_io_t
	);
end entity registers_io;

architecture RTL of registers_io is
	subtype address_t is std_logic_vector(15 downto 0);

	constant ADDR_TEST   : address_t := x"0000";
	constant ADDR_CLOCKS : address_t := x"0002";

	signal write_pulse : std_logic;
	signal read_pulse  : std_logic;

	signal reg_test : register_t := x"0000";
begin
	-- READ and WRITE signals --------------------------------------------------

	edge_write : entity work.edge_detector
		generic map(
			G_EDGE_TYPE  => "RISING",
			G_INIT_LEVEL => '0'
		)
		port map(
			i_clk   => i_clk,
			i_reset => i_rst,
			i_ce    => '1',
			i_data  => i_write,
			o_edge  => write_pulse
		);

	edge_read : entity work.edge_detector
		generic map(
			G_EDGE_TYPE  => "RISING",
			G_INIT_LEVEL => '0'
		)
		port map(
			i_clk   => i_clk,
			i_reset => i_rst,
			i_ce    => '1',
			i_data  => i_read,
			o_edge  => read_pulse
		);

	-- READ multiplexer --------------------------------------------------------

	with i_ebi_addr select o_ebi_data <=
		reg_test when x"0000",
		(
			0      => i_user2regs.clk_detect_wr,
			1      => i_user2regs.clk_detect_gps,
			2      => i_user2regs.clk_detect_ebi,
			others => '0'
		) when ADDR_CLOCKS,
		x"dead" when others;

	-- WRITE registers ---------------------------------------------------------

	p_write : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				reg_test <= x"0000";
			else
				if i_write = '1' then
					case i_ebi_addr is
						when ADDR_TEST => reg_test <= i_ebi_data;
						when others    => null;
					end case;

				end if;
			end if;
		end if;
	end process;

end architecture RTL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_divider is
	generic(
		G_RATIO : natural range 2 to natural'high
	);
	port(
		i_clk : in  std_logic;
		i_rst : in  std_logic;
		i_en  : in  std_logic;
		o_en  : out std_logic := '0'
	);
end entity clock_divider;

architecture RTL of clock_divider is

begin

end architecture RTL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_selector is
	generic(
		G_RESET_CYCLES : natural := 15
	);
	port(
		i_clk    : in  std_logic;
		i_rst    : in  std_logic;
		i_detect : in  std_logic;
		o_select : out std_logic;
		o_rst    : out std_logic
	);
end entity clock_selector;

architecture RTL of clock_selector is
	signal clock_select : std_logic;
begin
	o_select <= clock_select;

	p_sys_clock : process(i_clk)
		variable reset_counter : natural range 0 to G_RESET_CYCLES := G_RESET_CYCLES;
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				o_rst         <= '1';
				clock_select  <= '0';
				reset_counter := G_RESET_CYCLES;
			else
				if i_detect /= clock_select then
					o_rst         <= '1';
					clock_select  <= i_detect;
					reset_counter := G_RESET_CYCLES;
				else
					if reset_counter > 0 then
						o_rst         <= '1';
						reset_counter := reset_counter - 1;
					else
						o_rst <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;
end architecture RTL;

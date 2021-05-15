library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pulse_extender_var is
	port(
		i_clk    : in  std_logic;
		i_rst    : in  std_logic;
		i_clk_en : in  std_logic;
		i_delay  : in  std_logic_vector;
		i_data   : in  std_logic;
		o_data   : out std_logic
	);
end entity;

architecture RTL of pulse_extender_var is
	signal counter : unsigned(i_delay'range);
begin
	p_output : process(i_clk) is
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				o_data <= '0';
			else
				if counter = 0 then
					o_data <= i_data;
				else
					o_data <= '1';
				end if;
			end if;
		end if;
	end process;

	p_count : process(i_clk) is
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				counter <= (others => '0');
			else
				if i_data = '1' then
					counter <= unsigned(i_delay);
				elsif i_clk_en = '1' and counter > 0 then
					counter <= counter - 1;
				end if;
			end if;
		end if;
	end process;
end architecture RTL;

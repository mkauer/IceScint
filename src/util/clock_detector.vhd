library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_detector is
	generic(
		G_DETECT_DIV    : positive := 1;    -- internal divider for i_detect
		G_TIMEOUT       : positive := 1000; -- max delay between two edges of the divided i_detect
		G_STABLE_THRESH : positive := 5     -- minimum number of valid edges before o_active is asserted
	);
	port(
		i_clk : in std_logic;
		i_rst : in std_logic;
		
		i_detect : in  std_logic;
		o_stable : out std_logic
	);
end entity;

architecture RTL of clock_detector is
	signal ext_toggle : std_logic := '0';
	signal ext_toggle_sync : std_logic;
	signal ext_toggle_edge : std_logic;
begin

	p_ext : process(i_detect)
		constant RELOAD : natural := G_DETECT_DIV - 1;
		variable counter : integer range 0 to RELOAD := RELOAD;
	begin
		if rising_edge(i_detect) then
			if counter = 0 then
				ext_toggle <= not ext_toggle;
				counter := RELOAD;
			else
				counter := counter - 1;
			end if;
		end if;
	end process;
	
	sync_inst : entity work.synchronizer
		generic map(
			G_INIT_VALUE => '0',
			G_NUM_GUARD_FFS => 2
		)
		port map(
			i_reset => i_rst,
			i_clk => i_clk,
			i_data => ext_toggle,
			o_data => ext_toggle_sync
		);
	
	edge_inst : entity work.edge_detector
		generic map(
			G_EDGE_TYPE => "BOTH",
			G_INIT_LEVEL => '0'
		)
		port map(
			i_clk => i_clk,
			i_reset => i_rst,
			i_ce => '1',
			i_data => ext_toggle_sync,
			o_edge => ext_toggle_edge
		);
	
	p_sys : process(i_clk)
		variable active      : boolean                            := false;
		variable timeout_ctr : natural range 0 to G_TIMEOUT       := G_TIMEOUT;
		variable stable_ctr  : natural range 0 to G_STABLE_THRESH := G_STABLE_THRESH;
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				o_stable    <= '0';
				active      := false;
				timeout_ctr := G_TIMEOUT;
				stable_ctr  := G_STABLE_THRESH;
			else
				o_stable <= '1' when active and stable_ctr = 0 else '0'; 
				-- count down stable counter at each edge when active
				if active then
					if ext_toggle_edge = '1' and stable_ctr > 0 then
						stable_ctr := stable_ctr - 1;
					end if;
				else
					stable_ctr := G_STABLE_THRESH;
				end if;
				-- check if signal toggles before timeout elapses
				if ext_toggle_edge = '1' then
					active := timeout_ctr /= 0;
					timeout_ctr := G_TIMEOUT;
				elsif timeout_ctr /= 0 then
					timeout_ctr := timeout_ctr - 1;
				else
					active := false;
				end if;
			end if;
		end if;
	end process;

end architecture RTL;

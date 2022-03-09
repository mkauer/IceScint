library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timing_encoder is
	generic(
		G_OVERSAMPLING : natural := 4;
		G_REGULAR      : natural := 4
	);
	port(
		i_clk     : in  std_logic;
		i_rst     : in  std_logic;
		-- data input
		i_data    : in  std_logic;
		i_valid   : in  std_logic;
		o_ready   : out std_logic;
		-- encoded output
		o_encoded : out std_logic
	);
end entity timing_encoder;

architecture RTL of timing_encoder is
	signal encoded : std_ulogic := '0';
	signal ready   : std_ulogic := '0';

	signal dbg_regular : std_logic := '0';
	signal dbg_data    : std_logic := '0';
begin
	o_encoded <= encoded;
	o_ready   <= ready;

	p_main : process(i_clk)
		variable idle    : boolean := true;
		variable ctr_os  : integer range 0 to G_OVERSAMPLING - 1;
		variable ctr_reg : integer range 0 to G_REGULAR - 1;
	begin
		if rising_edge(i_clk) then
			dbg_regular <= '0';
			dbg_data    <= '0';
			if i_rst = '1' then
				idle    := true;
				ctr_os  := 0;
				ctr_reg := 0;
				encoded <= '0';
				ready   <= '0';
			else
				if idle then
					ready   <= '0';
					ctr_os  := 0;
					ctr_reg := 0;
					if i_valid = '1' then
						encoded <= not encoded;
						idle    := false;
					end if;
				else
					-- ready output, set this high before the next edge
					if ctr_os = G_OVERSAMPLING - 2 and ctr_reg /= G_REGULAR - 1 then
						ready <= '1';
					else
						ready <= '0';
					end if;
					-- encoded data
					if ctr_os = G_OVERSAMPLING - 1 then
						ctr_os := 0;
						if ctr_reg /= G_REGULAR - 1 then
							ctr_reg := ctr_reg + 1;
						else
							ctr_reg := 0;
						end if;
						if ready = '1' then
							-- ready -> output next bit
							if i_valid = '1' then
								encoded  <= i_data;
								dbg_data <= '1';
							else
								idle  := true;
								ready <= '1';
							end if;
						else
							-- not ready -> output regular clock edge
							encoded     <= not encoded;
							dbg_regular <= '1';
						end if;
					else
						ctr_os := ctr_os + 1;
					end if;
				end if;
			end if;
		end if;
	end process;

end architecture RTL;

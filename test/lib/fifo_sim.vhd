library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.types.slv8_array_t;

ENTITY fifo_sim IS
	PORT(
		clk   : IN  STD_LOGIC;
		srst  : IN  STD_LOGIC;
		din   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		wr_en : IN  STD_LOGIC;
		rd_en : IN  STD_LOGIC;
		dout  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		full  : OUT STD_LOGIC;
		empty : OUT STD_LOGIC;
		valid : OUT STD_LOGIC
	);
END;

architecture SIM of fifo_sim is
	signal data : slv8_array_t(0 to 15);
begin
	p : process(clk)
		variable is_full : std_logic;
		variable p_write : natural range data'range;
		variable p_read  : natural range data'range;

		procedure inc(var : inout natural) is
		begin
			var := var + 1;
			if var > data'high then
				var := 0;
			end if;
		end procedure;
	begin
		if rising_edge(clk) then
			if srst = '1' then
				p_write := 0;
				p_read  := 0;
				data    <= (others => x"XX");
				dout    <= x"XX";
				full    <= '0';
				empty   <= '1';
				valid   <= '0';
			else
				if rd_en = '1' then
					assert is_full = '1' report "read from empty fifo" severity failure;
					is_full := '0';
					dout    <= x"XX";
				end if;
				if wr_en = '1' then
					assert is_full = '0' report "write to full fifo" severity failure;
					is_full := '1';
					dout    <= din;
				end if;
				full  <= '1' when p_read = p_write else '0';
				empty <= '1' when p_read = p_write else '0';
				valid <= '1' when data(p_read) /= x"ff" else '0';
				dout  <= data(p_read);
			end if;
		end if;
	end process;
end architecture;

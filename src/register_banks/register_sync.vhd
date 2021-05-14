library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity register_sync is
	generic(
		G_INVERT_RWCS : boolean          := true;
		G_DATA_WIDTH  : natural          := 16;
		G_ADDR_WIDTH  : natural          := 16;
		G_GUARD_FFS   : positive         := 1;
		G_BANK        : std_logic_vector := ""
	);
	port(
		i_clk       : in  std_logic;
		i_rst       : in  std_logic;
		-- from pins
		i_ebi_read  : in  std_logic;
		i_ebi_write : in  std_logic;
		i_ebi_cs    : in  std_logic;
		i_ebi_addr  : in  std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
		i_ebi_data  : in  std_logic_vector(G_DATA_WIDTH - 1 downto 0);
		i_ebi_bank  : in  std_logic_vector(G_BANK'range);
		-- to register bank
		o_reading   : out std_logic;    -- high during a read -> do not update registers
		o_read      : out std_logic;    -- pulsed at the end of the read strobe
		o_write     : out std_logic;    -- pulsed
		o_addr      : out std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
		o_data      : out std_logic_vector(G_DATA_WIDTH - 1 downto 0)
	);
end entity register_sync;

architecture RTL of register_sync is

	function SYNC_INIT return std_logic is
	begin
		if G_INVERT_RWCS then
			return ('1');
		else
			return ('0');
		end if;
	end function SYNC_INIT;

	signal bank_sync  : std_logic_vector(G_BANK'range);
	signal read_sync  : std_logic;
	signal write_sync : std_logic;
	signal cs_sync    : std_logic;

	signal selected  : std_logic;
	signal read_sel  : std_logic;
	signal write_sel : std_logic;

	signal addr_sync : std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
begin
	sync_bank : entity work.vector_synchronizer
		generic map(
			G_DATA_WIDTH    => G_BANK'length,
			G_INIT_VALUE    => (others => '0'),
			G_NUM_GUARD_FFS => G_GUARD_FFS
		)
		port map(
			i_reset => i_rst,
			i_clk   => i_clk,
			i_data  => i_ebi_bank,
			o_data  => bank_sync
		);

	sync_read : entity work.synchronizer
		generic map(
			G_INIT_VALUE    => SYNC_INIT,
			G_NUM_GUARD_FFS => G_GUARD_FFS
		)
		port map(
			i_reset => i_rst,
			i_clk   => i_clk,
			i_data  => i_ebi_read,
			o_data  => read_sync
		);

	sync_write : entity work.synchronizer
		generic map(
			G_INIT_VALUE    => SYNC_INIT,
			G_NUM_GUARD_FFS => G_GUARD_FFS + 1 -- more delay so addr and data can settle
		)
		port map(
			i_reset => i_rst,
			i_clk   => i_clk,
			i_data  => i_ebi_write,
			o_data  => write_sync
		);

	sync_cs : entity work.synchronizer
		generic map(
			G_INIT_VALUE    => SYNC_INIT,
			G_NUM_GUARD_FFS => G_GUARD_FFS
		)
		port map(
			i_reset => i_rst,
			i_clk   => i_clk,
			i_data  => i_ebi_cs,
			o_data  => cs_sync
		);

	p_selected : process(all)
	begin
		if (cs_sync = '1' and bank_sync = G_BANK) then
			selected <= '1';
		else
			selected <= '0';
		end if;
	end process;

	read_sel  <= read_sync and selected;
	write_sel <= write_sync and selected;

	-- read / write outputs

	o_reading <= read_sel;

	edge_read : entity work.edge_detector
		generic map(
			G_EDGE_TYPE  => "FALLING",
			G_INIT_LEVEL => '0'
		)
		port map(
			i_clk   => i_clk,
			i_reset => i_rst,
			i_ce    => '1',
			i_data  => read_sel,
			o_edge  => o_read
		);

	edge_write : entity work.edge_detector
		generic map(
			G_EDGE_TYPE  => "RISING",
			G_INIT_LEVEL => '0'
		)
		port map(
			i_clk   => i_clk,
			i_reset => i_rst,
			i_ce    => '1',
			i_data  => write_sel,
			o_edge  => o_write
		);

	-- address synchronizer

	sync_addr : entity work.vector_synchronizer
		generic map(
			G_DATA_WIDTH    => G_ADDR_WIDTH,
			G_INIT_VALUE    => (others => '0'),
			G_NUM_GUARD_FFS => G_GUARD_FFS
		)
		port map(
			i_reset => i_rst,
			i_clk   => i_clk,
			i_data  => i_ebi_addr,
			o_data  => addr_sync
		);

	p_addr : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				o_addr <= (others => '0');
			else
				if selected = '1' then
					o_addr <= addr_sync;
				end if;
			end if;
		end if;
	end process;

	-- data synchronizer

	sync_data : entity work.vector_synchronizer
		generic map(
			G_DATA_WIDTH    => G_DATA_WIDTH,
			G_INIT_VALUE    => (others => '0'),
			G_NUM_GUARD_FFS => 1
		)
		port map(
			i_reset => i_rst,
			i_clk   => i_clk,
			i_data  => i_ebi_data,
			o_data  => o_data
		);

		-- read and write signals

end architecture RTL;

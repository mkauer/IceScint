library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.types.all;

entity registers_icescint is
	port(
		i_clk       : in  std_logic;
		i_rst       : in  std_logic;
		-- EBI interface
		i_reading   : in  std_logic;
		i_read      : in  std_logic;
		i_write     : in  std_logic;
		i_ebi_addr  : in  std_logic_vector(15 downto 0);
		i_ebi_data  : in  std_logic_vector(15 downto 0);
		o_ebi_data  : out std_logic_vector(15 downto 0);
		-- user interface
		i_user2regs : in  user2regs_t;
		o_regs2user : out regs2user_t
	);
end entity;

architecture RTL of registers_icescint is
	signal write_pulse : std_logic;
	signal read_pulse  : std_logic;

	signal ebi_addr   : integer;
	signal ebi_addr_3 : integer;

	-- ONLY USE EVEN ADDRESSES
	constant ADDR_SYS_CLOCK_SOURCE : integer := 16#0010#;

	constant ADDR_UDAQ_STATUS  : integer := 16#0100#;
	constant ADDR_UDAQ_TX      : integer := 16#0102#;
	constant ADDR_UDAQ_FLAGS   : integer := 16#0104#;
	constant ADDR_UDAQ_RX_LOW  : integer := 16#0110#; -- 8 registers from here
	constant ADDR_UDAQ_RX_HIGH : integer := 16#011f#;

	constant ADDR_TEST_1   : integer := 16#f554#;
	constant ADDR_TEST_2   : integer := 16#faaa#;
	constant ADDR_TEST_SUM : integer := 16#f000#;

	signal reg_sys_clock_source : register_t;

	signal reg_udaq_status : register_t;

	signal reg_udaq_flags       : register_t;
	signal reg_udaq_flags_clear : std_logic;
	alias reg_udaq_flags_tx_full is reg_udaq_flags(15 downto 8);
	alias reg_udaq_flags_rx_overflow is reg_udaq_flags(7 downto 0);
	signal reg_udaq_rx          : register_array_t(NUM_uDAQ - 1 downto 0);
	signal reg_udaq_tx          : register_t;
	alias reg_udaq_tx_valid is reg_udaq_tx(15 downto 8);
	alias reg_udaq_tx_data is reg_udaq_tx(7 downto 0);

	signal reg_test_1   : register_t := x"0000";
	signal reg_test_2   : register_t := x"0000";
	signal reg_test_sum : register_t;

	signal udaq_rx_data     : slv8_array_t(NUM_uDAQ - 1 downto 0);
	signal udaq_rx_valid    : std_logic_vector(NUM_uDAQ - 1 downto 0);
	signal udaq_rx_overflow : std_logic_vector(NUM_uDAQ - 1 downto 0);

	signal test : std_logic := '0';
begin

	ebi_addr   <= to_integer(unsigned(i_ebi_addr(i_ebi_addr'left downto 1) & '0'));
	ebi_addr_3 <= to_integer(unsigned(i_ebi_addr(3 downto 1)));

	-- uDAQs -------------------------------------------------------------------

	-- registers are ready to accept new data when
	-- the ARM processor is not currently reading
	-- there is no data in the register already
	p_udaq_ready : process(i_reading, udaq_rx_valid)
	begin
		if i_reading = '1' then
			o_regs2user.udaq_rx_ready <= (others => '0');
		else
			o_regs2user.udaq_rx_ready <= not udaq_rx_valid;
		end if;
	end process;

	o_regs2user.udaq_tx_data  <= reg_udaq_tx_data;
	o_regs2user.udaq_tx_valid <= reg_udaq_tx_valid;

	gen_udaq_rx_data : for i in reg_udaq_rx'range generate
		reg_udaq_rx(i)(15 downto 8) <= udaq_rx_valid;
		reg_udaq_rx(i)(7 downto 0)  <= udaq_rx_data(i);
	end generate;

	p_udaq_rx : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				udaq_rx_data  <= (others => (others => '0'));
				udaq_rx_valid <= (others => '0');
			else
				for i in reg_udaq_rx'range loop
					if i_reading = '0' then
						if udaq_rx_valid(i) = '1' then
							if i_read = '1' and ebi_addr = (ADDR_UDAQ_RX_LOW + 2 * i) then
								udaq_rx_valid(i) <= '0';
							end if;
						else
							if i_user2regs.udaq_rx_valid(i) = '1' then
								udaq_rx_valid(i) <= '1';
								udaq_rx_data(i)  <= i_user2regs.udaq_rx_data(i);
							end if;
						end if;
					end if;
				end loop;
			end if;
		end if;
	end process;

	p_udaq_flags : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				udaq_rx_overflow <= (others => '0');
				reg_udaq_flags   <= (others => '0');
				reg_udaq_status  <= (others => '0');
			else
				if i_reading = '1' then
					-- remember overflow flag during read cycle
					udaq_rx_overflow <= udaq_rx_overflow or i_user2regs.udaq_rx_overflow;
				else
					reg_udaq_status(7 downto 0) <= udaq_rx_valid;
					reg_udaq_flags_tx_full      <= not i_user2regs.udaq_tx_ready;
					udaq_rx_overflow            <= i_user2regs.udaq_rx_overflow; -- do not remember overflow flag
					if reg_udaq_flags_clear = '1' then
						reg_udaq_flags_rx_overflow <= (others => '0');
					else
						reg_udaq_flags_rx_overflow <= reg_udaq_flags_rx_overflow or udaq_rx_overflow;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- READ registers  ---------------------------------------------------------

	reg_sys_clock_source <= (
		0      => i_user2regs.sys_clock_source,
		others => '0'
	);

	reg_test_sum <= std_logic_vector(unsigned(reg_test_1) + unsigned(reg_test_2));

	-- READ multiplexer --------------------------------------------------------

	with ebi_addr select o_ebi_data <=
		reg_sys_clock_source when ADDR_SYS_CLOCK_SOURCE,
		-- uDAQ registers
		reg_udaq_status when ADDR_UDAQ_STATUS,
		reg_udaq_flags when ADDR_UDAQ_FLAGS,
		reg_udaq_tx when ADDR_UDAQ_TX,
		reg_udaq_rx(ebi_addr_3) when ADDR_UDAQ_RX_LOW to ADDR_UDAQ_RX_HIGH,
		-- TEST registers
		reg_test_1 when ADDR_TEST_1,
		reg_test_2 when ADDR_TEST_2,
		reg_test_sum when ADDR_TEST_SUM,
		x"dead" when others;

	-- WRITE registers ---------------------------------------------------------

	p_write : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				reg_udaq_tx          <= x"0000";
				reg_test_1           <= x"0000";
				reg_test_2           <= x"0000";
				reg_udaq_flags_clear <= '0';
			else
				reg_udaq_flags_clear <= '0';
				reg_udaq_tx_valid    <= reg_udaq_tx_valid and (not i_user2regs.udaq_tx_ready);
				if i_write = '1' then
					case ebi_addr is
						when ADDR_UDAQ_TX    => reg_udaq_tx <= i_ebi_data;
						when ADDR_UDAQ_FLAGS => reg_udaq_flags_clear <= '1';
						when ADDR_TEST_1     => reg_test_1 <= i_ebi_data;
						when ADDR_TEST_2     => reg_test_2 <= i_ebi_data;
						when others          => null;
					end case;
				end if;
			end if;
		end if;
	end process;

end architecture RTL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timing_gen is
	port(
		i_clk     : in  std_logic;      -- 125 MHz reference clock
		i_rst     : in  std_logic;
		-- timing input
		i_pps     : in  std_logic;
		i_sec_day : in  std_logic_vector(16 downto 0);
		-- timing output
		o_timing  : out std_logic
	);
end entity timing_gen;

architecture RTL of timing_gen is
	constant US_COUNT        : natural                         := 1_000_000;
	constant US_COUNT_LENGTH : natural                         := 20;
	signal us_counter        : integer range 0 to US_COUNT - 1 := 0;
	signal msg_start         : std_logic                       := '0';
	signal enc_valid         : std_logic                       := '0';
	signal enc_ready         : std_logic;
	constant MSG_DATA_LENGTH : natural                         := i_sec_day'length + US_COUNT_LENGTH;
	signal msg_data          : std_logic_vector(MSG_DATA_LENGTH - 1 downto 0);
	signal msg_checksum      : std_logic_vector(3 downto 0);
	constant MSG_LENGTH      : natural                         := MSG_DATA_LENGTH + 4 + 1;
	signal msg               : std_logic_vector(MSG_LENGTH downto 0);
begin

	p_subsec : process(i_clk)
		constant SUBUS_CNT     : natural                          := 125;
		variable subus_counter : natural range 0 to SUBUS_CNT - 1 := 0;
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				subus_counter := 0;
				us_counter    <= 0;
				msg_start     <= '0';
			else
				if i_pps = '1' then
					subus_counter := 0;
					us_counter    <= 0;
					msg_start     <= '1';
				else
					msg_start <= '0';
					if subus_counter = (SUBUS_CNT - 1) then
						subus_counter := 0;
						assert us_counter < US_COUNT report "us counter overflowed" severity failure;
						us_counter    <= us_counter + 1;
						msg_start     <= '1';
					else
						subus_counter := subus_counter + 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	encoder : entity work.timing_encoder
		generic map(
			G_OVERSAMPLING => 2,
			G_REGULAR      => 9
		)
		port map(
			i_clk     => i_clk,
			i_rst     => i_rst,
			i_data    => msg(msg'left),
			i_valid   => enc_valid,
			o_ready   => enc_ready,
			o_encoded => o_timing
		);

	msg_data <= i_sec_day & std_logic_vector(to_unsigned(us_counter, 20));

	p_checksum : process(msg_data)
		variable checksum  : unsigned(4 downto 0);
		variable index     : natural;
		variable index_top : natural;
	begin
		checksum     := (others => '0');
		index        := 0;
		while index < msg_data'length loop
			index_top := index + 3;
			if index_top > msg_data'left then
				index_top := msg_data'left;
			end if;
			checksum  := ("0" & checksum(3 downto 0)) + unsigned(msg_data(index_top downto index)) + checksum(4);
			index     := index + 4;
		end loop;
		while checksum(4) = '1' loop
			checksum := ("0" & checksum(3 downto 0)) + checksum(4);
		end loop;
		msg_checksum <= std_logic_Vector(checksum(3 downto 0));
	end process;

	p_msg : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				enc_valid <= '0';
				msg       <= (others => '0');
			else
				if enc_valid = '1' then
					if enc_ready = '1' then
						msg <= msg(msg'left - 1 downto 0) & "0";
						if unsigned(msg(msg'left - 2 downto 0)) = 0 then
							enc_valid <= '0';
						end if;
					end if;
				else
					if msg_start = '1' then
						-- data, checksum, zero, sentinel
						msg       <= msg_data & msg_checksum & "0" & "1";
						enc_valid <= '1';
					else
						enc_valid <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;
end architecture RTL;

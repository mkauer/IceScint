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
	signal two_us_counter : integer range 0 to 499_999 := 0;
	signal msg_start      : std_logic                  := '0';
	signal enc_valid      : std_logic                  := '0';
	signal enc_ready      : std_logic;
	signal msg            : std_logic_vector(36 downto 0);
begin

	p_subsec : process(i_clk)
		constant SUBUS_CNT     : natural                          := 250;
		variable subus_counter : natural range 0 to SUBUS_CNT - 1 := 0;
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				subus_counter  := 0;
				two_us_counter <= 0;
				msg_start      <= '0';
			else
				if i_pps = '1' then
					subus_counter  := 0;
					two_us_counter <= 0;
					msg_start      <= '1';
				else
					msg_start <= '0';
					if subus_counter = (SUBUS_CNT - 1) then
						subus_counter  := 0;
						assert two_us_counter /= 499_999 report "us counter overflowed" severity failure;
						two_us_counter <= two_us_counter + 1;
						msg_start      <= '1';
					else
						subus_counter := subus_counter + 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	encoder : entity work.timing_encoder
		generic map(
			G_OVERSAMPLING => 5,
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

	p_msg : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if i_rst = '1' then
				enc_valid <= '0';
				msg       <= (others => '0');
			else
				if unsigned(msg(msg'left - 1 downto 0)) = 0 then
					if msg_start = '1' then
						msg       <= i_sec_day & std_logic_vector(to_unsigned(two_us_counter, 19)) & "1";
						enc_valid <= '1';
					else
						enc_valid <= '0';
					end if;
				else
					if enc_ready = '1' then
						msg <= msg(msg'left - 1 downto 0) & "0";
					end if;
				end if;
			end if;
		end if;
	end process;
end architecture RTL;

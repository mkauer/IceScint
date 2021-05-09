library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

entity irig_receiver is
	generic(
		G_CLOCK_PERIOD : time := 100 ns 
	);
	port (
		i_clk_10m : in std_logic;
		i_rst_10m : in std_logic;
		i_irigb   : in std_logic;

		o_second  : out std_logic_vector(5 downto 0);
		o_minute  : out std_logic_vector(5 downto 0);
		o_hour    : out std_logic_vector(4 downto 0);
		o_day     : out std_logic_vector(8 downto 0);
		o_year    : out std_logic_vector(6 downto 0);
		o_sec_day : out std_logic_vector(16 downto 0)
	);
end irig_receiver;

architecture hdl of irig_receiver is
	component irig is
		port (
			clk_10mhz  : in  std_logic;
			rst        : in  std_logic;
			irigb      : in  std_logic;
			pps        : out std_logic;
			ts_second  : out std_logic_vector(5 downto 0);
			ts_minute  : out std_logic_vector(5 downto 0);
			ts_hour    : out std_logic_vector(4 downto 0);
			ts_day     : out std_logic_vector(8 downto 0);
			ts_year    : out std_logic_vector(6 downto 0);
			ts_sec_day : out std_logic_vector(16 downto 0)
		);
	end component;
begin
	irig_inst : irig
	port map(
		clk_10mhz => i_clk_10m,
		rst       => i_rst_10m,
		irigb     => i_irigb,

		ts_second  => o_second,
		ts_minute  => o_minute,
		ts_hour    => o_hour,
		ts_day     => o_day,
		ts_year    => o_year,
		ts_sec_day => o_sec_day
	);
end hdl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity udaq_rs485 is
	generic(
		G_CLK_FREQ  : natural := 100000000;
		G_BAUD_RATE : natural := 3000000
	);
	port(
		i_clk         : in  std_logic;
		i_rst         : in  std_logic;
		-- FIFO interface
		i_tx_data     : in  std_logic_vector(7 downto 0);
		i_tx_valid    : in  std_logic;
		o_tx_ready    : out std_logic;
		o_rx_data     : out std_logic_vector(7 downto 0);
		o_rx_valid    : out std_logic;
		i_rx_ready    : in  std_logic;
		o_rx_overflow : out std_logic;
		-- RS485 interface
		o_rs485_tx    : out std_logic;
		o_rs485_en    : out std_logic;
		i_rs485_rx    : in  std_logic
	);
end entity udaq_rs485;

architecture RTL of udaq_rs485 is
	signal rx_uart_data  : std_logic_vector(7 downto 0);
	signal rx_uart_valid : std_logic;

	signal rx_fifo_full  : std_logic;
	signal rx_fifo_valid : std_logic;
	signal rx_fifo_write : std_logic;
	signal rx_fifo_read  : std_logic;

	signal tx_uart_data   : std_logic_vector(7 downto 0);
	signal tx_uart_active : std_logic;

	signal tx_fifo_full  : std_logic;
	signal tx_fifo_valid : std_logic;
	signal tx_fifo_write : std_logic;
	signal tx_fifo_read  : std_logic;
begin

	uart_rx : entity work.UART_RX
		generic map(
			g_CLKS_PER_BIT => G_CLK_FREQ / G_BAUD_RATE
		)
		port map(
			i_Clk       => i_clk,
			i_RX_Serial => i_rs485_rx,
			o_RX_DV     => rx_uart_valid,
			o_RX_Byte   => rx_uart_data
		);

	uart_tx : entity work.UART_TX
		generic map(
			g_CLKS_PER_BIT => G_CLK_FREQ / G_BAUD_RATE
		)
		port map(
			i_Clk       => i_clk,
			i_TX_DV     => tx_fifo_valid,
			i_TX_Byte   => tx_uart_data,
			o_TX_Active => tx_uart_active,
			o_TX_Serial => o_rs485_tx,
			o_TX_Done   => open
		);

	o_rx_valid    <= rx_fifo_valid;
	o_rx_overflow <= rx_uart_valid and rx_fifo_full;
	rx_fifo_write <= rx_uart_valid and (not rx_fifo_full);
	rx_fifo_read  <= i_rx_ready and rx_fifo_valid;

	rx_fifo : entity work.udaq_rx_fifo
		port map(
			clk   => i_clk,
			srst  => i_rst,
			din   => rx_uart_data,
			wr_en => rx_fifo_write,
			rd_en => rx_fifo_read,
			dout  => o_rx_data,
			full  => rx_fifo_full,
			empty => open,
			valid => rx_fifo_valid
		);

	tx_fifo_read  <= tx_fifo_valid and (not tx_uart_active);
	tx_fifo_write <= i_tx_valid and (not tx_fifo_full);
	o_tx_ready    <= not tx_fifo_full;

	tx_fifo : entity work.udaq_tx_fifo
		port map(
			clk   => i_clk,
			srst  => i_rst,
			din   => i_tx_data,
			wr_en => tx_fifo_write,
			rd_en => tx_fifo_read,
			dout  => tx_uart_data,
			full  => tx_fifo_full,
			empty => open,
			valid => tx_fifo_valid
		);

end architecture RTL;

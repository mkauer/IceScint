----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    18:49:38 06/23/2017 
-- Design Name: 
-- Module Name:    triggerSystem - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity iceTad is
	generic (
		numberOfUarts : integer := 8
	);
	port (
		nP24VOn           : out std_logic_vector(0 to 7);
		nP24VOnTristate   : out std_logic_vector(0 to 7);
		rs485In           : in  std_logic_vector(0 to 7);
		rs485Out          : out std_logic_vector(0 to 7);
		rs485DataTristate : out std_logic_vector(0 to 7);
		rs485DataEnable   : out std_logic_vector(0 to 7);
		registerRead      : out iceTad_registerRead_t;
		registerWrite     : in iceTad_registerWrite_t
	);
end iceTad;

architecture Behavioral of iceTad is

	signal rs485DataIn_intern     : std_logic_vector(numberOfUarts - 1 downto 0);
	signal rs485DataEnable_intern : std_logic_vector(numberOfUarts - 1 downto 0);
	signal softTxEnable           : std_logic_vector(7 downto 0) := (others => '0');
	signal softTxMask             : std_logic_vector(7 downto 0) := (others => '0');
	signal txBusy                 : std_logic_vector(7 downto 0) := (others => '0');
	signal rxBusy                 : std_logic_vector(7 downto 0) := (others => '0');
	signal rxBusy_old             : std_logic_vector(7 downto 0) := (others => '0');

	signal fifo   : std_logic    := '0';
	signal fifoIn : data8x8Bit_t := (others => (others => '0'));
	--signal fifoOut : dataNumberOfChannelsX8Bit_t := (others=>(others=>'0'));
	signal fifoReset : std_logic_vector(7 downto 0);
	signal fifoRead  : std_logic_vector(7 downto 0);
	signal fifoWrite : std_logic_vector(7 downto 0);

	signal tx_delayed_start : std_logic_vector(7 downto 0);
	signal tx_module_busy : std_logic_vector(7 downto 0);
begin

	registerRead.powerOn <= registerWrite.powerOn;

	nP24VOn                   <= (others => '0');
	registerRead.rs485RxBusy  <= rxBusy;
	registerRead.rs485TxBusy  <= txBusy;
	registerRead.softTxEnable <= registerWrite.softTxEnable;
	softTxEnable              <= registerWrite.softTxEnable;
	registerRead.softTxMask   <= registerWrite.softTxMask;
	softTxMask                <= registerWrite.softTxMask;

	g1 : for i in 0 to numberOfUarts - 1 generate
		rs485DataIn_intern(i) <= rs485In(i) and not(rs485DataEnable_intern(i));
		x0 : entity work.uart_RxTx_V2
			generic map(
				Quarz_Taktfrequenz => 120000000,
				Baudrate => 3000000
			)
			port map(
				CLK => registerWrite.clock,
				RXD => rs485DataIn_intern(i),
				TXD => rs485Out(i),
				RX_Data  => fifoIn(i),
				TX_Data  => registerWrite.rs485Data(i),
				RX_Busy  => rxBusy(i),
				TX_Busy  => tx_module_busy(i),
				TX_Start => tx_delayed_start(i)
			);
		
		p_start : process(registerWrite.clock)
			type state_t is (IDLE, STARTING, ACTIVE);
			variable v_state : state_t;
			constant C_DELAY_START : natural := 40;
			constant C_DELAY_IDLE : natural := 300000;
			variable v_ctr_start : natural range 0 to C_DELAY_START;
			variable v_ctr_idle : natural range 0 to C_DELAY_IDLE;
		begin
			if rising_edge(registerWrite.clock) then
				if registerWrite.reset = '1' then
					v_state := IDLE;
					v_ctr_start := 0;
					v_ctr_idle := 0;
					tx_delayed_start(i) <= '0';
					txBusy(i) <= '0';
					rs485DataEnable(i) <= '0';
				else
					tx_delayed_start(i) <= '0';
					-- start request
					if registerWrite.rs485TxStart(i) = '1' then
						if v_state = IDLE or v_state = STARTING then
							v_state := STARTING;
						elsif v_state = ACTIVE then
							tx_delayed_start(i) <= '1';
                            v_ctr_idle := 0;
						end if;
					end if;
					-- reset idle counter when transmitting
					if tx_module_busy(i) = '1' then
						v_state := ACTIVE;
						v_ctr_idle := 0;
					end if;
					-- count to idle state when active and not transmitting
					if v_state = ACTIVE and tx_module_busy(i) = '0' then
						if v_ctr_idle = C_DELAY_IDLE then
							v_state := IDLE;
						else
							v_ctr_idle := v_ctr_idle + 1;
						end if;
					end if;
					-- count to active state
					if v_state = STARTING then
						if v_ctr_start = C_DELAY_START then
							v_state := ACTIVE;
							tx_delayed_start(i) <= '1';
						else
							v_ctr_start := v_ctr_start + 1;
						end if;
					end if;
					-- transmit enable
					if v_state /= IDLE then
						rs485DataEnable(i) <= '1';
					else
						rs485DataEnable(i) <= '0';
					end if;
					-- tx busy register
					if v_state = STARTING or v_state = ACTIVE then
						txBusy(i) <= '1';
					else
						txBusy(i) <= '0';
					end if;
					-- reset inactive counters
					if v_state = IDLE or v_state = STARTING then
						v_ctr_idle := 0;
					else
						v_ctr_start := 0;
					end if;
				end if;
			end if;
		end process;
		
		x2 : entity work.rs485fifo
			port map(
				clk        => registerWrite.clock,
				srst       => fifoReset(i),
				din        => fifoIn(i),
				wr_en      => fifoWrite(i),
				rd_en      => registerWrite.rs485FifoRead(i),
				dout       => registerRead.rs485FifoData(i),
				full       => registerRead.rs485FifoFull(i),
				empty      => registerRead.rs485FifoEmpty(i),
				data_count => registerRead.rs485FifoWords(i)(10 downto 0)
			);

		--registerRead.rs485FifoWords(i)(7 downto 6) <= "0";
	end generate;

	g2 : if (numberOfUarts < 8) generate
		rs485DataTristate(7 downto numberOfUarts) <= (others => '1');
		rs485DataEnable(7 downto numberOfUarts)   <= (others => '0');
	end generate;

	P1 : process (registerWrite.clock)
	begin
		if rising_edge(registerWrite.clock) then
			if (registerWrite.reset = '1') then
				nP24VOnTristate <= (others => '1');
			else
				q : for i in 0 to registerWrite.powerOn'length - 1 loop
					if (registerWrite.powerOn(i) = '1') then
						nP24VOnTristate(i) <= '0';
					else
						nP24VOnTristate(i) <= '1';
					end if;
				end loop;

				-- rs485 fifo goes here...

			end if;
		end if;
	end process P1;

	P2 : process (registerWrite.clock)
	begin
		if rising_edge(registerWrite.clock) then
			fifoWrite <= (others => '0'); -- autoreset
			fifoReset <= (others => '0'); -- autoreset
			if (registerWrite.reset = '1') then
				rxBusy_old <= (others => '0');
				fifoReset  <= (others => '1'); -- autoreset
			else
				if (registerWrite.rs485FifoClear /= x"00") then
					fifoReset <= registerWrite.rs485FifoClear; -- autoreset
				end if;

				rxBusy_old <= rxBusy;

				q : for i in 0 to fifoWrite'length - 1 loop
					if ((rxBusy_old(i) = '1') and (rxBusy(i) = '0')) then
						fifoWrite(i) <= '1' and not(txBusy(i)); -- autoreset
						--fifoWrite(i) <= '1'; -- autoreset
					end if;
				end loop;

			end if;
		end if;
	end process P2;

end Behavioral;

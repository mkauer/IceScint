----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:18:09 03/01/2017 
-- Design Name: 
-- Module Name:    smcBusEntry - Behavioral 
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
use IEEE.NUMERIC_STD.all;
use ieee.std_logic_unsigned.all;
use work.types.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity I2CMaster is
	port (
		clk : in std_logic;
		--Input comand:-Port
		comand    : in std_logic_vector(47 downto 0);
		newcomand : in std_logic;
		i2crxreg  : out std_logic_vector(15 downto 0);
		idle      : out std_logic;
		--I2C Port:
		scl    : out std_logic;
		sdaout : out std_logic;
		sdaint : in std_logic
	);
end I2CMaster;

architecture Behavioral of I2CMaster is
	signal fastcounter       : std_logic_vector(6 downto 0) := "0000000";
	signal i2cce             : std_logic;
	signal i2cstate, i2ccnt  : std_logic_vector(3 downto 0)  := "0000";
	signal i2csubcnt, datcnt : std_logic_vector(1 downto 0)  := "00";
	signal i2ctxdat, i2crxsr : std_logic_vector(7 downto 0)  := "00000000";
	signal i2crxreg_i        : std_logic_vector(15 downto 0) := "0000000000000000";
begin

	process (clk)
	begin
		if (clk'event and clk = '1') then
			fastcounter <= fastcounter + "0000001";
			if fastcounter = "1001010" then -- Fastcounter z�hlt auf 71; i2cce hat  118,75M / 75 = 1,58M -> I2c ca. 400khz
				i2cce       <= '1';
				fastcounter <= "0000001";
			else
				i2cce       <= '0';
				fastcounter <= fastcounter + "0000001";
			end if;
		end if;
	end process;
	--------- I2C Master Interface:

	process (clk)
	begin
		if (clk'event and clk = '1') then
			if (newcomand = '1') and (comand(47 downto 45) = "100") and (comand(40) = '0') then -- write I2C
				i2cstate  <= "0001";
				i2ccnt    <= "1111";
				i2csubcnt <= "00";
			elsif (newcomand = '1') and (comand(47 downto 45) = "100") and (comand(40) = '1') then -- read I2C
				i2cstate  <= "0110";
				i2ccnt    <= "1111";
				i2csubcnt <= "00";
			elsif (i2cce = '1') then
				i2csubcnt <= i2csubcnt + "01";
				if (i2csubcnt = "11") and (i2ccnt = "1111") then -- Byte oder start/stopcondition
					if (i2cstate = "0001") then                      -- writestart ready		
						i2cstate <= i2cstate + "0001";                   -- goto sendaddress
						i2ccnt   <= "0111";
					elsif (i2cstate = "0010") then -- sendaddress ready		
						i2cstate <= i2cstate + "0001"; -- goto sendsubaddress
						datcnt   <= "00";
						i2ccnt   <= "0111";
					elsif (i2cstate = "0011") then -- sendsubaddress ready		
						datcnt <= datcnt + "01";
						if datcnt = comand(42 downto 41) then
							i2cstate <= i2cstate + "0001"; -- goto senddata
						end if;
						i2ccnt <= "0111";
					elsif (i2cstate = "0100") then -- senddata ready		
						i2cstate <= i2cstate + "0001"; -- goto writestop
						i2ccnt   <= "1111";
					elsif (i2cstate = "0101") then -- writestop ready		
						i2cstate <= "0000";            -- goto idle
						i2ccnt   <= "1111";
					elsif (i2cstate = "0110") then -- readstart ready		
						i2cstate <= i2cstate + "0001"; -- goto sendaddress
						datcnt   <= "00";
						i2ccnt   <= "0111";
					elsif (i2cstate = "0111") then -- sendaddress ready		
						datcnt <= datcnt + "01";
						if datcnt = comand(42 downto 41) then
							i2cstate <= i2cstate + "0001"; -- goto sendsubaddress
						end if;
						i2ccnt <= "0111";
					elsif (i2cstate = "1000") then -- sendsubaddress ready		
						i2cstate <= i2cstate + "0001"; -- goto sendrepeatstart
						i2ccnt   <= "1111";
					elsif (i2cstate = "1001") then -- sendrepeatstart ready		
						i2cstate <= i2cstate + "0001"; -- goto sendaddress
						i2ccnt   <= "0111";
					elsif (i2cstate = "1010") then -- sendaddress ready		
						i2cstate <= i2cstate + "0001"; -- goto readdata
						i2ccnt   <= "0111";
						datcnt   <= "00";
					elsif (i2cstate = "1011") then -- readdata ready		
						datcnt <= datcnt + "01";
						if datcnt = comand(44 downto 43) then
							i2cstate <= i2cstate + "0001"; -- goto readstop
							i2ccnt   <= "1111";
						else
							i2cstate <= i2cstate;
							i2ccnt   <= "0111";
						end if;
						--				i2cstate <= i2cstate + "0001"; -- goto readstop
						--				i2ccnt <= "1111";
					else                -- readstop ready		
						i2cstate <= "0000"; -- goto idle
						i2ccnt   <= "1111";
					end if;
				elsif (i2csubcnt = "11") then
					i2ccnt <= i2ccnt + "0001";
				end if;
			end if;
			if (i2cstate = "0000") then
				scl    <= '1';
				sdaout <= '1';
			elsif (i2cstate = "0001") or (i2cstate = "0110") then -- startcondition
				if (i2csubcnt = "11") then
					scl <= '0';
				else
					scl <= '1';
				end if;
				if (i2csubcnt(1) = '0') then
					sdaout <= '1';
				else
					sdaout <= '0';
				end if;
			elsif (i2cstate = "0101") or (i2cstate = "1100") then -- stopcondition
				if (i2csubcnt = "00") then
					scl <= '0';
				else
					scl <= '1';
				end if;
				if (i2csubcnt(1) = '1') then
					sdaout <= '1';
				else
					sdaout <= '0';
				end if;
			elsif (i2cstate = "1001") then -- repeated startcondition
				if (i2csubcnt(0) = i2csubcnt(1)) then
					scl <= '0';
				else
					scl <= '1';
				end if;
				if (i2csubcnt(1) = '0') then
					sdaout <= '1';
				else
					sdaout <= '0';
				end if;
			elsif (i2cstate = "1011") then -- read data
				if (i2csubcnt(0) = i2csubcnt(1)) then
					scl <= '0';
				else
					scl <= '1';
				end if;
				if (i2ccnt = "1111") and (comand(44 downto 43) /= datcnt) then --ack always except last byte 
					sdaout <= '0';                                                 --ack
				else
					sdaout <= '1';
				end if;
			elsif (i2cstate = "0000") then -- idle
				scl    <= '1';
				sdaout <= '1';
			else -- writebyte
				if (i2csubcnt(0) = i2csubcnt(1)) then
					scl <= '0';
				else
					scl <= '1';
				end if;
				if (i2ctxdat(7) = '1') then
					sdaout <= '1';
				else
					sdaout <= '0';
				end if;
			end if;

			if (i2cce = '1') then
				---------- txdata:	
				if (i2csubcnt = "11") and (i2ccnt = "1111") then -- Byte oder start/stopcondition
					if (i2cstate = "0001") then                      -- writestart ready		
						i2ctxdat <= comand(39 downto 33) & '0';
					elsif (i2cstate = "0010") then -- sendaddress ready		
						i2ctxdat <= comand(31 downto 24);
					elsif (i2cstate = "0011") then -- sendsubaddress ready		
						if datcnt = "00" then
							i2ctxdat <= comand(23 downto 16);
						elsif datcnt = "01" then
							i2ctxdat <= comand(15 downto 8);
						else
							i2ctxdat <= comand(7 downto 0);
						end if;
					elsif (i2cstate = "0110") then -- readstart ready		
						i2ctxdat <= comand(39 downto 33) & '0';
					elsif (i2cstate = "0111") then -- sendaddress ready		
						--	i2ctxdat <= comand(31 downto 24);
						if datcnt = "00" then
							i2ctxdat <= comand(31 downto 24);
						elsif datcnt = "01" then
							i2ctxdat <= comand(23 downto 16);
						else
							i2ctxdat <= comand(15 downto 8);
						end if;
					elsif (i2cstate = "1001") then -- sendrepeatstart ready		
						i2ctxdat <= comand(39 downto 33) & '1';
					end if;
				elsif (i2csubcnt = "11") then
					i2ctxdat <= i2ctxdat(6 downto 0) & '1';
				end if;
				---------- rxdata:	
				if (i2csubcnt = "01") then -- Byte oder start/stopcondition
					i2crxsr <= i2crxsr(6 downto 0) & sdaint;
				end if;
				if (i2cstate = "1001") then -- repeated startconditio
					i2crxreg_i <= "0000000000000000";
				elsif (i2csubcnt = "10") and (i2ccnt = "1110") and (i2cstate = "1011") then -- Nach 8 bit read
					i2crxreg_i <= i2crxreg_i(7 downto 0) & i2crxsr;
				end if;
			end if;
		end if;
	end process;

	idle <= '1' when i2cstate = "0000" else
		'0';
	i2crxreg <= i2crxreg_i;
end Behavioral;

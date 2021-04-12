----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    18:49:38 06/23/2017 
-- Design Name: 
-- Module Name:    panelPower - Behavioral 
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

entity panelPower is
	port (
		nPowerOn      : out std_logic; --_vector(2 downto 0);
		registerRead  : out panelPower_registerRead_t;
		registerWrite : in panelPower_registerWrite_t
	);
end panelPower;

architecture Behavioral of panelPower is

	signal powerOn           : std_logic                 := '0';
	signal panelPowerCounter : integer range 0 to 130000 := 0;

begin

	nPowerOn <= not(powerOn); -- & powerOn & powerOn);

	P1 : process (registerWrite.clock)
	begin
		if rising_edge(registerWrite.clock) then
			if ((registerWrite.reset = '1') or (registerWrite.init = '1')) then
				powerOn           <= '0';
				panelPowerCounter <= 0;
			else
				--				if(panelPowerCounter >= 125000) then
				--					powerOn <= '1';
				--				elsif(panelPowerCounter = 125000) then
				--					powerOn <= '0';
				--				else
				--					panelPowerCounter <= panelPowerCounter + 1;
				--				end if;

				if (registerWrite.enable = '1') then
					powerOn <= '1';
				else
					powerOn <= '0';
				end if;

			end if;
		end if;
	end process P1;

end Behavioral;

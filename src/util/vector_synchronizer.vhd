-------------------------------------------------------------------------------
--
--  Vector synchronizer for clock-domain crossings.
--
--  This file is part of the noasic library.
--
--  Description:  
--    Synchronizes a single-bit signal from a source clock domain
--    to a destination clock domain using a chain of flip-flops (synchronizer
--    FF followed by one or more guard FFs).
--
--  Author(s):
--    Guy Eschemann, Guy.Eschemann@gmail.com
--
-------------------------------------------------------------------------------
--
--  Copyright (c) 2020 Guy Eschemann
--
--  This source file may be used and distributed without restriction provided
--  that this copyright statement is not removed from the file and that any
--  derivative work contains the original copyright notice and the associated
--  disclaimer.
--
--  This source file is free software: you can redistribute it and/or modify it
--  under the terms of the GNU Lesser General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or (at your
--  option) any later version.
--
--  This source file is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
--  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
--  for more details.
--
--  You should have received a copy of the GNU Lesser General Public License
--  along with the noasic library.  If not, see http://www.gnu.org/licenses
--
-------------------------------------------------------------------------------

library ieee;

use ieee.std_logic_1164.all;

entity vector_synchronizer is
	generic(
		G_DATA_WIDTH    : natural;      -- data width, in bits
		G_INIT_VALUE    : std_logic_vector; -- initial value of all flip-flops in the module
		G_NUM_GUARD_FFS : positive := 1); -- number of guard flip-flops after the synchronizing flip-flop
	port(
		i_reset : in  std_logic;        -- asynchronous, high-active
		i_clk   : in  std_logic;        -- destination clock
		i_data  : in  std_logic_vector(G_DATA_WIDTH - 1 downto 0);
		o_data  : out std_logic_vector(G_DATA_WIDTH - 1 downto 0));
end vector_synchronizer;

architecture RTL of vector_synchronizer is

begin

	gen_synchronizers : for i in 0 to G_DATA_WIDTH - 1 generate
		synchronizer_inst : entity work.synchronizer
			port map(
				i_reset => i_reset,
				i_clk   => i_clk,
				i_data  => i_data(i),
				o_data  => o_data(i)
			);
	end generate gen_synchronizers;

end RTL;

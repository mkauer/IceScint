--
--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 
--
--   To use any of the example code shown below, uncomment the lines and modify as necessary
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

package types_platformSpecific is

    constant numberOfChannels_platformSpecific   : integer := 8;
    constant globalClockRate_platformSpecific_hz : integer := 120000000;

    type system_type_t is (ICE_SCINT, UV_LOGGER, ICE_SCINT_RADIO, INVALID);
    constant SYSTEM_TYPE : system_type_t := ICE_SCINT;
    --alias numberOfChannels : integer is numberOfChannels_platformSpecific;

end types_platformSpecific;

package body types_platformSpecific is

    --	constant numberOfChannels_platformSpecific : integer := 8;

end types_platformSpecific;

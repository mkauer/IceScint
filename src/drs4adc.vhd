library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity drs4adc is
	port (
		address : out std_logic_vector(3 downto 0);

		notReset0 : out std_logic;
		denable0  : out std_logic;
		dwrite0   : out std_logic;
		rsrload0  : out std_logic;
		miso0     : in std_logic;
		mosi0     : out std_logic;
		srclk0    : out std_logic;
		dtap0     : in std_logic;
		plllck0   : in std_logic;

		deadTime       : out std_logic;
		trigger        : in std_logic; -- should be truly async later on
		internalTiming : in internalTiming_t;
		adcClocks      : in adcClocks_t;
		--drs4_to_ltm9007_14 : out drs4_to_ltm9007_14_t;
		--drs4_to_eventFifoSystem : out drs4_to_eventFifoSystem_t;

		drs4_0r : out drs4_registerRead_t;
		drs4_0w : in drs4_registerWrite_t;
		nCSA0   : out std_logic;
		nCSB0   : out std_logic;
		mosi    : out std_logic;
		sclk    : out std_logic;

		--enc_p0 : out std_logic;
		--enc_n0 : out std_logic;
		enc0        : out std_logic;
		adcDataA_p0 : in std_logic_vector(7 downto 0);
		adcDataA_n0 : in std_logic_vector(7 downto 0);

		--drs4_to_ltm9007_14 : in drs4_to_ltm9007_14_t;
		--ltm9007_14_to_eventFifoSystem : out ltm9007_14_to_eventFifoSystem_t;
		--adcClocks : in adcClocks_t;
		drs4AndAdcData : out drs4AndAdcData_t;

		ChannelID    : in std_logic_vector(1 downto 0);
		fifoemptyout : out std_logic_vector(1 downto 0);
		fifoemptyinA : in std_logic_vector(1 downto 0);
		fifoemptyinB : in std_logic_vector(1 downto 0);

		registerRead  : out ltm9007_14_registerRead_t;
		registerWrite : in ltm9007_14_registerWrite_t
	);
end entity;

architecture Behavioral of drs4adc is
	attribute keep : string;

	--signal address : std_logic_vector(3 downto 0);

	signal bitslipStart : std_logic;
	signal bitslipDone  : std_logic; --_vector(2 downto 0);

	signal bitslipDone_TPTHRU_TIG            : std_logic;
	attribute keep of bitslipDone_TPTHRU_TIG : signal is "true";

	signal bitslipStart_TPTHRU_TIG            : std_logic;
	attribute keep of bitslipStart_TPTHRU_TIG : signal is "true";

	signal drs4_to_ltm9007_14 : drs4_to_ltm9007_14_t;

	signal drs4_to_eventFifoSystem       : drs4_to_eventFifoSystem_t;
	signal ltm9007_14_to_eventFifoSystem : ltm9007_14_to_eventFifoSystem_t;
	signal bitslipStartExtern            : std_logic;

begin

	drs4AndAdcData.adcData  <= ltm9007_14_to_eventFifoSystem;
	drs4AndAdcData.drs4Data <= drs4_to_eventFifoSystem;

	--h0: for i in 0 to 3 generate k: OBUF port map(O => address_p(i), I => address(i)); end generate;

	y0 : entity work.drs4
	port map(
		address                 => address,
		notReset                => notReset0,
		denable                 => denable0,
		dwrite                  => dwrite0,
		rsrload                 => rsrload0,
		miso                    => miso0,
		mosi                    => mosi0,
		srclk                   => srclk0,
		dtap                    => dtap0,
		plllck                  => plllck0,
		deadTime                => deadTime,
		trigger                 => trigger,
		internalTiming          => internalTiming,
		adcClocks               => adcClocks,
		drs4_to_ltm9007_14      => drs4_to_ltm9007_14,
		drs4_to_eventFifoSystem => drs4_to_eventFifoSystem,
		registerRead            => drs4_0r,
		registerWrite           => drs4_0w
	);


	--g1: if drs4_type = "ICE_SCINT" generate

	bitslipDone_TPTHRU_TIG  <= bitslipDone;
	bitslipStart_TPTHRU_TIG <= bitslipStart;
	--yyy <= std_logic_TIG(bitslipStart);
	--l0: entity work.tig port map(bitslipStart, yyy);
	--temp <= std_logic_vector_TIG(bitslipDone); 

	--j0: OBUF port map(O => nCSA0, I => notChipSelectA);
	--j1: OBUF port map(O => nCSB0, I => notChipSelectB);

	bitslipStartExtern <= registerWrite.bitslipStart(0) when ChannelID = "00" else
		registerWrite.bitslipStart(1) when ChannelID = "01" else
		registerWrite.bitslipStart(2);
	y1 : entity work.ltm9007_14_slowControl port map(
		clock              => registerWrite.clock,
		reset              => registerWrite.reset,
		nCSA               => nCSA0,
		nCSB               => nCSB0,
		mosi               => mosi,
		sclk               => sclk,
		init               => registerWrite.init,
		bitslipDone        => bitslipDone_TPTHRU_TIG,
		bitslipStart_p     => bitslipStart,
		bitslipStartExtern => bitslipStartExtern,
		bitslipPattern     => LTM9007_14_BITSLIPPATTERN,
		testMode           => registerWrite.testMode,
		testPattern        => registerWrite.testPattern
	);

	y2 : entity work.ltm9007_14_adcData port map(
		enc_p                         => enc0,
		adcDataA_p                    => adcDataA_p0,
		adcDataA_n                    => adcDataA_n0,
		bitslipStartLatched           => bitslipStart_TPTHRU_TIG,
		bitslipDone_TIG               => bitslipDone,
		ChannelID                     => ChannelID,
		fifoemptyout                  => fifoemptyout,
		fifoemptyinA                  => fifoemptyinA,
		fifoemptyinB                  => fifoemptyinB,
		drs4_to_ltm9007_14            => drs4_to_ltm9007_14,
		ltm9007_14_to_eventFifoSystem => ltm9007_14_to_eventFifoSystem,
		adcClocks                     => adcClocks,
		registerRead                  => registerRead,
		registerWrite                 => registerWrite
	);

	--end generate; 
end Behavioral;

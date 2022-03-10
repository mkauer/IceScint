----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:59:02 03/27/2017 
-- Design Name: 
-- Module Name:    drs4 - Behavioral 
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
library UNISIM;
use UNISIM.VComponents.all;

entity drs4 is
    generic (
        adcPipelineStages   : integer := 5;
        dummyImplementation : string  := "FALSE"
    );
    port (
        address : out std_logic_vector(3 downto 0);

        notReset : out std_logic;
        denable  : out std_logic;
        dwrite   : out std_logic;
        --dwriteSerdes_p : out std_logic_vector(7 downto 0);

        rsrload : out std_logic;
        miso    : in std_logic;
        mosi    : out std_logic;
        srclk   : out std_logic;

        dtap   : in std_logic;
        plllck : in std_logic;

        deadTime : out std_logic;

        trigger                 : in std_logic; -- should be truly async later on
        internalTiming          : in internalTiming_t;
        adcClocks               : in adcClocks_t;
        drs4_to_ltm9007_14      : out drs4_to_ltm9007_14_t;
        drs4_to_eventFifoSystem : out drs4_to_eventFifoSystem_t;

        registerRead  : out drs4_registerRead_t;
        registerWrite : in drs4_registerWrite_t
    );
end drs4;

architecture Behavioral of drs4 is
    attribute keep            : string;
    constant spiNumberOfBits  : integer              := 8;
    constant sclkDivisor      : unsigned(3 downto 0) := x"2"; -- ((systemClock / spiClock) / 2) ... 2=~29.7MHz@118.75MHz
    constant sclkDefaultLevel : std_logic            := '0';
    constant mosiDefaultLevel : std_logic            := '0';
    --constant mosiValidEdge : std_logic := '0'; -- '0'=rising, '1'=falling
    --constant mosiMsbinitState : std_logic := '1'; -- '0'=LsbinitState, '1'=MsbinitState

    type stateDrs4Spi_t is (idle, transfer1, transfer2, readRegionOfInterest, transferEnd, readFullChip, readRegionOfInterest2, readRegionOfInterest3, readFullChip2, transferEnd2);
    signal stateDrs4Spi : stateDrs4Spi_t := idle;

    signal rxBuffer                                  : std_logic_vector(spiNumberOfBits - 1 downto 0); -- ## why is it 9 bit??
    signal writeShiftRegister_readBack               : std_logic_vector(rxBuffer'range);
    signal txBuffer                                  : std_logic_vector(spiNumberOfBits downto 0);
    signal roiBuffer_66                              : std_logic_vector(9 downto 0) := (others => '0');
    signal roiBufferLatched_66                       : std_logic_vector(9 downto 0) := (others => '0');
    signal roiBufferLatched_66_TPTHRU_TIG            : std_logic_vector(9 downto 0) := (others => '0');
    attribute keep of roiBufferLatched_66_TPTHRU_TIG : signal is "true";
    signal roiBufferLatched_sync                     : std_logic_vector(9 downto 0) := (others => '0');
    signal roiBufferReady_66                         : std_logic                    := '0';
    signal roiBufferReady_66_TPTHRU_TIG              : std_logic                    := '0';
    attribute keep of roiBufferReady_66_TPTHRU_TIG   : signal is "true";

    signal busy                  : std_logic                          := '0';
    signal spiTransfer           : std_logic                          := '0';
    signal spiTransfer_old       : std_logic                          := '0';
    signal spiCounter            : integer range 0 to spiNumberOfBits := 0;
    signal sclkDivisorCounter    : unsigned (3 downto 0)              := x"0";
    signal sclk_i                : std_logic                          := '0';
    signal sclkEnable            : std_logic                          := '0';
    signal sclkEdgeRisingDelayed : std_logic                          := '0';
    signal sclkEdgeRising        : std_logic                          := '0';
    signal sclkEdgeFalling       : std_logic                          := '0';
    signal inhibitSclk           : std_logic                          := '0';
    signal enableRsrload         : std_logic                          := '0';
    --  type readoutMode_t is (regionOfIntrest,fullReadout,configRegister);
    --  signal readoutMode : readoutMode_t := regionOfIntrest;
    type spiTransferMode_t is (sampleNormalMode, sampleTransparentMode, standby, regionOfIntrest, fullReadout, readShiftRegister_write, writeShiftRegister_transfer, configRegister_write, writeConfigRegister_write, regionOfIntrest2, fullReadout2, regionOfIntrest3);
    signal spiTransferMode                   : spiTransferMode_t        := sampleNormalMode;
    signal bitCounter1                       : integer range 0 to 65535 := 0; --unsigned(15 downto 0) := x"0000";
    signal bitCounter1_TPTHRU_TIG            : integer range 0 to 65535 := 0;
    attribute keep of bitCounter1_TPTHRU_TIG : signal is "true";
    signal roiCounter                        : integer range 0 to 15 := 0;
    signal edgeCounter                       : integer range 0 to 3  := 0;
    signal spiDone                           : std_logic             := '0';

    type stateDrs4_t is (init1, init2, init3, init4, init5, init6, init7, drs4start0, drs4start1, startSampling, sampling, readRoi, readFull, debug, readRoi2, readRoi3, readFull2, manageDrs4Cascading, manageDrs4Cascading2);
    signal stateDrs4 : stateDrs4_t := init1;

    --  signal readShiftRegister : std_logic_vector(7 downto 0);
    signal configRegister : std_logic_vector(2 downto 0) := "111";
    alias configRegister_dmode_bit is configRegister(0);
    alias configRegister_pllen_bit is configRegister(1);
    alias configRegister_wsrloop_bit is configRegister(2);
    --alias configRegister_reserved_bits is configRegister(7 downto 3); -- hast to be 1
    --signal writeShiftRegister : std_logic_vector(7 downto 0) := "11111111"; -- 8x1024 samples
    signal writeConfigRegister : std_logic_vector(7 downto 0) := "11111111";

    constant address_enableAllOutputs    : std_logic_vector(3 downto 0) := "1001";
    constant address_transparentMode     : std_logic_vector(3 downto 0) := "1010";
    constant address_readShiftRegister   : std_logic_vector(3 downto 0) := "1011";
    constant address_configRegister      : std_logic_vector(3 downto 0) := "1100";
    constant address_writeShiftRegister  : std_logic_vector(3 downto 0) := "1101";
    constant address_writeConfigRegister : std_logic_vector(3 downto 0) := "1110";
    constant address_stabdby             : std_logic_vector(3 downto 0) := "1111";

    --constant numberOfSamplesToRead : std_logic_vector(11 downto 0) := x"010";
    signal stopDrs4_old                   : std_logic                    := '0';
    signal counter1                       : integer range 0 to 1300000   := 0; -- 1023 := 0;
    signal sendFullReadoutSync_66         : std_logic_vector(2 downto 0) := (others => '0');
    signal sendRoiReadoutSync_66          : std_logic_vector(2 downto 0) := (others => '0');
    signal sendRoiReadout2Sync_66         : std_logic_vector(2 downto 0) := (others => '0');
    signal inhibitAdc                     : std_logic                    := '0';
    signal roiBufferReadySync             : std_logic_vector(2 downto 0) := (others => '0');
    signal spi2DoneSync                   : std_logic_vector(2 downto 0) := (others => '0');
    signal spi2Done_TPTHRU_TIG            : std_logic                    := '0';
    attribute keep of spi2Done_TPTHRU_TIG : signal is "true";
    --signal sclk2 : std_logic := '0';
    signal sclkPhase       : std_logic                := '0';
    signal sclk2Enabled    : std_logic                := '0';
    signal rsrload2Enabled : std_logic                := '0';
    signal bitCounter2     : integer range 0 to 65535 := 0;
    signal bitCounter2Max  : integer range 0 to 65535 := 0;
    type stateSpi2_t is (idle, syncFull, full, syncRoi, roiRsload, roiSrclk, adcBacklash);
    signal stateSpi2   : stateSpi2_t := idle;
    signal spi2Done    : std_logic   := '0';
    signal misoSync    : std_logic   := '0';
    signal misoSync125 : std_logic;

    signal rsrload1                              : std_logic := '0';
    signal srclk1                                : std_logic := '0';
    signal rsrload2                              : std_logic := '0';
    signal srclk2                                : std_logic := '0';
    signal sendFullReadout                       : std_logic := '0';
    signal sendRoiReadout                        : std_logic := '0';
    signal sendRoiReadout2                       : std_logic := '0';
    signal sendFullReadout_TPTHRU_TIG            : std_logic := '0';
    signal sendRoiReadout_TPTHRU_TIG             : std_logic := '0';
    signal sendRoiReadout2_TPTHRU_TIG            : std_logic := '0';
    attribute keep of sendFullReadout_TPTHRU_TIG : signal is "true";
    attribute keep of sendRoiReadout_TPTHRU_TIG  : signal is "true";
    attribute keep of sendRoiReadout2_TPTHRU_TIG : signal is "true";

    signal dwrite_i   : std_logic := '0';
    signal stopDrs4   : std_logic := '0';
    signal sumTrigger : std_logic := '0';

    --  signal address : std_logic_vector(3 downto 0);
    --  signal notReset : std_logic;
    --  signal denable : std_logic;
    --  signal dwrite : std_logic;
    --  signal miso : std_logic;
    --  signal mosi : std_logic;
    --  signal rsrload : std_logic;
    --  signal srclk : std_logic;
    --  signal dtap : std_logic;
    --  signal plllck : std_logic;
    signal regionOfInterest      : std_logic_vector(9 downto 0);
    signal regionOfInterestReady : std_logic;
    --signal drs4_to_eventFifoSystem : drs4_to_eventFifoSystem_t;

begin

    --g1: if dummyImplementation = "FALSE" generate
    --  z0: OBUF port map(O => notReset_p, I => notReset);
    --  z1: OBUF port map(O => denable_p, I => denable);
    --  z2: OBUF port map(O => dwrite_p, I => dwrite);
    --  z3: OBUF port map(O => rsrload_p, I => rsrload);
    --  z4: OBUF port map(O => mosi_p, I => mosi);
    --  z5: IBUF port map(I => miso_p, O => miso);
    --  z6: OBUF port map(O => srclk_p, I => srclk);
    --  z7: IBUF port map(I => dtap_p, O => dtap);
    --  z8: IBUF port map(I => plllck_p, O => plllck);
    --  z9: for i in 0 to 3 generate k: OBUF port map(O => address_p(i), I => address(i)); end generate;

    sendFullReadout_TPTHRU_TIG <= sendFullReadout;
    sendRoiReadout_TPTHRU_TIG  <= sendRoiReadout;
    sendRoiReadout2_TPTHRU_TIG <= sendRoiReadout2;

    roiBufferLatched_66_TPTHRU_TIG <= roiBufferLatched_66;
    roiBufferLatched_sync          <= roiBufferLatched_66_TPTHRU_TIG;

    roiBufferReady_66_TPTHRU_TIG <= roiBufferReady_66;

    bitCounter1_TPTHRU_TIG <= bitCounter1;

    spi2Done_TPTHRU_TIG <= spi2Done;

    rsrload1 <= sclk_i when enableRsrload = '1' else
        sclkDefaultLevel;
    srclk1 <= sclk_i when inhibitSclk = '0' else
        sclkDefaultLevel;

    rsrload <= rsrload1 or rsrload2; -- ## add fixed otput buffer for better timing
    srclk   <= srclk1 or srclk2;     -- ## add fixed otput buffer for better timing
    --rsrload <= rsrload1 or (sclk2 and rsrload2Enabled); -- ## add fixed otput buffer for better timing
    --srclk <= srclk1 or (sclk2 and sclk2Enabled); -- ## add fixed otput buffer for better timing

    stopDrs4 <= sumTrigger;
    --sumTrigger <=  trigger.triggerNotDelayed or trigger.softTrigger;
    --sumTrigger <=  trigger.triggerDelayed or trigger.softTrigger;
    sumTrigger <= trigger;
    --dwriteSerdes <= (dwrite_i&dwrite_i&dwrite_i&dwrite_i&dwrite_i&dwrite_i&dwrite_i&dwrite_i) when sumTrigger = '0' else x"00";
    dwrite <= dwrite_i when sumTrigger = '0' else
        '0';

    --srclk <= sclkDefaultLevel when ((spiTransferMode = regionOfIntrest) and (edgeCounter < 2)) or (inhibitSclk = '1') else sclk_i;

    registerRead.numberOfSamplesToRead <= registerWrite.numberOfSamplesToRead;
    registerRead.sampleMode            <= registerWrite.sampleMode;
    registerRead.readoutMode           <= registerWrite.readoutMode;
    registerRead.writeShiftRegister    <= registerWrite.writeShiftRegister;

    P0 : process (registerWrite.clock)
    begin
        if rising_edge(registerWrite.clock) then
            sclkEdgeRisingDelayed <= sclkEdgeRising;
            sclkEdgeRising        <= '0'; -- autoreset
            sclkEdgeFalling       <= '0'; -- autoreset
            if (registerWrite.reset = '1') then
                sclkDivisorCounter <= to_unsigned(0, sclkDivisorCounter'length);
                sclk_i             <= sclkDefaultLevel;
                --sclkEdgeRisingDelayed <= '0';
            else
                if (sclkEnable = '1') then
                    if (sclkDivisorCounter = sclkDivisor) then
                        sclkDivisorCounter <= to_unsigned(0, sclkDivisorCounter'length);

                        if (edgeCounter /= 3) then
                            edgeCounter <= edgeCounter + 1;
                        end if;

                        sclk_i <= not sclk_i;
                        if ((sclk_i = '0')) then
                            sclkEdgeRising <= '1'; -- autoreset
                        end if;
                        if ((sclk_i = '1')) then
                            sclkEdgeFalling <= '1'; -- autoreset
                        end if;
                    else
                        sclkDivisorCounter <= sclkDivisorCounter + 1;
                    end if;
                else
                    sclk_i             <= sclkDefaultLevel;
                    sclkDivisorCounter <= to_unsigned(0, sclkDivisorCounter'length);
                    edgeCounter        <= 0;
                end if;
            end if;
        end if;
    end process P0;

    --P01:process (registerWrite.globals.adcSerdesDivClockPhase.clock) -- ~66MHz
    P01 : process (adcClocks.clk_66_serdes_div7_second) -- ~66MHz
    begin
        --if rising_edge(registerWrite.globals.adcSerdesDivClockPhase.clock) then
        if rising_edge(adcClocks.clk_66_serdes_div7_second) then
            roiBufferReady_66 <= '0'; -- autoreset
            srclk2            <= '0'; -- autoreset
            rsrload2          <= '0'; -- autoreset
            if (adcClocks.rst_div7_second = '1') then
                --sclkPhase <= not(sclkDefaultLevel);
                sclkPhase                          <= sclkDefaultLevel;
                sendFullReadoutSync_66             <= (others => '0');
                sendRoiReadoutSync_66              <= (others => '0');
                sendRoiReadout2Sync_66             <= (others => '0');
                roiBuffer_66                       <= (others => '0');
                stateSpi2                          <= idle;
                spi2Done                           <= '0';
                misoSync                           <= '0';
                drs4_to_ltm9007_14.adcDataStart_66 <= '0';
            else
                sendFullReadoutSync_66 <= sendFullReadout_TPTHRU_TIG & sendFullReadoutSync_66(sendFullReadoutSync_66'length - 1 downto 1);
                sendRoiReadoutSync_66  <= sendRoiReadout_TPTHRU_TIG & sendRoiReadoutSync_66(sendRoiReadoutSync_66'length - 1 downto 1);
                sendRoiReadout2Sync_66 <= sendRoiReadout2_TPTHRU_TIG & sendRoiReadout2Sync_66(sendRoiReadout2Sync_66'length - 1 downto 1);
                sclkPhase              <= not sclkPhase;
                misoSync               <= miso;

                case stateSpi2 is
                    when idle =>
                        drs4_to_ltm9007_14.adcDataStart_66 <= '0';
                        spi2Done                           <= '0';
                        inhibitAdc                         <= '0';
                        roiBuffer_66                       <= (others => '0');
                        if (sendFullReadoutSync_66(0) = '1') then -- ## edge?
                            bitCounter2Max <= bitCounter1_TPTHRU_TIG; -- ## sync?!
                            stateSpi2      <= syncFull;
                        elsif (sendRoiReadoutSync_66(0) = '1') then -- ## edge?
                            bitCounter2Max <= bitCounter1_TPTHRU_TIG;   -- ## sync?!
                            stateSpi2      <= syncRoi;
                        elsif (sendRoiReadout2Sync_66(0) = '1') then -- ## edge?
                            inhibitAdc     <= '1';
                            bitCounter2Max <= bitCounter1_TPTHRU_TIG; -- ## sync?!
                            stateSpi2      <= syncRoi;
                        end if;

                    when syncFull => -- sync
                        if (sclkPhase = '0') then
                            stateSpi2 <= full;
                            --stateSpi2 <= roiSrclk; -- might be the same...
                            roiCounter  <= 0;
                            bitCounter2 <= 0;
                        end if;

                    when full =>
                        if (sclkPhase = '0') then
                            srclk2      <= '1'; -- autoreset
                            bitCounter2 <= bitCounter2 + 1;
                            if (bitCounter2 = adcPipelineStages) then
                                drs4_to_ltm9007_14.adcDataStart_66 <= '1';
                            end if;
                        end if;
                        if (bitCounter2 >= bitCounter2Max) then
                            spi2Done    <= '1';
                            stateSpi2   <= adcBacklash;
                            bitCounter2 <= 0;
                        end if;
                        if (sclkPhase = '0') then
                            if (roiCounter <= 11) then
                                roiCounter     <= roiCounter + 1;
                            end if;

                            if (roiCounter = 11) then
                                roiBufferLatched_66 <= (others => '0');
                                roiBufferReady_66   <= '1' and not(inhibitAdc); -- autoreset
                            end if;
                        end if;

                    when syncRoi => -- sync
                        if (sclkPhase = '0') then
                            stateSpi2   <= roiRsload;
                            roiCounter  <= 0;
                            bitCounter2 <= 0;
                        end if;

                    when roiRsload =>
                        if (sclkPhase = '0') then
                            rsrload2    <= '1'; -- autoreset
                            bitCounter2 <= bitCounter2 + 1;
                            stateSpi2   <= roiSrclk;
                        end if;

                    when roiSrclk =>
                        if (sclkPhase = '0') then
                            srclk2      <= '1'; -- autoreset
                            bitCounter2 <= bitCounter2 + 1;
                            if (bitCounter2 = adcPipelineStages) then
                                drs4_to_ltm9007_14.adcDataStart_66 <= '1' and not(inhibitAdc);
                            end if;
                        end if;
                        if (bitCounter2 >= bitCounter2Max) then -- has to be long enought, we need the full roi address
                            spi2Done    <= '1';
                            stateSpi2   <= adcBacklash;
                            bitCounter2 <= 0;
                        end if;

                        -- sample roi
                        if (sclkPhase = '0') then -- sclkEdgeRising but miso has lag
                            if (roiCounter < 11) then -- and (roiCounter > 0)
                                roiBuffer_66 <= roiBuffer_66(roiBuffer_66'length - 2 downto 0) & misoSync;
                            end if;

                            if (roiCounter <= 11) then
                                roiCounter     <= roiCounter + 1;
                            end if;

                            if (roiCounter = 11) then
                                roiBufferLatched_66 <= roiBuffer_66;
                                roiBufferReady_66   <= '1' and not(inhibitAdc); -- autoreset
                            end if;
                        end if;

                    when adcBacklash =>
                        spi2Done <= '1';
                        if (sclkPhase = '0') then
                            if (bitCounter2                    <= adcPipelineStages) then
                                bitCounter2                        <= bitCounter2 + 1;
                                drs4_to_ltm9007_14.adcDataStart_66 <= '1' and not(inhibitAdc);
                            else
                                drs4_to_ltm9007_14.adcDataStart_66 <= '0';
                                if ((sendFullReadoutSync_66(0) = '0') and (sendRoiReadoutSync_66(0) = '0')) then
                                    bitCounter2 <= 0;
                                    spi2Done    <= '0';
                                    stateSpi2   <= idle;
                                end if;
                            end if;
                        end if;

                        --  when manageDrs4WriteShiftRegister =>
                        --      stateSpi2 <= idle; 

                    when others =>
                        stateSpi2 <= idle;
                end case;
            end if;
        end if;
    end process P01;

    drs4_to_ltm9007_14.regionOfInterestReady      <= regionOfInterestReady;
    drs4_to_eventFifoSystem.regionOfInterestReady <= regionOfInterestReady;
    drs4_to_ltm9007_14.regionOfInterest           <= regionOfInterest;
    drs4_to_eventFifoSystem.regionOfInterest      <= regionOfInterest;
    registerRead.regionOfInterest                 <= regionOfInterest;

    P02 : process (registerWrite.clock)
    begin
        if rising_edge(registerWrite.clock) then
            roiBufferReadySync    <= roiBufferReady_66_TPTHRU_TIG & roiBufferReadySync(roiBufferReadySync'length - 1 downto 1);
            regionOfInterestReady <= '0'; -- autoreset
            if (registerWrite.reset = '1') then
                regionOfInterest <= (others => '0');
            else
                if ((roiBufferReadySync(1) = '1') and (roiBufferReadySync(0) = '0')) then
                    regionOfInterest      <= roiBufferLatched_sync;
                    regionOfInterestReady <= '1'; -- autoreset
                end if;
            end if;
        end if;
    end process P02;

    P1 : process (registerWrite.clock)
    begin
        if rising_edge(registerWrite.clock) then
            sclkEnable      <= '0'; -- autoreset
            spiDone         <= '0'; -- autoreset
            sendFullReadout <= '0'; -- autoreset
            sendRoiReadout  <= '0'; -- autoreset
            sendRoiReadout2 <= '0'; -- autoreset
            --drs4_to_ltm9007_14.roiBufferReady <= '0'; -- autoreset 
            --drs4_to_ltm9007_14.drs4RoiValid <= '0'; -- autoreset
            misoSync125 <= miso;
            if (registerWrite.reset = '1') then
                stateDrs4Spi  <= idle;
                address       <= address_stabdby;
                inhibitSclk   <= '0';
                enableRsrload <= '0';
                --drs4_to_ltm9007_14.roiBuffer <= (others=>'0');
                configRegister <= "111";
                --writeShiftRegister <= "11111111";
                writeConfigRegister <= "11111111";
                rxBuffer            <= (others => '0');
            else
                spiTransfer_old <= spiTransfer;
                spi2DoneSync    <= spi2Done_TPTHRU_TIG & spi2DoneSync(spi2DoneSync'length - 1 downto 1);

                case stateDrs4Spi is
                    when idle =>
                        if ((spiTransfer_old = '0') and (spiTransfer = '1')) then
                            if (spiTransferMode = readShiftRegister_write) then
                                address      <= address_readShiftRegister;
                                stateDrs4Spi <= transfer1;
                                bitCounter1  <= 1024;
                                --bitCounter1 <= to_integer(unsigned(registerWrite.numberOfSamplesToRead));
                                txBuffer <= "010000000";
                            elsif (spiTransferMode = configRegister_write) then
                                address      <= address_configRegister;
                                stateDrs4Spi <= transfer1;
                                --stateDrs4Spi <= transfer2;
                                bitCounter1 <= 8;
                                txBuffer    <= "011111" & configRegister;
                            elsif (spiTransferMode = writeShiftRegister_transfer) then
                                address      <= address_writeShiftRegister;
                                stateDrs4Spi <= transfer1;
                                --stateDrs4Spi <= transfer2;
                                bitCounter1 <= 8;
                                txBuffer    <= "0" & registerWrite.writeShiftRegister;
                                rxBuffer    <= (others => '0'); -- ## debug
                            elsif (spiTransferMode = standby) then
                                address <= address_stabdby;
                                spiDone <= '1'; -- autoreset
                            elsif (spiTransferMode = sampleTransparentMode) then
                                address <= address_transparentMode;
                                spiDone <= '1'; -- autoreset
                            elsif (spiTransferMode = sampleNormalMode) then
                                address <= address_enableAllOutputs;
                                spiDone <= '1'; -- autoreset
                            elsif (spiTransferMode = regionOfIntrest) then
                                address      <= address_enableAllOutputs;
                                stateDrs4Spi <= readRegionOfInterest;
                                bitCounter1  <= to_integer(unsigned(registerWrite.numberOfSamplesToRead));
                                --roiCounter <= 0;
                                txBuffer      <= "000000000";
                                inhibitSclk   <= '1';
                                enableRsrload <= '1';
                            elsif (spiTransferMode = fullReadout) then
                                address      <= address_enableAllOutputs;
                                stateDrs4Spi <= readFullChip;
                                --bitCounter1 <= 999;
                                bitCounter1 <= to_integer(unsigned(registerWrite.numberOfSamplesToRead));
                            elsif (spiTransferMode = regionOfIntrest2) then
                                address      <= address_enableAllOutputs;
                                stateDrs4Spi <= readRegionOfInterest2;
                                bitCounter1  <= to_integer(unsigned(registerWrite.numberOfSamplesToRead));
                            elsif (spiTransferMode = regionOfIntrest3) then
                                address      <= address_enableAllOutputs;
                                stateDrs4Spi <= readRegionOfInterest3;
                                bitCounter1  <= to_integer(unsigned(registerWrite.numberOfSamplesToRead));
                                --bitCounter1 <= to_integer(unsigned(registerWrite.numberOfSamplesToRead)/2);
                            elsif (spiTransferMode = fullReadout2) then
                                address      <= address_enableAllOutputs;
                                stateDrs4Spi <= readFullChip2;
                                bitCounter1  <= to_integer(unsigned(registerWrite.numberOfSamplesToRead));
                            elsif (spiTransferMode = writeConfigRegister_write) then
                                address      <= address_writeConfigRegister;
                                stateDrs4Spi <= transfer1;
                                bitCounter1  <= 8;
                                txBuffer     <= "0" & writeConfigRegister;
                            end if;
                        end if;

                    when transfer1 =>
                        sclkEnable <= '1'; -- autoreset
                        busy       <= '1'; -- autoreset
                        if (sclkEdgeRising = '1') then
                            if (spiTransferMode = readShiftRegister_write) then
                                if (bitCounter1 <= 1) then
                                    txBuffer        <= txBuffer(txBuffer'length - 2 downto 0) & mosiDefaultLevel;
                                    --txBuffer(txBuffer'length-1) <= '1';
                                end if;
                            else
                                if (bitCounter1 /= 0) then
                                    txBuffer <= txBuffer(txBuffer'length - 2 downto 0) & mosiDefaultLevel;
                                end if;
                            end if;

                            bitCounter1 <= bitCounter1 - 1;
                            if (bitCounter1 = 0) then
                                stateDrs4Spi <= transferEnd;
                                bitCounter1  <= 0;
                            end if;
                        end if;
                        if ((sclkEdgeFalling = '1') and (bitCounter1 = 0)) then
                            inhibitSclk <= '1';
                        end if;
                        if (sclkEdgeRisingDelayed = '1') then
                            -- ## omg simulate this!!11! there shold be no need for one more bit
                            --rxBuffer <= misoSync125 & rxBuffer(rxBuffer'length-1 downto 1); -- ## lag??
                            rxBuffer <= rxBuffer(rxBuffer'length - 2 downto 0) & misoSync125; -- ## lag??
                        end if;

                    when readFullChip2 =>
                        busy            <= '1';
                        sendFullReadout <= '1'; -- autoreset
                        if (spi2DoneSync(0) = '1') then
                            stateDrs4Spi <= transferEnd2;
                        end if;

                    when readRegionOfInterest2 =>
                        busy           <= '1';
                        sendRoiReadout <= '1'; -- autoreset
                        if (spi2DoneSync(0) = '1') then
                            stateDrs4Spi <= transferEnd2;
                        end if;

                    when readRegionOfInterest3 =>
                        busy            <= '1';
                        sendRoiReadout2 <= '1'; -- autoreset
                        if (spi2DoneSync(0) = '1') then
                            stateDrs4Spi <= transferEnd2;
                        end if;

                    when readRegionOfInterest => -- ## drs4RoiValid is not used anymore....
                        sclkEnable <= '1';           -- autoreset
                        busy       <= '1';           -- autoreset
                        if (sclkEdgeRising = '1') then
                            --if((roiCounter > 0) and (roiCounter < 9)) then
                            --  roiBuffer <= roiBuffer(roiBuffer'length-2 downto 0) & miso;
                            --end if;

                            --if(roiCounter < 9) then
                            --  roiCounter <= roiCounter + 1;
                            --end if;

                            if (bitCounter1 > 0) then
                                bitCounter1 <= bitCounter1 - 1;
                            end if;

                            --if(roiCounter = 9) then
                            --  registerRead.regionOfInterest <= roiBuffer;
                            --  drs4_to_ltm9007_14.roiBuffer <= roiBuffer;
                            --  drs4_to_ltm9007_14.roiBufferReady <= '1'; -- autoreset
                            if (bitCounter1 = 0) then
                                stateDrs4Spi <= transferEnd;
                                bitCounter1  <= 0;
                            end if;
                            --end if;

                        end if;

                        --if (sclkEdgeFalling = '1') then   
                        --  if(roiCounter = 1) then
                        --      inhibitSclk <= '0';
                        --      enableRsrload <= '0';
                        --  end if;
                        --end if;

                    when readFullChip =>
                        sclkEnable <= '1'; -- autoreset
                        busy       <= '1'; -- autoreset
                        if (sclkEdgeRising = '1') then
                            if (bitCounter1 > 0) then
                                bitCounter1 <= bitCounter1 - 1;
                            else
                                stateDrs4Spi <= transferEnd;
                                bitCounter1  <= 0;
                            end if;
                        end if;

                    when transferEnd =>
                        busy        <= '1'; -- autoreset
                        bitCounter1 <= bitCounter1 + 1;
                        --sclkEnable <= '1'; -- autoreset
                        --if (sclkEdgeFalling = '1') then
                        --  inhibitSclk <= '1';
                        --end if;
                        if (bitCounter1 >= 4) then -- ## may be we dont have to wait at all ...
                            --if (sclkEdgeRising = '1') then
                            --registerRead.regionOfInterest <= roiBuffer;
                            stateDrs4Spi <= idle;
                            txBuffer     <= (others => '0');
                            inhibitSclk  <= '0';
                            spiDone      <= '1'; -- autoreset
                        end if;

                    when transferEnd2 =>
                        if (spi2DoneSync(0) = '0') then
                            stateDrs4Spi <= idle;
                            spiDone      <= '1'; -- autoreset
                        end if;

                    when others => null;
                end case;

            end if;
        end if;
    end process P1;

    mosi <= txBuffer(txBuffer'length - 1);

    P2 : process (registerWrite.clock)
    begin
        if rising_edge(registerWrite.clock) then
            notReset                                   <= '1'; -- autoreset
            spiTransfer                                <= '0'; -- autoreset
            denable                                    <= '0'; -- autoreset
            dwrite_i                                   <= '0'; -- autoreset
            drs4_to_eventFifoSystem.cascadingDataReady <= '0'; -- autoreset
            if (registerWrite.reset = '1') then
                --denable <= '0';
                --dwrite_i <= '0';
                drs4_to_eventFifoSystem.realTimeCounter_latched <= (others => '0');
                drs4_to_eventFifoSystem.cascadingData           <= (others => '0');
                drs4_to_eventFifoSystem.cascadingDataShort      <= (others => '0');
                stateDrs4                                       <= init1;
                deadTime                                        <= '0';
            else
                stopDrs4_old <= stopDrs4;

                if (registerWrite.resetStates = '1') then
                    stateDrs4 <= init1;
                end if;

                case stateDrs4 is
                    when init1 =>
                        counter1        <= 0;
                        spiTransferMode <= standby;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            stateDrs4   <= init2;
                            spiTransfer <= '0'; -- autoreset
                        end if;

                    when init2 =>
                        notReset <= '0'; -- autoreset
                        counter1 <= counter1 + 1;
                        if (counter1 = 10) then
                            stateDrs4 <= init3;
                            counter1  <= 0;
                        end if;

                    when init3 =>
                        counter1 <= counter1 + 1;
                        --if(counter1 = 250) then -- 250 = ~2us
                        if (counter1 = 1250000) then -- 1250k = ~10ms
                            stateDrs4 <= init4;
                            counter1  <= 0;
                        end if;

                    when init4 =>
                        spiTransferMode <= configRegister_write;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            stateDrs4   <= init5;
                            spiTransfer <= '0'; -- autoreset
                        end if;

                    when init5 =>
                        spiTransferMode <= writeShiftRegister_transfer;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            --stateDrs4 <= drs4start0;
                            stateDrs4   <= init6;
                            spiTransfer <= '0'; -- autoreset
                        end if;

                    when init6 =>
                        spiTransferMode <= writeConfigRegister_write;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            stateDrs4   <= init7;
                            spiTransfer <= '0'; -- autoreset
                        end if;

                    when init7 =>
                        spiTransferMode <= readShiftRegister_write;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            stateDrs4   <= drs4start0;
                            spiTransfer <= '0'; -- autoreset
                        end if;

                    when drs4start0 =>
                        counter1  <= 0;
                        denable   <= '1'; -- autoreset
                        dwrite_i  <= '1';
                        stateDrs4 <= drs4start1;

                    when drs4start1 =>
                        denable  <= '1'; -- autoreset
                        dwrite_i <= '1';
                        counter1 <= counter1 + 1;
                        if (counter1 = 125) then -- 125 = ~1us ## ?!?
                            stateDrs4 <= startSampling;
                        end if;

                    when startSampling =>
                        denable  <= '1'; -- autoreset
                        dwrite_i <= '1';
                        deadTime <= '0';
                        if (registerWrite.sampleMode = x"0") then
                            spiTransferMode <= sampleNormalMode;
                        elsif (registerWrite.sampleMode = x"1") then
                            spiTransferMode <= sampleTransparentMode;
                        else
                            spiTransferMode <= sampleNormalMode;
                        end if;
                        spiTransfer <= '1'; -- autoreset
                        if (spiDone = '1') then
                            stateDrs4   <= sampling;
                            spiTransfer <= '0'; -- autoreset
                        end if;

                    when sampling =>
                        denable  <= '1'; -- autoreset
                        dwrite_i <= '1';
                        if ((stopDrs4_old = '0') and (stopDrs4 = '1')) then
                            if (registerWrite.readoutMode = x"0") then
                                stateDrs4 <= readFull;
                            elsif (registerWrite.readoutMode = x"1") then
                                stateDrs4 <= readRoi;
                            elsif (registerWrite.readoutMode = x"2") then
                                stateDrs4 <= debug;
                            elsif (registerWrite.readoutMode = x"3") then
                                stateDrs4 <= debug;
                            elsif (registerWrite.readoutMode = x"4") then
                                stateDrs4 <= readFull2;
                            elsif (registerWrite.readoutMode = x"5") then
                                stateDrs4 <= readRoi2;
                            elsif (registerWrite.readoutMode = x"6") then
                                stateDrs4 <= readRoi3;
                            else
                                stateDrs4 <= readFull;
                            end if;
                            dwrite_i                                        <= '0';
                            drs4_to_eventFifoSystem.realTimeCounter_latched <= internalTiming.realTimeCounter;
                            deadTime                                        <= '1'; -- ## lag...
                        end if;

                    when debug =>
                        spiTransferMode <= readShiftRegister_write;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            spiTransfer <= '0'; -- autoreset
                            if (registerWrite.readoutMode = x"2") then
                                stateDrs4 <= readFull;
                            elsif (registerWrite.readoutMode = x"3") then
                                stateDrs4 <= readRoi;
                            else
                                stateDrs4 <= readFull;
                            end if;
                        end if;

                    when readRoi =>
                        denable         <= '1'; -- autoreset
                        spiTransferMode <= regionOfIntrest;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            stateDrs4   <= manageDrs4Cascading;
                            spiTransfer <= '0'; -- autoreset
                        end if;

                    when readFull =>
                        denable         <= '1'; -- autoreset
                        spiTransferMode <= fullReadout;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            stateDrs4   <= manageDrs4Cascading;
                            spiTransfer <= '0'; -- autoreset
                        end if;

                    when readRoi2 =>
                        denable         <= '1'; -- autoreset
                        spiTransferMode <= regionOfIntrest2;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            stateDrs4   <= manageDrs4Cascading;
                            spiTransfer <= '0'; -- autoreset
                        end if;

                    when readRoi3 =>
                        denable         <= '1'; -- autoreset
                        spiTransferMode <= regionOfIntrest3;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            stateDrs4   <= readRoi2;
                            spiTransfer <= '0'; -- autoreset
                        end if;

                    when readFull2 =>
                        denable         <= '1'; -- autoreset
                        spiTransferMode <= fullReadout2;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            stateDrs4   <= manageDrs4Cascading;
                            spiTransfer <= '0'; -- autoreset
                        end if;

                        --      when manageDrs4Cascading =>
                        --          denable <= '1'; -- autoreset
                        --          stateDrs4 <= startSampling;

                    when manageDrs4Cascading =>
                        denable         <= '1'; -- autoreset
                        spiTransferMode <= writeShiftRegister_transfer;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            stateDrs4 <= drs4start0;
                            --stateDrs4 <= startSampling;
                            --stateDrs4 <= manageDrs4Cascading2; -- debug
                            spiTransfer                                <= '0'; -- autoreset
                            writeShiftRegister_readBack                <= rxBuffer;
                            drs4_to_eventFifoSystem.cascadingDataReady <= '1';      -- autoreset
                            drs4_to_eventFifoSystem.cascadingData      <= rxBuffer; --(8 downto 1);
                            registerRead.cascadingDataDebug            <= rxBuffer; --(8 downto 1);

                            case rxBuffer is
                                when "00000001" => drs4_to_eventFifoSystem.cascadingDataShort <= "0000";
                                when "00000010" => drs4_to_eventFifoSystem.cascadingDataShort <= "0001";
                                when "00000100" => drs4_to_eventFifoSystem.cascadingDataShort <= "0010";
                                when "00001000" => drs4_to_eventFifoSystem.cascadingDataShort <= "0011";
                                when "00010000" => drs4_to_eventFifoSystem.cascadingDataShort <= "0100";
                                when "00100000" => drs4_to_eventFifoSystem.cascadingDataShort <= "0101";
                                when "01000000" => drs4_to_eventFifoSystem.cascadingDataShort <= "0110";
                                when "10000000" => drs4_to_eventFifoSystem.cascadingDataShort <= "0111";
                                when others     => drs4_to_eventFifoSystem.cascadingDataShort     <= "1000";
                            end case;
                        end if;

                    when manageDrs4Cascading2 =>
                        denable         <= '1'; -- autoreset
                        spiTransferMode <= writeShiftRegister_transfer;
                        spiTransfer     <= '1'; -- autoreset
                        if (spiDone = '1') then
                            stateDrs4 <= drs4start0;
                            --stateDrs4 <= startSampling;
                            spiTransfer                                <= '0'; -- autoreset
                            writeShiftRegister_readBack                <= rxBuffer;
                            drs4_to_eventFifoSystem.cascadingDataReady <= '1';      -- autoreset
                            drs4_to_eventFifoSystem.cascadingData      <= rxBuffer; --(8 downto 1);
                            registerRead.cascadingDataDebug            <= rxBuffer; --(8 downto 1);
                        end if;

                    when others => stateDrs4 <= init1;
                end case;

            end if;
        end if;
    end process P2;
    --end generate;

end Behavioral;

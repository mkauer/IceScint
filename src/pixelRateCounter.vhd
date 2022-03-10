----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    20:29:56 03/08/2017 
-- Design Name: 
-- Module Name:    pixelRateCounter - Behavioral 
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
--use work.types_platformSpecific.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity pixelRateCounter is
    port (
        triggerPixelIn      : in  std_logic_vector(8 * numberOfChannels - 1 downto 0);
        deadTime            : in  std_logic;
        sumTriggerSameEvent : in  std_logic;
        --          eventTrigger : in std_logic;
        rateCounterTimeOut  : out std_logic;
        pixelRateCounter    : out pixelRateCounter_t;
        internalTiming      : in  internalTiming_t;
        registerRead        : out pixelRateCounter_registerRead_t;
        registerWrite       : in  pixelRateCounter_registerWrite_t
        );
end pixelRateCounter;

architecture behavioral of pixelRateCounter is
    signal sameEvent                               : std_logic_vector(numberOfChannels - 1 downto 0) := (others => '0');  -- is like sampling dead time, not readout dead time... trigger that are close will be count as one / same event..... all per channel, not the best way to do this....
    type counter2_t is array (0 to numberOfChannels - 1) of unsigned(7 downto 0);
    signal sameEventCounter                        : counter2_t;
    signal sameEventTime                           : std_logic_vector(7 downto 0)                    := x"00";
    signal doublePulsePrevention                   : std_logic                                       := '0';
    --    signal rateCounterTimeOut : std_logic := '0';
    signal pixel                                   : std_logic_vector(numberOfChannels - 1 downto 0) := (others => '0');
    signal pixel_old                               : std_logic_vector(pixel'length - 1 downto 0)     := (others => '0');
    type counter_t is array (0 to numberOfChannels - 1) of unsigned(15 downto 0);
    signal pixelCounterAllEdges                    : counter_t                                       := (others => (others => '0'));
    signal pixelCounterAllEdgesLatched             : counter_t                                       := (others => (others => '0'));
    signal pixelCounterPreventedDoublePulse        : counter_t                                       := (others => (others => '0'));
    signal pixelCounterPreventedDoublePulseLatched : counter_t                                       := (others => (others => '0'));
    signal pixelCounter                            : counter_t                                       := (others => (others => '0'));
    signal pixelCounterLatched                     : counter_t                                       := (others => (others => '0'));
    signal pixelCounterInsideDeadTime              : counter_t                                       := (others => (others => '0'));
    signal pixelCounterInsideDeadTimeLatched       : counter_t                                       := (others => (others => '0'));
    signal pixelCounterDebug                       : counter_t                                       := (others => (others => '0'));
    signal pixelCounterDebugLatched                : counter_t                                       := (others => (others => '0'));
    signal counter_ms                              : unsigned(15 downto 0)                           := (others => '0');
    signal counter_sec                             : unsigned(15 downto 0)                           := (others => '0');
    signal allEdges                                : counter_t                                       := (others => (others => '0'));
    signal realTimeDeltaCounter                    : unsigned(63 downto 0)                           := (others => '0');
    signal realTimeDeltaCounterLatched             : std_logic_vector(63 downto 0)                   := (others => '0');
    signal realTimeCounterLatched                  : std_logic_vector(63 downto 0)                   := (others => '0');
    --signal channel : counter_t := (others => (others => '0'));
    signal eventSamplingTime                       : unsigned(7 downto 0)                            := (others => '0');
    signal eventSamplingCounter                    : unsigned(7 downto 0)                            := (others => '0');
    signal eventSamplingActive                     : std_logic                                       := '0';
    signal eventTrigger_old                        : std_logic                                       := '0';

    signal newData         : std_logic := '0';
    signal newData_latched : std_logic := '0';

begin

    registerRead.counterPeriod     <= registerWrite.counterPeriod;
    pixelRateCounter.counterPeriod <= registerWrite.counterPeriod;

    registerRead.doublePulsePrevention <= registerWrite.doublePulsePrevention;
    doublePulsePrevention              <= registerWrite.doublePulsePrevention;
    registerRead.doublePulseTime       <= registerWrite.doublePulseTime;
    sameEventTime                      <= registerWrite.doublePulseTime;
    --    eventSamplingTime <= registerWrite.eventSamplingTime; -- ## should be number of samples to read / 8 if timeslot =8ns and drs4 sampling speed = 1Gs

    pixelRateCounter.realTimeCounterLatched      <= realTimeCounterLatched;
    pixelRateCounter.realTimeDeltaCounterLatched <= realTimeDeltaCounterLatched;

    g0 : for i in 0 to numberOfChannels - 1 generate
        --pixelRateCounter.channelLatched(i) <= std_logic_vector(pixelCounterLatched(i));
        pixelRateCounter.channelLatched(i)         <= std_logic_vector(pixelCounterAllEdgesLatched(i));
        pixelRateCounter.channelDeadTimeLatched(i) <= std_logic_vector(pixelCounterInsideDeadTimeLatched(i));

        registerRead.pixelCounterAllEdgesLatched(i)             <= std_logic_vector(pixelCounterAllEdgesLatched(i));
        registerRead.pixelCounterPreventedDoublePulseLatched(i) <= std_logic_vector(pixelCounterPreventedDoublePulseLatched(i));
        registerRead.pixelCounterLatched(i)                     <= std_logic_vector(pixelCounterLatched(i));
        registerRead.pixelCounterInsideDeadTimeLatched(i)       <= std_logic_vector(pixelCounterInsideDeadTimeLatched(i));
        registerRead.pixelCounterDebugLatched(i)                <= std_logic_vector(pixelCounterDebugLatched(i));
    end generate;

    pixelRateCounter.newData <= newData;
    registerRead.newData     <= newData_latched;
    P0 : process (registerWrite.clock)
    begin
        if rising_edge(registerWrite.clock) then
            newData            <= '0';  -- autoreset
            rateCounterTimeOut <= '0';  -- autorest
            if (registerWrite.reset = '1') then
                pixel       <= (others => '0');
                pixel_old   <= (others => '0');
                counter_ms  <= (others => '0');
                counter_sec <= (others => '0');

                pixelCounterAllEdges                    <= (others => (others => '0'));
                pixelCounterAllEdgesLatched             <= (others => (others => '0'));
                pixelCounterPreventedDoublePulse        <= (others => (others => '0'));
                pixelCounterPreventedDoublePulseLatched <= (others => (others => '0'));
                pixelCounter                            <= (others => (others => '0'));
                pixelCounterLatched                     <= (others => (others => '0'));
                pixelCounterInsideDeadTime              <= (others => (others => '0'));
                pixelCounterInsideDeadTimeLatched       <= (others => (others => '0'));
                pixelCounterDebug                       <= (others => (others => '0'));
                pixelCounterDebugLatched                <= (others => (others => '0'));

                realTimeDeltaCounter        <= (others => '0');
                realTimeDeltaCounterLatched <= (others => '0');
                realTimeCounterLatched      <= (others => '0');
                sameEvent                   <= (others => '0');
                sameEventCounter            <= (others => (others => '0'));
                eventSamplingCounter        <= (others => '0');
                eventSamplingActive         <= '0';
                eventTrigger_old            <= '0';
                newData_latched             <= '0';
            else
                newData_latched <= (newData_latched or newData) and not registerWrite.newDataReset;

                pixel_old            <= pixel;
                realTimeDeltaCounter <= realTimeDeltaCounter + 1;

                if (internalTiming.tick_ms = '1') then
                    counter_ms <= counter_ms + 1;
                end if;
                if (counter_ms >= x"03e7") then
                    counter_ms  <= (others => '0');
                    counter_sec <= counter_sec + 1;
                end if;

                for i in 0 to numberOfChannels - 1 loop
                    if (triggerPixelIn(i * 8 + 7 downto i * 8) /= x"00") then  -- ## this has odd time slot dependencys.... fast pulses can concartinate
                        pixel(i) <= '1';
                    else
                        pixel(i) <= '0';
                    end if;

                    if ((pixel_old(i) = '0') and (pixel(i) = '1')) then
                        sameEvent(i)        <= '1';  -- ## lag
                        sameEventCounter(i) <= (others => '0');
                    end if;
                    if (sameEvent(i) = '1') then
                        sameEventCounter(i) <= sameEventCounter(i) + 1;  -- ## more lag
                    end if;
                    if (sameEventCounter(i) >= unsigned(sameEventTime)) then  -- ## even more lag
                        sameEventCounter(i) <= (others => '0');
                        sameEvent(i)        <= '0';
                    end if;
                                                     --if((pixel_old(i) = '0') and (pixel(i) = '1')) then
                                                     --if((pixel_old(i) = '0') and (pixel(i) = '1') and ((sameEvent(i) = '0') or (doublePulsePrevention = '0'))) then
                    if ((pixel_old(i) = '0') and (pixel(i) = '1')) then
                        pixelCounterAllEdges(i) <= pixelCounterAllEdges(i) + 1;
                        if (pixelCounterAllEdges(i) = x"ffff") then
                            pixelCounterAllEdges(i) <= x"ffff";
                        end if;

                        if ((sameEvent(i) = '1') and (doublePulsePrevention = '1')) then
                                        -- all edges but the first
                            pixelCounterPreventedDoublePulse(i) <= pixelCounterPreventedDoublePulse(i) + 1;
                            if (pixelCounterPreventedDoublePulse(i) = x"ffff") then
                                pixelCounterPreventedDoublePulse(i) <= x"ffff";
                            end if;
                                        --end if;
                        else
                            if ((deadTime = '1') and (sumTriggerSameEvent = '1')) then  -- ## buggy!!!! deadtime is to late...
                                        -- cleaned channel events 
                                pixelCounter(i) <= pixelCounter(i) + 1;
                                if (pixelCounter(i) = x"ffff") then
                                    pixelCounter(i) <= x"ffff";
                                end if;
                            elsif ((deadTime = '1') and (sumTriggerSameEvent = '0')) then
                                pixelCounterInsideDeadTime(i) <= pixelCounterInsideDeadTime(i) + 1;
                                if (pixelCounterInsideDeadTime(i) = x"ffff") then
                                    pixelCounterInsideDeadTime(i) <= x"ffff";
                                end if;
                            else
                                pixelCounterDebug(i) <= pixelCounterDebug(i) + 1;
                                if (pixelCounterDebug(i) = x"ffff") then
                                    pixelCounterDebug(i) <= x"ffff";
                                end if;
                            end if;
                        end if;
                    end if;

                    if (registerWrite.resetCounter(i) = '1') then
                        pixelCounterAllEdges(i)             <= (others => '0');
                        pixelCounterPreventedDoublePulse(i) <= (others => '0');
                        pixelCounter(i)                     <= (others => '0');
                        pixelCounterInsideDeadTime(i)       <= (others => '0');
                        pixelCounterDebug(i)                <= (others => '0');
                        realTimeDeltaCounter                <= (others => '0');  -- ##
                    end if;
                end loop;

                if (registerWrite.counterPeriod = x"0000") then
                    pixelCounterAllEdgesLatched             <= pixelCounterAllEdges;
                    pixelCounterPreventedDoublePulseLatched <= pixelCounterPreventedDoublePulse;
                    pixelCounterLatched                     <= pixelCounter;
                    pixelCounterInsideDeadTimeLatched       <= pixelCounterInsideDeadTime;
                    pixelCounterDebugLatched                <= pixelCounterDebug;
                elsif (counter_sec >= unsigned(registerWrite.counterPeriod)) then  -- ## rates for continuous operation
                    counter_sec <= (others => '0');

                    pixelCounterAllEdgesLatched             <= pixelCounterAllEdges;
                    pixelCounterPreventedDoublePulseLatched <= pixelCounterPreventedDoublePulse;
                    pixelCounterLatched                     <= pixelCounter;
                    pixelCounterInsideDeadTimeLatched       <= pixelCounterInsideDeadTime;
                    pixelCounterDebugLatched                <= pixelCounterDebug;

                    pixelCounterAllEdges             <= (others => (others => '0'));
                    pixelCounterPreventedDoublePulse <= (others => (others => '0'));
                    pixelCounter                     <= (others => (others => '0'));
                    pixelCounterInsideDeadTime       <= (others => (others => '0'));
                    pixelCounterDebug                <= (others => (others => '0'));

                    newData                     <= '1';  -- autoreset
                    realTimeCounterLatched      <= internalTiming.realTimeCounter;
                    realTimeDeltaCounterLatched <= std_logic_vector(realTimeDeltaCounter);
                    realTimeDeltaCounter        <= (others => '0');
                    rateCounterTimeOut          <= '1';  -- autorest
                end if;

                --                              ... eventTrigger has to go to triggerLogic
                --                              eventTrigger_old <= eventTrigger;
                --                              if((eventTrigger_old = '0') and (eventTrigger = '1')) then
                --                                      eventSamplingCounter <= x"01";
                --                                      eventSamplingActive <= '1';
                --                              end if;
                --
                --                              if(eventSamplingCounterEnable = '1') then
                --                                      eventSamplingCounter <= eventSamplingCounter + 1;
                --                              end if;
                --                              if(eventSamplingCounter >= eventSamplingTime) then
                --                                      eventSamplingCounter <= x"00";
                --                                      eventSamplingActive <= '0';
                --                              end if;

            end if;
        end if;
    end process P0;

end behavioral;

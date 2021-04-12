--Das ist eine einfache Implementierung einer RS232 Schnittstelle.

-- File: uart_RxTx_V2
--Die bertragung erfolgt im Format 8 Datenbits, keine Parity, 1 Stop-Bit. 
--Die Baudrate kann generisch angegeben werden, die ntige Zhlerbreite und 
--der Zhlerwert wird dann aus aus der Taktfrequenz berechnet.
--
--Senden:
--Erst mu abgewartet werden bis das Signal TX_Busy inaktiv (='0') ist. 
--Dann knnen am Port TX_Data 8 Datenbits angelegt und mindestens 1 Takt lang das Signal 
--TX_Start aktiviert werden. Eine Flankenerkennung im Sendeteil erkennt die steigende Flanke 
--von TX_Start und beginnt sofort mit der bertragung. Whrend der bertragung der Daten geht TX_Busy auf '1'.
--
--Empfangen:
--Der (asynchrone) Eingangspin RXD wird ber ein 4-Bit-Schieberegister (rxd_sr) einsynchronisiert. 
--Die letzten beiden Bits werden zur Flankenerkennung verwendet rxd_sr(3 downto 2). 
--Eine fallende Flanke wird als Startbit erkannt, danach wird eine halbe Bitzeit gewartet, 
--und dann 9 Bits in das 8 Bit Empfangsdaten-Schieberegister rxsr eingetaktet. Damit wird das 
--Startbit eingelesen, dann aber einfach durchgetaktet und fllt vorne wieder aus dem Schieberegister heraus. 
--Nch dem Erkennen des Start-Bits und whrend des Empfang der Daten geht das Signal RX_Busy auf '1'. 
--Die fallende Flanke von RX_Busy zeigt also den Empfang eines Zeichens an.
--Dieses Zeichen sollte dann gleich abgeholt und weggespeichert werden, denn mit dem Erkennen des nchsten 
--Start-Bits werden die Daten einfach berschrieben.
-- Quelle: http://www.lothar-miller.de/s9y/categories/42-RS232
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity uart_RxTx_V2 is
   generic (
      Quarz_Taktfrequenz : integer := 50000000; -- Hertz 
      Baudrate           : integer := 9600      -- Bits/Sec
   );
   port (
      RXD : in std_logic;
      --RX_Fifo_Read_Strobe : in std_logic;
      --RX_Fifo_Clear        : in std_logic;
      --RX_Fifo_Words       : out std_logic_vector(3 downto 0);
      --RX_Fifo_Full        : out std_logic;
      RX_Data  : out std_logic_vector (7 downto 0);
      RX_Busy  : out std_logic;
      TXD      : out std_logic;
      TX_Data  : in std_logic_vector (7 downto 0);
      TX_Start : in std_logic;
      TX_Busy  : out std_logic;
      CLK      : in std_logic
   );
end uart_RxTx_V2;

architecture Behavioral of uart_RxTx_V2 is

   --component uart_fifo_16byte is
   --PORT (
   --   CLK              : IN  std_logic;
   --   DATA_COUNT       : OUT std_logic_vector(4-1 DOWNTO 0);
   --   SRST             : IN  std_logic;
   --   WR_EN            : IN  std_logic;
   --   RD_EN            : IN  std_logic;
   --   DIN              : IN  std_logic_vector(8-1 DOWNTO 0);
   --   DOUT             : OUT std_logic_vector(8-1 DOWNTO 0);
   --   FULL             : OUT std_logic;
   --   EMPTY            : OUT std_logic);
   --end component;

   signal txstart  : std_logic                     := '0';
   signal txsr     : std_logic_vector (9 downto 0) := "1111111111"; -- Startbit, 8 Datenbits, Stopbit
   signal txbitcnt : integer range 0 to 10         := 10;
   signal txcnt    : integer range 0 to (Quarz_Taktfrequenz/Baudrate) - 1;

   signal rxd_sr   : std_logic_vector (3 downto 0) := "1111";     -- Flankenerkennung und Eintakten
   signal rxsr     : std_logic_vector (7 downto 0) := "00000000"; -- 8 Datenbits
   signal rxbitcnt : integer range 0 to 9          := 9;
   signal rxcnt    : integer range 0 to (Quarz_Taktfrequenz/Baudrate) - 1;

   --signal fifo_wr_strobe : std_logic;
   --signal fifo_data_in   : std_logic_vector(7 downto 0);

begin

   -- fifo_data_in <= rxsr;
   --
   --  exdes_inst : uart_fifo_16byte 
   --    PORT MAP (
   --           CLK            => CLK,
   --           DATA_COUNT     => RX_Fifo_Words,
   --           SRST           => RX_Fifo_Clear,
   --           WR_EN            => fifo_wr_strobe,
   --           RD_EN          => RX_Fifo_Read_Strobe,
   --           DIN            => fifo_data_in,
   --           DOUT           => RX_Data,
   --           FULL           => RX_Fifo_Full,
   --           EMPTY          => open);

   -- Senden
   process begin
      wait until rising_edge(CLK);
      txstart <= TX_Start;
      if (TX_Start = '1' and txstart = '0') then -- steigende Flanke, los gehts
         txcnt    <= 0;                             -- Zhler initialisieren
         txbitcnt <= 0;
         txsr     <= '1' & TX_Data & '0'; -- Stopbit, 8 Datenbits, Startbit, rechts gehts los
      else
         if (txcnt < (Quarz_Taktfrequenz/Baudrate) - 1) then
            txcnt <= txcnt + 1;
         else -- nchstes Bit ausgeben  
            if (txbitcnt < 10) then
               txcnt    <= 0;
               txbitcnt <= txbitcnt + 1;
               txsr     <= '1' & txsr(txsr'left downto 1);
            end if;
         end if;
      end if;
   end process;
   TXD     <= txsr(0); -- LSB first
   TX_Busy <= '1' when (TX_Start = '1' or txbitcnt < 10) else
      '0';

   -- Empfangen
   process begin
      wait until rising_edge(CLK);
      rxd_sr <= rxd_sr(rxd_sr'left - 1 downto 0) & RXD;
      if (rxbitcnt < 9) then -- Empfang luft
         if (rxcnt < (Quarz_Taktfrequenz/Baudrate) - 1) then
            rxcnt <= rxcnt + 1;
         else
            rxcnt    <= 0;
            rxbitcnt <= rxbitcnt + 1;
            rxsr     <= rxd_sr(rxd_sr'left - 1) & rxsr(rxsr'left downto 1); -- rechts schieben, weil LSB first

            --- added by mp to strobe data into fifo
            --if (rxbitcnt=8) then
            --  -- write data to fifo on last bit
            --  fifo_wr_strobe <='1';
            --end if;

         end if;
      else                                               -- warten auf Startbit
         if (rxd_sr(3 downto 2) = "10") then                -- fallende Flanke Startbit
            rxcnt    <= ((Quarz_Taktfrequenz/Baudrate) - 1)/2; -- erst mal nur halbe Bitzeit abwarten
            rxbitcnt <= 0;
         end if;
      end if;
   end process;

   RX_Data <= rxsr;
   RX_Busy <= '1' when (rxbitcnt < 9) else
      '0';

end Behavioral;

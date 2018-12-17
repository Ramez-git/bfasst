-------------------------------------------------------------------------------
--	MiniGA
--  Author: Thomas Pototschnig (thomas.pototschnig@gmx.de)
--
--  License: Creative Commons Attribution-NonCommercial-ShareAlike 2.0 License
--           http://creativecommons.org/licenses/by-nc-sa/2.0/de/
--
--  If you want to use MiniGA for commercial purposes please contact the author
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity dds_sinus is
    Port ( clk : in std_logic;
           reset : in std_logic;
			  adr : in std_logic_vector (6 downto 0);
			  output1 : out std_logic_vector (15 downto 0));
end dds_sinus;

architecture Behavioral of dds_sinus is

begin
	process (adr)
	begin
		case adr is
			when "0000000" => output1 <= "0000000011001001"; -- 0.0061
			when "0000001" => output1 <= "0000001001011011"; -- 0.0184
			when "0000010" => output1 <= "0000001111101101"; -- 0.0307
			when "0000011" => output1 <= "0000010101111110"; -- 0.0430
			when "0000100" => output1 <= "0000011100010000"; -- 0.0552
			when "0000101" => output1 <= "0000100010100001"; -- 0.0675
			when "0000110" => output1 <= "0000101000110010"; -- 0.0798
			when "0000111" => output1 <= "0000101111000011"; -- 0.0920
			when "0001000" => output1 <= "0000110101010011"; -- 0.1043
			when "0001001" => output1 <= "0000111011100011"; -- 0.1166
			when "0001010" => output1 <= "0001000001110010"; -- 0.1289
			when "0001011" => output1 <= "0001001000000000"; -- 0.1411
			when "0001100" => output1 <= "0001001110001110"; -- 0.1534
			when "0001101" => output1 <= "0001010100011011"; -- 0.1657
			when "0001110" => output1 <= "0001011010100111"; -- 0.1779
			when "0001111" => output1 <= "0001100000110011"; -- 0.1902
			when "0010000" => output1 <= "0001100110111101"; -- 0.2025
			when "0010001" => output1 <= "0001101101000110"; -- 0.2148
			when "0010010" => output1 <= "0001110011001111"; -- 0.2270
			when "0010011" => output1 <= "0001111001010110"; -- 0.2393
			when "0010100" => output1 <= "0001111111011100"; -- 0.2516
			when "0010101" => output1 <= "0010000101100001"; -- 0.2638
			when "0010110" => output1 <= "0010001011100100"; -- 0.2761
			when "0010111" => output1 <= "0010010001100111"; -- 0.2884
			when "0011000" => output1 <= "0010010111100111"; -- 0.3007
			when "0011001" => output1 <= "0010011101100111"; -- 0.3129
			when "0011010" => output1 <= "0010100011100101"; -- 0.3252
			when "0011011" => output1 <= "0010101001100001"; -- 0.3375
			when "0011100" => output1 <= "0010101111011011"; -- 0.3497
			when "0011101" => output1 <= "0010110101010100"; -- 0.3620
			when "0011110" => output1 <= "0010111011001100"; -- 0.3743
			when "0011111" => output1 <= "0011000001000001"; -- 0.3866
			when "0100000" => output1 <= "0011000110110100"; -- 0.3988
			when "0100001" => output1 <= "0011001100100110"; -- 0.4111
			when "0100010" => output1 <= "0011010010010110"; -- 0.4234
			when "0100011" => output1 <= "0011011000000011"; -- 0.4357
			when "0100100" => output1 <= "0011011101101111"; -- 0.4479
			when "0100101" => output1 <= "0011100011011000"; -- 0.4602
			when "0100110" => output1 <= "0011101000111111"; -- 0.4725
			when "0100111" => output1 <= "0011101110100100"; -- 0.4847
			when "0101000" => output1 <= "0011110100000111"; -- 0.4970
			when "0101001" => output1 <= "0011111001100111"; -- 0.5093
			when "0101010" => output1 <= "0011111111000101"; -- 0.5216
			when "0101011" => output1 <= "0100000100100000"; -- 0.5338
			when "0101100" => output1 <= "0100001001111001"; -- 0.5461
			when "0101101" => output1 <= "0100001111010000"; -- 0.5584
			when "0101110" => output1 <= "0100010100100011"; -- 0.5706
			when "0101111" => output1 <= "0100011001110100"; -- 0.5829
			when "0110000" => output1 <= "0100011111000011"; -- 0.5952
			when "0110001" => output1 <= "0100100100001110"; -- 0.6075
			when "0110010" => output1 <= "0100101001010111"; -- 0.6197
			when "0110011" => output1 <= "0100101110011101"; -- 0.6320
			when "0110100" => output1 <= "0100110011100000"; -- 0.6443
			when "0110101" => output1 <= "0100111000100000"; -- 0.6565
			when "0110110" => output1 <= "0100111101011101"; -- 0.6688
			when "0110111" => output1 <= "0101000010010111"; -- 0.6811
			when "0111000" => output1 <= "0101000111001110"; -- 0.6934
			when "0111001" => output1 <= "0101001100000001"; -- 0.7056
			when "0111010" => output1 <= "0101010000110010"; -- 0.7179
			when "0111011" => output1 <= "0101010101011111"; -- 0.7302
			when "0111100" => output1 <= "0101011010001001"; -- 0.7424
			when "0111101" => output1 <= "0101011110110000"; -- 0.7547
			when "0111110" => output1 <= "0101100011010011"; -- 0.7670
			when "0111111" => output1 <= "0101100111110011"; -- 0.7793
			when "1000000" => output1 <= "0101101100001111"; -- 0.7915
			when "1000001" => output1 <= "0101110000101000"; -- 0.8038
			when "1000010" => output1 <= "0101110100111101"; -- 0.8161
			when "1000011" => output1 <= "0101111001001111"; -- 0.8283
			when "1000100" => output1 <= "0101111101011101"; -- 0.8406
			when "1000101" => output1 <= "0110000001100111"; -- 0.8529
			when "1000110" => output1 <= "0110000101101110"; -- 0.8652
			when "1000111" => output1 <= "0110001001110001"; -- 0.8774
			when "1001000" => output1 <= "0110001101110000"; -- 0.8897
			when "1001001" => output1 <= "0110010001101011"; -- 0.9020
			when "1001010" => output1 <= "0110010101100010"; -- 0.9143
			when "1001011" => output1 <= "0110011001010110"; -- 0.9265
			when "1001100" => output1 <= "0110011101000101"; -- 0.9388
			when "1001101" => output1 <= "0110100000110001"; -- 0.9511
			when "1001110" => output1 <= "0110100100011001"; -- 0.9633
			when "1001111" => output1 <= "0110100111111100"; -- 0.9756
			when "1010000" => output1 <= "0110101011011011"; -- 0.9879
			when "1010001" => output1 <= "0110101110110111"; -- 1.0002
			when "1010010" => output1 <= "0110110010001110"; -- 1.0124
			when "1010011" => output1 <= "0110110101100001"; -- 1.0247
			when "1010100" => output1 <= "0110111000110000"; -- 1.0370
			when "1010101" => output1 <= "0110111011111010"; -- 1.0492
			when "1010110" => output1 <= "0110111111000000"; -- 1.0615
			when "1010111" => output1 <= "0111000010000010"; -- 1.0738
			when "1011000" => output1 <= "0111000101000000"; -- 1.0861
			when "1011001" => output1 <= "0111000111111001"; -- 1.0983
			when "1011010" => output1 <= "0111001010101110"; -- 1.1106
			when "1011011" => output1 <= "0111001101011110"; -- 1.1229
			when "1011100" => output1 <= "0111010000001010"; -- 1.1351
			when "1011101" => output1 <= "0111010010110001"; -- 1.1474
			when "1011110" => output1 <= "0111010101010100"; -- 1.1597
			when "1011111" => output1 <= "0111010111110011"; -- 1.1720
			when "1100000" => output1 <= "0111011010001101"; -- 1.1842
			when "1100001" => output1 <= "0111011100100010"; -- 1.1965
			when "1100010" => output1 <= "0111011110110011"; -- 1.2088
			when "1100011" => output1 <= "0111100000111111"; -- 1.2210
			when "1100100" => output1 <= "0111100011000110"; -- 1.2333
			when "1100101" => output1 <= "0111100101001001"; -- 1.2456
			when "1100110" => output1 <= "0111100111000111"; -- 1.2579
			when "1100111" => output1 <= "0111101001000001"; -- 1.2701
			when "1101000" => output1 <= "0111101010110101"; -- 1.2824
			when "1101001" => output1 <= "0111101100100101"; -- 1.2947
			when "1101010" => output1 <= "0111101110010001"; -- 1.3070
			when "1101011" => output1 <= "0111101111110111"; -- 1.3192
			when "1101100" => output1 <= "0111110001011001"; -- 1.3315
			when "1101101" => output1 <= "0111110010110110"; -- 1.3438
			when "1101110" => output1 <= "0111110100001110"; -- 1.3560
			when "1101111" => output1 <= "0111110101100001"; -- 1.3683
			when "1110000" => output1 <= "0111110110110000"; -- 1.3806
			when "1110001" => output1 <= "0111110111111001"; -- 1.3929
			when "1110010" => output1 <= "0111111000111110"; -- 1.4051
			when "1110011" => output1 <= "0111111001111110"; -- 1.4174
			when "1110100" => output1 <= "0111111010111001"; -- 1.4297
			when "1110101" => output1 <= "0111111011101111"; -- 1.4419
			when "1110110" => output1 <= "0111111100100000"; -- 1.4542
			when "1110111" => output1 <= "0111111101001100"; -- 1.4665
			when "1111000" => output1 <= "0111111101110100"; -- 1.4788
			when "1111001" => output1 <= "0111111110010110"; -- 1.4910
			when "1111010" => output1 <= "0111111110110100"; -- 1.5033
			when "1111011" => output1 <= "0111111111001101"; -- 1.5156
			when "1111100" => output1 <= "0111111111100000"; -- 1.5278
			when "1111101" => output1 <= "0111111111101111"; -- 1.5401
			when "1111110" => output1 <= "0111111111111001"; -- 1.5524
			when "1111111" => output1 <= "0111111111111110"; -- 1.5647
      			when others => output1 <= (others => '0');
		end case;		
	end process;
end Behavioral;

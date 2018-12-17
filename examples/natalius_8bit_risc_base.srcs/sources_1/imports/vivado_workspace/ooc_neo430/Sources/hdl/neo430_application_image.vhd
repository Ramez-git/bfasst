-- NEO430 Processor, by Stephan Nolting
-- Auto-generated memory init file (for APPLICATION)

library ieee;
use ieee.std_logic_1164.all;

package neo430_application_image is

  type application_init_image_t is array (0 to (2**16)-1) of std_ulogic_vector(15 downto 0);
  constant application_init_image : application_init_image_t := (
    000000 => x"4303",
    000001 => x"4218",
    000002 => x"ffe8",
    000003 => x"4211",
    000004 => x"ffea",
    000005 => x"4302",
    000006 => x"5801",
    000007 => x"40b2",
    000008 => x"4700",
    000009 => x"ffd0",
    000010 => x"4382",
    000011 => x"ff9e",
    000012 => x"4382",
    000013 => x"ffa6",
    000014 => x"4382",
    000015 => x"ffb4",
    000016 => x"4382",
    000017 => x"ffb2",
    000018 => x"4382",
    000019 => x"ffc4",
    000020 => x"4382",
    000021 => x"fff8",
    000022 => x"4382",
    000023 => x"fffa",
    000024 => x"4382",
    000025 => x"fffc",
    000026 => x"4382",
    000027 => x"fffe",
    000028 => x"9801",
    000029 => x"2404",
    000030 => x"4388",
    000031 => x"0000",
    000032 => x"5328",
    000033 => x"3ffa",
    000034 => x"4035",
    000035 => x"0246",
    000036 => x"4036",
    000037 => x"0246",
    000038 => x"4037",
    000039 => x"8000",
    000040 => x"9506",
    000041 => x"2404",
    000042 => x"45b7",
    000043 => x"0000",
    000044 => x"5327",
    000045 => x"3ffa",
    000046 => x"4032",
    000047 => x"4000",
    000048 => x"430c",
    000049 => x"12b0",
    000050 => x"00a6",
    000051 => x"40b2",
    000052 => x"4700",
    000053 => x"ffd0",
    000054 => x"4302",
    000055 => x"4032",
    000056 => x"0010",
    000057 => x"4303",
    000058 => x"403e",
    000059 => x"ffa6",
    000060 => x"403f",
    000061 => x"ffa2",
    000062 => x"4c6d",
    000063 => x"930d",
    000064 => x"2001",
    000065 => x"4130",
    000066 => x"903d",
    000067 => x"000a",
    000068 => x"2006",
    000069 => x"b2be",
    000070 => x"0000",
    000071 => x"23fd",
    000072 => x"40b2",
    000073 => x"000d",
    000074 => x"ffa2",
    000075 => x"b2be",
    000076 => x"0000",
    000077 => x"23fd",
    000078 => x"4d8f",
    000079 => x"0000",
    000080 => x"531c",
    000081 => x"4030",
    000082 => x"007c",
    000083 => x"120a",
    000084 => x"421e",
    000085 => x"ffec",
    000086 => x"421f",
    000087 => x"ffee",
    000088 => x"434c",
    000089 => x"4f0a",
    000090 => x"930f",
    000091 => x"2033",
    000092 => x"403d",
    000093 => x"95ff",
    000094 => x"9e0d",
    000095 => x"282f",
    000096 => x"407d",
    000097 => x"00ff",
    000098 => x"9c0d",
    000099 => x"2831",
    000100 => x"4a0d",
    000101 => x"5a0d",
    000102 => x"5d0d",
    000103 => x"5d0d",
    000104 => x"5d0d",
    000105 => x"5d0d",
    000106 => x"5d0d",
    000107 => x"5d0d",
    000108 => x"5d0d",
    000109 => x"dc0d",
    000110 => x"4d82",
    000111 => x"ffa4",
    000112 => x"4392",
    000113 => x"ffa6",
    000114 => x"403a",
    000115 => x"0074",
    000116 => x"403c",
    000117 => x"0208",
    000118 => x"128a",
    000119 => x"b2b2",
    000120 => x"ffe2",
    000121 => x"242a",
    000122 => x"4382",
    000123 => x"ffb2",
    000124 => x"434c",
    000125 => x"403f",
    000126 => x"ffb2",
    000127 => x"4c4d",
    000128 => x"4d8f",
    000129 => x"0000",
    000130 => x"407d",
    000131 => x"000b",
    000132 => x"531c",
    000133 => x"533d",
    000134 => x"930d",
    000135 => x"27f7",
    000136 => x"433e",
    000137 => x"4303",
    000138 => x"533e",
    000139 => x"930e",
    000140 => x"23fc",
    000141 => x"4030",
    000142 => x"010a",
    000143 => x"503e",
    000144 => x"6a00",
    000145 => x"633f",
    000146 => x"531c",
    000147 => x"4030",
    000148 => x"00b2",
    000149 => x"936a",
    000150 => x"2402",
    000151 => x"926a",
    000152 => x"2007",
    000153 => x"12b0",
    000154 => x"0184",
    000155 => x"535a",
    000156 => x"f03a",
    000157 => x"00ff",
    000158 => x"4030",
    000159 => x"00c0",
    000160 => x"12b0",
    000161 => x"018c",
    000162 => x"4030",
    000163 => x"0136",
    000164 => x"403c",
    000165 => x"0224",
    000166 => x"128a",
    000167 => x"435c",
    000168 => x"413a",
    000169 => x"4130",
    000170 => x"c312",
    000171 => x"100c",
    000172 => x"c312",
    000173 => x"100c",
    000174 => x"c312",
    000175 => x"100c",
    000176 => x"c312",
    000177 => x"100c",
    000178 => x"c312",
    000179 => x"100c",
    000180 => x"c312",
    000181 => x"100c",
    000182 => x"c312",
    000183 => x"100c",
    000184 => x"c312",
    000185 => x"100c",
    000186 => x"c312",
    000187 => x"100c",
    000188 => x"c312",
    000189 => x"100c",
    000190 => x"c312",
    000191 => x"100c",
    000192 => x"c312",
    000193 => x"100c",
    000194 => x"c312",
    000195 => x"100c",
    000196 => x"c312",
    000197 => x"100c",
    000198 => x"c312",
    000199 => x"100c",
    000200 => x"4130",
    000201 => x"533d",
    000202 => x"c312",
    000203 => x"100c",
    000204 => x"930d",
    000205 => x"23fb",
    000206 => x"4130",
    000207 => x"c312",
    000208 => x"100d",
    000209 => x"100c",
    000210 => x"c312",
    000211 => x"100d",
    000212 => x"100c",
    000213 => x"c312",
    000214 => x"100d",
    000215 => x"100c",
    000216 => x"c312",
    000217 => x"100d",
    000218 => x"100c",
    000219 => x"c312",
    000220 => x"100d",
    000221 => x"100c",
    000222 => x"c312",
    000223 => x"100d",
    000224 => x"100c",
    000225 => x"c312",
    000226 => x"100d",
    000227 => x"100c",
    000228 => x"c312",
    000229 => x"100d",
    000230 => x"100c",
    000231 => x"c312",
    000232 => x"100d",
    000233 => x"100c",
    000234 => x"c312",
    000235 => x"100d",
    000236 => x"100c",
    000237 => x"c312",
    000238 => x"100d",
    000239 => x"100c",
    000240 => x"c312",
    000241 => x"100d",
    000242 => x"100c",
    000243 => x"c312",
    000244 => x"100d",
    000245 => x"100c",
    000246 => x"c312",
    000247 => x"100d",
    000248 => x"100c",
    000249 => x"c312",
    000250 => x"100d",
    000251 => x"100c",
    000252 => x"4130",
    000253 => x"533e",
    000254 => x"c312",
    000255 => x"100d",
    000256 => x"100c",
    000257 => x"930e",
    000258 => x"23fa",
    000259 => x"4130",
    000260 => x"420a",
    000261 => x"696c",
    000262 => x"6b6e",
    000263 => x"6e69",
    000264 => x"2067",
    000265 => x"454c",
    000266 => x"2044",
    000267 => x"6564",
    000268 => x"6f6d",
    000269 => x"7020",
    000270 => x"6f72",
    000271 => x"7267",
    000272 => x"6d61",
    000273 => x"000a",
    000274 => x"7245",
    000275 => x"6f72",
    000276 => x"2172",
    000277 => x"4e20",
    000278 => x"206f",
    000279 => x"5047",
    000280 => x"4f49",
    000281 => x"7520",
    000282 => x"696e",
    000283 => x"2074",
    000284 => x"7973",
    000285 => x"746e",
    000286 => x"6568",
    000287 => x"6973",
    000288 => x"657a",
    000289 => x"2164",
    000290 => x"0000",
    others => x"0000" -- nop
  );

end neo430_application_image;

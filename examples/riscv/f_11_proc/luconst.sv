/*************************************************************************************************************
*
*  Copyright 2021 BYU Configurable Computing Lab
*
*  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
*  associated documentation files (the "Software"), to deal in the Software without restriction, including 
*  without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
*  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the 
*  following conditions:
*
*  The above copyright notice and this permission notice shall be included in all copies or substantial 
*  portions of the Software.
*
*  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT 
*  LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO 
*  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
*  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR 
*  THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*
**************************************************************************************************************/

/*************************************************************************************************************
*
*  Description: Constants for arithmetic logic unit
*
**************************************************************************************************************/

`ifndef LUCONST
`define LUCONST

localparam[3:0] AND = 4'b0000;
localparam[3:0] OR = 4'b0001;
localparam[3:0] ADD = 4'b0010;
localparam[3:0] SUB = 4'b0011;
localparam[3:0] LESS_THAN = 4'b0111;
localparam[3:0] SRL = 4'b1000;
localparam[3:0] SLL = 4'b1001;
localparam[3:0] SRA = 4'b1010;
localparam[3:0] XOR = 4'b1101;


`endif 

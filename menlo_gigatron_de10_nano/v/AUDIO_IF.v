
//
// Menlo:
// 08/31/2018
//
// Added comments to clarify it. Make it a template for a general audio module.
//

// ============================================================================
// Copyright (c) 2012 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// ============================================================================
//           
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//
//
//
//                     web: http://www.terasic.com/
//                     email: support@terasic.com
//
// ============================================================================

/*

Function: 
	ADV7513 Video and Audio Control 
	
I2C Configuration Requirements:
	Master Mode
	I2S, 16-bits
	
Clock:
	input Clock 1.536MHz (48K*Data_Width*Channel_Num)
	
        Menlo: The above calculation is for (2) channels at 16 bit each
        and 48k clock rate.

Revision:
	1.0, 10/06/2014, Init by Nick
	
Compatibility:
	Quartus 14.0.2

*/




module AUDIO_IF(
	//
	reset_n,
	sclk,
	lrclk,
	i2s,
	clk   // pll_1536khz
);

/*****************************************************************************
 *                           Constant Declarations                           *
 *****************************************************************************/


/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/

//
output       sclk;	
output       lrclk;
input        reset_n;
output [3:0] i2s;
input        clk;

parameter DATA_WIDTH = 16;

// Menlo: Size of audio sample ROM
parameter SIN_SAMPLE_DATA = 48;

/*****************************************************************************
 *                 Internal wires and registers Declarations                 *
 *****************************************************************************/

reg        lrclk;
reg [5:0]  sclk_Count;
reg [5:0]  Simple_count;
reg [15:0] Data_Bit;
reg [6:0]  Data_Count;
reg [5:0]  SIN_Cont;
reg [3:0]  i2s;

/*****************************************************************************
 *                             Sequential logic                              *
 *****************************************************************************/

// Menlo: Pass through the audio clock
assign sclk = clk;

//
// Menlo: Generate lrclk as 1/16th of sclk
//
always@(negedge  sclk or negedge reset_n)
begin
	if(!reset_n)
	begin
	  lrclk<=0;
	  sclk_Count<=0;
	end
	
	else if(sclk_Count>=DATA_WIDTH-1)
	begin
	  sclk_Count <= 0;
	  lrclk <= ~lrclk;
	end
	else 
     sclk_Count <= sclk_Count + 1;
end
 
//
// Menlo: This counts through the bits in a 16 bit audio sample.
// 
// It supports the always@ process in implementing a serializer.
//
always@(negedge sclk or negedge reset_n)
begin
  if(!reset_n)
  begin
    Data_Count <= 0;
  end
  else
  begin
    if(Data_Count >= DATA_WIDTH-1)
	 begin
      Data_Count <= 0;
    end
	 else 
	 Data_Count <= Data_Count +1;
  end
end

//
// Menlo: Takes 4 bits at the inverse of the current DATA_COUNT
//
//        Applies the same value to all four channels.
//
always@(negedge sclk or negedge reset_n)
begin
  if(!reset_n)
  begin
    i2s <= 0;
  end
  else
  begin
    i2s[0] <= Data_Bit[~Data_Count];
    i2s[1] <= Data_Bit[~Data_Count];
    i2s[2] <= Data_Bit[~Data_Count];
    i2s[3] <= Data_Bit[~Data_Count];
  end
end

//
// Menlo: This counter sequences through the sampled audio waveform
// implemented in the case statement based ROM. In this case its a manually
// encoded sine wave.
//
// lrclk is the 1/16th clock, as the 16 bit serializer operates at sclk, so
// 16 bit samples are only needed once per 16 sclk's.  
//
always@(negedge lrclk or negedge reset_n)
begin
	if(!reset_n)
	  SIN_Cont	<=	0;
	else
	begin
          if(SIN_Cont < SIN_SAMPLE_DATA-1 )
	    SIN_Cont	<=	SIN_Cont+1;
	  else
	    SIN_Cont	<=	0;
	end
end

/*****************************************************************************
 *                            Combinational logic                            *
 *****************************************************************************/

//
// Menlo: This basically describes a ROM
//
// The sensitivity list is SIN_Cont which can be seen as an
// address and when ever any bit changes the table is evaluated.
//
// Each case entry is a 16 bit memory location since Data_Bit is 16 bit.
//
// Note that Data_Bit is a register, so its stable after the change
// in input address settles.
//
// The values here are a hand coded, mathmatically derived sine wave.
//
always@(SIN_Cont)
begin
  case(SIN_Cont)
    0  :   Data_Bit      <=      0       ;
    1  :   Data_Bit      <=      4276    ;
    2  :   Data_Bit      <=      8480    ;
    3  :   Data_Bit      <=      12539   ;
    4  :   Data_Bit      <=      16383   ;
    5  :   Data_Bit      <=      19947   ;
    6  :   Data_Bit      <=      23169   ;
    7  :   Data_Bit      <=      25995   ;
    8  :   Data_Bit      <=      28377   ;
    9  :   Data_Bit      <=      30272   ;
    10  :  Data_Bit      <=      31650   ;
    11  :  Data_Bit      <=      32486   ;
    12  :  Data_Bit      <=      32767   ;
    13  :  Data_Bit      <=      32486   ;
    14  :  Data_Bit      <=      31650   ;
    15  :  Data_Bit      <=      30272   ;
    16  :  Data_Bit      <=      28377   ;
    17  :  Data_Bit      <=      25995   ;
    18  :  Data_Bit      <=      23169   ;
    19  :  Data_Bit      <=      19947   ;
    20  :  Data_Bit      <=      16383   ;
    21  :  Data_Bit      <=      12539   ;
    22  :  Data_Bit      <=      8480    ;
    23  :  Data_Bit      <=      4276    ;
    24  :  Data_Bit      <=      0       ;
    25  :  Data_Bit      <=      61259   ;
    26  :  Data_Bit      <=      57056   ;
    27  :  Data_Bit      <=      52997   ;
    28  :  Data_Bit      <=      49153   ;
    29  :  Data_Bit      <=      45589   ;
    30  :  Data_Bit      <=      42366   ;
    31  :  Data_Bit      <=      39540   ;
    32  :  Data_Bit      <=      37159   ;
    33  :  Data_Bit      <=      35263   ;
    34  :  Data_Bit      <=      33885   ;
    35  :  Data_Bit      <=      33049   ;
    36  :  Data_Bit      <=      32768   ;
    37  :  Data_Bit      <=      33049   ;
    38  :  Data_Bit      <=      33885   ;
    39  :  Data_Bit      <=      35263   ;
    40  :  Data_Bit      <=      37159   ;
    41  :  Data_Bit      <=      39540   ;
    42  :  Data_Bit      <=      42366   ;
    43  :  Data_Bit      <=      45589   ;
    44  :  Data_Bit      <=      49152   ;
    45  :  Data_Bit      <=      52997   ;
    46  :  Data_Bit      <=      57056   ;
    47  :  Data_Bit      <=      61259   ;
  default	:
           Data_Bit	<=	 0;
	endcase

end // always@ SIN_Cont

endmodule // AUDIO_IF

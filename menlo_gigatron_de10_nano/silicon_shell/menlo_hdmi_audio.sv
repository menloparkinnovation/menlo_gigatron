
//
// Menlo:
// 08/31/2018
//
// Created from Terasic DE10-Nano example AUDIO_IF.v
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

module menlo_hdmi_audio (
	reset_n,
	sclk,  // Output clock to HDMI
	lrclk,
	i2s,   // output 4 serial channels of HDMI I2S audio
	clk,   // pll_1536khz HDMI I2S serialization clock 1.536Mhz
        audio_in,
        audio_test // true if audio test is asserted
);

/*****************************************************************************
 *                           Constant Declarations                           *
 *****************************************************************************/


/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/

//
output       sclk;	
output reg   lrclk;
input        reset_n;
output reg [3:0] i2s;
input        clk;
input [15:0] audio_in;
input        audio_test;

parameter DATA_WIDTH = 16;

// Menlo: Size of audio sample ROM
parameter SIN_SAMPLE_DATA = 48;

/*****************************************************************************
 *                 Internal wires and registers Declarations                 *
 *****************************************************************************/

reg [5:0]  sclk_Count;
reg [5:0]  Simple_count;

reg [15:0] Output_Data_Bit; // 16 bit audio sample to serialize out

/*****************************************************************************
 *                             Sequential logic                              *
 *****************************************************************************/

// Menlo: Pass through the I2S serialization clock
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
	
	else if(sclk_Count >= DATA_WIDTH-1)
	begin
	  sclk_Count <= 0;
	  lrclk <= ~lrclk;
	end
	else 
     sclk_Count <= sclk_Count + 6'd1;
end
 
//
// Menlo: This counts through the bits in a 16 bit audio sample.
// 
// It supports the always@ process in implementing a serializer.
//
reg [6:0]  Data_Count;

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
	 Data_Count <= Data_Count + 7'd1;
  end
end

//
// I2S audio serializer.
//
// This sends the serialized data MSB first.
//
// Applies the same value to all four I2S channels.
//
always@(negedge sclk or negedge reset_n)
begin
  if(!reset_n)
  begin
    i2s <= 0;
  end
  else
  begin
    i2s[0] <= Output_Data_Bit[~Data_Count];
    i2s[1] <= Output_Data_Bit[~Data_Count];
    i2s[2] <= Output_Data_Bit[~Data_Count];
    i2s[3] <= Output_Data_Bit[~Data_Count];
  end
end

//
// This existing example code produces a built in sine wave test signal.
//

//
// Menlo: This counter sequences through the sampled audio waveform
// implemented in the case statement based ROM. In this case its a manually
// encoded sine wave.
//
// lrclk is the 1/16th clock, as the 16 bit serializer operates at sclk, so
// 16 bit samples are only needed once per 16 sclk's.  
//
reg [5:0]  SIN_Count;

always@(negedge lrclk or negedge reset_n)
begin
	if(!reset_n) begin
	  SIN_Count	<=	0;
        end
	else
	begin
          if(SIN_Count < SIN_SAMPLE_DATA-1 )
	    SIN_Count <= SIN_Count + 6'd1;
	  else
	    SIN_Count <= 0;
	end
end

//
// Menlo: This basically describes a ROM
//
// The sensitivity list is SIN_Count which can be seen as an
// address and when ever any bit changes the table is evaluated.
//
// Each case entry is a 16 bit memory location since Data_Bit is 16 bit.
//
// Note that Data_Bit is a register, so its stable after the change
// in input address settles.
//
// The values here are a hand coded, mathmatically derived sine wave.
//
reg [15:0] Test_Sample_Data_Bit;

always@(SIN_Count)
begin
  case(SIN_Count)
    0  :   Test_Sample_Data_Bit      <=      0       ;
    1  :   Test_Sample_Data_Bit      <=      4276    ;
    2  :   Test_Sample_Data_Bit      <=      8480    ;
    3  :   Test_Sample_Data_Bit      <=      12539   ;
    4  :   Test_Sample_Data_Bit      <=      16383   ;
    5  :   Test_Sample_Data_Bit      <=      19947   ;
    6  :   Test_Sample_Data_Bit      <=      23169   ;
    7  :   Test_Sample_Data_Bit      <=      25995   ;
    8  :   Test_Sample_Data_Bit      <=      28377   ;
    9  :   Test_Sample_Data_Bit      <=      30272   ;
    10  :  Test_Sample_Data_Bit      <=      31650   ;
    11  :  Test_Sample_Data_Bit      <=      32486   ;
    12  :  Test_Sample_Data_Bit      <=      32767   ;
    13  :  Test_Sample_Data_Bit      <=      32486   ;
    14  :  Test_Sample_Data_Bit      <=      31650   ;
    15  :  Test_Sample_Data_Bit      <=      30272   ;
    16  :  Test_Sample_Data_Bit      <=      28377   ;
    17  :  Test_Sample_Data_Bit      <=      25995   ;
    18  :  Test_Sample_Data_Bit      <=      23169   ;
    19  :  Test_Sample_Data_Bit      <=      19947   ;
    20  :  Test_Sample_Data_Bit      <=      16383   ;
    21  :  Test_Sample_Data_Bit      <=      12539   ;
    22  :  Test_Sample_Data_Bit      <=      8480    ;
    23  :  Test_Sample_Data_Bit      <=      4276    ;
    24  :  Test_Sample_Data_Bit      <=      0       ;
    25  :  Test_Sample_Data_Bit      <=      61259   ;
    26  :  Test_Sample_Data_Bit      <=      57056   ;
    27  :  Test_Sample_Data_Bit      <=      52997   ;
    28  :  Test_Sample_Data_Bit      <=      49153   ;
    29  :  Test_Sample_Data_Bit      <=      45589   ;
    30  :  Test_Sample_Data_Bit      <=      42366   ;
    31  :  Test_Sample_Data_Bit      <=      39540   ;
    32  :  Test_Sample_Data_Bit      <=      37159   ;
    33  :  Test_Sample_Data_Bit      <=      35263   ;
    34  :  Test_Sample_Data_Bit      <=      33885   ;
    35  :  Test_Sample_Data_Bit      <=      33049   ;
    36  :  Test_Sample_Data_Bit      <=      32768   ;
    37  :  Test_Sample_Data_Bit      <=      33049   ;
    38  :  Test_Sample_Data_Bit      <=      33885   ;
    39  :  Test_Sample_Data_Bit      <=      35263   ;
    40  :  Test_Sample_Data_Bit      <=      37159   ;
    41  :  Test_Sample_Data_Bit      <=      39540   ;
    42  :  Test_Sample_Data_Bit      <=      42366   ;
    43  :  Test_Sample_Data_Bit      <=      45589   ;
    44  :  Test_Sample_Data_Bit      <=      49152   ;
    45  :  Test_Sample_Data_Bit      <=      52997   ;
    46  :  Test_Sample_Data_Bit      <=      57056   ;
    47  :  Test_Sample_Data_Bit      <=      61259   ;
  default	:
           Test_Sample_Data_Bit	<=	 0;
	endcase

end // always@ SIN_Count

  //
  // Menlo: Use the audio 16 bit audio input
  //
  always@(audio_in, audio_test, Test_Sample_Data_Bit) begin
    if (audio_test == 1'b0) begin
      // Use the DAC input audio data
      Output_Data_Bit <= audio_in;
    end
    else begin
      // Use the built in test sample
      Output_Data_Bit <= Test_Sample_Data_Bit;
    end
  end

endmodule // menlo_hdmi_audio


//
// Menlo: Modified to have a dual port frame buffer instead of image ROM.
//
// 08/24/2018
//
// This file came from the DE10-Nano examples CD Copyright Terasic. It was modified
// for this project to implement a VGA framebuffer.
//

// Set this to implement dual port RAM based frambuffer vs. static image ROM.
`define DUAL_PORT_FRAME_BUFFER 1

// Set this to use a built in true color 8 bit palette rather than the lookup ROM.
`define EIGHT_BIT_TRUE_COLOR_PALETTE 1

module vga_controller(iRST_n,
                      iVGA_CLK,   // 25Mhz
                      fpga_clock, // 50Mhz
                      oBLANK_n,
                      oHS,
                      oVS,
                      b_data,
                      g_data,
                      r_data,

                      // From Gigatron VGA controller output
		      input_framebuffer_write_clock,
		      input_framebuffer_write_signal,
		      input_framebuffer_write_address,
		      input_framebuffer_write_data
                      );
input iRST_n;
input iVGA_CLK; // 25Mhz from DE10_Nano_Default.v
input fpga_clock; // 50Mhz ""
output reg oBLANK_n;
output reg oHS;
output reg oVS;
output [7:0] b_data;
output [7:0] g_data;  
output [7:0] r_data;                        

//
// Dual port framebuffer support.
//
input        input_framebuffer_write_clock;
input        input_framebuffer_write_signal;
input [18:0] input_framebuffer_write_address;
input  [7:0] input_framebuffer_write_data;

///////// ////                     
// 640 * 480 == 307,200 == 0x4B000
//                      == 0 - 0x4AFFF
// 19 bit address [18:0]
//
parameter VIDEO_W	= 640; // 10 bits [9:0]
parameter VIDEO_H	= 480; // 9 bits  [8:0]

reg [23:0] bgr_data;
wire VGA_CLK_n;
wire [7:0] index;
wire [23:0] bgr_data_raw;
wire cBLANK_n, cHS, cVS, rst/*synthesis keep*/;
////

// Positive Reset signal
assign rst = ~iRST_n;

video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
                              .reset(rst),
                              .blank_n(cBLANK_n),
                              .HS(cHS),
                              .VS(cVS)
									);
////
////Address generator
reg [18:0] ADDR/*synthesis noprune*/;  // 19 bits
reg [9:0] H_COUNT/*synthesis noprune*/; // 10 bits
reg [8:0] V_COUNT/*synthesis noprune*/;  // 9 bits
reg cBLANK_n_delay;
wire BLANK_n_valid/*synthesis keep*/;

always@(posedge iVGA_CLK)
  cBLANK_n_delay=cBLANK_n;

assign BLANK_n_valid = (cBLANK_n_delay==1 & cBLANK_n==0) ? 1'b1 : 1'b0;

//
// Generate horizontal pixel counter
//
always@(posedge iVGA_CLK,negedge iRST_n) begin
  if (!iRST_n) begin
     H_COUNT <= 10'd0;
  end
  else if (cHS == 1'b0) begin
     // Horizontal sync is asserted, clear horizontal count
     H_COUNT <= 10'd0;
  end
  else if (cBLANK_n == 1'b1) begin
     // We are not in the blanking interval, count pixels
     H_COUNT <= H_COUNT + 10'h1;
  end
end

//
// Generate vertical line counter
//
always@(posedge iVGA_CLK, negedge iRST_n) begin
  if (!iRST_n) begin
     V_COUNT <= 9'd0;
  end
  else if (cHS==1'b0 && cVS==1'b0) begin
     // horizontal and vertical sync pulses are active, reset vertical counter.
     V_COUNT <= 9'd0;
  end
  else if (BLANK_n_valid == 1 && V_COUNT < VIDEO_H) begin
     // Not in a blanking interval, and have not exceeded vertical line count.
     V_COUNT <= V_COUNT + 9'h1;
  end
end
//////////////////////////

assign VGA_CLK_n = ~iVGA_CLK;

`ifdef DUAL_PORT_FRAME_BUFFER

  //
  // Menlo: the image ROM and palette implementations is replaced by a
  // dual port RAM framebuffer that allows for operation across independent
  // clock domains.
  //
  // The framebuffer implements 8 bit "true color" at 640x480.
  //
  //  The 8 bit true color values indexes the DAC's 8 bit R, G, B entries.
  //
  // The framebuffer RAM may be initialized with an initial image file using
  // the Altera IP configuration tool to set an initialization file.
  //   
  // The palette generator is not used here.
  //
  // Note: The 24 bit output from the palette RAM orders Red [7:0],
  // Green [15:8], Blue [23:16].
  //
  // See the assigns below.
  //
  // Color formats:
  //
  // https://en.wikipedia.org/wiki/8-bit_color
  //
  // https://en.wikipedia.org/wiki/List_of_color_palettes
  //
  // http://www.libertybasicuniversity.com/lbnews/nl100/format.htm
  //
  // An Altera dual port RAM IP block is used to allow use across separate
  // clock domains. A FIFO is not required.
  //

  //
  // dualport RAM signals
  //
  wire        dualport_ram_write_clock;
  wire        dualport_ram_write_signal;
  wire [18:0] dualport_ram_write_address;
  wire [7:0]  dualport_ram_write_data;

  //
  // dualportframebuffer is generated from the Altera IP tool for a dual port RAM.
  //
  dualportframebuffer	vga_framebuffer (
	.data (dualport_ram_write_data), // write input
	.rdaddress (ADDR),               // read by VGA screen refresh logic
	.rdclock (VGA_CLK_n),            // read by VGA screen refresh logic
	.wraddress (dualport_ram_write_address ), // write addres
	.wrclock (dualport_ram_write_clock),      // write clock
	.wren (dualport_ram_write_signal),        // write signal
	.q (index)                       // read by VGA screen refresh logic
	);

  reg        reg_vga_write_framebuffer_clock_delay;

  reg        reg_vga_write_framebuffer_signal;
  reg [7:0]  reg_vga_write_framebuffer_data;
  reg [18:0] reg_vga_write_framebuffer_address;
   
  assign dualport_ram_write_clock = input_framebuffer_write_clock;
  assign dualport_ram_write_signal = reg_vga_write_framebuffer_signal;
  assign dualport_ram_write_address = reg_vga_write_framebuffer_address;
  assign dualport_ram_write_data = reg_vga_write_framebuffer_data;

  always@(posedge input_framebuffer_write_clock) begin

      if (rst) begin
         reg_vga_write_framebuffer_signal <= 1'b0;
         reg_vga_write_framebuffer_data <= 8'd0;
         reg_vga_write_framebuffer_address <= 18'd0;
         reg_vga_write_framebuffer_clock_delay <= 1'b0;
      end
      else begin

         //
         // Not reset
         //

         if (reg_vga_write_framebuffer_clock_delay == 1'b1) begin

             //
	     // A framebuffer RAM write cycle has completed, so
	     // reset its signal state for this clock cycle.
             //

             reg_vga_write_framebuffer_signal <= 1'b0;
             reg_vga_write_framebuffer_clock_delay <= 1'b0;
         end
         else begin

             //
             // Not writing framebuffer RAM
             //

	     if (input_framebuffer_write_signal == 1'b1) begin

                //
                // A request to write the dual port RAM
                //

		reg_vga_write_framebuffer_data <= input_framebuffer_write_data;
		reg_vga_write_framebuffer_address <= input_framebuffer_write_address;

		reg_vga_write_framebuffer_signal <= 1'b1;
		reg_vga_write_framebuffer_clock_delay <= 1'b1;
    	     end

         end // not writing framebuffer

      end // not reset

  end // Dual port ram write process

`else

  img_data	img_data_inst (
	.address ( ADDR ),
	.clock ( VGA_CLK_n ),
	.q ( index )
	);

`endif // DUAL_PORT_FRAMEBUFFER

//
// Menlo:
//
// Implement 8 bit true color without the palette RAM for Gigatron.
//
// The Gigatron VGA decoder will output 8 bit pixels in this format.
//
// https://en.wikipedia.org/wiki/8-bit_color
//
// Bit    7  6  5  4  3  2  1  0
// Data   R  R  R  G  G  G  B  B
//
// This is 3 bits Red [7:5], 3 bits Green [4:2], 2 bits Blue [1:0].
//
// Also called 8-8-4 RGB mode.
//
// https://en.wikipedia.org/wiki/List_of_color_palettes
//
// Since this is a general purpose format its not specific to the Gigatron.
//
// For more complex palletes, implment the img_index ROM module and an initialization
// .mif file for the custom palette.
//
`ifdef EIGHT_BIT_TRUE_COLOR_PALETTE
    vga_8bit_true_color_palette_generator img_index_inst (
	.address ( index ),
	.clock ( iVGA_CLK ),
	.q ( bgr_data_raw)
	);	

`else
//
// Menlo: This implements an 8 bit => 24 bit color palette map initialized
//        from the project file VGA_DATA\index_logo.mif which has 256 24 bit entries.
//
//        This could be set to a common 256 color palette, or an application specific one.
//
    img_index img_index_inst (
	.address ( index ),
	.clock ( iVGA_CLK ),
	.q ( bgr_data_raw)
	);	
`endif

//
// VGA screen refresh logic framebuffer address generator.
//
always@(posedge iVGA_CLK, negedge iRST_n) begin

  if (!iRST_n) begin
    ADDR <= 19'd0;
    bgr_data <= 0;  
  end
  else begin

    //
    // Not Reset
    //

    if ((H_COUNT == 0) && (V_COUNT == 0)) begin
        // Vertical and horizontal sync, reset counter
        ADDR <= 19'd0;
        bgr_data <= 0;  
    end
    else begin

        //
        // Currently in the visible region of the display so lookup and
        // display the output pixels.
        //

        bgr_data <= bgr_data_raw;
        ADDR <= ADDR + 19'h1;
    end

  end // not reset

end // always

//
// Menlo: Mapping of RGB 8 bit values from 24 bit palette generators output.
//
assign b_data = bgr_data[23:16];
assign g_data = bgr_data[15:8];
assign r_data = bgr_data[7:0];

//////Delay the iHD, iVD, iDEN for one clock cycle;
always@(negedge iVGA_CLK) begin
  oHS <= cHS;
  oVS <= cVS;
  oBLANK_n <= cBLANK_n;
end

endmodule // vga_controller
 	
//
// Implement 8 bit true color without the palette RAM.
//
// https://en.wikipedia.org/wiki/8-bit_color
//
// Bit    7  6  5  4  3  2  1  0
// Data   R  R  R  G  G  G  B  B
//
// This is 3 bits Red [7:5], 3 bits Green [4:2], 2 bits Blue [1:0].
//
// Also called 8-8-4 RGB mode.
//
// https://en.wikipedia.org/wiki/List_of_color_palettes
//
// For more complex palettes, implment the img_index ROM module and an initialization
// .mif file for the custom palette.
//
// The interface conforms with the bit pattern from the img_index.v palette generator.
//
// assign b_data = bgr_data[23:16];
// assign g_data = bgr_data[15:8];
// assign r_data = bgr_data[7:0];
//
module vga_8bit_true_color_palette_generator(
	address, // 8 bit pixel value, normally a palette lookup table address
	clock,
	q
        );

    input [7:0] address;
    input  clock;
    output [23:0]  q;

    reg [7:0]   reg_address;

    // two bits for blue
    assign q[23:22] = reg_address[1:0];
    assign q[21:16] = 6'b000000;
   
    // 3 bits for green
    assign q[15:13] = reg_address[4:2];
    assign q[12:8]  = 5'b00000;

    // 3 bits for red
    assign q[7:5] = reg_address[7:5];
    assign q[4:0] = 5'b00000;

    // The input address is registered so the output is steady to the next clock
    always@(posedge clock) begin
        reg_address <= address;
    end

endmodule

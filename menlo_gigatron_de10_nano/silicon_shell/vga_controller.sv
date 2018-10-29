
//
// Menlo: Modified to have a dual port frame buffer instead of image ROM.
//
// 08/24/2018
//
// This file came from the DE10-Nano examples CD Copyright Terasic. It was modified
// for this project to implement a VGA framebuffer.
//

module vga_controller(iRST_n,
                      iVGA_CLK,   // 25Mhz
                      fpga_clock, // 50Mhz
                      oBLANK_n,
                      oHS,
                      oVS,
                      b_data,
                      g_data,
                      r_data,

                      // From Application VGA controller output
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

wire     hsync_n;
wire     vsync_n;
wire     cBLANK_n;
wire     rst;

// Positive Reset signal
assign rst = ~iRST_n;

video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
                              .reset(rst),
                              .blank_n(cBLANK_n),
                              .HS(hsync_n),
                              .VS(vsync_n)
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
  else if (hsync_n == 1'b0) begin
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
  else if (hsync_n == 1'b0 && vsync_n == 1'b0) begin
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

//
// Menlo:
//
// Implement 8 bit true color without the palette RAM.
//
// The Application VGA decoder will output 8 bit pixels in this format.
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
  vga_8bit_true_color_palette_generator img_index_inst (
    .address ( index ),
    .clock ( iVGA_CLK ),
    .q ( bgr_data_raw)
    );	

  //
  // VGA screen refresh logic framebuffer address generator.
  //

  //
  //
  // Note: 480 + back_porch + front_porch must equal 525. (45 for the two).
  parameter VGA_V_FRONT_PORCH = 10'd11;
  parameter VGA_V_BACK_PORCH  = 12'd30;    // Appears to be best.
  // parameter VGA_V_BACK_PORCH  = 12'd28; // Little bit of chop on the top
  //parameter VGA_V_BACK_PORCH  = 12'd30; // almost perfect. Maybe a line left to move up for the bottom.
  //parameter VGA_V_BACK_PORCH  = 12'd34; // not chopped at top. Has 1 Gigatron line left.
  // parameter VGA_V_BACK_PORCH  = 12'd26; // still chopped at top, RAM read to early
  //parameter VGA_V_BACK_PORCH  = 12'd34;

  // Note: 640 + back_porch + front_porch must equal 800. (160 for the two).
  parameter VGA_H_FRONT_PORCH = 10'd16;

  //
  // This value is calculated from:
  // 800 pixels total scan line
  // -96 pixels for hsync_n time.
  // -48 back porch
  // -640 visible pixels
  // -16 front porch
  // ------
  //   0
  //
  parameter VGA_H_BACK_PORCH  = 10'd42;
  //parameter VGA_H_BACK_PORCH  = 10'd43; // Almost perfect.
  //parameter VGA_H_BACK_PORCH  = 10'd48; // Now it has overscan and to much on the right
  //parameter VGA_H_BACK_PORCH  = 10'd38; // still chopped at left, RAM read to early
  //parameter VGA_H_BACK_PORCH  = 10'd48;

  //
  // These values are from video_sync_generator.v
  //
  // parameter VGA_V_FRONT_PORCH = 10'd11;
  // parameter VGA_V_BACK_PORCH  = 12'd34;  // cut off on the top
  // parameter VGA_H_FRONT_PORCH = 10'd16;
  // parameter VGA_H_BACK_PORCH  = 10'd144; // cut off on left
   
  reg        vga_vsync_arm;
  reg        vga_hsync_arm;

  // This bumps by 640 for each horizontal line
  parameter VGA_FRAMEBUFFER_MAX_ADDRESS = 19'h4AFFF; // (640*480) - 1, (307,200) - 1
  reg [18:0] vga_line_address_counter;

  //
  // The maximum visible horizontal and vertical scan line counters
  // ensure we don't overflow the framebuffer RAM.
  //
  parameter VGA_FRAMEBUFFER_MAX_VISIBLE_HORZ_SCAN_LINE = 10'd640;
  reg [9:0]  vga_horizontal_visible_line_index;

  parameter VGA_FRAMEBUFFER_MAX_VISIBLE_VERT_SCAN_LINE = 10'd480;

  //
  // The total number of horizontal and vertical scan lines is larger
  // than the visible regions due to the horizontal and vertical
  // front and back porches, which represent the non-visible regions
  // in the standard VGA timings.
  //

  //
  // This is from 0 - 799 for a horizontal line pixels/vga clocks
  // due to horizontal front and back porches. The visible area
  // is 640 pixels.
  //
  parameter VGA_FRAMEBUFFER_MAX_HORZ_SCAN_LINE = 10'd800;
  reg [9:0]  vga_horizontal_line_index;

  //
  // This is from 0 - 524 for the number of vertical lines
  // due to vertical front and back porches. The visible area
  // is 480 lines.
  //
  parameter VGA_FRAMEBUFFER_MAX_VERT_SCAN_LINE = 10'd525;
  reg [9:0] vga_vertical_line_index;

  //
  // This is run at vga_clock since that is what the monitor draws its pixels
  // at from the real time color signal inputs.
  //
  always@(posedge iVGA_CLK, negedge iRST_n) begin

    if (iRST_n == 1'b0) begin

      ADDR <= 19'd0;
      bgr_data <= 0;

      vga_vsync_arm <= 0;
      vga_hsync_arm <= 0;
      vga_line_address_counter <= 0;
      vga_vertical_line_index <= 0;
      vga_horizontal_line_index <= 10'd0;
      vga_horizontal_visible_line_index <= 10'd0;
    end
    else begin

      //
      // Not Reset
      //

      //
      // Process vsync state machine
      //
      if (vsync_n == 1'b0) begin

	  // vsync is asserted
	  vga_vsync_arm <= 1'b1;
      end
      else begin

	  //
	  // vsync_n is not asserted
	  //
	  if (vga_vsync_arm == 1'b1) begin

	      // A vsync has occured, reset the framebuffer address
	      ADDR <= 19'd0;
	      vga_line_address_counter <= 19'd0;
	      vga_vertical_line_index <= 10'd0;
	      vga_horizontal_line_index <= 10'd0;
	      vga_horizontal_visible_line_index <= 10'd0;

	      vga_vsync_arm <= 1'b0;
	  end

      end // vsync_n state machine

      //
      // Process hsync state machine
      //
      if (hsync_n == 1'b0) begin

	  vga_hsync_arm <= 1'b1;

      end
      else begin

	  //
	  // hsync_n is not asserted
	  //

	  if (vga_hsync_arm == 1'b1) begin

	      vga_hsync_arm <= 1'b0;

	      //
	      // An hsync has occurred.
	      //

	      if (vga_vertical_line_index != VGA_FRAMEBUFFER_MAX_VERT_SCAN_LINE) begin

		// Increment vertical line index
		vga_vertical_line_index <= vga_vertical_line_index + 10'd1;
	      end

	      //
	      // Don't add horizontal lines to framebuffer until beyond
	      // the vertical back porch.
	      //
	      if (vga_vertical_line_index >= VGA_V_BACK_PORCH) begin

		// Set the framebuffer address to the next line address.
		vga_line_address_counter <= vga_line_address_counter + 19'd640;
		vga_horizontal_line_index <= 10'd0;
		vga_horizontal_visible_line_index <= 10'd0;

		ADDR <= vga_line_address_counter;
	      end
	  end
	  else begin

	      //
	      // Main pixel scan logic.
              // The framebuffer contents are output onto the VGA/HDMI
	      // signals to the monitor.
              //

	      //
	      // Don't add horizontal lines to framebuffer address unless in the
	      // visible region.
	      //
	      if (vga_vertical_line_index >= VGA_V_BACK_PORCH) begin

		vga_horizontal_line_index <= vga_horizontal_line_index + 10'd1;

		if (vga_horizontal_line_index >= VGA_H_BACK_PORCH) begin

		  // Ensure we don't overrun the current horizontal scan lines allocated memory
		  if (vga_horizontal_visible_line_index != VGA_FRAMEBUFFER_MAX_VISIBLE_HORZ_SCAN_LINE) begin

		    vga_horizontal_visible_line_index <= vga_horizontal_visible_line_index + 10'd1;

                    bgr_data <= bgr_data_raw;

		    ADDR <= ADDR + 19'd1;
		  end

		end // in visible horizontal region

	      end // in visible vertical region

	  end // not vga_hsync armed

      end // hsync_n state machine

    end // not reset

  end // end always posedge vga_clock

`ifdef not_working_code

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
`endif

//
// Menlo: Mapping of RGB 8 bit values from 24 bit palette generators output.
//
assign b_data = bgr_data[23:16];
assign g_data = bgr_data[15:8];
assign r_data = bgr_data[7:0];

//////Delay the iHD, iVD, iDEN for one clock cycle;
always@(negedge iVGA_CLK) begin
  oHS <= hsync_n;
  oVS <= vsync_n;
  oBLANK_n <= cBLANK_n;
end

endmodule // vga_controller

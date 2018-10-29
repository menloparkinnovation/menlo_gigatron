
//
// See MENLO_COPYRIGHT.TXT for the copyright notice for this file.
//
// Use of this file is not allowed without the copyright notice present
// and re-distributed along with these files.
//

//
// Menlo: Modified to have a dual port frame buffer instead of image ROM.
//
// 10/12/2018
//
// Implement version with overlap sprite for on screen setup UI.
//
// 08/24/2018
//
// This file came from the DE10-Nano examples CD Copyright Terasic. It was modified
// for this project to implement a VGA framebuffer.
//

//
// VGA controller with single sprite support.
//
// The sprite is represented as an additional overlay memory up
// to screen size (typically smaller) which displays over the
// contents in the framebuffer on the monitor.
//
// The sprite must be wholly contained within the visible region
// of the screen, and no portion may be offscreen.
//
// Its size and position is specified as input signals as well
// as its enable/disable state. These are relative to the
// visible region of the screen, in this case 640x480.
//
// The invoking module provides a RAM which holds the sprites
// contents, and this module supplies the address and control
// signals to read this RAM. The sprites contents in the RAM
// are merged in real time during the video display cycle.
//
// The sprite is really just an overlay memory at its basic
// implementation, but allows the invoking module to control
// actual sprite actions such as position, size, enable/disable
// state, and contents such as graphics, text, flashing, transitions,
// panning, etc.
//
// Some improvements that could be done, but not here for this simple
// implementation:
//
// - The sprite RAM indexing logic assumes that the sprite is fully
// contained within the visible area of the screen. This is because
// the sprite x + y hit detection logic advances the sprite ram by 1 for
// each horizontal pixel when hit == true. If the sprite is off
// the screen the address into the sprite ram would not have been calculated
// for the visible portion of the sprite. More complex logic can breakout
// the sprite address generator from the main VGA logic to perform
// the more complex calculations. This can be worked around by the
// invoker by adjusting the size of the sprite when it sees a portion
// of it would be off screen, and scroll any text or images within the
// sprite itself. This is not needed in this simple implemention for its
// Gigatron overlay use.
//
module Vga_Controller_With_Sprite (
                      iRST_n,
                      iVGA_CLK,   // 25Mhz
                      fpga_clock, // 50Mhz
                      oBLANK_n,
                      oHS,
                      oVS,
                      b_data,
                      g_data,
                      r_data,

                      //
                      // These signals allows to internal framebuffer to be updated.
                      //
		      input_framebuffer_write_clock,
		      input_framebuffer_write_signal,
		      input_framebuffer_write_address,
		      input_framebuffer_write_data,

                      // Sprite parameters
                      input_sprite_active,
                      input_sprite_x_position,
                      input_sprite_y_position,
                      input_sprite_x_size,
                      input_sprite_y_size,

                      //
                      // Sprite memory.
		      // These signals are used to read the sprite memory.
                      //
		      output_sprite_read_clock,
		      output_sprite_read_signal,
		      output_sprite_read_address,
		      input_sprite_read_data
                      );


input iRST_n;
input iVGA_CLK; // 25Mhz from DE10_Nano_Default.v
input fpga_clock; // 50Mhz ""
output reg oBLANK_n;
output reg oHS;
output reg oVS;

//
// These signals support the dualport frame buffer write requests.
//
input        input_framebuffer_write_clock;
input        input_framebuffer_write_signal;
input [18:0] input_framebuffer_write_address;
input  [7:0] input_framebuffer_write_data;

//
// Sprite support.
//
input         input_sprite_active;
input [9:0]   input_sprite_x_position;
input [8:0]   input_sprite_y_position;
input [9:0]   input_sprite_x_size;
input [8:0]   input_sprite_y_size;

output        output_sprite_read_clock;
output        output_sprite_read_signal;
output [18:0] output_sprite_read_address;

//
// This is the data output from the sprite RAM.
//
input  [7:0]  input_sprite_read_data;

//
// Dual port RAM read support
//
// Same clock as dualport_ram_read_clock
//
wire    dualport_ram_read_clock;
assign dualport_ram_read_clock = VGA_CLK_n;

assign        output_sprite_read_clock = dualport_ram_read_clock;

// Read is always on.
assign        output_sprite_read_signal = 1'b1;

//
// Output BGR data to HDMI DAC
//
output [7:0] b_data;
output [7:0] g_data;  
output [7:0] r_data;                        

//
// Dual port framebuffer support.
//
// This is the read address input to the dual port framebuffer.
//
reg [18:0] reg_dualport_ram_read_address /*synthesis noprune*/;

//
// This is the data output from the dualport RAM.
//
wire [7:0]   dualport_ram_read_data;

//
// This is the address into the sprite RAM.
//
reg [18:0]    reg_sprite_ram_read_address;

assign        output_sprite_read_address = reg_sprite_ram_read_address;

wire is_in_sprite_region;

//
// The data input to the pallete generator comes from either
// the dualport framebuffer RAM, or the sprite RAM.
//
wire [7:0]    pallete_generator_data_input;

assign pallete_generator_data_input = 
  (input_sprite_active && is_in_sprite_region) ? input_sprite_read_data : dualport_ram_read_data;

//
// This is the raw data output from the palette generator after
// converting the value from the display RAM.
//
// This is not clocked as it represents real time combinatorial
// logic as the RAM's inputs change from the VGA signal generation
// logic.
//
wire [23:0] bgr_data_raw;

//
// This is the clocked palette generator value that holds a stable
// value from the VGA signal generator.
//
reg [23:0] bgr_data;

assign b_data = bgr_data[23:16];
assign g_data = bgr_data[15:8];
assign r_data = bgr_data[7:0];

///////// ////                     
// 640 * 480 == 307,200 == 0x4B000
//                      == 0 - 0x4AFFF
// 19 bit address [18:0]
//
parameter VIDEO_W	= 640; // 10 bits [9:0]
parameter VIDEO_H	= 480; // 9 bits  [8:0]

wire VGA_CLK_n;

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
//
//Address generator
//

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
  // dualport RAM write signals
  //
  wire        dualport_ram_write_clock;
  wire        dualport_ram_write_signal;
  wire [18:0] dualport_ram_write_address;
  wire [7:0]  dualport_ram_write_data;

  //
  // dualportframebuffer is generated from the Altera IP tool for a dual port RAM.
  //
  // Dualport framebuffer RAM
  //
  dualportframebuffer	vga_framebuffer (
	.data (dualport_ram_write_data), // write input
	.rdaddress (reg_dualport_ram_read_address), // read by VGA screen refresh logic
	.rdclock (dualport_ram_read_clock),         // read by VGA screen refresh logic
	.wraddress (dualport_ram_write_address ), // write addres
	.wrclock (dualport_ram_write_clock),      // write clock
	.wren (dualport_ram_write_signal),        // write signal
	.q (dualport_ram_read_data)               // read by VGA screen refresh logic
	);

  reg        reg_vga_write_framebuffer_clock_delay;

  reg        reg_vga_write_framebuffer_signal;
  reg [7:0]  reg_vga_write_framebuffer_data;
  reg [18:0] reg_vga_write_framebuffer_address;
   
  assign dualport_ram_write_clock = input_framebuffer_write_clock;
  assign dualport_ram_write_signal = reg_vga_write_framebuffer_signal;
  assign dualport_ram_write_address = reg_vga_write_framebuffer_address;
  assign dualport_ram_write_data = reg_vga_write_framebuffer_data;

  //
  // Dual port framebuffer write process.
  //
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
// The application VGA decoder will output 8 bit pixels in this format.
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
    .address ( pallete_generator_data_input ),
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
  //parameter VGA_H_BACK_PORCH  = 10'd48; // Now it has overscan and too much on the right
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
  // This combinatorial always process is the hit detector
  // for the sprite region on the screen.
  //
  // It's done separately to simply the nested code in the
  // VGA signal generation always process.
  //
  reg reg_is_in_sprite_vertical_region;
  reg reg_is_in_sprite_horizontal_region;

  //
  // Must be in both the vertical and horizontal region to
  // be in the sprite region.
  //
  assign is_in_sprite_region =
    (reg_is_in_sprite_vertical_region && reg_is_in_sprite_horizontal_region) ? 1'b1 : 1'b0;

  //
  // Vertical sprite region signal.
  //
  always@* begin
    if (iRST_n == 1'b0) begin
      reg_is_in_sprite_vertical_region = 1'b0;
    end
    else begin

      //
      // not reset
      //
      if (((vga_vertical_line_index - VGA_V_BACK_PORCH) >= input_sprite_y_position) &&
	  ((vga_vertical_line_index - VGA_V_BACK_PORCH) < 
           (input_sprite_y_position + input_sprite_y_size))) begin

        //
        // In vertical region
        //
        reg_is_in_sprite_vertical_region = 1'b1;
      end
      else begin
        reg_is_in_sprite_vertical_region = 1'b0;
      end
    end // not reset
  end // end always@* for sprite vertical region

  //
  // Horizontal sprite region signal.
  //
  always@* begin
    if (iRST_n == 1'b0) begin
      reg_is_in_sprite_horizontal_region = 1'b0;
    end
    else begin

      //
      // not reset
      //

      //
      // See if its in the horizontal region
      //
      if (((vga_horizontal_line_index - VGA_H_BACK_PORCH) >= input_sprite_x_position) &&
          ((vga_horizontal_line_index - VGA_H_BACK_PORCH) < 
            (input_sprite_x_position + input_sprite_x_size))) begin

        //
        // In horizontal region
        //
        reg_is_in_sprite_horizontal_region = 1'b1;
      end
      else begin
        reg_is_in_sprite_horizontal_region = 1'b0;
      end
    end // not reset
  end // end always@* for sprite horizontal region

  //
  // Dual port framebuffer read side process.
  //
  // This generates the real time VGA/HDMI signals
  // from the merging of the frame and sprite buffer RAM's.
  //
  // This is run at vga_clock since that is what the monitor draws its pixels
  // at from the real time color signal inputs.
  //
  always@(posedge iVGA_CLK, negedge iRST_n) begin

    if (iRST_n == 1'b0) begin

      reg_dualport_ram_read_address <= 19'd0;
      reg_sprite_ram_read_address <= 19'd0;

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
	      reg_dualport_ram_read_address <= 19'd0;

              // Reset the sprite address
	      reg_sprite_ram_read_address <= 19'd0;

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

		vga_horizontal_line_index <= 10'd0;
		vga_horizontal_visible_line_index <= 10'd0;

		// Set the framebuffer address to the next line address.
		vga_line_address_counter <= vga_line_address_counter + 19'd640;

                //
                // TODO: Could this be the result of bottom monitor overscan?
                // Verilog does not make available the above addition till the next clock.
                //
		// reg_dualport_ram_read_address <= vga_line_address_counter;
                //

		reg_dualport_ram_read_address <= vga_line_address_counter + 19'd640;
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
		  if (vga_horizontal_visible_line_index != 
                      VGA_FRAMEBUFFER_MAX_VISIBLE_HORZ_SCAN_LINE) begin

		    vga_horizontal_visible_line_index <= vga_horizontal_visible_line_index + 10'd1;

                    //
                    // bgr_data_raw is output from the palette generator from
		    // the RAM contents of the sprite or framebuffer RAM.
                    //
                    bgr_data <= bgr_data_raw;

		    reg_dualport_ram_read_address <= reg_dualport_ram_read_address + 19'd1;

                    if (is_in_sprite_region == 1'b1) begin

                      //
                      // Advance the sprite RAM address.
                      //
                      // Note: This only works if the sprite is fully contained
		      // in the visible region.
                      //
                      // More complex logic would be required to track the sprite
		      // RAM address when the sprite is partially off the screen in
		      // various dimensions.
                      //
                      reg_sprite_ram_read_address <= reg_sprite_ram_read_address + 19'd1;
                    end // in sprite_region

		  end // not over the scan line
		end // in visible horizontal region
	      end // in visible vertical region
	  end // not vga_hsync armed
      end // hsync_n state machine
    end // not reset
  end // end always posedge vga_clock

//////Delay the iHD, iVD, iDEN for one clock cycle;
always@(negedge iVGA_CLK) begin
  oHS <= hsync_n;
  oVS <= vsync_n;
  oBLANK_n <= cBLANK_n;
end

endmodule // vga_controller

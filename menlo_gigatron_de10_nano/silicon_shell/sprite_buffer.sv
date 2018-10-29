
//
//   Menlo Silicon Shell Sprite Buffer.
//
//   Copyright (C) 2018 Menlo Park Innovation LLC
//
//   menloparkinnovation.com
//   menloparkinnovation@gmail.com
//
//   Snapshot License
//
//   This license is for a specific snapshot of a base work of
//   Menlo Park Innovation LLC on a non-exclusive basis with no warranty
//   or obligation for future updates. This work, any portion, or derivative
//   of it may be made available under other license terms by
//   Menlo Park Innovation LLC without notice or obligation to this license.
//
//   There is no warranty, statement of fitness, statement of
//   fitness for any purpose, and no statements as to infringements
//   on any patents.
//
//   Menlo Park Innovation has no obligation to offer support, updates,
//   future revisions and improvements, source code, source code downloads,
//   media, etc.
//
//   This specific snapshot is made available under the following license:
//
//   Licensed under the MIT License (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://opensource.org/licenses/MIT
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

// 
// The MIT License (MIT)
// 
// Copyright (c) 2018 Menlo Park Innovation LLC
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
// 
//

//
// Sprite buffer using Altera dual port RAM.
//
// It also generates the sprite enable, size, and position
// signals for the sprite handling VGA controller.
//
module Sprite_Buffer (
  input fpga_clock,
  input reset,

  //
  // Indicate sprite is to be active on the screen.
  //
  input activate_sprite,

  //
  // Sprite parameters to VGA controller with sprite overlay support.
  //
  output         sprite_active,
  output [9:0]   sprite_x_position,
  output [8:0]   sprite_y_position,
  output [9:0]   sprite_x_size,
  output [8:0]   sprite_y_size,

  //
  // Sprite memory.
  //
  // These signals are used by the VGA controller to read the sprite memory.
  //
  input        sprite_read_clock,
  input        sprite_read_signal,
  input [18:0] sprite_read_address,
  output [7:0] sprite_read_data
  );

  // Initial sprite position and size
  parameter SPRITE_Y_POSITION = 9'd0;
  parameter SPRITE_Y_SIZE     = 9'd120;

  parameter SPRITE_X_POSITION = 10'd0;
  parameter SPRITE_X_SIZE     = 10'd320;

  // Sprite parameters
  reg       reg_sprite_active;
  reg [9:0] reg_sprite_x_position;
  reg [8:0] reg_sprite_y_position;
  reg [9:0] reg_sprite_x_size;
  reg [8:0] reg_sprite_y_size;

  assign sprite_active = reg_sprite_active;
  assign sprite_x_position = reg_sprite_x_position;
  assign sprite_y_position = reg_sprite_y_position;
  assign sprite_x_size = reg_sprite_x_size;
  assign sprite_y_size = reg_sprite_y_size;

  //
  // Note: The currently configured sprite RAM capacity is for a full
  // width sprite (640 pixels) at 1/4 of the vertical screen (120 lines).
  //
  // Depending on the size that is to be displayed, the pixels must
  // be packed densly in the RAM, meaning if its a 320 bit wide sprite
  // in the x dimension, each 320 bytes in the RAM represents a line.
  //

  wire        sprite_write_clock;
  assign      sprite_write_clock = fpga_clock;

  wire        sprite_write_enable;
  wire [16:0] sprite_write_address;
  wire [7:0]  sprite_write_data;

  //
  // 76,800 8 bit words of memory.
  //
  dualportspritebuffer	dualportspritebuffer_inst (
    .data ( sprite_write_data ), // write data
    .rdaddress ( sprite_read_address ),
    .rdclock ( sprite_read_clock ),
    .wraddress ( sprite_write_address ),
    .wrclock ( sprite_write_clock ),
    .wren ( sprite_write_enable ),
    .q ( sprite_read_data ) // read data
    );

  always@(posedge fpga_clock) begin
    if (reset == 1'b1) begin
      reg_sprite_active <= 1'b0;

      reg_sprite_y_position <= SPRITE_Y_POSITION;
      reg_sprite_y_size <= SPRITE_Y_SIZE;

      reg_sprite_x_position <= SPRITE_X_POSITION;
      reg_sprite_x_size <= SPRITE_X_SIZE;
    end
    else begin

      if (activate_sprite == 1'b1) begin
        reg_sprite_active <= 1'b1;
      end
      else begin
        reg_sprite_active <= 1'b0;
      end
    end
  end // not reset

  //
  // This simple implementation uses an external file that has
  // the bitmap for the sprite. It is generated by an external program
  // in Verilog $readmemh compatible format.
  //
  // Additional logic can allow selection of different initialization
  // prom's or data area, as well as direct generation of text into
  // bitmap into the sprite buffer with the module Sprite_Character_Generator.
  //

  //
  // Data ROM to fill the sprite.
  //
  parameter DATA_ROM_ARRAY_SIZE = 76800;

  //  width             depth
  reg [7:0] reg_datarom [0:DATA_ROM_ARRAY_SIZE];

  // Leave blank. This allows pre-calculated images to be imported.
  //initial begin
  //  $readmemh(
  //    "C:/Dropbox/embedded/altera/workspace/menlo_gigatron_de10_nano/sprite_text_verilog_data.txt",
  //    reg_datarom,
  //    0,
  //    9866 // 1 minus file size
  //    );
  //end

  //
  // This initializes the sprite buffer when the sprite is activated.
  //
  // Note: it could delay activation while filling in the data before
  // presenting, but right now want to watch it fill in, though it will
  // be pretty fast at the 50Mhz fpga clock rate.
  //

  reg        reg_sprite_write_enable;
  assign sprite_write_enable = reg_sprite_write_enable;

  reg [16:0] reg_sprite_write_address;
  assign sprite_write_address = reg_sprite_write_address;

  reg [7:0]  reg_sprite_write_data;
  assign sprite_write_data = reg_sprite_write_data;

  always@(posedge fpga_clock) begin

    if (reset == 1'b1) begin
      reg_sprite_write_enable <= 1'b0;
      reg_sprite_write_address <= 17'd0;
      reg_sprite_write_data <= 8'd0;
    end
    else begin
      // not reset

      //
      // This will initialize after reset so its available right away
      //

      //
      // One clock per write.
      //
      if (reg_sprite_write_enable == 1'b1) begin
        reg_sprite_write_enable <= 1'b0;
      end
      else begin
        // the sprite buffer is loaded with the ROM contents at 1:1 address.
        if (reg_sprite_write_address < DATA_ROM_ARRAY_SIZE) begin
          reg_sprite_write_data <= reg_datarom[reg_sprite_write_address];
          reg_sprite_write_address <= reg_sprite_write_address + 17'd1;
          reg_sprite_write_enable <= 1'b1;
        end
      end
    end // not reset
  end // always fill in sprite buffer

endmodule // sprite_buffer

//
// Character generator for sprite
//
// Converts a character to a fixed size 4x6 raster scan image and draws
// it into the supplied buffer.
//
// x_position, y_position represent the upper left edge of the character and
// is the lowest address in the buffer. This represents a screen
// scan framebuffer in which address 0 is the upper left of the screen
// during a VGA refresh cycle. The sprite uses similar co-ordinates.
//
// x_size is used to calculate the address stride to write the next row.
//
// It is usually the horizontal size of the sprite or screen buffer.
//
// 6 Y rows will be updated with 4 X pixels starting at x_position, y_position.
//
// The supplied 8 bit true color values for forground color and background
// color will be used to draw the raster scan pixels.
//
// Does not check for overflow or wrap around.
//
// Scale factor will take the basic 4x6 font outline and scale it
// by the value.
//
module Sprite_Character_Generator (
  input         fpga_clock,
  input         reset,

  input         request,     // true when raster generation is requested
  output        request_ack, // true when rasterization is complete.

  // Input parameters
  input  [7:0]  character_to_convert,
  input  [9:0]  x_position,
  input  [9:0]  x_size,
  input  [8:0]  y_position,
  input  [3:0]  scale_factor,

  // 8 bit true color input
  input  [7:0]  foreground_color,
  input  [7:0]  background_color,

  //
  // Output to sprite/framebuffer for generated raster scan.
  //
  // The framebuffer is expected to be one 8 bit byte per pixel
  // in 8 bit true color format.
  //
  // Current logic assumes it can write at the fpga_clock rate
  // with two cycles per write. One cycle to assert write, one cycle
  // to setup the next write (address and data hold time).
  //
  output        framebuffer_write_signal,
  output [18:0] framebuffer_write_address,
  output [7:0]  framebuffer_write_data
  );

  parameter CHARACTER_GENERATOR_ROM_ARRAY_SIZE = 96;

  reg 		reg_request_ack;
  assign request_ack = reg_request_ack;
   
  reg 		reg_framebuffer_write_signal;
  assign framebuffer_write_signal = reg_framebuffer_write_signal;

  reg [18:0]	reg_framebuffer_write_address;
  assign framebuffer_write_address = reg_framebuffer_write_address;

  reg [7:0]	reg_framebuffer_write_data;
  assign framebuffer_write_data = reg_framebuffer_write_data;

  //  width                  depth
  reg [7:0] reg_character_rom[0:CHARACTER_GENERATOR_ROM_ARRAY_SIZE];

  // Character raster from ROM
  reg [15:0] raster;

  // Raster position counter
  reg [3:0] raster_bit_position;

  // Used by the horizontal line raster
  reg [3:0] x_raster_bit_position;

  // Current scale counter for a font pixel
  reg [3:0] x_scale_counter;
  reg [3:0] y_scale_counter;

  // X position in the font
  reg [2:0] x_font_counter;

  // Y position in the font
  reg [2:0] y_font_counter;

  //
  // Character generator ROM data generated by tinyfont/tinyfont_verilog.py
  //
  // tinyfont/tinyfont_table.txt documents the character mappings.
  //
  initial begin
    $readmemh(
      "silicon_shell/tinyfont_verilog_data.txt",
      reg_character_rom
      );
  end

  parameter[3:0]
    IDLE                 = 4'b0000,
    RASTERIZE_X_SCALE_NA = 4'b0001,
    RASTERIZE_NEXT_Y     = 4'b0010,
    RASTERIZE_X_SCALE    = 4'b0011,
    WRITING_MEMORY       = 4'b0100,
    RASTERIZE_Y_BLANK    = 4'b0101,
    RASTERIZE_LINE       = 4'b0110,
    RASTERIZE_NEXT_LINE  = 4'b0111,
    RASTERIZE_Y_BLANK_NA = 4'b1000,
    UNASSIGNED_4         = 4'b1001,
    UNASSIGNED_5         = 4'b1010,
    UNASSIGNED_6         = 4'b1011,
    UNASSIGNED_7         = 4'b1100,
    UNASSIGNED_8         = 4'b1101,
    UNASSIGNED_9         = 4'b1110,
    FINALIZE             = 4'b1111;
   
  reg [2:0] reg_state;
  reg [2:0] reg_next_state;

  always@(posedge fpga_clock) begin
    if (reset == 1'b1) begin
      reg_state <= IDLE;
      reg_next_state <= IDLE;

      reg_request_ack <= 1'b0;

      reg_framebuffer_write_signal <= 1'b0;
      reg_framebuffer_write_address <= 19'd0;
      reg_framebuffer_write_data <= 8'd0;

      raster <= 16'd0;
      raster_bit_position <= 4'd0;
      x_raster_bit_position <= 4'd0;

      x_scale_counter <= 4'd0;
      y_scale_counter <= 4'd0;
      x_font_counter <= 3'd0;
      y_font_counter <= 3'd0;       
    end
    else begin

      case (reg_state) 

        IDLE: begin

          //
          // Input:
          //
          // request - 1 representing new request
          //
          // Output:
          //
          //   Initializes the follow control state variables:
          //     request_ack
          //     reg_framebuffer_write_address
          //     x_font_counter
          //     y_font_counter
          //     x_scale_counter
          //     y_scale_counter
	  //     raster
          //     raster_bit_position
	  //
	  // Modifies:
          //
          // Final Output State - RASTERIZE_NEXT_Y
          //

          if (request == 1'b1) begin

            reg_request_ack <= 0;

            // set start address, parameters
            reg_framebuffer_write_address <= (y_position * x_size) + x_position;

            // 4x6 font scan. Actually 3x5 pixels plus 1 pixel white space in x and y.
            x_font_counter <= 3'd0;
            y_font_counter <= 3'd0;

            x_scale_counter <= 4'd0;
            y_scale_counter <= 4'd0;

            raster_bit_position <= 4'd0;

            // Character is ASCII starting with 0x20 (32) in the ROM.
            raster <= reg_character_rom[character_to_convert - 8'h20];

            reg_state <= RASTERIZE_NEXT_Y;
          end
        end

        RASTERIZE_NEXT_Y: begin

          //
          // Input:
          //
          //   raster_bit_position
          //
          //   y_font_counter
          //     - initialized to zero by the caller
          //
          // Output:
          //
          //   raster_bit_position
          //     - advanced by (3) when done
          //   
	  // Modifies:
          //
          //   y_font_counter
          //
          //   reg_framebuffer_write_address
          //   reg_framebuffer_write_data
          //
          // Final Output State: FINALIZE
          //

          if (y_font_counter == 3'd6) begin
            // Y lines finished
            // Done, ack request, wait for request to de-assert.
            reg_request_ack <= 1'b1;
            reg_state <= FINALIZE;
          end
          else if (y_font_counter == 3'd5) begin

            reg_framebuffer_write_address <=
              ((y_position + y_font_counter) * x_size) + x_position;

            y_font_counter <= y_font_counter + 3'd1;
	     
            // Bump the raster bit position for the (3) we wrote
            raster_bit_position <= raster_bit_position + 4'd3;

            // Write blank background color on last line
            reg_framebuffer_write_data <= background_color;
            x_font_counter <= 3'd0;
            reg_state <= RASTERIZE_Y_BLANK;
          end
          else begin

            // Next vertical address
            reg_framebuffer_write_address <=
              ((y_position + y_font_counter) * x_size) + x_position;

            // Rasterize the next X line
            x_font_counter <= 3'd0;
            y_scale_counter <= 4'd0;

            reg_state <= RASTERIZE_NEXT_LINE;
          end
        end

        RASTERIZE_NEXT_LINE: begin

          //
          // This rasterizes the horizontal font line scale_factor number of
          // times.
	  //
          // It is invoked for each Y line in the pixel.
	  //
          // Input:
          //
          // raster
	  //  - word with the font raster bits
          //
          // raster_bit_position
          //  - bit index into raster with the (3) raster line bits to draw.
          //
          // scale_factor
          //  - number of Y lines to write font X raster
          //
          // y_scale_counter
	  //  - initialized to 0
          //
          // y_font_counter
	  //  - current Y index in font
          //
          // reg_framebuffer_write_address
          //  - Address of pixel to start writing at
          //
          // Output:
          //
          // raster_bit_position
          //  - updated to point to end of current horizontal raster line
          //
          // y_font_counter
          //  - updated to next Y line
          //
	  // Modifies:
          //
          // reg_framebuffer_write_address
          //   - advanced by (4) * scale_factor
          //
          // reg_framebuffer_write_data
          //   - last pixel value written
          //
          // Final Output State: RASTERIZE_NEXT_Y
          //
          if (y_scale_counter == scale_factor) begin
            y_font_counter <= y_font_counter + 3'd1;
            reg_state <= RASTERIZE_NEXT_Y;
	  end
          else begin

            //
            // Setup for the next X line rasterize
            //
            x_raster_bit_position <= raster_bit_position;

            // Next horizontal address
            reg_framebuffer_write_address <= 
              ((y_position + y_scale_counter) * x_size) + x_position;

            y_scale_counter <= y_scale_counter + 4'd1;

            x_font_counter <= 3'd0;

            reg_state <= RASTERIZE_LINE;
          end
        end

        RASTERIZE_LINE: begin

          //
          // TODO: This needs to write each pixel scale_factor times.
          //
          // Use RASTERIZE_X_SCALE.
	  //

          //
	  // This rasterizes a single horizontal line in
	  // the font ROM.
	  //
	  // It may be invoked multiple times by another state
	  // to scale the font in the vertical dimension.
	  //
          // A raster line consists of (3) font raster bits
	  // and a blank one, for (4) total drawn bits at the
	  // current Y, X position.
          //
          // Input:
          //
          // raster
	  //  - word with the font raster bits
          //
          // x_raster_bit_position
          //  - bit index into raster with the (3) raster bits to draw.
          //
          // reg_framebuffer_write_address
          //  - Address of pixel to start writing at
          //
          // x_font_counter
	  //  - caller must initialize to 0
          //
          // Output:
          //
	  // Modifies:
          //
          // x_raster_bit_position
          //
          // x_font_counter
          //
          // reg_framebuffer_write_address
          //   - advanced by (4)
          //
          // reg_framebuffer_write_data
          //   - last pixel value written
          //
          // Final Output State: RASTERIZE_NEXT_LINE
          //

          //
          // A bit set in the pixel raster indicates forground pixel set.
          //
          if (raster[x_raster_bit_position] == 1'b1) begin
            reg_framebuffer_write_data <= foreground_color;
          end
          else begin
            reg_framebuffer_write_data <= background_color;
          end

          if (x_font_counter == 3'd4) begin

            //
            // End of raster line.
            //
            reg_state <= RASTERIZE_NEXT_LINE;
          end
          else if (x_font_counter == 3'd3) begin

            //
            // Last horizontal pixel is blank.
            //

            //
	    // Note this overrides above.
            //
            reg_framebuffer_write_data <= background_color;

            x_font_counter <= x_font_counter + 3'd1;

            // TODO: This will be done by RASTERIZE_X_SCALE...

            reg_framebuffer_write_address <=
              reg_framebuffer_write_address + 19'd1;

            reg_next_state <= RASTERIZE_LINE;
            reg_framebuffer_write_signal <= 1'b1;
            reg_state <= WRITING_MEMORY;
          end
          else begin

            // Next bit position in the raster word.
            x_raster_bit_position <= x_raster_bit_position + 4'd1;

            x_font_counter <= x_font_counter + 3'd1;

            // Next horizontal address
            reg_framebuffer_write_address <=
              reg_framebuffer_write_address + 19'd1;

            reg_next_state <= RASTERIZE_LINE;

            // write memory at the current framebuffer pointer
            reg_framebuffer_write_signal <= 1'b1;
            reg_state <= WRITING_MEMORY;
          end
        end

        RASTERIZE_Y_BLANK: begin

          //
          // TODO: The blank line should be written scale times.
	  //
          // Otherwise currently vertical font spacing is not scaled.
	  //

          //
          // Input:
          //
          // x_font_counter 
	  //   - initialized to 0 by the caller.
          //
          // reg_framebuffer_write_address
          //   - where to start writing
          //
          // Output:
          //
	  // Modifies:
          //
          // x_font_counter
          //
          // reg_framebuffer_write_address
          //
          // raster output memory through RASTERIZE_Y_BLANK state.
	  //
          // Final Output State - RASTERIZE_NEXT_Y
          //

          //
          // Fonts are 4x6, but only 3x5 is in the ROM.
	  //
	  // The last Y line is blank 4 pixels, so write 4 times to
          // the RAM the blank background color
          //
          if (x_font_counter == 3'd4) begin
            reg_state <= RASTERIZE_NEXT_Y;
          end
          else begin

            // Must calculate next address when done writing current
            reg_next_state <= RASTERIZE_Y_BLANK_NA;

            reg_framebuffer_write_signal <= 1'b1;
            reg_state <= WRITING_MEMORY;
	  end
        end

        RASTERIZE_Y_BLANK_NA: begin

	  //
          // This worker state advances the framebuffer address
	  // and x_font_counter.
	  //

          // Next horizontal address
          reg_framebuffer_write_address <=
            reg_framebuffer_write_address + 19'd1;

          x_font_counter <= x_font_counter + 3'd1;

          reg_state <= RASTERIZE_Y_BLANK;
        end

        RASTERIZE_X_SCALE: begin

          //
          // Input:
          //
          //   scale_factor
          //    - scale factor
          //
          //   x_scale_counter
          //    - Initialized to 0 by the caller.
          //
          //   reg_framebuffer_write_address
          //    - Initialized to start address by the caller.
          //
          //   reg_framebuffer_write_data
          //    - Initialized to value to write by the caller.
          //
          // Output:
          //
	  //  Pixels written to memory
          //
	  // Modifies:
          //
          //   x_scale_counter
          //
          //   reg_framebuffer_write_address
          //
          // Final Output State: RASTERIZE_LINE
          //

          //
          // Rasterize X scale outputs the currently selected font
	  // pixel for x_scale_counter times.
          //
          if (x_scale_counter == scale_factor) begin
            reg_state <= RASTERIZE_LINE;
	  end
          else begin

	    //
            // write current reg_framebuffer_write_data which is held constant
	    // for writing the series of "scale" pixels in sequence.
	    //

            reg_next_state <= RASTERIZE_X_SCALE_NA;
            reg_framebuffer_write_signal <= 1'b1;
            reg_state <= WRITING_MEMORY;
          end
        end

        RASTERIZE_X_SCALE_NA: begin

          //
          // Worker state for RASTERIZE_X_SCALE
          //

          // Next address
          reg_framebuffer_write_address <=
            reg_framebuffer_write_address + 19'd1;

          x_scale_counter <= x_scale_counter + 4'd1;

          reg_state <= RASTERIZE_X_SCALE;
        end

        WRITING_MEMORY: begin

          //
          // Input:
          //   reg_framebuffer_address
          //   reg_framebuffer_data
          //
          // Output:
          //
          //   reg_framebuffer_write_signal
          //
	  // Modifies:
          //
          // Final Output State:
          //

          //
          // Done writing framebuffer/sprite memory, go to previously
	  // setup next state.
          //
          reg_framebuffer_write_signal <= 1'b0;

          reg_state <= reg_next_state;
        end

        FINALIZE: begin

          //
          // Input:
          //
          //   request
          //
          // Output:
          //
          //  request_ack
          //
	  // Modifies:
          //
          // Final Output State: IDLE
          //

          // Stay in finalize state until request is deasserted.
          if (request == 1'b0) begin
            reg_request_ack <= 1'b0;
            reg_state <= IDLE;
          end
        end

        default: begin
          reg_request_ack <= 1'b0;
          reg_state <= IDLE;
        end

      endcase
    end // not reset
  end // always

endmodule

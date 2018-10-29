
//
//   Menlo Silicon Shell VGA Test Pattern Generator.
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
// VGA test pattern generator
//
module vga_test_pattern_generator(
    input         vga_clock,
    input         fpga_clock,
    input         application_clock,
    input         reset_n,
    output        write_clock,
    output        write_signal,
    output [18:0] write_address,
    output [7:0]  write_data
    );
   
   // VGA clock is the write clock
   assign write_clock = vga_clock;

   // Test application clock timings
   //assign write_clock = application_clock;

  //
  // Assignments in the always process must be variables (registers)
  // so registers are declared locally, and continuous assigns are used
  // to set the output signals.
  //
  reg [18:0] reg_write_address;
  reg [7:0]  reg_write_data;
  reg        reg_write_signal;

  assign write_address = reg_write_address;
  assign write_data = reg_write_data;
  assign write_signal = reg_write_signal;

  //
  // For test pattern
  //
  reg [31:0] reg_vga_test_counter;
  reg        reg_vga_writing_framebuffer;
   
  //
  // Test pattern loop to verify VGA + framebuffer.
  //
  // Uses the VGA clock.
  //
  // Writes an incrementing 8 bit color pattern in the frame buffer
  // per clock period.
  //
  always@(posedge vga_clock) begin

    if (reset_n == 1'b0) begin
      reg_write_address <= 0;
      reg_write_data <= 0;
      reg_write_signal <= 0;

      reg_vga_test_counter <= 0;
      reg_vga_writing_framebuffer <= 0;
    end
    else begin

      //
      // Not Reset
      //

      //
      // Process sequential write of the current VGA 8 bit value through the frame buffer.
      //
      if (reg_vga_writing_framebuffer != 1'b0) begin

          if (reg_write_signal == 1'b1) begin
              // done with this framebuffer location.
              reg_write_signal <= 1'b0;
              reg_write_address <= reg_write_address + 18'd1;
          end
          else begin

              // Write not asserted, see if we are still writing the framebuffer
              if (reg_write_address == 0) begin
                  reg_vga_writing_framebuffer <= 1'b0; // Done
              end
              else begin
                  reg_write_signal <= 1'b1; // Write current address
              end
          end
      end

      //
      // 25Mhz clock, 8 million clocks == ~1/4 sec
      //
      if (reg_vga_test_counter < 32'h007FFFFF) begin
          reg_vga_test_counter <= reg_vga_test_counter + 1;
      end
      else begin

          //
          // New cycle, increment the color value.
          //
          reg_vga_test_counter <= 0; // reset counter

          // 8 bit wrap around
          reg_write_data <= reg_write_data + 8'd1;
       
          // Indicate we are writing the framebuffer
          reg_vga_writing_framebuffer <= 1;
          reg_write_address <= 0;
          reg_write_signal <= 1;
      end
    end
  end

endmodule // vga_test_pattern_generator

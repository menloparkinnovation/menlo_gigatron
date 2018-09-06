
//`define EDGE_MARKERS 1

//
// TODO:
// 08/19/2018
//
//  Markers are done, alignments with internal buffers looks fine.
//
//  Examine the state of the y, x registers during the burst line in the code.
//   0x010d is hsync_n and blue signal
//
// 08/17/2018
//
// debugging ideas:
//
// Scan line 27 shows the first pixel burst.
//
// Mark the begining and end of the scan lines with red + green
// to see if truncation occurs from internal rgb ram logic to framebuffer
// read and conversion with the Linux tool.
//
// Try not using io_write as a qualification signal.
//
// Find scan line number for pixel burst with white
//  v_line_index == 78
//
// Validate values from RAM
//  Determine if full line
//
// Look at memory addressing
//
// Identify bits in binary .rgb file.
//
// 08/15/2018
//  - Add tracking counters to know full range of the vertical
//    and horizontal timings in Gigatron and FPGA clocks.
//    - could be part of the PLL.
//  - Expand vertical dimension to 512 from 256.
//  - Figure out model for blanking/hold steady when there are
//    no io_write's. Monitor will display last DAC outputs.
//    ?Is gigatron clock the dot clock?
//  - Use the FPGA clock for the VGA PLL.
//
// 08/13/2018
//  - why blue? does it need to run longer?
//   #- output format issue, fixed.
//   - what PC is it at?
//   - is output port data being captured correctly into framebuffer memory?
//  #- why is file 3X?
//   #- must use %b formatting
//

//
// See MENLO_COPYRIGHT.TXT for the copyright notice for this file.
//
// Use of this file is not allowed without the copyright notice present
// and re-distributed along with these files.
//

// set timescale for 1ns with 100ps precision.
`timescale 1ns / 100ps

//
// 07/04/2018
//
// One file implementation of the Gigatron in System Verilog.
//
// Inspired by the one file C program gtemu.c and the simple
// block diagram.
//
// Why Gigatron?
//
// It's a simple processor. It does not take up much space on an FPGA
// so it can be used to implement more complex state machines better
// represented in a processor than Verilog for access by software trained
// engineers.
//
// Since its simple, it provides a great introduction to the implemention
// of soft-procesors on an FPGA.
//
// Since it uses low resources, you can implement multiple of them dedicated
// to specific tasks in parallel. So you effectively have a "multi-core"
// processor setup.
//
// Since its simple, its easy to customize for specific tasks such as
// memory block move instructions, protocol processing instructions, and
// other "instructions" connected directly to FPGA logic expressed in Verilog.
//
// Due to its simple, low resource design it can be used in hybrid architectures
// such as hyperthreading in which longer memory latencies (such as over
// a PCIe bus, a DRAM, etc.) can be "hidden" from multiple virtual execution
// units Tera computer or SPARC hyperthreading style.
//
// 6.25 Mhz Clock: This is required to execute existing Gigatron software
// correctly since timing loops are embedded in the code as per practice
// in the 8 bit world. For embedded situations with new code you can use
// the clock frequency of your FPGA, which is 50Mhz on the Altera Cyclone V
// used in the Terasic DE10-Standard and DE10-Nano boards.
//

//
// The top level Gigatron module integrates its EEPROM, RAM,
// I/O, and system control signals.
//
// This allows the components to be replaced or repurposed as needed.
//

module Gigatron_BlinkenLights
(
    input [7:0] ext_io_in,

    // Generated BlinkenLights signals
    output led5, // extended_output_port bit 0
    output led6, // "" bit 1
    output led7, // "" bit 2
    output led8  // "" bit 3
);

  assign led5 = ext_io_in[0:0];
  assign led6 = ext_io_in[1:1];
  assign led7 = ext_io_in[2:2];
  assign led8 = ext_io_in[3:3];

endmodule // Gigatron_BlinkenLights

module Gigatron_Audio_Handler
(
    input fpga_clock,
    input gigatron_clock,
    input reset,
    input [7:0] ext_io_in, // Gigatron Extended I/O port
    output [3:0] output_audio_dac
    );

  //
  // extended_output_port bits 7-4
  //
  // This is a real time audio pass through. The audio interface logic
  // to the specific FPGA board will sample at its audio clock sampling
  // rate which is higher than the Gigatrons..
  //
  assign output_audio_dac = ext_io_in[7:4];

endmodule //

//
// This module is not part of the Gigatron, but handles the 8 bit output
// signals from the Gigatron I/O output port and generates the VGA signals
// for the FPGA VGA logic.
//
// Gigatrons RAW VGA signals are passed through for implementations
// that operate the VGA timings directly from the Gigatron.
//
// In addition, the Gigatron VGA timings are decoded and a set of
// output signals are generated to write to a RAM based external
// framebuffer.
//
// This allows an external VGA controller implemenentation handle the
// VGA monitor at a different resolution and timing of the Gigatron.
//
// The output format is 8 bit true color, as documented at:
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
module Gigatron_VGA_Handler
(
    input fpga_clock,
    input vga_clock,
    input gigatron_clock,
    input vga_reset,
    input [7:0] io_in,
    input io_write,

    // Raw VGA signals from the Gigatron
    output       raw_output_hsync_n,
    output       raw_output_vsync_n,
    output [1:0] raw_output_red,
    output [1:0] raw_output_green,
    output [1:0] raw_output_blue,

    // Write output to external framebuffer
    output        output_framebuffer_write_clock,
    output        output_framebuffer_write_signal,
    output [18:0] output_framebuffer_write_address,
    output  [7:0] output_framebuffer_write_data
);

  //
  // raw_output_* are async combinatorial non-registered signals
  // generated from the raw Gigatron io_in.
  //
  // output_framebuffer_* are registered signals generated by the VGA
  // receiver control logic.
  //
  // vga_* are internal variables used by the VGA receiver control logic.
  //

  //
  // RAW Gigatron VGA signals.
  //
  // Gigatron determines the external VGA monitor timing for these signals.
  //
  // These are asynchronous logic, and must be handled carefully.
  //
  assign raw_output_hsync_n = io_in[6:6];
  assign raw_output_vsync_n = io_in[7:7];
  assign raw_output_red = io_in[1:0];
  assign raw_output_green = io_in[3:2];
  assign raw_output_blue = io_in[5:4];

  //
  // This synthesizes the 8 bit true color output from the
  // Gigatron's 2 bit color signals.
  //

  wire [7:0] raw_gigatron_eight_bit_true_color;

  // Red
  assign raw_gigatron_eight_bit_true_color[7:6] = raw_output_red;
  assign raw_gigatron_eight_bit_true_color[5:5] = 1'b0;

  // Green
  assign raw_gigatron_eight_bit_true_color[4:3] = raw_output_green;
  assign raw_gigatron_eight_bit_true_color[2:2] = 1'b0;

  // Blue
  assign raw_gigatron_eight_bit_true_color[1:0] = raw_output_blue;

  //
  // VGA Clocking:
  //

  //
  // Double clock any inputs received from the gigatron.
  // Otherwise the compiler gets confused about the Gigatrons large asynchronous
  // blocks and does not know if a stable output is present in all cases in the
  // main VGA receivers always process.
  //

  reg [7:0] reg_gigatron_eight_bit_true_color;
  reg       reg_gigatron_vsync_n;
  reg       reg_gigatron_hsync_n;

  //
  // fpga_clock is used to minimize signal delay from the Gigatron running
  // at Gigatron clock.
  //
  always@(posedge fpga_clock) begin

      if (vga_reset == 1'b1) begin
          reg_gigatron_eight_bit_true_color <= 0;
          reg_gigatron_vsync_n <= 0;
          reg_gigatron_hsync_n <= 0;
      end
      else begin
          reg_gigatron_eight_bit_true_color <= raw_gigatron_eight_bit_true_color;
          reg_gigatron_vsync_n <= raw_output_vsync_n;
          reg_gigatron_hsync_n <= raw_output_hsync_n;
      end
  end

  //
  // These are the registered outputs for the VGA framebuffer write signals.
  //

  // Read and written by the framebuffer write always process.
  reg        vga_framebuffer_write_signal;

  // Set by the VGA state machine always process
  reg [18:0] vga_framebuffer_write_address;
  reg  [7:0] vga_framebuffer_write_data;

  // FPGA clock is used for framebuffer write in its own always process.
  assign output_framebuffer_write_clock = fpga_clock;

  assign output_framebuffer_write_signal = vga_framebuffer_write_signal;
  assign output_framebuffer_write_address = vga_framebuffer_write_address;
  assign output_framebuffer_write_data = vga_framebuffer_write_data;

  //
  // Framebuffer write process. This runs at FPGA clock to allow a
  // complete write cycle to complete to the dual port RAM during a
  // single VGA clock pixel cycle.
  //

  //
  // This is written by the VGA state machine always process, and
  // read by the framebuffer write process.
  //
  reg vga_framebuffer_write_request;

  //
  // Framebuffer write process.
  //
  always@(posedge fpga_clock) begin

    if (vga_reset == 1'b1) begin
      vga_framebuffer_write_signal <= 0;
    end
    else begin

      //
      // Not reset
      //
      if (vga_framebuffer_write_signal == 1'b1) begin
        // Done with a framebuffer write request
        vga_framebuffer_write_signal <= 0;
      end
      else begin

        //
        // No write in progress, see if a new request is to started.
        //
        // Note that vga_framebuffer_write_request is controlled by the
        // VGA state machine always process.
        //
        if (vga_framebuffer_write_request == 1'b1) begin

          //
          // This will cause the contents of vga_framebuffer_write_address and
          // vga_framebuffer_write_data to be written to the framebuffer
          // dual port RAM.
          //
          vga_framebuffer_write_signal <= 1'b1;
        end

      end // no write in progress

    end // not reset

  end // framebuffer write process

  //
  // VGA receiver state machine Implementation
  //
  // This basically implements a 640x480 VGA monitor at 25Mhz storing
  // the 8 bit true color results of its visible area into a
  // 300K (307,200 bytes) (640*480*1_byte) framebuffer.
  //

  parameter VGA_V_FRONT_PORCH = 10'd6;     // This is actually 6 after its clock adjust from 10 in ROMv2.py
  parameter VGA_V_BACK_PORCH  = 10'd25;    // Top is cut off. So reduce a few lines.
  //parameter VGA_V_BACK_PORCH  = 10'd33;  // from ROMv2.py

  parameter VGA_H_FRONT_PORCH = 10'd16;    // From vga_controller.v
  parameter VGA_H_BACK_PORCH  = 10'd45;    // To much cut off the side
  //parameter VGA_H_BACK_PORCH  = 10'd144; // from vga_controller.v

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
  always@(posedge vga_clock) begin

    if (vga_reset == 1'b1) begin

      //
      // These signals are read by the framebuffer write always process.
      //
      vga_framebuffer_write_request <= 0;
      vga_framebuffer_write_address <= 0;
      vga_framebuffer_write_data <= 0;

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

      if (vga_framebuffer_write_request == 1'b1) begin

          //
          // The framebuffers write signal is controlled by its own
          // always process since it runs at fpga_clock. This is 2X
          // the vga_clock, and allows time to complete a write cycle
          // during a VGA clock pixel time.
          //
          // This can be updated back to 1'b1 by the VGA state machine
          // below during a horizontal pixel burst at VGA clock rate.
          //

          vga_framebuffer_write_request <= 1'b0;
      end
	
      //
      // Process vsync state machine
      //
      if (reg_gigatron_vsync_n == 1'b0) begin

	  // vsync is asserted
	  vga_vsync_arm <= 1'b1;
      end
      else begin

	  //
	  // reg_vsync_n is not asserted
	  //

	  if (vga_vsync_arm == 1'b1) begin

	      // A vsync has occured, reset the framebuffer address
	      vga_framebuffer_write_address <= 19'd0;
	      vga_line_address_counter <= 19'd0;
	      vga_vertical_line_index <= 10'd0;
	      vga_horizontal_line_index <= 10'd0;
	      vga_horizontal_visible_line_index <= 10'd0;

	      vga_vsync_arm <= 1'b0;
	  end

      end // reg_gigatron_vsync_n state machine

      //
      // Process hsync state machine
      //
      if (reg_gigatron_hsync_n == 1'b0) begin

	  vga_hsync_arm <= 1'b1;

      end
      else begin

	  //
	  // reg_gigatron_hsync_n is not asserted
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
		vga_framebuffer_write_address <= vga_line_address_counter;
	      end
	  end
	  else begin

	      //
	      // Main pixel scan logic. We read the Gigatron VGA data at
	      // VGA clock rate to simulate a monitor.
	      //
	      // Even though the maximum rate that the pixels can be written
	      // by the Gigatron is at the Gigatron clock rate, the monitor
	      // will write four horizontal pixels for each Gigatron pixel.
	      //
	      // This is by design in the Gigatrons 160 pixel horizontal
	      // pixel count, which is 1/4 of the VGA horizontal pixel
	      // clock sample rate for 640 x 480 mode.
	      //

	      //
	      // Don't add horizontal lines to framebuffer unless in the
	      // visible region.
	      //
	      if (vga_vertical_line_index >= VGA_V_BACK_PORCH) begin

		vga_horizontal_line_index <= vga_horizontal_line_index + 10'd1;

		if (vga_horizontal_line_index >= VGA_H_BACK_PORCH) begin

		  // Ensure we don't overrun the current horizontal scan lines allocated memory
		  if (vga_horizontal_visible_line_index != VGA_FRAMEBUFFER_MAX_VISIBLE_HORZ_SCAN_LINE) begin

		    vga_horizontal_visible_line_index <= vga_horizontal_visible_line_index + 10'd1;

		    vga_framebuffer_write_data <= reg_gigatron_eight_bit_true_color;
		    vga_framebuffer_write_address <= vga_framebuffer_write_address + 19'd1;
		    vga_framebuffer_write_request <= 1'b1;
		  end

		end // in visible horizontal region

	      end // in visible vertical region

	  end // not vga_hsync armed

      end // reg_gigatron_hsync_n state machine

    end // not reset

  end // end always posedge vga_clock

endmodule

module Gigatron
(
    // FPGA 50Mhz clock
    input       fpga_clock,

    // VGA 25Mhz clock
    input       vga_clock,

    // 6.25 Mhz Gigatron clock
    input       clock,

    // Reset when == 1
    input reset,

    // run == 0 Halt, run == 1 run/resume
    input run,

    // I/O Port signals
    input  [7:0] gigatron_input_port,
    output [7:0] gigatron_output_port,
    output [7:0] gigatron_extended_output_port,

    // Raw VGA signals from the Gigatron
    output hsync_n,
    output vsync_n,
    output [1:0] red,
    output [1:0] green,
    output [1:0] blue,

    // Write output to external framebuffer
    output        framebuffer_write_clock,
    output        framebuffer_write_signal,
    output [18:0] framebuffer_write_address,
    output  [7:0] framebuffer_write_data,

    // BlinkenLights Signals
    output led5, // extended_output_port bit 0
    output led6, // "" bit 1
    output led7, // "" bit 2
    output led8, // "" bit 3

    // 4 bit Audio DAC
    output [3:0] audio_dac, // extended_output_port bits 7-4

    // Serial game controller
    output ser_pulse,
    output ser_latch,
    input  ser_data
);

  //
  // The 64k x 16 EEPROM
  //

  wire [15:0] eeprom_address;
  wire [15:0] eeprom_data;
  wire        eeprom_cs;

  Gigatron_EEPROM eeprom(
    .address(eeprom_address),
    .data(eeprom_data),
    .cs(eeprom_cs)
  );

  //
  // The 32k x 8 RAM
  //

  wire [14:0] ram_address;
  wire [7:0]  ram_data;
  wire        ram_cs;
  wire        ram_oe;
  wire        ram_write;

  Gigatron_RAM_Wrapper ram(
    .clock(fpga_clock),
    .address(ram_address),
    .data(ram_data),
    .cs(ram_cs),
    .oe(ram_oe),
    .write(ram_write) // input
  );

  //
  // Create the I/O handler instances
  //

  wire output_port_write;

  Gigatron_VGA_Handler vga(
    .fpga_clock(fpga_clock),
    .vga_clock(vga_clock),
    .gigatron_clock(clock),
    .vga_reset(reset),
    .io_in(gigatron_output_port),
    .io_write(output_port_write),
    .raw_output_hsync_n(hsync_n),
    .raw_output_vsync_n(vsync_n),
    .raw_output_red(red),
    .raw_output_green(green),
    .raw_output_blue(blue),
    .output_framebuffer_write_clock(framebuffer_write_clock),
    .output_framebuffer_write_signal(framebuffer_write_signal),
    .output_framebuffer_write_address(framebuffer_write_address),
    .output_framebuffer_write_data(framebuffer_write_data)
  );

  Gigatron_BlinkenLights blinkenlights(
    .ext_io_in(gigatron_extended_output_port),
    .led5(led5),
    .led6(led6),
    .led7(led7),
    .led8(led8)
  );

  //
  // Audio
  //
  Gigatron_Audio_Handler audio(
    .fpga_clock(fpga_clock),
    .gigatron_clock(clock),     // Gigatron clock
    .reset(reset),
    .ext_io_in(gigatron_extended_output_port),
    .output_audio_dac(audio_dac)
    );

  // Game Controller
  assign ser_pulse = 1'b0;
  assign ser_latch = 1'b0;

  //
  // The Gigatron CPU is its own module to allow customization
  // of EEPROM, RAM and I/O signals.
  //
  // This allows its use as a general purpose soft processor
  // on the FPGA.
  //
  // For example a tiny Gigatron CPU instance could be used with
  // a 4K EEPROM and a 2K RAM with custom I/O port bindings to
  // implement software based state machine, function, packet
  // or signal procesor, etc. The size of the EEPROM and RAM can
  // be customized to the task at hand, up to the Gigatrons
  // addressing limits.
  //
  // In addition RAM address space can be used to map additional
  // I/O registers which would be accessed using RAM instructions.
  //

  Gigatron_CPU cpu(

    // Support signals
    .clock(clock),
    .reset(reset),
    .run(run),

    // EEPROM signals
    .eeprom_address(eeprom_address),
    .eeprom_data(eeprom_data),
    .eeprom_cs(eeprom_cs),

    // Ram signals
    .ram_address(ram_address),
    .ram_data(ram_data),
    .ram_cs(ram_cs),
    .ram_oe(ram_oe),
    .ram_write(ram_write), // output

    // I/O signals
    .input_port_data(gigatron_input_port), // input
    .output_port_data(gigatron_output_port), // output
    .extended_output_port_data(gigatron_extended_output_port), // output

    .output_port_write(output_port_write) // output
  );

endmodule

module Gigatron_CPU
(
    // 6.25 Mhz clock
    input       clock,

    // Reset when == 1
    input reset,

    // run == 0 Halt, run == 1 run/resume
    input run,

    //
    // EEPROM
    //
    // Note: eeprom_address is not declared reg since its
    // driven by an assign from the PC, which is a reg.
    //
    output [15:0]      eeprom_address,

    input [15:0]       eeprom_data,
    output reg         eeprom_cs,

    // RAM
    output [14:0 ]     ram_address,
    inout [7:0]        ram_data,
    output reg         ram_cs,
    output reg         ram_oe,
    output reg         ram_write,

    // I/O signals
    input [7:0]        input_port_data,
    output [7:0]       output_port_data,
    output [7:0]       extended_output_port_data,

    //
    // This is true when the output port is being written
    // It allows the VGA logic to clock the RGB outputs.
    //
    output             output_port_write
);

  //
  // Gigatron Parameters
  //

  //
  // Note: This is from the actual schematic. The videos on youtube
  // are in conflict with this.
  //
  // Validated by reading the source code to the Gigatron assembler,
  // and it in fact encodes the opcode in the upper three bits.
  //
  parameter[2:0]
    OPCODE_LD     = 3'b000,
    OPCODE_AND    = 3'b001,
    OPCODE_OR     = 3'b010,
    OPCODE_XOR    = 3'b011,
    OPCODE_ADD    = 3'b100,
    OPCODE_SUB    = 3'b101,
    OPCODE_ST     = 3'b110,
    OPCODE_BRANCH = 3'b111;

  //
  // The main Gigatron program EEPROM is 16 bits wide, 64K in size.
  //
  parameter EEPROM_DATA_WIDTH = 16;
  parameter EEPROM_ADDR_WIDTH = 16;
  parameter EEPROM_DEPTH = 1 << EEPROM_ADDR_WIDTH;

  //
  // The Gigatron RAM is 32kx8
  //
  parameter RAM_DATA_WIDTH = 8;
  parameter RAM_ADDR_WIDTH = 15 ;
  parameter RAM_DEPTH = 1 << RAM_ADDR_WIDTH;

  //
  // registered data declarations
  //

  //
  // 16 bit program counter
  //
  // This drives the EEPROM with an assign statement.
  //
  reg [15:0] PC;

  //
  // IR (instruction) register holds the current instruction being decoded
  // and operated on from the eeprom.
  //
  // Instructions are technically 8 bits, but always include the 8 bit
  // immediate data/instruction literal parameter even if not needed. So
  // you could says its a 16 bit instruction format MIPS style in which
  // each instruction always has 8 immediate bits to work with in addition
  // to the base instructions encoding for address modes, etc.
  //
  reg [7:0] IR;

  //
  // D register holds the current instruction operand from the eeprom.
  //
  // Note: The 8 bit instructions always include the 8 bit D parameter even
  // if not used/needed by the instruction.
  //
  // The D register is contained in addressing modes as a source of data,
  // and is how load immediate is implemented. It can be output onto the data bus
  // from a control signal based on opcode, addressing mode, bus mode.
  //
  reg [7:0] D;

  // 8 bit accumulator
  // reg AC
  reg [7:0] AC;

  // 8 bit X register
  reg [7:0] X;

  // 8 bit Y register
  reg [7:0] Y;

  //
  // The Output Register is on Schematic page 7/8 is a user
  // register loaded by CPU instructions.
  //
  // It provides signals that drive the extended I/O registers.
  //
  // The extended output register and the game controller input
  // port are clocked by bit 6 of this register going high under
  // software control.
  //

  reg [7:0] reg_output_port;

  //
  // Extended Output Port
  //
  // Schematic page 8/8.
  //
  // KEYWORDS: output port
  //
  // It's loaded with the accumulators current contents
  // when the Output Port's bit 6 (HSYNC_N) goes high.
  //
  reg [7:0] reg_extended_output_port;

  //
  // Hold clocked input data based on OUT6 going high.
  //
  // Schematic page 8/8
  //
  // KEYWORDS: input port
  //
  reg [7:0] reg_game_controller_input;

  //
  // Instruction format:
  //
  // 7 6 5  4 3 2  1 0
  // OPCODE AMOD   BUS
  //

  //
  // Control wires, signals
  //
  // wires are driven by registers, in most cases after passing
  // through async logic in a subunit decoder. The async subunit
  // provides its output function within the current clock cycle
  // of the main instruction fetch + decode clocked always process.
  //

  // Main data bus
  // reg bus (search term)
  wire [7:0] bus;

  // ALU output
  wire [7:0] alu;
  wire       alu_co;

  //
  // Top level assignments
  //

  //
  // This ensures the EEPROM address reflects the current PC value.
  //
  assign eeprom_address = PC;

  //
  // Buses
  //
  // There are to main buses in the Gigatron CPU that connect
  // multiple registers and endpoints. These are:
  //
  // Data bus, which connects the following:
  //
  // RAM - input/output
  //
  // D   - output only
  //
  // AC  - output only
  // 
  // ALU - input only
  //
  // PC (lower half) - input only
  //
  // Input - input only
  //

  //
  // The Gigatron Control Unit module asychronously within the current
  // clock period determines the output of the control signals used
  // to latch the results in the stateful registers at the end of
  // the clock period.
  //
  // It models the timing of the Gigatron hardware implementation in TTL
  // of executing each instruction, including its RAM access within
  // one clock cycle. This design may not be ideal on an FPGA for maximum
  // speed, but we are modeling the Gigatrons 6.25Mhz clock on a 50Mhz or
  // better FPGA. Exact software timings of instructions are critical to
  // the Gigatrons generation of video, sound, game movement, etc so its
  // modeled here as implemented in TTL.
  //
  // A more native FPGA design would use additional clocked stages as required
  // to get timing closure at full speed of the FPGA.
  //
  // Note: Signal names match what is on the schematic to make it easy to
  // go between the physical Gigatron implementation and its representation
  // in Verilog. "cu_" has been added for local clarity.
  //

  // User registers
  wire cu_xl_n;
  wire cu_yl_n;
  wire cu_ix;

  // Memory Address Unit selects
  wire cu_eh;
  wire cu_el;

  // Control signals for user registers on schematic page 7/8
  wire cu_dl_n; // Output register clock enable (load) (note: actually OL_N on schematic)
  wire cu_ld_n; // Accumulator register clock enable (load)

  // This allows the VGA logic to clock the RGB outputs.
  assign output_port_write = ~cu_dl_n;

  // Program Counter
  wire cu_pl_n;
  wire cu_ph_n;

  // ALU controls
  wire cu_al;
  wire cu_ar0;
  wire cu_ar1;
  wire cu_ar2;
  wire cu_ar3;

  //
  // memory write signal.
  //
  // Generated by the following module hierarchy:
  //
  // Gigatron_CPU
  //  Gigatron_Control_Unit
  //    Gigatron_Instruction_Decoder
  //
  wire we_n;

  // Bus Access Decoder
  wire de_n; // enable D
  wire oe_n; // enable RAM
  wire ae_n; // enable AC
  wire ie_n; // enable input I/O port

  Gigatron_Control_Unit ControlUnit(
    .clock(clock),
    .opcode(IR),

    // input signals
    .ac7(AC[7:7]), // Accumulator bit 7

    // X, Y registers
    .xl_n(cu_xl_n),
    .yl_n(cu_yl_n),
    .ix(cu_ix),

    // Memory Address Unit
    .eh(cu_eh),
    .el(cu_el),

    // User registers
    .dl_n(cu_dl_n), // Output register load enable
    .ld_n(cu_ld_n), // Accumulator

    // Program Counter
    .pl_n(cu_pl_n),
    .ph_n(cu_ph_n),

    // ALU
    .co(alu_co),
    .al(cu_al),
    .ar0(cu_ar0),
    .ar1(cu_ar1),
    .ar2(cu_ar2),
    .ar3(cu_ar3),

    // RAM
    .we_n(we_n), // output

    // Bus Decoder
    .de_n(de_n),
    .oe_n(oe_n),
    .ae_n(ae_n),
    .ie_n(ie_n)
  );

  //
  // Gigatron ALU
  //

  Gigatron_ALU ALU(
    .ac(AC),     // accumulator
    .bus(bus),   // main data bus (input)
    .al(cu_al),  // input control signals
    .ar0(cu_ar0),
    .ar1(cu_ar1),
    .ar2(cu_ar2),
    .ar3(cu_ar3),
    .alu(alu),   // alu output
    .co(alu_co)  // alu carry output
  );

  //
  // Assigns outside the clocked procedure (always) block.
  //

  //
  // Gigatron Data Bus
  //
  // Handles the outputs from the bus access decoder
  // and enables the different registers onto the bus
  // based on these decodes.
  //
  // This implements a traditional tri-state bus which
  // enables on value on it one at a time.
  //
  // The bus decoder logic ensures only one of the four
  // bus enable signals are enabled (low true) at one time.
  //

  // Assign D to bus when enabled
  assign bus = (de_n == 1'b0) ? D : 8'hZZ;

  // Enable RAM data bus
  assign bus = (oe_n == 1'b0) ? ram_data : 8'hZZ;

  // Assign AC to bus when enabled
  assign bus = (ae_n == 1'b0) ? AC : 8'hZZ;

  //
  // Enable the registered I/O input port to bus.
  //
  // The I/O input port register clocks its raw input signals
  // under software control from the output port's bit 6 going high,
  // which is also the HSYNC_N signal. The value read now by the
  // current instruction is the value clocked in during the previous
  // HSYNC_N signal going high.
  //
  // KEYWORDS: input port
  assign bus = (ie_n == 1'b0) ? reg_game_controller_input : 8'hZZ;

  //
  // KEYWORDS: RAM
  //
  // The Gigatron accesses the RAM asynchronously within a
  // single clock cycle. As such asynchronous continous assigns
  // must be used to generate the output control signals to the RAM.
  //
  // The signals are generated by the asynchronous instruction decoder,
  // control unit, and memory address unit.
  //
  // Memory and Address Unit schematic page 5/8
  //
  // 74HCT157 Quad 2:1 Mux non-inverting.
  //
  // S on schematic when low selects input 0
  //
  // E_N on schematic when high forces output to 0
  //
  // Truth Table:
  //
  // EH EL | AH  AL  Notation
  //  L  L |  Y   X  [y,x]
  //  L  H |  Y   D  [y,$dd]
  //  H  L |  0   X  [x]
  //  H  H |  0   D  [$dd]
  //

  //
  // ram chip-select is is always asserted
  //
  // Note: cs_n on schematic, but memory module here is active high cs.
  //
  assign ram_cs = 1'b1;

  // Ram output enable from Bus Decoder
  assign ram_oe = ~oe_n;

  // Generate positive high ram_write signal from control unit signal.
  assign ram_write = ~we_n;

  // Select high RAM address from Y register, or constant zero.
  assign ram_address[14:8] = (cu_eh == 1'b0) ? Y[6:0] : 7'b0000000;

  // Select low RAM address from X register, or D (instruction operand).
  assign ram_address[7:0] = (cu_el == 1'b0) ? X : D;

  //
  // The RAM data bus is bi-directional so logic must ensure that
  // the drivers are tri-stated when write is not enabled.
  //
  // Schematic page 5/8, Memory and Address Unit.
  //
  assign ram_data = (ram_write) ? bus : 8'bz;

  //
  // I/O handling
  //
  // The Output Register on schematic page 7/8 is loaded as
  // a user register under software control from instructions
  // whose address mode is OUTPUT.
  //
  // This Output Register generates the VGA signals through a series
  // of resistors and provides a going high clock on bit 6 that is
  // used to clock two auxilary I/O registers Extended Output and
  // Game controller input.
  //
  // Note that bit 6 is also the HSYNC_N line to the VGA monitor
  // so HSYNC_N going high clocks current accumulator output
  // into the Extended Output register.
  //

  // This allows the output to reflect the registered Output Port value.
  assign output_port_data = reg_output_port;

  assign extended_output_port_data = reg_extended_output_port;

  //
  // The Auxiliary I/O registers are clocked by the general output port
  // bit 6 going high.
  //
  wire aux_io_clock;
  assign aux_io_clock = reg_output_port[6:6];

  //
  // Auxilary I/O register processing block
  //
  // The extended output and game controller input registers
  // are clocked by reg_output_port[6:6] going high
  // separate from the main clock CLK1.
  //
  // So they need their own always block.
  //
  // This implements the logic on schematic page 8/8.
  //
  always @ (posedge aux_io_clock or posedge reset) begin

    // handle async reset
    if (reset == 1'b1) begin
      reg_extended_output_port <= 0;
      reg_game_controller_input <= 8'h00;
    end
    else begin
      if (aux_io_clock == 1'b1) begin

          // Clock the current accumulator register value to the AUX I/O output
          reg_extended_output_port <= AC;

          // Read the game controller input from the raw I/O input lines.
          reg_game_controller_input <= input_port_data;
      end
    end
  end // end always extended I/O processing

  //
  // Main processor execution block
  //
  // Reads and executes an instruction on every clock cycle.
  //
  // This includes memory accesses.
  //
  // It has a one stage instruction fetch and decode pipeline. In the
  // current clock period the PC value is used to lookup the next
  // instruction in the EEPROM, while the current instruction in the
  // IR + D registers is decoded and computes its result using async
  // combinatorial logic.
  //
  // At the end of the current clock period the resulting output signals
  // are stored in the registers, and provide the stable state for the
  // next clock period. This includes the result of the EEPROM lookup
  // based on the PC at entry to the current clock, thus pre-loading
  // the next instruction for decode.
  //
  // As a result of the one instruction prefetch, branches taken always
  // execute the instruction after the branch before the new PC value
  // is loaded and the branch target instruction is executed. The software
  // model for the Gigatron CPU takes this into account.
  //
  // The assignments in this always process match the stateful
  // registers that CLK1 and CLK2 connects to in the Gigatron since these
  // sample and store their inputs at the rising edge of each clock pulse.
  // In Verilog RTL this is represented as non-blocking assignments "<=" in a
  // clocked always process.
  //
  // As described above, the inputs sampled are generated by the
  // async combinatorial logic within the current clock cycle and
  // represent the critical timing path of the core Gigatron one
  // instruction per clock cycle design.
  //

  always @ (posedge clock) begin

    if (reset == 1'b1) begin

      //
      // Initial CPU registers
      //
      PC <= 0;
      IR <= 0;
      D <= 0;
      AC <= 0;
      X <= 0;
      Y <= 0;

      // EEPROM controls
      // Begin with dedicated EEPROM selected
      eeprom_cs <= 1;

      //
      // Note: the reg_output_port is assigned by instructions and
      // updated in this always process.
      //
      // Bit 6 of this port drives the clock for the auxiliary output port
      // and the game controller input port which are handled in their own
      // parallel always process.
      //
      reg_output_port <= 0;

    end
    else begin

      //
      // Not reset
      //

      //
      // Run controls whether the CPU is executing instructions
      // in an externally controlled wait state. External controls
      // could control single step, etc.
      //

      if (run == 1'b1) begin

        //
        // Update the program counter.
        //
        // Note: This could get updated by the following
        // instruction logic if a branch. The Verilog clocked always
        // process rule for non-blocking assignments will store the
        // the last update value overriding this assignment.
        //
        // The current PC value at the start of the current clock cycle
        // will reflect the value stored during the previous clock cycle
        // and not any of these stores in the current clock cycle.
        //

        PC <= PC + 16'h0001;

        //
        // This is the prefetch of the next instruction
        // from the EEPROM into the IR + D registers.
        //
        // The IR + D registers values for this clock cycle remain
        // the values loaded from the previous cycle.
        //

        IR <= eeprom_data[7:0]; // Low Byte
        D <= eeprom_data[15:8]; // High Byte

        //
        // The asynchronous logic submodules have decoded instruction
        // opcode, address mode, bus mode, and branch condition from the
        // *previous* clock cycle and have resulting outputs.
        //
        // Assign these outputs to the stateful registers to be
        // written at the end of the current clock cycle.
        //

        //
        // User registers on schematic page 7/8 with signals generated
        // by the Control Unit's outputs.
        //

        //
        // Load Accumulator from the ALU result.
        //
        if (cu_ld_n == 1'b0) begin
          AC <= alu;
        end

        //
        // Load X from the ALU result
        //
        if (cu_xl_n == 1'b0) begin
            X <= alu;
        end

        //
        // Load Y from the ALU result
        //
        if (cu_yl_n == 1'b0) begin
            Y <= alu;
        end

        //
        // Increment X if the X increment control signal is set.
        //
        if (cu_ix == 1'b1) begin
            X <= X + 8'h01;
        end

        //
        // Load Output Register (I/O output port) from the ALU result.
        //
        if (cu_dl_n == 1'b0) begin
          reg_output_port <= alu;
        end

        //
        // Load program counter if branch condition is set, implements jump/bcc.
        //
        if (cu_pl_n == 1'b0) begin
          // Note: bus can come from multiple sources based on Bus Access Decoder
          PC[7:0] <= bus;
        end

        if (cu_ph_n == 1'b0) begin
          PC[15:8] <= Y;
        end

      end // end if run

    end // not reset

  end // always

endmodule

//
// The Gigatron Control Unit generates control signals in an
// asynchronous fashion.
//
// It performs the function of the combination of gates and diodes used in the
// physical Gigatron hardware implementation documented on page
// 4/8 of the schematics.
//
// It's fully asynchronous and slaved to the clock of the containing
// Gigatron_CPU.
//
// As such it only uses combinatorial logic.
//
module Gigatron_Control_Unit
(
    input clock,
    input [7:0] opcode,

    // input signals
    input ac7,

    // User registers
    output xl_n,
    output yl_n,
    output ix,

    // Output to Memory Address Unit
    output eh,
    output el,

    // User registers
    output dl_n, // Load Output Register from ALU
    output ld_n, // Load Accumulator from ALU

    // Program Counter
    output pl_n,
    output ph_n,

    // ALU
    input co,
    output al,
    output ar0,
    output ar1,
    output ar2,
    output ar3,

    // Memory write signal
    output we_n,

    // Bus Access Decoder
    output de_n,
    output oe_n,
    output ae_n,
    output ie_n
);

  //
  // Continuous assigns must be used since we are driving
  // output signals as pure wires, not register. This allows the
  // calculations to occur within the same clock cycle of this
  // modules containing clocked RTL always block.
  //

  //
  // The following modules make up the Gigatron Control Unit on page 4/8.
  //
  // Bus(Access)Decoder
  //
  // (Address)ModeDecoder
  // 
  // ConditionDecoder
  //
  // InstructionDecoder
  //
  // JumpDetector
  //

  //
  // Bus Access Decoder
  //

  //
  // Lower 2 bits (1, 0) are BUS operation.
  //

  wire [1:0] busmode;
  assign busmode = opcode[1:0];

  Gigatron_Bus_Access_Decoder BusAccessDecoder(
    .busmode(busmode),
    .de_n(de_n),  // enable D => bus
    .oe_n(oe_n),  // enable RAM => bus
    .ae_n(ae_n),  // enable ACC => bus
    .ie_n(ie_n)   // enable input port => bus
  );

  //
  // Address Mode Decoder
  //

  //
  // Middle 3 bits (4, 3, 2) are the address mode for non-branch instructions.
  //
  // The address mode decoder combines the 3:8 decoder and the,
  // the diode array, and some combinatorial logic gates to
  // generate the output control signals.
  //

  wire [2:0] address_mode;
  assign address_mode = opcode[4:2];

  wire j_n;
  wire u16b_4;
  wire u16c_9;

  Gigatron_Address_Mode_Decoder AddressModeDecoder(
    .address_mode(address_mode),
    .j_n(j_n),
    .xl_n(xl_n),
    .yl_n(yl_n),
    .ix(ix),
    .eh(eh),
    .el(el),
    .u16b_4(u16b_4),
    .u16c_9(u16c_9)
  );

  //
  // Condition Decoder
  //
  // Branch condition is the middle 3 bits (4, 3, 2) of opcode.
  //

  wire [2:0] condition;
  assign condition = opcode[4:2];

  wire inv_c_out_n;

  Gigatron_Condition_Decoder ConditionDecoder(
    .condition(condition),
    .j_n(j_n),
    .ac7(ac7), // Accumulator bit 7
    .co(co),
    .inv_c_out_n(inv_c_out_n)
  );

  //
  // Instruction Decoder
  //

  //
  // The upper 3 bits (7, 6, 5) are the 8 instruction opcodes.
  //
  // The instruction decoder combines the 3:8 decoder and the,
  // the diode array, and some combinatorial logic gates to
  // generate the output control signals.
  // 

  wire [2:0] instr;
  assign instr = opcode[7:5];

  wire w_n;

  Gigatron_Instruction_Decoder InstructionDecoder(
    .clock(clock),
    .instr(instr),
    .w_n(w_n),
    .j_n(j_n),
    .we_n(we_n), // output
    .al(al),
    .ar0(ar0),
    .ar1(ar1),
    .ar2(ar2),
    .ar3(ar3)
  );

  //
  // Jump Detector
  //

  Gigatron_Jump_Detector JumpDetector(
    .condition(condition),
    .j_n(j_n),
    .inv_c_out_n(inv_c_out_n),
    .pl_n(pl_n),
    .ph_n(ph_n)
  );

  //
  // Page 4/8 of schematic
  //

  //
  // dl_n is clock enable to Output Register pin 1 CLKEN_N  
  //
  // ul16_b is driven by diodes for [D], OUT and [Y,X++], OUT address modes.
  //
  // Note: this is really OL_N on the schematic to mean Output Load
  //
  assign dl_n = (u16b_4 | ~w_n); // ~w_n creates w from w_n into inv_b_in/inv_b_out on the schematic.

  // ld_n is the clock enable to Accumulator Register pin 1 CLK_EN
  assign ld_n = (u16c_9 | ~w_n);

endmodule // Gigatron_Control_Unit

//
// Gigatron ALU
//
// The Gigatron ALU is on page 6/8 of the schematics.
//
// The Gigatron ALU operates asynchronous to the clock.
//
// ac is the output from the accumulator and an input
// operand to the ALU.
//
// bus is the shared bus by many registers that can drive it
// and read from it. For the ALU its an input that allows
// the source of an operand to come from any source driving
// the bus enabled by the control unit.
//
module Gigatron_ALU
(
    // ALU input   
    input [7:0] ac,  // accumulator register output
    input [7:0] bus, // data bus input to ALU

    // ALU control signals
    input al,
    input ar0,
    input ar1,
    input ar2,
    input ar3,

    // ALU output signals
    output [7:0] alu,
    output co
);

  //
  // The Gigatron ALU uses 4:1 muxes as a form of LUT (lookup table)
  // to implement the various ALU operations using a pair of 4 bit
  // 2 operand adders.
  //
  // It's truth table appears rather bizarre at first if you look
  // at it as an input 4:1 mux for signal sources, but it is not
  // being used in that way. It's actually encoding the bits
  // from the AC and BUS into a set of input selections depending
  // on constants set by hard tied 1's or 0's, and the output from
  // the instruction decoder diode array (PROM in the definition
  // of the Gigatron designers).
  //
  // It uses a 74HCT153 non-inverting 4:1 mux with enable line
  // to implement the ALU truth table that provides inputs to
  // the cascaded 4 bit adders to create an 8 bit ALU that does
  // add, sub, or, and, xor.
  //
  // The Verilog here replicates the exact wiring on the schematic
  // using a x74xx153 utility module that implements the truth
  // table of the 4:1 mux in the TTL IC chip.
  //
  // Truth table from the schematic on page 6/8
  //
  // L stands for "left" side of the chip, and is operand
  // A input to the adder.
  //
  // R stands for "right" side of the chip, and is the operand
  // B input to the adder.
  //
  // An important control point is that the AL signal from the
  // control unit when high forces one operand to 0, as its
  // connected to the enable low line of the 74HCT153 whose
  // truth table output is forced low when enable is high (disabled).
  //
  // This provides the 0 operand input for operations that compare
  // to 0. It's also used by the ld instruction to "passthrough" the
  // ALU a value from the bus, ignoring the accumulator.
  //
  //
  // Instuction | L   R        CIN  Result
  // -------------------------------------
  // LD         | 0   B        0    B
  // AND        | 0   A AND B  0    A AND B
  // OR         | 0   A OR B   0    A OR B
  // XOR        | 0   A XOR B  0    A XOR B
  // ADD        | A   B        0    A + B
  // SUB        | A   NOT B    1    A - B
  // ST         | A   0        0    A
  // Bcc        | 0   NOT A    1    -A
  //
  // The schematic references design notes of another project
  // describing this style of ALU implementation and really clarifies
  // things.
  //
  // This is at: http://6502.org/users/dieter/a1/a1_4.htm
  //
  // The key point is that MUX's are used as a form of lookup
  // table (LUT) to implement the boolean logic functions for
  // AND, OR, XOR, NOT. In addition they can provide pass through
  // signals from the AC to the adder, and generate 0's as one of
  // the adder operands when needed for compare with zero used
  // for branches.
  //

  wire [7:0] alu_operand_a;
  wire [7:0] alu_operand_b;

  //
  // Note: Unlike the upper bits the output from the 4:1 mux
  // into the ALU operands is consistent among the lower bits 3-0.
  // 

  //
  // Truth table for the A side of the 74HCT153 on the upper
  // half of the schematic on page 6/8. Notice that it differs
  // from the lower half, which is documented following the
  // upper half module instances.
  //
  // The "A" side of the muxes supply operand A input to the adder bits 3-0.
  //
  // Note: unlike the lower half of the schematic no bits are swapped
  // here. The A side goes to operand A bits 3-0 as expected, and the
  // B side goes to operand B bits 3-0 as expected.
  //
  // Ea is hardwired to 0, so the mux is always enabled.
  //
  // The inputs to A are the AR3 - AR0 signals from the control
  // unit, programmed by the diode array. This allows the output
  // of the truth table for all combinations of ACx and BUSx to
  // be under "microcode" control, with the microprogram being
  // supplied by the diodes acting as a PROM.
  //
  // Using this technique the AND, OR, XOR logic functions can
  // be implemented. The ADD logic function operates as a passthrough
  // of the operands to the adder.
  //
  // S0 == ACx
  // S1 == BUSx
  //
  // BUS AC | Za
  // ----------
  //  0  0  | AR0
  //  0  1  | AR1
  //  1  0  | AR2
  //  1  1  | AR3
  //
  // Further understanding of the logic here requires the per
  // instruction truth table provided by the diode array in the
  // instruction decoder which generates the AR3 - AR0 signals.
  //
  // This is an another example of using a mux as a lookup table (LUT)
  // which can implement any boolean function of its inputs based on
  // its settings in each location. In this case the locations value
  // is set by the instruction decoder based on the instructions
  // logical operation results.
  //
  // By comparing the truth table below with the one for the
  // BUS, AC signals above you can see how the computation of
  // AND, OR, XOR, and NEG occurs. In addition you can see how
  // some operands "pass through" the truth table with it
  // acting as a router/switch as well. A good example of
  // this usage is the load (ld) instruction.
  //
  // Notice how Bcc uses the AC complement, or negation
  // similar to the sub instruction which is using the negation
  // of the BUS signal.
  //
  // Logical per instruction truth table:
  //
  //  inst | AR3 AR2 AR1 AR0
  // ---------------------------
  //  ld   |   1   1   0   0      => BUS passes through to operand A
  //  and  |   1   0   0   0      => AND(BUS, AC) to operand A
  //  or   |   1   1   1   0      => OR(BUS, AC) to operand A
  //  xor  |   0   1   1   0      => XOR(BUS, AC) to operand A
  //  add  |   1   1   0   0      => BUS passes through to operand A
  //  sub  |   0   0   1   1      => ~BUS passes through to operand A
  //  st   |   0   0   0   0      => 0 passes through to operand A
  //  bcc  |   0   1   0   1      => ~AC passes through to operand A
  //
  // Note: operand B is supplied as 0 or AC based on the AL
  // signal by the B side of the mux below.
  //
  // 0 is supplied to ld, and, or, xor, bcc to allow the resulting
  // truth table computed value to passthrough the adder unchanged.
  //
  // AC is supplied for the add, sub, st, instructions.
  //
  // The st instruction works by passing 0 to operand A of the
  // adder, but AL == 0, so the AC passes through to operand B.
  // This way the AC can be placed on the memory bus with the
  // generated we_n memory write control signal.
  //
  // Note: You would not write a Verilog native ALU this way,
  // instead using simpler Verilog statements that (hopefully)
  // compile to adders and logic elements on the FPGA.
  // But we are modeling the Gigatrons TTL implementation, which
  // uses these efficient techniques which are fast for the TTL
  // era since it minimizes externally packaged gates and reuses
  // the on-chip fast gates of the mux.
  //

  //
  // Truth table for the B side of the 74HCT153 on the upper
  // half of the schematic on page 6/8. Notice that it differs
  // from the lower half, which is documented following the
  // upper half module instances.
  //
  // The "B" side of the muxes supply operand B input to the adder bits 3-0.
  //
  // Note: unlike the lower half of the schematic no bits are swapped
  // here. The A side goes to operand A bits 3-0 as expected, and the
  // B side goes to operand B bits 3-0 as expected.
  //
  // Based on the value of the AL line, they select either all
  // zeros (AL = 1), or the value in the accumulator (AL = 0).
  //
  // The mechanism for passing through the accumulator value uses
  // hardwired inputs as follows:
  //
  // IOb - 0
  // I1b - 1
  // I2b - 0
  // I3b - 1
  //
  // The S0 select line is the ACx bit.
  //
  // The S1 select line is the Busx bit.
  //
  // When disabled by AL == 1, which disables Eb, the output
  // is always 0. This used when a 0 operand is desired to the adder.
  //
  // When AL == 0, the output is based on the truth table of the
  // select lines S1, S0 based on the hardwired inputs above.
  //
  // S0 == ACx
  // S1 == BUSx
  //
  // BUS AC | Zb
  // ----------
  //  0  0  |  0
  //  0  1  |  1
  //  1  0  |  0
  //  1  1  |  1
  //
  // With ACx on S0, this means Zb follows ACx, or the value
  // from the accumulator regardless of the value of S1, which
  // is connected to BUSx. In this way it "passes through" the
  // value of the accumulator, ignoring the value from BUSx.
  //
  // This is an example of using the 4:1 mux as a LUT, or lookup table
  // to implement any truth table desired based on the number of input
  // bits (locations or entries). On the FPGA itself this is done with
  // 64x1 RAM cells for 6 input LUT's.
  //

  x74xx153 alu_decoder_bit0(
    .E1_N(1'b0),   // Pin 1, Ea on schematic
    .S1(bus[0:0]), // pin 2, S1 on schematic
    .I1_3(ar3),    // pin 3, I3a
    .I1_2(ar2),    // pin 4, I2a
    .I1_1(ar1),    // pin 5, I1a
    .I1_0(ar0),    // pin 6, I0a on schematic
    .Y1(alu_operand_a[0:0]), // pin 7, Za on schematic, Operand A

    .Y2(alu_operand_b[0:0]), // pin 9, Zb on schematic, Operand B
    .I2_0(1'b0),   // pin 10, I0b on schematic
    .I2_1(1'b1),   // pin 11, I1b
    .I2_2(1'b0),   // pin 12, I2b
    .I2_3(1'b1),   // pin 13  I3b
    .S0(ac[0:0]),  // pin 14, S0 on schematic
    .E2_N(al)      // pin 15, Eb on schematic
  );

  x74xx153 alu_decoder_bit1(
    .E1_N(1'b0),   // Pin 1, Ea on schematic
    .S1(bus[1:1]), // pin 2, S1 on schematic
    .I1_3(ar3),    // pin 3, I3a
    .I1_2(ar2),    // pin 4, I2a
    .I1_1(ar1),    // pin 5, I1a
    .I1_0(ar0),    // pin 6, I0a on schematic
    .Y1(alu_operand_a[1:1]), // pin 7, Za on schematic

    .Y2(alu_operand_b[1:1]), // pin 9, Zb on schematic
    .I2_0(1'b0),   // pin 10, I0b on schematic
    .I2_1(1'b1),   // pin 11, I1b
    .I2_2(1'b0),   // pin 12, I2b
    .I2_3(1'b1),   // pin 13  I3b
    .S0(ac[1:1]),  // pin 14, S0 on schematic
    .E2_N(al)      // pin 15, Eb on schematic
  );

  x74xx153 alu_decoder_bit2(
    .E1_N(1'b0),   // Pin 1, Ea on schematic
    .S1(bus[2:2]), // pin 2, S1 on schematic
    .I1_3(ar3),    // pin 3, I3a
    .I1_2(ar2),    // pin 4, I2a
    .I1_1(ar1),    // pin 5, I1a
    .I1_0(ar0),    // pin 6, I0a on schematic
    .Y1(alu_operand_a[2:2]), // pin 7, Za on schematic

    .Y2(alu_operand_b[2:2]), // pin 9, Zb on schematic
    .I2_0(1'b0),   // pin 10, I0b on schematic
    .I2_1(1'b1),   // pin 11, I1b
    .I2_2(1'b0),   // pin 12, I2b
    .I2_3(1'b1),   // pin 13  I3b
    .S0(ac[2:2]),  // pin 14, S0 on schematic
    .E2_N(al)      // pin 15, Eb on schematic
  );

  x74xx153 alu_decoder_bit3(
    .E1_N(1'b0),   // Pin 1, Ea on schematic
    .S1(bus[3:3]), // pin 2, S1 on schematic
    .I1_3(ar3),    // pin 3, I3a
    .I1_2(ar2),    // pin 4, I2a
    .I1_1(ar1),    // pin 5, I1a
    .I1_0(ar0),    // pin 6, I0a on schematic
    .Y1(alu_operand_a[3:3]), // pin 7, Za on schematic

    .Y2(alu_operand_b[3:3]), // pin 9, Zb on schematic
    .I2_0(1'b0),   // pin 10, I0b on schematic
    .I2_1(1'b1),   // pin 11, I1b
    .I2_2(1'b0),   // pin 12, I2b
    .I2_3(1'b1),   // pin 13  I3b
    .S0(ac[3:3]),  // pin 14, S0 on schematic
    .E2_N(al)      // pin 15, Eb on schematic
  );

  //
  // Truth table for the A side of the 74HCT153 on the lower
  // half of the schematic on page 6/8. Notice that it differs
  // from the upper half, so it called out here.
  //
  // Since this provides the LUT truth table based on the
  // hardwired inputs, it performs a similar function
  // to the "B" side of the upper half of the schematic
  // providing operand B input to the adder, in this case
  // for logically for bits 7 - 4.
  //
  // Notice in this case there is a swapping of which bits
  // supply which operand of the adder for bit 7 and bit 4.
  // This is explained further in a following section.
  //
  // The A side provides the following bits to the adder:
  //
  // Bit 4 - operand A4 // Swapped: this is swapped A -> B
  // Bit 5 - operand B5 // Normal: Reflects behavior of upper half of the schematic
  // Bit 6 - operand B6 // Normal: Reflects behavior of upper half of the schematic
  // Bit 7 - operand A7 // Swapped: this is swapped A -> B
  //
  // The "A" side has hard wired inputs of the following:
  //
  // IOa - 0
  // I1a - 0
  // I2a - 1
  // I3a - 1
  //
  // When disabled by AL == 1, which disables Ea, the output
  // is always 0. This used when a 0 operand is desired.
  //
  // When AL == 0, the output is based on the truth table of the
  // select lines S1, S0 based on the hardwired inputs above.
  //
  // S0 == BUSx
  // S1 == ACx
  //
  // AC BUS | Za
  // ----------
  //  0  0  |  0
  //  0  1  |  0
  //  1  0  |  1
  //  1  1  |  1
  //
  // With ACx on S1, this means Za follows ACx, or the value
  // from the accumulator regardless of the value of S0, which
  // is connected to BUSx. In this way it "passes through" the
  // value of the accumulator.
  //
  // This is an example of using the 4:1 mux as a LUT, or lookup table.
  //

  //
  // Truth table for the B side of the 74HCT153 on the lower
  // half of the schematic on page 6/8. Notice that it differs
  // from the upper half, which is documented above for bits 3 - 0.
  //
  // The "B" sides output is based on the control signals AR3 - AR0.
  //
  // The "B" side of the muxes supply operand A input to the adder bits
  // 6 and 5 and would be "normal" in that it reflects the schematics
  // upper half in supplying the AR3 - AR0 signals to operand A
  // of the adder.
  //
  // The "B" side of the muxes supply operand B input to the adder bits
  // 7 and 4 and are reversed from what you would expect.
  //
  // In addition unlike the upper half of the schematic in which
  // the AR3 - AR0 inputs match 1:1 with the  mux selected input signals
  // the middle two are also reversed. This is documented in the
  // truth table below.
  //
  // Logically all B side bits should go to operand A of the adder,
  // with symmetry of the AR3 - AR0 signals to the mux selected input
  // signals, mirroring the connections on the upper half of the schematic.
  // This is explained later in a following section.
  //
  // Eb is hardwired to 0, so the mux is always enabled.
  //
  // The inputs to B are the AR3 - AR0 signals from the control
  // unit, programmed by the diode array. This allows the output
  // of the truth table for all combinations of ACx and BUSx to
  // be under "microcode" control, with the microprogram being
  // supplied by the diodes acting as a PROM.
  //
  // Using this technique the AND, OR, XOR logic functions can
  // be implemented. The ADD logic function operates as a passthrough
  // of the operands to the adder.
  //
  // Note: For bits 7-4 on the lower half of the schematic the S0 + S1
  // select inputs are reversed, and so are the AR1 + AR2 data inputs.
  // This allows the truth table to operate the same as the upper half
  // of the schematic even though the S1 + S0 wiring is reversed.
  //
  // S0 == BUSx // Note: reversed from connections in upper half of schematic
  // S1 == ACx  // Note: reversed from connections in upper half of schematic
  //
  // AC BUS | Zb
  // ----------
  //  0  0  | AR0
  //  0  1  | AR2 // Note: reversed from connections in upper half of schemaic
  //  1  0  | AR1 // Note: reversed from connections in upper half of schematic
  //  1  1  | AR3
  //
  // Further understanding of the logic here requires the per
  // instruction truth table provided by the diode array in the
  // instruction decoder which generates the AR3 - AR0 signals.
  //
  // Logical per instruction truth table:
  //
  //  inst | AR3 AR2 AR1 AR0
  // ---------------------------
  //  ld   |   1   1   0   0      => BUS passes through to operand A
  //  and  |   1   0   0   0      => AND(BUS, AC) to operand A
  //  or   |   1   1   1   0      => OR(BUS, AC) to operand A
  //  xor  |   0   1   1   0      => XOR(BUS, AC) to operand A
  //  add  |   1   1   0   0      => BUS passes through to operand A
  //  sub  |   0   0   1   1      => ~BUS passes through to operand A
  //  st   |   0   0   0   0      => 0 passes through to operand A
  //  bcc  |   0   1   0   1      => ~AC passes through to operand A
  //

  //
  // Details on reversed operand and ARx selected input bits.
  //
  // It appears related that the ARx bits are swapped with
  // which bits of Za and Zb go to operand A and operand B
  // of the adder.
  //
  // At a base line, in the case of adding 0 to a result with
  // these bits swapped results in the following conditions:
  //
  // For reference, normal is 0 as operand B and the value as
  // operand A.
  // 
  // Normal:
  //
  //     A          B          Z
  //  00000000 + 00000000 = 00000000
  //  00000000 + 01010101 = 01010101
  //  00000000 + 10101010 = 10101010
  //  00000000 + 11111111 = 11111111
  //
  // With bits 7 + 4 reversed
  //
  // Note that this generates no carries which would effect the
  // result if CIN == 0. Note that AR0 supplies the CIN signal
  // to the first 4 bit adder. In this case the add opcode has
  // AR0 == 0, so no carry in.
  //
  //     A          B          Z
  //  00000000 + 00000000 = 00000000
  //  00010000 + 01000101 = 01010101
  //  10000000 + 00101010 = 10101010
  //  10010000 + 01101111 = 11111111
  //
  // From the above result, adding 0 in one operand
  // to a result in other works the same for either normal
  // or reversed bits 7 + 4 provided there is no carry in.
  //
  // Logically, AND, OR, XOR operate similar, and since there
  // is  no carry to worry about their truth tables operate
  // the same with the bits swapped.
  //
  // So in the end it appears the swapping has no effect
  // on operation.
  //

  //
  // But why swap these bits? Bit 7 must be the key, since
  // this is the "sign" bit. This swap must be used for
  // operations that want to branch on less than, equal to,
  // or greater than zero. But an examination of the
  // jump detector shows it uses AC[7:7] and not the
  // result of the ALU for the sign bit. The only ALU
  // output used is the COUT signal used to indicate
  // whether a branch occurs at 0, or !0.
  //
  // It's easy to chalk this up to convenient wiring, and may
  // be the reason for swapping the A + B sides of the muxes
  // between the upper and lower halfs, but the bit swap
  // and confused logic in the lower half must have a reason.
  //
  // Normally designs would follow a regular, logical pattern that
  // is easy to understand rather than resort to trickery. Unless
  // the wiring was expecially ugly or involved sensitive timing
  // paths it would have been best to keep the use of the A and
  // B sides of the muxes the same, with the same order of the
  // select inputs as well. But there is likely some subtle trick
  // here as a result of the whole series of optimizations explained
  // at the web site:
  // http://6502.org/users/dieter/a1/a1_4.htm
  //
  // From instruction decoder:
  //
  // Note: each instruction when present results in a 1 output.
  //
  // assign ar0 = (~sub_n | ~bcc_n);
  // assign ar1 = (~or_n  | ~xor_n | ~sub_n);
  // assign ar2 = (~ld_n  | ~or_n  | ~xor_n | ~add_n | ~bcc_n);
  // assign ar3 = (~ld_n  | ~and_n | ~or_n  | ~add_n);
  //
  // Logical per instruction truth table:
  //
  //  inst | AL AR3 AR2 AR1 AR0
  // ---------------------------
  //  ld   |  1   1   1   0   0
  //  and  |  1   1   0   0   0
  //  or   |  1   1   1   1   0
  //  xor  |  1   0   1   1   0
  //  add  |  0   1   1   0   0
  //  sub  |  0   0   0   1   1
  //  st_  |  0   0   0   0   0
  //  bcc  |  1   0   1   0   1
  //

  //
  // al is 1 for the first (4) instructions due to high bit of INSTR
  //
  // (~ld_n | ~and_n | ~or_n | ~xor_n | ~bcc_n)
  //
  // assign al = (~instr[2:2] | ~bcc_n); // D21, D34
  //

  //
  // *** OPERANDS A + B ARE REVERSED FOR THIS BIT ***
  //

  x74xx153 alu_decoder_bit4(
    .E1_N(al),     // Pin 1, Ea on schematic
    .S1(ac[4:4]),  // pin 2, S1 on schematic
    .I1_3(1'b1),   // pin 3, I3a
    .I1_2(1'b1),   // pin 4, I2a
    .I1_1(1'b0),   // pin 5, I1a
    .I1_0(1'b0),   // pin 6, I0a on schematic
    .Y1(alu_operand_a[4:4]), // pin 7, Za on schematic, ALU operand A (normal)

    .Y2(alu_operand_b[4:4]), // pin 9, Zb on schematic, ALU operand B (normal)
    .I2_0(ar0),    // pin 10, I0b on schematic
    .I2_1(ar2),    // pin 11, I1b // *REVERSED*
    .I2_2(ar1),    // pin 12, I2b // *REVERSED*
    .I2_3(ar3),    // pin 13  I3b
    .S0(bus[4:4]), // pin 14, S1 on schematic
    .E2_N(1'b0)    // pin 15, Eb on schematic
  );

  //
  // This is wired as expected in that its B side with
  // the AR3 - AR0 signals goes to operand A of the adder
  // mirroring the upper half of the schematic.
  //

  x74xx153 alu_decoder_bit5(
    .E1_N(al),     // Pin 1, Ea on schematic
    .S1(ac[5:5]),      // pin 2, S1 on schematic
    .I1_3(1'b1),   // pin 3, I3a
    .I1_2(1'b1),   // pin 4, I2a
    .I1_1(1'b0),   // pin 5, I1a
    .I1_0(1'b0),   // pin 6, I0a on schematic
    .Y1(alu_operand_b[5:5]), // pin 7, Za on schematic, ALU operand B (*reversed*)

    .Y2(alu_operand_a[5:5]), // pin 9, Zb on schematic, ALU operand A (*reversed*)
    .I2_0(ar0),    // pin 10, I0b on schematic
    .I2_1(ar2),    // pin 11, I1b // *REVERSED*
    .I2_2(ar1),    // pin 12, I2b // *REVERSED*
    .I2_3(ar3),    // pin 13  I3b
    .S0(bus[5:5]), // pin 14, S1 on schematic
    .E2_N(1'b0)    // pin 15, Eb on schematic
  );

  //
  // This is wired as expected in that its B side with
  // the AR3 - AR0 signals goes to operand A of the adder
  // mirroring the upper half of the schematic.
  //

  x74xx153 alu_decoder_bit6(
    .E1_N(al),     // Pin 1, Ea on schematic
    .S1(ac[6:6]),      // pin 2, S1 on schematic
    .I1_3(1'b1),   // pin 3, I3a
    .I1_2(1'b1),   // pin 4, I2a
    .I1_1(1'b0),   // pin 5, I1a
    .I1_0(1'b0),   // pin 6, I0a on schematic
    .Y1(alu_operand_b[6:6]), // pin 7, Za on schematic, ALU operand B (*reversed*)

    .Y2(alu_operand_a[6:6]), // pin 9, Zb on schematic, ALU operand A (*reversed*)
    .I2_0(ar0),    // pin 10, I0b on schematic
    .I2_1(ar2),    // pin 11, I1b // *REVERSED*
    .I2_2(ar1),    // pin 12, I2b // *REVERSED*
    .I2_3(ar3),    // pin 13  I3b
    .S0(bus[6:6]), // pin 14, S1 on schematic
    .E2_N(1'b0)    // pin 15, Eb on schematic
  );

  //
  // *** OPERANDS A + B ARE REVERSED FOR THIS BIT ***
  //

  x74xx153 alu_decoder_bit7(
    .E1_N(al),     // Pin 1, Ea on schematic
    .S1(ac[7:7]),  // pin 2, S1 on schematic
    .I1_3(1'b1),   // pin 3, I3a
    .I1_2(1'b1),   // pin 4, I2a
    .I1_1(1'b0),   // pin 5, I1a
    .I1_0(1'b0),   // pin 6, I0a on schematic
    .Y1(alu_operand_a[7:7]), // pin 7, Za on schematic, ALU operand A (normal)

    .Y2(alu_operand_b[7:7]), // pin 9, Zb on schematic, ALU operand B (normal)
    .I2_0(ar0),    // pin 10, I0b on schematic
    .I2_1(ar2),    // pin 11, I1b // *REVERSED*
    .I2_2(ar1),    // pin 12, I2b // *REVERSED*
    .I2_3(ar3),    // pin 13  I3b
    .S0(bus[7:7]), // pin 14, S1 on schematic
    .E2_N(1'b0)    // pin 15, Eb on schematic
  );

  //
  // The ALU adder consists of 2 74HCT283 4 bit full adders with fast carry
  // to create an 8 bit adder.
  //
  // Carry in to the first 4 bit adder is from AR0.
  //
  // The carry out of the first 4 bit addr is the carry in of the second one.
  //
  // The carry out of the second adder is the co (carry overlow) signal.
  //
  // Note: On the schematics the carry in on pin 7 is marked "C0" but is "Cin" on
  // the data sheet. Don't confuse this will the actual carry out which is pin
  // 9, marked "Cout" on the data sheet, but "C4" on the schematic.
  //
  // In addition the data sheet starts the A and B operand numbering with 0
  // while the schematic starts with 1. So for example pin 5 which is the "A0"
  // operand on the data sheet is marked "A1" on the schematic.
  //

  // Operands
  wire [7:0] A;
  wire [7:0] B;
  wire CIN;

  // Output
  wire [7:0] S;

  // Internal carry signals
  wire carry1;
  wire carry2;
  wire carry3;
  wire carry4;
  wire carry5;
  wire carry6;
  wire carry7;
  
  //
  // Connect the output of the 4:1 muxes to the adders operands.
  //
  assign A = alu_operand_a;
  assign B = alu_operand_b;

  // Carry in is connected to ar0 on the schematic page 6/8.
  assign CIN = ar0;

  // ALU is the output result along with co
  assign alu = S;

  //
  // Full adder circuit described in:
  //
  // Fundamentals of Digital Logic with Verilog Design
  // Stephen Brown, Zvonko Vranesic
  // Third edition
  // page 154 
  // McGraw Hill 2014
  //
  // www.eecg.toronto.edu/~brown/Verilog_3e
  // Note: The above web site was not used, only the general
  // idea of a full adder consisting of XOR logic for its
  // sum, and AND logic for its carry computation as a well
  // known practice.
  //
  // This implements a ripple adder which should work fine on a
  // 50Mhz FPGA in a 6.25 Mhz circuit such as the Gigatron.
  //
  // A text book fast adder could be implemented, or use
  // Verilog Synthesis add statements to use FPGA based adders.
  //
  // Note HDL compilers tend to recognize "text book" Verilog
  // patterns such as this and optimize to an internal fast
  // adder, so this ripple carry adder may actually get reduced
  // to a fast adder block that will operate at the FPGA's
  // design speed.
  //

  //
  // 8 bit add CIN + A + B => C + COUT
  //
  Gigatron_FullAdder stage0(CIN,    A[0:0], B[0:0], S[0:0], carry1);
  Gigatron_FullAdder stage1(carry1, A[1:1], B[1:1], S[1:1], carry2);
  Gigatron_FullAdder stage2(carry2, A[2:2], B[2:2], S[2:2], carry3);
  Gigatron_FullAdder stage3(carry3, A[3:3], B[3:3], S[3:3], carry4);
  Gigatron_FullAdder stage4(carry4, A[4:4], B[4:4], S[4:4], carry5);
  Gigatron_FullAdder stage5(carry5, A[5:5], B[5:5], S[5:5], carry6);
  Gigatron_FullAdder stage6(carry6, A[6:6], B[6:6], S[6:6], carry7);
  Gigatron_FullAdder stage7(carry7, A[7:7], B[7:7], S[7:7], co);

endmodule // Gigatron_ALU

//
// Full Adder using industry text book description with
// XOR sum function and AND carry computation.
//
module Gigatron_FullAdder(
    input CIN,
    input A,
    input B,
    output S,
    output COUT
    );

  //
  // Sum function is the XOR A, B and carry in.
  //
  // Note: This is not a 3 input XOR, but the result the XOR
  //       of the XOR *output* of (A ^ B) with CIN or
  //       assign S = (A ^ B) ^ CIN;
  //
  // See page 129 for gate level circuit diagram.
  //
  assign S = A ^ B ^ CIN;

  // Compute carry output as sum of products.
  assign COUT = ((A & B) | (A & CIN) | (B & CIN));

endmodule // Gigatron_FullAdder

//
// The Gigatron Bus Access Decoder handles the bus control
// signals.
//
// It's fully asynchronous and slaved to the clocks
// of the containing Gigatron_CPU.
//
// As such it only uses combinatorial logic.
//
// Truth Table for Bus Decoder:
//
// input signal busmode
//
// output signals:
//  D = enable_data (DE_N) DE_N connected to tri-state buffer for D => BUS (3/8)
//  R = enable_ram  (OE_N) OE_N connected to RAM OE_N (5/8)
//  A = enable_ac   (AE_N) controls tri-state buffer for output of AC => BUS (7/8)
//  I = enable_input_port (IE_N) (8/8)
//
//   busmode      output signals
// [1:1] [0:0]  | D R A I
// ------------------------
//    0     0   | 1 0 0 0
//    0     1   | 0 1 0 0
//    1     0   | 0 0 1 0
//    1     1   | 0 0 0 1
//
module Gigatron_Bus_Access_Decoder
(
    input [1:0] busmode,
    output de_n,
    output oe_n,
    output ae_n,
    output ie_n
);

  // This is purely symbolic and gives meaning to the busmode input signals.
  parameter[1:0]
    BUS_MODE_DATA = 2'b00,
    BUS_MODE_RAM  = 2'b01,
    BUS_MODE_AC   = 2'b10,
    BUS_MODE_IN   = 2'b11;

  //
  // Continuous assigns must be used since we are driving
  // output signals as pure wires, not register. This allows the
  // calculations to occur within the same clock cycle of this
  // modules containing clocked RTL always block.
  //
  // The always@* block allows combinatorial logic, but fails
  // to compile unless the output is register. Since we want
  // to avoid register, this syntax is not used.
  //

  //
  // To express a series of continuous assigns, start with
  // a truth table for the function/module/component.
  //
  // See truth table in the module specification header above.
  //

  //
  // Then define a continuous assign statement for each
  // output signal. This statement has an AND (&) block for
  // each row in which the output is true. If there are multiple
  // rows in which the output is true, connect them with OR (|)
  // statements.
  //

  //
  // 74HCT139 inverting 2:4 mux
  //
  assign de_n = ~(~busmode[1:1] & ~busmode[0:0]);
  assign oe_n = ~(~busmode[1:1] & busmode[0:0]);
  assign ae_n = ~(busmode[1:1]  & ~busmode[0:0]);
  assign ie_n = ~(busmode[1:1]  & busmode[0:0]);

endmodule // Gigatron_Bus_Access_Decoder

//
// The Gigatron address mode decoder handles the signals
// to enable the various address modes.
//
// It's fully asynchronous and slaved to the clocks
// of the container Gigatron_CPU.
//
// As such it only uses combinatorial logic.
//
module Gigatron_Address_Mode_Decoder
(
    input [2:0] address_mode,
    input j_n,
    output xl_n,
    output yl_n,
    output ix,
    output eh,
    output el,
    output u16b_4,
    output u16c_9
);

  // This is purely symbolic and gives meaning to the busmode input signals.
  parameter[2:0]
    AMODE_0D_TO_AC  = 3'b000,
    AMODE_0X_TO_AC  = 3'b001,
    AMODE_YD_TO_AC  = 3'b010,
    AMODE_YX_TO_AC  = 3'b011,
    AMODE_0D_TO_X   = 3'b100,
    AMODE_0D_TO_Y   = 3'b101,
    AMODE_0D_TO_OUT = 3'b110,
    AMODE_YX_INCR_TO_OUT = 3'b111;

  //
  // Continuous assigns must be used since we are driving
  // output signals as pure wires, not register. This allows the
  // calculations to occur within the same clock cycle of this
  // modules containing clocked RTL always block.
  //
  // The always@* block allows combinatorial logic, but fails
  // to compile unless the output is register. Since we want
  // to avoid register, this syntax is not used.
  //

  //
  // Symbols for address decode signal names:
  //
  // 0 - Zero's generated. When present high address bits are zero. [15:8].
  //
  // d - D, or Data register. Value from instructions required 1 byte parameter.
  //
  // ac - accumulator register
  //
  // x - x register, forms lower bits of an address. [7:0]
  //
  // y - y register, forms higher bits of an address. [15:8]
  //
  // out - output I/O port.
  //
  // Truth Table for Address mode decoder:
  //
  // input signal address_mode
  //
  // The mode decoder is disabled by the instruction decoders output for bcc
  // (j_n) asserted when a bcc instruction is being executed. This blocks writes
  // to registers as a result of bcc since its re-using address modes.
  //

  wire enable_0d_to_ac_n;
  wire enable_0x_to_ac_n;
  wire enable_yd_to_ac_n;
  wire enable_yx_to_ac_n;
  wire enable_0d_to_x_n;
  wire enable_0d_to_y_n;
  wire enable_0d_to_out_n;
  wire enable_yx_incr_to_out_n;

  //
  // Truth table for the basic address mode 3:8 inverting decoder:
  // 74HCT138
  //
  // Note: j_n is a master gate that when low (jump) disables
  // the output of this truth table. It is the G1 (high enable)
  // intput. Disabled outputs are high, since this is an active low decoder.
  //
  // output signals (inverted):
  //
  //  A = enable_0d_to_ac_n
  //  B = enable_0x_to_ac_n
  //  C = enable_yd_to_ac_n
  //  D = enable_yx_to_ac_n
  //  E = enable_0d_to_x_n
  //  F = enable_0d_to_y_n
  //  G = enable_0d_to_out_n
  //  H = enable_yx_incr_to_out_n
  //
  //    address_mode      output signals
  // [2:2] [1:1] [0:0]  | A B C D E F G H
  // ------------------------
  //     0    0     0   | 0 1 1 1 1 1 1 1
  //     0    0     1   | 1 0 1 1 1 1 1 1
  //     0    1     0   | 1 1 0 1 1 1 1 1
  //     0    1     1   | 1 1 1 0 1 1 1 1
  //     1    0     0   | 1 1 1 1 0 1 1 1
  //     1    0     1   | 1 1 1 1 1 0 1 1
  //     1    1     0   | 1 1 1 1 1 1 0 1
  //     1    1     1   | 1 1 1 1 1 1 1 0
  //

  //
  // j_n is the active high master enable G1 on pin 6 marked as E3 on the schematic.
  //
  assign enable_0d_to_ac_n = ~(j_n & ~address_mode[2:2] & ~address_mode[1:1] & ~address_mode[0:0]);
  assign enable_0x_to_ac_n = ~(j_n & ~address_mode[2:2] & ~address_mode[1:1] & address_mode[0:0]);
  assign enable_yd_to_ac_n = ~(j_n & ~address_mode[2:2] & address_mode[1:1]  & ~address_mode[0:0]);
  assign enable_yx_to_ac_n = ~(j_n & ~address_mode[2:2] & address_mode[1:1]  & address_mode[0:0]);
  assign enable_0d_to_x_n  = ~(j_n & address_mode[2:2]  & ~address_mode[1:1] & ~address_mode[0:0]);
  assign enable_0d_to_y_n  = ~(j_n &address_mode[2:2]  & ~address_mode[1:1] & address_mode[0:0]);
  assign enable_0d_to_out_n = ~(j_n &address_mode[2:2]  & address_mode[1:1]  & ~address_mode[0:0]);
  assign enable_yx_incr_to_out_n = ~(j_n & address_mode[2:2] & address_mode[1:1] & address_mode[0:0]);

  //
  // The basic 3:8 address mode decoder feeds a diode array that implements
  // the control signals. See the End Comments Diode Arrays at the end of
  // this file for description of how they operate.
  //
  // The truth table for this diode array is as follows:
  //
  //  A = enable_0d_to_ac_n
  //  B = enable_0x_to_ac_n
  //  C = enable_yd_to_ac_n
  //  D = enable_yx_to_ac_n
  //  E = enable_0d_to_x_n
  //  F = enable_0d_to_y_n
  //  G = enable_0d_to_out_n
  //  H = enable_yx_incr_to_out_n
  //
  //  W = u16c_9 - 74HCT32 OR gate input
  //  X = u16b_4 - 74HCT32 OR gate input
  //  Y = el     - EL signal
  //  Z = eh     - EH signal
  //
  // Note: The truth table is simplified since the
  // 3:8 decoder generating the address mode input signals
  // will only assert one signal at a time. So the full 256
  // entries do not need to be called out here.
  //
  // Note that each 0 in the output signals indicates
  // a presence of a diode on that row signal in the schematic.
  //
  //   address mode    output signals
  // A B C D E F G H | W X Y Z
  // -------------------------
  // 0 1 1 1 1 1 1 1 | 0 1 1 1   - 0d_to_ac_n
  // 1 0 1 1 1 1 1 1 | 0 1 0 1   - 0x_to_ac_n
  // 1 1 0 1 1 1 1 1 | 0 1 1 0   - yd_to_ac_n
  // 1 1 1 0 1 1 1 1 | 0 1 0 0   - yx_to_ac_n
  // 1 1 1 1 0 1 1 1 | 1 1 1 1   - 0d_to_x_n
  // 1 1 1 1 1 0 1 1 | 1 1 1 1   - 0d_to_y_n
  // 1 1 1 1 1 1 0 1 | 1 0 1 1   - 0d_to_out_n
  // 1 1 1 1 1 1 1 0 | 1 0 0 0   - yx_incr_to_out_n
  //

  //
  // Signal outputs
  //

  assign xl_n = enable_0d_to_x_n;

  assign yl_n = enable_0d_to_y_n;

  assign ix = ~enable_yx_incr_to_out_n; // inv_a_in/inv_a_out

  // W - Controls loading Accumulator
  assign u16c_9 = ~(~enable_0d_to_ac_n | ~enable_0x_to_ac_n |
                    ~enable_yd_to_ac_n | ~enable_yx_to_ac_n);

  // X - Controls loading Output register
  assign u16b_4 = ~(~enable_0d_to_out_n | ~enable_yx_incr_to_out_n);

  // Y
  assign el = ~(~enable_0x_to_ac_n | ~enable_yx_to_ac_n | ~enable_yx_incr_to_out_n);

  // Z
  assign eh = ~(~enable_yd_to_ac_n | ~enable_yx_to_ac_n | ~enable_yx_incr_to_out_n);

endmodule // Gigatron_AddressMode_Decoder

//
// Condition Decoder
//
module Gigatron_Condition_Decoder
(
    input [2:0] condition,
    input j_n,
    input ac7,
    input co,
    output inv_c_out_n
);

  //
  // 74HCT153 4:1 multiplexor
  //
  // ac7 selects S0
  // co selects S1
  // j_n is ea_n (enable output low)
  //
  // Truth Table for 4:1 mux
  //
  // If ea_n H, output is always low.
  //
  //  co ac7 | inv_c_in
  // ------------------------
  //  0  0   | ir2 condition[0:0]
  //  0  1   | ir3 condition[1:1]
  //  1  0   | ir4 condition[2:2]
  //  1  1   | 0
  //
  wire inv_c_in;

  assign inv_c_in = ((~j_n & ~co & ~ac7 & condition[0:0]) ||
                     (~j_n & ~co & ac7  & condition[1:1])  ||
                     (~j_n & co & ~ac7  & condition[2:2])  ||
                     (~j_n & co & ac7   & 1'b0));

  assign inv_c_out_n = ~inv_c_in;

endmodule // Gigatron_Condition_Decoder

//
// The Gigatron instruction decoder handles the signals
// to enable the operations for each instruction.
//
// It's fully asynchronous and slaved to the clocks
// of the container Gigatron_CPU.
//
// As such it only uses combinatorial logic.
//
// Logical per instruction truth table:
//
//  inst | AL AR3 AR2 AR1 AR0
// ---------------------------
//  ld   |  1   1   1   0   0
//  and  |  1   1   0   0   0
//  or   |  1   1   1   1   0
//  xor  |  1   0   1   1   0
//  add  |  0   1   1   0   0
//  sub  |  0   0   0   1   1
//  st_  |  0   0   0   0   0
//  bcc  |  1   0   1   0   1
//
//
module Gigatron_Instruction_Decoder
(
    input clock,
    input [2:0] instr,

    // Output control signals
    output w_n,
    output j_n,
    output we_n,
    output al,
    output ar0,
    output ar1,
    output ar2,
    output ar3
);

  // This is purely symbolic and gives meaning to the instr input signals.
  parameter[2:0]
    OPCODE_LD     = 3'b000,
    OPCODE_AND    = 3'b001,
    OPCODE_OR     = 3'b010,
    OPCODE_XOR    = 3'b011,
    OPCODE_ADD    = 3'b100,
    OPCODE_SUB    = 3'b101,
    OPCODE_ST     = 3'b110,
    OPCODE_BCC    = 3'b111;

  //
  // Continuous assigns must be used since we are driving
  // output signals as pure wires, not register. This allows the
  // calculations to occur within the same clock cycle of this
  // modules containing clocked RTL always block.
  //
  // The always@* block allows combinatorial logic, but fails
  // to compile unless the output is register. Since we want
  // to avoid register, this syntax is not used.
  //

  //
  // This implements the basic instruction decoder 3:8 mux.
  //
  // Its inverting, so output is active low.
  //
  // input signal instr
  //
  // output signals from basic instruction decoder mux:
  //
  //  A = ld_n
  //  B = and_n
  //  C = or_n
  //  D = xor_n
  //  E = add_n
  //  F = sub_n
  //  G = st_n
  //  H = bcc_n
  //
  //       instr          output signals
  // [2:2] [1:1] [0:0]  | A B C D E F G H
  // ------------------------
  //     0    0     0   | 0 1 1 1 1 1 1 1
  //     0    0     1   | 1 0 1 1 1 1 1 1
  //     0    1     0   | 1 1 0 1 1 1 1 1
  //     0    1     1   | 1 1 1 0 1 1 1 1
  //     1    0     0   | 1 1 1 1 0 1 1 1
  //     1    0     1   | 1 1 1 1 1 0 1 1
  //     1    1     0   | 1 1 1 1 1 1 0 1
  //     1    1     1   | 1 1 1 1 1 1 1 0
  //

  wire ld_n;
  wire and_n;
  wire or_n;
  wire xor_n;
  wire add_n;
  wire sub_n;
  wire st_n;
  wire bcc_n;

  assign ld_n  = ~(~instr[2:2] & ~instr[1:1] & ~instr[0:0]);
  assign and_n = ~(~instr[2:2] & ~instr[1:1] & instr[0:0]);
  assign or_n  = ~(~instr[2:2] & instr[1:1]  & ~instr[0:0]);
  assign xor_n = ~(~instr[2:2] & instr[1:1]  & instr[0:0]);
  assign add_n = ~(instr[2:2]  & ~instr[1:1] & ~instr[0:0]);
  assign sub_n = ~(instr[2:2]  & ~instr[1:1] & instr[0:0]);
  assign st_n  = ~(instr[2:2]  & instr[1:1]  & ~instr[0:0]);
  assign bcc_n = ~(instr[2:2] & instr[1:1] & instr[0:0]);
  
  //
  // The instruction decoder feeds into a set of diodes to implement
  // control logic from the core instruction decoder.
  //
  // See the End Comments at the bottom of this file for 
  // a description of how they work.
  //
  // The truth table for the instruction decoder with the
  // diodes is as follows:
  //
  //  Input signals from instruction 3:8 decoder:
  //
  //  A = ld_n
  //  B = and_n
  //  C = or_n
  //  D = xor_n
  //  E = add_n
  //  F = sub_n
  //  G = st_n
  //  H = bcc_n
  //  G = IR7 - high bit of instruction 3 bit opcode
  //
  // Output Signals
  //
  // V = AL - note this has its own truth table below
  // W = AR0
  // X = AR1
  // Y = AR2
  // Z = AR3
  //

  //
  // Truth table for the AR0 - AR3 signals
  //
  // A 0 in the output signal column indicates presence of a diode
  // between that output and row signal in the schematic on page 4/8.
  //
  //   instruction     output signals
  // A B C D E F G H | W X Y Z
  // -------------------------
  // 0 1 1 1 1 1 1 1 | 1 1 0 0   - ld_n
  // 1 0 1 1 1 1 1 1 | 1 1 1 0   - and_n
  // 1 1 0 1 1 1 1 1 | 1 0 0 0   - or_n
  // 1 1 1 0 1 1 1 1 | 1 0 0 1   - xor_n
  // 1 1 1 1 0 1 1 1 | 1 1 0 0   - add_n
  // 1 1 1 1 1 0 1 1 | 0 0 1 1   - sub_n
  // 1 1 1 1 1 1 0 1 | 1 1 1 1   - st_n
  // 1 1 1 1 1 1 1 0 | 0 1 0 1   - bcc_n
  //
  //
  // Logical per instruction truth table:
  //
  //  inst | AL AR3 AR2 AR1 AR0
  // ---------------------------
  //  ld   |  1   1   1   0   0
  //  and  |  1   1   0   0   0
  //  or   |  1   1   1   1   0
  //  xor  |  1   0   1   1   0
  //  add  |  0   1   1   0   0
  //  sub  |  0   0   0   1   1
  //  st_  |  0   0   0   0   0
  //  bcc  |  1   0   1   0   1
  //

  // Note: each instruction when present results in a 1 output.
  assign ar0 = (~sub_n | ~bcc_n); // D32, D35
  assign ar1 = (~or_n  | ~xor_n | ~sub_n);
  assign ar2 = (~ld_n  | ~or_n  | ~xor_n | ~add_n | ~bcc_n);
  assign ar3 = (~ld_n  | ~and_n | ~or_n  | ~add_n);

  //
  // Truth Table for AL signal is separate since it also
  // uses the IR7 non-inverted signal.
  //
  //   instruction     output
  // A B C D E F G H | AL
  // -------------------------
  // 0 1 1 1 1 1 1 1 | 0 - diode connected to non-inverted IR7, high bit of instr
  // 1 0 1 1 1 1 1 1 | 0 
  // 1 1 0 1 1 1 1 1 | 0
  // 1 1 1 0 1 1 1 1 | 0
  // 1 1 1 1 0 1 1 1 | 1
  // 1 1 1 1 1 0 1 1 | 1 
  // 1 1 1 1 1 1 0 1 | 1 
  // 1 1 1 1 1 1 1 0 | 0 - diode on bcc signal
  //

  //
  // There are (4) grayed out diodes on schematic page 4/8 Control Unit
  // maked II. These are present for LD, AND, OR, XOR. It appears
  // these are alternatives to diode D21 which connects to IR7 and in effect
  // replaces these (4) diodes in ensuring al is generated when IR7 == 0.
  //

  assign al = (~instr[2:2] | ~bcc_n); // D21, D34

  //
  // w_n - write when low
  //
  assign w_n = st_n;

  //
  // j_n - jump when low
  //
  assign j_n = bcc_n;

  //
  // we_n - Memory write enable when low.
  //
  // Conditioned by the OR gate U16A.
  //
  assign we_n = st_n | clock;

endmodule // Gigatron_Instruction_Decoder

//
// Jump Detector
//
module Gigatron_Jump_Detector
(
    input [2:0] condition,
    input j_n,
    input inv_c_out_n,
    output pl_n,
    output ph_n
);

    wire bf_n;

    //
    // 74HCT139 inverting 2:4 line decoder
    //

    assign bf_n = ~(~condition[2:2] & ~condition[1:1] & ~condition[0:0]);

    assign ph_n = (bf_n | j_n);

    //
    // Two diodes and 2.2k pull up resistor create a wired AND
    // of ph_n & inv_c_out.
    //
    // A == inv_c_out
    // B == ph_n
    //
    // A B | pl_n
    // ----------
    // 0 0 | 0
    // 0 1 | 0
    // 1 0 | 0
    // 1 1 | 1
    //

    assign pl_n = ph_n & inv_c_out_n; // uses a diode and

endmodule // Gigatron_Jump_Detector

//
// The Gigatron RAM is a 32K by 8 RAM.
//
// Note that the Gigatron accesses the RAM synchronous with its
// 6.25Mhz clock cycle.
//
// The Altera IP block RAM uses a clock, so we use the 50Mhz FPGA
// clock which will have time to access the data needed for
// the gigatron.
//
// TODO: May have to use registers to ensure setup + hold times
// due to large combinatorial logic blocks from the Gigatron, and
// its 6.25Mhz clock domain.
//
module Gigatron_RAM_Wrapper
(
    input clock,
    input [14:0] address,
    inout [7:0] data,
    input cs,
    input oe,
    input write
);

  //
  // Use Altera RAM IP block since use registers is being overloaded
  // resulting in compilation failures.
  //

  wire [7:0] read_data;

  // Handle input/output/tristate on data out
  assign data = (cs && oe && !write) ? read_data : 8'bz;

  gigatron_ram	gigatron_ram_inst (
	.address (address),
	.clock (clock),
	.data (data),  // RAM write data
	.wren (write),
	.q (read_data) // RAM read data
	);

`ifdef broken_overloads_registers

  reg [7:0] reg_data_out;

  // The memory is 32k x 8
  //  width     depth
  reg [7:0] mem [0:32767];

  //
  // This is to allow the testbench/ModelSim to see initialized
  // memory. It will model a read of an uninitialized state as an
  // unknown and track it throughout the design. This ends up turning
  // an early uninitialized RAM read in the Gigatron EEPROM into a whole
  // series of unknowns throughout the Gigatron registers, etc, and
  // the whole simulation falls apart at that point since none of
  // the further instructions logical instructions have any valid
  // results. Example: Read uninitialized memory location $00 into
  // ACC, and now ACC becomes unknown. As this value is placed on
  // the bus, input to ALU operations and stored in other registers
  // you end up with an increasing number of signals that are now
  // "unknown" in the simulation. They are marked as red in ModelSim
  // as opposed to blue which is Verilog logic asserted tri-state.
  //
  // It appears the uninitialized memory read is on purpose to
  // get "entropy" from the RAM.
  //
  // The file here is all 00's in order to not have entropy, but
  // reproducable simulations.
  //
  // TODO: Using the Altera IP RAM block allows it to automatically clear it.
  //
  initial begin
    $readmemh("C:/Dropbox/embedded/altera/workspace/menlo_gigatron_de10_nano/RAMv1_verilog_data.txt", mem);
  end

  // Handle input/output/tristate on data out
  assign data = (cs && oe && !write) ? reg_data_out : 8'bz;

  //
  // Memory write process
  //

  always @ (address or data or cs or write) begin
    if (cs && write) begin
      mem[address] = data;
    end
  end // always write

  //
  // Memory read process
  //
  // Note the sensitivity list includes write since the
  // evaluation must be done when write transitions so that
  // read does not interface with writes.
  //

  always @ (address or cs or write or oe) begin

    if (cs && !write && oe) begin
      reg_data_out = mem[address];
    end
    else begin
      reg_data_out = 8'h00;
    end

  end // always read

`endif // broken_overloads_registers

endmodule

//
// Test benches
//
// The following test benches are great not just for validating
// components but for exploring the design. It allows you to update
// the test bench to exercise a specific component and see its exact
// behavior, before and after any modifications.
//

`define tb_gigatron_assert(signal, value) \
    if (signal !== value) begin \
	     $display("ASSERTION FAILED in %m: signal != value"); \
		  $stop; \
    end

module tb_gigatron();

  // FPGA clock
  reg clock_50;

  // VGA clock
  reg clock_25;

  // Gigatron clock
  reg clock_6_25;

  reg reset;
  reg run;

  reg [7:0] gigatron_input_port;

  wire [7:0] gigatron_output_port;
  wire [7:0] gigatron_extended_output_port;

  // VGA signals
  wire hsync_n;
  wire vsync_n;
  wire [1:0] red;
  wire [1:0] green;
  wire [1:0] blue;

  // 000 0000 0000 0000 0000
  // 001 1111 1111 1111 1111 == 0x1FFFF // 128K 512x256
  // 01 1111 1111 1111 1111 == 0x3FFFF // 256K 512x512
  // 100 1010 1111 1111 1111 == 0x4AFFF // 307,199 640x480
  parameter framebuffer_max_addr = 19'h4AFFF;

  // Output from Gigatron to external VGA framebuffer
  wire        framebuffer_write_clock;
  wire        framebuffer_write_signal;
  wire [18:0] framebuffer_write_address;
  wire [7:0]  framebuffer_write_data;

  // BlinkenLights
  wire led5;
  wire led6;
  wire led7;
  wire led8;

  // Audio output DAC
  wire [3:0] audio_dac;

  // Serial game controller
  wire ser_pulse;
  wire ser_latch;
  reg ser_data;

  // Test variables
  reg [31:0] reg_vsync_count;
  reg reg_test_stop_signal;
  reg reg_vsync_trigger_suppress;
  reg [18:0] framebuffer_read_address;

  // File I/O
  integer fd;
  integer index;
  reg [7:0] red_8bpp;
  reg [7:0] green_8bpp;
  reg [7:0] blue_8bpp;

  // 640 x 480 x 8 Framebuffer Model
  reg [7:0] framebuffer [0:307199]; // 19 bit address, 8 bit data
  reg [7:0] value;

  // Device Under Test instance
  Gigatron DUT(
    .fpga_clock(clock_50),
    .vga_clock(clock_25),
    .clock(clock_6_25),
    .reset(reset),
    .run(run),
    .gigatron_input_port(gigatron_input_port),
    .gigatron_output_port(gigatron_output_port),
    .gigatron_extended_output_port(gigatron_extended_output_port),

    // Raw VGA signals from the Gigatron
    .hsync_n(hsync_n),
    .vsync_n(vsync_n),
    .red(red),
    .green(green),
    .blue(blue),

    // Write output to external framebuffer
    .framebuffer_write_clock(framebuffer_write_clock),
    .framebuffer_write_signal(framebuffer_write_signal),
    .framebuffer_write_address(framebuffer_write_address),
    .framebuffer_write_data(framebuffer_write_data),

    // BlinkenLights
    .led5(led5),
    .led6(led6),
    .led7(led7),
    .led8(led8),

    // 4 bit Audio DAC
    .audio_dac(audio_dac), // extended_output_port bits 7-4

    // Serial game controller
    .ser_pulse(ser_pulse),
    .ser_latch(ser_latch),
    .ser_data(ser_data)
  );

  // Set initial values
  initial begin
     clock_50 = 0;
     clock_25 = 0;
     clock_6_25 = 0;
     reset = 1;
     run = 0;
     gigatron_input_port = 0;
     ser_data = 0;

     reg_vsync_count = 0;
     reg_test_stop_signal = 0;

     fd = 0;
     index = 0;
     reg_vsync_trigger_suppress = 0;
     framebuffer_read_address = 0;
  end

  //
  // Setup FPGA 50Mhz clock
  //
  // 50mhz == 20ns period.
  // #10 delay is 1/2 of the cycle.
  //
  always #10 clock_50 = ~clock_50;

  //
  // Setup 25Mhz VGA clock
  //
  always #20 clock_25 = ~clock_25;

  //
  // Setup 6.25Mhz Gigatron clock at 1ns resolution in simulation.
  //
  // #xx - delay in nanoseconds
  //
  // 6.25mhz == 160ns per cycle.
  //
  // so #80 delay is 1/2 of the cycle.
  //

  always #80 clock_6_25 = ~clock_6_25;

  //
  // VGA framebuffer model
  //
  always @(posedge framebuffer_write_clock) begin

    //
    // Handle framebuffer writes
    //
    if (framebuffer_write_signal == 1'b1) begin
        framebuffer[framebuffer_write_address] <= framebuffer_write_data;
    end

    //
    // Let the Gigatron run.
    //
    // Stop ModelSim manually and look at the traces to see how
    // instruction execution has proceeded.
    //

    if (vsync_n == 1'b0) begin

        if (reg_vsync_trigger_suppress == 1'b0) begin

          // 1 second of VSYNC's at 60 per second to examine framebuffer
          //if (reg_vsync_count >= 32'd60) begin

          // 10 seconds of VSYNC's at 60 per second to examine framebuffer
          //if (reg_vsync_count >= 32'd600) begin

          // 20 seconds of VSYNC's at 60 per second to examine framebuffer
          //if (reg_vsync_count >= 32'd1200) begin

          // 1 second of VSYNC's at 60 per second to examine framebuffer
          if (reg_vsync_count >= 32'd60) begin
            reg_test_stop_signal <= 1;
          end
          else begin
            reg_vsync_count <= reg_vsync_count + 1;
          end
        end

        // Suppress new trigger till transition
        reg_vsync_trigger_suppress <= 1;

    end
    else begin
        // vsync went low, so we can clear the trigger suppress.
        reg_vsync_trigger_suppress <= 0;
    end

    //
    // Stop at first HSYNC_N going high for testing
    //if (gigatron_output_port[6:6] == 1'b1) begin
    //  $stop;
    //end

  end

  // Stimulus to step through values
  initial begin

    // Set Reset
    reset = 1'b1;

    // Wait some Gigatron clock cycles
    @(posedge clock_6_25);
    @(posedge clock_6_25);
    @(posedge clock_6_25);
    @(posedge clock_6_25);

    // Remove reset
    reset = 1'b0;

    // Wait some Gigatron clock cycles
    @(posedge clock_6_25);
    @(posedge clock_6_25);
    @(posedge clock_6_25);
    @(posedge clock_6_25);
     
    // Set run, she is off and running...
    run = 1'b1;
    @(posedge clock_6_25);
    @(posedge clock_6_25);

    // Wait till test_stop_signal
    @(posedge reg_test_stop_signal);

    //
    // Write out framebuffer to file.
    //
    // We create a standard 8 bit per pixel RGB RAW
    // file which is used by many graphics conversion programs.
    //
    // The output from the Gigatron is an 8 bit true color output
    // with 3 bits red, 3 bits green, 2 bits blue. The Gigatron's
    // 2 bits for each color are in the higher order of the brighness
    // bits.
    //
    fd = $fopen("C:\\tmp\\gigatron_framebuffer.rgb", "w");

    framebuffer_read_address = 0;

    for (index = 0; index < framebuffer_max_addr; index++) begin

      value = framebuffer[framebuffer_read_address];
      
      //
      // Construct a 24 bit R, G, B color from the 8 bit true color
      // output by the Gigatron VGA handler.
      //

      red_8bpp[7:5] = value[7:5];
      red_8bpp[4:0] = 5'b00000;

      green_8bpp[7:5] = value[4:2];
      green_8bpp[4:0] = 5'b00000;

      blue_8bpp[7:6] = value[1:0];
      blue_8bpp[5:0] = 6'b000000;

      //
      // %c is directly as character, which is actually
      // binary without expansion. %b which means binary
      // actually outputs the ASCII for a binary value as
      // series of ASCII 0's and 1's.
      //
      $fwrite(fd, "%c", red_8bpp);
      $fwrite(fd, "%c", green_8bpp);
      $fwrite(fd, "%c", blue_8bpp);

      framebuffer_read_address = framebuffer_read_address + 1;

      // Test breakpoint
      //$stop;
      //@(posedge clock_50);
      //@(posedge clock_50);

    end

    $fclose(fd);

    // Wait two clocks before ending
    @(posedge clock_6_25);
    @(posedge clock_6_25);
    $stop;

  end

endmodule

module tb_gigatron_ram();

  reg clock_50;

  reg [14:0] address;
  reg cs;
  reg oe;
  reg write;
  reg [7:0] reg_data;
  integer i;

  // This is an in/out port controlled by the write, oe, cs signals.
  wire [7:0] data;

  // Device Under Test instance
  Gigatron_RAM DUT(
    .address(address),
    .data(data),
    .cs(cs),
    .oe(oe),
    .write(write)
  );

  // Set initial values
  initial begin
     clock_50 = 0;
     address = 0;
     cs = 0;
     oe = 0;
     write = 0;
     reg_data = 0;
  end

  //
  // We can't assign to data directly since its just a set of
  // wires to the bi-directional port of the RAM.
  //
  // This logic ensures we drive the data wires when
  // write == TRUE, but leave the signals here undriven
  // as hi-Z when not write, which allows the RAM to drive
  // the wires as input to this module for a read.
  //
  assign data = (write) ? reg_data : 8'bz;

  //
  // Setup 50Mhz clock at 1ns resolution.
  //
  // 50mhz == 20ns period.
  // #10 delay is 1/2 of the cycle.
  //
  always #10 clock_50 = ~clock_50;

  // Stimulus to step through values
  initial begin

     cs = 1;
     oe = 1;
     @(posedge clock_50);

     $display("ram test write data:");

     for (i = 0; i < 32768; i = i + 1) begin

       address = i;
       write = 1;
       reg_data = i;
       @(posedge clock_50);

       write = 0;
       @(posedge clock_50);

     end

     $display("ram test read data:");

     for (i = 0; i < 16; i = i + 1) begin

       address = i;
       @(posedge clock_50);

       $display("%d:%h", i, data);

     end

     for (i = 32768 - 16; i < 32768; i = i + 1) begin

       address = i;
       @(posedge clock_50);

       $display("%d:%h", i, data);

     end

     @(posedge clock_50);
     @(posedge clock_50);

     $stop;

  end

endmodule // tb_gigatron_ram()

//
// Test the bus decoder.
//

`define tb_gigatron_bus_decoder_assert(signal, value) \
    if (signal !== value) begin \
	     $display("ASSERTION FAILED in %m: signal != value"); \
		  $stop; \
    end

module tb_gigatron_bus_decoder();

  reg clock_50;

  reg [1:0] busmode;

  wire enable_data;
  wire enable_ram;
  wire enable_ac;
  wire enable_input_port;

  // Device Under Test instance
  Gigatron_Bus_Decoder DUT(
    .busmode(busmode),
    .enable_data(enable_data),
    .enable_ram(enable_ram),
    .enable_ac(enable_ac),
    .enable_input_port(enable_input_port)
  );

  // Set initial values
  initial begin
     clock_50 = 0;
     busmode = 0;
  end

  //
  // Setup 50Mhz clock at 1ns resolution.
  //
  // 50mhz == 20ns period.
  // #10 delay is 1/2 of the cycle.
  //
  always #10 clock_50 = ~clock_50;

  // Stimulus to step through values
  initial begin

     busmode = 2'b00;
     @(posedge clock_50);
     tb_gigatron_bus_decoder_assert_output_values(4'b0001);

     busmode = 2'b01;
     @(posedge clock_50);
     tb_gigatron_bus_decoder_assert_output_values(4'b0010);

     busmode = 2'b10;
     @(posedge clock_50);
     tb_gigatron_bus_decoder_assert_output_values(4'b0100);

     busmode = 2'b11;
     @(posedge clock_50);
     tb_gigatron_bus_decoder_assert_output_values(4'b1000);

     @(posedge clock_50);
     @(posedge clock_50);

     $stop;

  end

//
// Task to assert output values
//
task tb_gigatron_bus_decoder_assert_output_values;
  input [3:0] values_to_assert;

  begin

    //
    // Note this task can see the signals (local variables) of the module
    // its included in.
    //
    // Note: Task must be within the module by being before its
    // endmodule statement.
    //

    `tb_gigatron_bus_decoder_assert(enable_data, values_to_assert[0:0])
    `tb_gigatron_bus_decoder_assert(enable_ram,  values_to_assert[1:1])
    `tb_gigatron_bus_decoder_assert(enable_ac,   values_to_assert[2:2])
    `tb_gigatron_bus_decoder_assert(enable_input_port, values_to_assert[3:3])

  end  
endtask

endmodule

  //
  // End Comments:
  //
  // These are here to not hurt clarity of the logic.
  //

  //
  // Diode Arrays:
  //
  // This is a description of the operation of the two diode arrays
  // used for the mode and instruction decoder control logic. They are
  // described by the Gigatron authors as a type of PROM. It's another
  // example of going back to 1970's (actually 1960's) digital logic
  // design in which diode-transistor (DTL) logic was common due to the
  // compact, inexpensive parts before TTL MOS integrated circuits
  // became common. This was used in many phone switches, and even in
  // "boot cards" for mini-computers in which a boot program was encoded
  // with diodes and wires on a printed circuit card that is inserted into
  // the computer to boot. For example such a card would have enough
  // instructions to load from a paper tape reader a larger "loader"
  // program.
  //
  // Input signals to the diode array are active low coming out of the
  // 74HCT138 decoder IC.
  //
  // The output lines are pulled up by 2.2k resistors which keeps them
  // high by default, unless actively driven low.
  //
  // Each output signal is connected to the anodes of one or more diodes.
  //
  // Each diode connects its cathode to an input signal line. When that
  // line is driven low (signaled active low) the diode conducts and
  // pulls the line down, and the output is now at the diodes forward
  // bias value of 0.4-0.7v.
  //
  // The diodes prevent reverse current flow, thus allowing a given output
  // line to be connected to multiple input lines without interference since
  // they appear as back to back diodes between the input signal lines which
  // have a very high impedance.
  //
  // Since multiple diodes may be connected to an output line with
  // each diode connecting to a unique input line, a negated input OR function
  // with an active low output is created.
  //
  // Using Boolean logic this creates an AND gate.
  //
  // Here is the truth table looking at the input signals before the
  // 74HCT138 inverting decoder and the Q output line connected by a diode
  // to A, and B, while being pulled up by the 2.2k resistor.
  //
  // A B | Q
  // --------
  // 0 0 | 0
  // 0 1 | 0
  // 1 0 | 0
  // 1 1 | 1
  //


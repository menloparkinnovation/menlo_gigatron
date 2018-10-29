
//
//   Menlo Silicon Shell for DE10-Nano SoC
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

// Set this for VGA sprite support.
`define VGA_SPRITE_SUPPORT 1

// This produces a VGA test pattern instead of the applications output.
//`define VGA_TEST_PATTERN 1

  //
  // Layout of a board specific shell is as follows:
  //
  // Top level I/O bindings and declarations for the physical
  // resources of the board. These are the signals of the boards
  // top level module.
  //
  // Support modules for the boards resources such as clocks, reset
  // generators, VGA/HDMI, Audio, etc.
  //
  // Project specific modules and support logic. It is strongly desired that
  // this is contained in a projectname_shell.sv file and top level module
  // that is invoked by this board shell to make it easy to move a project
  // implementation from one board to another.
  //
  // This layout comes the the fact that in order to get a board
  // working you need to take one of its default projects that contains
  // the Quartus II project settings, pin resource assignments, and
  // support modules that active the hardware resources on the board.
  //
  // Your design needs to bind to these resources, and keeping this
  // as straightfoward as possible makes it easier to port the design
  // from board to board.
  //   

  //
  // Bind top level hardware resources from the board specific shell.
  //
  // Resource Map:
  //
  // Both key switches are LOW when pressed.
  //
  // KEY[0:0] is on the right. // see top of file
  // KEY[1:1] is on the left.  // see top of file
  //
  // SW[3:0] 4 bits of dip switches // used for value input.
  // SW[0:0] is the right most switch.
  // SW[3:3] is the left most switch.
  //
  //   - Up   ("1") is HIGH
  //   - Down ("0") is LOW
  //
  // LED's are laid out from bit 7 - 0, with bit 7 LED on the
  // left, and bit 0 LED on the right.
  //
  // The right most, lower bit number 4 LED's are assigned to the application.
  //  assign LED[0:0] = led0;
  //  assign LED[1:1] = led1;
  //  assign LED[2:2] = led2;
  //  assign LED[3:3] = led3;
  //
  // The left most, higher bit number 4 LED's are used for user interface for
  // settings along with the pushbuttons and switches.
  //  - see top of file for assignments.
  //

module DE10_Nano_Shell_Top (

	//////////// ADC //////////
	output		          		ADC_CONVST,
	output		          		ADC_SCK,
	output		          		ADC_SDI,
	input 		          		ADC_SDO,

	//////////// ARDUINO //////////
	inout 		    [15:0]		ARDUINO_IO,
	inout 		          		ARDUINO_RESET_N,

	//////////// CLOCK //////////
	input 		          		FPGA_CLK1_50,
	input 		          		FPGA_CLK2_50,
	input 		          		FPGA_CLK3_50,

	//////////// HDMI //////////
	inout 		          		HDMI_I2C_SCL,
	inout 		          		HDMI_I2C_SDA,
	inout 		          		HDMI_I2S,
	inout 		          		HDMI_LRCLK,
	inout 		          		HDMI_MCLK,
	inout 		          		HDMI_SCLK,
	output		          		HDMI_TX_CLK,
	output		          		HDMI_TX_DE,
	output		    [23:0]		HDMI_TX_D,
	output		          		HDMI_TX_HS,
	input 		          		HDMI_TX_INT,
	output		          		HDMI_TX_VS,

	//////////// KEY //////////
	input 		     [1:0]		KEY,

	//////////// LED //////////
	output		     [7:0]		LED,

	//////////// SW //////////
	input 		     [3:0]		SW,

	//////////// PLL clocks //////////
        input                                   application_clock, // 6.25Mhz
        input                                   vga_clock,         // 25Mhz
        input                                   audio_clock        // I2S 1.536 Mhz
);

  // Unused. Set to known value to prevent warnings.
  assign ADC_CONVST = 1'b0;
  assign ADC_SCK = 1'b0;
  assign ADC_SDI = 1'b0;
   
  //
  // Bottom 4 LED's used by the application.
  //
  wire [3:0] application_leds;
  assign LED[3:0] = application_leds;

  //
  // Top 4 LED's used by the shell user interface.
  //
  wire led4;
  wire led5;
  wire led6;
  wire led7;
   
  assign LED[4:4] = led4;
  assign LED[5:5] = led5;
  assign LED[6:6] = led6;
  assign LED[7:7] = led7;

  //
  // inout [15:0] ARDUINO_IO
  //
  // Note that the application shell needs to assign any ports
  // used as input to hi-z.
  //
  // This is required to input on the port without conflict since
  // the FPGA Arduino ports have been configured for bi-directional
  // operation, similar to an Arduino's native ports.
  //
  // Example:
  //
  // assign ARDUINO_IO[2:2] = 1'bz;
  //

  //
  // Project variables needed to bind to support modules so they need
  // to be declared up top.
  //

  // Audio test setting
  reg 	      hdmi_audio_test;

  // Application audio output DAC
  wire [15:0]  application_audio_output_dac;

  //
  // FPGA Clock and reset generation.
  //

  wire clock;
  assign clock = FPGA_CLK1_50;

  wire reset_n; // active low reset
  wire reset;   // active high reset

  // inverted reset for active high
  assign reset = ~reset_n;

  //
  // Reset Generator.
  //
  Reset_Delay reset_generator(
    .iCLK(FPGA_CLK1_50),
    .oRESET(reset_n) // output
    );

  //
  // HDMI I2C	
  //
  I2C_HDMI_Config u_I2C_HDMI_Config (
    .iCLK(FPGA_CLK1_50),
    .iRST_N(reset_n),
    .I2C_SCLK(HDMI_I2C_SCL),
    .I2C_SDAT(HDMI_I2C_SDA),
    .HDMI_TX_INT(HDMI_TX_INT)
  );
   
  //
  // VGA controller implements a 640x480 8 bit true color dual ported frame buffer.
  //
  // It can optionally implement a customized palette as well.
  //

  //
  // VGA Frame buffer write variables
  //
  wire        vga_write_clock;
  wire        vga_write_signal;
  wire [18:0] vga_write_address;
  wire  [7:0] vga_write_data;

  // hdmi support
  wire [7:0] hdmi_b;
  wire [7:0] hdmi_g;
  wire [7:0] hdmi_r;
  wire       disp_de;
  wire       disp_hs;
  wire       disp_vs;

  // These are the output generated signals to the HDMI display driver chip.
  assign HDMI_TX_CLK	= vga_clock;
  assign HDMI_TX_D	= {hdmi_r,hdmi_g,hdmi_b};
  assign HDMI_TX_DE	= disp_de;
  assign HDMI_TX_HS	= disp_hs;
  assign HDMI_TX_VS	= disp_vs;
	
`ifdef VGA_SPRITE_SUPPORT

  // Sprite parameters
  wire        sprite_active;
  wire [9:0]  sprite_x_position;
  wire [8:0]  sprite_y_position;
  wire [9:0]  sprite_x_size;
  wire [8:0]  sprite_y_size;

  //
  // Sprite memory.
  // These signals are used to read the sprite memory.
  //
  wire        sprite_read_clock;
  wire        sprite_read_signal;
  wire [18:0] sprite_read_address;
  wire [7:0]  sprite_read_data;

  //
  // Sprite Controller/Buffer
  //

  // Set by UI handler from KEY[0:0] (volume control)
  wire       activate_sprite;

  Sprite_Buffer sprite (
    .fpga_clock(FPGA_CLK1_50),
    .reset(reset),

    .activate_sprite(activate_sprite),

    .sprite_active(sprite_active),
    .sprite_x_position(sprite_x_position),
    .sprite_y_position(sprite_y_position),
    .sprite_x_size(sprite_x_size),
    .sprite_y_size(sprite_y_size),

    .sprite_read_clock(sprite_read_clock),
    .sprite_read_signal(sprite_read_signal),
    .sprite_read_address(sprite_read_address),
    .sprite_read_data(sprite_read_data)
  );

  Vga_Controller_With_Sprite hdmi_ins(
    .iRST_n(reset_n),
    .iVGA_CLK(vga_clock),
    .fpga_clock(FPGA_CLK1_50),
    .oBLANK_n(disp_de),
    .oHS(disp_hs),
    .oVS(disp_vs),
    .b_data(hdmi_b),
    .g_data(hdmi_g),
    .r_data(hdmi_r),
    .input_framebuffer_write_clock(vga_write_clock),
    .input_framebuffer_write_signal(vga_write_signal),
    .input_framebuffer_write_address(vga_write_address),
    .input_framebuffer_write_data(vga_write_data),

    // Sprite parameters
    .input_sprite_active(sprite_active),
    .input_sprite_x_position(sprite_x_position),
    .input_sprite_y_position(sprite_y_position),
    .input_sprite_x_size(sprite_x_size),
    .input_sprite_y_size(sprite_y_size),

    //
    // Sprite memory.
    // These signals are used to read the sprite memory.
    //
    .output_sprite_read_clock(sprite_read_clock),
    .output_sprite_read_signal(sprite_read_signal),
    .output_sprite_read_address(sprite_read_address),
    .input_sprite_read_data(sprite_read_data)
    );	

`else

  vga_controller hdmi_ins(
    .iRST_n(reset_n),
    .iVGA_CLK(vga_clock),
    .fpga_clock(FPGA_CLK1_50),
    .oBLANK_n(disp_de),
    .oHS(disp_hs),
    .oVS(disp_vs),
    .b_data(hdmi_b),
    .g_data(hdmi_g),
    .r_data(hdmi_r),
    .input_framebuffer_write_clock(vga_write_clock),
    .input_framebuffer_write_signal(vga_write_signal),
    .input_framebuffer_write_address(vga_write_address),
    .input_framebuffer_write_data(vga_write_data)
    );	
							 
`endif

  //
  // HDMI I2S audio support.
  //

  menlo_hdmi_audio hdmi_audio(
	.reset_n(reset_n),         // input
	.sclk(HDMI_SCLK),          // output to HDMI (passed through from .clk)
	.lrclk(HDMI_LRCLK),        // output to HDMI
	.i2s(HDMI_I2S),            // output [3:0] four serialized HDMI I2S audio channels
	.clk(audio_clock),         // input
        .audio_in(application_audio_output_dac), // input audio DAC audio signal
        .audio_test(hdmi_audio_test) // input, true if use internal test sample.
  );
	
  // Application shell VGA output signals
  wire application_framebuffer_write_clock;
  wire application_framebuffer_write_signal;
  wire [18:0] application_framebuffer_write_address;
  wire [7:0] application_framebuffer_write_data;

`ifdef VGA_TEST_PATTERN

  //
  // This allows the replacement application of the applications framebuffer
  // signals with a test pattern for validating VGA/HDMI.
  //

  //
  // Create a VGA color test pattern sequencing through the
  // 8 bit true color palette.
  //
  vga_test_pattern_generator test_pattern(
    .vga_clock(vga_clock), // 25Mhz VGA display clock
    .fpga_clock(FPGA_CLK1_50),
    .application_clock(application_clock), // application Clock from the PLL
    .reset_n(reset_n),    // Active low reset
    .write_clock(vga_write_clock),
    .write_signal(vga_write_signal),
    .write_address(vga_write_address),
    .write_data(vga_write_data)
  );

`else

  assign vga_write_clock = application_framebuffer_write_clock;
  assign vga_write_signal = application_framebuffer_write_signal;
  assign vga_write_address = application_framebuffer_write_address;
  assign vga_write_data = application_framebuffer_write_data;

`endif // VGA_TEST_PATTERN

  //
  // User interface process
  //
  // Allows selection of audio level, or application module
  // input selection.
  //

  //
  // Audio digital volume control support
  //
  // Our volume controls go to 11 ...
  //
  // https://en.wikipedia.org/wiki/Spinal_Tap_(band)
  // https://www.youtube.com/watch?v=KOO5S4vxi0o
  //
  wire [3:0]  digital_volume_control;

  // Application go button
  wire 	      application_go;

  // Application select
  wire [3:0]   application_select;

  // output from the application.
  wire        application_active;

  // Output from LED Flasher
  wire        led_flasher_output_application_active;

  // LED5 flashing indicates the application is active
  assign led5 = led_flasher_output_application_active;

  //
  // application_active signal from is gated by flasher so it
  // flahses the LED 5 when running.
  //
  LED_Flasher loader_active_flasher(
    .clock(clock),
    .reset(reset),
    .counter(32'h00FFFFFF),
    .led_state(application_active), // input
    .led(led_flasher_output_application_active) // output
  );

  Application_UI application_ui (
    .clock(clock),
    .reset_n(reset_n),
    .KEY(KEY),
    .SW(SW),
    .led4(led4),
    .led6(led6),
    .led7(led7),
    .digital_volume_control(digital_volume_control),
    .application_go(application_go),
    .application_select(application_select),
    .activate_sprite(activate_sprite)
  );

  //
  // Application project invoked from the board shell.
  //

  Application_Shell application_shell(
    .fpga_clock(FPGA_CLK1_50), // 50Mhz FPGA clock
    .vga_clock(vga_clock),      // 25Mhz VGA clock from the PLL
    .application_clock(application_clock), // application clock from the PLL
    .reset(reset),

    //
    // Write output to external framebuffer
    //
    // Note: application outputs its 6.25Mhz clock as the clock
    // to synchronize these signals.
    //
    // The output is standard 8 bit true color with RRRGGGBB.
    //
    // https://en.wikipedia.org/wiki/8-bit_color
    //
    .framebuffer_write_clock(application_framebuffer_write_clock),
    .framebuffer_write_signal(application_framebuffer_write_signal),
    .framebuffer_write_address(application_framebuffer_write_address),
    .framebuffer_write_data(application_framebuffer_write_data),

    // 16 bit LPCM audio output from the application.
    .audio_dac(application_audio_output_dac),

    // Digital volume control with range 0 - 11.
    .digital_volume_control(digital_volume_control),

    // Signals from user interface to select program to load
    .application_go(application_go),  // input, true when user select load
    .application_active(application_active), // output

    // Switches
    .switches(application_select),

    // LED's
    .leds(application_leds),

    // I/O Port signals
    .arduino_io(ARDUINO_IO),
    .arduino_reset_n(ARDUINO_RESET_N)
  );

endmodule // de10_nano_shell_top.sv

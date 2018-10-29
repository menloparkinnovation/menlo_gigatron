
//
// Gigatron Application Shell
//
// 10/28/2018
//

//
// See MENLO_COPYRIGHT.TXT for the copyright notice for this file.
//
// Use of this file is not allowed without the copyright notice present
// and re-distributed along with these files.
//

// set timescale for 1ns with 100ps precision.
`timescale 1ns / 100ps

module Application_Shell (

    // FPGA 50Mhz clock
    input       fpga_clock,

    // VGA 25Mhz clock
    input       vga_clock,

    // 6.25 Mhz Application clock
    // Note: Adjust project PLL(s) to suit your application.
    input       application_clock,

    // Reset when == 1
    input reset,

    //
    // Write output to external framebuffer
    //
    // Allows application to display on the screen with simple
    // framebuffer memory writes.
    //
    output        framebuffer_write_clock,
    output        framebuffer_write_signal,
    output [18:0] framebuffer_write_address,
    output  [7:0] framebuffer_write_data,

    // 16 bit LPCM audio output from the Gigatron.
    output [15:0] audio_dac,

    // Digital volume control with range 0 - 11.
    input [3:0] digital_volume_control,

    // Signals from push button/switch user interface to control application.
    input application_go,      // true when user pushes application go button
    output application_active, // true when application is active

    // Switches
    input [3:0] switches,

    // LED's
    output [3:0]  leds,

    //
    // I/O Port signals
    //
    // Arduino I/O is a popular setup.
    //
    // Some boards have an Arduino UNO header which allows
    // shields to be directly connected.
    //
    // Boards with standard GPIO pins assign 16 pins to
    // Arduino I/O compatible signals and use a breakout
    // board to connect to an Arduino compatible header.
    //
    // Even without an Arduino shield, its a popular wiring
    // convention since you can move a project between an Arduino
    // and the FPGA for testing.
    //
    inout [15:0] arduino_io,
    inout arduino_reset_n
  );

  //
  // Gigatron BlinkenLights
  //
  wire gigatron_led5;
  wire gigatron_led6;
  wire gigatron_led7;
  wire gigatron_led8;

  // The bottom 4 LED's are assigned to the BlinkenLights
  assign leds[0:0] = gigatron_led5;
  assign leds[1:1] = gigatron_led6;
  assign leds[2:2] = gigatron_led7;
  assign leds[3:3] = gigatron_led8;

  //
  // Note: to use arduino_io signals as inputs you must assign its
  // output to hi-z.
  //
  // This is required to input on the port without conflict since
  // the FPGA Arduino ports have been configured for bi-directional
  // operation, similar to an Arduino's native ports and the FPGA
  // way to dynamically configure for input it to assign hi-z to
  // its output driver.
  //
  // Arduino I/O 2 (usually an interrupt input pin) is assigned
  // to hi-z here as an example to allow its use as an input
  // such as responding to the Arduino INTR signal that comes from
  // many shields. It can be "polled" using an always@(posedge fpga_clock)
  // to operate as a true interrupt input at FPGA clock speed.
  //

  //
  // Serial game controller
  //
  wire famicom_pulse;
  wire famicom_latch;
  wire famicom_data;

  //
  // inout [15:0] ARDUINO_IO
  //
  // Handle Arduino I/O to the game port.
  //
  // ARDUINO_IO[2:2] - famicom_data  (input),  Pin 2 of the DB9, 2.2K pull up to VCC
  // ARDUINO_IO[3:3] - famicom_pulse (output), Pin 4 of the DB9, series 68 ohm
  // ARDUINO_IO[4:4] - famicom_latch (output), Pin 3 of the DB9, series 68 ohm
  //
  // VCC +5V to DB9 Pin 6, Red
  // GND     to DB9 Pin 8, Black
  //
  // ARDUINO DIO2 - DB9 Pin 2 famicom_data (input)
  // ARDUINO DIO3 - DB9 Pin 4 famicom_pulse (output)
  // ARDUINO DIO4 - DB9 Pin 3 famicom_latch (output)
  // ARDUINO 5V   - DB9 Pin 6
  // ARDUINO GND  - DB9 Pin 8
  //

  //
  // Assign ARDUINO_IO[2:2] output to hiZ as its only an input.
  // This is required to input on the port without conflict since
  // the FPGA Arduino ports have been configured for bi-directional
  // operation, similar to an Arduino's native ports.
  //
  assign arduino_io[2:2] = 1'bz;

  assign famicom_data = arduino_io[2:2]; // input signal, DB9 Pin 2, Green
  assign arduino_io[3:3] = famicom_pulse; // output signal, DB9 Pin 4, Yellow
  assign arduino_io[4:4] = famicom_latch; // output signal, DB9 Pin 3, White

  //
  // RAW VGA signals from the Gigatron
  //
  wire hsync_n;
  wire vsync_n;
  wire [1:0] red;
  wire [1:0] green;
  wire [1:0] blue;

  // Raw output port signals from the Gigatron.
  wire [7:0] gigatron_output_port;
  wire [7:0] gigatron_extended_output_port;

  Gigatron_Shell gigatron_shell(
    .fpga_clock(fpga_clock), // 50Mhz FPGA clock
    .vga_clock(vga_clock),      // 25Mhz VGA clock from the PLL
    .clock(application_clock), // 6.25Mhz Gigatron clock from the PLL
    .reset(reset),
    .run(1'b1),

    .gigatron_output_port(gigatron_output_port),
    .gigatron_extended_output_port(gigatron_extended_output_port),

    //
    // These signals are from the Famicom serial game controller.
    //
    .famicom_pulse(famicom_pulse), // output
    .famicom_latch(famicom_latch), // output
    .famicom_data(famicom_data),   // input

    // Raw VGA signals from the Gigatron
    .hsync_n(hsync_n),
    .vsync_n(vsync_n),
    .red(red),
    .green(green),
    .blue(blue),

    //
    // Write output to external framebuffer
    //
    // Note: Gigatron outputs its 6.25Mhz clock as the clock
    // to synchronize these signals.
    //
    // The output is standard 8 bit true color with RRRGGGBB.
    //
    // https://en.wikipedia.org/wiki/8-bit_color
    //
    .framebuffer_write_clock(framebuffer_write_clock),
    .framebuffer_write_signal(framebuffer_write_signal),
    .framebuffer_write_address(framebuffer_write_address),
    .framebuffer_write_data(framebuffer_write_data),

    // BlinkenLights
    .led5(gigatron_led5),
    .led6(gigatron_led6),
    .led7(gigatron_led7),
    .led8(gigatron_led8),

    // 16 bit LPCM audio output from the Gigatron.
    .audio_dac(audio_dac),

    // Digital volume control with range 0 - 11.
    .digital_volume_control(digital_volume_control),

    // Signals from user interface to select program to load
    .loader_go(application_go),  // input, true when user select load
    .loader_program_select(switches),
    .loader_active(application_active) // output
  );

endmodule

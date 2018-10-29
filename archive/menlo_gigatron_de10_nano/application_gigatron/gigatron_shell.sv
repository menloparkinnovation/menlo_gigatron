

// TODO: 10/20/2018
//
// Gigagron goes in the weeds when BabelFish is activated.
//  - led loader active flashes without going out.
//  - so the sender is not completing its sequence.
//  - It could be that if Gigatron messes up the hsync, vsync
//    its state machine won't advance.
//    - from the look of the screen, it does not like loss of
//      sync from the Gigatron, and no blinken lights.
//
//  - Get the Arduino BabelFish connector options and make the
//    FPGA Arduino ports the same. This way so can test with
//    Arduino BabelFish.
//
// KEY[0:0] is on the right.
//  - lights LED7, most left LED only when pressed.
//  - toggles sprite
//  - sets digital volume control from switches
//
// KEY[1:1] is on the left.
//  - application select from switches
//  - application go
//  - lights LED 6 second from left only when pressed.
//
//  LED[7:7] the left most led
//   - KEY[0:0]
//
//  LED[6:6] the second from the left
//   - KEY[1:1]
//
//  LED[5:5] is the third from left
//   - flashes when Gigatron loader is running
//
//  LED[4:4] is the fourth from left
//   - unassigned
//
// Validate volume control.
// LED on when button is currently pressed.
//
// LED on when BabelFish is active
// Look at debounce for buttons
// validate sprite is initialized with bits in first part.
//  - leave blank
//
// SW[3:0] 4 bits of dip switches // used for value input.
// SW[0:0] is the right most switch.
// SW[3:3] is the left most switch.
//
//   - Up   ("1") is HIGH
//   - Down ("0") is LOW
//
// UI:
//
// Set the four dip switches to either the volume level,
// or program to load.
//
// Press the left button to change the volume, or the
// right button to initiate a Gigatron BabelFish program load.
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
// Gigatron Shell
//
// 10/12/2018
//
// The Gigatron is implemented of the core Gigatron CPU
// and supporting RAM and ROM modules.
//
// In addition there are modules developed to adapter its
// VGA and audio output to HDMI video and audio, adapt the
// interface to the game controler, and implement the
// BabelFish loader protocol in System Verilog.
//
// These are fairly standard intefaces at the top level module
// to this shell, and interface with board specific implementations
// and signal bindings.
//
// This makes porting the Gigatron to new boards easier, as well
// as providing a project discipline.
//

module Gigatron_Shell (

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
    output [7:0] gigatron_output_port,
    output [7:0] gigatron_extended_output_port,
    output       famicom_pulse,
    output       famicom_latch,
    input        famicom_data,

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

    // 16 bit LPCM audio output from the Gigatron.
    output [15:0] audio_dac,

    // Digital volume control with range 0 - 11.
    input [3:0] digital_volume_control,

    // Signals from user interface to select program to load
    input loader_go,  // true when user select load
    input [3:0] loader_program_select,
    output loader_active // true when loader is active
  );

  //
  // The Gigatron loader operates in passthrough mode for
  // the Famicom controller signals by default.
  //
  // When the Gigatron loader program in the ROM is being run, the
  // Gigatron loader is activated by the user, and the Famicom
  // input is switched to the loader which executes the Gigatron
  // BabelFish program loading protocol which is a form of RDMA
  // (Remote Direct Memory Access) because it performs a scatter-write
  // of memory fragments through the Gigatrons RAM address space.
  //
  // This is because Gigatron programs must fit within the dead space
  // in memory for the screen data's horizontal scan lines, as an optimization
  // in Gigatron page address is used to provide each scan line at the start
  // of a 256 byte Gigatron page as addressed by the high address register.
  //
  // In the Gigatron kit the BabelFish protocol is run from an Arduino,
  // but in this implementation is written in 100% System Verilog.
  //

  wire gigatron_famicom_pulse;
  wire gigatron_famicom_latch;
  wire gigatron_famicom_data;

  //
  // Gigatron loader using Menlo version of BabelFish implemented as
  // an RDMA transmitter.
  //

  Gigatron_Loader gigatron_loader(
    .fpga_clock(fpga_clock),  // 50Mhz FPGA clock
    .gigatron_clock(clock),   // 6.25Mhz Gigatron clock from the PLL
    .reset(reset),

    //
    // These signals are from the Famicom serial game controller.
    //
    .famicom_pulse(famicom_pulse), // output
    .famicom_latch(famicom_latch), // output
    .famicom_data(famicom_data),   // input

    // Timing input from the Gigatron
    .gigatron_famicom_pulse(gigatron_famicom_pulse),
    .gigatron_famicom_latch(gigatron_famicom_latch),

    // Output to the Gigatron generated by gigatron_loader
    .gigatron_famicom_data(gigatron_famicom_data),

    // Signals from user interface to select program to load
    .loader_go(loader_go),  // true when user select load
    .loader_program_select(loader_program_select),
    .loader_active(loader_active)
  );

  Gigatron gigatron(
    .fpga_clock(fpga_clock), // 50Mhz FPGA clock
    .vga_clock(vga_clock),   // 25Mhz VGA clock from the PLL
    .clock(clock),           // 6.25Mhz Gigatron clock from the PLL
    .reset(reset),
    .run(1'b1),

    .gigatron_output_port(gigatron_output_port),
    .gigatron_extended_output_port(gigatron_extended_output_port),

    //
    // Famicom Serial game controller.
    //
    // These signals are from the Gigatron_Loader.
    //
    .famicom_pulse(gigatron_famicom_pulse), // output
    .famicom_latch(gigatron_famicom_latch), // output
    .famicom_data(gigatron_famicom_data),   // input

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
    .led5(led5),
    .led6(led6),
    .led7(led7),
    .led8(led8),

    // 16 bit LPCM audio output from the Gigatron.
    .audio_dac(audio_dac),

    // Digital volume control with range 0 - 11.
    .digital_volume_control(digital_volume_control)
  );

endmodule
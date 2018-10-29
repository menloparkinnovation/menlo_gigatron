
//
// See MENLO_COPYRIGHT.TXT for the copyright notice for this file.
//
// Use of this file is not allowed without the copyright notice present
// and re-distributed along with these files.
//

//
// See menlo_7xxx_series_library_notes.txt for more details on the
// general philosophy of this module.
//

// set timescale for 1ns with 100ps precision.
`timescale 1ns / 100ps

//
// 07/03/2018
//
// 74xx153/SN74HCT153 dual 4-line to 1-line selector/multiplexer TTL chip in 16 pin DIP.
//
// http://www.ti.com/lit/ds/symlink/cd74hc153.pdf
//
// Note: Order of inputs and output signals follows the sequence of
// pins on the physical chip 1 - 16.
//
// Pin 8 is GND, Pin 16 is VCC which are not required here.
//
module x74xx153
(
    input  E1_N,  // 1E_N on data sheet (pin 1)
    input  S1,    // S1 on data sheet   (pin 2)
    input  I1_3,  // 1I3 on data sheet  (pin 3)
    input  I1_2,  // 1I2 on data sheet  (pin 4)
    input  I1_1,  // 1I1 on data sheet  (pin 5)
    input  I1_0,  // 1I0 on data sheet  (pin 6)
    output Y1,    // 1Y on  datasheet   (pin 7)

    output Y2,    // 2Y on  datasheet   (pin 9)
    input  I2_0,  // 2I0 on data sheet  (pin 10)
    input  I2_1,  // 2I1 on data sheet  (pin 11)
    input  I2_2,  // 2I2 on data sheet  (pin 12)
    input  I2_3,  // 2I3 on data sheet  (pin 13)
    input  S0,    // S0 on data sheet   (pin 14)
    input  E2_N  // 2E_N on data sheet (pin 15)
);

  //
  // Truth table in datasheet shows active high, non-inverting output.
  //
  // Schematic/block diagram shows a NAND output, not sure if this
  // is an error.
  //
  // No clock, simple logic.
  //

  // Tied together for select, address

  //
  // Mux #1
  //
  // E1_N - Active low enable for function 1
  //
  // I1_3 - I1_0 - Input signals multiplexed onto Y1
  //
  // S1, S0 - two address bits for selecting Y1 from
  //          the inputs I1_3 - I1_0. 
  //          (in common with function 2)
  // 

  assign Y1 =  (((~E1_N & ~S1 & ~S0) & I1_0) ||
               ((~E1_N & ~S1 &  S0) & I1_1) ||
               ((~E1_N &  S1 & ~S0) & I1_2) ||
               ((~E1_N &  S1 &  S0) & I1_3));

  //
  // Mux #1
  //
  // E2_N - Active low enable for function 1
  //
  // I2_3 - I2_0 - Input signals multiplexed onto Y2
  //
  // S1, S0 - two address bits for selecting Y2 from
  //          the inputs I2_3 - I2_0. 
  //          (in common with function 1)
  // 

  assign Y2 =  (((~E2_N & ~S1 & ~S0) & I2_0) ||
               ((~E2_N & ~S1 &  S0) & I2_1) ||
               ((~E2_N &  S1 & ~S0) & I2_2) ||
               ((~E2_N &  S1 &  S0) & I2_3));

endmodule

`define tb_x74xx153_assert(signal, value) \
    if (signal !== value) begin \
	     $display("ASSERTION FAILED in %m: signal != value"); \
		  $stop; \
    end

//
// Test bench
//
module tb_x74xx153();

  reg clock_50;

  reg input_S0;
  reg input_S1;

  reg input_E1_N;
  reg input_I1_0;
  reg input_I1_1;
  reg input_I1_2;
  reg input_I1_3;

  reg input_E2_N;
  reg input_I2_0;
  reg input_I2_1;
  reg input_I2_2;
  reg input_I2_3;

  wire output_Y1;
  wire output_Y2;

  // Device Under Test instance
  x74xx153 DUT(
     .E1_N(input_E1_N),
     .S1(input_S1),

     .I1_3(input_I1_3),
     .I1_2(input_I1_2),
     .I1_1(input_I1_1),
     .I1_0(input_I1_0),
     .Y1(output_Y1),

     .Y2(output_Y2),
     .I2_0(input_I2_0),
     .I2_1(input_I2_1),
     .I2_2(input_I2_2),
     .I2_3(input_I2_3),

     .S0(input_S0),
     .E2_N(input_E2_N)
  );

  // Set initial values
  initial begin
     clock_50 = 0;

     input_S0 = 1;
     input_S1 = 1;

     input_E1_N = 1;
     input_I1_0 = 0;
     input_I1_1 = 0;
     input_I1_2 = 0;
     input_I1_3 = 0;

     input_E2_N = 1;
     input_I2_0 = 0;
     input_I2_1 = 0;
     input_I2_2 = 0;
     input_I2_3 = 0;
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

     @(posedge clock_50);

     input_E1_N = 0;
     input_E2_N = 0;
     @(posedge clock_50);

     //
     // Both halves are loaded and tested at once.
     //

     set_input_values(2'b00, 8'b11111111);
     assert_output_values(2'b11);

     set_input_values(2'b00, 8'b00000000);
     assert_output_values(2'b00);

     // Test enable/disable
     input_E1_N = 1;
     input_E2_N = 1;
     @(posedge clock_50);
     assert_output_values(2'b00);

     input_E1_N = 0;
     input_E2_N = 0;
     @(posedge clock_50);

     //
     // Test full decodes
     //

     // S1, S0 == 00
     set_input_values(2'b00, 8'b11101110);
     assert_output_values(2'b00);

     set_input_values(2'b00, 8'b00010001);
     assert_output_values(2'b11);

     // S1, S0 == 01
     set_input_values(2'b01, 8'b11011101);
     assert_output_values(2'b00);

     set_input_values(2'b01, 8'b00100010);
     assert_output_values(2'b11);

     // S1, S0 == 10
     set_input_values(2'b10, 8'b10111011);
     assert_output_values(2'b00);

     set_input_values(2'b10, 8'b01000100);
     assert_output_values(2'b11);

     // S1, S0 == 11
     set_input_values(2'b11, 8'b01110111);
     assert_output_values(2'b00);

     set_input_values(2'b11, 8'b10001000);
     assert_output_values(2'b11);

     //
     // Look for cross wiring
     //

     set_input_values(2'b00, 8'b00000001);
     assert_output_values(2'b01);

     set_input_values(2'b00, 8'b00010000);
     assert_output_values(2'b10);

     @(posedge clock_50);
     @(posedge clock_50);

     $stop;

  end

//
// Task to assert output values
//
task assert_output_values;
  input [1:0] values_to_assert;

  begin

    //
    // Note this task can see the signals (local variables) of the module
    // its included in.
    //

    `tb_x74xx153_assert(output_Y1, values_to_assert[0:0])
    `tb_x74xx153_assert(output_Y2, values_to_assert[1:1])

  end  
endtask

task set_input_values;
  input [1:0] select_value;
  input [7:0] values_to_assert;

  begin

     input_S0 = select_value[0:0];
     input_S1 = select_value[1:1];

     input_I1_0 = values_to_assert[0:0];
     input_I1_1 = values_to_assert[1:1];
     input_I1_2 = values_to_assert[2:2];
     input_I1_3 = values_to_assert[3:3];

     input_I2_0 = values_to_assert[4:4];
     input_I2_1 = values_to_assert[5:5];
     input_I2_2 = values_to_assert[6:6];
     input_I2_3 = values_to_assert[7:7];

     @(posedge clock_50);

  end  
endtask

endmodule

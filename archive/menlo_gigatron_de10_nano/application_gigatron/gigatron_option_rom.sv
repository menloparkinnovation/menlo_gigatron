
// set timescale for 1ns with 100ps precision.
`timescale 1ns / 100ps

//
// See MENLO_COPYRIGHT.TXT for the copyright notice for this file.
//
// Use of this file is not allowed without the copyright notice present
// and re-distributed along with these files.
//

module Gigatron_option_rom
(
       input [3:0] option_select,
       input [15:0] address,
       output reg [7:0] data
);

  parameter ROM_ARRAY_SIZE = 32767;

  //
  // Note: This gets inferred as a RAM/ROM and generates
  // warnings about unconfigured signal lines.
  //
  // Maybe convert this to a ROM IP block to make the
  // warnings go away as the proper defaults will be implemented
  // by the generated shell.
  //
  // Warning (10030): Net "reg_eeprom.data_a" at gigatron_option_rom.sv(22) has no driver or initial value, using a default initial value '0'
  //
  // Warning (10030): Net "reg_eeprom.waddr_a" at gigatron_option_rom.sv(22) has no driver or initial value, using a default initial value '0'
  //
  // Warning (10030): Net "reg_eeprom.we_a" at gigatron_option_rom.sv(22) has no driver or initial value, using a default initial value '0'
  //

  //  width             depth
  reg [7:0] reg_eeprom [0:ROM_ARRAY_SIZE];

  initial begin
    $readmemh(
      "application_gigatron/gt1_tetris_verilog_data.txt",
      reg_eeprom,
      0,
      9866 // actual currrent file size is 9867 bytes
      );
  end

  always @* begin
    data = reg_eeprom[address];
  end

endmodule

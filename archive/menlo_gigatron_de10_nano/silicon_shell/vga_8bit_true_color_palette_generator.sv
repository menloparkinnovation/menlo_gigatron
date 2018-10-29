
//
// See MENLO_COPYRIGHT.TXT for the copyright notice for this file.
//
// Use of this file is not allowed without the copyright notice present
// and re-distributed along with these files.
//

//
// Implement 8 bit true color without the palette RAM.
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
// For more complex palettes, implment the img_index ROM module and an initialization
// .mif file for the custom palette.
//
// The interface conforms with the bit pattern from the img_index.v palette generator.
//
// assign b_data = bgr_data[23:16];
// assign g_data = bgr_data[15:8];
// assign r_data = bgr_data[7:0];
//
module vga_8bit_true_color_palette_generator(
	address, // 8 bit pixel value, normally a palette lookup table address
	clock,
	q
        );

    input [7:0] address;
    input  clock;
    output [23:0]  q;

    reg [7:0]   reg_address;

    // two bits for blue
    assign q[23:22] = reg_address[1:0];
    assign q[21:16] = 6'b000000;
   
    // 3 bits for green
    assign q[15:13] = reg_address[4:2];
    assign q[12:8]  = 5'b00000;

    // 3 bits for red
    assign q[7:5] = reg_address[7:5];
    assign q[4:0] = 5'b00000;

    // The input address is registered so the output is steady to the next clock
    always@(posedge clock) begin
        reg_address <= address;
    end

endmodule

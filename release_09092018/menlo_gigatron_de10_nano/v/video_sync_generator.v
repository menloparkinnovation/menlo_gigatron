
//
// Menlo: Cleaned this up and documented it.
//
// 09/03/2018
//

module video_sync_generator(reset,
                            vga_clk,
                            blank_n,
                            HS,
                            VS
			    );
   
// Reset is active high
input reset;

// VGA clock is 25Mhz from the PLL.
input vga_clk;

// blank_n == 0 when in the blanking interval
output reg blank_n;

// HS is the horizontal sync pulse. It is 96 VGA clocks.
output reg HS;

// VS is the vertical sync pulse. It is 2 VGA clocks.
output reg VS;

/*
--VGA Timing
--Horizontal :
--                ______________                 _____________
--               |              |               |
--_______________|  VIDEO       |_______________|  VIDEO (next line)

--___________   _____________________   ______________________
--           |_|                     |_|
--            B <-C-><----D----><-E->
--           <------------A--------->
--The Unit used below are pixels;  
--  B->Sync_cycle (96)              :H_sync_cycle
--  C->Back_porch (144)             :hori_back
--  D->Visable Area
--  E->Front porch (16)             :hori_front
--  A->horizontal line total length :hori_line (800)

--Vertical :
--               ______________                 _____________
--              |              |               |          
--______________|  VIDEO       |_______________|  VIDEO (next frame)
--
--__________   _____________________   ______________________
--          |_|                     |_|
--           P <-Q-><----R----><-S->
--          <-----------O---------->
--The Unit used below are horizontal lines;  
--  P->Sync_cycle (2)               :V_sync_cycle
--  Q->Back_porch (34)              :vert_back
--  R->Visable Area
--  S->Front porch (11)             :vert_front
--  O->vertical line total length :vert_line*

*/

//parameter

// This is 640 pixels + horizontal front porch (16) and horizontal back porch (144)
parameter hori_line  = 800;                           
parameter hori_back  = 144;
parameter hori_front = 16;

// This is 480 lines + vertical front porch (11) and vertical back porch (34)
parameter vert_line  = 525;
parameter vert_back  = 34;
parameter vert_front = 11;

// number of VGA clocks hsync_n is low
parameter H_sync_cycle = 96;
 
// number of VGA clocks vsync_n is low
parameter V_sync_cycle = 2;

//////////////////////////
reg [10:0] h_cnt;
reg [9:0]  v_cnt;

wire cHD, cVD, cDEN, hori_valid, vert_valid;

//
// Generates horizontal and vertical counters with wrap around at their
// maximum values.
//
always@(negedge vga_clk, posedge reset)
begin
  if (reset) begin
     h_cnt<=11'd0;
     v_cnt<=10'd0;
  end
  else begin

      // Not Reset

      if (h_cnt == hori_line-1) begin 
         h_cnt <= 11'd0;

         if (v_cnt == vert_line-1) begin
            v_cnt <= 10'd0;
         end
         else begin
            v_cnt <= v_cnt + 10'd1;
         end
      end
      else begin
         h_cnt <= h_cnt + 11'd1;
      end

    end
end

// cHD == 1 when horizontal pulse is asserted
assign cHD = (h_cnt < H_sync_cycle) ? 1'b0: 1'b1;

// cVD == 1 when vertical pulse is asserted
assign cVD = (v_cnt < V_sync_cycle) ? 1'b0: 1'b1;

// hori_valid == 1 when in the visible region
assign hori_valid = (h_cnt < (hori_line - hori_front) && h_cnt >= hori_back) ? 1'b1: 1'b0;

// vert_valid == 1 when in the visible region
assign vert_valid = (v_cnt < (vert_line - vert_front) && v_cnt >= vert_back) ? 1'b1: 1'b0;

// cDEN == 1 when in the visible region rectangle
assign cDEN = hori_valid && vert_valid;

// Sets the registered outputs based on VGA clock.
always@(negedge vga_clk)  begin
  HS <= cHD;
  VS <= cVD;
  blank_n <= cDEN;
end

endmodule



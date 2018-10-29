
//
//   Menlo Silicon Shell Led Flasher.
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

module LED_Flasher (
  input clock,
  input reset,
  input [31:0] counter,
  input  led_state,
  output led
  );
   
  reg 	     reg_flasher;
  reg [31:0] reg_counter;

  // LED is active if flasher is HIGH, and led_state is HIGH
  assign led = reg_flasher == 1'b1 ? led_state : 1'b0;

  always@ (posedge clock) begin
    if (reset == 1'b1) begin
      reg_flasher <= 1'b0;
      reg_counter <= counter;
    end
    else begin
      // not reset
      reg_counter <= reg_counter - 32'd1;
      if (reg_counter == 32'd0) begin
         reg_counter <= counter;
         if (reg_flasher == 1'b1) begin
            reg_flasher <= 1'b0;
	 end
	 else begin
            reg_flasher <= 1'b1;
	 end
      end
    end
  end

endmodule // Flasher

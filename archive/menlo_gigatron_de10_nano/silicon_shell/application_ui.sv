
//
//   Menlo Silicon Shell Application UI.
//
//   Handles UI with switches and LED's.
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
// Application user interface
//
module Application_UI (
  input clock,

  input reset_n,

  input [1:0] KEY,

  input [3:0] SW,

  output led4,
  output led6,
  output led7,

  output [3:0]  digital_volume_control,

  // Application go button
  output application_go,
  
  // Application select
  output [3:0]   application_select,

  // Activate Sprite
  output activate_sprite
  );
   
  //
  // Outputs are registered so the caller does not have to maintain
  // its register state.
  //

  reg reg_led4;
  assign led4 = reg_led4;

  reg reg_led6;
  assign led6 = reg_led6;

  reg reg_led7;
  assign led7 = reg_led7;

  reg [3:0]  reg_digital_volume_control;
  assign digital_volume_control = reg_digital_volume_control;

  // Application go button
  reg 	      reg_application_go;
  assign application_go = reg_application_go;
  
  // Application select
  reg [3:0]   reg_application_select;
  assign application_select = reg_application_select;

  reg 	      reg_activate_sprite;
  assign activate_sprite = reg_activate_sprite;
   
  always@ (posedge clock) begin
    if (reset_n == 1'b0) begin
       reg_led4 <= 0;
       reg_led6 <= 0;
       reg_led7 <= 0;
       reg_digital_volume_control <= 4'd11; // Our amps go to 1l...
       reg_application_go <= 0;
       reg_application_select <= 0;
       reg_activate_sprite <= 0;
    end
    else begin

      //
      // Not reset.
      //

      //
      // Drive the user interface state machine
      //

      //
      // KEY0 is the pushbutton on the right.
      //
      // It is LOW when pressed.
      //
      // When pressed the switches are read into
      // the current digital volume control register.
      //
      if (KEY[0:0] == 1'b0) begin

        reg_digital_volume_control <= SW;

        // Light LED to indicate press being held
        reg_led6 <= 1'b1;
        
        //
        // Toggle sprite on screen
        //
        if (reg_activate_sprite == 1'b1) begin
          reg_activate_sprite <= 1'b0;
	end
        else begin
          reg_activate_sprite <= 1'b1;
        end

      end // key0
      else begin
        reg_led6 <= 1'b0;
      end

      //
      // KEY1 is the pushbutton on the left.
      //
      // It is LOW when pressed.
      //
      if (KEY[1:1] == 1'b0) begin

        reg_application_select <= SW;

        reg_application_go <= 1'b1;

        // Light LED to indicate press being held
        reg_led7 <= 1'b1;

      end // key1
      else begin

        //
        // It's only active for one clock after press, but
        // that is enough time for the application to latch it.
        //
        reg_application_go <= 1'b0;
        reg_led7 <= 1'b0;
      end

    end // not reset

  end // always user interface state machine

endmodule // application UI

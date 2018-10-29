
//
// See MENLO_COPYRIGHT.TXT for the copyright notice for this file.
//
// Use of this file is not allowed without the copyright notice present
// and re-distributed along with these files.
//

// set timescale for 1ns with 100ps precision.
`timescale 1ns / 100ps

//
// User Switch interface.
//
// This handles debouncing of the signal from on to off and back again.
//
module user_switch (
  input raw_switch, // raw switch I/O port signal, active high.
  input clock,
  input reset_n,        // active low reset
  output switch_state
  );

  // 20ms at 50Mhz.
  parameter debounce_delay = 32'h000FFFFF;

  parameter MAX_DEBOUNCE_COUNTER = 32'hFFFFFFFF;
  reg [31:0] debounce_counter;

  reg reg_switch_state;

  assign switch_state = reg_switch_state;

  parameter[2:0]
    SWITCH_IDLE      = 3'b000,
    SWITCH_ON_DELAY  = 3'b001,
    SWITCH_ON        = 3'b010,
    SWITCH_OFF_DELAY = 3'b011,
    SWITCH_OFF       = 3'b100;

  // Bit width must match the state parameters.
  reg [2:0] reg_state;

  always@(posedge clock) begin

    if (reset_n == 1'b0) begin
      reg_state <= SWITCH_IDLE;
      debounce_counter <= 0;
      reg_switch_state <= 0;
    end
    else begin

      //
      // not reset
      //

      if (debounce_counter <= MAX_DEBOUNCE_COUNTER) begin
	debounce_counter <= debounce_counter + 1;
      end

      case (reg_state)

        SWITCH_IDLE: begin
         if(raw_switch == 1'b1) begin
             //
             // Switch is in the ON state, set the debounce timer
             // for a possible transition to switch on.
             //
             debounce_counter <= 0;
             reg_state <= SWITCH_ON_DELAY;
         end
         else begin
             //
             // Switch is in the off state, set the debounce timer
             // for a possible transition to switch off.
             //
             debounce_counter <= 0;
             reg_state <= SWITCH_OFF_DELAY;
         end
        end // SWITCH_IDLE

        SWITCH_ON_DELAY: begin
          if (debounce_counter >= MAX_DEBOUNCE_COUNTER) begin

            //
            // Counter debounce time has passed. Re-sample and if still
            // asserted signal the switch on. Otherwise cancel and go back to
            // idle and resample.
            //
            if(raw_switch == 1'b1) begin
              reg_switch_state <= 1;
              reg_state <= SWITCH_ON;
            end
            else begin
              // No longer on, cancel and go back to idle and re-sample.
              reg_state <= SWITCH_IDLE;
            end
          end
          else begin
            // Counting up the debounce timer, do nothing
          end
        end // SWITCH_ON_DELAY

        SWITCH_ON: begin

          //
          // Switch is on after the debounce delay.
          //
          if (raw_switch == 1'b0) begin

            //
            // Switch has changed state, go back to idle and re-sample
            // for a possible transition to off.
            //
            reg_state <= SWITCH_IDLE;
          end

        end // SWITCH_ON

        SWITCH_OFF_DELAY: begin
          if (debounce_counter >= MAX_DEBOUNCE_COUNTER) begin

            // switch off delay has hit, re-test the switch.

            if (raw_switch == 1'b0) begin
               // Switch has remained off for the debounce delay, change switch state.
               reg_switch_state <= 0;
               reg_state <= SWITCH_OFF;
            end
            else begin
              //
              // Switch is no longer off, go back to idle to resample.
              //
              reg_state <= SWITCH_IDLE;
            end

          end
          else begin
            // Waiting for the switch off delay counter.
          end
        end // SWITCH_OFF_DELAY

        SWITCH_OFF: begin

          //
          // Switch is off after the debounce delay.
          //
          if (raw_switch == 1'b1) begin

            //
            // Switch is no longer off, go back to idle and resample
            // for a possible state transition to on.
            //
            reg_state <= SWITCH_IDLE;
          end

        end // SWITCH_OFF

    	default: begin
          // Bad state. Reset everything and start over.
          reg_state <= SWITCH_IDLE;
    	end

      endcase

    end // not reset

  end // end always

endmodule

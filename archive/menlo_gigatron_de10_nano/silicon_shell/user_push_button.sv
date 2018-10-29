
//
// See MENLO_COPYRIGHT.TXT for the copyright notice for this file.
//
// Use of this file is not allowed without the copyright notice present
// and re-distributed along with these files.
//

// set timescale for 1ns with 100ps precision.
`timescale 1ns / 100ps

//
// User Push Button Interface.
//
// Handles a user push button. A user interface for a button
// press must handle:
//
// 1) Debounce. A configurable debounce time based on the interface
//    use is required.
//
// 2) One shot function. If the debounce time is short, the user pressing
//    the button once will cause multiple button press indications
//    unless the interface explicitly forces a set/reset for each button
//    press and release.
//
// 3) Missed presses. Depending on the circuit, for example if connected
//    to an external software interface, a button press could be missed
//    if its not pressed during the "poll" time. So positive feedback that
//    the signal is accepted is required.
//
// raw_button_n is active low since the most common push
// button usage is a direct connection to an I/O port with
// a pull up resistor. This makes it active low on press.
//
// press_accepted is acknowledgement from the circuit receiving
// the button press that it has be accepted.
//
// press_activated is true when a press has been indicated as it
// met the debounce and de-activation to re-activation times.
//
// clock is the clock to use for the logic.
//
// reset_n is an external signal to reset the push button state machine
// usually at subsystem startup time.
//
// This module accepts the debounce_delay parameter, which is the
// number of clock's for the debounce delay. The default is 10**6, or
// one million, which is 20ms with a 50Mhz FPGA clock. The maximum
// value is 32 bits as that is the size of the counter used.
//
// The debounce_delay is used for both the push button press accept,
// and push button reset delays. The reset delay is the time the
// button must be released (not asserted) before a new button press
// will be accepted.
//
module user_push_button (
  input raw_button_n,   // raw pushbutton I/O port signal, active low.
  input clock,
  input reset_n,        // active low reset
  input press_accepted,
  output press_activated
  );

  // 20ms at 50Mhz.
  parameter debounce_delay = 32'h000FFFFF;

  parameter MAX_DEBOUNCE_COUNTER = 32'hFFFFFFFF;
  reg [31:0] debounce_counter;

  reg reg_button_pressed;

  assign press_activated = reg_button_pressed;

  parameter[2:0]
    BUTTON_NOT_PRESSED      = 3'b000,
    BUTTON_PRESS_DELAY      = 3'b001,
    BUTTON_PRESSED          = 3'b010,
    BUTTON_WAIT_FOR_RELEASE = 3'b011,
    BUTTON_REPRESS_DELAY    = 3'b100;

  // Bit width must match the state parameters.
  reg [2:0] reg_state;

  always@(posedge clock) begin

    if (reset_n == 1'b0) begin
      reg_state <= BUTTON_NOT_PRESSED;
      debounce_counter <= 0;
      reg_button_pressed <= 0;
    end
    else begin

      //
      // not reset
      //

      if (debounce_counter <= MAX_DEBOUNCE_COUNTER) begin
	debounce_counter <= debounce_counter + 1;
      end

      case (reg_state)

        BUTTON_NOT_PRESSED: begin
         if(raw_button_n == 1'b0) begin
             // first button press, start the counter.
             debounce_counter <= 0;
             reg_state <= BUTTON_PRESS_DELAY;
         end
        end

        BUTTON_PRESS_DELAY: begin
          if (debounce_counter >= MAX_DEBOUNCE_COUNTER) begin

            //
            // Counter debounce time has passed. Re-sample and if still
            // asserted signal the press. Otherwise cancel and go back to idle.
            //
            if(raw_button_n == 1'b0) begin
              reg_button_pressed <= 1;
              reg_state <= BUTTON_PRESSED;
            end
            else begin
              // No longer pressed, cancel and go back to idle.
              debounce_counter <= 0;
              reg_state <= BUTTON_NOT_PRESSED;
            end
          end
          else begin
            // Counting up the debounce timer, do nothing
          end
        end // BUTTON_PRESS_DELAY

        BUTTON_PRESSED: begin

          //
          // Button is pressed after the debounce delay.
          //

          if (press_accepted == 1'b1) begin

            //
            // Circuit accepted the button press, now go to the
            // wait for button release state.
            //
            reg_button_pressed <= 0;
            reg_state <= BUTTON_WAIT_FOR_RELEASE;
          end
          else begin
            //
            // If the button press is not accepted yet by the
            // circuit, stay in the button pressed state.
            //
          end

        end // BUTTON_PRESSED

        BUTTON_WAIT_FOR_RELEASE: begin
          if (raw_button_n == 1'b1) begin
            // Button is no longer pressed, start the repress delay counter.
            debounce_counter <= 0;
            reg_state <= BUTTON_REPRESS_DELAY;
          end
          else begin
            // Button is still pressed, stay in button wait for release state.
          end
        end // BUTTON_WAIT_FOR_RELEASE

        BUTTON_REPRESS_DELAY: begin
          if (debounce_counter >= MAX_DEBOUNCE_COUNTER) begin
             // repress delay has hit, we can accept a new button press.
             reg_state <= BUTTON_NOT_PRESSED;
          end
          else begin
            // Waiting for the button repress delay.
          end
        end // BUTTON_REPRESS_DELAY

    	default: begin
          // Bad state. Reset everything and start over.
          reg_state <= BUTTON_NOT_PRESSED;
          debounce_counter <= 0;
          reg_button_pressed <= 0;
    	end

      endcase

    end // not reset

  end // end always

endmodule

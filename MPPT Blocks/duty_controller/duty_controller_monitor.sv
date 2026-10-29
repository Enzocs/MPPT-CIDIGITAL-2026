

// ===========================================================================
// Formal monitor for duty_controller
// ===========================================================================
module duty_controller_monitor #(
    parameter width = 10
) (
    input wire              clk,
    input wire              rst,
    input wire              valid_input,
    input wire [1:0]        Dc_in,
    input wire [width:0]    D_out
);

  // ===========================================================================
  // === duty_accumulator family ===
  // Constants only — no state.
  // ===========================================================================

  // Upper saturation bound, all ones (dutty_controller.sv:24).
  localparam [width:0] MAX_D = {(width+1){1'b1}};

  // Step size. This replicates the RTL's hard-wired `assign delta_d = 10'd256`
  // (dutty_controller.sv:29) as a specification constant in the checker; the
  // DUT's internal `delta_d` wire is never referenced.
  localparam [width:0] DELTA = 'd256;

  // Command encoding (dutty_controller.sv:14-20,38-60).
  localparam [1:0] CMD_DEC = 2'b00;  // decrease by DELTA, clamp at 0
  localparam [1:0] CMD_INC = 2'b01;  // increase by DELTA, clamp at MAX_D
  localparam [1:0] CMD_HLD = 2'b10;  // hold
  localparam [1:0] CMD_RSV = 2'b11;  // reserved -> default arm, also holds

  // Supported parameter range: width >= 9.

  // ===========================================================================
  // === Assumptions (input constraints) ===
  // None.
  // ===========================================================================

  // ===========================================================================
  // === Interface / protocol assertions ===
  // ===========================================================================

  // testplan: duty_changes_only_on_accepted_command
  // The accumulator may only move in response to an accepted step command.
  duty_changes_only_on_accepted_command_a: assert property (
      @(posedge clk) disable iff (rst)
      $changed(D_out) |-> ($past(valid_input) &&
                           (($past(Dc_in) == CMD_DEC) || ($past(Dc_in) == CMD_INC)))
  );

  // testplan: duty_holds_while_qualifier_low
  // An unqualified command can never perturb the duty value.
  duty_holds_while_qualifier_low_a: assert property (
      @(posedge clk) disable iff (rst)
      !valid_input |=> $stable(D_out)
  );

  // ===========================================================================
  // === End-to-end assertions ===
  // ===========================================================================

  // testplan: increment_saturates_at_max
  // Above the threshold the clamp path loads MAX_D rather than wrapping.
  increment_saturates_at_max_a: assert property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_INC) && (D_out > (MAX_D - DELTA)))
      |=> (D_out == MAX_D)
  );

  // testplan: decrement_clamps_at_zero
  // Below one step the clamp path loads 0 rather than borrowing/wrapping.
  decrement_clamps_at_zero_a: assert property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_DEC) && (D_out < DELTA))
      |=> (D_out == '0)
  );

  // testplan: hold_command_preserves_duty
  // The explicit hold code is a true no-op, even though it is qualified.
  hold_command_preserves_duty_a: assert property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_HLD)) |=> $stable(D_out)
  );

  // ===========================================================================
  // === Corner-case assertions ===
  // ===========================================================================

  // testplan: max_endpoint_is_sticky_under_increase
  // The ceiling is an absorbing state for increase commands.
  max_endpoint_is_sticky_under_increase_a: assert property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_INC) && (D_out == MAX_D)) |=> (D_out == MAX_D)
  );

  // testplan: zero_endpoint_is_sticky_under_decrease
  // The floor is an absorbing state for decrease commands.
  zero_endpoint_is_sticky_under_decrease_a: assert property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_DEC) && (D_out == '0)) |=> (D_out == '0)
  );

  // ===========================================================================
  // === Error-scenario assertions ===
  // ===========================================================================

  // testplan: reserved_command_is_a_safe_nop
  // The reserved encoding is absorbed by the default arm as a clean no-op.
  reserved_command_is_a_safe_nop_a: assert property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_RSV)) |=> $stable(D_out)
  );

  // ===========================================================================
  // === Step-arithmetic assertions (guarded: width >= 9) ===
  // See the supported-parameter-range note above.
  // ===========================================================================

  if (width >= 9) begin : g_step_arith

    // testplan: duty_step_is_bounded_by_delta
    // Blanket anti-wrap guard: one accepted command moves the accumulator by
    // at most one step in either direction, across both arithmetic and clamp
    // paths. Catches a wrap-around independently of the per-direction checks.
    duty_step_is_bounded_by_delta_a: assert property (
        @(posedge clk) disable iff (rst)
        1'b1 |=> ((D_out >= $past(D_out)) ? ((D_out - $past(D_out)) <= DELTA)
                                          : (($past(D_out) - D_out) <= DELTA))
    );

    // testplan: increment_adds_step_below_threshold
    // Sub-threshold increase advances by exactly DELTA. The RTL guard is a
    // strict '>', so the arithmetic path covers D_out <= MAX_D - DELTA.
    increment_adds_step_below_threshold_a: assert property (
        @(posedge clk) disable iff (rst)
        (valid_input && (Dc_in == CMD_INC) && (D_out <= (MAX_D - DELTA)))
        |=> (D_out == ($past(D_out) + DELTA))
    );

    // testplan: decrement_subtracts_step_above_threshold
    // Above-threshold decrease retreats by exactly DELTA. The RTL guard is a
    // strict '<', so the arithmetic path covers D_out >= DELTA.
    decrement_subtracts_step_above_threshold_a: assert property (
        @(posedge clk) disable iff (rst)
        (valid_input && (Dc_in == CMD_DEC) && (D_out >= DELTA))
        |=> (D_out == ($past(D_out) - DELTA))
    );

    // testplan: endpoint_is_escapable_by_opposite_command
    // Saturation must be recoverable, not a trap state: the opposite command
    // steps off the ceiling by exactly one DELTA.
    endpoint_is_escapable_by_opposite_command_a: assert property (
        @(posedge clk) disable iff (rst)
        (valid_input && (Dc_in == CMD_DEC) && (D_out == MAX_D))
        |=> (D_out == (MAX_D - DELTA))
    );

  end

  // ===========================================================================
  // === Cover properties ===
  // ===========================================================================

  // testplan: cover_increment_at_exact_threshold
  // Arithmetic path at exactly MAX_D - DELTA, landing precisely on MAX_D.
  cover_increment_at_exact_threshold_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_INC) && (D_out == (MAX_D - DELTA)))
      ##1 (D_out == MAX_D)
  );

  // testplan: cover_increment_one_above_threshold
  // Clamp path one LSB above the threshold.
  cover_increment_one_above_threshold_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_INC) && (D_out == (MAX_D - DELTA + 1'b1)))
      ##1 (D_out == MAX_D)
  );

  // testplan: cover_decrement_at_exact_step
  // Subtract path at exactly DELTA, landing precisely on 0.
  cover_decrement_at_exact_step_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_DEC) && (D_out == DELTA))
      ##1 (D_out == '0)
  );

  // testplan: cover_decrement_below_step
  // Clamp path below one step.
  cover_decrement_below_step_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_DEC) && (D_out < DELTA) && (D_out != '0))
      ##1 (D_out == '0)
  );

  // testplan: cover_sustained_ramp_to_saturation
  // Back-to-back increases walking from 0 up to MAX_D at one command/clock.
  cover_sustained_ramp_to_saturation_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_INC) && (D_out == '0))
      ##1 (valid_input && (Dc_in == CMD_INC))[*7]
      ##1 (D_out == MAX_D)
  );

  // testplan: cover_sustained_ramp_to_zero
  // Back-to-back decreases walking from MAX_D down to the 0 floor.
  cover_sustained_ramp_to_zero_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_DEC) && (D_out == MAX_D))
      ##1 (valid_input && (Dc_in == CMD_DEC))[*7]
      ##1 (D_out == '0)
  );

  // testplan: cover_alternating_commands_oscillate
  // Maximum-rate mixed stream: +/-DELTA oscillation on consecutive clocks.
  cover_alternating_commands_oscillate_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_INC) && (D_out == '0))
      ##1 (valid_input && (Dc_in == CMD_DEC) && (D_out == DELTA))
      ##1 (valid_input && (Dc_in == CMD_INC) && (D_out == '0))
  );

  // testplan: cover_command_ignored_while_qualifier_low
  // Arithmetic opcode presented while unqualified, duty provably unchanged.
  cover_command_ignored_while_qualifier_low_c: cover property (
      @(posedge clk) disable iff (rst)
      (!valid_input && (Dc_in == CMD_INC) && (D_out != '0))
      ##1 $stable(D_out)
  );

  // testplan: cover_hold_command_accepted
  // Behavioural witness: an accepted explicit hold opcode is absorbed with the
  // accumulator pinned at its previous value.
  cover_hold_command_accepted_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_HLD) && (D_out != '0))
      ##1 $stable(D_out)
  );

  // testplan: cover_max_endpoint_held_under_repeated_increase
  // Sustained increase while ALREADY parked at the ceiling (residence, as
  // distinct from the approach witnessed by the ramp cover).
  cover_max_endpoint_held_under_repeated_increase_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_INC) && (D_out == MAX_D))
      ##1 (valid_input && (Dc_in == CMD_INC) && (D_out == MAX_D))
      ##1 (D_out == MAX_D)
  );

  // testplan: cover_zero_endpoint_held_under_repeated_decrease
  // Symmetric floor residence.
  cover_zero_endpoint_held_under_repeated_decrease_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_DEC) && (D_out == '0))
      ##1 (valid_input && (Dc_in == CMD_DEC) && (D_out == '0))
      ##1 (D_out == '0)
  );

  // testplan: cover_escape_from_max_endpoint
  // Saturation is recoverable: MAX_D -> MAX_D - DELTA.
  cover_escape_from_max_endpoint_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_DEC) && (D_out == MAX_D))
      ##1 (D_out == (MAX_D - DELTA))
  );

  // testplan: cover_escape_from_zero_endpoint
  // Symmetric floor escape: 0 -> DELTA.
  cover_escape_from_zero_endpoint_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_INC) && (D_out == '0))
      ##1 (D_out == DELTA)
  );

  // testplan: cover_reserved_command_accepted
  // Behavioural witness: an accepted reserved opcode is absorbed by the
  // default arm with the accumulator pinned at its previous value.
  cover_reserved_command_accepted_c: cover property (
      @(posedge clk) disable iff (rst)
      (valid_input && (Dc_in == CMD_RSV) && (D_out != '0))
      ##1 $stable(D_out)
  );

endmodule

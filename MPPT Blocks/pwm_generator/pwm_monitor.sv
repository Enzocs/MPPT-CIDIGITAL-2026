// ===========================================================================
// Formal monitor for pwm_generator
// ===========================================================================
module pwm_generator_monitor #(
    parameter width = 10
) (
    input wire              clk,
    input wire              rst,
    input wire [width:0]    D_in,
    input wire              pwm_out
);

  // ===========================================================================
  // === pwm_phase family ===
  // Port-derived reference model. `mon_phase` is a free-running counter whose
  // only inputs are `clk` and `rst` — both DUT top-level ports — so it is a
  // port-level prediction of the PWM phase, not a DUT-internal tap and not an
  // FSM clone. It mirrors the DUT time base exactly (pwm_generator.sv:12-17):
  // increments every posedge clk, asynchronously cleared by rst, wraps
  // naturally modulo 2**(width+1).
  //
  // Soundness precondition (see testplan "Harness precondition for phase
  // alignment"): mon_phase and the DUT counter are cleared by the same rst and
  // therefore remain phase-aligned for all time, provided the harness applies
  // reset at time zero (the generated Jasper TCL does).
  // ===========================================================================

  localparam int unsigned DW     = width + 1;              // datapath width
  localparam [width:0]    MAX_D  = {(width+1){1'b1}};      // full-scale duty code
  localparam int unsigned PERIOD = 2 ** DW;                // PWM period, PERIOD == MAX_D + 1

  // Supported parameter range: width >= 1.
  // At width == 0 the datapath degenerates to DW == 1, MAX_D == 1, so the
  // minimum-pulse code (D_in == 1) coincides with the full-scale override code
  // and the DUT legally holds pwm_out high. minimum_pulse_is_single_cycle_a and
  // near_full_scale_has_two_low_cycles_a would then report a spurious
  // counterexample. The boundary-code assertions are therefore generated only
  // for width >= 1; the delivered configuration is width = 10.

  logic [width:0] mon_phase;

  always_ff @(posedge clk or posedge rst) begin
    if (rst)
      mon_phase <= '0;
    else
      mon_phase <= mon_phase + 1'b1;
  end

  // ===========================================================================
  // === Assumptions (input constraints) ===
  // None. Every D_in value is architecturally legal, including mid-period
  // changes: D_in is unregistered and feeds the comparator directly
  // (pwm_generator.sv:4,19-20). A global $stable(D_in) assumption would delete
  // the dynamic-update behaviour the design exists to support and would make
  // duty_update_takes_effect_combinationally_a vacuous. Scenarios needing a
  // steady duty state it locally in their own antecedent.
  // ===========================================================================

  // ===========================================================================
  // === Interface / protocol assertions ===
  // ===========================================================================

  // testplan: pwm_out_asserts_only_for_nonzero_duty
  // The output may never drive high while the commanded duty is zero.
  pwm_out_asserts_only_for_nonzero_duty_a: assert property (
      @(posedge clk) disable iff (rst)
      pwm_out |-> (D_in != '0)
  );

  // testplan: pwm_out_deasserts_only_below_full_scale
  // A low output is only legal below the full-scale duty code, because the
  // override sits ahead of the comparator in the output ternary.
  pwm_out_deasserts_only_below_full_scale_a: assert property (
      @(posedge clk) disable iff (rst)
      !pwm_out |-> (D_in != MAX_D)
  );

  // testplan: nonzero_duty_eventually_produces_a_pulse
  // Bounded liveness: the generator cannot deadlock low. Within any PERIOD
  // consecutive cycles mon_phase passes through 0 exactly once, and at phase 0
  // any non-zero duty drives the output high. So a run of PERIOD consecutive
  // cycles that are simultaneously "duty non-zero" and "output low" is
  // impossible. Expressed as a bounded never-sequence, this needs no stability
  // flag and no extra state (a strict subset of the testplan's stated aux
  // logic), and it keeps the duty-stable requirement inside the window rather
  // than only at the trigger cycle.
  //
  // Deviation from the testplan's literal form, in the stronger direction: the
  // testplan states a `$stable(D_in)` antecedent with a `##[0:PERIOD]` window
  // plus a 1-bit stability flag. The never-sequence below SUBSUMES that
  // obligation — a stable non-zero duty across the window is one special case
  // of "duty non-zero every cycle of the window" — while using zero extra
  // state and requiring the non-zero condition throughout the window rather
  // than only at the trigger cycle.
  nonzero_duty_eventually_produces_a_pulse_a: assert property (
      @(posedge clk) disable iff (rst)
      not ((!pwm_out && (D_in != '0))[*PERIOD])
  );

  // ===========================================================================
  // === End-to-end assertions ===
  // ===========================================================================

  // testplan: output_level_matches_phase_comparison
  // Core functional contract: below full scale the output is exactly the
  // magnitude comparison of the current phase against the commanded duty.
  output_level_matches_phase_comparison_a: assert property (
      @(posedge clk) disable iff (rst)
      (D_in != MAX_D) |-> (pwm_out == (mon_phase < D_in))
  );

  // testplan: pwm_rises_at_period_wrap
  // Every period begins with the high phase, so successive periods are
  // contiguous across the counter wrap.
  pwm_rises_at_period_wrap_a: assert property (
      @(posedge clk) disable iff (rst)
      ((mon_phase == '0) && (D_in != '0)) |-> pwm_out
  );

  // testplan: pwm_falls_when_phase_reaches_duty
  // The strict less-than comparator ends the pulse exactly at the commanded
  // count, making the high time D_in cycles rather than D_in + 1.
  pwm_falls_when_phase_reaches_duty_a: assert property (
      @(posedge clk) disable iff (rst)
      ((mon_phase == D_in) && (D_in != MAX_D)) |-> !pwm_out
  );

  // testplan: duty_update_takes_effect_combinationally
  // A duty update is reflected in the same cycle it is applied — no
  // period-boundary latch and no pipeline stage.
  duty_update_takes_effect_combinationally_a: assert property (
      @(posedge clk) disable iff (rst)
      $changed(D_in) |-> (pwm_out == ((D_in == MAX_D) || (mon_phase < D_in)))
  );

  // ===========================================================================
  // === Corner-case assertions ===
  // ===========================================================================

  // testplan: zero_duty_forces_constant_low
  // Strict less-than guarantees a true 0% off state with no residual pulse.
  zero_duty_forces_constant_low_a: assert property (
      @(posedge clk) disable iff (rst)
      (D_in == '0) |-> !pwm_out
  );

  // testplan: full_scale_duty_forces_constant_high
  // The full-scale override bypasses the counter and suppresses the one-cycle
  // notch the bare comparator would produce at the top phase.
  full_scale_duty_forces_constant_high_a: assert property (
      @(posedge clk) disable iff (rst)
      (D_in == MAX_D) |-> pwm_out
  );

  // testplan: minimum_pulse_is_single_cycle
  // The smallest resolvable pulse is one clock wide, with no dead-time or
  // minimum-pulse filtering.
  // Guarded: at width == 0 this duty code equals MAX_D and the override applies.
  if (width >= 1) begin : g_min_pulse
    minimum_pulse_is_single_cycle_a: assert property (
        @(posedge clk) disable iff (rst)
        (D_in == {{width{1'b0}}, 1'b1}) |-> (pwm_out == (mon_phase == '0))
    );
  end

  // testplan: near_full_scale_has_two_low_cycles
  // One code below full scale the override must NOT fire: the output is low
  // for two phases (MAX_D-1 and MAX_D) because PERIOD == MAX_D + 1.
  // Guarded: at width == 0 the "one below full scale" code is 0, a different case.
  if (width >= 1) begin : g_near_full_scale
    near_full_scale_has_two_low_cycles_a: assert property (
        @(posedge clk) disable iff (rst)
        (D_in == (MAX_D - 1'b1)) |-> (pwm_out == (mon_phase < (MAX_D - 1'b1)))
    );
  end

  // ===========================================================================
  // === Cover properties ===
  // ===========================================================================

  // testplan: cover_zero_duty_held_across_full_period
  // Requires a PERIOD-long consecutive match (2048 cycles at the delivered
  // width = 10), which is unlikely to be witnessed within practical bounded
  // depth at full width even though the behaviour is architecturally
  // reachable. Intended to be witnessed at the reduced-width configuration
  // described in the testplan notes (e.g. width = 3 -> PERIOD = 16); re-check
  // at the delivered width during the prove run.
  cover_zero_duty_held_across_full_period_c: cover property (
      @(posedge clk) disable iff (rst)
      ((D_in == '0) && !pwm_out)[*PERIOD]
  );

  // testplan: cover_full_scale_across_counter_wrap
  cover_full_scale_across_counter_wrap_c: cover property (
      @(posedge clk) disable iff (rst)
      ((mon_phase == MAX_D) && (D_in == MAX_D) && pwm_out)
      ##1 ((mon_phase == '0) && (D_in == MAX_D) && pwm_out)
  );

  // testplan: cover_minimum_width_pulse
  cover_minimum_width_pulse_c: cover property (
      @(posedge clk) disable iff (rst)
      ((D_in == {{width{1'b0}}, 1'b1}) && pwm_out)
      ##1 ((D_in == {{width{1'b0}}, 1'b1}) && !pwm_out)
  );

  // testplan: cover_near_full_scale_two_cycle_low_run
  cover_near_full_scale_two_cycle_low_run_c: cover property (
      @(posedge clk) disable iff (rst)
      ((D_in == (MAX_D - 1'b1)) && (mon_phase == (MAX_D - 1'b1)) && !pwm_out)
      ##1 ((D_in == (MAX_D - 1'b1)) && (mon_phase == MAX_D) && !pwm_out)
  );

  // testplan: cover_period_wrap_with_active_duty
  cover_period_wrap_with_active_duty_c: cover property (
      @(posedge clk) disable iff (rst)
      ((mon_phase == MAX_D) && (D_in != '0) && (D_in != MAX_D))
      ##1 ((mon_phase == '0) && (D_in != '0) && pwm_out)
  );

  // testplan: cover_mid_period_duty_change_truncates_pulse
  cover_mid_period_duty_change_truncates_pulse_c: cover property (
      @(posedge clk) disable iff (rst)
      ((mon_phase != '0) && pwm_out)
      ##1 ($changed(D_in) && !pwm_out && (mon_phase != '0))
  );

endmodule

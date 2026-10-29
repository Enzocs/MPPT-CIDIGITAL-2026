# Formal Testplan — pwm_generator

Throughout this plan:
- `DW = width + 1` — datapath width of `D_in` and the internal phase counter (11 bits by default).
- `PERIOD = 2**(width+1)` — PWM period in `clk` cycles (2048 by default) (source: pwm_generator.sv:8-17).
- `MAX_D = {(width+1){1'b1}}` — the full-scale duty code (11'h7FF = 2047 by default) (source: pwm_generator.sv:10). Note `PERIOD == MAX_D + 1`.
- `mon_phase` — the monitor-side reference phase model described in `## Notes`.

**Clocking and reset convention (applies to every scenario below).** All assertions and covers are evaluated on `posedge clk`, the DUT's single native clock, with `disable iff (rst)`. Reset is harness infrastructure: no scenario names `rst` in its antecedent, precondition, or consequent, and no scenario checks reset sequencing or reset release. Individual scenarios therefore state only their data-side conditions.


## Assumptions (input constraints)


Every value of `D_in` is architecturally legal, including mid-period changes: `D_in` is an unregistered control input consumed directly by the combinational output stage, with no double-buffering or period-boundary latch (source: pwm_generator.sv:4,19-20). A global `$stable(D_in)` assumption would therefore remove exactly the dynamic-update behavior the design is built to support, and would make `duty_update_takes_effect_combinationally` vacuous.

Scenarios that require a steady duty code express that requirement **locally in their own antecedent** (`$stable(D_in)` / a held-value precondition) rather than as a global environment constraint.

## Interface / protocol assertions

- **pwm_out_asserts_only_for_nonzero_duty**
  - **Type:** assertion
  - **Description:** The output must never drive high while the commanded duty is zero. With `D_in == 0` the comparison `counter < D_in` is false for every phase, and the full-scale override does not apply because `MAX_D != 0`, so a high output would be a spurious pulse (source: pwm_generator.sv:19-20). Intentionally redundant — see the redundancy note in `## Notes`.
  - **Stimulus / antecedent:** `pwm_out == 1'b1`
  - **Expected output / consequent:** `D_in != {DW{1'b0}}`
  - **Timing:** Same cycle (combinational output).
  - **Success criteria:** A zero duty command can never produce an output pulse of any width.

- **pwm_out_deasserts_only_below_full_scale**
  - **Type:** assertion
  - **Description:** The full-scale override `(D_in == MAX_D) ? 1'b1 : …` sits at the head of the output ternary and takes priority over the counter comparison, so a low output is only legal when the duty code is below full scale (source: pwm_generator.sv:19). This catches an override that is mis-decoded or ordered after the comparator. Intentionally redundant — see the redundancy note in `## Notes`.
  - **Stimulus / antecedent:** `pwm_out == 1'b0`
  - **Expected output / consequent:** `D_in != MAX_D`
  - **Timing:** Same cycle (combinational output).
  - **Success criteria:** No low cycle is ever observed while the full-scale duty code is applied.

- **nonzero_duty_eventually_produces_a_pulse**
  - **Type:** assertion
  - **Description:** The free-running counter wraps modulo `2**(width+1)` with no stall or terminal-count reload, so any non-zero duty code that is held stable must produce a rising output within one full period — the generator cannot deadlock low (source: pwm_generator.sv:16,19-20).
  - **Stimulus / antecedent:** `D_in != 0` held stable (`$stable(D_in)`). Purely data-side; reset is handled by `disable iff (rst)`.
  - **Expected output / consequent:** `pwm_out == 1'b1` is observed.
  - **Timing:** Bounded — within `PERIOD` cycles of the antecedent. The bound is architectural (one counter wrap), not open-ended, so a bounded window is used rather than unbounded liveness.
  - **Auxiliary logic (minimal):** 1-bit "duty held stable and non-zero" flag; the bounded window is expressed as `##[0:PERIOD]` with no explicit counter.
  - **Success criteria:** A stable non-zero duty always yields at least one rising edge per period.

## End-to-end assertions

- **output_level_matches_phase_comparison**
  - **Type:** assertion
  - **Description:** The core functional contract of the generator: below full scale, the output level at every cycle is exactly the magnitude comparison of the current period phase against the commanded duty, `pwm_out = (counter < D_in)` (source: pwm_generator.sv:19-20). The phase is reconstructible from ports alone, so this is a port-level prediction, not a DUT tap.
  - **Stimulus / antecedent:** `D_in != MAX_D`
  - **Expected output / consequent:** `pwm_out == (mon_phase < D_in)`
  - **Timing:** Same cycle — the output is a continuous assignment with no register stage.
  - **Auxiliary logic (minimal):** `mon_phase` — one `DW`-bit free-running reference phase counter, incremented every `posedge clk`, asynchronously cleared by `rst` (mirrors the DUT time base; `rst` is used here only as the counter's clear, never as a property antecedent).
  - **Success criteria:** The output level agrees with the reference comparison on every cycle of every period.

- **pwm_rises_at_period_wrap**
  - **Type:** assertion
  - **Description:** Each period begins with the high phase. When the counter wraps from all-ones back to zero, the comparison `0 < D_in` becomes true for any non-zero duty, so the output must rise on the wrap boundary with no missing or doubled cycle — this is the property that makes successive periods contiguous (source: pwm_generator.sv:16,19-20).
  - **Stimulus / antecedent:** `mon_phase == 0` and `D_in != 0`.
  - **Expected output / consequent:** `pwm_out == 1'b1`
  - **Timing:** Same cycle as the zero phase.
  - **Modelling complexity:** HIGH — shares the single `DW`-bit `mon_phase` counter with the other end-to-end scenarios; no additional state.
  - **Success criteria:** Every period starts high whenever a non-zero duty is commanded.

- **pwm_falls_when_phase_reaches_duty**
  - **Type:** assertion
  - **Description:** The high phase ends exactly at the commanded count. Because the comparator is strict less-than, the output must be low on the first cycle where the phase equals the duty code, which is what makes the measured high time equal `D_in` cycles per period rather than `D_in + 1` (source: pwm_generator.sv:20). Paired with `pwm_rises_at_period_wrap`, this pins the pulse-width contract without a separate run-length counter.
  - **Stimulus / antecedent:** `mon_phase == D_in` and `D_in != MAX_D`.
  - **Expected output / consequent:** `pwm_out == 1'b0`
  - **Timing:** Same cycle as the matching phase.
  - **Auxiliary logic (minimal):** reuses `mon_phase` (`DW`-bit reference phase counter).
  - **Success criteria:** The pulse terminates at exactly the commanded count, giving a high time of `D_in` cycles.

- **duty_update_takes_effect_combinationally**
  - **Type:** assertion
  - **Description:** `D_in` is unregistered and feeds the comparator directly, so a duty update takes effect in the same cycle it is applied, with no end-of-period latching and no pipeline latency. A mid-pulse decrease truncates the in-flight pulse and a mid-period increase re-asserts the output immediately (source: pwm_generator.sv:4,19-20). This is the control path an upstream MPPT controller relies on.
  - **Stimulus / antecedent:** `$changed(D_in)`
  - **Expected output / consequent:** `pwm_out` already reflects the **new** `D_in` in the same cycle — i.e. `pwm_out == ((D_in == MAX_D) || (mon_phase < D_in))`.
  - **Timing:** Zero latency — same cycle as the `D_in` change.
  - **Auxiliary logic (minimal):** reuses `mon_phase` (`DW`-bit reference phase counter).
  - **Success criteria:** No duty update is deferred to a period boundary or delayed by a register stage.

## Corner-case assertions

- **zero_duty_forces_constant_low**
  - **Description:** Corner case 1 — the zero duty code. The strict less-than comparator (rather than less-than-or-equal) guarantees that `D_in == 0` yields no pulse at all, so 0% duty is exactly representable and the generator has a true off state (source: pwm_generator.sv:19-20).
  - **Stimulus / antecedent:** `D_in == {DW{1'b0}}`
  - **Expected output / consequent:** `pwm_out == 1'b0`
  - **Timing:** Same cycle, for every phase of the period.
  - **Auxiliary logic (minimal):** none
  - **Success criteria:** Zero duty never produces even a one-cycle pulse.

- **full_scale_duty_forces_constant_high**
  - **Type:** assertion
  - **Description:** Corner case 2 — the full-scale override. When `D_in == MAX_D` the dedicated equality compare bypasses the counter entirely and forces a constant-high output, producing a true 100% duty instead of the `MAX_D/PERIOD` duty the bare comparator would give. Specifically, the bare comparator `mon_phase < MAX_D` would go low for one cycle at the top phase (`mon_phase == MAX_D`); the override suppresses exactly that notch (source: pwm_generator.sv:10,19).
  - **Stimulus / antecedent:** `D_in == MAX_D`
  - **Expected output / consequent:** `pwm_out == 1'b1` — including at `mon_phase == MAX_D`, where the bare comparator would have produced a low cycle.
  - **Timing:** Same cycle, for every phase including the counter wrap.
  - **Auxiliary logic (minimal):** none (the consequent is a constant; `mon_phase` is referenced only to describe the suppressed notch, not required by the check).
  - **Success criteria:** Zero low samples are observed across complete periods at full scale.

- **minimum_pulse_is_single_cycle**
  - **Type:** assertion
  - **Description:** Corner case 3 — the smallest resolvable pulse. With `D_in == 1` the output must be high only while the phase is zero and low for the remaining `PERIOD-1` cycles, confirming a one-clock minimum pulse width with no dead-time or minimum-pulse filtering (source: pwm_generator.sv:19-20).
  - **Stimulus / antecedent:** `D_in == 1`
  - **Expected output / consequent:** `pwm_out == (mon_phase == 0)`
  - **Timing:** Same cycle, evaluated across the period.
  - **Auxiliary logic (minimal):** reuses `mon_phase` (`DW`-bit reference phase counter).
  - **Success criteria:** Exactly one high cycle per period at the minimum non-zero duty code.

- **near_full_scale_has_two_low_cycles**
  - **Description:** Proves the saturation override does **not** trigger one code early. At `D_in == MAX_D - 1` the override does not apply, so the plain strict-less-than comparator governs: the output is high for phases `0 .. MAX_D-2` (that is `MAX_D - 1` cycles) and low for **two** phases, `MAX_D - 1` and `MAX_D`, because the period is `PERIOD = MAX_D + 1` cycles (source: pwm_generator.sv:19-20). If the override fired one code early the output would instead be constantly high, which this assertion detects.
  - **Stimulus / antecedent:** `D_in == MAX_D - 1`
  - **Expected output / consequent:** `pwm_out == (mon_phase < (MAX_D - 1))` — i.e. low exactly at `mon_phase ∈ {MAX_D-1, MAX_D}`.
  - **Timing:** Same cycle, evaluated across the period.
  - **Auxiliary logic (minimal):** reuses `mon_phase` (`DW`-bit reference phase counter).
  - **Success criteria:** Exactly two low cycles per period immediately below full scale, confirming the override boundary is at `MAX_D` and not lower.

- **cover_zero_duty_held_across_full_period**
  - **Type:** cover
  - **Description:** Witness that the 0% duty corner is reachable and sustained — `D_in == 0` held across a complete period with the output continuously low.
  - **Signals:** `D_in`, `pwm_out`

- **cover_full_scale_across_counter_wrap**
  - **Type:** cover
  - **Description:** Witness the saturation path across the counter rollover — `D_in == MAX_D` held while `mon_phase` passes through the top phase `MAX_D` and wraps to 0, with `pwm_out` continuously high. This is precisely the notch the override suppresses.
  - **Signals:** `D_in`, `pwm_out`

- **cover_minimum_width_pulse**
  - **Type:** cover
  - **Description:** Witness a single-cycle output pulse (`D_in == 1`), confirming the minimum pulse width is reachable.
  - **Signals:** `D_in`, `pwm_out`

- **cover_near_full_scale_two_cycle_low_run**
  - **Type:** cover
  - **Description:** Witness the **two**-cycle low run at `D_in == MAX_D - 1`, spanning phases `MAX_D-1` and `MAX_D`. Together with `cover_full_scale_across_counter_wrap` this distinguishes the override boundary: one code below full scale the output dips low twice, at full scale it never dips.
  - **Signals:** `D_in`, `pwm_out`

- **cover_period_wrap_with_active_duty**
  - **Type:** cover
  - **Description:** Corner case 4 — witness the counter rollover from all-ones to zero while a mid-scale duty is active, with the output rising on the wrap boundary.
  - **Signals:** `D_in`, `pwm_out`

- **cover_mid_period_duty_change_truncates_pulse**
  - **Type:** cover
  - **Description:** Corner case 5 — witness `D_in` dropping below the current phase while the output is high, truncating the in-flight pulse in the same cycle.
  - **Signals:** `D_in`, `pwm_out`

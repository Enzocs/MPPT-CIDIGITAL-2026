# Formal Testplan — duty_controller

Throughout this plan:
- `DW = width + 1` — width of the duty accumulator and of `D_out` (11 bits by default).
- `MAX_D = {(width+1){1'b1}}` — upper saturation bound (2047 by default) (source: dutty_controller.sv:24).
- `DELTA = 256` — the step size. `delta_d` is declared `[width-1:0]` but hard-wired to the literal `10'd256` because the intended `banco_de_dados` lookup is commented out (source: dutty_controller.sv:22,29).

**No auxiliary state is required anywhere in this plan.** `D_out` is a continuous assignment straight from the accumulator register `D_older` (`assign D_out = D_older`, source: dutty_controller.sv:32), so the DUT's entire state is directly observable at the output port. Every scenario below is therefore expressed as a relation between `$past(D_out)` and `D_out`, with no shadow register, no reference model, and no DUT-internal tap. `$past` of an output port is an observation of port history, not modelling state.

**Clocking and reset convention (applies to every scenario below).** All assertions and covers are evaluated on `posedge clk`, the DUT's single native clock, with `disable iff (rst)`. `clk` is the only clock and its active edge is the rising edge; `rst` is **active-high and asynchronous**, appearing as `posedge rst` in the sensitivity list and tested as `if (rst)` — hence the bare `disable iff (rst)` term rather than `disable iff (!rst)`. Reset is harness infrastructure: no scenario names `rst` in an antecedent, precondition, or consequent, and no scenario checks reset sequencing or reset release.

**Command encoding**:

| `Dc_in` | Action |
|---|---|
| `2'b00` | Decrease by `DELTA`, clamped at 0 |
| `2'b01` | Increase by `DELTA`, clamped at `MAX_D` |
| `2'b10` | Hold |
| `2'b11` | Reserved — falls through the `default` arm, also holds |



## Assumptions (input constraints)


Every combination of `valid_input` and `Dc_in` is architecturally legal and fully decoded. The `case` statement has an explicit `default` arm covering `2'b10` and `2'b11` (source: dutty_controller.sv:57-59), and the `else` branch covers `valid_input == 0` (source: dutty_controller.sv:62-64), so no input pattern is illegal or undefined. In particular the reserved code `2'b11` must **not** be assumed away — the plan asserts that it is treated as a safe no-op, which is a real obligation (see `reserved_command_is_a_safe_nop`).

The Counter pattern suggests `assume_bounded_continuous_increment` / `assume_bounded_continuous_decrement` to aid convergence. These are **deliberately not adopted**: every assertion here is a single-cycle `|=>` step relation with no liveness obligation and no unbounded window, so there is nothing for them to help converge, and they would exclude the legal back-to-back command stream that `cover_sustained_ramp_to_saturation` exists to witness.

## Interface / protocol assertions

- **duty_changes_only_on_accepted_command**
  - **Type:** assertion
  - **Description:** The accumulator may only move in response to an accepted step command. A change in `D_out` must be attributable to the previous cycle having presented `valid_input` together with an arithmetic opcode (`2'b00` or `2'b01`); any other combination leaves the register reloaded with its own value (source: dutty_controller.sv:37,57-64).
  - **Stimulus / antecedent:** `$changed(D_out)`
  - **Expected output / consequent:** `$past(valid_input) && ($past(Dc_in) == 2'b00 || $past(Dc_in) == 2'b01)`
  - **Timing:** Same cycle, referencing the previous cycle's inputs.
  - **Auxiliary logic (minimal):** none
  - **Success criteria:** The duty output never moves spontaneously, on a hold code, on the reserved code, or while the qualifier is low.

- **duty_holds_while_qualifier_low**
  - **Type:** assertion
  - **Description:** Counter-pattern `count_stability_when_disabled`. With `valid_input` low the command is not consumed and the register reloads its own value, so the duty output is bit-exact stable regardless of how `Dc_in` toggles (source: dutty_controller.sv:37,62-64).
  - **Stimulus / antecedent:** `!valid_input`
  - **Expected output / consequent:** `D_out` is unchanged on the next cycle — `$stable(D_out)` at `t+1`.
  - **Timing:** Next cycle (registered accumulator, one-cycle command-to-output latency).
  - **Auxiliary logic (minimal):** none
  - **Success criteria:** An unqualified command can never perturb the duty value.

- **duty_step_is_bounded_by_delta**
  - **Type:** assertion
  - **Description:** A single accepted command can move the accumulator by at most one step. This is the blanket anti-wrap and anti-jump guard: it holds across both the arithmetic and the saturating paths, because a clamp always lands strictly between the old value and the respective bound. It catches a wrap-around (which would appear as a near-`MAX_D` jump) independently of the per-direction scenarios below (source: dutty_controller.sv:40-56).
  - **Stimulus / antecedent:** any cycle
  - **Expected output / consequent:** at `t+1`, `(D_out >= $past(D_out)) ? (D_out - $past(D_out) <= DELTA) : ($past(D_out) - D_out <= DELTA)`
  - **Timing:** Next cycle.
  - **Auxiliary logic (minimal):** none
  - **Success criteria:** No single cycle ever moves the duty value by more than `DELTA` in either direction.

## End-to-end assertions

- **increment_adds_step_below_threshold**
  - **Type:** assertion
  - **Description:** Counter-pattern `increment_correctness`. An accepted increase command below the saturation threshold adds exactly one step. The RTL guard is a strict `>` against `MAX_D - delta_d`, so the arithmetic path is taken for all `D_older <= MAX_D - DELTA` (source: dutty_controller.sv:49-55).
  - **Stimulus / antecedent:** `valid_input && (Dc_in == 2'b01) && (D_out <= MAX_D - DELTA)`
  - **Expected output / consequent:** `D_out == $past(D_out) + DELTA`
  - **Timing:** Next cycle.
  - **Auxiliary logic (minimal):** none
  - **Success criteria:** Every sub-threshold increase advances the duty by exactly `DELTA`, with no off-by-one at the boundary.

- **increment_saturates_at_max**
  - **Type:** assertion
  - **Description:** Counter-pattern `saturating_behavior` (increase direction). Above the threshold the clamp path loads `MAX_D` rather than allowing the 11-bit add to wrap through zero (source: dutty_controller.sv:50-51).
  - **Stimulus / antecedent:** `valid_input && (Dc_in == 2'b01) && (D_out > MAX_D - DELTA)`
  - **Expected output / consequent:** `D_out == MAX_D`
  - **Timing:** Next cycle.
  - **Auxiliary logic (minimal):** none
  - **Success criteria:** The increase path never wraps; it pins at the ceiling.

- **decrement_subtracts_step_above_threshold**
  - **Type:** assertion
  - **Description:** Counter-pattern `decrement_correctness`. An accepted decrease command at or above one step subtracts exactly one step. The RTL guard is a strict `<` against `delta_d`, so the arithmetic path is taken for all `D_older >= DELTA` (source: dutty_controller.sv:44-46).
  - **Stimulus / antecedent:** `valid_input && (Dc_in == 2'b00) && (D_out >= DELTA)`
  - **Expected output / consequent:** `D_out == $past(D_out) - DELTA`
  - **Timing:** Next cycle.
  - **Auxiliary logic (minimal):** none
  - **Success criteria:** Every above-threshold decrease retreats by exactly `DELTA`, with no off-by-one at the boundary.

- **decrement_clamps_at_zero**
  - **Type:** assertion
  - **Description:** Counter-pattern `saturating_behavior` (decrease direction). Below one step the clamp path loads 0 rather than allowing the subtraction to borrow and wrap to a near-`MAX_D` value (source: dutty_controller.sv:41-43).
  - **Stimulus / antecedent:** `valid_input && (Dc_in == 2'b00) && (D_out < DELTA)`
  - **Expected output / consequent:** `D_out == '0`
  - **Timing:** Next cycle.
  - **Auxiliary logic (minimal):** none
  - **Success criteria:** The decrease path never underflows; it pins at the floor.

- **hold_command_preserves_duty**
  - **Type:** assertion
  - **Description:** An accepted hold command (`2'b10`) is a true no-op: the `default` arm reloads the register with its own value, so no partial update occurs even though the command was qualified (source: dutty_controller.sv:57-59).
  - **Stimulus / antecedent:** `valid_input && (Dc_in == 2'b10)`
  - **Expected output / consequent:** `D_out == $past(D_out)`
  - **Timing:** Next cycle.
  - **Auxiliary logic (minimal):** none
  - **Success criteria:** The explicit hold code never perturbs the duty value.

## Corner-case assertions

- **max_endpoint_is_sticky_under_increase**
  - **Type:** assertion
  - **Description:** Corner case 3 (ceiling half). Once parked at `MAX_D`, repeated increase commands leave the value pinned — the accumulator has no wrap path off the endpoint (source: dutty_controller.sv:40-56). Logically implied by `increment_saturates_at_max`, but stated separately because stickiness under a *sustained* stream is the behaviour the MPPT loop depends on.
  - **Stimulus / antecedent:** `valid_input && (Dc_in == 2'b01) && (D_out == MAX_D)`
  - **Expected output / consequent:** `D_out == MAX_D`
  - **Timing:** Next cycle.
  - **Auxiliary logic (minimal):** none
  - **Success criteria:** The ceiling is an absorbing state for increase commands.

- **zero_endpoint_is_sticky_under_decrease**
  - **Type:** assertion
  - **Description:** Corner case 3 (floor half). Once parked at 0, repeated decrease commands leave the value pinned (source: dutty_controller.sv:41-43). Logically implied by `decrement_clamps_at_zero`; stated separately for the same reason as the ceiling case.
  - **Stimulus / antecedent:** `valid_input && (Dc_in == 2'b00) && (D_out == '0)`
  - **Expected output / consequent:** `D_out == '0`
  - **Timing:** Next cycle.
  - **Auxiliary logic (minimal):** none
  - **Success criteria:** The floor is an absorbing state for decrease commands.

- **endpoint_is_escapable_by_opposite_command**
  - **Type:** assertion
  - **Description:** Corner case 3 (escape half) — the liveness-flavoured complement of the two stickiness checks. A saturated accumulator must not be permanently stuck: the opposite command moves it off the endpoint by exactly one step on the very next cycle (`MAX_D -> MAX_D - DELTA`, since `MAX_D >= DELTA`) (source: dutty_controller.sv:44-46). Without this check, an RTL that clamped unconditionally in both directions would still satisfy every other assertion in this plan.
  - **Stimulus / antecedent:** `valid_input && (Dc_in == 2'b00) && (D_out == MAX_D)`
  - **Expected output / consequent:** `D_out == MAX_D - DELTA`
  - **Timing:** Next cycle.
  - **Auxiliary logic (minimal):** none
  - **Success criteria:** Saturation is recoverable, not a trap state.

- **cover_increment_at_exact_threshold**
  - **Type:** cover
  - **Description:** Corner case 1. Witness the increase command applied at exactly `MAX_D - DELTA` (1791), where the strict `>` comparison is false so the *arithmetic* path runs and lands precisely on `MAX_D`. This is the off-by-one-sensitive boundary.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

- **cover_increment_one_above_threshold**
  - **Type:** cover
  - **Description:** Corner case 1. Witness the increase command applied one LSB above the threshold, where the *clamp* path is taken instead. Together with the previous cover this pins which side of the comparison each value falls on.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

- **cover_decrement_at_exact_step**
  - **Type:** cover
  - **Description:** Corner case 2. Witness the decrease command applied at exactly `DELTA` (256), where the strict `<` comparison is false so the *subtract* path runs and lands precisely on 0.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

- **cover_decrement_below_step**
  - **Type:** cover
  - **Description:** Corner case 2. Witness the decrease command applied below one step, where the *clamp* path loads 0 directly.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

- **cover_sustained_ramp_to_saturation**
  - **Type:** cover
  - **Description:** End-to-end functionality 1 and corner case 7. Witness a back-to-back stream of accepted increase commands driving the accumulator from 0 all the way to `MAX_D`, at one command per clock with no backpressure.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

- **cover_sustained_ramp_to_zero**
  - **Type:** cover
  - **Description:** End-to-end functionality 2. Witness a back-to-back stream of accepted decrease commands driving the accumulator from `MAX_D` down to the 0 floor.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

- **cover_alternating_commands_oscillate**
  - **Type:** cover
  - **Description:** Corner case 7. Witness `valid_input` held high with `Dc_in` alternating between increase and decrease on consecutive clocks, producing a +/-`DELTA` oscillation — the maximum-rate mixed-command case.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

- **cover_command_ignored_while_qualifier_low**
  - **Type:** cover
  - **Description:** End-to-end functionality 3. Witness an arithmetic opcode presented while `valid_input` is low, with the duty value provably unchanged across that cycle.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

- **cover_hold_command_accepted**
  - **Type:** cover
  - **Description:** Witness the explicit hold encoding `2'b10` actually presented with `valid_input` high, confirming `hold_command_preserves_duty` is exercised rather than passing vacuously. Every other command class has such a witness; this closes the gap.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

- **cover_max_endpoint_held_under_repeated_increase**
  - **Type:** cover
  - **Description:** Corner case 3 (ceiling stickiness). Witness `valid_input` with `Dc_in == 2'b01` applied while the accumulator is **already parked** at `MAX_D`, sustained across at least two consecutive cycles with `D_out` pinned. Distinct from `cover_sustained_ramp_to_saturation`, which witnesses the approach to the ceiling rather than residence at it.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

- **cover_zero_endpoint_held_under_repeated_decrease**
  - **Type:** cover
  - **Description:** Corner case 3 (floor stickiness). The symmetric witness: `Dc_in == 2'b00` applied while already parked at 0, sustained across at least two consecutive cycles with `D_out` pinned at 0.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

- **cover_escape_from_max_endpoint**
  - **Type:** cover
  - **Description:** Corner case 3 (escape half). Witness the accumulator parked at `MAX_D` and then stepping off to `MAX_D - DELTA` on the next cycle under a decrease command, proving saturation is recoverable rather than a trap state.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

- **cover_escape_from_zero_endpoint**
  - **Type:** cover
  - **Description:** Corner case 3 (escape half, floor). The symmetric witness: parked at 0, then stepping up to `DELTA` on the next cycle under an increase command.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

## Error-scenario assertions

- **reserved_command_is_a_safe_nop**
  - **Type:** assertion
  - **SOIL category:** Functional
  - **Black-box feasibility:** HIGH
  - **Targets output(s):** `D_out`
  - **Description:** Error scenario 1 / corner case 4. The RTL command table marks `2'b11` as undefined (`--------`, source: dutty_controller.sv:14-20), and the design has no error output to report it. The `default` arm must therefore absorb it as a clean no-operation: the duty value is reloaded with itself, with no partial update and no corruption. This is the checkable half of the error scenario — the detect-and-report half does not exist in this DUT, by design.
  - **Stimulus / antecedent:** `valid_input && (Dc_in == 2'b11)`
  - **Expected output / consequent:** `D_out == $past(D_out)`
  - **Timing:** Next cycle.
  - **Auxiliary logic (minimal):** none
  - **Modelling complexity:** LOW — none
  - **Success criteria:** The reserved encoding is silently and safely ignored rather than causing an undefined update.

- **cover_reserved_command_accepted**
  - **Type:** cover
  - **Description:** Witness the reserved encoding `2'b11` actually presented with `valid_input` high, confirming the no-op path is exercised rather than vacuously true.
  - **Signals:** `valid_input`, `Dc_in`, `D_out`

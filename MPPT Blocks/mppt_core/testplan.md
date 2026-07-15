# Assumptions (Input Constraints)

## `valid_signal_is_single_cycle_pulse`

**Description**: Legal transactions present `valid_signal` as a one-cycle pulse so the DUT's rising-edge detector starts exactly one MPPT evaluation cycle. The RTL detects the valid pulse as `valid_pulse = valid_signal & ~valid_d`, where `valid_d` is registered on `clk`.
**Signals**: `valid_signal`
**Notes**:
```systemverilog
$rose(valid_signal) |-> ##1 !valid_signal;
```

---

## `sample_inputs_stable_during_evaluation`

**Description**: A legal MPPT sample holds `V` and `I` stable long enough for the controller sequence to compare the current power and voltage against the stored previous sample. The RTL computes `P_new = V * I` combinationally and reuses it throughout the FSM evaluation sequence.
**Signals**: `V`, `I`, `valid_signal`
**Notes**: After a `valid_signal` pulse, hold `V` and `I` stable for the bounded evaluation window (approximately four cycles). This is an input-only constraint.

---

# Interface Assertions

## `reset_forces_idle_outputs`

**Type**: Assertion
**Targets**: `Dc_out`, `valid_end_cycle`
**Description**: Asserting active-high `rst` asynchronously clears the edge detector and returns the FSM to the `IDLE` state. Since `Dc_out` defaults to `2'b10` outside the action states and `valid_end_cycle` is asserted only during the `END` state, reset should force the observable idle output pattern.
**Stimulus / Antecedent**:
```systemverilog
rst == 1'b1
```
**Expected Consequent**:
```systemverilog
Dc_out == 2'b10
valid_end_cycle == 1'b0
```
**Timing**: Same cycle (asynchronous reset) and remains true while reset is asserted.
**Auxiliary Logic**: None.
**Success Criteria**: Reset always presents the idle/no-action output state and suppresses completion.

---

## `no_completion_without_accepted_valid`

**Type**: Assertion
**Targets**: `valid_end_cycle`
**Description**: `valid_end_cycle` shall not assert unless a previously accepted `valid_signal` rising edge has started an MPPT evaluation. The DUT leaves `IDLE` only on `valid_pulse`.
**Stimulus / Antecedent**: No pending transaction exists, and no accepted `valid_signal` rising edge has occurred during the bounded observation window.
**Expected Consequent**:
```systemverilog
valid_end_cycle == 1'b0
```
**Timing**: Continuous outside the one-to-four-cycle transaction window.
**Auxiliary Logic**: 1-bit pending flag and a 3-bit transaction-age counter started by `$rose(valid_signal)` and cleared by `valid_end_cycle`.
**Success Criteria**: The completion flag never asserts spuriously during idle operation.

---

## `valid_end_single_cycle_pulse`

**Type**: Assertion
**Targets**: `valid_end_cycle`
**Description**: Completion is encoded by the one-cycle `END` state because `valid_end_cycle = (state == END)`. The FSM immediately transitions from `END` back to `IDLE`.
**Stimulus / Antecedent**:
```systemverilog
valid_end_cycle == 1'b1
```
**Expected Consequent**:
```systemverilog
##1 !valid_end_cycle
```
**Timing**: One cycle.
**Auxiliary Logic**: None.
**Success Criteria**: Completion is a one-cycle pulse rather than a level.

## `equal_power_completes_without_action`

**Type**: Assertion
**Targets**: `valid_end_cycle`, `Dc_out`
**Description**: When a newly accepted sample has the same computed power as the stored previous power, the FSM transitions directly from `IDLE` to `END` without changing the duty command from its default value. This matches the Perturb and Observe (P&O) algorithm, where no perturbation is required when the measured power does not change.
**Stimulus / Antecedent**: Accepted `valid_signal` pulse when the auxiliary shadow register satisfies `prev_power == V * I`.
**Expected Consequent**: `valid_end_cycle` asserts during the bounded completion cycle and `Dc_out == 2'b10`.
**Timing**: One cycle after the accepted sample, using the monitor's registered transaction-age counter.
**Auxiliary Logic**: Shadow `prev_power`, updated when `valid_end_cycle` completes; pending flag and transaction-age counter.
**Success Criteria**: Equal-power samples complete without issuing action codes `2'b00` or `2'b01`.

---

## `same_direction_reference_increase_code`

**Type**: Assertion
**Targets**: `Dc_out`
**Description**: When power and voltage change in the same direction, the controller perturbs the reference voltage in the same direction. The RTL maps both `(curr_power > prev_power && V > prev_V)` and `(curr_power < prev_power && V < prev_V)` to the `V_ref_G` state, where `Dc_out == 2'b00`.
**Stimulus / Antecedent**: Accepted sample satisfying `(curr_power > prev_power && V > prev_V)` or `(curr_power < prev_power && V < prev_V)`.
**Expected Consequent**: `Dc_out == 2'b00` during the bounded action cycle before completion.
**Timing**: Second cycle after the accepted sample; completion follows one cycle later.
**Auxiliary Logic**: Shadow `prev_power`, shadow `prev_V`, and transaction-age counter.
**Success Criteria**: Same-direction power and voltage changes always produce the reference-increase command.

---

## `same_direction_sequence_completes`

**Type**: Assertion
**Targets**: `valid_end_cycle`
**Description**: After taking the same-direction branch, the FSM must progress through the action state and eventually reach `END`, asserting `valid_end_cycle`.
**Stimulus / Antecedent**: Same antecedent as `same_direction_reference_increase_code`.
**Expected Consequent**: `valid_end_cycle == 1'b1`.
**Timing**: Third cycle after the accepted sample.
**Auxiliary Logic**: Reuse the shadow registers and transaction-age counter.
**Success Criteria**: The same-direction branch cannot deadlock before completion.

---

## `opposite_direction_reference_decrease_code`

**Type**: Assertion
**Targets**: `Dc_out`
**Description**: When power and voltage change in opposite directions, the controller perturbs the reference voltage in the opposite direction. The RTL maps `(curr_power > prev_power && V < prev_V)` and `(curr_power < prev_power && V > prev_V)` to the `V_ref_L` state, where `Dc_out == 2'b01`.
**Stimulus / Antecedent**: Accepted sample satisfying `(curr_power > prev_power && V < prev_V)` or `(curr_power < prev_power && V > prev_V)`.
**Expected Consequent**: `Dc_out == 2'b01` during the bounded action cycle before completion.
**Timing**: Second cycle after the accepted sample; completion follows one cycle later.
**Auxiliary Logic**: Shadow `prev_power`, shadow `prev_V`, and transaction-age counter.
**Success Criteria**: Opposite-direction power and voltage changes always produce the reference-decrease command.

---

## `opposite_direction_sequence_completes`

**Type**: Assertion
**Targets**: `valid_end_cycle`
**Description**: After taking the opposite-direction branch, the FSM must progress through the action state and eventually reach `END`, asserting `valid_end_cycle`.
**Stimulus / Antecedent**: Same antecedent as `opposite_direction_reference_decrease_code`.
**Expected Consequent**: `valid_end_cycle == 1'b1`.
**Timing**: Third cycle after the accepted sample.
**Auxiliary Logic**: Reuse the shadow registers and transaction-age counter.
**Success Criteria**: The opposite-direction branch cannot deadlock before completion.

## `ambiguous_delta_keeps_default_command`

**Type**: Assertion
**Targets**: `Dc_out`
**Description**: If power changes but voltage remains unchanged relative to the stored previous voltage, neither directional P&O branch condition is satisfied. The FSM therefore transitions from `P_DIFF` directly to `END` without entering either `V_ref_L` or `V_ref_G`, leaving the duty command at its default value.
**Stimulus / Antecedent**: Accepted `valid_signal` pulse where `curr_power != prev_power` and `V == prev_V`.
**Expected Consequent**: `Dc_out == 2'b10` throughout the bounded transaction; no action code is emitted.
**Timing**: Bounded over the two-cycle `P_DIFF` → `END` path.
**Auxiliary Logic**: Shadow `prev_power`, shadow `prev_V`, pending flag, and transaction-age counter.
**Success Criteria**: An ambiguous voltage delta never generates a false reference increase or decrease command.

---

## `ambiguous_delta_completes`

**Type**: Assertion
**Targets**: `valid_end_cycle`
**Description**: Even when the voltage comparison cannot select either directional branch, the FSM must still terminate by taking the default `P_DIFF` → `END` path and asserting `valid_end_cycle`.
**Stimulus / Antecedent**: Same antecedent as `ambiguous_delta_keeps_default_command`.
**Expected Consequent**: `valid_end_cycle == 1'b1`.
**Timing**: Second cycle after the accepted sample.
**Auxiliary Logic**: Reuse the shadow registers and transaction-age counter from `ambiguous_delta_keeps_default_command`.
**Success Criteria**: The controller always completes the transaction, even when the voltage comparison is ambiguous.

---

## `back_to_back_samples_use_previous_completion_sample`

**Type**: Assertion
**Targets**: `Dc_out`, `valid_end_cycle`
**Description**: A sample accepted after a completed transaction shall be compared against the voltage and power captured at the previous completed transaction. The RTL updates `prev_V` and `prev_power` only during the `END` state, so each new transaction must use the most recently completed sample as its comparison baseline.
**Stimulus / Antecedent**: Drive one legal transaction to completion. Then drive a second legal `valid_signal` pulse with `V` and `I` selected so that the relationship between the second sample and the first completed sample produces a known directional branch.
**Expected Consequent**: The second transaction emits the command corresponding to the relationship with the first completed sample (`Dc_out == 2'b00` for same-direction deltas or `Dc_out == 2'b01` for opposite-direction deltas), followed by `valid_end_cycle == 1'b1`.
**Timing**: During the second transaction, the action code is produced on the second cycle after the accepted sample, and `valid_end_cycle` asserts on the third cycle.
**Auxiliary Logic**: Shadow `prev_power` and `prev_V` updated only when `valid_end_cycle` is observed, a two-transaction phase flag, and a transaction-age counter.
**Success Criteria**: Consecutive transactions always use the previous completed sample as the comparison baseline rather than reset values or the current sample itself.

# Signal Processing Verification Test Plan

## 1. Overview and Scope

This document details the verification plan for the `signal_processing` RTL module. The Design Under Test (DUT) is a signal processing module, its function is to receive voltage and current samples, apply a four-sample moving average filter, and provide filtered outputs with a valid pulse indicating that a new filtered value is available.

**Input Signals:** `clk`, `rst_n`, `v_sample_out`, `i_sample_out`, `sample_valid`
**Output Signals:** `v_signal_out`, `i_signal_out`, `signal_valid`

## 2. Verification Strategy

The verification strategy is based on RTL simulation using a self-checking testbench combined with SystemVerilog Assertions (SVA). Functional correctness is verified by comparing DUT outputs against a reference moving-average model implemented inside the testbench. Assertions are used to verify protocol timing, reset behavior and output validity.

## 3. Test Cases

### 3.1 Reset and Inicialization

**objective:** Ensure that the reset initializes correctly.
* **Stimulus:** Assert and de-assert `rst_n` (active-low).
* **Expected Result:**
  * FSM returs to `STATE_IDLE`;
  * `v_signal_out = 16'h0000`;
  * `i_signal_out = 16'h0000`;
  * `signal_valid = 1'b0`;
  * `v_sum = 18'h00000`;
  * `i_sum = 18'h00000`;
  * All positions of `v_reg` and `v_reg` goes to `16'h0000`.

### 3.2 Single Sample Processing

**objective:** Check the first sample.
* **Stimulus:** 
  * Assert `sample_valid` (active-high);
  * Assign one sample ​​to `v_sample_out` and `i_sample_out`.
* **Expected Result:**
  * `v_signal_out = v_sample_out / 4`;
  * `i_signal_out = i_sample_out / 4`.
  
### 3.3 Pipeline Filling

**objective:** Check the pipeline filling.
* **Stimulus:** 
  * Assert `sample_valid` (active-high);
  * Assign four samples ​​to `v_sample_out` and `i_sample_out`.
* **Expected Result:**
  * First sample: 
    * `v_signal_out = v_sample_1 / 4`;
    * `i_signal_out = i_sample_1 / 4`;
  * Second sample: 
    * `v_signal_out = (v_sample_1 + v_sample_2) / 4`;
    * `i_signal_out = (i_sample_1 + i_sample_2) / 4`;
  * Third sample: 
    * `v_signal_out = (v_sample_1 + v_sample_2 + v_sample_3) / 4`;
    * `i_signal_out = (i_sample_1 + i_sample_2 + i_sample_3) / 4`;
  * Fourth sample: 
    * `v_signal_out = (v_sample_1 + v_sample_2 + v_sample_3 + v_sample_4) / 4`;
    * `i_signal_out = (i_sample_1 + i_sample_2 + i_sample_3 + i_sample_4) / 4`.

### 3.4 Sliding Window Verification

**objective:** Check the disposal of the oldest sample.
* **Stimulus:** 
  * Assign five samples ​​to `v_sample_out` and `i_sample_out`.
* **Expected Result:**
  * Discard the oldest sample, so that the fifth sample is: 
    * `v_signal_out = (v_sample_2 + v_sample_3 + v_sample_4 + v_sample_5) / 4`;
    * `i_signal_out = (i_sample_2 + i_sample_3 + i_sample_4 + i_sample_5) / 4`.

### 3.5 Constant Inputs

**objective:** Check stability.
* **Stimulus:** 
  * Assign four equal samples ​​to `v_sample_out` and `i_sample_out`.
* **Expected Result:**
  * The final result must be equal to the input: 
    * `v_signal_out = v_sample_out`;
    * `i_signal_out = i_sample_out`.

### 3.6 Increasing Ramp

**objective:** Check the rising average.
* **Stimulus:** 
  * Assign rising samples ​​to `v_sample_out` and `i_sample_out`.
* **Expected Result:**
  * The final result must increase and correspond to a known result.

### 3.7 Decreasing Ramp

**objective:** Check the declining average.
* **Stimulus:** 
  * Assign declining samples ​​to `v_sample_out` and `i_sample_out`.
* **Expected Result:**
  * The final result must decrease and correspond to a known result.

### 3.8 Maximum Values

**objective:** Check overflow.
* **Stimulus:** 
  * Assign maximum values ​​to `v_sample_out` and `i_sample_out`.
* **Expected Result:**
  * The final result must correspond to a maximum known value;
  * The internal sum must not overflow.

### 3.9 Minimum Values

**objective:** Check zeros.
* **Stimulus:** 
  * Assign zero ​​to `v_sample_out` and `i_sample_out`.
* **Expected Result:**
  * The final result must be zero.

### 3.10 Random Samples

**objective:** Check reliability and functionality.
* **Stimulus:** 
  * Assign random values ​​to `v_sample_out` and `i_sample_out`.
* **Expected Result:**
  * The result must be equal to the one calculated automatically.

### 3.11 `signal_valid` Timing

**objective:** Ensure protocol.
* **Stimulus:** 
  * Assign values ​​to `v_sample_out` and `i_sample_out`.
* **Expected Result:**
  * Single pulse;
  * Occurs after processing;
  * Never occurs spontaneously.

### 3.12 Consecutive Transactions

**objective:** Check that consecutive samples are not lost.
* **Stimulus:** 
  * Send multiple consecutive samples ​​to `v_sample_out` and `i_sample_out`.
* **Expected Result:**
  * No samples lost.
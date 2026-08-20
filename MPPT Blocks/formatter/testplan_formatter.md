# Sample Formatter Verification Test Plan

## 1. Overview and Scope

This document details the verification plan for the `sample_formatter` RTL module. The Design Under Test (DUT) receives 16-bit SPI frames containing a 4-bit Channel ID and a 12-bit ADC sample. The module extracts both fields, zero-extends the ADC sample to 16 bits, routes the formatted sample to the appropriate output according to the Channel ID, and generates a one-clock-cycle `sample_valid` pulse indicating that a new formatted sample is available.

**Input Signals:** `clk`, `rst_n`, `spi_frame_rx`, `spi_data_valid`
**Output Signals:** `v_sample_out`, `i_sample_out`, `sample_valid`

## 2. Verification Strategy

The verification strategy is based on RTL simulation using a self-checking testbench combined with SystemVerilog Assertions (SVA). Functional correctness is verified by comparing the DUT outputs against a reference formatter model implemented in the testbench. Assertions are used to verify FSM behavior, reset behavior, output protocol, and timing of the `sample_valid` signal.

## 3. Test Cases

### 3.1 Reset and Inicialization

**objective:** Ensure that reset initializes correctly.
* **Stimulus:** Assert and de-assert `rst_n` (active-low).
* **Expected Result:**
  * FSM returs to `STATE_IDLE`;
  * `v_sample_out = 16'h0000`;
  * `i_sample_out = 16'h0000`;
  * `sample_valid = 1'b0`;
  * `r_formatted_data = 16'h0000`;
  * `r_channel_id = 4'h0`;
  * `r_adc_sample = 12'h000`.

### 3.2 Voltage Frame Formatting

**objective:** Verify correct formatting of a voltage sample.
* **Stimulus:** 
  * Assert `spi_data_valid`;
  * Send a frame with:
    * Channel ID = `4'h1`;
    * ADC sample = known value.
* **Expected Result:**
  * `v_sample_out` receives the formatted value;
  * `i_sample_out` remains unchanged;
  * `sample_valid` asserted for one cycle.
  
### 3.3 Current Frame Formatting

**objective:** Verify correct formatting of a current sample.
* **Stimulus:** 
  * Assert `spi_data_valid`;
  * Send a frame with:
    * Channel ID = `4'h2`;
    * ADC sample = known value.
* **Expected Result:**
  * `i_sample_out` receives the formatted value;
  * `v_sample_out` remains unchanged;
  * `sample_valid` asserted for one cycle.
  
### 3.4 Zero Extension

**objective:** Verify proper zero-extension from 12 bits to 16 bits.
* **Stimulus:** 
  * Send several 12-bit values.
* **Expected Result:**
  * Correct extension (upper four bits must always be zero).
  
### 3.5 Invalid Channel ID

**objective:** Verify behavior for unsupported channel IDs.
* **Stimulus:** 
  * Send samples using Channel IDs different from `4'h1` and `4'h2`.
* **Expected Result:**
  * Neither output is modified;
  * `sample_valid = 1'b0`.
  
### 3.6 Minimum ADC Value

**objective:** Verify formatting of the minimum input.
* **Stimulus:** 
  * ADC sample = `12'h000`.
* **Expected Result:**
  * Formatted output = `16'h0000`.
  
### 3.7 Maximum ADC Value

**objective:** Verify formatting of the maximum input.
* **Stimulus:** 
  * ADC sample = `12'hFFF`.
* **Expected Result:**
  * Formatted output = `16'h0FFF`.
  
### 3.8 Consecutive Frames

**objective:** Verify continuous operation.
* **Stimulus:** 
  * Send multiple consecutive SPI frames alternating voltage and current channels.
* **Expected Result:**
  * No frame lost;
  * Every frame updates the corresponding output;
  * Every frame produces one `sample_valid` pulse.
  
### 3.9 Random Frames

**objective:** Verify overall functionality.
* **Stimulus:** 
  * Generate random Channel IDs and random ADC values.
* **Expected Result:**
  * The formatted outputs match the reference model for every valid transaction.
  
### 3.10 `sample_valid` Timing

**objective:** Verify protocol timing.
* **Stimulus:** 
  * Send several valid SPI frames.
* **Expected Result:**
  * `sample_valid` is asserted for exactly one clock cycle;
  * Pulse occurs only after processing reaches the output stage;
  * No false pulses occur.
  
### 3.11 FSM State Transition

**objective:** Verify correct FSM sequence.
* **Stimulus:** 
  * Send one valid SPI transaction.
* **Expected Result:**
  * FSM follows: `STATE_IDLE` -> `STATE_EXTEND_ALIGN` -> `STATE_CH_SEPARATOR` -> `STATE_REG_OUTPUT` -> `STATE_IDLE`;
  * No illegal transitions occur.
  
### 3.12 No Valid Input

**objective:** Verify idle behavior.
* **Stimulus:** 
  * Keep `spi_data_valid = 0`.
* **Expected Result:**
  * FSM remains in `STATE_IDLE`;
  * Outputs remain unchanged;
  * `sample_valid` stays low.
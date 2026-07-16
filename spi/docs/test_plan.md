# SPI Controller Verification Test Plan

## 1. Overview and Scope

This document details the verification plan for the `spi_controller` RTL module. The Design Under Test (DUT) is a parameterized SPI Master module, intended as a communication submodule for an MPPT system.

The verification strategy focuses on RTL-level simulation to ensure functional correctness, data integrity, and strict adherence to protocol timing constraints. This includes validating all four standard SPI modes, customizable clock generation, and handshake signals.

## 2. Test Environment Strategy

The primary testbench strategy relies on a **Self-Checking Loopback** topology. By connecting the `SDO` (Serial Data Out) directly to the `SDI` (Serial Data In), the testbench can automate data integrity checks by comparing the transmitted parallel word (`SDO_DATA`) with the received parallel word (`SDI_DATA`).

Protocol timing checks will be validated using waveform analysis and procedural assertions within the testbench to prepare the design for accurate static timing analysis (STA) and gate-level synthesis.

## 3. Test Cases

### 3.1 Basic Initialization and Reset (Smoke Test)
**Objective:** Verify the module safely recovers from reset and maintains safe idle states.
* **Stimulus:** Assert `RST_N` (active low) asynchronously during active system clock (`CLK`).
* **Expected Result:**
  * All internal state machines immediately return to `ST_IDLE`.
  * Outputs `BUSY`, `DONE`, `SCLK`, and `SDO` drop to 0 (or `CPOL` equivalent for `SCLK`).
  * Chip Select `CS_N` drives high (inactive) within 1 system clock cycle.
  * Inputs are ignored while `RST_N` is low.

### 3.2 Clock Divider Verification (`CLK_DIV`)
**Objective:** Validate that the SPI serial clock frequency is correctly derived from the system clock based on the `CLK_DIV` parameter.
* **Stimulus:** Parameterize the DUT with `CLK_DIV` = 1, 2, and 5. Initiate a dummy transfer.
* **Expected Result:**
  * The measured period of `SCLK` exactly matches the formula: `T_sclk = 2 * CLK_DIV * T_clk`.
  * For `CLK_DIV = 1`, `SCLK` runs at half the system clock frequency.

### 3.3 SPI Protocol Modes Validation (`CPOL` & `CPHA`)
**Objective:** Ensure the module correctly implements all four standard SPI communication modes.
* **Stimulus:** Run sequential transfers with configurations:
  * Mode 0: `CPOL=0, CPHA=0`
  * Mode 1: `CPOL=0, CPHA=1`
  * Mode 2: `CPOL=1, CPHA=0`
  * Mode 3: `CPOL=1, CPHA=1`
* **Expected Result:**
  * **Idle State:** `SCLK` matches the value of `CPOL` when `BUSY` is low.
  * **Shift/Sample Edges:** Data on `SDO` shifts on the correct propagating edge, and `SDI` is sampled on the correct sampling edge, precisely determined by the `CPHA` setting.

### 3.4 Data Integrity and Loopback (Full-Duplex)
**Objective:** Verify that data parallel-to-serial and serial-to-parallel conversions occur flawlessly (MSB first).
* **Stimulus:** 
  * Connect `SDO` to `SDI` in the testbench.
  * Parameterize `DATA_WIDTH` = 12.
  * Send varied patterns: `12'hA5A` (alternating), `12'hFFF` (all ones), `12'h000` (all zeros), `12'h001` (walking one).
* **Expected Result:**
  * For every initiated transfer, upon the assertion of the `DONE` signal, `SDI_DATA` must exactly equal `SDO_DATA`.
  * The first bit transmitted on `SDO` must be the MSB of `SDO_DATA`.

### 3.5 Handshake & Protocol Timing Constraints
**Objective:** Validate structural protocol timing, ensuring safety margins for external SPI peripherals.
* **Stimulus:** Initiate a standard 12-bit transfer and monitor the transaction boundaries.
* **Expected Result:**
  * **CS Setup:** `CS_N` must assert (go low) at least 1 full `SCLK` period before the first active edge of `SCLK`.
  * **CS Hold:** `CS_N` must remain asserted (low) for at least 1 full `SCLK` period after the final active edge of `SCLK`.
  * **Done Pulse:** `DONE` must pulse high for exactly 1 system clock (`CLK`) cycle upon completion of `ST_IDLE_GAP`.
  * **Inter-Transaction Gap:** If a new `START` is immediately requested, the module must ensure `CS_N` remains de-asserted (high) for a minimum of 2 `SCLK` periods before starting the next transaction.
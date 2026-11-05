# FPGA Implementation of Elliptic IIR Low-Pass Filter Architectures on EBAZ4205

## Project Overview

A fixed-point DSP project that designs, implements, simulates, and evaluates elliptic IIR low-pass filters on the **EBAZ4205 board with the Xilinx Zynq XC7Z010 FPGA**. The project compares three RTL architectures and validates the filtering system using a real analog signal path.

The goal is to compare the filtering behavior, FPGA resource usage, timing, and processing latency of different IIR implementations using Verilog and fixed-point arithmetic.

The project includes:

- Elliptic low-pass filter design and coefficient quantization in MATLAB.
- Three Verilog filter architectures: DF1 single biquad, DF1 cascade, and TDF2 cascade.
- SPI-based acquisition from an MCP3208 12-bit ADC.
- Test-signal generation using an ESP32 and MCP4921 12-bit DAC.
- UART transmission of filtered samples to a PC for waveform and frequency-domain analysis.
- RTL simulation and hardware validation, with FPGA utilization and timing analysis in Vivado.

## System Architecture

```text
ESP32
  |
  v
MCP4921 DAC (12-bit)
  |
  v
Analog input signal
  |
  v
MCP3208 ADC (12-bit, SPI)
  |
  v
EBAZ4205 / Zynq XC7Z010
  +-- SPI Master / ADC interface
  +-- IIR filter core (select one architecture)
  +-- UART TX
  |
  v
USB-to-UART interface (CP2102)
  |
  v
PC: waveform display and result analysis
```

The end-to-end hardware path makes it possible to evaluate the filter beyond RTL simulation, including ADC/DAC behavior, SPI communication, fixed-point arithmetic, and UART data transfer.

## Filter Design Specifications

| Parameter                   | Value                         |
| --------------------------- | ----------------------------- |
| Filter type                 | Elliptic IIR low-pass         |
| Cutoff frequency            | 200 Hz                        |
| Sampling frequency          | Approximately 35,511 Hz       |
| Passband ripple             | 0.1 dB                        |
| Stopband attenuation target | 40 dB                         |
| Coefficient representation  | Fixed-point Q2.28             |
| FPGA clock constraint       | 50 MHz                        |
| FPGA platform               | EBAZ4205, Xilinx Zynq XC7Z010 |
| RTL language                | Verilog                       |

The fourth-order filter is factored into two second-order sections (biquads) for the cascade implementations. The DF1 single-biquad design is a second-order reference architecture; therefore, it is not an equal-order comparison against the two fourth-order cascade designs.

## Implemented Architectures

### 1. Direct Form I — Single Biquad (DF1)

- Second-order filter.
- Implements the feedforward and feedback paths directly from the difference equation.
- Provides a simpler baseline architecture.

### 2. Direct Form I — Cascade (DF1 Cascade)

- Fourth-order filter implemented as two cascaded biquad sections.
- Uses separate input and output delay paths in each DF1 section.
- Provides a useful balance of resource usage and timing in the measured implementation.

### 3. Transposed Direct Form II — Cascade (TDF2 Cascade)

- Fourth-order filter implemented as two cascaded TDF2 biquad sections.
- Uses a transposed state-space arrangement.
- Uses fewer DSP blocks than DF1 Cascade in the reported implementation, while requiring more LUTs and flip-flops.

## FPGA Implementation Results

Post-implementation results reported for the 50 MHz clock constraint:

| Architecture      | Filter order | DSP blocks | FFs | Slices | LUTs | WNS       | Estimated Fmax | Timing |
| ----------------- | :----------: | :--------: | :-: | :----: | :--: | :-------: | :------------: | :----: |
| DF1 single biquad |      2       |     21     |  10 |  147   | 492  | +0.018 ns |   50.05 MHz    |  Met   |
| DF1 Cascade       |      4       |     39     | 166 |  266   | 882  | +0.047 ns |   50.12 MHz    |  Met   |
| TDF2 Cascade      |      4       |     36     | 355 |  277   | 962  | +0.038 ns |   50.10 MHz    |  Met   |

**Key observations**

- All three architectures met the 50 MHz timing constraint in the reported implementation.
- DF1 Cascade had the largest positive WNS and the lowest LUT count among the two fourth-order cascade implementations.
- TDF2 Cascade used 3 fewer DSP blocks than DF1 Cascade, but used more LUTs, flip-flops, and slices.
- The DF1 single biquad is second order, while both cascade implementations are fourth order; resource comparisons should be interpreted with this difference in mind.

### Processing Latency

| Architecture      | Filter enable cycles | System clock cycles | Approx. latency |
| ----------------- | :------------------: | :-----------------: | :-------------: |
| DF1 single biquad |          1           |        1,408        |    28.16 µs     |
| DF1 Cascade       |          2           |        2,816        |    56.32 µs     |
| TDF2 Cascade      |          2           |        2,816        |    56.32 µs     |

Latency is measured from a valid ADC sample entering the filter core until the corresponding filtered output becomes stable, according to the project's reported enable-cycle definition.

## Verification and Testing

The project evaluates the designs through MATLAB analysis, RTL simulation, and hardware measurements.

Test scenarios documented in the project include:

- **Multi-tone input:** 50 Hz, 2 kHz, and 3 kHz components.
- **Single-tone inputs:** 150 Hz and 250 Hz to examine passband preservation and attenuation around the cutoff; a 350 Hz case is also reported for the second-order DF1 implementation.
- **DC input:** 1.65 V to inspect steady-state behavior.
- **Cross-checking:** comparison of MATLAB reference results, Verilog simulation, and hardware output.
- **Implementation analysis:** Vivado resource utilization and post-route timing reports.

## Repository Structure

The layout below is a suggested organization. Adjust directory and filenames to match the files actually included in this repository.

```text
.
├── matlab/      # Filter design, coefficient quantization, reference response
├── rtl/         # Verilog sources (filters, SPI master, UART TX, top level)
├── sim/         # Testbenches and test vectors
├── constraints/ # XDC files
├── esp32/       # Test-signal generator firmware
├── python/      # Host-side UART capture/display and analysis
├── docs/        # Reports, figures, schematics
└── README.md
```

## Tools and Technologies

- **Verilog** — RTL implementation of the filter and interface modules.
- **AMD/Xilinx Vivado** — FPGA synthesis, implementation, timing analysis, and hardware programming.
- **MATLAB** — elliptic filter design, coefficient quantization, and reference-response analysis.
- **Python** — host-side UART data capture/display and result analysis.
- **ESP32, MCP4921, MCP3208** — test-signal generation and analog-to-digital acquisition.
- **EBAZ4205 / Zynq XC7Z010** — FPGA implementation platform.

## How to Use

1. Clone or download this repository.
2. Open the Vivado project or create a project targeting the Zynq XC7Z010 device.
3. Add the RTL source files and the applicable XDC constraints.
4. Select the desired filter architecture at the top-level configuration, if the project supports architecture selection.
5. Run RTL simulation using the provided testbench and test vectors.
6. Run synthesis and implementation, then review utilization and timing reports.
7. If reproducing the hardware experiment, connect the MCP3208 ADC, MCP4921 DAC, ESP32, UART interface, and EBAZ4205 according to the circuit documentation.
8. Run the host-side serial display/analysis script using the correct serial port and baud rate.

> **Note:** Exact Vivado setup steps, top-module names, simulation commands, serial-port settings, and pin assignments depend on the source files and board configuration included in the repository. Update this section with the actual filenames and instructions before publishing.

## Authors and Acknowledgment

**Authors**

- Nguyen Duy Hung (Nguyễn Duy Hưng) — `duyhung0939@gmail.com`

**Institution**

- Ho Chi Minh City University of Technology and Engineering (HCMUTE)

This project was completed as a graduation thesis in Electronic and Telecommunication Engineering (Oct 2026).

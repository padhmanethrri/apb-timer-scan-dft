# APB Timer with Scan-Based DFT

**RTL Design | Design for Testability | Verification | Synthesis | Physical Design**

An APB-based programmable timer enhanced with scan-based Design-for-Testability (DFT), verified through Verilog simulation and evaluated using Yosys synthesis and the LibreLane physical-design flow with the SkyWater SKY130A PDK.

## Overview

This project integrates a **49-bit scan chain** into an existing APB timer to improve the controllability and observability of internal sequential state during testing.

The implementation preserves the original RTL and functional testbench while maintaining a separate scan-enabled design and scan-specific verification environment.

## Key Features

- APB-based programmable timer with memory-mapped registers.
- Scan interface with `scan_en`, `scan_in`, and `scan_out`.
- 49-bit serial scan chain across `CTRL`, `LOAD`, `COUNT`, and `done`.
- Functional and scan-specific simulation using Icarus Verilog.
- Baseline-versus-scan synthesis comparison using Yosys.
- Physical implementation using LibreLane and the SkyWater SKY130A PDK.
- Timing analysis and GDSII layout generation.

## Architecture

```text
              +----------------------+
 APB Signals  |                      |
 ------------>|      APB Timer       |----> Read Data
              |                      |
              | CTRL | LOAD | COUNT  |
              +----------------------+
                         |
                         v
 Scan Input --> CTRL --> LOAD --> COUNT --> done --> Scan Output
                  <------ 49-bit scan chain ------>
```

## Synthesis Results

Standalone mapped synthesis using Yosys 0.65:

| Metric | Baseline | Scan-Enabled |
|---|---:|---:|
| Generic cells | 406 | 458 |
| Flip-flops | 127 | 127 |
| Mapped cells | 374 | 475 |
| Mapped area | 4989.79 µm² | 5298.83 µm² |

**Mapped-area overhead: approximately 6.20%.**

The mapped-area comparison is based on standalone synthesis results. It is not a baseline-versus-scan post-route area comparison.

## Verification Results

The scan-specific testbench completed with:

`ALL TESTS PASSED`

The testbench checks reset behavior, scan shifting, chain length, functional capture, timer modes, APB reads, and normal timer regression behavior.

## Physical Design Results

The final LibreLane run used a configured clock period of 12 ns.

| Metric | Result |
|---|---:|
| Standard-cell area | 9188.81 µm² |
| Total instance area | 16524.6 µm² |
| Die area | 21293.1 µm² |
| Worst setup slack | +1.5522 ns |
| Setup violations | 0 |
| Worst hold slack | +0.1105 ns |
| Hold violations | 0 |
| Maximum-slew violations | 113 |

**Note:** Maximum-slew violations remain, and dedicated PNR/signoff SDC files were not configured. These results do not establish complete signoff closure.

## Repository Structure

```text
apb-timer-scan-dft/
├── rtl/             # Original RTL
├── tb/              # Original functional testbench
├── scan_dft/        # Scan-enabled RTL and configuration
├── scan_dft_tb/     # Scan-specific testbench
├── results/         # Selected reports and simulation outputs
├── baseline/        # Baseline design files
├── docs/
│   └── project_report.md
└── README.md
```

## Running the Simulation

Run the following commands from the repository root in an environment with Icarus Verilog installed:

```bash
iverilog -g2012 -o results/scan_tb.out \
  scan_dft/apb_master.v \
  scan_dft/apb_timer.v \
  scan_dft/apb_timer_top.v \
  scan_dft_tb/tb_apb_timer.v

vvp results/scan_tb.out
```

The testbench generates a VCD waveform for inspection when configured to do so.

## Tools Used

- Verilog
- Icarus Verilog and VVP
- Yosys
- LibreLane Classic
- OpenROAD-based implementation flow
- SkyWater SKY130A PDK
- GTKWave

## Future Work

- Resolve remaining maximum-slew violations.
- Configure and validate dedicated physical-design and signoff timing constraints.
- Perform comparable baseline and scan-enabled physical-design runs.
- Verify final-run power and compare both implementations under consistent conditions.
- Generate ATPG patterns and evaluate fault coverage.
- Expand scan verification and assertion-based checking.

## Detailed Report

See [`docs/project_report.md`](docs/project_report.md) for the detailed project report, including design architecture, synthesis comparison, physical-design metrics, timing results, limitations, and future work.

---

**Project Focus:** RTL Design · Verilog · DFT · Functional Verification · Logic Synthesis · Static Timing Analysis · Physical Design

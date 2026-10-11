
# APB Timer with Scan-Based DFT

## 1. Project Overview

This project integrates scan-based Design-for-Testability (DFT) into an existing APB timer design. The objective is to improve the controllability and observability of internal sequential state through a serial scan chain while preserving the original RTL and functional testbench.

The design was simulated using Icarus Verilog, synthesized using Yosys, and physically implemented using LibreLane with the SkyWater SKY130A platform.

## 2. Objectives

- Integrate scan-based DFT into the existing APB timer.
- Provide serial scan input, scan enable, and scan output signals.
- Verify scan shifting and normal timer functionality through simulation.
- Compare baseline and scan-enabled synthesis results.
- Run the scan-enabled design through the physical-design flow.
- Evaluate area and timing results and identify remaining limitations.

## 3. Design Architecture

### 3.1 APB Timer

The timer contains the following registers:

| Register | Width | Address | Access |
| --- | ---: | --- | --- |
| CTRL | 32 bits | `0x00` | Read/Write |
| LOAD | 8 bits | `0x04` | Read/Write |
| COUNT | 8 bits | `0x08` | Read-only |
| STATUS | — | `0x0C` | Status |

### 3.2 Scan Interface

The scan-enabled design exposes three additional signals:

| Signal | Description |
| --- | --- |
| `scan_en` | Enables scan shifting |
| `scan_in` | Serial scan input |
| `scan_out` | Serial scan output |

### 3.3 Scan Chain

The scan chain connects the sequential state in the following logical order:

```text
scan_in -> CTRL -> LOAD -> COUNT -> done -> scan_out
```

The total scan-chain length is **49 bits**:

- `CTRL`: 32 bits
- `LOAD`: 8 bits
- `COUNT`: 8 bits
- `done`: 1 bit

The scan output is connected to `done`. During scan shifting, data propagates through the sequential state according to the implemented shift logic.

## 4. Tools and Technology

| Category | Tool or Technology |
| --- | --- |
| HDL | Verilog |
| Simulation | Icarus Verilog and VVP |
| Synthesis | Yosys |
| Physical design | LibreLane Classic v3.0.3 |
| PDK | SkyWater SKY130A |
| Timing and implementation analysis | OpenROAD-based reports |

## 5. Project Directory Structure

```text
apb-timer-scan-dft/
├── rtl/                 # Original timer RTL
├── tb/                  # Original functional testbench
├── scan_dft/             # Scan-enabled RTL and configuration
├── scan_dft_tb/          # Scan-specific testbench
├── results/              # Selected reports and simulation outputs
├── baseline/             # Baseline design files
├── docs/
│   └── project_report.md
└── README.md
```

The original RTL and functional testbench are kept separate from the scan-enabled implementation.

## 6. Functional Verification

The scan-enabled design was simulated using Icarus Verilog and VVP.

### 6.1 Simulation Command

Run the following command from the project root:

```bash
iverilog -g2012 -o results/scan_tb.out \
  scan_dft/apb_master.v \
  scan_dft/apb_timer.v \
  scan_dft/apb_timer_top.v \
  scan_dft_tb/tb_apb_timer.v

vvp results/scan_tb.out
```

### 6.2 Verification Coverage

The testbench checks:

- Reset behavior
- Scan shifting
- Scan-chain length
- Functional capture
- Timer operating modes
- APB read operations
- Normal timer regression behavior

**Simulation result:** `ALL TESTS PASSED`

A VCD waveform named `scan_timer.vcd` was generated for waveform inspection.

These results confirm that the included testbench checks passed. They do not establish exhaustive verification or ATPG fault coverage.

## 7. Synthesis Results

Standalone mapped synthesis was performed using Yosys 0.65.

### 7.1 Baseline vs. Scan-Enabled Design

| Metric | Baseline | Scan-Enabled |
| --- | ---: | ---: |
| Generic cells | 406 | 458 |
| Generic muxes | 121 | 170 |
| Flip-flops | 127 | 127 |
| Reported mapped cells | 374 | 475 |
| Mapped area | 4989.7856 µm² | 5298.8320 µm² |
| Structural check problems | 0 | 0 |

### 7.2 Area Overhead

The mapped-area increase is calculated as:

```text
Area increase = Scan-enabled area - Baseline area
              = 5298.8320 - 4989.7856
              = 309.0464 µm²
```

The percentage increase relative to the baseline is:

```text
Area overhead = (309.0464 / 4989.7856) × 100
              ≈ 6.20%
```

The standalone mapped-area overhead is approximately **6.20%**.

The generic-cell count increased by approximately 12.81%. Generic-cell count and mapped standard-cell area are different metrics and should not be interpreted interchangeably.

The mapped netlists and synthesis reports are included in the `results/` directory.

## 8. Physical Design Implementation

The scan-enabled design was implemented using LibreLane with the SKY130A platform.

The final implementation used the run tag `apb_timer_scan_12ns` and a configured clock period of 12 ns.

The flow generated physical-design artifacts, including GDSII layout, DEF, LEF, and netlist outputs.

### 8.1 Physical Design Metrics

| Metric | Reported Value |
| --- | ---: |
| Standard-cell area | 9188.81 µm² |
| Total instance area | 16524.6 µm² |
| Die area | 21293.1 µm² |
| Standard-cell instances | 908 |
| Sequential cells | 127 |
| Reported utilization | 55.61% |

The final GDSII layout is located at:

```text
scan_dft/runs/apb_timer_scan_12ns/final/gds/apb_timer_top.gds
```

The standalone synthesis area and final physical-design area correspond to different implementation stages. They are not directly comparable as equivalent area measurements.

## 9. Timing and Physical Checks

The final 12 ns LibreLane run reported the following results:

| Metric | Reported Result |
| --- | ---: |
| Worst setup slack | +1.5522 ns |
| Setup TNS | 0 |
| Setup violations | 0 |
| Worst hold slack | +0.1105 ns |
| Hold violations | 0 |
| Maximum-capacitance violations | 0 |
| Maximum-slew violations | 113 |

The reported setup slack was positive across the listed timing corners. The final timing summary reported no setup or hold violations.

However, **113 maximum-slew violations remain** in the reported summary. The run also emitted a warning that dedicated PNR and signoff SDC files were not configured.

Therefore, these results represent implementation-stage timing and physical checks rather than proof of complete signoff closure.

## 10. Power Analysis

A nominal power estimate of approximately 2.002 mW was recorded from an earlier 10 ns implementation run.

This value is not a verified power result for the final 12 ns run and is therefore not presented as the final implementation's power consumption.

A comparable baseline-versus-scan physical implementation and a verified final-run power result remain future work.

## 11. Limitations and Future Work

The following improvements are planned:

1. Resolve the remaining maximum-slew violations.
2. Configure and validate dedicated PNR and signoff timing constraints.
3. Run a comparable physical-design flow for the baseline implementation.
4. Verify power under consistent conditions for both implementations.
5. Develop ATPG patterns and evaluate fault coverage.
6. Expand scan verification with additional corner cases and assertions.
7. Evaluate area, timing, and power trade-offs under consistent constraints.

ATPG generation and fault-coverage analysis are planned extensions and have not been claimed as completed work.

## 12. Conclusion

This project demonstrates the integration of a 49-bit scan chain into an APB timer and its evaluation through simulation, mapped synthesis, and physical implementation using open-source digital-design tools.

The included scan testbench passed its checks, and standalone synthesis showed a mapped-area increase of approximately 6.20% over the baseline.

The final physical-design run reported positive setup and hold slack with zero reported setup and hold violations. Maximum-slew violations and signoff-constraint limitations remain to be addressed.

The implementation provides a foundation for further work on ATPG, fault coverage, and more complete physical-design validation.

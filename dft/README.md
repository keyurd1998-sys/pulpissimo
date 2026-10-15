# Cadence Modular DFT & ATPG Flow for PULPissimo

This directory provides a modular, step-by-step Design For Testability (DFT) and Automatic Test Pattern Generation (ATPG) flow using **Cadence Genus** and **Cadence Modus**.

---

## 1. Directory Structure

```
dft/
├── blocks/
│   ├── cv32e40p_core/                # Current block: RISC-V CPU Core
│   │   ├── scripts/
│   │   │   ├── 00_setup_env.tcl      # Shared environment & library paths
│   │   │   └── 01_elaborate.tcl      # Step 1: RTL Elaboration & Design Health Check
│   │   ├── run_step.sh               # Step-by-step execution runner
│   │   ├── dbs/                      # Checkpoint databases saved per step (.db)
│   │   ├── reports/                  # Reports organized by step
│   │   │   ├── 01_elaboration/
│   │   │   ├── 02_tdrc/
│   │   │   ├── 03_mapping/
│   │   │   ├── 04_scan_chains/
│   │   │   └── 05_timing_qor/
│   │   ├── netlists/                 # Final scan netlist (.v), SCANDEF, SDC
│   │   ├── atpg/                     # Modus ATPG workspace
│   │   └── logs/                     # Isolated step logs (e.g. 01_elaborate.log)
│   │
│   └── pulpissimo_top/               # Future block: Full SoC top
│       └── ...
│
├── filelists/
│   └── cv32e40p_core.flist          # SystemVerilog RTL filelist
├── constraints/
│   └── cv32e40p_core.sdc            # 200 MHz functional timing constraints
└── README.md
```

---

## 2. Step-by-Step Learning Flow

Each step saves a database snapshot (`.db`) in `dbs/` so you can inspect, debug, and run each phase without restarting from scratch:

1. **Step 1: RTL Elaboration & Design Health Check** (`scripts/01_elaborate.tcl`)
   - Reads timing/physical libraries and RTL.
   - Elaborates top-level module into generic GTECH gates.
   - Checks unresolved instances (`check_design -unresolved`).
   - Saves checkpoint: `dbs/01_elaborated.db`.

2. **Step 2: DFT Test Signals & Pre-DFT DRC (TDRC)** (`scripts/02_dft_setup_tdrc.tcl`)
   - Loads `01_elaborated.db`.
   - Defines test clocks, active-low reset (`rst_ni`), and shift enable (`SCAN_ENABLE`).
   - Runs Pre-DFT Rule Checks (`check_dft_rules`).
   - Saves checkpoint: `dbs/02_tdrc.db`.

3. **Step 3: Generic Synthesis & Scan Mapping** (`scripts/03_scan_mapping.tcl`)
   - Loads `02_tdrc.db`.
   - Maps logic and substitutes regular flip-flops with scan flip-flops (`syn_map`).
   - Saves checkpoint: `dbs/03_mapped.db`.

4. **Step 4: Scan Chain Architecture & Stitching** (`scripts/04_scan_stitching.tcl`)
   - Loads `03_mapped.db`.
   - Defines 4 scan chains, clock mixing, and lockup latches.
   - Stitches chains using `connect_scan_chains`.
   - Saves checkpoint: `dbs/04_stitched.db`.

5. **Step 5: Post-Scan Optimization & ATPG Export** (`scripts/05_syn_opt_export.tcl`)
   - Loads `04_stitched.db`.
   - Optimizes post-scan timing (`syn_opt`).
   - Exports scan netlist, SCANDEF, and Modus ATPG files (`write_dft_atpg`).

6. **Step 6: Modus ATPG & Fault Coverage Analysis** (`scripts/06_run_atpg.tcl`)
   - Runs Modus ATPG in `atpg/`.
   - Generates stuck-at test patterns and calculates fault coverage.

---

## 3. Remote Server Execution

```bash
cd ~/pulpissimo
git pull origin dft-flow
cd dft/blocks/cv32e40p_core

# Run Step 1
./run_step.sh 1
```

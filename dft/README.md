# Cadence DFT & ATPG Flow for CV32E40P (PULPissimo RISC-V Core)

This folder contains the complete, automated Design For Testability (DFT) and Automatic Test Pattern Generation (ATPG) flow for the **CV32E40P** core using **Cadence Genus** and **Cadence Modus**.

---

## 1. Directory Structure

```
dft/
├── filelists/
│   └── cv32e40p_core.flist      # Portable SystemVerilog source list
├── constraints/
│   └── cv32e40p_core.sdc        # 200 MHz timing constraints
├── scripts/
│   ├── 01_run_genus_dft.tcl     # Genus synthesis and scan chain insertion script
│   └── 02_run_modus_atpg.tcl    # Modus ATPG pattern generation script
├── run_dft.sh                   # Main execution bash runner
└── README.md                    # Flow documentation
```

---

## 2. Key Features

- **Scan Style**: Muxed-Scan (`muxed_scan`) replacing regular registers with `SDFF*` scan flip-flops.
- **Scan Chains**: 4 balanced scan chains with dedicated auto-created I/O ports (`SCAN_ENABLE`, `TEST_MODE`, `chain0_in`..`chain3_out`).
- **Clock Gate Transparency**: Uses `scan_cg_en_i` test mode control to hold all internal clock gates open during scan shift.
- **Register File**: Uses the scan-friendly flip-flop register file (`cv32e40p_register_file_ff.sv`).
- **Handoff to ATPG**: Automated generation of Modus logic models, pin assignments, and test scripts via `write_dft_atpg`.

---

## 3. Remote Server Execution Instructions

```bash
# 1. Pull the dft-flow branch on your server
git fetch origin
git checkout dft-flow
git pull origin dft-flow

# 2. Enter the dft directory
cd dft

# 3. Optional: Override library path if stored in a custom folder
# export CADENCE_DFT_LIB="/path/to/your/LIBS"

# 4. Run the full flow
./run_dft.sh
```

Or run step-by-step:
```bash
# Run Genus:
genus -f scripts/01_run_genus_dft.tcl -log results/genus.log

# Run Modus:
modus -f scripts/02_run_modus_atpg.tcl -log results/modus.log
```

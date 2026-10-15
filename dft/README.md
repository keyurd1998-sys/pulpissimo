# Cadence DFT & ATPG Flow for CV32E40P (PULPissimo RISC-V Core)

This workspace provides an automated, Cadence-verified Design For Testability (DFT) and Automatic Test Pattern Generation (ATPG) flow for the **CV32E40P** core using **Cadence Genus** and **Cadence Modus**.

---

## 1. Directory Structure

```
dft/
├── filelists/
│   └── cv32e40p_core.flist      # Complete SystemVerilog source list (with fpnew_pkg & FF regfile)
├── constraints/
│   └── cv32e40p_core.sdc        # 200 MHz synthesis timing constraints
├── scripts/
│   ├── 01_run_genus_dft.tcl     # Genus synthesis and scan insertion script
│   └── 02_run_modus_atpg.tcl    # Modus ATPG pattern generation script
├── run_dft.sh                   # Main bash runner
└── README.md                    # Flow documentation
```

---

## 2. Verified Technical Details

- **Target Library**: Direct server path at `/home/admin/DFT/Library`.
  - Timing: `/home/admin/DFT/Library/timing/slow.lib`
  - LEF: `/home/admin/DFT/Library/lef/all.lef`
  - ATPG Models: `/home/admin/DFT/Library/atpg/include_libraries.v`
- **Clock & Reset Setup**:
  - Functional clock `clk_i` defined as `scan_clk` (20 ns period) via `define_test_clock`.
  - Functional reset `rst_ni` defined as active-low via `define_test_signal -function async_set_reset -active low` (held inactive during scan shift).
  - Shift enable `SCAN_ENABLE` auto-created as primary input port via `define_test_signal -function shift_enable -name scan_en -active high -ideal -create_port`.
  - Clock gating bypass `scan_cg_en_i` configured via `define_test_mode -name scan_cg_en -active high` to keep all internal ICG cells transparent during test shift.
- **Scan Chains**:
  - 4 balanced scan chains configured with `-create_ports` and stitched using `connect_scan_chains -auto_create_chains`.
- **Modus Handoff**:
  - Netlist and ATPG setup exported via `write_dft_atpg -library ... -directory ... -run_from_directory`.

---

## 3. Remote Server Execution

```bash
# 1. Update your workspace on the server
cd pulpissimo
git pull origin dft-flow

# 2. Enter the dft folder
cd dft

# 3. Run the full automated flow
./run_dft.sh
```

Or run step-by-step:
```bash
# Step 1: Genus Synthesis & Scan Insertion
genus -f scripts/01_run_genus_dft.tcl -log results/genus.log

# Step 2: Modus ATPG
modus -f scripts/02_run_modus_atpg.tcl -log results/modus.log
```

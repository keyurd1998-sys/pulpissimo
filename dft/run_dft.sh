#!/usr/bin/env bash
# ==============================================================================
# Cadence DFT & ATPG Execution Runner
# Target: cv32e40p_core (PULPissimo RISC-V Core)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=================================================================="
echo " Cadence DFT & ATPG Flow for CV32E40P Core"
echo " Working Directory: $SCRIPT_DIR"
echo "=================================================================="

# Check Genus availability
if ! command -v genus &> /dev/null; then
    echo "ERROR: 'genus' binary not found in PATH."
    echo "Please load your Cadence Genus environment before running."
    echo "Example: module load cadence/genus"
    exit 1
fi

echo "[Step 1/2] Running Genus Synthesis and DFT Scan Insertion..."
genus -f scripts/01_run_genus_dft.tcl -log results/genus.log

echo "Genus run completed. Checking for Modus..."

# Check Modus availability
if ! command -v modus &> /dev/null; then
    echo "WARNING: 'modus' binary not found in PATH."
    echo "Genus synthesis and scan insertion completed successfully."
    echo "To run ATPG, load Cadence Modus and run:"
    echo "  modus -f scripts/02_run_modus_atpg.tcl -log results/modus.log"
    exit 0
fi

echo "[Step 2/2] Running Modus ATPG & Fault Coverage Analysis..."
modus -f scripts/02_run_modus_atpg.tcl -log results/modus.log

echo "=================================================================="
echo " Flow completed successfully!"
echo " Reports:   $SCRIPT_DIR/results/reports/"
echo " Netlists:  $SCRIPT_DIR/results/netlists/"
echo " ATPG Data: $SCRIPT_DIR/results/modus_atpg/"
echo "=================================================================="

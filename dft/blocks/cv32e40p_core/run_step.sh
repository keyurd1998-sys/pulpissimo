#!/usr/bin/env bash
# ==============================================================================
# Interactive Step-by-Step DFT Runner for cv32e40p_core
# Usage:
#   ./run_step.sh 1          (Runs Step 1)
#   ./run_step.sh 1 2 3 4    (Runs Steps 1, 2, 3, 4)
#   ./run_step.sh all        (Runs Steps 1 through 7 in one go)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export CADENCE_DFT_LIB="/home/admin/DFT/Library"

mkdir -p logs reports dbs netlists atpg

check_tool() {
    if ! command -v genus &> /dev/null; then
        echo "ERROR: 'genus' binary not found in PATH."
        echo "Please load your Cadence Genus environment before running."
        echo "Example: module load cadence/genus"
        exit 1
    fi
}

run_single_step() {
    local step="$1"
    case "$step" in
        1|2|3|4|5|6|7)
            check_tool
            ;;
    esac
    case "$step" in
        1)
            echo "=================================================================="
            echo " Running Step 1: RTL Elaboration & Design Health Check"
            echo " Output Log: logs/01_elaborate.log"
            echo "=================================================================="
            rm -f logs/01_elaborate.log* logs/01_elaborate.cmd*
            genus -overwrite -f scripts/01_elaborate.tcl -log logs/01_elaborate.log
            echo ""
            echo ">>> Step 1 Complete!"
            echo ">>> Checkpoint Saved: dbs/01_elaborated.db"
            echo ">>> Reports:          reports/01_elaboration/"
            ;;
        2)
            echo "=================================================================="
            echo " Running Step 2: DFT Signal Setup & Pre-DFT DRC (TDRC)"
            echo " Output Log: logs/02_dft_setup_tdrc.log"
            echo "=================================================================="
            rm -f logs/02_dft_setup_tdrc.log* logs/02_dft_setup_tdrc.cmd*
            genus -overwrite -f scripts/02_dft_setup_tdrc.tcl -log logs/02_dft_setup_tdrc.log
            echo ""
            echo ">>> Step 2 Complete!"
            echo ">>> Checkpoint Saved: dbs/02_tdrc.db"
            echo ">>> Reports:          reports/02_tdrc/"
            echo ">>> Violation Summary:"
            if [ -f reports/02_tdrc/cv32e40p_core_dft_rules_pre_syn.rpt ]; then
                head -n 28 reports/02_tdrc/cv32e40p_core_dft_rules_pre_syn.rpt
            fi
            ;;
        3)
            echo "=================================================================="
            echo " Running Step 3: Generic Synthesis & Scan Mapping (syn_map)"
            echo " Output Log: logs/03_scan_mapping.log"
            echo "=================================================================="
            rm -f logs/03_scan_mapping.log* logs/03_scan_mapping.cmd*
            genus -overwrite -f scripts/03_scan_mapping.tcl -log logs/03_scan_mapping.log
            echo ""
            echo ">>> Step 3 Complete!"
            echo ">>> Checkpoint Saved: dbs/03_mapped.db"
            echo ">>> Reports:          reports/03_mapping/"
            echo ">>> Post-Map DRC Summary:"
            if [ -f reports/03_mapping/cv32e40p_core_dft_rules_post_map.rpt ]; then
                head -n 28 reports/03_mapping/cv32e40p_core_dft_rules_post_map.rpt
            fi
            ;;
        4)
            echo "=================================================================="
            echo " Running Step 4: On-Chip Clock Controller (OCC/OPCG) Insertion"
            echo " Output Log: logs/04_insert_opcg.log"
            echo "=================================================================="
            rm -f logs/04_insert_opcg.log* logs/04_insert_opcg.cmd*
            genus -overwrite -f scripts/04_insert_opcg.tcl -log logs/04_insert_opcg.log
            echo ""
            echo ">>> Step 4 Complete!"
            echo ">>> Checkpoint Saved: dbs/04_opcg.db"
            echo ">>> Reports:          reports/04_opcg/"
            if [ -f reports/04_opcg/cv32e40p_core_opcg_info.rpt ]; then
                echo "=================================================================="
                echo " OPCG Clock Domain Information:"
                echo "=================================================================="
                cat reports/04_opcg/cv32e40p_core_opcg_info.rpt
            fi
            if [ -f reports/04_opcg/cv32e40p_core_dft_rules.rpt ]; then
                echo "=================================================================="
                echo " Post-OPCG DFT DRC Summary:"
                echo "=================================================================="
                head -n 28 reports/04_opcg/cv32e40p_core_dft_rules.rpt
            fi
            ;;
        5)
            echo "=================================================================="
            echo " Running Step 5: Pre-TPI Scan Compression Analysis (Ratios 70, 80)"
            echo " Output Log: logs/05_compression_analysis_pre_tpi.log"
            echo "=================================================================="
            rm -f logs/05_compression_analysis_pre_tpi.log* logs/05_compression_analysis_pre_tpi.cmd*
            genus -overwrite -f scripts/05_compression_analysis_pre_tpi.tcl -log logs/05_compression_analysis_pre_tpi.log
            echo ""
            echo ">>> Step 5 Complete!"
            echo ">>> Checkpoint Saved: dbs/05_compression_analysis_pre_tpi.db"
            echo ">>> Reports:          reports/05_compression_analysis_pre_tpi/"
            if [ -f reports/05_compression_analysis_pre_tpi/cv32e40p_core_compressibility_stuck_at.rpt ]; then
                echo "=================================================================="
                echo " Pre-TPI Stuck-At Compressibility Report (Ratios 70, 80):"
                echo "=================================================================="
                cat reports/05_compression_analysis_pre_tpi/cv32e40p_core_compressibility_stuck_at.rpt
            fi
            if [ -f reports/05_compression_analysis_pre_tpi/cv32e40p_core_compressibility_delay.rpt ]; then
                echo "=================================================================="
                echo " Pre-TPI Transition Delay Compressibility Report (Ratios 70, 80):"
                echo "=================================================================="
                cat reports/05_compression_analysis_pre_tpi/cv32e40p_core_compressibility_delay.rpt
            fi
            ;;
        6)
            echo "=================================================================="
            echo " Running Step 6: ATPG-Guided Test Point Insertion (TPI, Max 100 TPs)"
            echo " Output Log: logs/06_test_point_insertion.log"
            echo "=================================================================="
            rm -f logs/06_test_point_insertion.log* logs/06_test_point_insertion.cmd*
            genus -overwrite -f scripts/06_test_point_insertion.tcl -log logs/06_test_point_insertion.log
            echo ""
            echo ">>> Step 6 Complete!"
            echo ">>> Checkpoint Saved: dbs/06_tpi.db"
            echo ">>> Reports:          reports/06_tpi/"
            if [ -f reports/06_tpi/cv32e40p_core_test_points.rpt ]; then
                echo "=================================================================="
                echo " Analyzed Test Points Report Summary:"
                echo "=================================================================="
                cat reports/06_tpi/cv32e40p_core_test_points.rpt
            fi
            if [ -f reports/06_tpi/cv32e40p_core_dft_rules.rpt ]; then
                echo "=================================================================="
                echo " Post-TPI DFT DRC Summary:"
                echo "=================================================================="
                head -n 28 reports/06_tpi/cv32e40p_core_dft_rules.rpt
            fi
            ;;
        7)
            echo "=================================================================="
            echo " Running Step 7: Final Scan Compression Insertion & DRC Check"
            echo " Output Log: logs/07_insert_compression.log"
            echo "=================================================================="
            rm -f logs/07_insert_compression.log* logs/07_insert_compression.cmd*
            genus -overwrite -f scripts/07_insert_compression.tcl -log logs/07_insert_compression.log
            echo ""
            echo ">>> Step 7 Complete!"
            echo ">>> Checkpoint Saved: dbs/07_compressed.db"
            echo ">>> Reports:          reports/07_compression/"
            if [ -f reports/07_compression/cv32e40p_core_dft_rules.rpt ]; then
                echo "=================================================================="
                echo " Post-Compression DFT DRC Summary:"
                echo "=================================================================="
                head -n 28 reports/07_compression/cv32e40p_core_dft_rules.rpt
            fi
            if [ -f reports/07_compression/cv32e40p_core_scan_chains.rpt ]; then
                echo "=================================================================="
                echo " Scan Chains Summary:"
                echo "=================================================================="
                head -n 25 reports/07_compression/cv32e40p_core_scan_chains.rpt
            fi
            ;;
        help|*)
            echo "=================================================================="
            echo " Interactive Step Runner for CV32E40P Core"
            echo "=================================================================="
            echo "Usage: ./run_step.sh <step_number | all>"
            echo ""
            echo "Available Steps:"
            echo "  1    - Step 1: RTL Elaboration & Health Check"
            echo "  2    - Step 2: DFT Signal Setup & Pre-DFT DRC (TDRC)"
            echo "  3    - Step 3: Generic Synthesis & Scan Mapping (syn_map)"
            echo "  4    - Step 4: On-Chip Clock Controller (OCC/OPCG) Insertion"
            echo "  5    - Step 5: Pre-TPI Scan Compression Analysis (Ratios 70, 80)"
            echo "  6    - Step 6: ATPG-Guided Test Point Insertion (TPI, Max 100 TPs)"
            echo "  7    - Step 7: Final Scan Compression Insertion & DRC Check"
            echo "  all  - Run Steps 1 through 7 sequentially in one go"
            echo "=================================================================="
            exit 0
            ;;
    esac
}

if [ $# -eq 0 ]; then
    run_single_step help
fi

for arg in "$@"; do
    if [ "$arg" = "all" ]; then
        for s in 1 2 3 4 5 6 7; do
            run_single_step "$s"
        done
    else
        run_single_step "$arg"
    fi
done

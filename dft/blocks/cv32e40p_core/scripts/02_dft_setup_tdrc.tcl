###############################################################################
## Step 2: DFT Signal Setup & Pre-DFT Testability Design Rule Check (TDRC)
## Target: cv32e40p_core
## Goal:
##   1. Restore the elaborated design from Step 1 (01_elaborated.db).
##   2. Read functional timing constraints (SDC).
##   3. Define scan style (muxed_scan) and test signals:
##      - Test clock (scan_clk on clk_i)
##      - Test mode reset control (scan_rst on active-low rst_ni)
##      - Test mode clock gate bypass (scan_cg_en on scan_cg_en_i)
##      - Shift enable primary input (SCAN_ENABLE)
##   4. Run Pre-DFT Rule Checks (check_dft_rules).
##   5. Save the checkpoint database (02_tdrc.db) for Step 3 (Scan Mapping).
###############################################################################

# Source common environment setup
set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR "$REPORTS_DIR/02_tdrc"
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

puts "=========================================================================="
puts "  STAGE 2: DFT SIGNAL SETUP & PRE-DFT RULE CHECKING                       "
puts "=========================================================================="

#-------------------------------------------------------------------------------
# 1. Restore Checkpoint Database from Step 1
#-------------------------------------------------------------------------------
set PREV_DB "$DBS_DIR/01_elaborated.db"
if {![file exists $PREV_DB]} {
    puts "ERROR: Checkpoint database $PREV_DB not found!"
    puts "Please execute Step 1 (./run_step.sh 1) first."
    exit 1
}

puts "INFO: Restoring elaborated design from $PREV_DB..."
read_db $PREV_DB

#-------------------------------------------------------------------------------
# 2. Read Functional Timing Constraints (SDC)
#-------------------------------------------------------------------------------
puts "INFO: Reading SDC constraints from $SDC_FILE..."
read_sdc $SDC_FILE

#-------------------------------------------------------------------------------
# 3. Configure DFT Scan Parameters & Signals
#-------------------------------------------------------------------------------
puts "INFO: Configuring DFT scan style and test signals..."

# Scan style: Standard multiplexed flip-flops (Mux-D scan style)
set_db root: .dft_scan_style muxed_scan
set_db root: .dft_prefix DFT_

# Auto-identification settings
set_db root: .dft_identify_top_level_test_clocks true
set_db root: .dft_identify_test_signals true
set_db root: .dft_identify_internal_test_clocks false
set_db root: .use_scan_seqs_for_non_dft false

# 1. Define Test Clock:
# Maps the functional clock input 'clk_i' as the scan test clock (period: 20000ps)
puts "INFO: Defining test clock 'scan_clk' on port clk_i..."
define_test_clock -name scan_clk -period 20000 [get_ports clk_i]

# 2. Define Asynchronous Reset (rst_ni):
# rst_ni is active-low (0 = reset asserted, 1 = inactive/deasserted).
# -active high: In Genus, forces logic 1 during scan shifting to keep reset inactive.
# -scan_shift:  Only forces the inactive state during scan shift, allowing ATPG
#               to pulse the reset pin during capture cycles.
# -shared_input: Marks rst_ni as an existing functional port.
puts "INFO: Defining test mode control for active-low reset 'rst_ni'..."
define_test_mode -name scan_rst -active high -scan_shift -shared_input [get_ports rst_ni]

# 3. Define Clock Gate Test Bypass (scan_cg_en_i):
# In functional mode, internal clock gates can gate the clock.
# In test mode, we force scan_cg_en_i high to make all clock gates transparent.
puts "INFO: Defining test mode bypass for internal clock gates 'scan_cg_en_i'..."
define_test_mode -name scan_cg_en -active high -shared_input [get_ports scan_cg_en_i]

# 4. Define Shift Enable (SCAN_ENABLE):
# Creates a dedicated top-level primary input port named SCAN_ENABLE.
# When SCAN_ENABLE=1, flip-flops shift data through the scan chain (SI -> Q).
# When SCAN_ENABLE=0, flip-flops capture functional combinational logic (D -> Q).
puts "INFO: Defining shift-enable test signal 'scan_en' (creates port SCAN_ENABLE)..."
define_test_signal -function shift_enable -name scan_en -active high -ideal -create_port SCAN_ENABLE

#-------------------------------------------------------------------------------
# 4. Run Pre-DFT Testability Design Rule Check (TDRC)
#-------------------------------------------------------------------------------
puts "INFO: Running Pre-DFT Rule Check (TDRC)..."
check_dft_rules > "$STEP_RPT_DIR/${DESIGN}_dft_rules_pre_syn.rpt"
report_dft_violations > "$STEP_RPT_DIR/${DESIGN}_dft_violations_pre_syn.rpt"

puts "INFO: TDRC Report generated at: $STEP_RPT_DIR/${DESIGN}_dft_rules_pre_syn.rpt"

#-------------------------------------------------------------------------------
# 5. Save Checkpoint Database for Step 3
#-------------------------------------------------------------------------------
set DB_FILE "$DBS_DIR/02_tdrc.db"
puts "INFO: Saving checkpoint database to $DB_FILE..."
write_db -all_root_attributes -to_file $DB_FILE

puts "=========================================================================="
puts "  STAGE 2 COMPLETED SUCCESSFULLY!                                       "
puts "  Check report:   $STEP_RPT_DIR/${DESIGN}_dft_rules_pre_syn.rpt          "
puts "  Database Saved: $DB_FILE                                              "
puts "  Next Step:      03_scan_mapping.tcl                                   "
puts "=========================================================================="
exit

set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR "$REPORTS_DIR/02_tdrc"
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

# Restore Step 1 elaborated database
set PREV_DB "$DBS_DIR/01_elaborated.db"
if {![file exists $PREV_DB]} {
    puts "ERROR: $PREV_DB not found! Run Step 1 first."
    exit 1
}
read_db $PREV_DB

# Read functional timing constraints
read_sdc $SDC_FILE

# Configure scan style and test signals
set_db root: .dft_scan_style muxed_scan
set_db root: .dft_prefix DFT_
set_db root: .dft_identify_top_level_test_clocks true
set_db root: .dft_identify_test_signals true
set_db root: .dft_identify_internal_test_clocks false
set_db root: .use_scan_seqs_for_non_dft false

define_test_clock -name scan_clk -period 20000 [get_ports clk_i]
define_test_mode -name scan_rst -active high -scan_shift -shared_input [get_ports rst_ni]
define_test_mode -name scan_cg_en -active high -shared_input [get_ports scan_cg_en_i]
define_test_signal -function shift_enable -name scan_en -active high -ideal -create_port SCAN_ENABLE

# Run Pre-DFT Testability Design Rule Check (TDRC)
check_dft_rules       > "$STEP_RPT_DIR/${DESIGN}_dft_rules_pre_syn.rpt"
report_dft_violations > "$STEP_RPT_DIR/${DESIGN}_dft_violations_pre_syn.rpt"

# Save checkpoint database
set DB_FILE "$DBS_DIR/02_tdrc.db"
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 2 completed successfully. Checkpoint saved: $DB_FILE"
exit

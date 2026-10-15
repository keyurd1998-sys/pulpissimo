set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR "$REPORTS_DIR/04_scan_chains"
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

# Restore Step 3 mapped database
set PREV_DB "$DBS_DIR/03_mapped.db"
if {![file exists $PREV_DB]} {
    puts "ERROR: $PREV_DB not found! Run Step 3 first."
    exit 1
}
read_db $PREV_DB

# Configure scan chain attributes
set_db [current_design] .dft_min_number_of_scan_chains 4
set_db [current_design] .dft_mix_clock_edges_in_scan_chains true
set_db [current_design] .dft_lockup_element_type preferred_level_sensitive

# Define 4 scan chains with dedicated top-level ports
define_scan_chain -name chain0 -sdi scan_in_0 -sdo scan_out_0 -create_ports -shift_enable scan_en
define_scan_chain -name chain1 -sdi scan_in_1 -sdo scan_out_1 -create_ports -shift_enable scan_en
define_scan_chain -name chain2 -sdi scan_in_2 -sdo scan_out_2 -create_ports -shift_enable scan_en
define_scan_chain -name chain3 -sdi scan_in_3 -sdo scan_out_3 -create_ports -shift_enable scan_en

# Stitch scan chains
connect_scan_chains -auto_create_chains

# Post-stitching DRC and reports
check_dft_rules    > "$STEP_RPT_DIR/${DESIGN}_dft_rules_post_scan.rpt"
report_scan_chains > "$STEP_RPT_DIR/${DESIGN}_scan_chains.rpt"
report_scan_setup  > "$STEP_RPT_DIR/${DESIGN}_scan_setup.rpt"

# Save checkpoint database
set DB_FILE "$DBS_DIR/04_stitched.db"
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 4 completed successfully. Checkpoint saved: $DB_FILE"
exit

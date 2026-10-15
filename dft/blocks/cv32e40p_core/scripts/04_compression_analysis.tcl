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
set_db [current_design] .dft_mix_clock_edges_in_scan_chains true
set_db [current_design] .dft_lockup_element_type preferred_level_sensitive

# Define 1 base scan chain with 1 scan-in and 1 scan-out port
define_scan_chain -name chain0 -sdi scan_in -sdo scan_out -create_ports -shift_enable scan_en

# Stitch base scan chain
connect_scan_chains -auto_create_chains

# Base scan chain reports
check_dft_rules    > "$STEP_RPT_DIR/${DESIGN}_dft_rules_base.rpt"
report_scan_chains > "$STEP_RPT_DIR/${DESIGN}_scan_chains_base.rpt"

# Compression Analysis: Preview ratios 50, 60, 70, 80
compress_scan_chains -ratio 50 -compressor xor -preview > "$STEP_RPT_DIR/${DESIGN}_preview_ratio_50.rpt"
compress_scan_chains -ratio 60 -compressor xor -preview > "$STEP_RPT_DIR/${DESIGN}_preview_ratio_60.rpt"
compress_scan_chains -ratio 70 -compressor xor -preview > "$STEP_RPT_DIR/${DESIGN}_preview_ratio_70.rpt"
compress_scan_chains -ratio 80 -compressor xor -preview > "$STEP_RPT_DIR/${DESIGN}_preview_ratio_80.rpt"

# Compressibility analysis with ATPG library
if {[catch {
    analyze_scan_compressibility -library $ATPG_LIB -ratios {50 60 70 80} > "$STEP_RPT_DIR/${DESIGN}_compressibility_analysis.rpt"
} msg]} {
    puts "NOTE: analyze_scan_compressibility: $msg"
}

# Save checkpoint database
set DB_FILE "$DBS_DIR/04_stitched.db"
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 4 compression analysis completed. Checkpoint saved: $DB_FILE"
exit

set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR [file normalize "$REPORTS_DIR/07_compression_analysis_post_tpi"]
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

# Restore Step 6 TPI database
set PREV_DB [file normalize "$DBS_DIR/06_tpi.db"]
if {![file exists $PREV_DB]} {
    puts "ERROR: $PREV_DB not found! Run Step 6 first."
    exit 1
}
read_db $PREV_DB

# Configure scan chain attributes
set_db [current_design] .dft_mix_clock_edges_in_scan_chains true
set_db [current_design] .dft_lockup_element_type preferred_level_sensitive

# Define 1 base scan chain with 1 scan-in and 1 scan-out port
define_scan_chain -name chain0 -sdi scan_in -sdo scan_out -create_ports -shift_enable scan_en

# Stitch base scan chain (includes all flops + test point flops + OPCG segments)
set has_opcg [llength [get_db opcg_domains *]]
if {$has_opcg > 0} {
    connect_scan_chains -auto_create_chains -include_opcg_segments
    connect_opcg_segments -side_scan_only
} else {
    connect_scan_chains -auto_create_chains
}

# Base scan chain reports
check_dft_rules    > "$STEP_RPT_DIR/${DESIGN}_dft_rules_base.rpt"
report_scan_chains > "$STEP_RPT_DIR/${DESIGN}_scan_chains_base.rpt"

# Run Compressibility Analysis with Modus ATPG for Ratios 70 and 80
set asc_dir [file normalize "$STEP_RPT_DIR/asc_ratios_70_80"]
set asc_rpt [file normalize "$STEP_RPT_DIR/${DESIGN}_compressibility_ratios_70_80.rpt"]
file delete -force $asc_dir

analyze_scan_compressibility \
    -library $ATPG_LIB \
    -build_model_options "-allowmissingmodules yes" \
    -compression_method compress_scan_chains \
    -compressor xor \
    -decompressor broadcast \
    -mask wide1 \
    -ratios {70 80} \
    -directory $asc_dir \
    -verbose

report_scan_compressibility -directory $asc_dir > $asc_rpt

# Save checkpoint database
set DB_FILE [file normalize "$DBS_DIR/07_compression_analysis_post_tpi.db"]
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 7 post-TPI compression analysis (Ratios 70, 80) completed. Report: $asc_rpt"
exit

set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR [file normalize "$REPORTS_DIR/07_compression"]
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

# Compression ratio setting (default 70, can be overridden by env variable)
if {[info exists ::env(COMPRESSION_RATIO)]} {
    set COMP_RATIO $::env(COMPRESSION_RATIO)
} else {
    set COMP_RATIO 70
}

# Restore Step 5 TPI database; fallback to Step 3 mapped database if TPI skipped
set PREV_DB [file normalize "$DBS_DIR/05_tpi.db"]
if {![file exists $PREV_DB]} {
    set PREV_DB [file normalize "$DBS_DIR/03_mapped.db"]
    if {![file exists $PREV_DB]} {
        puts "ERROR: Neither $DBS_DIR/05_tpi.db nor $DBS_DIR/03_mapped.db found!"
        exit 1
    }
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

# Insert Scan Compression with Ratio $COMP_RATIO
compress_scan_chains \
    -ratio $COMP_RATIO \
    -compressor xor \
    -decompressor broadcast \
    -mask wide1 \
    -auto_create

# Post-compression DFT DRC and scan chain reports
check_dft_rules    > "$STEP_RPT_DIR/${DESIGN}_dft_rules.rpt"
report_scan_chains > "$STEP_RPT_DIR/${DESIGN}_scan_chains.rpt"

# Save checkpoint database
set DB_FILE [file normalize "$DBS_DIR/07_compressed.db"]
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 7 compression insertion (Ratio $COMP_RATIO) completed. Checkpoint saved: $DB_FILE"
exit

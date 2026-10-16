set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR [file normalize "$REPORTS_DIR/05_compression_analysis_pre_tpi"]
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

# Restore Step 4 OPCG database; fallback to Step 3 mapped database
set PREV_DB [file normalize "$DBS_DIR/04_opcg.db"]
if {![file exists $PREV_DB]} {
    set PREV_DB [file normalize "$DBS_DIR/03_mapped.db"]
    if {![file exists $PREV_DB]} {
        puts "ERROR: Neither $DBS_DIR/04_opcg.db nor $DBS_DIR/03_mapped.db found! Run Step 4 or Step 3 first."
        exit 1
    }
}
read_db $PREV_DB

# Configure scan chain attributes
set_db [current_design] .dft_mix_clock_edges_in_scan_chains true
set_db [current_design] .dft_lockup_element_type preferred_level_sensitive

# Define 1 base scan chain with 1 scan-in and 1 scan-out port
define_scan_chain -name chain0 -sdi scan_in -sdo scan_out -create_ports -shift_enable scan_en

# Stitch base scan chain (includes OPCG segments if present)
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

# ==============================================================================
# PASS 1: Stuck-At Fault Compression Analysis (Ratios 70 and 80)
# ==============================================================================
set asc_sa_dir [file normalize "$STEP_RPT_DIR/asc_stuck_at"]
set asc_sa_rpt [file normalize "$STEP_RPT_DIR/${DESIGN}_compressibility_stuck_at.rpt"]
file delete -force $asc_sa_dir

puts "INFO: Running Stuck-At Compression Analysis for Ratios 70 and 80..."
analyze_scan_compressibility \
    -library $ATPG_LIB \
    -build_model_options "-allowmissingmodules yes" \
    -compression_method compress_scan_chains \
    -compressor xor \
    -decompressor broadcast \
    -mask wide1 \
    -ratios {70 80} \
    -directory $asc_sa_dir \
    -verbose

report_scan_compressibility -directory $asc_sa_dir > $asc_sa_rpt

# ==============================================================================
# PASS 2: Transition (Delay) Fault Compression Analysis (Ratios 70 and 80)
# ==============================================================================
set asc_delay_dir [file normalize "$STEP_RPT_DIR/asc_delay"]
set asc_delay_rpt [file normalize "$STEP_RPT_DIR/${DESIGN}_compressibility_delay.rpt"]
file delete -force $asc_delay_dir

puts "INFO: Running Transition Delay Compression Analysis for Ratios 70 and 80..."
analyze_scan_compressibility \
    -library $ATPG_LIB \
    -build_model_options "-allowmissingmodules yes" \
    -compression_method compress_scan_chains \
    -compressor xor \
    -decompressor broadcast \
    -mask wide1 \
    -ratios {70 80} \
    -delay \
    -directory $asc_delay_dir \
    -verbose

report_scan_compressibility -directory $asc_delay_dir > $asc_delay_rpt

# Save checkpoint database
set DB_FILE [file normalize "$DBS_DIR/05_compression_analysis_pre_tpi.db"]
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 5 pre-TPI compression analysis completed."
puts "INFO: Stuck-at Report:   $asc_sa_rpt"
puts "INFO: Transition Report: $asc_delay_rpt"
exit

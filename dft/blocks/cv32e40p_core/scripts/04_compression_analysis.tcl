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
set preview_summary "$STEP_RPT_DIR/${DESIGN}_compression_previews.rpt"
set fp [open $preview_summary w]
puts $fp "=================================================================="
puts $fp " Compression Architecture Previews for 1-Channel Scan"
puts $fp " Total Scannable Registers: 2154"
puts $fp "=================================================================="
close $fp

foreach r {50 60 70 80} {
    set rpt_file "$STEP_RPT_DIR/${DESIGN}_preview_ratio_${r}.rpt"
    compress_scan_chains -ratio $r -compressor xor -decompressor broadcast -mask wide1 -auto_create -preview > $rpt_file
    set fp [open $preview_summary a]
    puts $fp "\n--------------------------------------------------"
    puts $fp " Preview Report for Ratio: $r"
    puts $fp "--------------------------------------------------"
    set ifp [open $rpt_file r]
    puts $fp [read $ifp]
    close $ifp
    close $fp
}

# Compressibility analysis: Runs Modus ATPG across ratios 50, 60, 70, 80
set asc_dir "$STEP_RPT_DIR/asc_1channel"
if {[catch {
    analyze_scan_compressibility \
        -library $ATPG_LIB \
        -compression_method compress_scan_chains \
        -compressor xor \
        -decompressor broadcast \
        -mask wide1 \
        -ratios "50 60 70 80" \
        -directory $asc_dir \
        -verbose > "$STEP_RPT_DIR/${DESIGN}_compressibility_analysis.rpt"
} msg]} {
    puts "NOTE: Background ATPG failed ($msg). Running with -dont_run_atpg fallback..."
    analyze_scan_compressibility \
        -library $ATPG_LIB \
        -compression_method compress_scan_chains \
        -compressor xor \
        -decompressor broadcast \
        -mask wide1 \
        -ratios "50 60 70 80" \
        -directory $asc_dir \
        -dont_run_atpg \
        -verbose > "$STEP_RPT_DIR/${DESIGN}_compressibility_analysis.rpt"
}

# Save checkpoint database
set DB_FILE "$DBS_DIR/04_stitched.db"
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 4 compression analysis completed. Checkpoint saved: $DB_FILE"
exit

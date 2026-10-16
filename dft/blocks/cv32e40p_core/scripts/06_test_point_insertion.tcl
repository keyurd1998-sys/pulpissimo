set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR [file normalize "$REPORTS_DIR/06_tpi"]
set TPI_DIR      [file normalize "$STEP_RPT_DIR/modus_tpi_work"]
file mkdir $STEP_RPT_DIR
file mkdir $TPI_DIR
file mkdir $DBS_DIR

# Restore Step 4 OPCG database if available; fallback to Step 3 mapped database
set PREV_DB [file normalize "$DBS_DIR/04_opcg.db"]
if {![file exists $PREV_DB]} {
    set PREV_DB [file normalize "$DBS_DIR/03_mapped.db"]
    if {![file exists $PREV_DB]} {
        puts "ERROR: Neither $DBS_DIR/04_opcg.db nor $DBS_DIR/03_mapped.db found!"
        exit 1
    }
}
read_db $PREV_DB

# PASS 1: Build temporary scan chains for Modus ATPG analysis
define_test_mode -name test_mode -active high -create_port test_mode
set_db [current_design] .dft_mix_clock_edges_in_scan_chains true
set_db [current_design] .dft_lockup_element_type preferred_level_sensitive
define_scan_chain -name chain0 -sdi scan_in -sdo scan_out -create_ports -shift_enable scan_en

set has_opcg [llength [get_db opcg_domains *]]
if {$has_opcg > 0} {
    connect_scan_chains -auto_create_chains -include_opcg_segments
    connect_opcg_segments -side_scan_only
} else {
    connect_scan_chains -auto_create_chains
}

# Write Modus compression test point analysis setup
set_db / .dft_generate_atpg_no_testpoint_file auto
write_dft_compression_test_points \
    -directory $TPI_DIR \
    -library $ATPG_LIB \
    -build_model_options "-allowmissingmodules yes" \
    -min_slack_for_no_tp_file 100 \
    -compression_testpoints_options "-maxtestpts 100" \
    -force

# Run Modus ATPG test point analysis
puts "INFO: Running Modus Compression Test Point Analysis..."
shell modus -file "$TPI_DIR/runmodus.compression_testpoints.tcl"

# PASS 2: Reload clean mapped netlist without temporary chains
delete_obj [get_db designs *]
read_db $PREV_DB

# Define test mode signal on clean netlist
define_test_mode -name test_mode -active high -create_port test_mode

# Locate Modus test point file
set TP_FILE "$TPI_DIR/${DESIGN}.compression_testpoints.tpfile"
if {![file exists $TP_FILE]} {
    set alt_files [glob -nocomplain "$TPI_DIR/*compression_testpoints*.tpfile" "$TPI_DIR/**/${DESIGN}*.tpfile"]
    if {[llength $alt_files] > 0} {
        set TP_FILE [lindex $alt_files 0]
    }
}

# Insert analyzed test points
if {[file exists $TP_FILE]} {
    puts "INFO: Inserting test points from $TP_FILE"
    add_analyzed_test_points \
        -input_test_point_file $TP_FILE \
        -share_observe_flop 4 \
        -test_control test_mode \
        -min_slack 100 \
        -verbose
} else {
    puts "WARNING: Test point file $TP_FILE not found! Skipping test point insertion."
}

# Post-TPI DFT DRC and test point reports
check_dft_rules                 > "$STEP_RPT_DIR/${DESIGN}_dft_rules.rpt"
report_dft_analyzed_test_points > "$STEP_RPT_DIR/${DESIGN}_test_points.rpt"

# Save checkpoint database
set DB_FILE [file normalize "$DBS_DIR/06_tpi.db"]
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 6 Test Point Insertion (max 100 TPs) completed. Checkpoint saved: $DB_FILE"
exit

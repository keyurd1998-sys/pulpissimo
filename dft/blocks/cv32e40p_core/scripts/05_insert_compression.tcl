set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR "$REPORTS_DIR/05_compression"
file mkdir $STEP_RPT_DIR
file mkdir $NETLISTS_DIR
file mkdir $ATPG_DIR
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

# Insert Scan Compression with Ratio 60
compress_scan_chains \
    -ratio 60 \
    -compressor xor \
    -decompressor broadcast \
    -mask wide1 \
    -auto_create

# Post-compression DFT DRC and scan chain reports
check_dft_rules    > "$STEP_RPT_DIR/${DESIGN}_dft_rules.rpt"
report_scan_chains > "$STEP_RPT_DIR/${DESIGN}_scan_chains.rpt"

# Incremental timing & area optimization
syn_opt -incr

# Post-optimization reports
report_timing > "$STEP_RPT_DIR/${DESIGN}_timing.rpt"
report_area   > "$STEP_RPT_DIR/${DESIGN}_area.rpt"
report_qor    > "$STEP_RPT_DIR/${DESIGN}_qor.rpt"

# Export compressed netlist, SCANDEF, and SDC
write_hdl                  > "$NETLISTS_DIR/${DESIGN}_scan_compressed.v"
write_scandef -version 5.5 > "$NETLISTS_DIR/${DESIGN}_scan_compressed.def"
write_sdc                  > "$NETLISTS_DIR/${DESIGN}_scan_compressed.sdc"

# Export Modus ATPG workspace for compression mode
file delete -force $ATPG_DIR
file mkdir $ATPG_DIR

write_dft_atpg \
    -compression \
    -library $ATPG_LIB \
    -build_model_options "-allowmissingmodules yes" \
    -directory "$ATPG_DIR" \
    $DESIGN

# Save checkpoint database
set DB_FILE "$DBS_DIR/05_compressed.db"
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 5 compression insertion completed. Checkpoint saved: $DB_FILE"
exit

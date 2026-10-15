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

# Prepare ATPG library with resolved absolute paths to fix broken relative ./LIBS paths
set resolved_atpg_lib "$STEP_RPT_DIR/atpg_libs.v"
set fp [open $resolved_atpg_lib w]
set found_stdcell 0
if {[file exists "$LIB_DIR/atpg/include_libraries.v"]} {
    set orig_fp [open "$LIB_DIR/atpg/include_libraries.v" r]
    while {[gets $orig_fp line] >= 0} {
        if {[regexp {`include\s+"(\./)?LIBS/([^"]+)"} $line -> prefix subpath]} {
            set target "$LIB_DIR/$subpath"
            if {[file exists $target]} {
                puts $fp "`include \"$target\""
                if {[string match "*stdcell.v" $target]} { set found_stdcell 1 }
            }
        } else {
            puts $fp $line
        }
    }
    close $orig_fp
}
if {!$found_stdcell && [file exists "$LIB_DIR/atpg/stdcell.v"]} {
    puts $fp "`include \"$LIB_DIR/atpg/stdcell.v\""
}
close $fp

# Run Compressibility Analysis with Modus ATPG
set asc_dir "$STEP_RPT_DIR/asc_1channel"
set asc_rpt "$STEP_RPT_DIR/${DESIGN}_compressibility.rpt"
file delete -force $asc_dir

analyze_scan_compressibility \
    -library $resolved_atpg_lib \
    -build_model_options "-allowmissingmodules yes" \
    -compression_method compress_scan_chains \
    -compressor xor \
    -decompressor broadcast \
    -mask wide1 \
    -ratios {50 60 70 80} \
    -directory $asc_dir \
    -verbose

report_scan_compressibility -directory $asc_dir > $asc_rpt

# Save checkpoint database
set DB_FILE "$DBS_DIR/04_stitched.db"
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 4 compression analysis completed. Checkpoint saved: $DB_FILE"
exit

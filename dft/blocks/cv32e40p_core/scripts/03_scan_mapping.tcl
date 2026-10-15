###############################################################################
## Step 3: Generic Synthesis & Technology Mapping to Scan Flip-Flops
## Target: cv32e40p_core
## Goal:
##   1. Restore the pre-DFT verified design from Step 2 (02_tdrc.db).
##   2. Synthesize RTL into generic logic (syn_generic).
##   3. Configure scan mapping attributes:
##      - dft_scan_map_mode = tdrc_pass (only map registers that passed TDRC)
##      - dft_connect_shift_enable_during_mapping = tie_off
##      - dft_connect_scan_data_pins_during_mapping = loopback
##   4. Map generic logic to target technology gates and substitute regular
##      flip-flops with Mux-D scan flip-flops (syn_map).
##   5. Verify post-mapping DFT rules and report mapped scan flip-flops.
##   6. Save checkpoint database (03_mapped.db) for Step 4 (Scan Stitching).
###############################################################################

# Source common environment setup
set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR "$REPORTS_DIR/03_mapping"
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

puts "=========================================================================="
puts "  STAGE 3: LOGIC SYNTHESIS & SCAN FLOP REPLACEMENT (syn_map)              "
puts "=========================================================================="

#-------------------------------------------------------------------------------
# 1. Restore Checkpoint Database from Step 2
#-------------------------------------------------------------------------------
set PREV_DB "$DBS_DIR/02_tdrc.db"
if {![file exists $PREV_DB]} {
    puts "ERROR: Checkpoint database $PREV_DB not found!"
    puts "Please execute Step 2 (./run_step.sh 2) first."
    exit 1
}

puts "INFO: Restoring design checkpoint from $PREV_DB..."
read_db $PREV_DB

#-------------------------------------------------------------------------------
# 2. Generic Synthesis (syn_generic)
# Optimizes RTL logic structures into technology-independent generic gates (GTECH)
#-------------------------------------------------------------------------------
puts "INFO: Running generic logic synthesis (syn_generic)..."
syn_generic

#-------------------------------------------------------------------------------
# 3. Configure Scan Mapping Controls
# (Verified against Cadence Genus DFT User Guide: basic_flows_re_Synthesize_the_Design.html)
#-------------------------------------------------------------------------------
puts "INFO: Configuring scan mapping attributes..."

# Only map flip-flops that passed Pre-DFT TDRC rules to scan flip-flops
set_db [current_design] .dft_scan_map_mode tdrc_pass

# Temporarily tie off Shift Enable to inactive state during logic mapping
# so timing analysis accurately reflects functional operation
set_db [current_design] .dft_connect_shift_enable_during_mapping tie_off

# Connect Scan-In (SI) pin to Scan-Out (Q) pin in loopback mode during mapping
# to prevent floating inputs prior to chain stitching in Step 4
set_db [current_design] .dft_connect_scan_data_pins_during_mapping loopback

# Allow mixing rising and falling clock edge flip-flops with lockup protection
set_db [current_design] .dft_mix_clock_edges_in_scan_chains true

#-------------------------------------------------------------------------------
# 4. Technology Mapping with Scan Replacement (syn_map)
# Maps generic gates to technology standard cells and replaces regular DFFs
# with Mux-D scan flip-flops from slow.lib
#-------------------------------------------------------------------------------
puts "INFO: Mapping generic gates to technology cells and replacing flip-flops with scan equivalents (syn_map)..."
syn_map

#-------------------------------------------------------------------------------
# 5. Post-Mapping Health Check & Reports
#-------------------------------------------------------------------------------
puts "INFO: Verifying Post-Mapping DFT Rules..."
check_dft_rules > "$STEP_RPT_DIR/${DESIGN}_dft_rules_post_map.rpt"

puts "INFO: Generating gate-level area and scan register reports..."
report_gates          > "$STEP_RPT_DIR/${DESIGN}_gates.rpt"
report_scan_registers > "$STEP_RPT_DIR/${DESIGN}_scan_registers.rpt"

puts "INFO: Post-map DRC report:  $STEP_RPT_DIR/${DESIGN}_dft_rules_post_map.rpt"
puts "INFO: Scan registers list:  $STEP_RPT_DIR/${DESIGN}_scan_registers.rpt"

#-------------------------------------------------------------------------------
# 6. Save Checkpoint Database for Step 4
#-------------------------------------------------------------------------------
set DB_FILE "$DBS_DIR/03_mapped.db"
puts "INFO: Saving checkpoint database to $DB_FILE..."
write_db -all_root_attributes -to_file $DB_FILE

puts "=========================================================================="
puts "  STAGE 3 COMPLETED SUCCESSFULLY!                                       "
puts "  Post-Map DRC:   $STEP_RPT_DIR/${DESIGN}_dft_rules_post_map.rpt          "
puts "  Database Saved: $DB_FILE                                              "
puts "  Next Step:      04_scan_stitching.tcl                                 "
puts "=========================================================================="
exit

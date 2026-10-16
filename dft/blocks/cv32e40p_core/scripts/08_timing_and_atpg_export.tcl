set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR [file normalize "$REPORTS_DIR/08_atpg"]
set SA_DIR       [file normalize "$ATPG_DIR/stuck_at"]
set DELAY_DIR    [file normalize "$ATPG_DIR/delay"]

file mkdir $STEP_RPT_DIR
file mkdir $SA_DIR
file mkdir $DELAY_DIR
file mkdir $NETLISTS_DIR
file mkdir $DBS_DIR

# Restore Step 7 compressed database
set PREV_DB [file normalize "$DBS_DIR/07_compressed.db"]
if {![file exists $PREV_DB]} {
    puts "ERROR: Database $PREV_DB not found! Please run Step 7 first."
    exit 1
}
read_db $PREV_DB

# Verify timing constraints; reload SDC if no clocks exist
if {[llength [get_db clocks *]] == 0} {
    set SDC_FILE [file normalize "$SCRIPT_DIR/../constraints/cv32e40p_core.sdc"]
    if {[file exists $SDC_FILE]} {
        puts "INFO: Reading SDC constraints from $SDC_FILE..."
        read_sdc $SDC_FILE
    }
}

# Post-DFT Timing & QoR Analysis
set STEP_TIMING_DIR [file normalize "$REPORTS_DIR/08_timing"]
file mkdir $STEP_TIMING_DIR

puts "INFO: Running timing analysis on final compressed design..."
check_timing_intent          > "$STEP_TIMING_DIR/${DESIGN}_check_timing_intent.rpt"
report_timing -path_type summary > "$STEP_TIMING_DIR/${DESIGN}_timing_summary.rpt"
report_timing -max_paths 20  > "$STEP_TIMING_DIR/${DESIGN}_timing_paths.rpt"
report_timing -unconstrained > "$STEP_TIMING_DIR/${DESIGN}_unconstrained.rpt"
report_qor                   > "$STEP_TIMING_DIR/${DESIGN}_qor.rpt"

puts "=================================================================="
puts " Post-DFT QoR & Timing Summary:"
puts "=================================================================="
report_qor

# Export final compressed gate-level Verilog netlist
set FINAL_NETLIST [file normalize "$NETLISTS_DIR/${DESIGN}_compressed.v"]
write_hdl > $FINAL_NETLIST
puts "INFO: Exported compressed netlist: $FINAL_NETLIST"

# Export Stuck-At ATPG workspace for Modus (including IEEE 1500 serial testmodes)
puts "INFO: Generating Modus Stuck-At ATPG scripts..."
write_dft_atpg \
    -directory $SA_DIR \
    -library $ATPG_LIB \
    -compression \
    -serial \
    -build_model_options "-allowmissingmodules yes" \
    -run_from_directory \
    -force

# Export Transition Delay (At-Speed OCC) ATPG workspace for Modus
puts "INFO: Generating Modus Transition Delay (OPCG At-Speed) ATPG scripts..."
write_dft_atpg \
    -directory $DELAY_DIR \
    -library $ATPG_LIB \
    -compression \
    -delay \
    -build_model_options "-allowmissingmodules yes" \
    -run_from_directory \
    -force

puts "INFO: Modus Stuck-At ATPG script exported to: $SA_DIR/runmodus.atpg.tcl"
puts "INFO: Modus Transition Delay ATPG script exported to: $DELAY_DIR/runmodus.atpg.tcl"
puts "INFO: To run ATPG manually with Modus:"
puts "INFO:   cd $SA_DIR && modus -file runmodus.atpg.tcl"
puts "INFO:   cd $DELAY_DIR && modus -file runmodus.atpg.tcl"
puts "INFO: Step 8 Timing analysis and ATPG script export completed successfully."
exit

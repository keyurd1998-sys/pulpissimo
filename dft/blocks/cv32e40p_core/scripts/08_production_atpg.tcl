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

# Export final compressed gate-level Verilog netlist
set FINAL_NETLIST [file normalize "$NETLISTS_DIR/${DESIGN}_compressed.v"]
write_hdl > $FINAL_NETLIST
puts "INFO: Exported compressed netlist: $FINAL_NETLIST"

# Export Stuck-At ATPG workspace for Modus
puts "INFO: Generating Modus Stuck-At ATPG scripts..."
write_dft_atpg \
    -directory $SA_DIR \
    -library $ATPG_LIB \
    -compression \
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

# Run Modus Stuck-At ATPG
puts "INFO: Executing Modus Stuck-At ATPG in $SA_DIR..."
shell modus -file "$SA_DIR/runmodus.atpg.tcl"

# Run Modus Transition Delay ATPG
puts "INFO: Executing Modus Transition Delay ATPG in $DELAY_DIR..."
shell modus -file "$DELAY_DIR/runmodus.atpg.tcl"

puts "INFO: Step 8 Production ATPG (Stuck-At & Transition Delay) completed successfully."
exit

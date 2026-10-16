set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR "$REPORTS_DIR/03_mapping"
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

read_db "$DBS_DIR/02_tdrc.db"

# Generic synthesis
syn_generic

# Configure scan mapping attributes
set_db [current_design] .dft_scan_map_mode tdrc_pass
set_db [current_design] .dft_connect_shift_enable_during_mapping tie_off
set_db [current_design] .dft_connect_scan_data_pins_during_mapping loopback
set_db [current_design] .dft_mix_clock_edges_in_scan_chains true

# Technology mapping with scan flop replacement
syn_map

# Post-mapping DRC and reports
check_dft_rules       > "$STEP_RPT_DIR/${DESIGN}_dft_rules_post_map.rpt"
report_gates          > "$STEP_RPT_DIR/${DESIGN}_gates.rpt"
report_scan_registers > "$STEP_RPT_DIR/${DESIGN}_scan_registers.rpt"

# Save checkpoint database
set DB_FILE "$DBS_DIR/03_mapped.db"
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 3 completed successfully. Checkpoint saved: $DB_FILE"
exit

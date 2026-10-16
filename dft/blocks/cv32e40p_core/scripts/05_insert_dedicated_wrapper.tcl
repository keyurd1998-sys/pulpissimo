set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR [file normalize "$REPORTS_DIR/05_wrapper"]
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

# Restore Step 4 OPCG database
set PREV_DB [file normalize "$DBS_DIR/04_opcg.db"]
if {![file exists $PREV_DB]} {
    puts "ERROR: $DBS_DIR/04_opcg.db not found! Please run Step 4 first."
    exit 1
}
read_db $PREV_DB

# Shift enable port created in Step 2
set se_port [get_db ports SCAN_ENABLE]

# Identify all functional ports to wrap (exclude clocks, resets, and all DFT / IEEE 1500 control pins)
set EXCLUDE_PORTS [list clk_i rst_ni scan_cg_en_i pulp_clock_en_i \
                        test_mode opcg_mode scan_clk opcg_load_clk \
                        scan_en SCAN_ENABLE opcg_trigger \
                        SERIAL_WRCK ShiftWR UpdateWR WIR_SEL WRSTN WSI WSO WIR_TEST \
                        WINT WEXT SERIAL BYPASS]

set WRAP_PORTS [list]
foreach p [get_db ports *] {
    set pname [get_db $p .base_name]
    if {[lsearch -exact $EXCLUDE_PORTS $pname] == -1} {
        lappend WRAP_PORTS $p
    }
}

puts "INFO: Wrapping [llength $WRAP_PORTS] functional ports with Dedicated Wrapper Cells (DWC)..."

# Insert Dedicated Wrapper Cells connected to WIR internal mode controls (wir_instance/WINT and wir_instance/WEXT)
set skipped_ports [list]
add_core_wrapper_cell \
    -locations $WRAP_PORTS \
    -wsen_in $se_port \
    -wsen_out $se_port \
    -wint wir_instance/WINT \
    -wext wir_instance/WEXT \
    -skipped_locations_variable skipped_ports

# Post-wrapper DFT DRC and wrapper reports
check_dft_rules                  > "$STEP_RPT_DIR/${DESIGN}_dft_rules.rpt"
report_core_wrapper_cell         > "$STEP_RPT_DIR/${DESIGN}_wrapper_cells.rpt"
report_core_wrapper_cell -report_flops > "$STEP_RPT_DIR/${DESIGN}_wrapper_cells_detailed.rpt"

# Save checkpoint database
set DB_FILE [file normalize "$DBS_DIR/05_wrapper.db"]
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 5 Dedicated Boundary Wrapper Insertion completed. Checkpoint saved: $DB_FILE"
exit

set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR [file normalize "$REPORTS_DIR/05_wrapper"]
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

# Restore Step 4 OPCG database; fallback to Step 3 mapped database
set PREV_DB [file normalize "$DBS_DIR/04_opcg.db"]
if {![file exists $PREV_DB]} {
    set PREV_DB [file normalize "$DBS_DIR/03_mapped.db"]
    if {![file exists $PREV_DB]} {
        puts "ERROR: Neither $DBS_DIR/04_opcg.db nor $DBS_DIR/03_mapped.db found!"
        exit 1
    }
}
read_db $PREV_DB

# Ensure IEEE 1500 Wrapper Instruction Register (WIR) exists
set wir_inst [get_db hinsts *wir_instance*]
if {[llength $wir_inst] == 0} {
    puts "INFO: wir_instance not found in restored database. Defining and inserting IEEE 1500 WIR..."
    # 1. Wrapper Serial Control (WSC) interface ports
    define_test_signal -function serial_wrck   -name WRCK      -create_port SERIAL_WRCK
    define_test_signal -function shift_wr      -name ShiftWR   -create_port ShiftWR
    define_test_signal -function update_wr     -name UpdateWR  -create_port UpdateWR
    define_test_signal -function select_wir    -name WIR_SEL   -create_port WIR_SEL
    define_test_signal -function wrapper_reset -name WRSTN     -create_port WRSTN -active low -lec_value 0
    define_test_signal -function serial_sdi    -name WSI       -create_port WSI
    define_test_signal -function serial_sdo    -name WSO       -create_port WSO
    define_test_signal -function wir_test      -name WIR_TEST  -create_port WIR_TEST -lec_value 0

    # 2. IEEE 1500 Decoded Instructions (WIR internal mode signals)
    define_test_signal -function wint          -name WINT      -wir_signal
    define_test_signal -function wext          -name WEXT      -wir_signal
    define_test_signal -function select_serial -name SERIAL    -wir_signal
    define_test_signal -function select_bypass -name BYPASS    -wir_signal

    # 3. Insert WIR module
    add_wir_signal_bits -preview
    add_wir_signal_bits
} else {
    puts "INFO: Existing IEEE 1500 WIR instance detected: [get_db $wir_inst .name]"
}

# Determine shift enable port
set se_port [get_db ports SCAN_ENABLE]
if {[llength $se_port] == 0} {
    set se_port [get_db ports scan_en]
}

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

# Insert Dedicated Wrapper Cells connected directly to WIR internal mode controls (wir_instance/WINT and wir_instance/WEXT)
# -skipped_locations_variable allows Genus to skip floating/unconnected ports (e.g. boot_addr_i[1:0], apu_*) without erroring
set skipped_ports [list]
add_core_wrapper_cell \
    -locations $WRAP_PORTS \
    -wsen_in $se_port \
    -wsen_out $se_port \
    -wint wir_instance/WINT \
    -wext wir_instance/WEXT \
    -skipped_locations_variable skipped_ports

if {[info exists skipped_ports] && [llength $skipped_ports] > 0} {
    puts "INFO: Skipped [llength $skipped_ports] floating/unconnected ports during wrapper insertion."
    set fp [open "$STEP_RPT_DIR/${DESIGN}_skipped_ports.rpt" w]
    puts $fp "=================================================================="
    puts $fp " Skipped Ports During Wrapper Insertion (Floating / Unconnected)"
    puts $fp " Total Skipped Ports: [llength $skipped_ports]"
    puts $fp "=================================================================="
    foreach sp $skipped_ports {
        puts $fp "  $sp"
    }
    close $fp
}

# Post-wrapper DFT DRC and wrapper reports
check_dft_rules                  > "$STEP_RPT_DIR/${DESIGN}_dft_rules.rpt"
report_core_wrapper_cell         > "$STEP_RPT_DIR/${DESIGN}_wrapper_cells.rpt"
report_core_wrapper_cell -report_flops > "$STEP_RPT_DIR/${DESIGN}_wrapper_cells_detailed.rpt"

# Save checkpoint database
set DB_FILE [file normalize "$DBS_DIR/05_wrapper.db"]
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 5 Dedicated Boundary Wrapper Insertion completed. Checkpoint saved: $DB_FILE"
exit

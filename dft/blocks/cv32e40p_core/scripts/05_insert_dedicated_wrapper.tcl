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

# Define Wrapper Test Control Signals (creates WINT and WEXT mode control ports)
define_test_signal -function wint -name WINT -create_port WINT
define_test_signal -function wext -name WEXT -create_port WEXT

# Determine shift enable port
set se_port [get_db ports SCAN_ENABLE]
if {[llength $se_port] == 0} {
    set se_port [get_db ports scan_en]
}

# Identify all functional ports to wrap (exclude clocks, resets, DFT control pins, and test data pins)
set EXCLUDE_PATTERNS [list clk_i rst_ni scan_cg_en_i pulp_clock_en_i \
                           test_mode opcg_mode scan_clk opcg_load_clk \
                           scan_en* SCAN_ENABLE* opcg_trigger* WINT* WEXT* \
                           scan_in* scan_out* WSI* WSO* WPI* WPO*]

set WRAP_PORTS [list]
foreach p [get_db ports *] {
    set pname [get_db $p .base_name]
    set is_excluded 0
    foreach pat $EXCLUDE_PATTERNS {
        if {[string match $pat $pname]} {
            set is_excluded 1
            break
        }
    }
    if {!$is_excluded} {
        lappend WRAP_PORTS $p
    }
}

puts "INFO: Wrapping [llength $WRAP_PORTS] functional ports with Dedicated Wrapper Cells (DWC)..."

# Insert Dedicated Wrapper Cells (omitting -shared_through forces dedicated cells)
add_core_wrapper_cell \
    -locations $WRAP_PORTS \
    -wsen_in $se_port \
    -wsen_out $se_port \
    -wint WINT \
    -wext WEXT

# Post-wrapper DFT DRC and wrapper reports
check_dft_rules          > "$STEP_RPT_DIR/${DESIGN}_dft_rules.rpt"
report_core_wrapper_cell > "$STEP_RPT_DIR/${DESIGN}_wrapper_cells.rpt"

# Save checkpoint database
set DB_FILE [file normalize "$DBS_DIR/05_wrapper.db"]
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 5 Dedicated Boundary Wrapper Insertion completed. Checkpoint saved: $DB_FILE"
exit

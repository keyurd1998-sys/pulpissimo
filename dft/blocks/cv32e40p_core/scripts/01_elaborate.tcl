set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR "$REPORTS_DIR/01_elaboration"
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

# Global synthesis attributes
set_db root: .max_cpus_per_server 8
set_db root: .information_level 9
set_db root: .hdl_array_naming_style %s\[%d\]
set_db root: .hdl_unconnected_input_port_value none
set_db root: .hdl_undriven_output_port_value   none
set_db root: .hdl_undriven_signal_value        none

set_db root: .syn_generic_effort medium
set_db root: .syn_map_effort     high
set_db root: .syn_opt_effort     high

set_db root: .init_lib_search_path [list . "$LIB_DIR/timing" "$LIB_DIR/lef"]

# Load target libraries
set_db root: .lib_lef_consistency_check_enable false
read_libs $TIMING_LIB
if {[file exists $LEF_FILE]} {
    read_physical -lef $LEF_FILE
}
set_db [get_db lib_cells] .avoid false
set_db root: .lp_insert_clock_gating false

# Parse filelist and read RTL
set inc_dirs [list]
set rtl_files [list]
set fp [open $FLIST r]
while {[gets $fp line] >= 0} {
    set line [string trim $line]
    if {$line eq "" || [string match "//*" $line] || [string match "#*" $line]} {
        continue
    }
    regsub -all {\$\{CV32E40P_DIR\}} $line $CV32E40P_DIR line
    if {[string match "+incdir+*" $line]} {
        regsub {^\+incdir\+} $line "" dir_path
        lappend inc_dirs $dir_path
    } else {
        lappend rtl_files $line
    }
}
close $fp

set_db root: .init_hdl_search_path $inc_dirs
read_hdl -language sv $rtl_files

# Elaborate design
elaborate $DESIGN

# Checks and reports
check_design -unresolved > "$STEP_RPT_DIR/${DESIGN}_unresolved.rpt"
report_design            > "$STEP_RPT_DIR/${DESIGN}_design_summary.rpt"
report_hierarchy         > "$STEP_RPT_DIR/${DESIGN}_hierarchy.rpt"

# Save checkpoint database
set DB_FILE "$DBS_DIR/01_elaborated.db"
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 1 completed successfully. Checkpoint saved: $DB_FILE"
exit

###############################################################################
## Step 1: RTL Elaboration & Design Health Check
## Target: cv32e40p_core
## Goal:
##   1. Load standard cell timing and physical libraries.
##   2. Parse the SystemVerilog filelist and analyze RTL.
##   3. Elaborate top-level module into generic logic gates (GTECH).
##   4. Check for any unresolved module instances, black boxes, or syntax issues.
##   5. Save the checkpoint database (01_elaborated.db) for Step 2.
###############################################################################

# Source common environment setup
set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR "$REPORTS_DIR/01_elaboration"
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

puts "=========================================================================="
puts "  STAGE 1: RTL ELABORATION & LIBRARY LOADING                              "
puts "=========================================================================="

#-------------------------------------------------------------------------------
# 1. Global Synthesis Attributes
#-------------------------------------------------------------------------------
set_db root: .max_cpus_per_server 8
set_db root: .information_level 9

# Clean bus and array naming for downstream formal verification and ATPG
set_db root: .hdl_array_naming_style %s\[%d\]
set_db root: .hdl_unconnected_input_port_value none
set_db root: .hdl_undriven_output_port_value   none
set_db root: .hdl_undriven_signal_value        none

set_db root: .syn_generic_effort medium
set_db root: .syn_map_effort     high
set_db root: .syn_opt_effort     high

# Search paths
set_db root: .init_lib_search_path [list . "$LIB_DIR/timing" "$LIB_DIR/lef"]

#-------------------------------------------------------------------------------
# 2. Load Target Libraries
#-------------------------------------------------------------------------------
# Disable LEF consistency check to prevent Genus from marking library cells as 'avoid' (PHYS-103)
set_db root: .lib_lef_consistency_check_enable false

puts "INFO: Reading timing library: $TIMING_LIB"
read_libs $TIMING_LIB

if {[file exists $LEF_FILE]} {
    puts "INFO: Reading physical LEF: $LEF_FILE"
    read_physical -lef $LEF_FILE
}

# Ensure all library cells (standard cells, scan flip-flops) are usable
set_db [get_db lib_cells] .avoid false

# Disable automated clock gating insertion to avoid requiring missing ICG cells
set_db root: .lp_insert_clock_gating false

#-------------------------------------------------------------------------------
# 3. Parse Filelist and Read RTL
#-------------------------------------------------------------------------------
puts "INFO: Reading SystemVerilog RTL files from $FLIST..."
set inc_dirs [list]
set rtl_files [list]

set fp [open $FLIST r]
while {[gets $fp line] >= 0} {
    set line [string trim $line]
    if {$line eq "" || [string match "//*" $line] || [string match "#*" $line]} {
        continue
    }
    # Substitute ${CV32E40P_DIR} with actual checkout path
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

#-------------------------------------------------------------------------------
# 4. Elaborate Design (RTL -> GTECH generic gates)
#-------------------------------------------------------------------------------
puts "INFO: Elaborating top-level module '$DESIGN'..."
elaborate $DESIGN

#-------------------------------------------------------------------------------
# 5. Sanity Checks & Reports
#-------------------------------------------------------------------------------
puts "INFO: Checking design for unresolved references or errors..."
check_design -unresolved > "$STEP_RPT_DIR/${DESIGN}_unresolved.rpt"

report_design   > "$STEP_RPT_DIR/${DESIGN}_design_summary.rpt"
report_hierarchy > "$STEP_RPT_DIR/${DESIGN}_hierarchy.rpt"

puts "INFO: Unresolved modules check report: $STEP_RPT_DIR/${DESIGN}_unresolved.rpt"

#-------------------------------------------------------------------------------
# 6. Save Checkpoint Database
#-------------------------------------------------------------------------------
set DB_FILE "$DBS_DIR/01_elaborated.db"
puts "INFO: Saving checkpoint database to $DB_FILE..."
write_db -all_root_attributes -to_file $DB_FILE

puts "=========================================================================="
puts "  STAGE 1 COMPLETED SUCCESSFULLY!                                       "
puts "  Database Saved: $DB_FILE                                              "
puts "  Next Step:      02_dft_setup_tdrc.tcl                                 "
puts "=========================================================================="
exit

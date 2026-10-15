###############################################################################
## Cadence Genus Synthesis & DFT Scan Insertion Script
## Target: cv32e40p_core (PULPissimo RISC-V Core)
## Technology: Cadence Reference Library (/home/admin/DFT/Library)
## Verified against: Cadence Genus DFT User Guide & Command Reference (v23.1)
###############################################################################

puts "=========================================================================="
puts "  STARTING GENUS SYNTHESIS & DFT SCAN INSERTION: CV32E40P CORE           "
puts "=========================================================================="

#-------------------------------------------------------------------------------
# Step 1: Directory Setup & Variable Definitions
#-------------------------------------------------------------------------------
set DESIGN       "cv32e40p_core"
set SCRIPT_DIR   [file dirname [file normalize [info script]]]
set DFT_ROOT     [file normalize "$SCRIPT_DIR/.."]
set REPO_ROOT    [file normalize "$DFT_ROOT/.."]
set RESULTS_DIR  "$DFT_ROOT/results"
set FLIST        "$DFT_ROOT/filelists/cv32e40p_core.flist"
set SDC_FILE     "$DFT_ROOT/constraints/cv32e40p_core.sdc"

# Direct target library paths on server
set LIB_DIR      "/home/admin/DFT/Library"
set TIMING_LIB   "$LIB_DIR/timing/slow.lib"
set LEF_FILE     "$LIB_DIR/lef/all.lef"
set ATPG_LIB     "$LIB_DIR/atpg/include_libraries.v"

puts "INFO: Library Base Directory: $LIB_DIR"
puts "INFO: Timing Library:         $TIMING_LIB"
puts "INFO: Floorplan LEF:          $LEF_FILE"
puts "INFO: Modus ATPG Library:     $ATPG_LIB"

# Dynamically locate CV32E40P checkout directory from Bender
if {[info exists env(CV32E40P_DIR)] && [file isdirectory $env(CV32E40P_DIR)]} {
    set CV32E40P_DIR $env(CV32E40P_DIR)
} else {
    set cv_dirs [glob -nocomplain "$REPO_ROOT/.bender/git/checkouts/cv32e40p-*"]
    if {[llength $cv_dirs] > 0} {
        set CV32E40P_DIR [lindex $cv_dirs 0]
    } else {
        puts "ERROR: Cannot find cv32e40p checkout under $REPO_ROOT/.bender/git/checkouts/!"
        puts "Please ensure 'make checkout' was run at the repository root."
        exit 1
    }
}
puts "INFO: CV32E40P RTL Directory: $CV32E40P_DIR"

# Create output subdirectories
file mkdir "$RESULTS_DIR/reports"
file mkdir "$RESULTS_DIR/netlists"
file mkdir "$RESULTS_DIR/dbs"
file mkdir "$RESULTS_DIR/modus_atpg"

#-------------------------------------------------------------------------------
# Step 2: Global Synthesis & Optimization Attributes
#-------------------------------------------------------------------------------
set_db root: .max_cpus_per_server 8
set_db root: .information_level 9

# Low-power clock gating insertion during synthesis
set_db root: .lp_insert_clock_gating true

# Clean array naming style for scan stitching and formal verification
set_db root: .hdl_array_naming_style %s\[%d\]
set_db root: .hdl_unconnected_input_port_value none
set_db root: .hdl_undriven_output_port_value   none
set_db root: .hdl_undriven_signal_value        none

# Synthesis effort levels
set_db root: .syn_generic_effort medium
set_db root: .syn_map_effort     high
set_db root: .syn_opt_effort     high

# Search paths
set_db root: .init_lib_search_path [list . "$LIB_DIR/timing" "$LIB_DIR/lef"]

#-------------------------------------------------------------------------------
# Step 3: Load Target Libraries
#-------------------------------------------------------------------------------
puts "INFO: Reading timing library..."
read_libs $TIMING_LIB

if {[file exists $LEF_FILE]} {
    puts "INFO: Reading physical LEF..."
    read_physical -lef $LEF_FILE
}

#-------------------------------------------------------------------------------
# Step 4: Parse Filelist and Read RTL
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
    # Expand ${CV32E40P_DIR}
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

puts "INFO: Elaborating design '$DESIGN'..."
elaborate $DESIGN
check_design -unresolved

#-------------------------------------------------------------------------------
# Step 5: Read Timing Constraints (SDC)
#-------------------------------------------------------------------------------
puts "INFO: Reading SDC constraints from $SDC_FILE..."
read_sdc $SDC_FILE

#-------------------------------------------------------------------------------
# Step 6: Configure DFT Parameters & Test Signals
# (Verified against Cadence Genus DFT User Guide: setup.html)
#-------------------------------------------------------------------------------
puts "INFO: Setting up DFT scan configuration and test signals..."

# Scan style: Standard multiplexed flip-flops (Mux-D scan style)
set_db root: .dft_scan_style muxed_scan
set_db root: .dft_prefix DFT_

set_db root: .dft_identify_top_level_test_clocks true
set_db root: .dft_identify_test_signals true
set_db root: .dft_identify_internal_test_clocks false
set_db root: .use_scan_seqs_for_non_dft false

# 1. Define Test Clock: functional clk_i used during scan shift & capture (period: 20000ps)
define_test_clock -name scan_clk -period 20000 [get_ports clk_i]

# 2. Define Asynchronous Reset: functional rst_ni is active-low
# Genus ensures it is held inactive (high) during scan shifting
define_test_signal -function async_set_reset -active low [get_ports rst_ni]

# 3. Define Shift Enable: creates dedicated primary input port SCAN_ENABLE
# Marked ideal to prevent premature buffering during synthesis
define_test_signal -function shift_enable -name scan_en -active high -ideal -create_port SCAN_ENABLE

# 4. Define Clock Gate Test Bypass for CV32E40P:
# Holds internal ICG clock gates transparent during scan shift
define_test_mode -name scan_cg_en -active high [get_ports scan_cg_en_i]

# 5. Link Shift Enable to low-power clock gates inserted during synthesis
if {[get_db root: .lp_insert_clock_gating] eq "true"} {
    set_db design:$DESIGN .lp_clock_gating_test_signal [get_db test_signal:$DESIGN/scan_en]
}

# Run Pre-DFT Testability Design Rule Check (TDRC)
puts "INFO: Running Pre-DFT Rule Check (TDRC)..."
check_dft_rules > "$RESULTS_DIR/reports/${DESIGN}_dft_rules_pre_syn.rpt"
report_dft_violations > "$RESULTS_DIR/reports/${DESIGN}_dft_violations_pre_syn.rpt"

#-------------------------------------------------------------------------------
# Step 7: Generic Synthesis & Scan Mapping
#-------------------------------------------------------------------------------
puts "INFO: Running generic synthesis..."
syn_generic

# Setup scan mapping behavior
set_db designs .dft_scan_map_mode tdrc_pass
set_db designs .dft_connect_shift_enable_during_mapping tie_off
set_db designs .dft_connect_scan_data_pins_during_mapping loopback
set_db designs .dft_mix_clock_edges_in_scan_chains true

puts "INFO: Mapping logic and replacing regular registers with scan flip-flops..."
syn_map

check_dft_rules > "$RESULTS_DIR/reports/${DESIGN}_dft_rules_post_map.rpt"

#-------------------------------------------------------------------------------
# Step 8: Configure & Connect Scan Chains
# (Verified against Cadence Genus DFT User Guide: run_configuration.html)
#-------------------------------------------------------------------------------
puts "INFO: Configuring and stitching 4 scan chains..."
set_db [current_design] .dft_min_number_of_scan_chains 4
set_db [current_design] .dft_mix_clock_edges_in_scan_chains true
set_db [current_design] .dft_lockup_element_type preferred_level_sensitive

# Define 4 scan chains with auto-created dedicated top-level ports (-create_ports)
define_scan_chain -name chain0 -sdi scan_in_0 -sdo scan_out_0 -create_ports -shift_enable scan_en
define_scan_chain -name chain1 -sdi scan_in_1 -sdo scan_out_1 -create_ports -shift_enable scan_en
define_scan_chain -name chain2 -sdi scan_in_2 -sdo scan_out_2 -create_ports -shift_enable scan_en
define_scan_chain -name chain3 -sdi scan_in_3 -sdo scan_out_3 -create_ports -shift_enable scan_en

# Stitch scan chains
connect_scan_chains -auto_create_chains

puts "INFO: Running Post-Stitching DRC..."
check_dft_rules > "$RESULTS_DIR/reports/${DESIGN}_dft_rules_post_scan.rpt"

#-------------------------------------------------------------------------------
# Step 9: Incremental Timing Optimization
#-------------------------------------------------------------------------------
puts "INFO: Running incremental timing optimization..."
syn_opt -incr

#-------------------------------------------------------------------------------
# Step 10: Reports
#-------------------------------------------------------------------------------
puts "INFO: Generating DFT, Area, and Timing reports..."
report_scan_chains    > "$RESULTS_DIR/reports/${DESIGN}_scan_chains.rpt"
report_scan_registers > "$RESULTS_DIR/reports/${DESIGN}_scan_registers.rpt"
report_scan_setup     > "$RESULTS_DIR/reports/${DESIGN}_scan_setup.rpt"
report_timing         > "$RESULTS_DIR/reports/${DESIGN}_timing.rpt"
report_area           > "$RESULTS_DIR/reports/${DESIGN}_area.rpt"
report_qor            > "$RESULTS_DIR/reports/${DESIGN}_qor.rpt"

#-------------------------------------------------------------------------------
# Step 11: Export Netlists, Constraints & Modus ATPG Package
# (Verified against Cadence Genus DFT User Guide: export_tk.html)
#-------------------------------------------------------------------------------
puts "INFO: Exporting scan-inserted netlist and constraints..."
write_hdl                      > "$RESULTS_DIR/netlists/${DESIGN}_scan.v"
write_scandef -version 5.5     > "$RESULTS_DIR/netlists/${DESIGN}_scan.def"
write_sdc                      > "$RESULTS_DIR/netlists/${DESIGN}_scan.sdc"
write_db -all_root_attributes  -to_file "$RESULTS_DIR/dbs/${DESIGN}_final_scan.db"

# Write out complete Modus ATPG workspace
puts "INFO: Generating Cadence Modus ATPG workspace..."
write_dft_atpg -library "$ATPG_LIB" \
               -directory "$RESULTS_DIR/modus_atpg" \
               -run_from_directory \
               $DESIGN

puts "=========================================================================="
puts "  GENUS DFT INSERTION COMPLETED SUCCESSFULLY!                           "
puts "  Netlist:   $RESULTS_DIR/netlists/${DESIGN}_scan.v                     "
puts "  Modus Dir: $RESULTS_DIR/modus_atpg                                    "
puts "=========================================================================="
exit

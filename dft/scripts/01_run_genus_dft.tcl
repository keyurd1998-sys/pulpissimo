###############################################################################
## Cadence Genus Synthesis & DFT Scan Insertion Script
## Target: cv32e40p_core (PULPissimo RISC-V Core)
## Flow: RTL -> Synthesis -> TDRC -> Scan Mapping -> Scan Stitching -> Modus Export
###############################################################################

puts "=========================================================================="
puts "  STARTING GENUS SYNTHESIS & DFT INSERTION FOR CV32E40P CORE             "
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

# Locate Target Standard Cell Library:
# Priority 1: Environment variable CADENCE_DFT_LIB
# Priority 2: Remote server path /home/admin/DFT/Library
# Priority 3: Standard RAK library location in user home
if {[info exists env(CADENCE_DFT_LIB)] && [file isdirectory $env(CADENCE_DFT_LIB)]} {
    set LIB_DIR $env(CADENCE_DFT_LIB)
} elseif {[file isdirectory "/home/admin/DFT/Library"]} {
    set LIB_DIR "/home/admin/DFT/Library"
} else {
    set LIB_DIR "$env(HOME)/keyurd1998-sys/LAB/GENUS_LABS/Normal_runs/Basic_Digital_Test_RAK_21.1/LIBS"
}
puts "INFO: Using Library Directory: $LIB_DIR"

# Locate CV32E40P Directory from Bender checkout
if {[info exists env(CV32E40P_DIR)] && [file isdirectory $env(CV32E40P_DIR)]} {
    set CV32E40P_DIR $env(CV32E40P_DIR)
} else {
    set cv_dirs [glob -nocomplain "$REPO_ROOT/.bender/git/checkouts/cv32e40p-*"]
    if {[llength $cv_dirs] > 0} {
        set CV32E40P_DIR [lindex $cv_dirs 0]
    } else {
        puts "ERROR: Cannot find cv32e40p checkout under $REPO_ROOT/.bender/git/checkouts/!"
        puts "Please run 'make checkout' at repository root first."
        exit 1
    }
}
puts "INFO: Using CV32E40P RTL Directory: $CV32E40P_DIR"

# Create output subdirectories
file mkdir "$RESULTS_DIR/reports"
file mkdir "$RESULTS_DIR/netlists"
file mkdir "$RESULTS_DIR/dbs"
file mkdir "$RESULTS_DIR/modus_atpg"

#-------------------------------------------------------------------------------
# Step 2: Global Attributes & Synthesis Setup
#-------------------------------------------------------------------------------
set_db root: .max_cpus_per_server 8
set_db root: .information_level 9

# Low-power clock gating insertion during synthesis
set_db root: .lp_insert_clock_gating true

# Clean array naming style for testability
set_db root: .hdl_array_naming_style %s\[%d\]
set_db root: .hdl_unconnected_input_port_value none
set_db root: .hdl_undriven_output_port_value   none
set_db root: .hdl_undriven_signal_value        none

# Effort levels
set_db root: .syn_generic_effort medium
set_db root: .syn_map_effort     high
set_db root: .syn_opt_effort     high

# Search paths
set_db root: .init_lib_search_path [list . "$LIB_DIR" "$LIB_DIR/timing" "$LIB_DIR/lef"]

#-------------------------------------------------------------------------------
# Step 3: Load Target Libraries
#-------------------------------------------------------------------------------
puts "INFO: Reading timing libraries..."
set timing_lib ""
if {[file exists "$LIB_DIR/timing/slow.lib"]} {
    set timing_lib "$LIB_DIR/timing/slow.lib"
} elseif {[file exists "$LIB_DIR/slow.lib"]} {
    set timing_lib "$LIB_DIR/slow.lib"
} else {
    set candidate_libs [glob -nocomplain "$LIB_DIR/timing/*.lib" "$LIB_DIR/*.lib"]
    if {[llength $candidate_libs] > 0} {
        set timing_lib [lindex $candidate_libs 0]
    }
}

if {$timing_lib ne ""} {
    puts "INFO: Found timing library: $timing_lib"
    read_libs $timing_lib
} else {
    puts "ERROR: No .lib file found under $LIB_DIR!"
    exit 1
}

if {[file exists "$LIB_DIR/lef/all.lef"]} {
    read_physical -lef "$LIB_DIR/lef/all.lef"
} elseif {[file exists "$LIB_DIR/all.lef"]} {
    read_physical -lef "$LIB_DIR/all.lef"
}

#-------------------------------------------------------------------------------
# Step 4: Parse Filelist and Read RTL
#-------------------------------------------------------------------------------
puts "INFO: Reading RTL files from $FLIST..."
set inc_dirs [list]
set rtl_files [list]

set fp [open $FLIST r]
while {[gets $fp line] >= 0} {
    set line [string trim $line]
    if {$line eq "" || [string match "//*" $line] || [string match "#*" $line]} {
        continue
    }
    # Substitute ${CV32E40P_DIR} dynamically
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
#-------------------------------------------------------------------------------
puts "INFO: Configuring DFT and defining test signals..."

# Scan style: Standard multiplexed flip-flops (Mux-D)
set_db root: .dft_scan_style muxed_scan
set_db root: .dft_prefix DFT_

set_db root: .dft_identify_top_level_test_clocks true
set_db root: .dft_identify_test_signals true
set_db root: .dft_identify_internal_test_clocks false
set_db root: .use_scan_seqs_for_non_dft false

# 1. Define Shift Enable (Active High) - creates dedicated top-level port
define_shift_enable -name scan_en -active high -create_port SCAN_ENABLE -default -lec_value 0

# 2. Define Test Mode (Active High) - creates dedicated top-level port
define_test_mode -name test_mode -active high -create_port TEST_MODE -lec_value 0

# 3. Define Test Clock: functional clock clk_i used during scan test (period 20ns)
define_test_clock -name scan_clk -period 20000 clk_i

# 4. Define Test Reset: functional reset rst_ni (Active Low)
define_test_mode -name scan_rst -active low -scan_shift rst_ni

# 5. Enable Clock Gate bypass during test shift
# In CV32E40P, scan_cg_en_i forces clock gates open during test
define_test_mode -name scan_cg_en -active high scan_cg_en_i

# Connect clock gating test signal for synthesis-inserted clock gates
if {[get_db root: .lp_insert_clock_gating] eq "true"} {
    set_db design:$DESIGN .lp_clock_gating_test_signal [get_db test_signal:$DESIGN/scan_en]
}

# Run Pre-DFT Testability Design Rule Check (TDRC)
puts "INFO: Running Pre-DFT Rule Check (TDRC)..."
check_dft_rules > "$RESULTS_DIR/reports/${DESIGN}_dft_rules_pre_syn.rpt"

#-------------------------------------------------------------------------------
# Step 7: Generic Synthesis & Scan Mapping
#-------------------------------------------------------------------------------
puts "INFO: Running generic synthesis..."
syn_generic

# Configure scan mapping rules
set_db designs .dft_scan_map_mode tdrc_pass
set_db designs .dft_connect_shift_enable_during_mapping tie_off
set_db designs .dft_connect_scan_data_pins_during_mapping loopback
set_db designs .dft_mix_clock_edges_in_scan_chains true

puts "INFO: Mapping logic and replacing flip-flops with scan equivalents..."
syn_map

check_dft_rules > "$RESULTS_DIR/reports/${DESIGN}_dft_rules_post_map.rpt"

#-------------------------------------------------------------------------------
# Step 8: Define & Stitch Scan Chains
#-------------------------------------------------------------------------------
puts "INFO: Stitching 4 scan chains..."
set_db root: .dft_min_number_of_scan_chains 4

define_scan_chain -name chain0 -create_pins
define_scan_chain -name chain1 -create_pins
define_scan_chain -name chain2 -create_pins
define_scan_chain -name chain3 -create_pins

connect_scan_chains

puts "INFO: Running Post-Stitching DRC..."
check_dft_rules > "$RESULTS_DIR/reports/${DESIGN}_dft_rules_post_scan.rpt"

#-------------------------------------------------------------------------------
# Step 9: Incremental Optimization
#-------------------------------------------------------------------------------
puts "INFO: Running incremental timing optimization..."
syn_opt -incr

#-------------------------------------------------------------------------------
# Step 10: Reports
#-------------------------------------------------------------------------------
puts "INFO: Writing reports..."
report_scan_chains    > "$RESULTS_DIR/reports/${DESIGN}_scan_chains.rpt"
report_scan_registers > "$RESULTS_DIR/reports/${DESIGN}_scan_registers.rpt"
report_scan_setup     > "$RESULTS_DIR/reports/${DESIGN}_scan_setup.rpt"
report_timing         > "$RESULTS_DIR/reports/${DESIGN}_timing.rpt"
report_area           > "$RESULTS_DIR/reports/${DESIGN}_area.rpt"
report_qor            > "$RESULTS_DIR/reports/${DESIGN}_qor.rpt"

#-------------------------------------------------------------------------------
# Step 11: Export Netlists, Constraints & Modus ATPG Package
#-------------------------------------------------------------------------------
puts "INFO: Exporting scan-inserted netlist and constraints..."
write_hdl                      > "$RESULTS_DIR/netlists/${DESIGN}_scan.v"
write_scandef -version 5.5     > "$RESULTS_DIR/netlists/${DESIGN}_scan.def"
write_sdc                      > "$RESULTS_DIR/netlists/${DESIGN}_scan.sdc"
write_db -all_root_attributes  -to_file "$RESULTS_DIR/dbs/${DESIGN}_final_scan.db"

# Write out complete Modus ATPG workspace
puts "INFO: Generating Modus ATPG workspace..."
set atpg_lib ""
if {[file exists "$LIB_DIR/atpg/include_libraries.v"]} {
    set atpg_lib "$LIB_DIR/atpg/include_libraries.v"
} elseif {[file exists "$LIB_DIR/include_libraries.v"]} {
    set atpg_lib "$LIB_DIR/include_libraries.v"
} elseif {[file exists "$LIB_DIR/atpg/stdcell.v"]} {
    set atpg_lib "$LIB_DIR/atpg/stdcell.v"
} elseif {[file exists "$LIB_DIR/stdcell.v"]} {
    set atpg_lib "$LIB_DIR/stdcell.v"
} else {
    set cand_atpg [glob -nocomplain "$LIB_DIR/atpg/*.v" "$LIB_DIR/*.v"]
    if {[llength $cand_atpg] > 0} {
        set atpg_lib [lindex $cand_atpg 0]
    }
}

if {$atpg_lib ne ""} {
    puts "INFO: Found ATPG library: $atpg_lib"
    write_dft_atpg -tcl \
                   -library $atpg_lib \
                   -directory "$RESULTS_DIR/modus_atpg" \
                   $DESIGN
} else {
    puts "WARNING: No ATPG Verilog model found under $LIB_DIR; generating ATPG template without -library"
    write_dft_atpg -tcl \
                   -directory "$RESULTS_DIR/modus_atpg" \
                   $DESIGN
}

puts "=========================================================================="
puts "  GENUS DFT INSERTION COMPLETED SUCCESSFULLY!                           "
puts "  Netlist: $RESULTS_DIR/netlists/${DESIGN}_scan.v                       "
puts "  Modus ATPG Files: $RESULTS_DIR/modus_atpg                             "
puts "=========================================================================="
exit

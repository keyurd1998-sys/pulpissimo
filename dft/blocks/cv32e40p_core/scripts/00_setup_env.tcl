###############################################################################
## Step 0: Common Environment Setup for CV32E40P Core
## This script is sourced by all subsequent step scripts.
###############################################################################

set DESIGN "cv32e40p_core"

# Resolve absolute directory paths
set SCRIPTS_DIR  [file dirname [file normalize [info script]]]
set BLOCK_DIR    [file normalize "$SCRIPTS_DIR/.."]
set DFT_ROOT     [file normalize "$BLOCK_DIR/../.."]
set REPO_ROOT    [file normalize "$DFT_ROOT/.."]

set DBS_DIR      "$BLOCK_DIR/dbs"
set REPORTS_DIR  "$BLOCK_DIR/reports"
set NETLISTS_DIR "$BLOCK_DIR/netlists"
set LOGS_DIR     "$BLOCK_DIR/logs"
set ATPG_DIR     "$BLOCK_DIR/atpg"

# Remote server target library paths
if {[info exists ::env(CADENCE_DFT_LIB)]} {
    set LIB_DIR $::env(CADENCE_DFT_LIB)
} else {
    set LIB_DIR "/home/admin/DFT/Library"
}

set TIMING_LIB "$LIB_DIR/timing/slow.lib"
set LEF_FILE   "$LIB_DIR/lef/all.lef"
set ATPG_LIB   "$LIB_DIR/atpg/include_libraries.v"

# Design Constraints and RTL Filelist
set FLIST    "$DFT_ROOT/filelists/cv32e40p_core.flist"
set SDC_FILE "$DFT_ROOT/constraints/cv32e40p_core.sdc"

# Locate Bender checked out RTL for cv32e40p
if {![info exists CV32E40P_DIR]} {
    set cv_dirs [glob -nocomplain -directory "$REPO_ROOT/.bender/git/checkouts" "cv32e40p*"]
    if {[llength $cv_dirs] > 0} {
        set CV32E40P_DIR [lindex $cv_dirs 0]
    } else {
        puts "ERROR: Cannot find cv32e40p checkout under $REPO_ROOT/.bender/git/checkouts/!"
        puts "Please ensure 'make checkout' was run at the repository root."
        exit 1
    }
}

puts "=========================================================================="
puts "  ENVIRONMENT INITIALIZED FOR BLOCK: $DESIGN"
puts "  Repo Root:    $REPO_ROOT"
puts "  Block Dir:    $BLOCK_DIR"
puts "  CV32E40P RTL: $CV32E40P_DIR"
puts "  Timing Lib:   $TIMING_LIB"
puts "=========================================================================="

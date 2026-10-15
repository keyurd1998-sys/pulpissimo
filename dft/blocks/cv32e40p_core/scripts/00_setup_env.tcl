set DESIGN "cv32e40p_core"

set SCRIPTS_DIR  [file dirname [file normalize [info script]]]
set BLOCK_DIR    [file normalize "$SCRIPTS_DIR/.."]
set DFT_ROOT     [file normalize "$BLOCK_DIR/../.."]
set REPO_ROOT    [file normalize "$DFT_ROOT/.."]

set DBS_DIR      "$BLOCK_DIR/dbs"
set REPORTS_DIR  "$BLOCK_DIR/reports"
set NETLISTS_DIR "$BLOCK_DIR/netlists"
set LOGS_DIR     "$BLOCK_DIR/logs"
set ATPG_DIR     "$BLOCK_DIR/atpg"

if {[info exists ::env(CADENCE_DFT_LIB)]} {
    set LIB_DIR $::env(CADENCE_DFT_LIB)
} else {
    set LIB_DIR "/home/admin/DFT/Library"
}

set TIMING_LIB "$LIB_DIR/timing/slow.lib"
set LEF_FILE   "$LIB_DIR/lef/all.lef"
set ATPG_LIB [file normalize "$LIB_DIR/atpg/stdcell.v"]

set FLIST    "$BLOCK_DIR/filelists/cv32e40p_core.flist"
set SDC_FILE "$BLOCK_DIR/constraints/cv32e40p_core.sdc"

if {![info exists CV32E40P_DIR]} {
    set cv_dirs [glob -nocomplain -directory "$REPO_ROOT/.bender/git/checkouts" "cv32e40p*"]
    if {[llength $cv_dirs] > 0} {
        set CV32E40P_DIR [lindex $cv_dirs 0]
    } else {
        puts "ERROR: Cannot find cv32e40p under $REPO_ROOT/.bender/git/checkouts/!"
        exit 1
    }
}

###############################################################################
## Cadence Modus ATPG Script
## Target: cv32e40p_core (PULPissimo RISC-V Core)
## Goal: ATPG Pattern Generation & Stuck-At Fault Coverage Analysis
###############################################################################

puts "=========================================================================="
puts "  STARTING CADENCE MODUS ATPG FOR CV32E40P CORE                          "
puts "=========================================================================="

#-------------------------------------------------------------------------------
# Step 1: Initialize Variables & Paths
#-------------------------------------------------------------------------------
set DESIGN       "cv32e40p_core"
set SCRIPT_DIR   [file dirname [file normalize [info script]]]
set DFT_ROOT     [file normalize "$SCRIPT_DIR/.."]
set RESULTS_DIR  "$DFT_ROOT/results"
set MODUS_DIR    "$RESULTS_DIR/modus_atpg"

if {[info exists env(CADENCE_DFT_LIB)] && [file isdirectory $env(CADENCE_DFT_LIB)]} {
    set LIB_DIR $env(CADENCE_DFT_LIB)
} else {
    set LIB_DIR "$env(HOME)/keyurd1998-sys/LAB/GENUS_LABS/Normal_runs/Basic_Digital_Test_RAK_21.1/LIBS"
}

set_db workdir $MODUS_DIR
set WORKDIR [get_db workdir]

set_option stdout summary
set ::env(CDS_LIC_REPORT) yes
set_db stop_on_severity error

# Clean previous temporary run data
file delete -force "$WORKDIR/tbdata"
file delete -force "$WORKDIR/testresults"

#-------------------------------------------------------------------------------
# Step 2: Build Logic Model
#-------------------------------------------------------------------------------
puts "INFO: Building Modus Logic Model..."
build_model \
    -cell                $DESIGN \
    -techlib             "$LIB_DIR/atpg/include_libraries.v" \
    -designsource        "$WORKDIR/${DESIGN}.test_netlist.v" \
    -allowmissingmodules yes \
    -messagecounteach    100

#-------------------------------------------------------------------------------
# Step 3: Build Test Model
#-------------------------------------------------------------------------------
puts "INFO: Building Test Model (FULLSCAN)..."
build_testmode \
    -testmode              FULLSCAN \
    -assignfile            "$WORKDIR/${DESIGN}.FULLSCAN.pinassign" \
    -modedef               FULLSCAN \
    -allowflushedmeasures  yes

#-------------------------------------------------------------------------------
# Step 4: Report & Verify Test Structures
#-------------------------------------------------------------------------------
puts "INFO: Reporting Scan Chains..."
report_test_structures \
    -testmode FULLSCAN \
    -reportscanchain all

puts "INFO: Verifying Test Structures (DRC)..."
verify_test_structures \
    -testmode FULLSCAN \
    -xclockanalysis yes

#-------------------------------------------------------------------------------
# Step 5: Build Fault Model (Stuck-At Faults)
#-------------------------------------------------------------------------------
puts "INFO: Building Fault Model..."
build_faultmodel \
    -includedynamic no

#-------------------------------------------------------------------------------
# Step 6: ATPG Pattern Generation
#-------------------------------------------------------------------------------
puts "INFO: Generating ATPG Patterns for Stuck-at Faults..."
create_logic_tests \
    -experiment "${DESIGN}_stuckat" \
    -testmode   FULLSCAN

# Report fault coverage summary
puts "INFO: Reporting Test Fault Summary & Coverage..."
report_faults \
    -experiment "${DESIGN}_stuckat" \
    -testmode   FULLSCAN

#-------------------------------------------------------------------------------
# Step 7: Export Verilog Test Vectors & Commit
#-------------------------------------------------------------------------------
puts "INFO: Exporting Verilog parallel simulation test vectors..."
write_vectors \
    -inexperiment "${DESIGN}_stuckat" \
    -testmode     FULLSCAN \
    -language     verilog \
    -scanformat   parallel

commit_tests \
    -inexperiment "${DESIGN}_stuckat" \
    -testmode     FULLSCAN

puts "=========================================================================="
puts "  MODUS ATPG COMPLETED SUCCESSFULLY!                                    "
puts "=========================================================================="
exit

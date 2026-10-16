set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR "$REPORTS_DIR/02_tdrc"
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

read_db "$DBS_DIR/01_elaborated.db"

# Read functional timing constraints
read_sdc $SDC_FILE

# Configure scan style and test signals
set_db root: .dft_scan_style muxed_scan
set_db root: .dft_prefix DFT_
set_db root: .dft_identify_top_level_test_clocks true
set_db root: .dft_identify_test_signals true
set_db root: .dft_identify_internal_test_clocks false
set_db root: .use_scan_seqs_for_non_dft false

define_test_clock -name scan_clk -period 20000 [get_ports clk_i]
define_test_mode -name scan_rst -active high -scan_shift -shared_input [get_ports rst_ni]
define_test_mode -name scan_cg_en -active high -shared_input [get_ports scan_cg_en_i]
define_test_signal -function shift_enable -name scan_en -active high -ideal -create_port SCAN_ENABLE

# ==============================================================================
# IEEE 1500 Standard Test Wrapper Architecture Setup
# ==============================================================================
# 1. Wrapper Serial Control (WSC) interface ports (external IEEE 1500 pins)
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

# 3. Insert Wrapper Instruction Register (WIR) module with shift & update slices
puts "INFO: Inserting IEEE 1500 Wrapper Instruction Register (WIR)..."
add_wir_signal_bits -preview
add_wir_signal_bits

# Run Pre-DFT Testability Design Rule Check (TDRC)
check_dft_rules       > "$STEP_RPT_DIR/${DESIGN}_dft_rules_pre_syn.rpt"
report_dft_violations > "$STEP_RPT_DIR/${DESIGN}_dft_violations_pre_syn.rpt"

# Save checkpoint database
set DB_FILE "$DBS_DIR/02_tdrc.db"
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 2 completed successfully. Checkpoint saved: $DB_FILE"
exit

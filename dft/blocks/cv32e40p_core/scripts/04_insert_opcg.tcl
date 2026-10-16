set SCRIPT_DIR [file dirname [file normalize [info script]]]
source "$SCRIPT_DIR/00_setup_env.tcl"

set STEP_RPT_DIR [file normalize "$REPORTS_DIR/04_opcg"]
file mkdir $STEP_RPT_DIR
file mkdir $DBS_DIR

read_db "$DBS_DIR/03_mapped.db"

# Disable automatic clock gating inside test logic during mapped insertion
set_db lp_insert_clock_gating false

# Enable OPCG domain blocking for cross-domain isolation
set_db dft_opcg_domain_blocking true

# Remove existing test clock from clk_i so clk_i can serve as free-running oscillator source
set existing_tclks [get_db test_clocks *]
if {[llength $existing_tclks] > 0} {
    delete_obj $existing_tclks
}
set existing_tdoms [get_db test_clock_domains *]
if {[llength $existing_tdoms] > 0} {
    delete_obj $existing_tdoms
}

# Define test control signals and test clocks for OCC/OPCG
define_test_mode -name test_mode -active high -create_port test_mode
define_test_mode -name opcg_mode -active high -create_port opcg_mode

define_test_clock -name scanClock -period 20000 -create_port scan_clk
define_test_clock -name opcgLoadClock -period 40000 -create_port opcg_load_clk

# Insert Clock Buffer on input port clk_i to create internal clock pin
insert_buffer -name u_opcg_clk_buf -buffer "BUFX12" -pin [get_db ports clk_i]
set osc_pin [get_db pins *u_opcg_clk_buf/Y]

# Define Oscillator Source on buffer output pin
define_opcg_osc_source -name OSC_MAIN \
    -ref_clock_pin [get_db ports clk_i] \
    -min_input_period 4000 -max_input_period 25000 \
    -min_output_period 2000 -max_output_period 5000 \
    $osc_pin

# Define Domain Macro Parameters (mandatory -min_target_period for mapped design)
define_opcg_domain_macro_parameters -name DOM_PARAMS_CORE \
    -max_num_pulse 2 \
    -counter_length 4 \
    -min_target_period 4000

# Define OPCG Trigger signal
define_opcg_trigger -name TRIGGER_CORE \
    -osc_source OSC_MAIN \
    -active high \
    -create_port opcg_trigger

# Define OPCG Clock Domain spliced at buffer output pin
define_opcg_domain -name DOMAIN_CORE \
    -osc_source OSC_MAIN \
    -domain_macro_parameter DOM_PARAMS_CORE \
    -opcg_trigger TRIGGER_CORE \
    -location $osc_pin \
    -min_domain_period 4000

# Insert OCC / OPCG Domain Macro Logic
add_opcg \
    -opcg_load_clock opcgLoadClock \
    -scan_clock scanClock \
    -test_enable test_mode \
    -opcg_enable opcg_mode

# Re-enable regular clock gating attribute
set_db lp_insert_clock_gating true

# Post-OPCG DFT DRC check and domain reports
check_dft_rules               > "$STEP_RPT_DIR/${DESIGN}_dft_rules.rpt"
report_opcg_clock_domain_info > "$STEP_RPT_DIR/${DESIGN}_opcg_info.rpt"

# Save checkpoint database
set DB_FILE [file normalize "$DBS_DIR/04_opcg.db"]
write_db -all_root_attributes -to_file $DB_FILE

puts "INFO: Step 4 OCC/OPCG insertion completed. Checkpoint saved: $DB_FILE"
exit

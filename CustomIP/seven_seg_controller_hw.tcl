# seven_seg_controller_hw.tcl
# Tcl script for creating the seven_seg_controller component in Qsys

package require -exact qsys 14.0

set_module_property NAME seven_seg_controller
set_module_property DISPLAY_NAME "Seven Segment Controller"
set_module_property DESCRIPTION "Custom IP for controlling 4-digit 7-segment display"
set_module_property VERSION 1.0
set_module_property GROUP "Custom IP"

# Add clock interface
add_interface clock clock end
set_interface_property clock ENABLED true
add_interface_port clock clk clk input 1

# Add reset interface
add_interface reset reset end
set_interface_property reset ENABLED true
set_interface_property reset associatedClock clock
add_interface_port reset reset reset input 1

# Add Avalon-MM slave interface for data input
add_interface avalon_slave avalon end
set_interface_property avalon_slave addressAlignment DYNAMIC
set_interface_property avalon_slave addressUnits WORDS
set_interface_property avalon_slave associatedClock clock
set_interface_property avalon_slave associatedReset reset
set_interface_property avalon_slave bitsPerSymbol 8
set_interface_property avalon_slave burstOnBurstBoundariesOnly false
set_interface_property avalon_slave burstcountUnits WORDS
set_interface_property avalon_slave constantBurstBehavior false
set_interface_property avalon_slave holdTime 0
set_interface_property avalon_slave linewrapBursts false
set_interface_property avalon_slave maximumPendingReadTransactions 0
set_interface_property avalon_slave maximumPendingWriteTransactions 0
set_interface_property avalon_slave readLatency 0
set_interface_property avalon_slave readWaitTime 1
set_interface_property avalon_slave setupTime 0
set_interface_property avalon_slave timingUnits Cycles
set_interface_property avalon_slave writeWaitTime 0
set_interface_property avalon_slave ENABLED true
set_interface_property avalon_slave EXPORT_OF ""
set_interface_property avalon_slave PORT_NAME_MAP ""
set_interface_property avalon_slave CMSIS_SVD_VARIABLES ""
set_interface_property avalon_slave SVD_ADDRESS_GROUP ""

add_interface_port avalon_slave avs_address address input 1
add_interface_port avalon_slave avs_write write input 1
add_interface_port avalon_slave avs_writedata writedata input 16
add_interface_port avalon_slave avs_waitrequest waitrequest output 1

# Add conduit interface for shift-register outputs (74HC595)
add_interface conduit_shift conduit end
set_interface_property conduit_shift ENABLED true
# serial data, clock, latch
add_interface_port conduit_shift sr_data export output 1
add_interface_port conduit_shift sr_clk export output 1
add_interface_port conduit_shift sr_latch export output 1

# Set component files
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL seven_seg_controller
add_fileset_file seven_seg_controller.v VERILOG PATH seven_seg_controller.v TOP_LEVEL_FILE

# Set synthesis files
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
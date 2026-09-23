open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
puts "TARGET: [get_hw_targets]"
puts "DEVICES: [get_hw_devices]"
puts "CURRENT: [current_hw_device]"
puts "PROGRAM_DONE: [get_property PROGRAM.DONE [current_hw_device]]"
exit

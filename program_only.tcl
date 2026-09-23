open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
current_hw_device [get_hw_devices xc7s25_0]
set_property PROGRAM.FILE {./neurobist_edge.bit} [get_hw_devices xc7s25_0]
program_hw_devices [get_hw_devices xc7s25_0]
refresh_hw_device [get_hw_devices xc7s25_0]
puts ">>> FPGA PROGRAMMED SUCCESSFULLY WITH NEUROBIST-EDGE! <<<"
exit

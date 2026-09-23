open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
current_hw_device [get_hw_devices xc7s25_0]
refresh_hw_device [get_hw_devices xc7s25_0]
puts "STATUS_DONE: [get_property REGISTER.CONFIG_STATUS.DONE_PIN [get_hw_devices xc7s25_0]]"
puts "BOOT_STATUS: [get_property REGISTER.BOOT_STATUS [get_hw_devices xc7s25_0]]"
exit

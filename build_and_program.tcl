# Vivado Implementation and Bitstream Generation Script for NeuroBIST-Edge
set_param general.maxThreads 8

puts "--- STEP 1: Reading Design Sources ---"
read_verilog -sv ./neuromorphic_bist_core.v
read_verilog -sv ./arty_s7_neuromorphic_top.v
read_xdc ./ArtyS7_Master.xdc

puts "--- STEP 2: Synthesis ---"
synth_design -top arty_s7_neuromorphic_top -part xc7s25csga324-1

puts "--- STEP 3: Logic Optimization ---"
opt_design

puts "--- STEP 4: Placement ---"
place_design

puts "--- STEP 5: Routing ---"
route_design

puts "--- STEP 6: Generating Bitstream ---"
write_bitstream -force ./neurobist_edge.bit

puts "--- STEP 7: Programming Spartan-7 Board ---"
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
current_hw_device [get_hw_devices xc7s25_0]
set_property PROGRAM.FILE {./neurobist_edge.bit} [get_hw_devices xc7s25_0]
program_hw_devices [get_hw_devices xc7s25_0]
refresh_hw_device [get_hw_devices xc7s25_0]

puts "========================================================================="
puts ">>> SUCCESS: SPARTAN-7 FPGA PROGRAMMED WITH NEUROBIST-EDGE ARCHITECTURE! <<<"
puts "========================================================================="
exit

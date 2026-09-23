## ============================================================================
## Master Physical XDC Constraints for Digilent Arty S7-25 (XC7S25-CSGA324)
## Project: NeuroBIST-Edge
## Using Standard Arduino / ChipKit Headers (L16, R14, T14, R16)
## ============================================================================

## 100 MHz System Clock (Bank 34 - SSTL135)
set_property -dict { PACKAGE_PIN R2    IOSTANDARD SSTL135 } [get_ports { CLK100MHZ }];
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports { CLK100MHZ }];
set_property INTERNAL_VREF 0.675 [get_iobanks 34]

## Dedicated Reset Push Button (Board Red Button, Active-Low)
set_property -dict { PACKAGE_PIN C18   IOSTANDARD LVCMOS33 } [get_ports { RESET_N }];

## Slide Switches (Bank 15 - LVCMOS33)
set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]; # SW0: 0=Wireless Mode, 1=BIST Mode
set_property -dict { PACKAGE_PIN H18   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]; # SW1: Manual Spike Level

## Push Buttons (Bank 15 - LVCMOS33)
set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]; # BTN0: Manual Spike Trigger
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]; # BTN1: BIST Reseed
set_property -dict { PACKAGE_PIN J16   IOSTANDARD LVCMOS33 } [get_ports { btn[2] }];
set_property -dict { PACKAGE_PIN H13   IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]; # BTN3: Reset

## ============================================================================
## Arduino / ChipKit Digital Header J1 (Bank 14 - LVCMOS33)
## Direct Wire Connection to ESP8266:
##   IO2 (Pin L16): Input from ESP8266 GPIO2 (D4 / TXD1)
##   IO3 (Pin R14): Output ACK to ESP8266 GPIO4 (D2)
##   IO4 (Pin T14): Output Spike to ESP8266 GPIO5 (D1)
##   IO5 (Pin R16): Output BIST Pass to ESP8266 GPIO12 (D6)
## ============================================================================
set_property -dict { PACKAGE_PIN L16   IOSTANDARD LVCMOS33 PULLDOWN true } [get_ports { esp_spike_in }];    # Arduino IO2 (Pin L16)
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { esp_pat_ack }];     # Arduino IO3 (Pin R14)
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { esp_neuron_fire }]; # Arduino IO4 (Pin T14)
set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports { esp_bist_pass }];   # Arduino IO5 (Pin R16)

## RGB LED LD0 (Residue Status - Bank 15 - LVCMOS33)
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { led0_r }]; # Red (Residue Error / Desync)
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { led0_g }]; # Green (Residue Invariant Valid)
set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { led0_b }];

## RGB LED LD1 (Neuron & BIST Status - Bank 15 - LVCMOS33)
set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 } [get_ports { led1_r }]; # Red/Purple (BIST Active)
set_property -dict { PACKAGE_PIN F18   IOSTANDARD LVCMOS33 } [get_ports { led1_g }]; # Green/Cyan (BIST Pass)
set_property -dict { PACKAGE_PIN E14   IOSTANDARD LVCMOS33 } [get_ports { led1_b }]; # Blue (Neuron Action Potential)

## 4 Standard Green LEDs (Bank 15 - LVCMOS33)
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; # LD2: BIST Pass / Divisible by 3
set_property -dict { PACKAGE_PIN F13   IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; # LD3: Remainder Bit 0 / MISR[0]
set_property -dict { PACKAGE_PIN E13   IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; # LD4: Remainder Bit 1 / MISR[1]
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; # LD5: Spike Activity Strobe

## Configuration Voltage
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## USB-UART Interface (FTDI Channel B - COM5)
set_property -dict { PACKAGE_PIN R12   IOSTANDARD LVCMOS33 } [get_ports { uart_rxd }]; # Sch=uart_rxd_out (Input from PC)
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { uart_txd }]; # Sch=uart_txd_in (Output to PC)


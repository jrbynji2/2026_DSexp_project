## clk = MAIN_CLOCK (CLOCK SELECT ?ä§?úÑÏπ? F = 50MHz)
set_property -dict {PACKAGE_PIN B6  IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name clk [get_ports clk]
## TGAM T(TX) -> Exp. Port J6 3Î≤? ?? = EXT0
## ?ó∞Í≤∞Ïù¥ Îπ†Ï†∏?èÑ UART idle(High)Î°? Î≥¥Ïù¥Í≤? ?Ç¥Î∂? ???óÖ
set_property -dict {PACKAGE_PIN Y21 IOSTANDARD LVCMOS33 PULLUP true} [get_ports tgam_tx]

## LED1~5
set_property -dict {PACKAGE_PIN U5  IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN V1  IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN V4  IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN V5  IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN W1  IOSTANDARD LVCMOS33} [get_ports {led[4]}]

## 7-segment (10Ï£ºÏ∞® keypad.xdc Í∏∞Ï?)
set_property -dict {PACKAGE_PIN T2  IOSTANDARD LVCMOS33} [get_ports {seg_com[7]}]
set_property -dict {PACKAGE_PIN T1  IOSTANDARD LVCMOS33} [get_ports {seg_com[6]}]
set_property -dict {PACKAGE_PIN R5  IOSTANDARD LVCMOS33} [get_ports {seg_com[5]}]
set_property -dict {PACKAGE_PIN R4  IOSTANDARD LVCMOS33} [get_ports {seg_com[4]}]
set_property -dict {PACKAGE_PIN R3  IOSTANDARD LVCMOS33} [get_ports {seg_com[3]}]
set_property -dict {PACKAGE_PIN R2  IOSTANDARD LVCMOS33} [get_ports {seg_com[2]}]
set_property -dict {PACKAGE_PIN P3  IOSTANDARD LVCMOS33} [get_ports {seg_com[1]}]
set_property -dict {PACKAGE_PIN P2  IOSTANDARD LVCMOS33} [get_ports {seg_com[0]}]
set_property -dict {PACKAGE_PIN P1  IOSTANDARD LVCMOS33} [get_ports {seg_data[7]}]
set_property -dict {PACKAGE_PIN N5  IOSTANDARD LVCMOS33} [get_ports {seg_data[6]}]
set_property -dict {PACKAGE_PIN N4  IOSTANDARD LVCMOS33} [get_ports {seg_data[5]}]
set_property -dict {PACKAGE_PIN N3  IOSTANDARD LVCMOS33} [get_ports {seg_data[4]}]
set_property -dict {PACKAGE_PIN N1  IOSTANDARD LVCMOS33} [get_ports {seg_data[3]}]
set_property -dict {PACKAGE_PIN M5  IOSTANDARD LVCMOS33} [get_ports {seg_data[2]}]
set_property -dict {PACKAGE_PIN M4  IOSTANDARD LVCMOS33} [get_ports {seg_data[1]}]
set_property -dict {PACKAGE_PIN M3  IOSTANDARD LVCMOS33} [get_ports {seg_data[0]}]

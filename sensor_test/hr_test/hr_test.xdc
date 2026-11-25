## clk = MAIN_CLOCK (CLOCK SELECT 스위치 F = 50MHz)
set_property -dict {PACKAGE_PIN B6  IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name clk [get_ports clk]

## 심박센서 출력 -> J6 5번 핀 (EXT2)
##  5V 배선: 10kΩ + 15kΩ 분압을 거쳐 연결 / 3.3V 배선: 바로 연결
##  분압이 틀어지지 않게 PULLUP은 걸지 않음
set_property -dict {PACKAGE_PIN AB21 IOSTANDARD LVCMOS33} [get_ports hr_sig]

## 3.3V 배선일 때 센서 VCC -> J6 7번 핀 (EXT4). 최대 구동전류 16mA로 설정
set_property -dict {PACKAGE_PIN AA20 IOSTANDARD LVCMOS33 DRIVE 16} [get_ports hr_vcc]

## LED1~3
set_property -dict {PACKAGE_PIN U5 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN V1 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN V4 IOSTANDARD LVCMOS33} [get_ports {led[2]}]

## 7-segment (10주차 keypad.xdc 기준)
set_property -dict {PACKAGE_PIN T2 IOSTANDARD LVCMOS33} [get_ports {seg_com[7]}]
set_property -dict {PACKAGE_PIN T1 IOSTANDARD LVCMOS33} [get_ports {seg_com[6]}]
set_property -dict {PACKAGE_PIN R5 IOSTANDARD LVCMOS33} [get_ports {seg_com[5]}]
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS33} [get_ports {seg_com[4]}]
set_property -dict {PACKAGE_PIN R3 IOSTANDARD LVCMOS33} [get_ports {seg_com[3]}]
set_property -dict {PACKAGE_PIN R2 IOSTANDARD LVCMOS33} [get_ports {seg_com[2]}]
set_property -dict {PACKAGE_PIN P3 IOSTANDARD LVCMOS33} [get_ports {seg_com[1]}]
set_property -dict {PACKAGE_PIN P2 IOSTANDARD LVCMOS33} [get_ports {seg_com[0]}]
set_property -dict {PACKAGE_PIN P1 IOSTANDARD LVCMOS33} [get_ports {seg_data[7]}]
set_property -dict {PACKAGE_PIN N5 IOSTANDARD LVCMOS33} [get_ports {seg_data[6]}]
set_property -dict {PACKAGE_PIN N4 IOSTANDARD LVCMOS33} [get_ports {seg_data[5]}]
set_property -dict {PACKAGE_PIN N3 IOSTANDARD LVCMOS33} [get_ports {seg_data[4]}]
set_property -dict {PACKAGE_PIN N1 IOSTANDARD LVCMOS33} [get_ports {seg_data[3]}]
set_property -dict {PACKAGE_PIN M5 IOSTANDARD LVCMOS33} [get_ports {seg_data[2]}]
set_property -dict {PACKAGE_PIN M4 IOSTANDARD LVCMOS33} [get_ports {seg_data[1]}]
set_property -dict {PACKAGE_PIN M3 IOSTANDARD LVCMOS33} [get_ports {seg_data[0]}]

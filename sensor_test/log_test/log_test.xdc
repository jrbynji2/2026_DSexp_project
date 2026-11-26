## clk = MAIN_CLOCK (CLOCK SELECT 스위치 F = 50MHz)
set_property -dict {PACKAGE_PIN B6   IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name clk [get_ports clk]

## 뇌파센서 T -> J6 3번 (EXT0). 선이 빠져도 idle(High)로 보이게 풀업
set_property -dict {PACKAGE_PIN Y21  IOSTANDARD LVCMOS33 PULLUP true} [get_ports tgam_tx]
## 심박센서 출력 -> J6 5번 (EXT2). 5V 배선이면 분압 후 연결, PULLUP 금지
set_property -dict {PACKAGE_PIN AB21 IOSTANDARD LVCMOS33} [get_ports hr_sig]
## 3.3V 배선일 때 심박센서 VCC -> J6 7번 (EXT4)
set_property -dict {PACKAGE_PIN AA20 IOSTANDARD LVCMOS33 DRIVE 16} [get_ports hr_vcc]

## USB-Serial: FPGA 출력 = U4 (보드 USB 칩 CP2102의 RXD). U3은 칩의 TXD라 FPGA 입력 (2026-11-26 usb_probe로 보드 확인)
set_property -dict {PACKAGE_PIN U4   IOSTANDARD LVCMOS33} [get_ports usb_tx]

## DIP 스위치 (올리면 1)
set_property -dict {PACKAGE_PIN AB3  IOSTANDARD LVCMOS33} [get_ports {dip[0]}]
set_property -dict {PACKAGE_PIN AB4  IOSTANDARD LVCMOS33} [get_ports {dip[1]}]
set_property -dict {PACKAGE_PIN Y4   IOSTANDARD LVCMOS33} [get_ports {dip[2]}]
set_property -dict {PACKAGE_PIN Y5   IOSTANDARD LVCMOS33} [get_ports {dip[3]}]
set_property -dict {PACKAGE_PIN W5   IOSTANDARD LVCMOS33} [get_ports {dip[4]}]
set_property -dict {PACKAGE_PIN V6   IOSTANDARD LVCMOS33} [get_ports {dip[5]}]
set_property -dict {PACKAGE_PIN AB5  IOSTANDARD LVCMOS33} [get_ports {dip[6]}]
set_property -dict {PACKAGE_PIN AA6  IOSTANDARD LVCMOS33} [get_ports {dip[7]}]

## 마커 버튼 SW_C
set_property -dict {PACKAGE_PIN AB6  IOSTANDARD LVCMOS33} [get_ports btn_mark]

## LED1~4
set_property -dict {PACKAGE_PIN U5   IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN V1   IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN V4   IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN V5   IOSTANDARD LVCMOS33} [get_ports {led[3]}]

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

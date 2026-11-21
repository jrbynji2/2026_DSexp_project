## 버튼 SW_B
set_property -dict {PACKAGE_PIN V7   IOSTANDARD LVCMOS33} [get_ports btn]
## 진동모터 모듈 IN -> J6 4번 핀 (EXT1). 모듈 VCC는 J6 2번(5V), GND는 J6 50번
set_property -dict {PACKAGE_PIN AA22 IOSTANDARD LVCMOS33} [get_ports motor]
## LED1
set_property -dict {PACKAGE_PIN U5   IOSTANDARD LVCMOS33} [get_ports led]

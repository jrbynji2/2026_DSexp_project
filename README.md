# FPGA 기반 거짓말탐지기

2026-2 디지털시스템실험 기말 프로젝트.
뇌파 센서(TGAM1)와 심박 센서(DFRobot SEN0203) 값을 FPGA로 받아, **참인 질문(기준)** 과 **판별 질문** 에 대한
생체 반응을 비교해 거짓/진실을 표시합니다. 신호 수신부터 판정, 화면 출력까지 모두 Verilog로 구현했습니다.

- 보드: 한백전자 FPGA Digital Logic Design (Vivado 2022.2)
- 클럭: 보드의 **CLOCK SELECT 스위치를 F(50MHz)** 에 두고 사용합니다. 모든 설계가 50MHz 단일 클럭을 전제로 합니다.

## 폴더 구조

```
sensor_test/     센서를 하나씩 확인하는 테스트 설계 4개   → sensor_test/README.md
  tgam_test/       뇌파 수신 확인
  hr_test/         심박 확인
  motor_test/      진동모터 확인
  log_test/        뇌파+심박 데이터를 노트북으로 기록
main_project/    최종 설계                                      → main_project/README.md
```

각 폴더는 **독립된 Vivado 프로젝트 하나에 들어갈 소스 묶음** 입니다. 공통 모듈도
폴더마다 복사본이 있으므로, 폴더 하나씩 합성을 진행합니다. `tb_*.v`는 시뮬레이션 전용입니다.

## 하드웨어 연결

| 장치 | 연결 | FPGA 핀 | 주의 |
|---|---|---|---|
| 뇌파 TGAM1 T(송신) | J6 3번 (EXT0) | Y21 | TGAM 전원은 배터리(2.97\~3.63V). **5V 연결 금지** |
| 진동모터 모듈 IN | J6 4번 (EXT1) | AA22 | 모듈 VCC = J6 2번(5V), GND = J6 50번 |
| 심박센서 OUT | J6 5번 (EXT2) | AB21 | 5V 전원이면 **10kΩ+15kΩ 분압(약 3.0V) 필요** |
| 심박센서 VCC (3.3V 배선) | J6 7번 (EXT4) | AA20 | FPGA 핀이 항상 1을 출력해 전원으로 씀. 5V(J6 1번)와 동시 연결 금지 |
| 피에조 | 보드 내장 | W4 | 옆 DIP 스위치를 켜야 소리 남 |

- J6(Exp. Port, 25×2): 1·2번 = 5V, 3\~48번 = EXT0\~EXT45, 49·50번 = GND
- 버튼, LED, 7-Segment, Text LCD, TFT LCD 핀은 각 폴더의 `.xdc` 파일에 있습니다.

## Vivado 사용법 (공통)

1. **Create Project** → RTL Project → 보드 FPGA 파트 선택
2. **Add Sources**
   - Design Sources: 폴더 안의 `.v` 파일 중 `tb_*.v`를 **뺀** 전부
   - Constraints: 폴더 안의 `.xdc`
   - Simulation Sources: `tb_*.v` (시뮬레이션할 때만)
3. 합성 top이 폴더의 `*_top` 모듈인지 확인합니다 (Sources 창에서 우클릭 → Set as Top).
   시뮬레이션 top(`tb_*`)과 헷갈리지 않도록 주의하세요.
4. Generate Bitstream → Hardware Manager → Program Device
5. 보드의 CLOCK SELECT 스위치가 **50MHz** 인지 확인합니다.

> `.xdc` 파일의 주석은 UTF-8 한국어입니다. Vivado 안에서 열고 저장하면 한글 주석이 깨질 수 있으므로
> VS Code로 수정하는 것을 권장합니다.

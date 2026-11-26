# sensor_test: 센서·장치 확인용 테스트 설계

최종 설계에 들어가기 전에 센서와 장치를 하나씩 보드에서 확인하기 위한 설계입니다.
폴더마다 독립된 Vivado 프로젝트로 만들어 사용합니다.

| 폴더 | 합성 top | 확인하는 것 |
|---|---|---|
| `tgam_test/` | `tgam_test_top` | 뇌파 패킷 수신, Attention·Meditation 값 |
| `hr_test/` | `hr_test_top` | 심박 펄스 검출, BPM 계산 |
| `motor_test/` | `motor_test_top` | 진동모터 구동 |
| `log_test/` | `log_test_top` | 뇌파+심박 데이터를 노트북에 CSV로 기록 |
| `tgam_bluetooth/` | (FPGA 없음) | TGAM 키트 블루투스 모듈로 노트북에서 직접 뇌파 확인 |

---

## tgam_test: 뇌파 수신 확인

TGAM1이 보내는 UART(57600 baud) 패킷을 받아 체크섬을 검사하고, 값을 7-Segment와 LED로 보여줍니다.

**표시**
- 7-Segment: `[Attention 3자리] [빈칸 2] [Meditation 3자리]`
- LED1: UART 바이트 수신 중 · LED2: 정상 패킷 수신 중 · LED3: 체크섬 오류 발생
- LED4: 신호 양호(Poor Signal = 0) · LED5: 전극 미접촉(Poor Signal = 200)

**확인 순서**
1. 전극을 이마와 귓불에 착용하고 TGAM 전원을 켭니다.
2. LED1, LED2가 깜빡이면 수신은 정상입니다. LED3이 자주 켜지면 배선이나 전원을 확인하세요.
3. LED4가 켜진 뒤 몇 초가 지나면 Attention·Meditation 값이 나옵니다. 0은 계산 불가라는 뜻입니다.

**모듈**: `uart_rx`(8N1 수신, 2FF 동기화), `tgam_parser`(ThinkGear 패킷 파서, 체크섬이 맞는 패킷만 반영)

---

## hr_test: 심박 확인

심박센서의 디지털 펄스 출력에서 박동을 검출하고 BPM을 계산합니다. 5V 배선과 3.3V 배선 모두 같은 비트스트림을 씁니다.

**표시**
- 7-Segment: `[BPM 3자리] [빈칸] [박동 간격 ms 4자리]`
- LED1: 센서 출력 그대로 · LED2: 박동으로 인정된 순간(100ms 켜짐) · LED3: 3초 넘게 박동 없음

**배선 (둘 중 하나 확인해서)**
- 3.3V: 센서 VCC → J6 7번(`hr_vcc`, FPGA가 1 출력). 사양 하한이라 불안정할 수 있습니다.
- 5V: 센서 VCC → J6 1번, 센서 OUT → 10kΩ+15kΩ 분압 → J6 5번

**동작 방식**
- 상승 엣지를 박동으로 봅니다. 직전 박동 후 300ms 안의 엣지는 노이즈로 무시합니다(최대 200BPM).
- BPM = 60000 / 간격(ms). 나눗셈기 대신 반복 뺄셈으로 계산합니다.

**모듈**: `tick_gen`(1ms 펄스), `pulse_in`(박동 검출·간격 측정), `bpm_calc`(BPM 계산), `seg8_driver`(7-Segment 스캔)

---

## motor_test: 진동모터 확인

SW_B를 누르는 동안 진동모터와 LED1이 켜집니다.
누르지 않았는데 진동하면 버튼이 눌렸을 때 Low인 것이므로, `motor_test_top.v`의 `btn`을 `~btn`으로 바꿉니다.

---

## log_test: 데이터 기록

판정 규칙을 정하기 위해 뇌파와 심박 데이터를 USB-Serial(115200 baud)로 노트북에 보내고, `eeg_logger.py`로 CSV에 저장합니다.

**표시와 조작**
- 7-Segment: `[Attention 3자리] [빈칸 2] [BPM 3자리]`
- LED1: 뇌파 패킷 수신 · LED2: 박동 · LED3: 전극 접촉 양호 · LED4: 마커 버튼 눌림
- **DIP 스위치 8개 = 상황 플래그**: 모든 줄에 함께 기록됩니다. 스위치를 바꾸면 그 순간이 이벤트로도 기록됩니다.
  뜻은 아래 규약처럼 실험 전에 정해 두고 씁니다.
- **SW_C = 마커 버튼**: 누른 순간이 이벤트로 기록됩니다.
- 버튼이 반대로 동작하면(안 눌렀는데 LED4가 켜져 있으면) `log_test_top`의 `BTN_ACTIVE_HIGH`를 0으로 바꿉니다.

**DIP 스위치 규약 (예시)**

최종 설계의 진행(기준 질문 → 판별 질문)과 같은 구조로 데이터를 모으기 위한 규약입니다.
스위치는 올리면 1이고, CSV에는 `dip1`\~`dip8` 열로 따로 저장됩니다.

| 스위치 | 0 | 1 | 언제 바꾸나 |
|---|---|---|---|
| DIPSW1 | 쉬는 중 | **측정 구간** (질문\~답변 후 10초) | 질문을 시작할 때 올리고, 10초 뒤 내림 |
| DIPSW2 | 기준 질문 (참인 질문) | 판별 질문 | 질문하기 전에 맞춰 둠 |
| DIPSW3 | 진실로 답함 | 거짓으로 답함 | 질문하기 전에 피험자와 정한 대로 맞춰 둠 (정답 라벨) |
| DIPSW4 | 정상 | 움직임·말하기·전극 들뜸 등 잡음 있음 | 잡음이 생기면 바로 올림 → 분석에서 제외 |
| DIPSW5\~8 | 질문 번호 0\~15 (2진수, DIPSW5가 최하위 비트) | | 질문마다 바꿈 |

- 마커 버튼(SW_C)은 **피험자가 답한 순간**에 누릅니다. 질문을 시작한 시각은 DIPSW1이 올라간 순간으로 남습니다.
- 질문 번호 = `flag >> 4`, 측정 구간만 고르기 = `dip1 == 1`, 잡음 구간 빼기 = `dip4 == 0`

**실험 순서 예시** (질문 1개)
1. DIPSW5\~8을 질문 번호에 맞춥니다. 예를 들어 3번 질문이면 DIPSW5, DIPSW6을 올립니다.
2. DIPSW2(기준/판별)와 DIPSW3(진실/거짓)을 맞춥니다.
3. 질문을 시작하면서 DIPSW1을 올립니다.
4. 피험자가 답하면 SW_C를 누릅니다.
5. 10초 뒤 DIPSW1을 내리고, 다음 질문 전까지 쉽니다 (센서 값이 다시 안정될 때까지 20초 정도 권장).

예를 들어 "참인 질문에 진실로 답함"과 "판별 질문에 거짓으로 답함"의 측정 구간 평균 BPM·Meditation 차이를 보면,
최종 설계의 판정 기준값(`TH_BPM`, `TH_MED`)을 정할 수 있습니다.

**노트북 쪽 사용법**

보드의 USB-Serial 칩은 **CP2102**입니다. 처음 한 번 Silicon Labs의 *CP210x Universal Windows Driver*를 설치해야
COM 포트가 생깁니다 (장치 관리자 → 포트(COM & LPT)에서 번호 확인). COM 포트는 한 프로그램만 열 수 있으니,
로거를 다시 실행할 때는 이전 로거를 Ctrl+C로 끄고 실행하세요.
FPGA 송신 핀은 **U4**입니다 (2026-11-26 보드에서 확인. 장치 자료의 `USB_TXD = U3`은 USB 칩 기준 이름이라 U3은 FPGA 입력).
```
pip install pyserial
python eeg_logger.py --list            # 연결된 COM 포트 확인
python eeg_logger.py COM5              # 기록 시작, Ctrl+C로 종료
python eeg_logger.py --replay raw.log  # 저장해 둔 원본 로그를 다시 CSV로 변환
```

**저장 파일** (`logs/<날짜_시각>/`)

| 파일 | 내용 |
|---|---|
| `eeg.csv` | 1초마다: Poor Signal, Attention, Meditation, 8개 대역 파워 |
| `beat.csv` | 박동마다: 간격(ms), BPM |
| `events.csv` | DIP 스위치 변경, 마커 버튼 |
| `raw.log` | 받은 줄 원본 (PC 시각 포함) |

모든 줄에 FPGA 기준 시각(ms)과 DIP 플래그가 들어 있어, 파일끼리 시간을 맞춰 비교할 수 있습니다.

**전송 형식** (16진수 텍스트, 한 줄씩)
```
E,<ms>,<flag>,<poor>,<att>,<med>,<delta>,<theta>,<lowA>,<highA>,<lowB>,<highB>,<lowG>,<midG>
B,<ms>,<flag>,<박동 간격 ms>
F,<ms>,<flag>          DIP 스위치가 바뀐 순간
M,<ms>,<flag>          마커 버튼을 누른 순간
```

**모듈**: tgam_test·hr_test의 모듈 + `uart_tx`(8N1 송신), `log_formatter`(이벤트를 텍스트 줄로 만들어 전송)

---

## tgam_bluetooth: FPGA 없이 뇌파 확인

TGAM 키트의 블루투스 모듈로 노트북이 ThinkGear 패킷을 직접 받아, 1초마다 Poor Signal·Attention·Meditation을 보여주고 CSV로 저장합니다.
블루투스로는 값이 오는데 FPGA(tgam_test, log_test)로는 안 오면 TGAM은 정상이고 FPGA 쪽 배선 문제입니다. 최종 설계에서는 블루투스를 쓰지 않습니다.

1. 블루투스 모듈을 TGAM에 연결하고 TGAM 전원을 켭니다.
2. Windows 설정 → Bluetooth → 장치 추가에서 모듈과 페어링합니다 (PIN을 물으면 `1234` 또는 `0000`).
3. 장치 관리자에 블루투스 COM 포트가 2개 생깁니다. "기타 Bluetooth 설정 → COM 포트" 탭에서 **보내는 쪽(Outgoing)** 번호를 씁니다.
4. 실행합니다.
```
python tgam_bluetooth.py --list        # COM 포트 확인
python tgam_bluetooth.py COM7          # 수신 시작, Ctrl+C로 종료
python tgam_bluetooth.py COM7 --raw    # Raw 뇌파(약 512Hz)도 raw.csv로 저장
python tgam_bluetooth.py --test        # 파서 자체 점검
```
- 화면 열: `poor att med raw/s chk_err`. 정상이면 raw/s가 약 512이고, 전극을 착용하면 poor가 200 → 0으로 내려간 뒤 몇 초 후 att·med가 나옵니다.
- 바이트가 아예 안 오면 포트(Outgoing인지)·전원·페어링을, chk_err만 늘면 모듈의 내부 baud가 57600인지 확인합니다.
- 저장: `tgam_bluetooth/logs/<날짜_시각>/eeg.csv` (pc_time, poor, att, med, 8개 대역), `--raw`면 `raw.csv`

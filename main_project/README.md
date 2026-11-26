# main_project: 최종 설계

- 합성 top: `main_top` · 핀 제약: `main.xdc` · 시뮬레이션 top: `tb_main`
- Vivado 프로젝트 만드는 법은 저장소 루트 README 참고. 배선은 `sensor_test`와 같습니다.

> **현재 상태**: 시뮬레이션 검증까지 완료. 합성·보드 테스트 전.
> 판정 규칙과 소리는 임시값입니다 (아래 "조정할 값" 참고).

## 사용법

| 조작 | 기능 |
|---|---|
| SW_B (START) | 다음 단계로 |
| SW_A (RESET) | 언제든 처음(①)으로 |

| 단계 | Text LCD | Full Color LED | 넘어가는 조건 |
|---|---|---|---|
| ① 연결 대기 | `CONNECT SENSORS` / `EEG:OK  HR:--` | 꺼짐 | 두 센서가 모두 OK면 `PRESS START`로 바뀜 → START |
| ② 기준 준비 | `ASK TRUE Q.` / `THEN PRESS START` | 꺼짐 | 참인 질문을 하고 START |
| ③ 기준 측정 | `BASELINE...` / `TIME LEFT 10s` | 파랑 | 10초 뒤 자동 |
| ④ 판별 준비 | `ASK TEST Q.` / `THEN PRESS START` | 꺼짐 | 판별할 질문을 하고 START |
| ⑤ 판별 측정 | `MEASURING...` / `TIME LEFT 10s` | 노랑 | 10초 뒤 자동 |
| ⑥ 결과 | `LIE DETECTED` / `TRUTH` / `NO DATA (RETRY)` | 빨강 / 초록 / 흰색 | START → ④ (같은 기준으로 다음 질문) |

- 거짓: 빨강 LED + 낮은 부저음 3번 + 진동 1.5초 · 진실: 초록 LED + 도-미-솔
- `NO DATA`: 측정 중에 유효한 센서 값이 하나도 없었을 때입니다. 전극과 센서 착용을 확인하고 다시 측정하세요.
- 피에조 소리를 들으려면 피에조 옆 DIP 스위치를 켜야 합니다.

**그 밖의 표시**
- 7-Segment: `[Attention 3자리] [측정 중 남은 초 2자리] [BPM 3자리]`
- LED1: 뇌파 패킷 수신 · LED2: 박동 · LED3: 전극 접촉 양호 · LED4: 심박 측정 중 · LED5: START 버튼 눌림
- TFT LCD (800×480), 위에서 아래로:

| y 범위 | 내용 |
|---|---|
| 0~29 | 단계 색 막대 (Full Color LED와 같은 색) |
| 40~239 | Raw 뇌파 파형 (최근 약 3초) |
| 270~379 | 최근 100초 Attention(하늘색) / Meditation(초록) 막대 |
| 400~469 | 숫자: BPM(빨강) · Attention(하늘색) · Meditation(초록), 오른쪽 끝에 박동 표시 |

## 판정 방법

기준 측정(③)과 판별 측정(⑤) 각각 10초 동안 BPM과 Meditation의 평균을 구해 비교합니다.

- 판별 평균 BPM ≥ 기준 평균 BPM + `TH_BPM`, **또는**
- 판별 평균 Meditation ≤ 기준 평균 Meditation − `TH_MED`

→ **거짓** (`lie = 1`). 둘 다 아니면 진실입니다.

평균을 직접 나누지 않고 교차곱으로 비교합니다: `s_t/n_t − s_b/n_b ≥ TH` ⇔ `s_t·n_b ≥ s_b·n_t + TH·n_b·n_t`

## 조정할 값 (`main_top` 파라미터)

| 파라미터 | 기본값 | 의미 |
|---|---|---|
| `TH_BPM` | 5 | 거짓으로 볼 BPM 상승폭 (**임시**, log_test 데이터로 결정) |
| `TH_MED` | 10 | 거짓으로 볼 Meditation 하락폭 (**임시**) |
| `MEAS_SEC` | 10 | 측정 시간(초) |
| `BTN_ACTIVE_HIGH` | 1 | 버튼이 반대로 동작하면 0 |

`tft_display`의 `RAW_SHIFT`(기본 3)는 Raw 파형 세로 크기입니다. 파형이 너무 크면 올리고, 너무 작으면 내립니다.

## 모듈 구성

```
                 ┌ uart_rx → tgam_parser ─┬─────────────────────────────┐
 TGAM ───────────┘                        │ Attention/Meditation/Raw    │
                                          ▼                             ▼
 심박 ── pulse_in → bpm_calc ──→ feature_accum ×2 → decision ──┬→ rgb_led ──→ Full Color LED
                                   ▲ (기준/판별)                ├→ alert ────→ 피에조, 진동모터
 버튼 ── btn_pulse → main_fsm ─────┘                            ├→ lcd_msg → text_lcd_ctrl → Text LCD
                         └ 단계, 남은 초 ───────────────────────┴→ tft_display ──→ TFT LCD
```

| 모듈 | 역할 |
|---|---|
| `main_top` | 전체 연결, LED·7-Segment 표시 |
| `tick_gen` | 1ms마다 1클럭 펄스 |
| `uart_rx` | TGAM UART 수신 (57600 8N1) |
| `tgam_parser` | ThinkGear 패킷 파서. Poor Signal, Attention, Meditation, Raw |
| `pulse_in` | 심박 펄스 → 박동 검출, 간격(ms) 측정 |
| `bpm_calc` | BPM = 60000 / 간격 (반복 뺄셈) |
| `btn_pulse` | 버튼 동기화, 눌린 순간 펄스 |
| `main_fsm` | 6단계 진행, 측정 시간 카운트 |
| `feature_accum` | 측정 구간의 BPM·Meditation 합과 개수 (기준용·판별용 2개) |
| `decision` | 평균 비교로 거짓/진실 판정 |
| `rgb_led` | 단계별 Full Color LED 색 |
| `alert` | 결과 소리(피에조 멜로디)와 진동 |
| `lcd_msg` | 단계별 Text LCD 문구 |
| `text_lcd_ctrl` | Text LCD(HD44780) 초기화와 글자 쓰기 |
| `seg8_driver` | 7-Segment 8자리 스캔 |
| `tft_display` | TFT 타이밍 생성, Raw·기록 버퍼, 화면 그리기 (프레임 버퍼 없이 좌표 비교) |

## 시뮬레이션

`tb_main`은 시간을 줄여(1ms → 10us, 측정 4초) 전체 과정을 확인합니다.
- 기준 60BPM, 판별 100BPM → 거짓, 빨강 LED, 진동, 소리, LCD `LIE DETECTED`
- 같은 기준에서 판별 60BPM → 진실, 초록 LED, LCD `TRUTH`
- SW_A 리셋, TFT 한 화면 픽셀 수(800×480)

Vivado GUI에서는 Simulation Sources에 `tb_main.v`를 넣고 Run Simulation을 누릅니다. 명령줄에서는 이 폴더에서 다음을 실행합니다 (Git Bash 등 `*.v`가 펼쳐지는 셸 기준, Vivado `bin` 폴더가 PATH에 있어야 함).
```
xvlog *.v
xelab tb_main -s tb_main_sim
xsim tb_main_sim -R
```
마지막에 `errors = 0`이 나오면 통과입니다.

## 보드에서 확인할 것

- 버튼 극성(`BTN_ACTIVE_HIGH`)
- Full Color LED 노랑(R+G)이 노랗게 보이는지
- TFT가 25MHz 픽셀 클럭으로 표시되는지 (안 나오면 `tft_display.v` 주석 참고)
- Text LCD 표시
- Raw 파형 크기(`RAW_SHIFT`)
